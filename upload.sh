#!/usr/bin/env bash
# Upload a file to Google Drive

_usage() {
    printf "
The script can be used to upload file/directory to google drive.\n
Usage:\n %s [options.. ] <filename> <foldername>\n
Foldername argument is optional. If not provided, the file will be uploaded to preconfigured google drive.\n
File name argument is optional if create directory option is used.\n
Options:\n
  -C | --create-dir <foldername> - option to create directory. Will provide folder id. Can be used to provide input folder, see README.\n
  -r | --root-dir <google_folderid> or <google_folder_url> - google folder ID/URL to which the file/directory is going to upload.\nIf you want to change the default value, then use this format, -r/--root-dir default=root_folder_id/root_folder_url\n
  -s | --skip-subdirs - Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder, use this along with -p/--parallel option to speed up the uploads.\n
  -p | --parallel <no_of_files_to_parallely_upload> - Upload multiple files in parallel, Max value = 10.\n
  -f | --[file|folder] - Specify files and folders explicitly in one command, use multiple times for multiple folder/files. See README for more use of this command.\n 
  -o | --overwrite - Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders.\n
  -d | --skip-duplicates - Do not upload the files with the same name, if already present in the root folder/input folder, also works with recursive folders.\n
  -S | --share <optional_email_address>- Share the uploaded input file/folder, grant reader permission to provided email address or to everyone with the shareable link.\n
  -i | --save-info <file_to_save_info> - Save uploaded files info to the given filename.\n
  -z | --config <config_path> - Override default config file with custom config file.\nIf you want to change default value, then use this format -z/--config default=default=your_config_file_path.\n
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -v | --verbose - Display detailed message (only for non-parallel uploads).\n
  -V | --verbose-progress - Display detailed message and detailed upload progress(only for non-parallel uploads).\n
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
    { [[ ${job} =~ uninstall ]] && job_string="--uninstall"; } || :
    _print_center "justify" "Fetching ${job} script.." "-"
    # shellcheck source=/dev/null
    if [[ -f "${HOME}/.google-drive-upload/google-drive-upload.info" ]]; then
        source "${HOME}/.google-drive-upload/google-drive-upload.info"
    fi
    declare repo="${REPO:-labbots/google-drive-upload}" type_value="${TYPE_VALUE:-latest}"
    if [[ ${TYPE:-} = branch ]]; then
        if script="$(curl --compressed -Ls "https://raw.githubusercontent.com/${repo}/${type_value}/install.sh")"; then
            _clear_line 1
            bash <(printf "%s\n" "${script}") "${job_string:-}"
        else
            _print_center "justify" "Error: Cannot download ${job} script." "="
            exit 1
        fi
    else
        declare latest_sha script
        latest_sha="$(_get_latest_sha release "${type_value}" "${repo}")"
        if script="$(curl --compressed -Ls "https://raw.githubusercontent.com/${repo}/${latest_sha}/install.sh")"; then
            _clear_line 1
            bash <(printf "%s\n" "${script}") "${job_string:-}"
        else
            _print_center "justify" "Error: Cannot download ${job} script." "="
            exit 1
        fi
    fi
    exit $?
}

###################################################
# Print the contents of info file if scipt is installed system wide.
# Path is "${HOME}/.google-drive-upload/google-drive-upload.info"
# Globals: 1 variable
#   HOME
# Arguments: None
# Result: read description
###################################################
_version_info() {
    # shellcheck source=/dev/null
    if [[ -f "${HOME}/.google-drive-upload/google-drive-upload.info" ]]; then
        printf "%s\n" "$(< "${HOME}/.google-drive-upload/google-drive-upload.info")"
    else
        _print_center "justify" "google-drive-upload is not installed system wide." "="
    fi
    exit 0
}

###################################################
# Get information for a gdrive folder/file.
# Globals: 2 variables, 1 function
#   Variables - API_URL, API_VERSION
#   Functions - _json_value
# Arguments: 3
#   ${1} = folder/file gdrive id
#   ${2} = information to fetch, e.g name, id
#   ${3} = Access Token
# Result: On
#   Success - print fetched value
#   Error   - print "message" field from the json
# Reference:
#   https://developers.google.com/drive/api/v3/search-files
###################################################
_drive_info() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare folder_id="${1}" fetch="${2}" token="${3}"
    declare search_response fetched_data

    search_response="$(curl --compressed -s \
        -H "Authorization: Bearer ${token}" \
        "${API_URL}/drive/${API_VERSION}/files/${folder_id}?fields=${fetch}&supportsAllDrives=true")"

    fetched_data="$(_json_value "${fetch}" 1 <<< "${search_response}")"
    { [[ -z ${fetched_data} ]] && _json_value message 1 <<< "${search_response}" && return 1; } || {
        printf "%s\n" "${fetched_data}"
    }
}

###################################################
# Search for an existing file on gdrive with write permission.
# Globals: 2 variables, 2 functions
#   Variables - API_URL, API_VERSION
#   Functions - _url_encode, _json_value
# Arguments: 3
#   ${1} = file name
#   ${2} = root dir id of file
#   ${3} = Access Token
# Result: print file id else blank
# Reference:
#   https://developers.google.com/drive/api/v3/search-files
###################################################
_check_existing_file() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare name="${1}" rootdir="${2}" token="${3}"
    declare query search_response id

    query="$(_url_encode "name='${name}' and '${rootdir}' in parents and trashed=false and 'me' in writers")"

    search_response="$(curl --compressed -s \
        -H "Authorization: Bearer ${token}" \
        "${API_URL}/drive/${API_VERSION}/files?q=${query}&fields=files(id)")"

    id="$(_json_value id 1 <<< "${search_response}")"
    printf "%s\n" "${id}"
}

