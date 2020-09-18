#!/usr/bin/env sh

###################################################
# Used in collecting file properties from output json after a file has been uploaded/cloned
# Also handles logging in log file if LOG_FILE_ID is set
# Globals: 1 variables, 2 functions
#   Variables - LOG_FILE_ID
#   Functions - _error_logging_upload, _json_value
# Arguments: 1
#   ${1} = output jsom
# Result: set fileid and link, save info to log file if required
###################################################
_collect_file_info() {
    json_collect_file_info="${1}" info_collect_file_info=""
    FILE_ID="$(printf "%s\n" "${json_collect_file_info}" | _json_value id 1 1)" || { _error_logging_upload "${2}" "${json_collect_file_info}" && return 1; }
    { [ -z "${LOG_FILE_ID}" ] || [ -d "${LOG_FILE_ID}" ]; } && return 0
    info_collect_file_info="$(
        printf "%s\n" "Link: https://drive.google.com/open?id=${FILE_ID}"
        printf "%s\n" "Name: $(printf "%s\n" "${json_collect_file_info}" | _json_value name 1 1 || :)"
        printf "%s\n" "ID: ${FILE_ID}"
        printf "%s\n" "Type: $(printf "%s\n" "${json_collect_file_info}" | _json_value mimeType 1 1 || :)"
    )"
    printf "%s\n" "${info_collect_file_info}" >> "${LOG_FILE_ID}"
    return 0
}

