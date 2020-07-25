#!/usr/bin/env sh
# Upload a file to Google Drive
# shellcheck source=/dev/null

_usage() {
    printf "%b" "
The script can be used to upload file/directory to google drive.\n
Usage:\n ${0##*/} [options.. ] <filename> <foldername>\n
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
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -R | --retry 'num of retries' - Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.\n
  -in | --include 'pattern' - Only include the files with the given pattern to upload - Applicable for folder uploads.\n
      e.g: ${0##*/} local_folder --include "*1*", will only include with files with pattern '1' in the name.\n
  -ex | --exclude 'pattern' - Exclude the files with the given pattern from uploading. - Applicable for folder uploads.\n
      e.g: ${0##*/} local_folder --exclude "*1*", will exclude all the files pattern '1' in the name.\n
  -v | --verbose - Display detailed message (only for non-parallel uploads).\n
  -V | --verbose-progress - Display detailed message and detailed upload progress(only for non-parallel uploads).\n
  --skip-internet-check - Do not check for internet connection, recommended to use in sync jobs.\n
  -u | --update - Update the installed script in your system.\n
  --info - Show detailed info, only if script is installed system wide.\n
  -U | --uninstall - Uninstall script, remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Automatic updater, only update if script is installed system wide.
# Globals: 4 variables, 2 functions
#   Variables - INFO_FILE, COMMAND_NAME, LAST_UPDATE_TIME, AUTO_UPDATE_INTERVAL
#   Functions - _update, _update_config
# Arguments: None
# Result: On
#   Update if AUTO_UPDATE_INTERVAL + LAST_UPDATE_TIME less than printf "%(%s)T\\n" "-1"
###################################################
_auto_update() {
    (
        [ -w "${INFO_FILE}" ] && . "${INFO_FILE}" && command -v "${COMMAND_NAME}" 2> /dev/null 1>&2 && {
            [ "$((LAST_UPDATE_TIME + AUTO_UPDATE_INTERVAL))" -lt "$(date +'%s')" ] &&
                _update 2>&1 1>| "${INFO_PATH}/update.log" &&
                _update_config LAST_UPDATE_TIME "$(date +'%s')" "${INFO_FILE}"
        }
    ) 2> /dev/null 1>&2 &
    return 0
}

###################################################
# Install/Update/uninstall the script.
# Globals: 3 variables,2 functions
#   Variables - HOME, REPO, TYPE_VALUE
#   Functions - _clear_line, _print_center
# Arguments: 1
#   ${1}" = uninstall or update
# Result: On
#   ${1}" = nothing - Update the script if installed, otherwise install.
#   ${1}" = uninstall - uninstall the script
###################################################
_update() {
    job_update="${1:-update}"
    [ "${job_update}" = uninstall ] && job_string_update="--uninstall"
    _print_center "justify" "Fetching ${job_update} script.." "-"
    [ -w "${INFO_FILE}" ] && . "${INFO_FILE}"
    repo_update="${REPO:-labbots/google-drive-upload}" type_value_update="${TYPE_VALUE:-latest}"
    { [ "${TYPE:-}" != branch ] && type_value_update="$(_get_latest_sha release "${type_value_update}" "${repo_update}")"; } || :
    if script_update="$(curl --compressed -Ls "https://raw.githubusercontent.com/${repo_update}/${type_value_update}/install.sh")"; then
        _clear_line 1
        printf "%s\n" "${script_update}" | sh -s -- ${job_string_update:-} --skip-internet-check
    else
        _clear_line 1
        _print_center "justify" "Error: Cannot download" " ${job_update} script." "=" 1>&2
        exit 1
    fi
    exit "${?}"
}

###################################################
# Print the contents of info file if scipt is installed system wide.
# Path is INFO_FILE="${HOME}/.google-drive-upload/google-drive-upload.info"
# Globals: 1 variable
#   INFO_FILE
# Arguments: None
# Result: read description
###################################################
_version_info() {
    if [ -r "${INFO_FILE}" ]; then
        cat "${INFO_FILE}"
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
#   ${@}" = Flags with argument and file/folder input
# Result: On
#   Success - Set all the variables
#   Error   - Print error message and exit
# Reference:
#   Email Regex - https://stackoverflow.com/a/57295993
###################################################
_setup_arguments() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset FIRST_INPUT FOLDER_INPUT FOLDERNAME FINAL_LOCAL_INPUT_ARRAY FINAL_ID_INPUT_ARRAY
    unset PARALLEL NO_OF_PARALLEL_JOBS SHARE SHARE_EMAIL OVERWRITE SKIP_DUPLICATES SKIP_SUBDIRS ROOTDIR QUIET
    unset VERBOSE VERBOSE_PROGRESS DEBUG LOG_FILE_ID CURL_SPEED RETRY
    CURL_PROGRESS="-#" && unset CURL_PROGRESS_EXTRA CURL_PROGRESS_EXTRA_CLEAR EXTRA_LOG EXTRA_LOG_CLEAR
    INFO_PATH="${HOME}/.google-drive-upload"
    INFO_FILE="${INFO_PATH}/google-drive-upload.info"
    [ -f "${INFO_PATH}/google-drive-upload.configpath" ] && CONFIG="$(cat "${INFO_PATH}/google-drive-upload.configpath")"
    CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"

    # Grab the first and second argument ( if 1st argument isn't a drive url ) and shift, only if ${1} doesn't contain -.
    [ -n "${1##-*}" ] && {
        case "${1}" in
            *drive.google.com* | *docs.google.com*)
                FINAL_ID_INPUT_ARRAY="$(_extract_id "${1}")" && shift
                ;;
            *)
                LOCAL_INPUT_ARRAY="${1}" && shift
                ;;
        esac
        [ -n "${1##-*}" ] && FOLDER_INPUT="${1}" && shift
    }

    # Configuration variables # Remote gDrive variables
    unset ROOT_FOLDER CLIENT_ID CLIENT_SECRET REFRESH_TOKEN ACCESS_TOKEN
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"
    SCOPE="${API_URL}/auth/drive"
    REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
    TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _check_config() {
        [ -z "${1##default=*}" ] && UPDATE_DEFAULT_CONFIG="true"
        { [ -r "${2}" ] && CONFIG="${2}"; } || {
            printf "Error: Given config file (%s) doesn't exist/not readable,..\n" "${1}" 1>&2 && exit 1
        }
        return 0
    }

    _check_longoptions() {
        [ -z "${2}" ] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" &&
            exit 1
        return 0
    }

    while [ $# -gt 0 ]; do
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
                ROOTDIR="${2##default=}"
                [ -z "${2##default=*}" ] && UPDATE_DEFAULT_ROOTDIR="_update_config"
                shift
                ;;
            -z | --config)
                _check_longoptions "${1}" "${2}"
                _check_config "${2}" "${2##default=}"
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
                if [ "$((NO_OF_PARALLEL_JOBS))" -gt 0 ] 2> /dev/null 1>&2; then
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
                LOCAL_INPUT_ARRAY="${LOCAL_INPUT_ARRAY}
                                   ${2}" && shift
                ;;
            -cl | --clone)
                _check_longoptions "${1}" "${2}"
                FINAL_ID_INPUT_ARRAY="${FINAL_ID_INPUT_ARRAY}
                                      $(_extract_id "${2}")" && shift
                ;;
            -S | --share)
                SHARE="_share_id"
                EMAIL_REGEX="^([A-Za-z]+[A-Za-z0-9]*\+?((\.|\-|\_)?[A-Za-z]+[A-Za-z0-9]*)*)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
                case "${1}" in
                    -* | '') : ;;
                    *)
                        SHARE_EMAIL="${2}"
                        printf "%s\n" "${SHARE_EMAIL}" | grep -qE "${EMAIL_REGEX}" || printf "\nError: Provided email address for share option is invalid.\n" && exit 1
                        shift
                        ;;
                esac
                ;;
            --speed)
                _check_longoptions "${1}" "${2}"
                regex='^([0-9]+)([k,K]|[m,M]|[g,G])+$'
                if printf "%s\n" "${2}" | grep -qE "${regex}"; then
                    CURL_SPEED="--limit-rate ${2}" && shift
                else
                    printf "Error: Wrong speed limit format, supported formats: 1K , 1M and 1G\n" 1>&2
                    exit 1
                fi
                ;;
            -R | --retry)
                _check_longoptions "${1}" "${2}"
                if [ "$((2))" -gt 0 ] 2> /dev/null 1>&2; then
                    RETRY="${2}" && shift
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
            -q | --quiet) QUIET="_print_center_quiet" ;;
            -v | --verbose) VERBOSE="true" ;;
            -V | --verbose-progress) VERBOSE_PROGRESS="true" && CURL_PROGRESS="" ;;
            --skip-internet-check) SKIP_INTERNET_CHECK=":" ;;
            '') shorthelp ;;
            *) # Check if user meant it to be a flag
                if [ -z "${1##-*}" ]; then
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    case "${1}" in
                        *drive.google.com* | *docs.google.com*)
                            FINAL_ID_INPUT_ARRAY="${FINAL_ID_INPUT_ARRAY}
                                                  $(_extract_id "${1}")"
                            ;;
                        *)
                            LOCAL_INPUT_ARRAY="${LOCAL_INPUT_ARRAY}
                                               ${1}"
                            ;;
                    esac
                    [ -n "${2:+${2##-*}}" ] && [ -z "${3:-${FOLDERNAME:-${FOLDER_INPUT}}}" ] && FOLDER_INPUT="${FOLDER_INPUT:-${2}}" && shift
                fi
                ;;
        esac
        shift
    done

    [ -n "${VERBOSE_PROGRESS:-${VERBOSE}}" ] && unset "${VERBOSE}"

    [ -n "${QUIET}" ] && CURL_PROGRESS="-s"

    _check_debug

    { [ "${CURL_PROGRESS}" = "-#" ] && CURL_PROGRESS_EXTRA="-#" && CURL_PROGRESS_EXTRA_CLEAR="_clear_line"; } || CURL_PROGRESS_EXTRA="-s"

    # Get foldername, prioritise the input given by -C/--create-dir option.
    FOLDERNAME="${FOLDERNAME:-${FOLDER_INPUT}}"

    # If no input, then check if -C option was used or not.
    # check if given input exists ( file/folder )
    FINAL_LOCAL_INPUT_ARRAY="$(printf "%s\n" "${LOCAL_INPUT_ARRAY}" | while read -r input; do
        { [ -r "${input}" ] && printf "%s\n" "${input}"; } || {
            { "${QUIET:-_print_center}" 'normal' "[ Error: Invalid Input - ${input} ]" "=" && printf "\n"; } 1>&2
            continue
        }
    done)"

    [ -z "${FINAL_LOCAL_INPUT_ARRAY:-${FINAL_ID_INPUT_ARRAY:-${FOLDERNAME}}}" ] && _short_help

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
    { command -v mktemp 2> /dev/null 1>&2 && TMPFILE="$(mktemp -u)"; } || TMPFILE="$(pwd)/$(date +'%s').LOG"
    return 0
}