###################################################
# Create/Check directory in google drive.
# Globals: 2 variables, 2 functions
#   Variables - API_URL, API_VERSION
#   Functions - _url_encode, _json_value
# Arguments: 3
#   ${1} = dir name
#   ${2} = root dir id of given dir
#   ${3} = Access Token
# Result: print folder id
# Reference:
#   https://developers.google.com/drive/api/v3/folder
###################################################
_create_directory() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare dirname="${1}" rootdir="${2}" token="${3}"
    declare query search_response folder_id

    query="$(_url_encode "mimeType='application/vnd.google-apps.folder' and name='${dirname}' and trashed=false and '${rootdir}' in parents")"

    search_response="$(curl --compressed -s \
        -H "Authorization: Bearer ${token}" \
        "${API_URL}/drive/${API_VERSION}/files?q=${query}&fields=files(id)&supportsAllDrives=true")"

    folder_id="$(printf "%s\n" "${search_response}" | _json_value id 1)"

    if [[ -z ${folder_id} ]]; then
        declare create_folder_post_data create_folder_response
        create_folder_post_data="{\"mimeType\": \"application/vnd.google-apps.folder\",\"name\": \"${dirname}\",\"parents\": [\"${rootdir}\"]}"
        create_folder_response="$(curl --compressed -s \
            -X POST \
            -H "Authorization: Bearer ${token}" \
            -H "Content-Type: application/json; charset=UTF-8" \
            -d "${create_folder_post_data}" \
            "${API_URL}/drive/${API_VERSION}/files?fields=id&supportsAllDrives=true")"
        folder_id="$(_json_value id <<< "${create_folder_response}")"
    fi
    printf "%s\n" "${folder_id}"
}