###################################################
# Error logging wrapper
###################################################
_error_logging_upload() {
    "${QUIET:-_print_center}" "justify" "Upload ERROR" ", ${1:-} not ${STRING:-uploaded}." "=" 1>&2
    printf "%s\n" "${2}" 1>&2
    printf "\n\n\n" 1>&2
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
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    folder_id_drive_info="${1}" fetch_drive_info="${2}" token_drive_info="${3}"
    unset search_response_drive_info

    "${EXTRA_LOG}" "justify" "Fetching info.." "-" 1>&2
    search_response_drive_info="$(curl --compressed "${CURL_PROGRESS_EXTRA}" \
        -H "Authorization: Bearer ${token_drive_info}" \
        "${API_URL}/drive/${API_VERSION}/files/${folder_id_drive_info}?fields=${fetch_drive_info}&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    printf "%b" "${search_response_drive_info:+${search_response_drive_info}\n}"
    return 0
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
_check_existing_file() (
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    name_check_existing_file="${1##*/}" rootdir_check_existing_file="${2}" token_check_existing_file="${3}"
    unset query_check_existing_file response_check_existing_file id_check_existing_file

    "${EXTRA_LOG}" "justify" "Checking if file" " exists on gdrive.." "-" 1>&2
    query_check_existing_file="$(_url_encode "name='${name_check_existing_file}' and '${rootdir_check_existing_file}' in parents and trashed=false and 'me' in writers")"

    response_check_existing_file="$(curl --compressed "${CURL_PROGRESS_EXTRA}" \
        -H "Authorization: Bearer ${token_check_existing_file}" \
        "${API_URL}/drive/${API_VERSION}/files?q=${query_check_existing_file}&fields=files(id,name,mimeType)&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    { printf "%s\n" "${response_check_existing_file}" | _json_value id 1 1 2>| /dev/null 1>&2 && printf "%s\n" "${response_check_existing_file}"; } || return 1
    return 0
)

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
_create_directory() (
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    dirname_create_directory="${1##*/}" rootdir_create_directory="${2}" token_create_directory="${3}"
    unset query_create_directory search_response_create_directory folder_id_create_directory

    "${EXTRA_LOG}" "justify" "Creating GDRIVE DIR:" " ${dirname_create_directory}" "-" 1>&2
    query_create_directory="$(_url_encode "mimeType='application/vnd.google-apps.folder' and name='${dirname_create_directory}' and trashed=false and '${rootdir_create_directory}' in parents")"

    search_response_create_directory="$(curl --compressed "${CURL_PROGRESS_EXTRA}" \
        -H "Authorization: Bearer ${token_create_directory}" \
        "${API_URL}/drive/${API_VERSION}/files?q=${query_create_directory}&fields=files(id)&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2

    if ! folder_id_create_directory="$(printf "%s\n" "${search_response_create_directory}" | _json_value id 1 1)"; then
        unset create_folder_post_data_create_directory create_folder_response_create_directory
        create_folder_post_data_create_directory="{\"mimeType\": \"application/vnd.google-apps.folder\",\"name\": \"${dirname_create_directory}\",\"parents\": [\"${rootdir_create_directory}\"]}"
        create_folder_response_create_directory="$(curl --compressed "${CURL_PROGRESS_EXTRA}" \
            -X POST \
            -H "Authorization: Bearer ${token_create_directory}" \
            -H "Content-Type: application/json; charset=UTF-8" \
            -d "${create_folder_post_data_create_directory}" \
            "${API_URL}/drive/${API_VERSION}/files?fields=id&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2
    fi
    _clear_line 1 1>&2

    { folder_id_create_directory="${folder_id_create_directory:-$(printf "%s\n" "${create_folder_response_create_directory}" | _json_value id 1 1)}" && printf "%s\n" "${folder_id_create_directory}"; } ||
        { printf "%s\n" "${create_folder_response_create_directory}" 1>&2 && return 1; }
    return 0
)

###################################################
# Sub functions for _upload_file function - Start
# generate resumable upload link
_generate_upload_link() {
    "${EXTRA_LOG}" "justify" "Generating upload link.." "-" 1>&2
    uploadlink_upload_file="$(curl --compressed "${CURL_PROGRESS_EXTRA}" \
        -X "${request_method_upload_file}" \
        -H "Authorization: Bearer ${token_upload_file}" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -H "X-Upload-Content-Type: ${mime_type_upload_file}" \
        -H "X-Upload-Content-Length: ${inputsize_upload_file}" \
        -d "$postdata_upload_file" \
        "${url_upload_file}" \
        -D - || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    uploadlink_upload_file="$(printf "%s\n" "${uploadlink_upload_file##*[L,l]ocation: }" | while read -r line; do printf "%s\n" "${line%%$(printf '\r')}" && break; done)"
    { [ -n "${uploadlink_upload_file}" ] && return 0; } || return 1
}

# Curl command to push the file to google drive.
_upload_file_from_uri() {
    _print_center "justify" "Uploading.." "-"
    # shellcheck disable=SC2086 # Because unnecessary to another check because ${CURL_PROGRESS} won't be anything problematic.
    upload_body_upload_file="$(curl --compressed ${CURL_PROGRESS} \
        -X PUT \
        -H "Authorization: Bearer ${token_upload_file}" \
        -H "Content-Type: ${mime_type_upload_file}" \
        -H "Content-Length: ${content_length_upload_file}" \
        -H "Slug: ${slug_upload_file}" \
        -T "${input_upload_file}" \
        -o- \
        --url "${uploadlink_upload_file}" \
        --globoff \
        ${CURL_SPEED} ${resume_args1} ${resume_args2} \
        -H "${resume_args3}" || :)"
    [ -z "${VERBOSE_PROGRESS}" ] && for _ in 1 2; do _clear_line 1; done && "${1:-:}"
    return 0
}

# logging in case of successful upload
_normal_logging_upload() {
    [ -z "${VERBOSE_PROGRESS}" ] && _clear_line 1
    "${QUIET:-_print_center}" "justify" "${slug_upload_file} " "| ${readable_size_upload_file} | ${STRING}" "="
    return 0
}

# Tempfile Used for resuming interrupted uploads
_log_upload_session() {
    [ "${inputsize_upload_file}" -gt 1000000 ] && printf "%s\n" "${uploadlink_upload_file}" >| "${__file_upload_file}"
    return 0
}

# remove upload session
_remove_upload_session() {
    rm -f "${__file_upload_file}"
    return 0
}

# wrapper to fully upload a file from scratch
_full_upload() {
    _generate_upload_link || { _error_logging_upload "${slug_upload_file}" "${uploadlink_upload_file}" && return 1; }
    _log_upload_session
    _upload_file_from_uri
    _collect_file_info "${upload_body_upload_file}" "${slug_upload_file}" || return 1
    _normal_logging_upload
    _remove_upload_session
    return 0
}
# Sub functions for _upload_file function - End
###################################################

###################################################
# Upload ( Create/Update ) files on gdrive.
# Interrupted uploads can be resumed.
# Globals: 7 variables, 10 functions
#   Variables - API_URL, API_VERSION, QUIET, VERBOSE, VERBOSE_PROGRESS, CURL_PROGRESS, LOG_FILE_ID
#   Functions - _url_encode, _json_value, _print_center, _bytes_to_human
#               _generate_upload_link, _upload_file_from_uri, _log_upload_session, _remove_upload_session
#               _full_upload, _collect_file_info
# Arguments: 5
#   ${1} = update or upload ( upload type )
#   ${2} = file to upload
#   ${3} = root dir id for file
#   ${4} = Access Token
# Result: On
#   Success - Upload/Update file and export FILE_ID
#   Error - return 1
# Reference:
#   https://developers.google.com/drive/api/v3/create-file
#   https://developers.google.com/drive/api/v3/manage-uploads
#   https://developers.google.com/drive/api/v3/reference/files/update
###################################################
_upload_file() {
    [ $# -lt 4 ] && printf "Missing arguments\n" && return 1
    job_upload_file="${1}" input_upload_file="${2}" folder_id_upload_file="${3}" token_upload_file="${4}"
    unset slug_upload_file inputname_upload_file extension_upload_file inputsize_upload_file readable_size_upload_file request_method_upload_file \
        url_upload_file postdata_upload_file uploadlink_upload_file upload_body_upload_file mime_type_upload_file resume_args_upload_file

    slug_upload_file="${input_upload_file##*/}"
    inputname_upload_file="${slug_upload_file%.*}"
    extension_upload_file="${slug_upload_file##*.}"
    inputsize_upload_file="$(($(wc -c < "${input_upload_file}")))" && content_length_upload_file="${inputsize_upload_file}"
    readable_size_upload_file="$(printf "%s\n" "${inputsize_upload_file}" | _bytes_to_human)"

    # Handle extension-less files
    [ "${inputname_upload_file}" = "${extension_upload_file}" ] && {
        mime_type_upload_file="$(file --brief --mime-type "${input_upload_file}" || mimetype --output-format %m "${input_upload_file}")" 2>| /dev/null || {
            "${QUIET:-_print_center}" "justify" "Error: file or mimetype command not found." "=" && printf "\n"
            exit 1
        }
    }

    _print_center "justify" "${slug_upload_file}" " | ${readable_size_upload_file}" "="

    # Set proper variables for overwriting files
    [ "${job_upload_file}" = update ] && {
        unset file_check_json_upload_file
        # Check if file actually exists, and create if not.
        if file_check_json_upload_file="$(_check_existing_file "${slug_upload_file}" "${folder_id_upload_file}" "${token_upload_file}")"; then
            if [ -n "${SKIP_DUPLICATES}" ]; then
                # Stop upload if already exists ( -d/--skip-duplicates )
                _collect_file_info "${file_check_json_upload_file}" "${slug_upload_file}" || return 1
                _clear_line 1
                "${QUIET:-_print_center}" "justify" "${slug_upload_file} already exists." "=" && return 0
            else
                request_method_upload_file="PATCH"
                _file_id_upload_file="$(printf "%s\n" "${file_check_json_upload_file}" | _json_value id 1 1)" || { _error_logging_upload "${slug_upload_file}" "${file_check_json_upload_file}" && return 1; }
                url_upload_file="${API_URL}/upload/drive/${API_VERSION}/files/${_file_id_upload_file}?uploadType=resumable&supportsAllDrives=true&includeItemsFromAllDrives=true"
                # JSON post data to specify the file name and folder under while the file to be updated
                postdata_upload_file="{\"mimeType\": \"${mime_type_upload_file}\",\"name\": \"${slug_upload_file}\",\"addParents\": [\"${folder_id_upload_file}\"]}"
                STRING="Updated"
            fi
        else
            job_upload_file="create"
        fi
    }

    # Set proper variables for creating files
    [ "${job_upload_file}" = create ] && {
        url_upload_file="${API_URL}/upload/drive/${API_VERSION}/files?uploadType=resumable&supportsAllDrives=true&includeItemsFromAllDrives=true"
        request_method_upload_file="POST"
        # JSON post data to specify the file name and folder under while the file to be created
        postdata_upload_file="{\"mimeType\": \"${mime_type_upload_file}\",\"name\": \"${slug_upload_file}\",\"parents\": [\"${folder_id_upload_file}\"]}"
        STRING="Uploaded"
    }

    __file_upload_file="${INFO_PATH}/${slug_upload_file}__::__${folder_id_upload_file}__::__${inputsize_upload_file}"
    # https://developers.google.com/drive/api/v3/manage-uploads
    if [ -r "${__file_upload_file}" ]; then
        uploadlink_upload_file="$(cat "${__file_upload_file}" || :)"
        http_code_upload_file="$(curl --compressed -s -X PUT "${uploadlink_upload_file}" --write-out %"{http_code}")" || :
        case "${http_code_upload_file}" in
            308) # Active Resumable URI give 308 status
                uploaded_range_upload_file="$(raw_upload_file="$(curl --compressed -s -X PUT \
                    -H "Content-Range: bytes */${content_length_upload_file}" \
                    --url "${uploadlink_upload_file}" --globoff -D - || :)" &&
                    printf "%s\n" "${raw_upload_file##*[R,r]ange: bytes=0-}" | while read -r line; do printf "%s\n" "${line%%$(printf '\r')}" && break; done)"
                if [ "${uploaded_range_upload_file}" -gt 0 ] 2>| /dev/null; then
                    _print_center "justify" "Resuming interrupted upload.." "-" && _newline "\n"
                    content_range_upload_file="$(printf "bytes %s-%s/%s\n" "$((uploaded_range_upload_file + 1))" "$((inputsize_upload_file - 1))" "${inputsize_upload_file}")"
                    content_length_upload_file="$((inputsize_upload_file - $((uploaded_range_upload_file + 1))))"
                    # Resuming interrupted uploads needs http1.1
                    resume_args1='-s' resume_args2='--http1.1' resume_args3="Content-Range: ${content_range_upload_file}"
                    _upload_file_from_uri _clear_line
                    _collect_file_info "${upload_body_upload_file}" "${slug_upload_file}" || return 1
                    _normal_logging_upload
                    _remove_upload_session
                else
                    _full_upload || return 1
                fi
                ;;
            40[0-9]) # Dead Resumable URI give 40* status
                _full_upload
                ;;
            201 | 200) # Completed Resumable URI give 20* status
                upload_body_upload_file="${http_code_upload_file}"
                _collect_file_info "${upload_body_upload_file}" "${slug_upload_file}" || return 1
                _normal_logging_upload
                _remove_upload_session
                ;;
        esac
    else
        _full_upload || return 1
    fi
    return 0
}

