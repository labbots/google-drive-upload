#!/usr/bin/env bash
# Upload a file to Google Drive
# shellcheck source=/dev/null

_usage() {
    printf "%b" "
The script can be used to upload file/directory to google drive.\n
Usage:\n ${0##*/} [options.. ] <filename> <foldername>\n
Foldername argument is optional. If not provided, the file will be uploaded to preconfigured google drive.\n
File name argument is optional if create directory option is used.\n
Options:\n
  -a | --account 'account name' - Use different account than the default one.\n
      To change the default account name, use this format, -a/--account default=account_name\n
  -la | --list-accounts - Print all configured accounts in the config files.\n
  -ca | --create-account 'account name' - To create a new account with the given name if does not already exists.\n
  -da | --delete-account 'account name' - To delete an account information from config file. \n
  -c | -C | --create-dir <foldername> - option to create directory. Will provide folder id. Can be used to provide input folder, see README.\n
  -r | --root-dir <google_folderid> or <google_folder_url> - google folder ID/URL to which the file/directory is going to upload.
      If you want to change the default value, then use this format, -r/--root-dir default=root_folder_id/root_folder_url\n
  -s | --skip-subdirs - Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder, use this along with -p/--parallel option to speed up the uploads.\n
  -p | --parallel <no_of_files_to_parallely_upload> - Upload multiple files in parallel, Max value = 10.\n
  -f | --[file|folder] - Specify files and folders explicitly in one command, use multiple times for multiple folder/files. See README for more use of this command.\n
  -cl | --clone - Upload a gdrive file without downloading, require accessible gdrive link or id as argument.\n
  -o | --overwrite - Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders.\n
  -desc | --description | --description-all - Specify description for the given file. To use the respective metadata of a file, below is the format:\n
         File name ( fullname ): %f | Size: %s | Mime Type: %m\n
         Now to actually use it: --description 'Filename: %f, Size: %s, Mime: %m'\n
         Note: For files inside folders, use --description-all flag.\n
  -d | --skip-duplicates - Do not upload the files with the same name, if already present in the root folder/input folder, also works with recursive folders.\n
  -S | --share <optional_email_address>- Share the uploaded input file/folder, grant reader permission to provided email address or to everyone with the shareable link.\n
  -SM | -sm | --share-mode 'share mode' - Specify the share mode for sharing file.\n
        Share modes are: r / reader - Read only permission.\n
                       : w / writer - Read and write permission.\n
                       : c / commenter - Comment only permission.\n
        Note: Although this flag is independent of --share flag but when email is needed, then --share flag use is neccessary.\n
  --speed 'speed' - Limit the download speed, supported formats: 1K, 1M and 1G.\n
  -i | --save-info <file_to_save_info> - Save uploaded files info to the given filename.\n
  -z | --config <config_path> - Override default config file with custom config file.\nIf you want to change default value, then use this format -z/--config default=default=your_config_file_path.\n
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -R | --retry 'num of retries' - Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.\n
  -in | --include 'pattern' - Only include the files with the given pattern to upload - Applicable for folder uploads.\n
      e.g: ${0##*/} local_folder --include "*1*", will only include with files with pattern '1' in the name.\n
  -ex | --exclude 'pattern' - Exclude the files with the given pattern from uploading. - Applicable for folder uploads.\n
      e.g: ${0##*/} local_folder --exclude "*1*", will exclude all the files pattern '1' in the name.\n
  --hide - This flag will prevent the script to print sensitive information like root folder id or drivelink.\n
  -v | --verbose - Display detailed message (only for non-parallel uploads).\n
  -V | --verbose-progress - Display detailed message and detailed upload progress(only for non-parallel uploads).\n
  --skip-internet-check - Do not check for internet connection, recommended to use in sync jobs.
  $([[ ${GUPLOAD_INSTALLED_WITH} = script ]] && printf '%s\n' '\n  -u | --update - Update the installed script in your system.\n
  -U | --uninstall - Uninstall script, remove related files.\n')
  --info - Show detailed info, only if script is installed system wide.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display this message.\n"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Print info if installed
# Globals: 7 variable
#   COMMAND_NAME REPO INSTALL_PATH INSTALLATION TYPE TYPE_VALUE LATEST_INSTALLED_SHA
# Arguments: None
# Result: read description
###################################################
_version_info() {
    if command -v "${COMMAND_NAME}" 1> /dev/null && [[ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]]; then
        for i in REPO INSTALL_PATH INSTALLATION TYPE TYPE_VALUE LATEST_INSTALLED_SHA CONFIG; do
            printf "%s\n" "${i}=\"${!i}\""
        done | sed -e "s/=/: /g"
    else
        printf "%s\n" "google-drive-upload is not installed system wide."
    fi
    exit 0
}

###################################################
# Function to cleanup config file
# Remove invalid access tokens on the basis of corresponding expiry
# Globals: None
# Arguments: 1
#   ${1} = config file
# Result: read description
###################################################
_cleanup_config() {
    declare config="${1:?Error: Missing config}" values_regex

    ! [ -f "${config}" ] && return 0

    while read -r line && [[ -n ${line} ]]; do
        expiry_value_name="${line%%=*}"
        token_value_name="${expiry_value_name%%_EXPIRY}"

        : "${line##*=}" && : "${_%\"}" && expiry="${_#\"}"
        [[ ${expiry} -le "$(printf "%(%s)T\\n" "-1")" ]] &&
            values_regex="${values_regex:+${values_regex}|}${expiry_value_name}=\".*\"|${token_value_name}=\".*\""

    done <<< "$(grep -F ACCESS_TOKEN_EXPIRY "${config}" || :)"

    chmod u+w "${config}" &&
        printf "%s\n" "$(grep -Ev "^\$${values_regex:+|${values_regex}}" "${config}")" >| "${config}" &&
        chmod "a-w-r-x,u+r" "${config}"
    return 0
}

###################################################
# Process all arguments given to the script
# Globals: 2 variable, 1 function
#   Variable - HOME, CONFIG
#   Functions - _short_help
# Arguments: Many
#   ${@} = Flags with argument and file/folder input
# Result: On
#   Success - Set all the variables
#   Error   - Print error message and exit
# Reference:
#   Email Regex - https://gist.github.com/guessi/82a73ee7eb2b1216eb9db17bb8d65dd1
###################################################
_setup_arguments() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset LIST_ACCOUNTS UPDATE_DEFAULT_ACCOUNT CUSTOM_ACCOUNT_NAME NEW_ACCOUNT_NAME DELETE_ACCOUNT_NAME ACCOUNT_ONLY_RUN
    unset FOLDERNAME LOCAL_INPUT_ARRAY ID_INPUT_ARRAY CONTINUE_WITH_NO_INPUT
    unset PARALLEL NO_OF_PARALLEL_JOBS SHARE SHARE_ROLE SHARE_EMAIL OVERWRITE SKIP_DUPLICATES DESCRIPTION SKIP_SUBDIRS ROOTDIR QUIET
    unset VERBOSE VERBOSE_PROGRESS DEBUG LOG_FILE_ID CURL_SPEED RETRY
    export CURL_PROGRESS="-s" EXTRA_LOG=":" CURL_PROGRESS_EXTRA="-s"
    INFO_PATH="${HOME}/.google-drive-upload" CONFIG_INFO="${INFO_PATH}/google-drive-upload.configpath"
    [[ -f ${CONFIG_INFO} ]] && . "${CONFIG_INFO}"
    CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"

    # Configuration variables # Remote gDrive variables
    unset ROOT_FOLDER ROOT_FOLDER_NAME CLIENT_ID CLIENT_SECRET REFRESH_TOKEN ACCESS_TOKEN
    export API_URL="https://www.googleapis.com"
    export API_VERSION="v3" \
        SCOPE="${API_URL}/auth/drive" \
        REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob" \
        TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _check_config() {
        [[ ${1} = default* ]] && export UPDATE_DEFAULT_CONFIG="_update_config"
        { [[ -r ${2} ]] && CONFIG="${2}"; } || {
            printf "Error: Given config file (%s) doesn't exist/not readable,..\n" "${1}" 1>&2 && exit 1
        }
        return 0
    }

    _check_longoptions() {
        [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" &&
            exit 1
        return 0
    }

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help) _usage ;;
            -D | --debug) DEBUG="true" && export DEBUG ;;
            --info) _version_info ;;
            -a | --account)
                _check_longoptions "${1}" "${2}"
                export CUSTOM_ACCOUNT_NAME="${2/default=/}" && shift
                [[ ${2} = default* ]] && export UPDATE_DEFAULT_ACCOUNT="_update_config"
                ;;
            -la | --list-account) export LIST_ACCOUNTS="true" ;;
            # this flag is preferred over --account
            -ca | --create-account)
                _check_longoptions "${1}" "${2}"
                export NEW_ACCOUNT_NAME="${2}" && shift
                ;;
            -da | --delete-account)
                _check_longoptions "${1}" "${2}"
                export DELETE_ACCOUNT_NAME="${2}" && shift
                ;;
            -c | -C | --create-dir)
                _check_longoptions "${1}" "${2}"
                FOLDERNAME="${2}" && shift
                ;;
            -r | --root-dir)
                _check_longoptions "${1}" "${2}"
                ROOTDIR="${2/default=/}"
                [[ ${2} = default* ]] && UPDATE_DEFAULT_ROOTDIR="_update_config"
                shift
                ;;
            -z | --config)
                _check_longoptions "${1}" "${2}"
                _check_config "${2}" "${2/default=/}"
                shift
                ;;
            -i | --save-info)
                _check_longoptions "${1}" "${2}"
                export LOG_FILE_ID="${2}" && shift
                ;;
            -s | --skip-subdirs) export SKIP_SUBDIRS="true" ;;
            -p | --parallel)
                _check_longoptions "${1}" "${2}"
                NO_OF_PARALLEL_JOBS="${2}"
                if [[ ${2} -gt 0 ]]; then
                    NO_OF_PARALLEL_JOBS="$((NO_OF_PARALLEL_JOBS > 10 ? 10 : NO_OF_PARALLEL_JOBS))"
                else
                    printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                    exit 1
                fi
                export PARALLEL_UPLOAD="parallel" && shift
                ;;
            -o | --overwrite) export OVERWRITE="Overwrite" UPLOAD_MODE="update" ;;
            -d | --skip-duplicates) export SKIP_DUPLICATES="Skip Existing" UPLOAD_MODE="update" ;;
            -desc | --description | --description-all)
                _check_longoptions "${1}" "${2}"
                [[ ${1} = "--description-all" ]] && export DESCRIPTION_ALL="true"
                export DESCRIPTION="${2}" && shift
                ;;
            -f | --file | --folder)
                _check_longoptions "${1}" "${2}"
                LOCAL_INPUT_ARRAY+=("${2}") && shift
                ;;
            -cl | --clone)
                _check_longoptions "${1}" "${2}"
                FINAL_ID_INPUT_ARRAY+=("$(_extract_id "${2}")") && shift
                ;;
            -S | --share)
                SHARE="_share_id"
                EMAIL_REGEX="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
                if [[ -n ${2} && ! ${2} = -* && ${2} =~ ${EMAIL_REGEX} ]]; then
                    SHARE_EMAIL="${2}" && shift && export SHARE_EMAIL
                fi
                SHARE_ROLE="${SHARE_ROLE:-reader}"
                ;;
            -[Ss][Mm] | --share-mode)
                _check_longoptions "${1}" "${2}"
                case "${2}" in
                    r | read*) SHARE_ROLE="reader" ;;
                    w | write*) SHARE_ROLE="writer" ;;
                    c | comment*) SHARE_ROLE="commenter" ;;
                    *)
                        printf "%s\n" "Invalid share mode given ( ${2} ). Supported values are r or reader / w or writer / c or commenter." &&
                            exit 1
                        ;;
                esac
                SHARE="_share_id"
                shift
                ;;
            --speed)
                _check_longoptions "${1}" "${2}"
                regex='^([0-9]+)([k,K]|[m,M]|[g,G])+$'
                if [[ ${2} =~ ${regex} ]]; then
                    export CURL_SPEED="--limit-rate ${2}" && shift
                else
                    printf "Error: Wrong speed limit format, supported formats: 1K , 1M and 1G\n" 1>&2
                    exit 1
                fi
                ;;
            -R | --retry)
                _check_longoptions "${1}" "${2}"
                if [[ ${2} -gt 0 ]]; then
                    export RETRY="${2}" && shift
                else
                    printf "Error: -R/--retry only takes positive integers as arguments, min = 1, max = infinity.\n"
                    exit 1
                fi
                ;;
            -in | --include)
                _check_longoptions "${1}" "${2}"
                INCLUDE_FILES="${INCLUDE_FILES} -name '${2}' " && shift
                ;;
            -ex | --exclude)
                _check_longoptions "${1}" "${2}"
                EXCLUDE_FILES="${EXCLUDE_FILES} ! -name '${2}' " && shift
                ;;
            --hide) HIDE_INFO=":" ;;
            -q | --quiet) export QUIET="_print_center_quiet" ;;
            -v | --verbose) export VERBOSE="true" ;;
            -V | --verbose-progress) export VERBOSE_PROGRESS="true" ;;
            --skip-internet-check) SKIP_INTERNET_CHECK=":" ;;
            '') shorthelp ;;
            *) # Check if user meant it to be a flag
                if [[ ${1} = -* ]]; then
                    [[ ${GUPLOAD_INSTALLED_WITH} = script ]] && {
                        case "${1}" in
                            -u | --update)
                                _check_debug && _update && { exit 0 || exit 1; }
                                ;;
                            --uninstall)
                                _check_debug && _update uninstall && { exit 0 || exit 1; }
                                ;;
                        esac
                    }
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    if [[ ${1} =~ (drive.google.com|docs.google.com) ]]; then
                        FINAL_ID_INPUT_ARRAY+=("$(_extract_id "${1}")")
                    else
                        # If no "-" is detected in 1st arg, it adds to input
                        LOCAL_INPUT_ARRAY+=("${1}")
                    fi
                fi
                ;;
        esac
        shift
    done

    _check_debug

    [[ -n ${VERBOSE_PROGRESS} ]] && unset VERBOSE && export CURL_PROGRESS=""
    [[ -n ${QUIET} ]] && export CURL_PROGRESS="-s"

    # create info path folder, can be missing if gupload was not installed with install.sh
    mkdir -p "${INFO_PATH}"

    unset Aseen && declare -A Aseen
    for input in "${LOCAL_INPUT_ARRAY[@]}"; do
        { [[ ${Aseen[${input}]} ]] && continue; } || Aseen[${input}]=x
        { [[ -r ${input} ]] && FINAL_LOCAL_INPUT_ARRAY+=("${input}"); } || {
            { "${QUIET:-_print_center}" 'normal' "[ Error: Invalid Input - ${input} ]" "=" && printf "\n"; } 1>&2
            continue
        }
    done

    # handle account related flags here as we want to use the flags independenlty even with no normal valid inputs
    # delete account, --delete-account flag
    # TODO: add support for deleting multiple accounts
    [[ -n ${DELETE_ACCOUNT_NAME} ]] && _delete_account "${DELETE_ACCOUNT_NAME}"
    # list all configured accounts, --list-accounts flag
    [[ -n ${LIST_ACCOUNTS} ]] && _all_accounts

    # If no input, then check if either -C option was used.
    [[ -z ${FINAL_LOCAL_INPUT_ARRAY[*]:-${FINAL_ID_INPUT_ARRAY[*]:-${FOLDERNAME:-}}} ]] && {
        # if any account related option was used then don't show short help
        [[ -z ${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-${NEW_ACCOUNT_NAME}}} ]] && _short_help
        # exit right away if --list-accounts or --delete-account flag was used
        [[ -n ${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-}} ]] && exit 0
        # don't exit right away when new account is created but also let the rootdir stuff execute
        [[ -n ${NEW_ACCOUNT_NAME} ]] && CONTINUE_WITH_NO_INPUT="true"
    }

    return 0
}