###################################################
# Check Oauth credentials and create/update config file
# Client ID, Client Secret, Refesh Token and Access Token
# Globals: 10 variables, 3 functions
#   Variables - API_URL, API_VERSION, TOKEN URL,
#               CONFIG, UPDATE_DEFAULT_CONFIG, INFO_PATH,
#               CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN and ACCESS_TOKEN
#   Functions - _update_config, _json_value and _print
# Arguments: None
# Result: read description
###################################################
_check_credentials() {
    # Config file is created automatically after first run
    [ -r "${CONFIG}" ] &&
        . "${CONFIG}" && [ -n "${UPDATE_DEFAULT_CONFIG}" ] && printf "%s\n" "${CONFIG}" >| "${INFO_PATH}/google-drive-upload.configpath"

    until [ -n "${CLIENT_ID}" ]; do
        [ -n "${client_id}" ] && _clear_line 1
        printf "Client ID: " && read -r CLIENT_ID && client_id=1
    done && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"

    until [ -n "${CLIENT_SECRET}" ]; do
        [ -n "${client_secret}" ] && _clear_line 1
        printf "Client Secret: " && read -r CLIENT_SECRET && client_secret=1
    done && _update_config CLIENT_SECRET "${CLIENT_SECRET}" "${CONFIG}"

    # Method to regenerate access_token ( also updates in config ).
    # Make a request on https://www.googleapis.com/oauth2/""${API_VERSION}""/tokeninfo?access_token=${ACCESS_TOKEN} url and check if the given token is valid, if not generate one.
    # Requirements: Refresh Token
    # shellcheck disable=SC2120
    _get_token_and_update() {
        RESPONSE="${1:-$(curl --compressed -s -X POST --data "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" "${TOKEN_URL}")}" || :
        if ACCESS_TOKEN="$(printf "%s\n" "${RESPONSE}" | _json_value access_token 1 1)"; then
            _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
            { ACCESS_TOKEN_EXPIRY="$(curl --compressed -s "${API_URL}/oauth2/${API_VERSION}/tokeninfo?access_token=${ACCESS_TOKEN}" | _json_value exp 1 1)" &&
                _update_config ACCESS_TOKEN_EXPIRY "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"; } || { "${QUIET:-_print_center}" "justify" "Error: Couldn't update" " access token expiry." 1>&2 && exit 1; }
        else
            _print_center "justify" "Error: Something went wrong" ", printing error." "=" 1>&2
            printf "%s\n" "${RESPONSE}" 1>&2
            exit 1
        fi
        return 0
    }

    # Method to obtain refresh_token.
    # Requirements: client_id, client_secret and authorization code.
    [ -z "${REFRESH_TOKEN}" ] && {
        printf "%b" "If you have a refresh token generated, then type the token, else leave blank and press return key..\n\nRefresh Token: "
        read -r REFRESH_TOKEN
        if [ -n "${REFRESH_TOKEN}" ]; then
            _get_token_and_update && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
        else
            printf "\nVisit the below URL, tap on allow and then enter the code obtained:\n"
            URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
            printf "%s\n" "${URL}"
            until [ -n "${CODE}" ]; do
                [ -n "${code}" ] && _clear_line 1
                printf "Enter the authorization code: " && read -r CODE && code=1
            done
            RESPONSE="$(curl --compressed -s -X POST \
                --data "code=${CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :

            REFRESH_TOKEN="$(printf "%s\n" "${RESPONSE}" | _json_value refresh_token 1 1 || :)"
            _get_token_and_update "${RESPONSE}" && _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
        fi
    }

    [ -z "${ACCESS_TOKEN}" ] || [ "${ACCESS_TOKEN_EXPIRY}" -lt "$(date +'%s')" ] && _get_token_and_update

    return 0
}

###################################################
# Setup root directory where all file/folders will be uploaded/updated
# Globals: 6 variables, 5 functions
#   Variables - ROOTDIR, ROOT_FOLDER, UPDATE_DEFAULT_ROOTDIR, CONFIG, QUIET, ACCESS_TOKEN
#   Functions - _print, _drive_info, _extract_id, _update_config, _json_value
# Arguments: 1
#   ${1}" = Positive integer ( amount of time in seconds to sleep )
# Result: read description
#   If root id not found then pribt message and exit
#   Update config with root id and root id name if specified
# Reference:
#   https://github.com/dylanaraps/pure-sh-bible#use-read-as-an-alternative-to-the-sleep-command
###################################################
_setup_root_dir() {
    _check_root_id() {
        _setup_root_dir_json="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "id" "${ACCESS_TOKEN}")"
        if ! rootid_setup_root_dir="$(printf "%s\n" "${_setup_root_dir_json}" | _json_value id 1 1)"; then
            if printf "%s\n" "${_setup_root_dir_json}" | grep "File not found" -q; then
                "${QUIET:-_print}" "justify" "Given root folder" " ID/URL invalid." 1>&2
            else
                printf "%s\n" "${_setup_root_dir_json}" 1>&2
            fi
            exit 1
        fi

        ROOT_FOLDER="${rootid_setup_root_dir}"
        "${1:-:}" ROOT_FOLDER "${ROOT_FOLDER}" "${CONFIG}"
        return 0
    }
    _update_root_id_name() {
        ROOT_FOLDER_NAME="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "name" "${ACCESS_TOKEN}" | _json_value name 1 1 || :)"
        "${1:-:}" ROOT_FOLDER_NAME "${ROOT_FOLDER_NAME}" "${CONFIG}"
        return 0
    }

    [ -n "${ROOT_FOLDER}" ] && [ -z "${ROOT_FOLDER_NAME}" ] && _update_root_id_name _update_config

    if [ -n "${ROOTDIR:-}" ]; then
        ROOT_FOLDER="${ROOTDIR}" && _check_root_id "${UPDATE_DEFAULT_ROOTDIR}"
    elif [ -z "${ROOT_FOLDER}" ]; then
        printf "Root Folder ID or URL (Default: root) - Press enter for default: "
        read -r ROOT_FOLDER
        { [ -n "${ROOT_FOLDER}" ] && _check_root_id; } || {
            ROOT_FOLDER="root"
            _update_config ROOT_FOLDER "${ROOT_FOLDER}" "${CONFIG}"
        }
    fi

    [ -z "${ROOT_FOLDER_NAME}" ] && _update_root_id_name "${UPDATE_DEFAULT_ROOTDIR}"

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
    if [ -z "${FOLDERNAME}" ]; then
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
# Process all the values in "${FINAL_LOCAL_INPUT_ARRAY}" & "${FINAL_ID_INPUT_ARRAY}"
# Globals: 20 variables, 14 functions
#   Variables - FINAL_LOCAL_INPUT_ARRAY ( array ), ACCESS_TOKEN, VERBOSE, VERBOSE_PROGRESS
#               WORKSPACE_FOLDER_ID, UPLOAD_MODE, SKIP_DUPLICATES, OVERWRITE, SHARE,
#               UPLOAD_STATUS, COLUMNS, API_URL, API_VERSION, LOG_FILE_ID
#               FILE_ID, FILE_LINK, FINAL_ID_INPUT_ARRAY ( array )
#               PARALLEL_UPLOAD, QUIET, NO_OF_PARALLEL_JOBS, TMPFILE
#   Functions - _print_center, _clear_line, _newline, _is_terminal, _print_center_quiet
#               _upload_file, _share_id, _dirname,
#               _create_directory, _json_value, _url_encode, _check_existing_file
#               _clone_file
# Arguments: None
# Result: Upload/Clone all the input files/folders, if a folder is empty, print Error message.
###################################################
_process_arguments() {
    export API_URL API_VERSION ACCESS_TOKEN LOG_FILE_ID OVERWRITE UPLOAD_MODE SKIP_DUPLICATES CURL_SPEED RETRY UTILS_FOLDER SOURCE_UTILS \
        QUIET VERBOSE VERBOSE_PROGRESS CURL_PROGRESS CURL_PROGRESS_EXTRA CURL_PROGRESS_EXTRA_CLEAR COLUMNS EXTRA_LOG EXTRA_LOG_CLEAR PARALLEL_UPLOAD

    # on successful uploads
    _share_and_print_link() {
        "${SHARE:-:}" "${1:-}" "${ACCESS_TOKEN}" "${SHARE_EMAIL}"
        _print_center "justify" "DriveLink" "${SHARE:+ (SHARED)}" "-"
        _is_terminal && [ "$((COLUMNS))" -gt 45 ] 2> /dev/null && _print_center "normal" '^ ^ ^' ' '
        _print_center "normal" "https://drive.google.com/open?id=${1:-}" " "
    }

    unset Aseen && while read -r input <&4 && { [ -n "${input}" ] || continue; } &&
        case "${Aseen}" in
            *"|:_//_:|${gdrive_id}|:_//_:|"*) continue ;;
            *) Aseen="${Aseen}|:_//_:|${gdrive_id}|:_//_:|" ;;
        esac; do
        # Check if the argument is a file or a directory.
        if [ -f "${input}" ]; then
            _print_center "justify" "Given Input" ": FILE" "="
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            _upload_file_main noparse "${input}" "${WORKSPACE_FOLDER_ID}"
            if [ "${RETURN_STATUS}" = 1 ]; then
                _share_and_print_link "${FILE_ID}"
                printf "\n"
            else
                for _ in 1 2; do _clear_line 1; done && continue
            fi
        elif [ -d "${input}" ]; then
            input="$(cd "${input}" && pwd)" # to handle dirname when current directory (.) is given as input.
            unset EMPTY                     # Used when input folder is empty

            _print_center "justify" "Given Input" ": FOLDER" "-"
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            FOLDER_NAME="${input##*/}" && _print_center "justify" "Folder: ${FOLDER_NAME}" "="

            NEXTROOTDIRID="${WORKSPACE_FOLDER_ID}"

            _print_center "justify" "Processing folder.." "-"

            # Do not create empty folders during a recursive upload. Use of find in this section is important.
            DIRNAMES="$(find "${input}" -type d -not -empty)"
            NO_OF_FOLDERS="$(($(printf "%s\n" "${DIRNAMES}" | wc -l)))" && NO_OF_SUB_FOLDERS="$((NO_OF_FOLDERS - 1))" && _clear_line 1
            [ "${NO_OF_SUB_FOLDERS}" = 0 ] && SKIP_SUBDIRS="true"

            ERROR_STATUS=0 SUCCESS_STATUS=0

            # Skip the sub folders and find recursively all the files and upload them.
            if [ -n "${SKIP_SUBDIRS}" ]; then
                _print_center "justify" "Indexing files recursively.." "-"
                FILENAMES="$(_tmp='find "'${input}'" -type f -name "*" '${INCLUDE_FILES}' '${EXCLUDE_FILES}'' && eval "${_tmp}")"

                if [ -n "${FILENAMES}" ]; then
                    NO_OF_FILES="$(($(printf "%s\n" "${FILENAMES}" | wc -l)))"
                    for _ in 1 2; do _clear_line 1; done

                    "${QUIET:-_print_center}" "justify" "Folder: ${FOLDER_NAME} " "| ${NO_OF_FILES} File(s)" "=" && printf "\n"
                    _print_center "justify" "Creating folder.." "-"
                    { ID="$(_create_directory "${input}" "${NEXTROOTDIRID}" "${ACCESS_TOKEN}")" && export ID; } || { printf "%s\n" "${ID}" 1>&2 && return 1; }
                    _clear_line 1 && DIRIDS="${ID}"

                    [ -z "${PARALLEL_UPLOAD:-${VERBOSE:-${VERBOSE_PROGRESS}}}" ] && _newline "\n"
                    _upload_folder "${PARALLEL_UPLOAD:-normal}" noparse "${FILENAMES}" "${ID}"
                    [ -n "${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}}" ] && _newline "\n\n"
                else
                    _newline "\n" && EMPTY=1
                fi
            else
                _print_center "justify" "$((NO_OF_SUB_FOLDERS)) Sub-folders found." "="
                _print_center "justify" "Indexing files.." "="
                FILENAMES="$(_tmp='find "'${input}'" -type f -name "*" '${INCLUDE_FILES}' '${EXCLUDE_FILES}'' && eval "${_tmp}")"

                if [ -n "${FILENAMES}" ]; then
                    NO_OF_FILES="$(($(printf "%s\n" "${FILENAMES}" | wc -l)))"
                    for _ in 1 2 3; do _clear_line 1; done
                    "${QUIET:-_print_center}" "justify" "${FOLDER_NAME} " "| $((NO_OF_FILES)) File(s) | $((NO_OF_SUB_FOLDERS)) Sub-folders" "="

                    _newline "\n" && _print_center "justify" "Creating Folder(s).." "-" && _newline "\n"
                    unset status
                    while read -r dir <&4 && { [ -n "${dir}" ] || continue; }; do
                        [ -n "${status}" ] && __dir="$(_dirname "${dir}")" &&
                            __temp="$(printf "%s\n" "${DIRIDS}" | grep "|:_//_:|${__dir}|:_//_:|")" &&
                            NEXTROOTDIRID="${__temp%%"|:_//_:|${__dir}|:_//_:|"}"

                        NEWDIR="${dir##*/}" && _print_center "justify" "Name: ${NEWDIR}" "-" 1>&2
                        ID="$(_create_directory "${NEWDIR}" "${NEXTROOTDIRID}" "${ACCESS_TOKEN}")" || { printf "%s\n" "${ID}" 1>&2 && exit 1; }

                        # Store sub-folder directory IDs and it's path for later use.
                        DIRIDS="$(printf "%b%s|:_//_:|%s|:_//_:|\n" "${DIRIDS:+${DIRIDS}\n}" "${ID}" "${dir}")"

                        for _ in 1 2; do _clear_line 1 1>&2; done
                        _print_center "justify" "Status" ": $((status += 1)) / $((NO_OF_FOLDERS))" "=" 1>&2
                    done 4<< EOF
$(printf "%s\n" "${DIRNAMES}")
EOF
                    for _ in 1 2; do _clear_line 1; done

                    _print_center "justify" "Preparing to upload.." "-"

                    export DIRIDS && cores="$(($(nproc 2> /dev/null || sysctl -n hw.logicalcpu 2> /dev/null)))"
                    # shellcheck disable=SC2016
                    FINAL_LIST="$(printf "%s\n" "${FILENAMES}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS:-${cores}}" -I {} sh -c '
                    . "${UTILS_FOLDER}"/common-utils.sh && _gen_final_list "{}" ')"

                    _upload_folder "${PARALLEL_UPLOAD:-normal}" parse "${FINAL_LIST}"
                    [ -n "${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}}" ] && _newline "\n\n"
                else
                    EMPTY=1
                fi
            fi
            if [ "${EMPTY}" != 1 ]; then
                [ -z "${VERBOSE:-${VERBOSE_PROGRESS}}" ] && for _ in 1 2; do _clear_line 1; done

                [ "${SUCCESS_STATUS}" -gt 0 ] &&
                    FOLDER_ID="$(_tmp="$(printf "%s\n" "${DIRIDS}" | while read -r line; do printf "%s\n" "${line}" && break; done)" && printf "%s\n" "${_tmp%%"|:_//_:|"*}")" &&
                    _share_and_print_link "${FOLDER_ID}"

                _newline "\n"
                [ "${SUCCESS_STATUS}" -gt 0 ] && "${QUIET:-_print_center}" "justify" "Total Files " "Uploaded: ${SUCCESS_STATUS}" "="
                [ "${ERROR_STATUS}" -gt 0 ] && "${QUIET:-_print_center}" "justify" "Total Files " "Failed: ${ERROR_STATUS}" "="
                printf "\n"
            else
                for _ in 1 2; do _clear_line 1; done
                "${QUIET:-_print_center}" 'justify' "Empty Folder" ": ${input}" "=" 1>&2
                printf "\n"
            fi
        fi
    done 4<< EOF