###################################################
# A extra wrapper for _upload_file function to properly handle retries
# also handle uploads in case uploading from folder
# Globals: 3 variables, 1 function
#   Variables - RETRY, UPLOAD_MODE and ACCESS_TOKEN
#   Functions - _upload_file
# Arguments: 3
#   ${1} = parse or norparse
#   ${2} = if ${1} = parse; then final_list line ; else file to upload; fi
#   ${3} = if ${1} != parse; gdrive folder id to upload; fi
# Result: set SUCCESS var on succes
###################################################
_upload_file_main() {
    [ $# -lt 2 ] && printf "Missing arguments\n" && return 1
    [ "${1}" = parse ] && line_upload_file_main="${2}" && file_upload_file_main="${line_upload_file_main##*"|:_//_:|"}" &&
        dirid_upload_file_main="$(_tmp="${line_upload_file_main%%"|:_//_:|"${file_upload_file_main}}" &&
            printf "%s\n" "${_tmp##*"|:_//_:|"}")"

    retry_upload_file_main="${RETRY:-0}" && unset RETURN_STATUS
    until [ "${retry_upload_file_main}" -le 0 ] && [ -n "${RETURN_STATUS}" ]; do
        if [ -n "${4}" ]; then
            _upload_file "${UPLOAD_MODE:-create}" "${file_upload_file_main:-${2}}" "${dirid_upload_file_main:-${3}}" "${ACCESS_TOKEN}" 2>| /dev/null 1>&2 && RETURN_STATUS=1 && break
        else
            _upload_file "${UPLOAD_MODE:-create}" "${file_upload_file_main:-${2}}" "${dirid_upload_file_main:-${3}}" "${ACCESS_TOKEN}" && RETURN_STATUS=1 && break
        fi
        RETURN_STATUS=2 retry_upload_file_main="$((retry_upload_file_main - 1))" && continue
    done
    printf "%b" "${4:+${RETURN_STATUS}\n}" 1>&"${RETURN_STATUS}"
    return 0
}

###################################################
# Upload all files in the given folder, parallelly or non-parallely and show progress
# Globals: 2 variables, 3 functions
#   Variables - VERBOSE and VERBOSE_PROGRESS, NO_OF_PARALLEL_JOBS, NO_OF_FILES, TMPFILE, UTILS_FOLDER and QUIET
#   Functions - _clear_line, _newline, _print_center and _upload_file_main
# Arguments: 4
#   ${1} = parallel or normal
#   ${2} = parse or norparse
#   ${3} = if ${2} = parse; then final_list ; else filenames ; fi
#   ${4} = if ${2} != parse; then gdrive folder id to upload; fi
# Result: read discription, set SUCCESS_STATUS & ERROR_STATUS
###################################################
_upload_folder() {
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    mode_upload_folder="${1}" PARSE_MODE="${2}" list_upload_folder="${3}" ID="${4:-}" && export PARSE_MODE ID
    case "${mode_upload_folder}" in
        normal)
            [ "${PARSE_MODE}" = parse ] && _clear_line 1 && _newline "\n"

            while read -r line <&4; do
                _upload_file_main "${PARSE_MODE}" "${line}" "${ID}"
                : "$((RETURN_STATUS < 2 ? (SUCCESS_STATUS += 1) : (ERROR_STATUS += 1)))"
                if [ -n "${VERBOSE:-${VERBOSE_PROGRESS}}" ]; then
                    _print_center "justify" "Status: ${SUCCESS_STATUS} Uploaded" " | ${ERROR_STATUS} Failed" "=" && _newline "\n"
                else
                    for _ in 1 2; do _clear_line 1; done
                    _print_center "justify" "Status: ${SUCCESS_STATUS} Uploaded" " | ${ERROR_STATUS} Failed" "="
                fi
            done 4<< EOF
$(printf "%s\n" "${list_upload_folder}")
EOF
            ;;
        parallel)
            NO_OF_PARALLEL_JOBS_FINAL="$((NO_OF_PARALLEL_JOBS > NO_OF_FILES ? NO_OF_FILES : NO_OF_PARALLEL_JOBS))"
            [ -f "${TMPFILE}"SUCCESS ] && rm "${TMPFILE}"SUCCESS
            [ -f "${TMPFILE}"ERROR ] && rm "${TMPFILE}"ERROR

            # shellcheck disable=SC2016
            (printf "%s\n" "${list_upload_folder}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS_FINAL}" -I {} sh -c '
            eval "${SOURCE_UTILS}"
            _upload_file_main "${PARSE_MODE}" "{}" "${ID}" true
            ' 1>| "${TMPFILE}"SUCCESS 2>| "${TMPFILE}"ERROR) &
            pid="${!}"

            until [ -f "${TMPFILE}"SUCCESS ] || [ -f "${TMPFILE}"ERORR ]; do sleep 0.5; done
            [ "${PARSE_MODE}" = parse ] && _clear_line 1
            _newline "\n"

            until ! kill -0 "${pid}" 2>| /dev/null 1>&2; do
                SUCCESS_STATUS="$(($(wc -l < "${TMPFILE}"SUCCESS)))"
                ERROR_STATUS="$(($(wc -l < "${TMPFILE}"ERROR)))"
                sleep 1
                [ "$((SUCCESS_STATUS + ERROR_STATUS))" != "${TOTAL}" ] &&
                    _clear_line 1 && "${QUIET:-_print_center}" "justify" "Status" ": ${SUCCESS_STATUS} Uploaded | ${ERROR_STATUS} Failed" "="
                TOTAL="$((SUCCESS_STATUS + ERROR_STATUS))"
            done
            SUCCESS_STATUS="$(($(wc -l < "${TMPFILE}"SUCCESS)))"
            ERROR_STATUS="$(($(wc -l < "${TMPFILE}"ERROR)))"
            ;;
    esac
    return 0
}