###################################################
# Setup root directory where all file/folders will be uploaded/updated
# Globals: 5 variables, 6 functions
#   Variables - ROOTDIR, ROOT_FOLDER, UPDATE_DEFAULT_ROOTDIR, CONFIG, QUIET
#   Functions - _print_center, _drive_info, _extract_id, _update_config, _json_value, _set_value
# Arguments: None
# Result: read description
#   If root id not found then print message and exit
#   Update config with root id and root id name if specified
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#use-read-as-an-alternative-to-the-sleep-command
###################################################
_setup_root_dir() {
    _check_root_id() {
        declare json rootid
        json="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "id")"
        if ! rootid="$(_json_value id 1 1 <<< "${json}")"; then
            { [[ ${json} =~ "File not found" ]] && "${QUIET:-_print_center}" "justify" "Given root folder" " ID/URL invalid." "=" 1>&2; } || {
                printf "%s\n" "${json}" 1>&2
            }
            return 1
        fi
        ROOT_FOLDER="${rootid}"
        "${1:-:}" "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER" "${ROOT_FOLDER}" "${CONFIG}" || return 1
        return 0
    }
    _check_root_id_name() {
        ROOT_FOLDER_NAME="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "name" | _json_value name || :)"
        "${1:-:}" "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER_NAME" "${ROOT_FOLDER_NAME}" "${CONFIG}" || return 1
        return 0
    }

    _set_value indirect ROOT_FOLDER "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER"
    _set_value indirect ROOT_FOLDER_NAME "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER_NAME"

    if [[ -n ${ROOTDIR:-} ]]; then
        ROOT_FOLDER="${ROOTDIR}" && { _check_root_id "${UPDATE_DEFAULT_ROOTDIR}" || return 1; } && unset ROOT_FOLDER_NAME
    elif [[ -z ${ROOT_FOLDER} ]]; then
        { [[ -t 1 ]] && "${QUIET:-_print_center}" "normal" "Enter root folder ID or URL, press enter for default ( root )" " " && printf -- "-> " &&
            read -r ROOT_FOLDER && [[ -n ${ROOT_FOLDER} ]] && { _check_root_id _update_config || return 1; }; } || {
            ROOT_FOLDER="root"
            _update_config "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER" "${ROOT_FOLDER}" "${CONFIG}" || return 1
        }
    elif [[ -z ${ROOT_FOLDER_NAME} ]]; then
        _check_root_id_name _update_config || return 1 # update default root folder name if not available
    fi

    # fetch root folder name if rootdir different than default
    [[ -z ${ROOT_FOLDER_NAME} ]] && { _check_root_id_name "${UPDATE_DEFAULT_ROOTDIR}" || return 1; }

    return 0
}