###################################################
# Upload ( Create/Update ) files on gdrive.
# Interrupted uploads can be resumed.
# Globals: 5 variables, 4 functions
#   Variables - API_URL, API_VERSION, QUIET, VERBOSE, VERBOSE_PROGRESS, CURL_ARGS, LOG_FILE_ID
#   Functions - _url_encode, _json_value, _print_center, _bytes_to_human
# Arguments: 3
#   ${1} = update or upload ( upload type )
#   ${2} = file to upload
#   ${3} = root dir id for file
#   ${4} = Access Token
#   ${5} = anything or empty ( for parallel )
# Result: On
#   Success - Upload/Update file and export FILE_ID AND FILE_LINK
#   Error - export UPLOAD_STATUS=1
# Reference:
#   https://developers.google.com/drive/api/v3/create-file
#   https://developers.google.com/drive/api/v3/manage-uploads
#   https://developers.google.com/drive/api/v3/reference/files/update
###################################################
_upload_file() {
    [[ $# -lt 4 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare job="${1}" input="${2}" folder_id="${3}" token="${4}" parallel="${5}"
    declare slug inputname extension inputsize readable_size request_method url postdata uploadlink upload_body string

    slug="${input##*/}"
    inputname="${slug%.*}"
    extension="${slug##*.}"
    inputsize="$(wc -c < "${input}")"
    readable_size="$(_bytes_to_human "${inputsize}")"

    # Handle extension-less files
    if [[ ${inputname} = "${extension}" ]]; then
        declare mime_type
        if type -p mimetype &> /dev/null; then
            mime_type="$(mimetype --output-format %m "${input}")"
        elif type -p file &> /dev/null; then
            mime_type="$(file --brief --mime-type "${input}")"
        else
            _print_center "justify" "Error: file or mimetype command not found." && printf "\n"
            exit 1
        fi
    fi

    # Set proper variables for overwriting files
    if [[ ${job} = update ]]; then
        declare existing_file_id
        # Check if file actually exists, and create if not.
        existing_file_id=$(_check_existing_file "${slug}" "${folder_id}" "${ACCESS_TOKEN}")
        if [[ -n ${existing_file_id} ]]; then
            if [[ -n ${SKIP_DUPLICATES} ]]; then
                SKIP_DUPLICATES_FILE_ID="${existing_file_id}"
                FILE_LINK="${SKIP_DUPLICATES_FILE_ID/${SKIP_DUPLICATES_FILE_ID}/https://drive.google.com/open?id=${SKIP_DUPLICATES_FILE_ID}}"
            else
                request_method="PATCH"
                url="${API_URL}/upload/drive/${API_VERSION}/files/${existing_file_id}?uploadType=resumable&supportsAllDrives=true&supportsTeamDrives=true"
                # JSON post data to specify the file name and folder under while the file to be updated
                postdata="{\"mimeType\": \"${mime_type}\",\"name\": \"${slug}\",\"addParents\": [\"${folder_id}\"]}"
                string="Updated"
            fi
        else
            job="create"
        fi
    fi

    if [[ -n ${SKIP_DUPLICATES_FILE_ID} ]]; then
        # Stop upload if already exists ( -d/--skip-duplicates )
        "${QUIET:-_print_center}" "justify" "${slug}" " already exists." "="
    else
        # Set proper variables for creating files
        if [[ ${job} = create ]]; then
            url="${API_URL}/upload/drive/${API_VERSION}/files?uploadType=resumable&supportsAllDrives=true&supportsTeamDrives=true"
            request_method="POST"
            # JSON post data to specify the file name and folder under while the file to be created
            postdata="{\"mimeType\": \"${mime_type}\",\"name\": \"${slug}\",\"parents\": [\"${folder_id}\"]}"
            string="Uploaded"
        fi

        [[ -z ${parallel} ]] && _print_center "justify" "${input##*/}" " | ${readable_size}" "="

        _generate_upload_link() {
            uploadlink="$(curl --compressed -s \
                -X "${request_method}" \
                -H "Authorization: Bearer ${token}" \
                -H "Content-Type: application/json; charset=UTF-8" \
                -H "X-Upload-Content-Type: ${mime_type}" \
                -H "X-Upload-Content-Length: ${inputsize}" \
                -d "$postdata" \
                "${url}" \
                -D -)"
            uploadlink="$(read -r firstline <<< "${uploadlink/*[L,l]ocation: /}" && printf "%s\n" "${firstline//$'\r'/}")"
        }

        # Curl command to push the file to google drive.
        _upload_file_from_uri() {
            [[ -z ${parallel} ]] && _clear_line 1 && _print_center "justify" "Uploading.." "-"
            # shellcheck disable=SC2086 # Because unnecessary to another check because ${CURL_ARGS} won't be anything problematic.
            upload_body="$(curl --compressed \
                -X PUT \
                -H "Authorization: Bearer ${token}" \
                -H "Content-Type: ${mime_type}" \
                -H "Content-Length: ${inputsize}" \
                -H "Slug: ${slug}" \
                -T "${input}" \
                -o- \
                --url "${uploadlink}" \
                --globoff \
                ${CURL_ARGS})"
        }

        _collect_file_info() {
            FILE_LINK="$(: "$(printf "%s\n" "${upload_body}" | _json_value id)" && printf "%s\n" "${_/$_/https://drive.google.com/open?id=$_}")"
            FILE_ID="$(printf "%s\n" "${upload_body}" | _json_value id)"
            # Log to the filename provided with -i/--save-id flag.
            if [[ -n ${LOG_FILE_ID} && ! -d ${LOG_FILE_ID} ]]; then
                # shellcheck disable=SC2129
                # https://github.com/koalaman/shellcheck/issues/1202#issuecomment-608239163
                {
                    printf "%s\n" "Link: ${FILE_LINK}"
                    : "$(printf "%s\n" "${upload_body}" | _json_value name)" && printf "%s\n" "${_/*/Name: $_}"
                    : "$(printf "%s\n" "${FILE_ID}")" && printf "%s\n" "${_/*/ID: $_}"
                    : "$(printf "%s\n" "${upload_body}" | _json_value mimeType)" && printf "%s\n" "${_/*/Type: $_}"
                    printf '\n'
                } >> "${LOG_FILE_ID}"
            fi
        }

        _normal_logging() {
            if [[ -z ${VERBOSE_PROGRESS:-${parallel}} ]]; then
                for _ in {1..3}; do _clear_line 1; done
            fi
            "${QUIET:-_print_center}" "justify" "${slug} " "| ${readable_size} | ${string}" "="
        }

        _error_logging() {
            "${QUIET:-_print_center}" "justify" "Upload link generation ERROR" ", ${slug} not ${string}." "=" 1>&2 && [[ -z ${parallel} ]] && printf "\n\n\n" 1>&2
            UPLOAD_STATUS="ERROR" && export UPLOAD_STATUS # Send a error status, used in folder uploads.
        }

        # Used for resuming interrupted uploads
        _log_upload_session() {
            { [[ ${inputsize} -gt 1000000 ]] && printf "%s\n" "${uploadlink}" >| "${__file}"; } || :
        }

        _remove_upload_session() {
            rm -f "${__file}"
        }

        _full_upload() {
            _generate_upload_link
            if [[ -n ${uploadlink} ]]; then
                _log_upload_session
                _upload_file_from_uri
                if [[ -n ${upload_body} ]]; then
                    _collect_file_info
                    _normal_logging
                    _remove_upload_session
                else
                    _error_logging
                fi
            else
                _error_logging
            fi
        }

        __file="${HOME}/.google-drive-upload/${slug}__::__${folder_id}__::__${inputsize}"
        # https://developers.google.com/drive/api/v3/manage-uploads
        if [[ -r "${__file}" ]]; then
            uploadlink="$(< "${__file}")"
            http_code="$(curl --compressed -s -X PUT "${uploadlink}" --write-out %"{http_code}")"
            if [[ ${http_code} = "308" ]]; then # Active Resumable URI give 308 status
                uploaded_range="$(: "$(curl --compressed -s \
                    -X PUT \
                    -H "Content-Range: bytes */${inputsize}" \
                    --url "${uploadlink}" \
                    --globoff \
                    -D -)" && : "$(printf "%s\n" "${_/*[R,r]ange: bytes=0-/}")" && read -r firstline <<< "$_" && printf "%s\n" "${firstline//$'\r'/}")"
                if [[ ${uploaded_range} =~ (^[0-9]) ]]; then
                    content_range="$(printf "bytes %s-%s/%s\n" "$((uploaded_range + 1))" "$((inputsize - 1))" "${inputsize}")"
                    content_length="$((inputsize - $((uploaded_range + 1))))"
                    [[ -z ${parallel} ]] && {
                        _print_center "justify" "Resuming interrupted upload.." "-"
                        _print_center "justify" "Uploading.." "-"
                    }
                    # shellcheck disable=SC2086 # Because unnecessary to another check because ${CURL_ARGS} won't be anything problematic.
                    # Resuming interrupted uploads needs http1.1
                    upload_body="$(curl --compressed -s \
                        --http1.1 \
                        -X PUT \
                        -H "Authorization: Bearer ${token}" \
                        -H "Content-Type: ${mime_type}" \
                        -H "Content-Range: ${content_range}" \
                        -H "Content-Length: ${content_length}" \
                        -H "Slug: ${slug}" \
                        -T "${input}" \
                        -o- \
                        --url "${uploadlink}" \
                        --globoff)" || :
                    if [[ -n ${upload_body} ]]; then
                        _collect_file_info
                        _normal_logging resume
                        _remove_upload_session
                    else
                        _error_logging
                    fi
                else
                    [[ -z ${parallel} ]] && _print_center "justify" "Generating upload link.." "-"
                    _full_upload
                fi
            elif [[ ${http_code} =~ 40* ]]; then # Dead Resumable URI give 400,404.. status
                [[ -z ${parallel} ]] && _print_center "justify" "Generating upload link.." "-"
                _full_upload
            elif [[ ${http_code} =~ [200,201] ]]; then # Completed Resumable URI give 200 or 201 status
                upload_body="${http_code}"
                _collect_file_info
                _normal_logging
                _remove_upload_session
            fi
        else
            [[ -z ${parallel} ]] && _print_center "justify" "Generating upload link.." "-"
            _full_upload
        fi
    fi
}

###################################################
# Share a gdrive file/folder
# Globals: 2 variables, 2 functions
#   Variables - API_URL and API_VERSION
#   Functions - _url_encode, _json_value
# Arguments: 3
#   ${1} = gdrive ID of folder/file
#   ${2} = Access Token
#   ${3} = Email to which file will be shared ( optional )
# Result: read description
# Reference:
#   https://developers.google.com/drive/api/v3/manage-sharing
###################################################
_share_id() {
    [[ $# -lt 2 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare id="${1}" token="${2}" share_email="${3}" role="reader" type="anyone"
    declare type share_post_data share_post_data share_response share_id

    if [[ -n ${share_email} ]]; then
        type="user"
        share_post_data="{\"role\":\"${role}\",\"type\":\"${type}\",\"emailAddress\":\"${share_email}\"}"
    else
        share_post_data="{\"role\":\"${role}\",\"type\":\"${type}\"}"
    fi
    share_response="$(curl --compressed -s \
        -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "${share_post_data}" \
        "${API_URL}/drive/${API_VERSION}/files/${id}/permissions")"

    share_id="$(_json_value id 1 <<< "${share_response}")"
    [[ -z "${share_id}" ]] && _json_value message 1 <<< "${share_response}" && return 1
}

###################################################
# Process all arguments given to the script
# Globals: 1 variable, 2 functions
#   Variable - HOME
#   Functions - _short_help, _remove_array_duplicates
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
    unset FIRST_INPUT FOLDER_INPUT FOLDERNAME FINAL_INPUT_ARRAY INPUT_ARRAY
    unset PARALLEL NO_OF_PARALLEL_JOBS SHARE SHARE_EMAIL OVERWRITE SKIP_DUPLICATES SKIP_SUBDIRS ROOTDIR QUIET
    unset VERBOSE VERBOSE_PROGRESS DEBUG LOG_FILE_ID
    CURL_ARGS="-#"
    INFO_PATH="${HOME}/.google-drive-upload"
    CONFIG="$(< "${INFO_PATH}/google-drive-upload.configpath")" &> /dev/null || :

    # Grab the first and second argument and shift, only if ${1} doesn't contain -.
    { ! [[ ${1} = -* ]] && INPUT_ARRAY+=("${1}") && shift && [[ ${1} != -* ]] && FOLDER_INPUT="${1}" && shift; } || :

    # Configuration variables # Remote gDrive variables
    unset ROOT_FOLDER CLIENT_ID CLIENT_SECRET REFRESH_TOKEN ACCESS_TOKEN
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"
    SCOPE="${API_URL}/auth/drive"
    REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
    TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _check_config() {
        { [[ ${1} = default* ]] && UPDATE_DEFAULT_CONFIG="true"; } || :
        { [[ -r ${2} ]] && CONFIG="${2}"; } || {
            printf "Error: Given config file (%s) doesn't exist/not readable,..\n" "${1}" 1>&2 && exit 1
        }
    }

    _check_longoptions() {
        { [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1; } || :
    }

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                _usage
                ;;
            -D | --debug)
                DEBUG="true"
                export DEBUG
                ;;
            -u | --update)
                _check_debug && _update
                ;;
            -U | --uninstall)
                _check_debug && _update uninstall
                ;;
            --info)
                _version_info
                ;;
            -C | --create-dir)
                _check_longoptions "${1}" "${2}"
                FOLDERNAME="${2}" && shift
                ;;
            -r | --root-dir)
                _check_longoptions "${1}" "${2}"
                ROOTDIR="${2/default=/}"
                { [[ ${2} = default* ]] && UPDATE_DEFAULT_ROOTDIR="_update_config"; } || :
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
            -s | --skip-subdirs)
                SKIP_SUBDIRS="true"
                ;;
            -p | --parallel)
                _check_longoptions "${1}" "${2}"
                NO_OF_PARALLEL_JOBS="${2}"
                case "${NO_OF_PARALLEL_JOBS}" in
                    '' | *[!0-9]*)
                        printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                        exit 1
                        ;;
                    *)
                        [[ ${NO_OF_PARALLEL_JOBS} -gt 10 ]] && { NO_OF_PARALLEL_JOBS=10 || NO_OF_PARALLEL_JOBS="${2}"; }
                        ;;
                esac
                PARALLEL_UPLOAD="true" && shift
                ;;
            -o | --overwrite)
                OVERWRITE="Overwrite" && UPLOAD_METHOD="update"
                ;;
            -d | --skip-duplicates)
                SKIP_DUPLICATES="Skip Existing" && UPLOAD_METHOD="update"
                ;;
            -f | --file | --folder)
                _check_longoptions "${1}" "${2}"
                INPUT_ARRAY+=("${2}") && shift
                ;;
            -S | --share)
                SHARE="true"
                EMAIL_REGEX="^([A-Za-z]+[A-Za-z0-9]*\+?((\.|\-|\_)?[A-Za-z]+[A-Za-z0-9]*)*)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
                if [[ -n ${1} && ! ${1} =~ ^(\-|\-\-) ]]; then
                    SHARE_EMAIL="${2}" && ! [[ ${SHARE_EMAIL} =~ ${EMAIL_REGEX} ]] && printf "\nError: Provided email address for share option is invalid.\n" && exit 1
                    shift
                fi
                ;;
            -q | --quiet)
                QUIET="_print_center_quiet" && CURL_ARGS="-s"
                ;;
            -v | --verbose)
                VERBOSE="true"
                ;;
            -V | --verbose-progress)
                VERBOSE_PROGRESS="true" && CURL_ARGS=""
                ;;
            '')
                shorthelp
                ;;
            *)
                # Check if user meant it to be a flag
                if [[ ${1} = -* ]]; then
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    # If no "-" is detected in 1st arg, it adds to input
                    INPUT_ARRAY+=("${1}")
                    # if the 2nd arg available and doesn't start with "-", then set as folder input
                    # do above only if 3rd arg is either absent or doesn't start with "-"
                    if [[ -n ${2} && ${2} != -* ]] && { [[ -z ${3} ]] || [[ ${3} != -* ]]; }; then
                        FOLDER_INPUT="${2}" && shift
                    fi
                fi
                ;;
        esac
        shift
    done

    # If no input, then check if -C option was used or not.
    if [[ -z ${INPUT_ARRAY[0]} && -z ${FOLDERNAME} ]]; then
        _short_help
    else
        # check if given input exists ( file/folder )
        for array in "${INPUT_ARRAY[@]}"; do
            { [[ -f ${array} || -d ${array} ]] && FINAL_INPUT_ARRAY+=("${array[@]}"); } || {
                printf "\nError: Invalid Input ( %s ), no such file or directory.\n" "${array}"
                exit 1
            }
        done
    fi
    mapfile -t FINAL_INPUT_ARRAY <<< "$(_remove_array_duplicates "${FINAL_INPUT_ARRAY[@]}")"

    # Get foldername, prioritise the input given by -C/--create-dir option.
    { [[ -n ${FOLDER_INPUT} && -z ${FOLDERNAME} ]] && FOLDERNAME="${FOLDER_INPUT}"; } || :

    { [[ -n ${VERBOSE_PROGRESS} && -n ${VERBOSE} ]] && unset "${VERBOSE}"; } || :
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
    type -p mktemp &> /dev/null && { TMPFILE="$(mktemp -u)" || TMPFILE="${PWD}/$((RANDOM * 2)).LOG"; }
    trap 'rm -f "${TMPFILE}"SUCCESS ; rm -f "${TMPFILE}"ERROR' EXIT
}