###################################################
# Copy/Clone a public gdrive file/folder from another/same gdrive account
# Globals: 2 variables, 2 functions
#   Variables - API_URL, API_VERSION, CURL_PROGRESS, LOG_FILE_ID, QUIET
#   Functions - _check_existing_file, _json_value, _bytes_to_human, _clear_line
# Arguments: 5
#   ${1} = update or upload ( upload type )
#   ${2} = file id to upload
#   ${3} = root dir id for file
#   ${4} = Access Token
#   ${5} = name of file
#   ${6} = size of file
# Result: On
#   Success - Upload/Update file and export FILE_ID
#   Error - return 1
# Reference:
#   https://developers.google.com/drive/api/v2/reference/files/copy
###################################################
_clone_file() {
    [ $# -lt 4 ] && printf "Missing arguments\n" && return 1
    job_clone_file="${1}" file_id_clone_file="${2}" file_root_id_clone_file="${3}" token_clone_file="${4}" name_clone_file="${5}" size_clone_file="${6}"
    unset post_data_clone_file response_clone_file readable_size_clone_file && STRING="Cloned"
    post_data_clone_file="{\"parents\": [\"${file_root_id_clone_file}\"]}"
    readable_size_clone_file="$(printf "%s\n" "${size_clone_file}" | _bytes_to_human)"

    _print_center "justify" "${name_clone_file} " "| ${readable_size_clone_file}" "="

    if [ "${job_clone_file}" = update ]; then
        unset file_check_json_clone_file
        # Check if file actually exists.
        if file_check_json_clone_file="$(_check_existing_file "${name_clone_file}" "${file_root_id_clone_file}" "${token_clone_file}")"; then
            if [ -n "${SKIP_DUPLICATES}" ]; then
                _collect_file_info "${file_check_json_clone_file}" "${name_clone_file}" || return 1
                _clear_line 1
                "${QUIET:-_print_center}" "justify" "${name_clone_file}" " already exists." "=" && return 0
            else
                _print_center "justify" "Overwriting file.." "-"
                { _file_id_clone_file="$(printf "%s\n" "${file_check_json_clone_file}" | _json_value id 1 1)" &&
                    post_data_clone_file="$(_drive_info "${_file_id_clone_file}" "parents,writersCanShare" "${token_clone_file}")"; } ||
                    { _error_logging_upload "${name_clone_file}" "${post_data_clone_file:-${file_check_json_clone_file}}" && return 1; }
                if [ "${_file_id_clone_file}" != "${file_id_clone_file}" ]; then
                    curl --compressed -s \
                        -X DELETE \
                        -H "Authorization: Bearer ${token_clone_file}" \
                        "${API_URL}/drive/${API_VERSION}/files/${_file_id_clone_file}?supportsAllDrives=true&includeItemsFromAllDrives=true" 2>| /dev/null 1>&2 || :
                    STRING="Updated"
                else
                    _collect_file_info "${file_check_json_clone_file}" "${name_clone_file}" || return 1
                fi
            fi
        else
            _print_center "justify" "Cloning file.." "-"
        fi
    else
        _print_center "justify" "Cloning file.." "-"
    fi

    # shellcheck disable=SC2086
    response_clone_file="$(curl --compressed ${CURL_PROGRESS} \
        -X POST \
        -H "Authorization: Bearer ${token_clone_file}" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "${post_data_clone_file}" \
        "${API_URL}/drive/${API_VERSION}/files/${file_id_clone_file}/copy?supportsAllDrives=true&includeItemsFromAllDrives=true" || :)"
    for _ in 1 2 3; do _clear_line 1; done
    _collect_file_info "${response_clone_file}" "${name_clone_file}" || return 1
    "${QUIET:-_print_center}" "justify" "${name_clone_file} " "| ${readable_size_clone_file} | ${STRING}" "="
    return 0
}

###################################################
# Share a gdrive file/folder
# Globals: 2 variables, 4 functions
#   Variables - API_URL and API_VERSION
#   Functions - _url_encode, _json_value, _print_center, _clear_line
# Arguments: 3
#   ${1} = gdrive ID of folder/file
#   ${2} = Access Token
#   ${3} = Email to which file will be shared ( optional )
# Result: read description
# Reference:
#   https://developers.google.com/drive/api/v3/manage-sharing
###################################################
_share_id() {
    [ $# -lt 2 ] && printf "Missing arguments\n" && return 1
    id_share_id="${1}" token_share_id="${2}" share_email_share_id="${3}" role_share_id="reader" type_share_id="${share_email_share_id:+user}"
    unset post_data_share_id response_share_id

    "${EXTRA_LOG}" "justify" "Sharing.." "-" 1>&2
    post_data_share_id="{\"role\":\"${role_share_id}\",\"type\":\"${type_share_id:-anyone}\"${share_email_share_id:+,\\\"emailAddress\\\":\\\"${share_email_share_id}\\\"}}"

    response_share_id="$(curl --compressed "${CURL_PROGRESS_EXTRA}" \
        -X POST \
        -H "Authorization: Bearer ${token_share_id}" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "${post_data_share_id}" \
        "${API_URL}/drive/${API_VERSION}/files/${id_share_id}/permissions" || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    { printf "%s\n" "${response_share_id}" | _json_value id 1 1 2>| /dev/null 1>&2 && return 0; } ||
        { printf "%s\n" "Error: Cannot Share." 1>&2 && printf "%s\n" "${response_share_id}" 1>&2 && return 1; }
}