$(printf "%s\n" "${FINAL_LOCAL_INPUT_ARRAY}")
EOF

    unset Aseen && while read -r gdrive_id <&4 && { [ -n "${gdrive_id}" ] || continue; } &&
        case "${Aseen}" in
            *"|:_//_:|${gdrive_id}|:_//_:|"*) continue ;;
            *) Aseen="${Aseen}|:_//_:|${gdrive_id}|:_//_:|" ;;
        esac; do
        _print_center "justify" "Given Input" ": ID" "="
        _print_center "justify" "Checking if id exists.." "-"
        json="$(_drive_info "${gdrive_id}" "name,mimeType,size" "${ACCESS_TOKEN}")" || :
        if ! printf "%s\n" "${json}" | _json_value code 1 1 2> /dev/null 1>&2; then
            type="$(printf "%s\n" "${json}" | _json_value mimeType 1 1 || :)"
            name="$(printf "%s\n" "${json}" | _json_value name 1 1 || :)"
            size="$(printf "%s\n" "${json}" | _json_value size 1 1 || :)"
            for _ in 1 2; do _clear_line 1; done
            case "${type}" in
                *folder*)
                    _print_center "justify" "Folder not supported." "=" 1>&2 && _newline "\n" 1>&2 && continue
                    ## TODO: Add support to clone folders
                    ;;
                *)
                    _print_center "justify" "Given Input" ": File ID" "="
                    _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
                    _clone_file "${UPLOAD_MODE:-create}" "${gdrive_id}" "${WORKSPACE_FOLDER_ID}" "${ACCESS_TOKEN}" "${name}" "${size}" ||
                        { for _ in 1 2; do _clear_line 1; done && continue; }
                    ;;
            esac
            _share_and_print_link "${FILE_ID}"
            printf "\n"
        else
            _clear_line 1
            "${QUIET:-_print_center}" "justify" "File ID (${gdrive_id})" " invalid." "=" 1>&2
            printf "\n"
        fi
    done 4<< EOF
