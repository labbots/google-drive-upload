#!/usr/bin/env bash
# Upload a file to Google Drive
# shellcheck source=/dev/null

_usage() {
    printf "
The script can be used to upload file/directory to google drive.\n
Usage:\n %s [options.. ] <filename> <foldername>\n
Foldername argument is optional. If not provided, the file will be uploaded to preconfigured google drive.\n
File name argument is optional if create directory option is used.\n
Options:\n
  -C | --create-dir <foldername> - option to create directory. Will provide folder id. Can be used to provide input folder, see README.\n
  -r | --root-dir <google_folderid> or <google_folder_url> - google folder ID/URL to which the file/directory is going to upload.
      If you want to change the default value, then use this format, -r/--root-dir default=root_folder_id/root_folder_url\n
  -s | --skip-subdirs - Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder, use this along with -p/--parallel option to speed up the uploads.\n
  -p | --parallel <no_of_files_to_parallely_upload> - Upload multiple files in parallel, Max value = 10.\n
  -f | --[file|folder] - Specify files and folders explicitly in one command, use multiple times for multiple folder/files. See README for more use of this command.\n
  -cl | --clone - Upload a gdrive file without downloading, require accessible gdrive link or id as argument.\n
  -o | --overwrite - Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders.\n
  -d | --skip-duplicates - Do not upload the files with the same name, if already present in the root folder/input folder, also works with recursive folders.\n
  -S | --share <optional_email_address>- Share the uploaded input file/folder, grant reader permission to provided email address or to everyone with the shareable link.\n
  --speed 'speed' - Limit the download speed, supported formats: 1K, 1M and 1G.\n
  -i | --save-info <file_to_save_info> - Save uploaded files info to the given filename.\n
  -z | --config <config_path> - Override default config file with custom config file.\nIf you want to change default value, then use this format -z/--config default=default=your_config_file_path.\n
  -R | --retry 'num of retries' - Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.\n
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -v | --verbose - Display detailed message (only for non-parallel uploads).\n
  -V | --verbose-progress - Display detailed message and detailed upload progress(only for non-parallel uploads).\n
  --skip-internet-check - Do not check for internet connection, recommended to use in sync jobs.\n
  -u | --update - Update the installed script in your system.\n
  --info - Show detailed info, only if script is installed system wide.\n
  -U | --uninstall - Uninstall script, remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n" "${0##*/}"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Automatic updater, only update if script is installed system wide.
# Globals: 1 variable, 2 functions
#    INFO_FILE | _update, _update_config
# Arguments: None
# Result: On
#   Update if AUTO_UPDATE_INTERVAL + LAST_UPDATE_TIME less than printf "%(%s)T\\n" "-1"
###################################################
_auto_update() {
    (
        [[ -w ${INFO_FILE} ]] && . "${INFO_FILE}" && command -v "${COMMAND_NAME}" 2> /dev/null 1>&2 && {
            [[ $((LAST_UPDATE_TIME + AUTO_UPDATE_INTERVAL)) -lt $(printf "%(%s)T\\n" "-1") ]] &&
                _update 2>&1 1>| "${INFO_PATH}/update.log" &&
                _update_config LAST_UPDATE_TIME "$(printf "%(%s)T\\n" "-1")" "${INFO_FILE}"
        }
    ) 2> /dev/null 1>&2 &
    return 0
}

###################################################
# Install/Update/uninstall the script.
# Globals: 3 variables
#   Varibles - HOME, REPO, TYPE_VALUE
# Arguments: 1
#   ${1} = uninstall or update
# Result: On
#   ${1} = nothing - Update the script if installed, otherwise install.
#   ${1} = uninstall - uninstall the script
###################################################
_update() {
    declare job="${1:-update}"
    [[ ${job} =~ uninstall ]] && job_string="--uninstall"
    _print_center "justify" "Fetching ${job} script.." "-"
    [[ -w ${INFO_FILE} ]] && . "${INFO_FILE}"
    declare repo="${REPO:-labbots/google-drive-upload}" type_value="${TYPE_VALUE:-latest}"
    { [[ ${TYPE:-} != branch ]] && type_value="$(_get_latest_sha release "${type_value}" "${repo}")"; } || :
    if script="$(curl --compressed -Ls "https://raw.githubusercontent.com/${repo}/${type_value}/install.sh")"; then
        _clear_line 1
        printf "%s\n" "${script}" | bash -s -- ${job_string:-} --skip-internet-check
    else
        _clear_line 1
        _print_center "justify" "Error: Cannot download ${job} script." "=" 1>&2
        exit 1
    fi
    exit "${?}"
}

###################################################
# Print the contents of info file if scipt is installed system wide.
# Path is INFO_FILE="${HOME}/.google-drive-upload/google-drive-upload.info"
# Globals: 1 variable
#   HOME
# Arguments: None
# Result: read description
###################################################
_version_info() {
    if [[ -r ${INFO_FILE} ]]; then
        printf "%s\n" "$(< "${INFO_FILE}")"
    else
        _print_center "justify" "google-drive-upload is not installed system wide." "="
    fi
    exit 0
}

###################################################
# Process all arguments given to the script
# Globals: 1 variable, 1 function
#   Variable - HOME
#   Functions - _short_help
# Arguments: Many
#   ${@} = Flags with argument and file/folder input
# Result: On
#   Success - Set all the variables
#   Error   - Print error message and exit
# Reference:
#   Email Regex - https://stackoverflow.com/a/57295993
###################################################
_setup_arguments() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset FIRST_INPUT FOLDER_INPUT FOLDERNAME LOCAL_INPUT_ARRAY ID_INPUT_ARRAY
    unset PARALLEL NO_OF_PARALLEL_JOBS SHARE SHARE_EMAIL OVERWRITE SKIP_DUPLICATES SKIP_SUBDIRS ROOTDIR QUIET
    unset VERBOSE VERBOSE_PROGRESS DEBUG LOG_FILE_ID CURL_SPEED RETRY
    CURL_PROGRESS="-#" && unset CURL_PROGRESS_EXTRA CURL_PROGRESS_EXTRA_CLEAR EXTRA_LOG EXTRA_LOG_CLEAR
    INFO_PATH="${HOME}/.google-drive-upload" INFO_FILE="${INFO_PATH}/google-drive-upload.info"
    [[ -f "${INFO_PATH}/google-drive-upload.configpath" ]] && CONFIG="$(< "${INFO_PATH}/google-drive-upload.configpath")"
    CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"

    # Grab the first and second argument ( if 1st argument isn't a drive url ) and shift, only if ${1} doesn't contain -.
    if [[ ${1} != -* ]]; then
        if [[ ${1} =~ (drive.google.com|docs.google.com) ]]; then
            { FINAL_ID_INPUT_ARRAY=("$(_extract_id "${1}")") && shift && [[ ${1} != -* ]] && FOLDER_INPUT="${1}" && shift; } || :
        else
            { LOCAL_INPUT_ARRAY=("${1}") && shift && [[ ${1} != -* ]] && FOLDER_INPUT="${1}" && shift; } || :
        fi
    fi

    # Configuration variables # Remote gDrive variables
    unset ROOT_FOLDER CLIENT_ID CLIENT_SECRET REFRESH_TOKEN ACCESS_TOKEN
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"
    SCOPE="${API_URL}/auth/drive"
    REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
    TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _check_config() {
        [[ ${1} = default* ]] && UPDATE_DEFAULT_CONFIG="true"
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
            -u | --update) _check_debug && _update ;;
            -U | --uninstall) _check_debug && _update uninstall ;;
            --info) _version_info ;;
            -C | --create-dir)
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
                LOG_FILE_ID="${2}" && shift
                ;;
            -s | --skip-subdirs) SKIP_SUBDIRS="true" ;;
            -p | --parallel)
                _check_longoptions "${1}" "${2}"
                NO_OF_PARALLEL_JOBS="${2}"
                if [[ ${2} -gt 0 ]]; then
                    NO_OF_PARALLEL_JOBS="$((NO_OF_PARALLEL_JOBS > 10 ? 10 : NO_OF_PARALLEL_JOBS))"
                else
                    printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                    exit 1
                fi
                PARALLEL_UPLOAD="parallel" && shift
                ;;
            -o | --overwrite) OVERWRITE="Overwrite" && UPLOAD_MODE="update" ;;
            -d | --skip-duplicates) SKIP_DUPLICATES="Skip Existing" && UPLOAD_MODE="update" ;;
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
                EMAIL_REGEX="^([A-Za-z]+[A-Za-z0-9]*\+?((\.|\-|\_)?[A-Za-z]+[A-Za-z0-9]*)*)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
                [[ -n ${1} && ! ${1} = -* ]] && SHARE_EMAIL="${2}" && {
                    ! [[ ${SHARE_EMAIL} =~ ${EMAIL_REGEX} ]] && printf "\nError: Provided email address for share option is invalid.\n" && exit 1
                    shift
                }
                ;;
            --speed)
                _check_longoptions "${1}" "${2}"
                regex='^([0-9]+)([k,K]|[m,M]|[g,G])+$'
                if [[ ${2} =~ ${regex} ]]; then
                    CURL_SPEED="--limit-rate ${2}" && shift
                else
                    printf "Error: Wrong speed limit format, supported formats: 1K , 1M and 1G\n" 1>&2
                    exit 1
                fi
                ;;
            -R | --retry)
                _check_longoptions "${1}" "${2}"
                if [[ ${2} -gt 0 ]]; then
                    RETRY="${2}" && shift
                else
                    printf "Error: -R/--retry only takes positive integers as arguments, min = 1, max = infinity.\n"
                    exit 1
                fi
                ;;
            -q | --quiet) QUIET="_print_center_quiet" ;;
            -v | --verbose) VERBOSE="true" ;;
            -V | --verbose-progress) VERBOSE_PROGRESS="true" && CURL_PROGRESS="" ;;
            --skip-internet-check) SKIP_INTERNET_CHECK=":" ;;
            '') shorthelp ;;
            *) # Check if user meant it to be a flag
                if [[ ${1} = -* ]]; then
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    if [[ ${1} =~ (drive.google.com|docs.google.com) ]]; then
                        FINAL_ID_INPUT_ARRAY+=("$(_extract_id "${1}")")
                    else
                        # If no "-" is detected in 1st arg, it adds to input
                        LOCAL_INPUT_ARRAY+=("${1}")
                    fi
                    # if the 2nd arg available and doesn't start with "-", then set as folder input
                    # do above only if 3rd arg is either absent or doesn't start with "-"
                    [[ -n ${2:+${2##-*}} && -z ${3:-${FOLDERNAME:-${FOLDER_INPUT}}} ]] && FOLDER_INPUT="${2}" && shift
                fi
                ;;
        esac
        shift
    done

    # Get foldername, prioritise the input given by -C/--create-dir option.
    FOLDERNAME="${FOLDERNAME:-${FOLDER_INPUT}}"

    [[ -n ${VERBOSE_PROGRESS:+${VERBOSE}} ]] && unset "${VERBOSE}"

    [[ -n ${QUIET} ]] && CURL_PROGRESS="-s"

    _check_debug

    { [[ ${CURL_PROGRESS} = "-#" ]] && CURL_PROGRESS_EXTRA="-#" && CURL_PROGRESS_EXTRA_CLEAR="_clear_line"; } || CURL_PROGRESS_EXTRA="-s"

    unset Aseen && declare -A Aseen
    for input in "${LOCAL_INPUT_ARRAY[@]}"; do
        { [[ ${Aseen[${input}]} ]] && continue; } || Aseen[${input}]=x
        { [[ -r ${input} ]] && FINAL_LOCAL_INPUT_ARRAY+=("${input}"); } || {
            { "${QUIET:-_print_center}" 'normal' "[ Error: Invalid Input - ${input} ]" "=" && printf "\n"; } 1>&2
            continue
        }
    done

    # If no input, then check if -C option was used or not.
    [[ -z ${FINAL_LOCAL_INPUT_ARRAY[*]:-${FINAL_ID_INPUT_ARRAY[*]:-${FOLDERNAME}}} ]] && _short_help

    return 0
}

###################################################
# Setup Temporary file name for writing, uses mktemp, current dir as fallback
# Used in parallel folder uploads progress
# Globals: 2 variables
#   PWD ( optional ), RANDOM ( optional )
# Arguments: None
# Result: read description
###################################################
_setup_tempfile() {
    { type -p mktemp 2> /dev/null 1>&2 && TMPFILE="$(mktemp -u)"; } || TMPFILE="${PWD}/$((RANDOM * 2)).LOG"
    return 0
}

###################################################
# Check Oauth credentials and create/update config file
# Client ID, Client Secret, Refesh Token and Access Token
# Globals: 10 variables, 3 functions
#   Variables - API_URL, API_VERSION, TOKEN URL,
#               CONFIG, UPDATE_DEFAULT_CONFIG, INFO_PATH,
#               CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN and ACCESS_TOKEN
#   Functions - _update_config, _json_value and _print_center
# Arguments: None
# Result: read description
###################################################
_check_credentials() {
    # Config file is created automatically after first run
    [[ -r ${CONFIG} ]] &&
        . "${CONFIG}" && [[ -n ${UPDATE_DEFAULT_CONFIG} ]] && printf "%s\n" "${CONFIG}" >| "${INFO_PATH}/google-drive-upload.configpath"

    until [[ -n ${CLIENT_ID} ]]; do
        [[ -n ${client_id} ]] && _clear_line 1
        printf "Client ID: " && read -r CLIENT_ID && client_id=1
    done && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"

    until [[ -n ${CLIENT_SECRET} ]]; do
        [[ -n ${client_secret} ]] && _clear_line 1
        printf "Client Secret: " && read -r CLIENT_SECRET && client_secret=1
    done && _update_config CLIENT_SECRET "${CLIENT_SECRET}" "${CONFIG}"

    # Method to regenerate access_token ( also updates in config ).
    # Make a request on https://www.googleapis.com/oauth2/""${API_VERSION}""/tokeninfo?access_token=${ACCESS_TOKEN} url and check if the given token is valid, if not generate one.
    # Requirements: Refresh Token
    _get_token_and_update() {
        RESPONSE="${1:-$(curl --compressed -s -X POST --data "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" "${TOKEN_URL}")}" || :
        if ACCESS_TOKEN="$(_json_value access_token 1 1 <<< "${RESPONSE}")"; then
            _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
            { ACCESS_TOKEN_EXPIRY="$(curl --compressed -s "${API_URL}/oauth2/${API_VERSION}/tokeninfo?access_token=${ACCESS_TOKEN}" | _json_value exp 1 1)" &&
                _update_config ACCESS_TOKEN_EXPIRY "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"; } || { "${QUIET:-_print_center}" "justify" "Error: Couldn't update" " access token expiry." 1>&2 && exit 1; }
        else
            "${QUIET:-_print_center}" "justify" "Error: Something went wrong" ", printing error." 1>&2
            printf "%s\n" "${RESPONSE}" 1>&2
            exit 1
        fi
        return 0
    }

    # Method to obtain refresh_token.
    # Requirements: client_id, client_secret and authorization code.
    [[ -z ${REFRESH_TOKEN} ]] && {
        printf "%b" "If you have a refresh token generated, then type the token, else leave blank and press return key..\n\nRefresh Token: "
        read -r REFRESH_TOKEN && REFRESH_TOKEN="${REFRESH_TOKEN//[[:space:]]/}"
        if [[ -n ${REFRESH_TOKEN} ]]; then
            _get_token_and_update && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
        else
            printf "\nVisit the below URL, tap on allow and then enter the code obtained:\n"
            URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
            printf "%s\n" "${URL}" && printf "%b" "Enter the authorization code: " && read -r CODE
            until [[ -n ${CODE} ]]; do
                [[ -n ${code} ]] && _clear_line 1
                printf "Enter the authorization code: " && read -r -p CODE && code=1
            done
            RESPONSE="$(curl --compressed -s -X POST \
                --data "code=${CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :

            REFRESH_TOKEN="$(_json_value refresh_token 1 1 <<< "${RESPONSE}" || :)"
            _get_token_and_update "${RESPONSE}" && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
        fi
    }

    [[ -z ${ACCESS_TOKEN} || ${ACCESS_TOKEN_EXPIRY} -lt "$(printf "%(%s)T\\n" "-1")" ]] && _get_token_and_update

    return 0
}

###################################################
# Setup root directory where all file/folders will be uploaded/updated
# Globals: 6 variables, 5 functions
#   Variables - ROOTDIR, ROOT_FOLDER, UPDATE_DEFAULT_ROOTDIR, CONFIG, QUIET, ACCESS_TOKEN
#   Functions - _print_center, _drive_info, _extract_id, _update_config, _json_value
# Arguments: 1
#   ${1} = Positive integer ( amount of time in seconds to sleep )
# Result: read description
#   If root id not found then pribt message and exit
#   Update config with root id and root id name if specified
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#use-read-as-an-alternative-to-the-sleep-command
###################################################
_setup_root_dir() {
    _check_root_id() {
        declare json rootid
        json="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "id" "${ACCESS_TOKEN}")"
        if ! rootid="$(_json_value id 1 1 <<< "${json}")"; then
            { [[ ${json} =~ "File not found" ]] && "${QUIET:-_print_center}" "justify" "Given root folder" " ID/URL invalid." "=" 1>&2; } || {
                printf "%s\n" "${json}" 1>&2
            }
            exit 1
        fi
        ROOT_FOLDER="${rootid}"
        "${1:-:}" ROOT_FOLDER "${ROOT_FOLDER}" "${CONFIG}"
        return 0
    }
    _update_root_id_name() {
        ROOT_FOLDER_NAME="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "name" "${ACCESS_TOKEN}" | _json_value name || :)"
        "${1:-:}" ROOT_FOLDER_NAME "${ROOT_FOLDER_NAME}" "${CONFIG}"
        return 0
    }

    [[ -n ${ROOT_FOLDER} && -z ${ROOT_FOLDER_NAME} ]] && _update_root_id_name _update_config

    if [[ -n ${ROOTDIR:-} ]]; then
        ROOT_FOLDER="${ROOTDIR}" && _check_root_id "${UPDATE_DEFAULT_ROOTDIR}"
    elif [[ -z ${ROOT_FOLDER} ]]; then
        read -r -p "Root Folder ID or URL (Default: root) - Press enter for default: " ROOT_FOLDER
        ROOT_FOLDER="${ROOT_FOLDER}"
        { [[ -n ${ROOT_FOLDER} ]] && _check_root_id; } || {
            ROOT_FOLDER="root"
            _update_config ROOT_FOLDER "${ROOT_FOLDER}" "${CONFIG}"
        }
    fi

    [[ -z ${ROOT_FOLDER_NAME} ]] && _update_root_id_name "${UPDATE_DEFAULT_ROOTDIR}"

    return 0
}

###################################################
# Setup Workspace folder
# Check if the given folder exists in google drive.
# If not then the folder is created in google drive under the configured root folder.
# Globals: 3 variables, 3 functions
#   Variables - FOLDERNAME, ROOT_FOLDER, ACCESS_TOKEN
#   Functions - _create_directory, _drive_info, _json_value
# Arguments: None
# Result: Read Description
###################################################
_setup_workspace() {
    if [[ -z ${FOLDERNAME} ]]; then
        WORKSPACE_FOLDER_ID="${ROOT_FOLDER}"
        WORKSPACE_FOLDER_NAME="${ROOT_FOLDER_NAME}"
    else
        WORKSPACE_FOLDER_ID="$(_create_directory "${FOLDERNAME}" "${ROOT_FOLDER}" "${ACCESS_TOKEN}")" ||
            { printf "%s\n" "${WORKSPACE_FOLDER_ID}" 1>&2 && exit 1; }
        WORKSPACE_FOLDER_NAME="$(_drive_info "${WORKSPACE_FOLDER_ID}" name "${ACCESS_TOKEN}" | _json_value name 1 1)" ||
            { printf "%s\n" "${WORKSPACE_FOLDER_NAME}" 1>&2 && exit 1; }
    fi
    return 0
}

###################################################
# Process all the values in "${FINAL_LOCAL_INPUT_ARRAY[@]}" & "${FINAL_ID_INPUT_ARRAY[@]}"
# Globals: 21 variables, 14 functions
#   Variables - FINAL_LOCAL_INPUT_ARRAY ( array ), ACCESS_TOKEN, VERBOSE, VERBOSE_PROGRESS
#               WORKSPACE_FOLDER_ID, UPLOAD_MODE, SKIP_DUPLICATES, OVERWRITE, SHARE,
#               UPLOAD_STATUS, COLUMNS, API_URL, API_VERSION, LOG_FILE_ID
#               FILE_ID, FILE_LINK, FINAL_ID_INPUT_ARRAY ( array )
#               PARALLEL_UPLOAD, QUIET, NO_OF_PARALLEL_JOBS, TMPFILE
#   Functions - _print_center, _clear_line, _newline, _is_terminal, _print_center_quiet
#               _upload_file, _share_id, _is_terminal, _dirname,
#               _create_directory, _json_value, _url_encode, _check_existing_file, _bytes_to_human
#               _clone_file
# Arguments: None
# Result: Upload/Clone all the input files/folders, if a folder is empty, print Error message.
###################################################
_process_arguments() {
    export API_URL API_VERSION ACCESS_TOKEN LOG_FILE_ID OVERWRITE UPLOAD_MODE SKIP_DUPLICATES CURL_SPEED RETRY UTILS_FOLDER \
        QUIET VERBOSE VERBOSE_PROGRESS CURL_PROGRESS CURL_PROGRESS_EXTRA CURL_PROGRESS_EXTRA_CLEAR COLUMNS EXTRA_LOG EXTRA_LOG_CLEAR PARALLEL_UPLOAD

    export -f _bytes_to_human _dirname _json_value _url_encode _is_terminal _newline _print_center_quiet _print_center _clear_line \
        _check_existing_file _upload_file _upload_file_main _clone_file _collect_file_info _generate_upload_link _upload_file_from_uri _full_upload \
        _normal_logging_upload _error_logging_upload _log_upload_session _remove_upload_session _upload_folder _share_id _gen_final_list

    # on successful uploads
    _share_and_print_link() {
        "${SHARE:-:}" "${1:-}" "${ACCESS_TOKEN}" "${SHARE_EMAIL}"
        _print_center "justify" "DriveLink" "${SHARE:+ (SHARED)}" "-"
        _is_terminal && [[ ${COLUMNS} -gt 45 ]] && _print_center "normal" "↓ ↓ ↓" ' '
        _print_center "normal" "https://drive.google.com/open?id=${1:-}" " "
    }

    for input in "${FINAL_LOCAL_INPUT_ARRAY[@]}"; do
        # Check if the argument is a file or a directory.
        if [[ -f ${input} ]]; then
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
            input="$(cd "${input}" && pwd)" # to handle _dirname when current directory (.) is given as input.
            unset EMPTY                     # Used when input folder is empty

            _print_center "justify" "Given Input" ": FOLDER" "-"
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            FOLDER_NAME="${input##*/}" && _print_center "justify" "Folder: ${FOLDER_NAME}" "="

            NEXTROOTDIRID="${WORKSPACE_FOLDER_ID}"

            _print_center "justify" "Processing folder.." "-"

            # Do not create empty folders during a recursive upload. Use of find in this section is important.
            mapfile -t DIRNAMES <<< "$(find "${input}" -type d -not -empty)"
            NO_OF_FOLDERS="${#DIRNAMES[@]}" && NO_OF_SUB_FOLDERS="$((NO_OF_FOLDERS - 1))" && _clear_line 1
            [[ ${NO_OF_SUB_FOLDERS} = 0 ]] && SKIP_SUBDIRS="true"

            ERROR_STATUS=0 SUCCESS_STATUS=0

            # Skip the sub folders and find recursively all the files and upload them.
            if [[ -n ${SKIP_SUBDIRS} ]]; then
                _print_center "justify" "Indexing files recursively.." "-"
                mapfile -t FILENAMES <<< "$(find "${input}" -type f)"

                if [[ -n ${FILENAMES[0]} ]]; then
                    NO_OF_FILES="${#FILENAMES[@]}"
                    for _ in 1 2; do _clear_line 1; done

                    "${QUIET:-_print_center}" "justify" "Folder: ${FOLDER_NAME} " "| ${NO_OF_FILES} File(s)" "=" && printf "\n"
                    _print_center "justify" "Creating folder.." "-"
                    { ID="$(_create_directory "${input}" "${NEXTROOTDIRID}" "${ACCESS_TOKEN}")" && export ID; } || { printf "%s\n" "${ID}" 1>&2 && return 1; }
                    _clear_line 1 && DIRIDS="${ID}"

                    [[ -z ${PARALLEL_UPLOAD:-${VERBOSE:-${VERBOSE_PROGRESS}}} ]] && _newline "\n"
                    _upload_folder "${PARALLEL_UPLOAD:-normal}" noparse "$(printf "%s\n" "${FILENAMES[@]}")" "${ID}"
                    [[ -n ${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}} ]] && _newline "\n\n"
                else
                    _newline "\n" && EMPTY=1
                fi
            else
                _print_center "justify" "${NO_OF_SUB_FOLDERS} Sub-folders found." "="
                _print_center "justify" "Indexing files.." "="
                mapfile -t FILENAMES <<< "$(find "${input}" -type f)"

                if [[ -n ${FILENAMES[0]} ]]; then
                    NO_OF_FILES="${#FILENAMES[@]}"
                    for _ in 1 2 3; do _clear_line 1; done
                    "${QUIET:-_print_center}" "justify" "${FOLDER_NAME} " "| ${NO_OF_FILES} File(s) | ${NO_OF_SUB_FOLDERS} Sub-folders" "="

                    _newline "\n" && _print_center "justify" "Creating Folder(s).." "-" && _newline "\n"
                    unset status DIRIDS
                    for dir in "${DIRNAMES[@]}"; do
                        [[ -n ${status} ]] && __dir="$(_dirname "${dir}")" &&
                            __temp="$(printf "%s\n" "${DIRIDS}" | grep "|:_//_:|${__dir}|:_//_:|")" &&
                            NEXTROOTDIRID="${__temp%%"|:_//_:|${__dir}|:_//_:|"}"

                        NEWDIR="${dir##*/}" && _print_center "justify" "Name: ${NEWDIR}" "-" 1>&2
                        ID="$(_create_directory "${NEWDIR}" "${NEXTROOTDIRID}" "${ACCESS_TOKEN}")" || { printf "%s\n" "${ID}" 1>&2 && exit 1; }

                        # Store sub-folder directory IDs and it's path for later use.
                        DIRIDS+="${ID}|:_//_:|${dir}|:_//_:|"$'\n'

                        for _ in 1 2; do _clear_line 1 1>&2; done
                        _print_center "justify" "Status" ": $((status += 1)) / ${NO_OF_FOLDERS}" "=" 1>&2
                    done
                    for _ in 1 2; do _clear_line 1; done

                    _print_center "justify" "Preparing to upload.." "-"

                    export DIRIDS && cores="$(nproc 2> /dev/null || sysctl -n hw.logicalcpu 2> /dev/null)"
                    mapfile -t FINAL_LIST <<< "$(printf "\"%s\"\n" "${FILENAMES[@]}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS:-${cores}}" -I {} bash -c '
                    _gen_final_list "{}"')"

                    _upload_folder "${PARALLEL_UPLOAD:-normal}" parse "$(printf "%s\n" "${FINAL_LIST[@]}")"
                    [[ -n ${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}} ]] && _newline "\n\n"
                else
                    EMPTY=1
                fi
            fi
            if [[ ${EMPTY} != 1 ]]; then
                [[ -z ${VERBOSE:-${VERBOSE_PROGRESS}} ]] && for _ in 1 2; do _clear_line 1; done

                [[ ${SUCCESS_STATUS} -gt 0 ]] &&
                    FOLDER_ID="$(: "${DIRIDS%%$'\n'*}" && printf "%s\n" "${_/"|:_//_:|"*/}")" &&
                    _share_and_print_link "${FOLDER_ID}"

                _newline "\n"
                [[ ${SUCCESS_STATUS} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Total Files " "Uploaded: ${SUCCESS_STATUS}" "="
                [[ ${ERROR_STATUS} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Total Files " "Failed: ${ERROR_STATUS}" "="
                printf "\n"
            else
                for _ in 1 2; do _clear_line 1; done
                "${QUIET:-_print_center}" 'justify' "Empty Folder" ": ${input}" "=" 1>&2
                printf "\n"
            fi
        fi
    done

    unset Aseen && declare -A Aseen
    for gdrive_id in "${FINAL_ID_INPUT_ARRAY[@]}"; do
        { [[ ${Aseen[${gdrive_id}]} ]] && continue; } || Aseen[${gdrive_id}]=x
        _print_center "justify" "Given Input" ": ID" "="
        _print_center "justify" "Checking if id exists.." "-"
        json="$(_drive_info "${gdrive_id}" "name,mimeType,size" "${ACCESS_TOKEN}" || :)"
        if ! _json_value code 1 1 <<< "${json}" 2> /dev/null 1>&2; then
            type="$(_json_value mimeType 1 1 <<< "${json}" || :)"
            name="$(_json_value name 1 1 <<< "${json}" || :)"
            size="$(_json_value size 1 1 <<< "${json}" || :)"
            for _ in 1 2; do _clear_line 1; done
            if [[ ${type} =~ folder ]]; then
                _print_center "justify" "Folder not supported." "=" 1>&2 && _newline "\n" 1>&2 && continue
                ## TODO: Add support to clone folders
            else
                _print_center "justify" "Given Input" ": File ID" "="
                _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
                _clone_file "${UPLOAD_MODE:-create}" "${gdrive_id}" "${WORKSPACE_FOLDER_ID}" "${ACCESS_TOKEN}" "${name}" "${size}" ||
                    { for _ in 1 2; do _clear_line 1; done && continue; }
            fi
            _share_and_print_link "${FILE_ID}"
            printf "\n"
        else
            _clear_line 1
            "${QUIET:-_print_center}" "justify" "File ID (${gdrive_id})" " invalid." "=" 1>&2
            printf "\n"
        fi
    done
    return 0
}

main() {
    [[ $# = 0 ]] && _short_help

    UTILS_FOLDER="${UTILS_FOLDER:-$(pwd)}"
    { . "${UTILS_FOLDER}"/common-utils.bash && . "${UTILS_FOLDER}"/drive-utils.bash; } || { printf "Error: Unable to source util files.\n" && exit 1; }

    _check_bash_version && set -o errexit -o noclobber -o pipefail

    _setup_arguments "${@}"
    "${SKIP_INTERNET_CHECK:-_check_internet}"

    [[ -n ${PARALLEL_UPLOAD} ]] && _setup_tempfile

    _cleanup() {
        {
            [[ -n ${PARALLEL_UPLOAD} ]] && rm -f "${TMPFILE:?}"*
            export abnormal_exit && if [[ -n ${abnormal_exit} ]]; then
                printf "\n\n%s\n" "Script exited manually."
                kill -9 -$$ &
            else
                _auto_update
            fi
        } 2> /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1"; exit' INT TERM
    trap '_cleanup' EXIT

    START="$(printf "%(%s)T\\n" "-1")"
    _print_center "justify" "Starting script" "-"

    _print_center "justify" "Checking credentials.." "-"
    _check_credentials && for _ in 1 2; do _clear_line 1; done
    _print_center "justify" "Required credentials available." "-"

    _print_center "justify" "Checking root dir and workspace folder.." "-"
    _setup_root_dir && for _ in 1 2; do _clear_line 1; done
    _print_center "justify" "Root dir properly configured." "-"

    _print_center "justify" "Checking Workspace Folder.." "-"
    _setup_workspace && for _ in 1 2; do _clear_line 1; done
    _print_center "justify" "Workspace Folder: ${WORKSPACE_FOLDER_NAME}" "="
    _print_center "normal" " ${WORKSPACE_FOLDER_ID} " "-" && _newline "\n"

    _process_arguments

    END="$(printf "%(%s)T\\n" "-1")"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds " "="
}

main "${@}"