###################################################
# Check Oauth credentials and create/update config file
# Client ID, Client Secret, Refesh Token and Access Token
# Globals: 10 variables, 2 functions
#   Variables - API_URL, API_VERSION, TOKEN URL,
#               CONFIG, UPDATE_DEFAULT_CONFIG, INFO_PATH,
#               CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN and ACCESS_TOKEN
#   Functions - _update_config and _print_center
# Arguments: None
# Result: read description
###################################################
_check_credentials() {
    # shellcheck source=/dev/null
    # Config file is created automatically after first run
    if [[ -r ${CONFIG} ]]; then
        source "${CONFIG}"
        if [[ -n ${UPDATE_DEFAULT_CONFIG} ]]; then
            printf "%s\n" "${CONFIG}" >| "${INFO_PATH}/google-drive-upload.configpath"
        fi
    fi

    [[ -z ${CLIENT_ID} ]] && read -r -p "Client ID: " CLIENT_ID && {
        [[ -z ${CLIENT_ID} ]] && printf "Error: No value provided.\n" 1>&2 && exit 1
        _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"
    }

    [[ -z ${CLIENT_SECRET} ]] && read -r -p "Client Secret: " CLIENT_SECRET && {
        [[ -z ${CLIENT_SECRET} ]] && printf "Error: No value provided.\n" 1>&2 && exit 1
        _update_config CLIENT_SECRET "${CLIENT_SECRET}" "${CONFIG}"
    }

    # Method to obtain refresh_token.
    # Requirements: client_id, client_secret and authorization code.
    if [[ -z ${REFRESH_TOKEN} ]]; then
        read -r -p "If you have a refresh token generated, then type the token, else leave blank and press return key..
    Refresh Token: " REFRESH_TOKEN && REFRESH_TOKEN="${REFRESH_TOKEN//[[:space:]]/}"
        if [[ -n ${REFRESH_TOKEN} ]]; then
            _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
        else
            printf "\nVisit the below URL, tap on allow and then enter the code obtained:\n"
            URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
            printf "%s\n" "${URL}" && read -r -p "Enter the authorization code: " CODE
            CODE="${CODE//[[:space:]]/}"
            if [[ -n ${CODE} ]]; then
                RESPONSE="$(curl --compressed -s -X POST \
                    --data "code=${CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")"

                ACCESS_TOKEN="$(_json_value access_token <<< "${RESPONSE}")"
                REFRESH_TOKEN="$(_json_value refresh_token <<< "${RESPONSE}")"

                if [[ -n ${ACCESS_TOKEN} && -n ${REFRESH_TOKEN} ]]; then
                    _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
                    _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
                else
                    printf "Error: Wrong code given, make sure you copy the exact code.\n"
                    exit 1
                fi
            else
                printf "\n"
                _print_center "normal" "No code provided, run the script and try again" " "
                exit 1
            fi
        fi
    fi

    # Method to regenerate access_token ( also updates in config ).
    # Make a request on https://www.googleapis.com/oauth2/""${API_VERSION}""/tokeninfo?access_token=${ACCESS_TOKEN} url and check if the given token is valid, if not generate one.
    # Requirements: Refresh Token
    _get_token_and_update() {
        RESPONSE="$(curl --compressed -s -X POST --data "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" "${TOKEN_URL}")"
        ACCESS_TOKEN="$(_json_value access_token <<< "${RESPONSE}")"
        _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
    }
    if [[ -z ${ACCESS_TOKEN} ]]; then
        _get_token_and_update
    elif curl --compressed -s "${API_URL}/oauth2/${API_VERSION}/tokeninfo?access_token=${ACCESS_TOKEN}" | _json_value error_description &> /dev/null; then
        _get_token_and_update
    fi
}

###################################################
# Setup root directory where all file/folders will be uploaded/updated
# Globals: 6 variables, 4 functions
#   Variables - ROOTDIR, ROOT_FOLDER, UPDATE_DEFAULT_ROOTDIR, CONFIG, QUIET, ACCESS_TOKEN
#   Functions - _print_center, _drive_info, _extract_id, _update_config
# Arguments: 1
#   ${1} = Positive integer ( amount of time in seconds to sleep )
# Result: read description
#   If root id not found then pribt message and exit
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#use-read-as-an-alternative-to-the-sleep-command
###################################################
_setup_root_dir() {
    _check_root_id() {
        ROOT_FOLDER="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "id" "${ACCESS_TOKEN}")" || {
            { [[ ${ROOT_FOLDER} =~ "File not found" ]] && "${QUIET:-_print_center}" "justify" "Given root folder " " ID/URL invalid." "="; } || { printf "%s\n" "${ROOT_FOLDER}"; }
            exit 1
        }
        if [[ -n ${ROOT_FOLDER} ]]; then
            "${1:-_update_config}" ROOT_FOLDER "${ROOT_FOLDER}" "${CONFIG}"
        else
            "${QUIET:-_print_center}" "justify" "Given root folder " " ID/URL invalid." "="
            exit 1
        fi
    }
    if [[ -n ${ROOTDIR:-} ]]; then
        ROOT_FOLDER="${ROOTDIR//[[:space:]]/}"
        { [[ -n ${ROOT_FOLDER} ]] && _check_root_id "${UPDATE_DEFAULT_ROOTDIR}"; } || :
    elif [[ -z ${ROOT_FOLDER} ]]; then
        read -r -p "Root Folder ID or URL (Default: root): " ROOT_FOLDER
        ROOT_FOLDER="${ROOT_FOLDER//[[:space:]]/}"
        if [[ -n ${ROOT_FOLDER} ]]; then
            _check_root_id
        else
            ROOT_FOLDER="root"
            _update_config ROOT_FOLDER "${ROOT_FOLDER}" "${CONFIG}"
        fi
    fi
}

###################################################
# Setup Workspace folder
# Check if the given folder exists in google drive.
# If not then the folder is created in google drive under the configured root folder.
# Globals: 3 variables, 2 functions
#   Variables - FOLDERNAME, ROOT_FOLDER, ACCESS_TOKEN
#   Functions - _create_directory, _drive_info
# Arguments: None
# Result: read description
###################################################
_setup_workspace() {
    if [[ -z ${FOLDERNAME} ]]; then
        WORKSPACE_FOLDER_ID="${ROOT_FOLDER}"
    else
        WORKSPACE_FOLDER_ID="$(_create_directory "${FOLDERNAME}" "${ROOT_FOLDER}" "${ACCESS_TOKEN}")"
    fi
    WORKSPACE_FOLDER_NAME="$(_drive_info "${WORKSPACE_FOLDER_ID}" name "${ACCESS_TOKEN}")"
}

###################################################
# Process all the values in "${FINAL_INPUT_ARRAY[@]}"
# Globals: 20 variables, 15 functions
#   Variables - FINAL_INPUT_ARRAY ( array ), ACCESS_TOKEN, VERBOSE, VERBOSE_PROGRESS
#               WORKSPACE_FOLDER_ID, UPLOAD_METHOD, SKIP_DUPLICATES, OVERWRITE, SHARE,
#               UPLOAD_STATUS, COLUMNS, API_URL, API_VERSION, LOG_FILE_ID
#               FILE_ID, FILE_LINK,
#               PARALLEL_UPLOAD, QUIET, NO_OF_PARALLEL_JOBS, TMPFILE
#   Functions - _print_center, _clear_line, _newline, _is_terminal, _print_center_quiet
#               _upload_file, _share_id, _is_terminal, _bash_sleep, _dirname,
#               _create_directory, _json_value, _url_encode, _check_existing_file, _bytes_to_human
# Arguments: None
# Result: Upload all the input files/folders, if a folder is empty, print Error message.
###################################################
_process_arguments() {
    for INPUT in "${FINAL_INPUT_ARRAY[@]}"; do
        # Check if the argument is a file or a directory.
        if [[ -f ${INPUT} ]]; then
            _print_center "justify" "Given Input" ": FILE" "="
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            _upload_file "${UPLOAD_METHOD:-create}" "${INPUT}" "${WORKSPACE_FOLDER_ID}" "${ACCESS_TOKEN}"
            FILE_ID="${SKIP_DUPLICATES_FILE_ID:-${FILE_ID}}"
            [[ ${UPLOAD_STATUS} = ERROR ]] && for _ in {1..2}; do _clear_line 1; done && continue
            if [[ -n "${SHARE}" ]]; then
                _print_center "justify" "Sharing the file.." "-"
                if SHARE_MSG="$(_share_id "${FILE_ID}" "${ACCESS_TOKEN}" "${SHARE_EMAIL}")"; then
                    printf "%s\n" "${SHARE_MSG}"
                else
                    _clear_line 1
                fi
            fi
            _print_center "justify" "DriveLink" "${SHARE:-}" "-"
            _is_terminal && _print_center "normal" "$(printf "\xe2\x86\x93 \xe2\x86\x93 \xe2\x86\x93\n")" " "
            _print_center "normal" "${FILE_LINK}" " "
            printf "\n"
        elif [[ -d ${INPUT} ]]; then
            INPUT="$(_full_path "${INPUT}")" # to handle _dirname when current directory (.) is given as input.
            unset EMPTY                      # Used when input folder is empty
            parallel="${PARALLEL_UPLOAD:-}"  # Unset PARALLEL value if input is file, for preserving the logging output.

            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "="
            _print_center "justify" "Given Input" ": FOLDER" "-" && _newline "\n"
            FOLDER_NAME="${INPUT##*/}" && _print_center "justify" "Folder: ${FOLDER_NAME}" "="

            NEXTROOTDIRID="${WORKSPACE_FOLDER_ID}"

            # Skip the sub folders and find recursively all the files and upload them.
            if [[ -n ${SKIP_SUBDIRS} ]]; then
                _print_center "justify" "Indexing files recursively.." "-"
                mapfile -t FILENAMES <<< "$(find "${INPUT}" -type f)"
                if [[ -n ${FILENAMES[0]} ]]; then
                    NO_OF_FILES="${#FILENAMES[@]}"
                    for _ in {1..2}; do _clear_line 1; done
                    "${QUIET:-_print_center}" "justify" "Folder: ${FOLDER_NAME} " "| ${NO_OF_FILES} File(s)" "=" && printf "\n"
                    _print_center "justify" "Creating folder.." "-"
                    ID="$(_create_directory "${INPUT}" "${NEXTROOTDIRID}" "${ACCESS_TOKEN}")" && _clear_line 1
                    DIRIDS[1]="${ID}"
                    if [[ -n ${parallel} ]]; then
                        { [[ ${NO_OF_PARALLEL_JOBS} -gt ${NO_OF_FILES} ]] && NO_OF_PARALLEL_JOBS_FINAL="${NO_OF_FILES}"; } || { NO_OF_PARALLEL_JOBS_FINAL="${NO_OF_PARALLEL_JOBS}"; }
                        # Export because xargs cannot access if it is just an internal variable.
                        export ID CURL_ARGS="-s" ACCESS_TOKEN OVERWRITE COLUMNS API_URL API_VERSION LOG_FILE_ID SKIP_DUPLICATES QUIET UPLOAD_METHOD
                        export -f _upload_file _print_center _clear_line _json_value _url_encode _check_existing_file _print_center_quiet _newline _bytes_to_human

                        [[ -f ${TMPFILE}SUCCESS ]] && rm "${TMPFILE}"SUCCESS
                        [[ -f ${TMPFILE}ERROR ]] && rm "${TMPFILE}"ERROR

                        # shellcheck disable=SC2016
                        printf "%s\n" "${FILENAMES[@]}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS_FINAL}" -i bash -c '
                        _upload_file "${UPLOAD_METHOD:-create}" "{}" "${ID}" "${ACCESS_TOKEN}" parallel
                        ' 1>| "${TMPFILE}"SUCCESS 2>| "${TMPFILE}"ERROR &

                        while true; do [[ -f "${TMPFILE}"SUCCESS || -f "${TMPFILE}"ERROR ]] && { break || _bash_sleep 0.5; }; done

                        _newline "\n"
                        ERROR_STATUS=0 SUCCESS_STATUS=0
                        while true; do
                            SUCCESS_STATUS="$(_count < "${TMPFILE}"SUCCESS)"
                            ERROR_STATUS="$(_count < "${TMPFILE}"ERROR)"
                            _bash_sleep 1
                            if [[ $(((SUCCESS_STATUS + ERROR_STATUS))) != "${TOTAL}" ]]; then
                                _clear_line 1 && "${QUIET:-_print_center}" "justify" "Status" ": ${SUCCESS_STATUS} Uploaded | ${ERROR_STATUS} Failed" "="
                            fi
                            TOTAL="$(((SUCCESS_STATUS + ERROR_STATUS)))"
                            [[ ${TOTAL} = "${NO_OF_FILES}" ]] && break
                        done
                        for _ in {1..2}; do _clear_line 1; done
                        [[ -z ${VERBOSE:-${VERBOSE_PROGRESS}} ]] && _newline "\n\n"
                    else
                        [[ -z ${VERBOSE:-${VERBOSE_PROGRESS}} ]] && _newline "\n"

                        ERROR_STATUS=0 SUCCESS_STATUS=0
                        for file in "${FILENAMES[@]}"; do
                            DIRTOUPLOAD="${ID}"
                            _upload_file "${UPLOAD_METHOD:-create}" "${file}" "${DIRTOUPLOAD}" "${ACCESS_TOKEN}"
                            [[ ${UPLOAD_STATUS} = ERROR ]] && ERROR_STATUS="$((ERROR_STATUS + 1))" || SUCCESS_STATUS="$((SUCCESS_STATUS + 1))" || :
                            if [[ -n ${VERBOSE:-${VERBOSE_PROGRESS}} ]]; then
                                _print_center "justify" "Status: ${SUCCESS_STATUS} Uploaded" " | ${ERROR_STATUS} Failed" "=" && _newline "\n"
                            else
                                for _ in {1..2}; do _clear_line 1; done
                                _print_center "justify" "Status: ${SUCCESS_STATUS} Uploaded" " | ${ERROR_STATUS} Failed" "="
                            fi
                        done
                    fi
                else
                    _newline "\n" && EMPTY=1
                fi
            else
                _print_center "justify" "Indexing files/sub-folders" " recursively.." "-"
                # Do not create empty folders during a recursive upload. Use of find in this section is important.
                mapfile -t DIRNAMES <<< "$(find "${INPUT}" -type d -not -empty)"
                NO_OF_FOLDERS="${#DIRNAMES[@]}" && NO_OF_SUB_FOLDERS="$((NO_OF_FOLDERS - 1))"
                # Create a loop and make folders according to list made above.
                if [[ ${NO_OF_SUB_FOLDERS} != 0 ]]; then
                    _clear_line 1
                    _print_center "justify" "${NO_OF_SUB_FOLDERS} Sub-folders found." "="
                fi
                _print_center "justify" "Indexing files.." "="
                mapfile -t FILENAMES <<< "$(find "${INPUT}" -type f)"
                if [[ -n ${FILENAMES[0]} ]]; then
                    NO_OF_FILES="${#FILENAMES[@]}"
                    for _ in {1..3}; do _clear_line 1; done
                    if [[ ${NO_OF_SUB_FOLDERS} != 0 ]]; then
                        "${QUIET:-_print_center}" "justify" "${FOLDER_NAME} " "| ${NO_OF_FILES} File(s) | ${NO_OF_SUB_FOLDERS} Sub-folders" "="
                    else
                        "${QUIET:-_print_center}" "justify" "${FOLDER_NAME} " "| ${NO_OF_FILES} File(s)" "="
                    fi
                    _newline "\n"
                    _print_center "justify" "Creating Folder(s).." "-"
                    { [[ ${NO_OF_SUB_FOLDERS} != 0 ]] && _newline "\n"; } || :

                    unset status DIRIDS
                    for dir in "${DIRNAMES[@]}"; do
                        if [[ -n ${status} ]]; then
                            __dir="$(_dirname "${dir}")"
                            __temp="$(printf "%s\n" "${DIRIDS[@]}" | grep "|:_//_:|${__dir}|:_//_:|")"
                            NEXTROOTDIRID="$(printf "%s\n" "${__temp//"|:_//_:|"${__dir}*/}")"
                        fi
                        NEWDIR="${dir##*/}"
                        [[ ${NO_OF_SUB_FOLDERS} != 0 ]] && _print_center "justify" "Name: ${NEWDIR}" "-"
                        ID="$(_create_directory "${NEWDIR}" "${NEXTROOTDIRID}" "${ACCESS_TOKEN}")"
                        # Store sub-folder directory IDs and it's path for later use.
                        ((status += 1))
                        DIRIDS[${status}]="$(printf "%s|:_//_:|%s|:_//_:|\n" "${ID}" "${dir}" && printf "\n")"
                        if [[ ${NO_OF_SUB_FOLDERS} != 0 ]]; then
                            for _ in {1..2}; do _clear_line 1; done
                            _print_center "justify" "Status" ": ${status} / ${NO_OF_FOLDERS}" "="
                        fi
                    done

                    if [[ ${NO_OF_SUB_FOLDERS} != 0 ]]; then
                        for _ in {1..2}; do _clear_line 1; done
                    else
                        _clear_line 1
                    fi
                    _print_center "justify" "Preparing to upload.." "-"

                    unset status
                    for file in "${FILENAMES[@]}"; do
                        __rootdir="$(_dirname "${file}")"
                        ((status += 1))
                        FINAL_LIST[${status}]="$(printf "%s\n" "${__rootdir}|:_//_:|$(__temp="$(printf "%s\n" "${DIRIDS[@]}" | grep "|:_//_:|${__rootdir}|:_//_:|")" &&
                            printf "%s\n" "${__temp//"|:_//_:|"${__rootdir}*/}")|:_//_:|${file}")"
                    done

                    if [[ -n ${parallel} ]]; then
                        { [[ ${NO_OF_PARALLEL_JOBS} -gt ${NO_OF_FILES} ]] && NO_OF_PARALLEL_JOBS_FINAL="${NO_OF_FILES}"; } || { NO_OF_PARALLEL_JOBS_FINAL="${NO_OF_PARALLEL_JOBS}"; }
                        # Export because xargs cannot access if it is just an internal variable.
                        export CURL_ARGS="-s" ACCESS_TOKEN OVERWRITE COLUMNS API_URL API_VERSION LOG_FILE_ID SKIP_DUPLICATES QUIET UPLOAD_METHOD
                        export -f _upload_file _print_center _clear_line _json_value _url_encode _check_existing_file _print_center_quiet _newline _bytes_to_human

                        [[ -f "${TMPFILE}"SUCCESS ]] && rm "${TMPFILE}"SUCCESS
                        [[ -f "${TMPFILE}"ERROR ]] && rm "${TMPFILE}"ERROR

                        # shellcheck disable=SC2016
                        printf "%s\n" "${FINAL_LIST[@]}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS_FINAL}" -i bash -c '
                        LIST="{}"
                        FILETOUPLOAD="${LIST//*"|:_//_:|"}"
                        DIRTOUPLOAD="$(: "|:_//_:|""${FILETOUPLOAD}" && : "${LIST::-${#_}}" && printf "%s\n" "${_//*"|:_//_:|"}")"
                        _upload_file "${UPLOAD_METHOD:-create}" "${FILETOUPLOAD}" "${DIRTOUPLOAD}" "${ACCESS_TOKEN}" parallel
                        ' 1>| "${TMPFILE}"SUCCESS 2>| "${TMPFILE}"ERROR &

                        while true; do [[ -f "${TMPFILE}"SUCCESS || -f "${TMPFILE}"ERROR ]] && { break || _bash_sleep 0.5; }; done

                        _clear_line 1 && _newline "\n"
                        while true; do
                            SUCCESS_STATUS="$(_count < "${TMPFILE}"SUCCESS)"
                            ERROR_STATUS="$(_count < "${TMPFILE}"ERROR)"
                            _bash_sleep 1
                            if [[ $(((SUCCESS_STATUS + ERROR_STATUS))) != "${TOTAL}" ]]; then
                                _clear_line 1 && "${QUIET:-_print_center}" "justify" "Status" ": ${SUCCESS_STATUS} Uploaded | ${ERROR_STATUS} Failed" "="
                            fi
                            TOTAL="$(((SUCCESS_STATUS + ERROR_STATUS)))"
                            [[ ${TOTAL} = "${NO_OF_FILES}" ]] && break
                        done
                        _clear_line 1

                        [[ -z ${VERBOSE:-${VERBOSE_PROGRESS}} ]] && _newline "\n"
                    else
                        _clear_line 1 && _newline "\n"
                        ERROR_STATUS=0 SUCCESS_STATUS=0
                        for LIST in "${FINAL_LIST[@]}"; do
                            FILETOUPLOAD="${LIST//*"|:_//_:|"/}"
                            DIRTOUPLOAD="$(: "|:_//_:|""${FILETOUPLOAD}" && : "${LIST::-${#_}}" && printf "%s\n" "${_//*"|:_//_:|"/}")"
                            _upload_file "${UPLOAD_METHOD:-create}" "${FILETOUPLOAD}" "${DIRTOUPLOAD}" "${ACCESS_TOKEN}"
                            [[ ${UPLOAD_STATUS} = ERROR ]] && ERROR_STATUS="$((ERROR_STATUS + 1))" || SUCCESS_STATUS="$((SUCCESS_STATUS + 1))" || :
                            if [[ -n ${VERBOSE:-${VERBOSE_PROGRESS}} ]]; then
                                _print_center "justify" "Status" ": ${SUCCESS_STATUS} Uploaded | ${ERROR_STATUS} Failed" "=" && _newline "\n"
                            else
                                for _ in {1..2}; do _clear_line 1; done
                                _print_center "justify" "Status" ": ${SUCCESS_STATUS} Uploaded | ${ERROR_STATUS} Failed" "="
                            fi
                        done
                    fi
                else
                    EMPTY=1
                fi
            fi
            if [[ ${EMPTY} != 1 ]]; then
                [[ -z ${VERBOSE:-${VERBOSE_PROGRESS}} ]] && for _ in {1..2}; do _clear_line 1; done

                if [[ ${SUCCESS_STATUS} -gt 0 ]]; then
                    if [[ -n ${SHARE} ]]; then
                        _print_center "justify" "Sharing the folder.." "-"
                        if SHARE_MSG="$(_share_id "$(read -r firstline <<< "${DIRIDS[1]}" && printf "%s\n" "${firstline/"|:_//_:|"*/}")" "${ACCESS_TOKEN}" "${SHARE_EMAIL}")"; then
                            printf "%s\n" "${SHARE_MSG}"
                        else
                            _clear_line 1
                        fi
                    fi
                    _print_center "justify" "FolderLink" "${SHARE:-}" "-"
                    _is_terminal && _print_center "normal" "$(printf "\xe2\x86\x93 \xe2\x86\x93 \xe2\x86\x93\n")" " "
                    _print_center "normal" "$(: "$(read -r firstline <<< "${DIRIDS[1]}" &&
                        printf "%s\n" "${firstline/"|:_//_:|"*/}")" && printf "%s\n" "${_/$_/https://drive.google.com/open?id=$_}")" " "
                fi
                _newline "\n"
                [[ ${SUCCESS_STATUS} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Total Files " "Uploaded: ${SUCCESS_STATUS}" "="
                [[ ${ERROR_STATUS} -gt 0 ]] && "${QUIET:-_print_center}" "justify" "Total Files " "Failed: ${ERROR_STATUS}" "="
                printf "\n"
            else
                for _ in {1..2}; do _clear_line 1; done
                "${QUIET:-_print_center}" 'justify' "Empty Folder." "-"
                printf "\n"
            fi
        fi
    done
}

main() {
    [[ $# = 0 ]] && _short_help

    UTILS_FILE="${UTILS_FILE:-./utils.sh}"
    if [[ -r ${UTILS_FILE} ]]; then
        # shellcheck source=/dev/null
        source "${UTILS_FILE}" || { printf "Error: Unable to source utils file ( %s ) .\n" "${UTILS_FILE}" && exit 1; }
    else
        printf "Error: Utils file ( %s ) not found\n" "${UTILS_FILE}"
        exit 1
    fi

    trap 'exit "$?"' INT TERM && trap 'exit "$?"' EXIT

    _check_bash_version && set -o errexit -o noclobber -o pipefail

    _setup_arguments "${@}"
    _check_debug && _check_internet
    _setup_tempfile

    START=$(printf "%(%s)T\\n" "-1")
    _print_center "justify" "Starting script" "-"

    _print_center "justify" "Checking credentials.." "-"
    _check_credentials && for _ in {1..2}; do _clear_line 1; done
    _print_center "justify" "Required credentials available." "-"

    _print_center "justify" "Checking root dir and workspace folder.." "-"
    _setup_root_dir && for _ in {1..2}; do _clear_line 1; done
    _print_center "justify" "Root dir properly configured." "-"

    _print_center "justify" "Checking Workspace Folder.." "-"
    _setup_workspace && for _ in {1..2}; do _clear_line 1; done
    _print_center "justify" "Workspace Folder: ${WORKSPACE_FOLDER_NAME}" "="
    _print_center "normal" " ${WORKSPACE_FOLDER_ID} " "-" && _newline "\n"

    _process_arguments

    END="$(printf "%(%s)T\\n" "-1")"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="
}

main "${@}"