###################################################
# Setup Workspace folder
# Check if the given folder exists in google drive.
# If not then the folder is created in google drive under the configured root folder.
# Globals: 2 variables, 3 functions
#   Variables - FOLDERNAME, ROOT_FOLDER
#   Functions - _create_directory, _drive_info, _json_value
# Arguments: None
# Result: Read Description
###################################################
_setup_workspace() {
    if [[ -z ${FOLDERNAME} ]]; then
        WORKSPACE_FOLDER_ID="${ROOT_FOLDER}"
        WORKSPACE_FOLDER_NAME="${ROOT_FOLDER_NAME}"
    else
        WORKSPACE_FOLDER_ID="$(_create_directory "${FOLDERNAME}" "${ROOT_FOLDER}")" ||
            { printf "%s\n" "${WORKSPACE_FOLDER_ID}" 1>&2 && return 1; }
        WORKSPACE_FOLDER_NAME="$(_drive_info "${WORKSPACE_FOLDER_ID}" name | _json_value name 1 1)" ||
            { printf "%s\n" "${WORKSPACE_FOLDER_NAME}" 1>&2 && return 1; }
    fi
    return 0
}

###################################################
# Process all the values in "${FINAL_LOCAL_INPUT_ARRAY[@]}" & "${FINAL_ID_INPUT_ARRAY[@]}"
# Globals: 22 variables, 17 functions
#   Variables - FINAL_LOCAL_INPUT_ARRAY ( array ), ACCESS_TOKEN, VERBOSE, VERBOSE_PROGRESS
#               WORKSPACE_FOLDER_ID, UPLOAD_MODE, SKIP_DUPLICATES, OVERWRITE, SHARE,
#               UPLOAD_STATUS, COLUMNS, API_URL, API_VERSION, TOKEN_URL, LOG_FILE_ID
#               FILE_ID, FILE_LINK, FINAL_ID_INPUT_ARRAY ( array )
#               PARALLEL_UPLOAD, QUIET, NO_OF_PARALLEL_JOBS, TMPFILE, SHARE_ROLE
#   Functions - _print_center, _clear_line, _newline, _support_ansi_escapes, _print_center_quiet
#               _upload_file, _share_id, _is_terminal, _dirname,
#               _create_directory, _json_value, _url_encode, _check_existing_file, _bytes_to_human
#               _clone_file, _get_access_token_and_update, _get_rootdir_id
# Arguments: None
# Result: Upload/Clone all the input files/folders, if a folder is empty, print Error message.
###################################################
_process_arguments() {
    # on successful uploads
    _share_and_print_link() {
        "${SHARE:-:}" "${1:-}" "${SHARE_ROLE}" "${SHARE_EMAIL}"
        [[ -z ${HIDE_INFO} ]] && {
            _print_center "justify" "DriveLink" "${SHARE:+ (SHARED[${SHARE_ROLE:0:1}])}" "-"
            _support_ansi_escapes && [[ ${COLUMNS} -gt 45 ]] && _print_center "normal" "↓ ↓ ↓" ' '
            "${QUIET:-_print_center}" "normal" "https://drive.google.com/open?id=${1:-}" " "
        }
        return 0
    }

    for input in "${FINAL_LOCAL_INPUT_ARRAY[@]}"; do
        # Check if the argument is a file or a directory.
        if [[ -f ${input} ]]; then
            # export DESCRIPTION_FILE, used for descriptions in _upload_file function
            export DESCRIPTION_FILE="${DESCRIPTION}"

            _print_center "justify" "Given Input" ": FILE" "="
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            _upload_file_main noparse "${input}" "${WORKSPACE_FOLDER_ID}"
            if [[ ${RETURN_STATUS} = 1 ]]; then
                _share_and_print_link "${FILE_ID}"
                printf "\n"
            else
                for _ in 1 2; do _clear_line 1; done && continue
            fi
        elif [[ -d ${input} ]]; then
            input="$(cd "${input}" && pwd)" || return 1 # to handle _dirname when current directory (.) is given as input.
            unset EMPTY                                 # Used when input folder is empty

            # export DESCRIPTION_FILE only if DESCRIPTION_ALL var is available, used for descriptions in _upload_file function
            export DESCRIPTION_FILE="${DESCRIPTION_ALL:+${DESCRIPTION}}"

            _print_center "justify" "Given Input" ": FOLDER" "-"
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            FOLDER_NAME="${input##*/}" && "${EXTRA_LOG}" "justify" "Folder: ${FOLDER_NAME}" "="

            NEXTROOTDIRID="${WORKSPACE_FOLDER_ID}"

            "${EXTRA_LOG}" "justify" "Processing folder.." "-"

            [[ -z ${SKIP_SUBDIRS} ]] && "${EXTRA_LOG}" "justify" "Indexing subfolders.." "-"
            # Do not create empty folders during a recursive upload. Use of find in this section is important.
            mapfile -t DIRNAMES <<< "$(find "${input}" -type d -not -empty)"
            NO_OF_FOLDERS="${#DIRNAMES[@]}" && NO_OF_SUB_FOLDERS="$((NO_OF_FOLDERS - 1))"
            [[ -z ${SKIP_SUBDIRS} ]] && _clear_line 1
            [[ ${NO_OF_SUB_FOLDERS} = 0 ]] && SKIP_SUBDIRS="true"

            "${EXTRA_LOG}" "justify" "Indexing files.." "-"
            mapfile -t FILENAMES <<< "$(_tmp='find "'${input}'" -type f -name "*" '${INCLUDE_FILES}' '${EXCLUDE_FILES}'' && eval "${_tmp}")"
            _clear_line 1

            # Skip the sub folders and find recursively all the files and upload them.
            if [[ -n ${SKIP_SUBDIRS} ]]; then
                if [[ -n ${FILENAMES[0]} ]]; then
                    for _ in 1 2; do _clear_line 1; done
                    NO_OF_FILES="${#FILENAMES[@]}"

                    "${QUIET:-_print_center}" "justify" "Folder: ${FOLDER_NAME} " "| ${NO_OF_FILES} File(s)" "=" && printf "\n"
                    "${EXTRA_LOG}" "justify" "Creating folder.." "-"
                    { ID="$(_create_directory "${input}" "${NEXTROOTDIRID}")" && export ID; } ||
                        { "${QUIET:-_print_center}" "normal" "Folder creation failed" "-" && printf "%s\n\n\n" "${ID}" 1>&2 && continue; }
                    _clear_line 1 && DIRIDS="${ID}"

                    [[ -z ${PARALLEL_UPLOAD:-${VERBOSE:-${VERBOSE_PROGRESS}}} ]] && _newline "\n"
                    _upload_folder "${PARALLEL_UPLOAD:-normal}" noparse "$(printf "%s\n" "${FILENAMES[@]}")" "${ID}"
                    [[ -n ${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}} ]] && _newline "\n\n"
                else
                    for _ in 1 2; do _clear_line 1; done && EMPTY=1
                fi
            else
                if [[ -n ${FILENAMES[0]} ]]; then
                    for _ in 1 2; do _clear_line 1; done
                    NO_OF_FILES="${#FILENAMES[@]}"
                    "${QUIET:-_print_center}" "justify" "${FOLDER_NAME} " "| ${NO_OF_FILES} File(s) | ${NO_OF_SUB_FOLDERS} Sub-folders" "="

                    _newline "\n" && "${EXTRA_LOG}" "justify" "Creating Folder(s).." "-" && _newline "\n"
                    unset status DIRIDS
                    for dir in "${DIRNAMES[@]}"; do
                        [[ -n ${status} ]] && __dir="$(_dirname "${dir}")" &&
                            __temp="$(printf "%s\n" "${DIRIDS}" | grep -F "|:_//_:|${__dir}|:_//_:|")" &&
                            NEXTROOTDIRID="${__temp%%"|:_//_:|${__dir}|:_//_:|"}"

                        NEWDIR="${dir##*/}" && _print_center "justify" "Name: ${NEWDIR}" "-" 1>&2
                        ID="$(_create_directory "${NEWDIR}" "${NEXTROOTDIRID}")" ||
                            { "${QUIET:-_print_center}" "normal" "Folder creation failed" "-" && printf "%s\n\n\n" "${ID}" 1>&2 && continue; }

                        # Store sub-folder directory IDs and it's path for later use.
                        DIRIDS+="${ID}|:_//_:|${dir}|:_//_:|"$'\n'

                        for _ in 1 2; do _clear_line 1 1>&2; done
                        "${EXTRA_LOG}" "justify" "Status" ": $((status += 1)) / ${NO_OF_FOLDERS}" "=" 1>&2
                    done && export DIRIDS

                    _clear_line 1

                    _upload_folder "${PARALLEL_UPLOAD:-normal}" parse "$(printf "%s\n" "${FILENAMES[@]}")"
                    [[ -n ${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}} ]] && _newline "\n\n"
                else
                    for _ in 1 2 3; do _clear_line 1; done && EMPTY=1
                fi
            fi
            if [[ ${EMPTY} != 1 ]]; then
                [[ -z ${VERBOSE:-${VERBOSE_PROGRESS}} ]] && for _ in 1 2; do _clear_line 1; done

                FOLDER_ID="$(: "${DIRIDS%%$'\n'*}" && printf "%s\n" "${_/"|:_//_:|"*/}")"

                [[ ${SUCCESS_STATUS} -gt 0 ]] && _share_and_print_link "${FOLDER_ID}"

                _newline "\n"
                [[ ${SUCCESS_STATUS} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Total Files " "Uploaded: ${SUCCESS_STATUS}" "="
                [[ ${ERROR_STATUS} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Total Files " "Failed: ${ERROR_STATUS}" "=" && {
                    # If running inside a terminal, then check if failed files are more than 25, if not, then print, else save in a log file
                    if [[ -t 1 ]]; then
                        { [[ ${ERROR_STATUS} -le 25 ]] && printf "%s\n" "${ERROR_FILES}"; } || {
                            epoch_time="$(printf "%(%s)T\\n" "-1")" log_file_name="${0##*/}_${FOLDER_NAME}_${epoch_time}.failed"
                            # handle in case the vivid random file name was already there
                            i=0 && until ! [[ -f ${log_file_name} ]]; do
                                : $((i += 1)) && log_file_name="${0##*/}_${FOLDER_NAME}_$((epoch_time + i)).failed"
                            done
                            printf "%s\n%s\n%s\n\n%s\n%s\n" \
                                "Folder name: ${FOLDER_NAME} | Folder ID: ${FOLDER_ID}" \
                                "Run this command to retry the failed uploads:" \
                                "    ${0##*/} --skip-duplicates \"${input}\" --root-dir \"${NEXTROOTDIRID}\" ${SKIP_SUBDIRS:+-s} ${PARALLEL_UPLOAD:+--parallel} ${PARALLEL_UPLOAD:+${NO_OF_PARALLEL_JOBS}}" \
                                "Failed files:" \
                                "${ERROR_FILES}" >> "${log_file_name}"
                            printf "%s\n" "To see the failed files, open \"${log_file_name}\""
                            printf "%s\n" "To retry the failed uploads only, use -d / --skip-duplicates flag. See log file for more help."

                        }
                        # if not running inside a terminal, print it all
                    else
                        printf "%s\n" "${ERROR_FILES}"
                    fi
                }
                printf "\n"
            else
                for _ in 1 2 3; do _clear_line 1; done
                "${QUIET:-_print_center}" 'justify' "Empty Folder" ": ${FOLDER_NAME}" "=" 1>&2
                printf "\n"
            fi
        fi
    done

    unset Aseen && declare -A Aseen
    for gdrive_id in "${FINAL_ID_INPUT_ARRAY[@]}"; do
        { [[ ${Aseen[${gdrive_id}]} ]] && continue; } || Aseen[${gdrive_id}]=x
        _print_center "justify" "Given Input" ": ID" "="
        "${EXTRA_LOG}" "justify" "Checking if id exists.." "-"
        json="$(_drive_info "${gdrive_id}" "name,mimeType,size" || :)"
        if ! _json_value code 1 1 <<< "${json}" 2>| /dev/null 1>&2; then
            type="$(_json_value mimeType 1 1 <<< "${json}" || :)"
            name="$(_json_value name 1 1 <<< "${json}" || :)"
            size="$(_json_value size 1 1 <<< "${json}" || :)"
            for _ in 1 2; do _clear_line 1; done
            if [[ ${type} =~ folder ]]; then
                # export DESCRIPTION_FILE only if DESCRIPTION_ALL var is available, used for descriptions in _clone_file function
                export DESCRIPTION_FILE="${DESCRIPTION_ALL+:${DESCRIPTION}}"

                "${QUIET:-_print_center}" "justify" "Folder not supported." "=" 1>&2 && _newline "\n" 1>&2 && continue
                ## TODO: Add support to clone folders
            else
                # export DESCRIPTION_FILE, used for descriptions in _clone_file function
                export DESCRIPTION_FILE="${DESCRIPTION}"

                _print_center "justify" "Given Input" ": File ID" "="
                _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
                _clone_file "${UPLOAD_MODE:-create}" "${gdrive_id}" "${WORKSPACE_FOLDER_ID}" "${name}" "${size}" ||
                    { for _ in 1 2; do _clear_line 1; done && continue; }
            fi
            _share_and_print_link "${FILE_ID}"
            printf "\n"
        else
            _clear_line 1
            "${QUIET:-_print_center}" "justify" "File ID (${HIDE_INFO:-gdrive_id})" " invalid." "=" 1>&2
            printf "\n"
        fi
    done
    return 0
}

main() {
    [[ $# = 0 ]] && _short_help

    [[ -z ${SELF_SOURCE} ]] && {
        export UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}"
        { . "${UTILS_FOLDER}"/auth-utils.bash && . "${UTILS_FOLDER}"/common-utils.bash && . "${UTILS_FOLDER}"/drive-utils.bash && . "${UTILS_FOLDER}"/upload-utils.bash; } ||
            { printf "Error: Unable to source util files.\n" && exit 1; }
    }

    _check_bash_version && set -o errexit -o noclobber -o pipefail

    _setup_arguments "${@}" || exit 1
    "${SKIP_INTERNET_CHECK:-_check_internet}" || exit 1

    { { command -v mktemp 1>| /dev/null && TMPFILE="$(mktemp -u)"; } ||
        TMPFILE="${PWD}/.$(_t="$(printf "%(%s)T\\n" "-1")" && printf "%s\n" "$((_t * _t))").LOG"; } || exit 1
    export TMPFILE

    _cleanup() {
        # unhide the cursor if hidden
        [[ -n ${SUPPORT_ANSI_ESCAPES} ]] && printf "\e[?25h\e[?7h"
        {
            [[ -f ${TMPFILE}_ACCESS_TOKEN ]] && {
                # update the config with latest ACCESS_TOKEN and ACCESS_TOKEN_EXPIRY only if changed
                . "${TMPFILE}_ACCESS_TOKEN"
                [[ ${INITIAL_ACCESS_TOKEN} = "${ACCESS_TOKEN}" ]] || {
                    _update_config "ACCOUNT_${ACCOUNT_NAME}_ACCESS_TOKEN" "${ACCESS_TOKEN}" "${CONFIG}"
                    _update_config "ACCOUNT_${ACCOUNT_NAME}_ACCESS_TOKEN_EXPIRY" "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"
                }
            } || : 1>| /dev/null

            # grab all chidren processes of access token service
            # https://askubuntu.com/a/512872
            [[ -n ${ACCESS_TOKEN_SERVICE_PID} ]] && {
                token_service_pids="$(ps --ppid="${ACCESS_TOKEN_SERVICE_PID}" -o pid=)"
                # first kill parent id, then children processes
                kill "${ACCESS_TOKEN_SERVICE_PID}"
            } || : 1>| /dev/null

            # grab all script children pids
            script_children_pids="$(ps --ppid="${MAIN_PID}" -o pid=)"

            # kill all grabbed children processes
            # shellcheck disable=SC2086
            kill ${token_service_pids} ${script_children_pids} 1>| /dev/null

            rm -f "${TMPFILE:?}"*

            export abnormal_exit && if [[ -n ${abnormal_exit} ]]; then
                printf "\n\n%s\n" "Script exited manually."
                kill -- -$$ &
            else
                { _cleanup_config "${CONFIG}" && [[ ${GUPLOAD_INSTALLED_WITH} = script ]] && _auto_update; } 1>| /dev/null &
            fi
        } 2>| /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1"; exit' INT TERM
    trap '_cleanup' EXIT
    trap '' TSTP # ignore ctrl + z

    export MAIN_PID="$$"

    START="$(printf "%(%s)T\\n" "-1")"

    "${EXTRA_LOG}" "justify" "Checking credentials.." "-"
    { _check_credentials && _clear_line 1; } ||
        { "${QUIET:-_print_center}" "normal" "[ Error: Credentials checking failed ]" "=" && exit 1; }
    "${QUIET:-_print_center}" "normal" " Account: ${ACCOUNT_NAME} " "="

    "${EXTRA_LOG}" "justify" "Checking root dir.." "-"
    { _setup_root_dir && _clear_line 1; } ||
        { "${QUIET:-_print_center}" "normal" "[ Error: Rootdir setup failed ]" "=" && exit 1; }
    _print_center "justify" "Root dir properly configured." "="

    # only execute next blocks if there was some input
    [[ -n ${CONTINUE_WITH_NO_INPUT} ]] && exit 0

    "${EXTRA_LOG}" "justify" "Checking Workspace Folder.." "-"
    { _setup_workspace && for _ in 1 2; do _clear_line 1; done; } ||
        { "${QUIET:-_print_center}" "normal" "[ Error: Workspace setup failed ]" "=" && exit 1; }
    _print_center "justify" "Workspace Folder: ${WORKSPACE_FOLDER_NAME}" "="
    _print_center "normal" " ${WORKSPACE_FOLDER_ID} " "-" && _newline "\n"

    # hide the cursor if ansi escapes are supported
    [[ -n ${SUPPORT_ANSI_ESCAPES} ]] && printf "\e[?25l"

    _process_arguments

    END="$(printf "%(%s)T\\n" "-1")"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds " "="
}

{ [[ -z ${SOURCED_GUPLOAD} ]] && main "${@}"; } || :