$(printf "%s\n" "${FINAL_ID_INPUT_ARRAY}")
EOF
    return 0
}

main() {
    [ $# = 0 ] && _short_help

    UTILS_FOLDER="${UTILS_FOLDER:-$(pwd)}" && SOURCE_UTILS=". '${UTILS_FOLDER}/common-utils.sh' && . '${UTILS_FOLDER}/drive-utils.sh'"
    eval "${SOURCE_UTILS}" || { printf "Error: Unable to source util files.\n" && exit 1; }

    set -o errexit -o noclobber

    _setup_arguments "${@}"
    "${SKIP_INTERNET_CHECK:-_check_internet}"

    [ -n "${PARALLEL_UPLOAD}" ] && _setup_tempfile

    _cleanup() {
        {
            [ -n "${PARALLEL_UPLOAD}" ] && rm -f "${TMPFILE:?}"*
            export abnormal_exit && if [ -n "${abnormal_exit}" ]; then
                printf "\n\n%s\n" "Script exited manually."
                kill -9 -$$ &
            else
                _auto_update
            fi
        } 2> /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1" ; exit' INT TERM
    trap '_cleanup' EXIT

    START="$(date +'%s')"
    "${EXTRA_LOG:-:}" "justify" "Starting script" "-"

    "${EXTRA_LOG:-:}" "justify" "Checking credentials.." "-"
    _check_credentials && for _ in 1 2; do _clear_line 1; done
    _print_center "justify" "Required credentials available." "="

    "${EXTRA_LOG:-:}" "justify" "Checking root dir and workspace folder.." "-"
    _setup_root_dir && for _ in 1 2; do _clear_line 1; done
    _print_center "justify" "Root dir properly configured." "="

    "${EXTRA_LOG:-:}" "justify" "Checking Workspace Folder.." "-"
    _setup_workspace && for _ in 1 2; do _clear_line 1; done
    _print_center "justify" "Workspace Folder: ${WORKSPACE_FOLDER_NAME}" "="
    _print_center "normal" " ${WORKSPACE_FOLDER_ID} " "-" && _newline "\n"

    _process_arguments

    END="$(date +'%s')"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" 'normal' " Time Elapsed: $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds " "="
}

main "${@}"
