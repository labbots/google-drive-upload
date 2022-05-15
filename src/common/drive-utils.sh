#!/usr/bin/env sh

###################################################
# Search for an existing file on gdrive with write permission.
# Arguments: 4
#   ${1} = file name
#   ${2} = root dir id of file
#   ${3} = mode ( size or md5Checksum or empty )
#   ${4} = if mode = empty, then not required
#             mode = size, then size
#             mode = md5Checksum, then md5sum
# Result: print search response if id fetched
#         check size and md5sum if mode size or md5Checksum
# Reference:
#   https://developers.google.com/drive/api/v3/search-files
###################################################
_check_existing_file() {
    export EXTRA_LOG CURL_PROGRESS_EXTRA API_URL API_VERSION
    [ $# -lt 2 ] && printf "Missing arguments\n" && return 1
    name_check_existing_file="${1}" rootdir_check_existing_file="${2}" mode_check_existing_file="${3}" param_value_check_existing_file="${4}"
    unset query_check_existing_file response_check_existing_file id_check_existing_file

    "${EXTRA_LOG}" "justify" "Checking if file" " exists on gdrive.." "-" 1>&2
    query_check_existing_file="$(_url_encode "name=\"${name_check_existing_file}\" and '${rootdir_check_existing_file}' in parents and trashed=false and 'me' in writers")"

    response_check_existing_file="$(_api_request "${CURL_PROGRESS_EXTRA}" \
        "${API_URL}/drive/${API_VERSION}/files?q=${query_check_existing_file}&fields=files(id,name,mimeType${mode_check_existing_file:+,${mode_check_existing_file}})&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    printf "%s\n" "${response_check_existing_file}" | _json_value id 1 1 2>| /dev/null 1>&2 || return 1

    [ -n "${mode_check_existing_file}" ] && {
        [ "$(printf "%s\n" "${response_check_existing_file}" | _json_value "${mode_check_existing_file}" 1 1)" = "${param_value_check_existing_file}" ] || return 1
    }

    printf "%s\n" "${response_check_existing_file}"
    return 0
}

###################################################
# Copy/Clone a public gdrive file/folder from another/same gdrive account
# Arguments: 5
#   ${1} = update or upload ( upload type )
#   ${2} = file id to upload
#   ${3} = root dir id for file
#   ${4} = name of file
#   ${5} = size of file
#   ${6} = md5sum of file
# Result: On
#   Success - Upload/Update file and export FILE_ID
#   Error - return 1
# Reference:
#   https://developers.google.com/drive/api/v2/reference/files/copy
###################################################
_clone_file() {
    export DESCRIPTION_FILE CHECK_MODE SKIP_DUPLICATES QUIET API_URL API_VERSION CURL_PROGRESS
    [ $# -lt 5 ] && printf "Missing arguments\n" && return 1
    job_clone_file="${1}" file_id_clone_file="${2}" file_root_id_clone_file="${3}" name_clone_file="${4}" size_clone_file="${5}" md5_clone_file="${6}"
    unset post_data_clone_file response_clone_file readable_size_clone_file description_clone_file && STRING="Cloned"
    readable_size_clone_file="$(_bytes_to_human "${size_clone_file}")"
    escaped_name_clone_file="$(_json_escape j "${name_clone_file}")" print_name_clone_file="$(_json_escape p "${name_clone_file}")"

    # create description data
    [ -n "${DESCRIPTION_FILE}" ] && {
        description_clone_file="$(printf "%s\n" "${DESCRIPTION_FILE}" | sed -e "s|%f|${name_clone_file}|g|" -e "s|%f|${readable_size_clone_file}|g|")"
        description_clone_file="$(_json_escape j "${description_clone_file}")" # escape for json
    }

    post_data_clone_file="{\"parents\": [\"${file_root_id_clone_file}\"]${description_clone_file:+,\"description\":\"${description_clone_file}\"}}"

    _print_center "justify" "${print_name_clone_file} " "| ${readable_size_clone_file}" "="

    if [ "${job_clone_file}" = update ]; then
        unset file_check_json_clone_file check_value_type_clone_file check_value_clone_file
        case "${CHECK_MODE}" in
            2) check_value_type_clone_file="size" check_value_clone_file="${size_clone_file}" ;;
            3) check_value_type_clone_file="md5Checksum" check_value_clone_file="${md5_clone_file}" ;;
            *) : ;;
        esac
        # Check if file actually exists.
        if file_check_json_clone_file="$(_check_existing_file "${escaped_name_clone_file}" "${file_root_id_clone_file}" "${check_value_type_clone_file}" "${check_value_clone_file}")"; then
            if [ -n "${SKIP_DUPLICATES}" ]; then
                _collect_file_info "${file_check_json_clone_file}" "${print_name_clone_file}" || return 1
                _clear_line 1
                "${QUIET:-_print_center}" "justify" "${print_name_clone_file}" " already exists." "=" && return 0
            else
                _print_center "justify" "Overwriting file.." "-"
                { _file_id_clone_file="$(printf "%s\n" "${file_check_json_clone_file}" | _json_value id 1 1)" &&
                    post_data_clone_file="$(_drive_info "${_file_id_clone_file}" "parents,writersCanShare")"; } ||
                    { _error_logging_upload "${print_name_clone_file}" "${post_data_clone_file:-${file_check_json_clone_file}}" || return 1; }
                if [ "${_file_id_clone_file}" != "${file_id_clone_file}" ]; then
                    _api_request -s \
                        -X DELETE \
                        "${API_URL}/drive/${API_VERSION}/files/${_file_id_clone_file}?supportsAllDrives=true&includeItemsFromAllDrives=true" 2>| /dev/null 1>&2 || :
                    STRING="Updated"
                else
                    _collect_file_info "${file_check_json_clone_file}" "${print_name_clone_file}" || return 1
                fi
            fi
        else
            _print_center "justify" "Cloning file.." "-"
        fi
    else
        _print_center "justify" "Cloning file.." "-"
    fi

    # shellcheck disable=SC2086
    response_clone_file="$(_api_request ${CURL_PROGRESS} \
        -X POST \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "${post_data_clone_file}" \
        "${API_URL}/drive/${API_VERSION}/files/${file_id_clone_file}/copy?supportsAllDrives=true&includeItemsFromAllDrives=true" || :)"
    for _ in 1 2 3; do _clear_line 1; done
    _collect_file_info "${response_clone_file}" "${print_name_clone_file}" || return 1
    "${QUIET:-_print_center}" "justify" "${print_name_clone_file} " "| ${readable_size_clone_file} | ${STRING}" "="
    return 0
}

###################################################
# Create/Check directory in google drive.
# Arguments: 2
#   ${1} = dir name
#   ${2} = root dir id of given dir
# Result: print folder id
# Reference:
#   https://developers.google.com/drive/api/v3/folder
###################################################
_create_directory() {
    export EXTRA_LOG CURL_PROGRESS_EXTRA API_VERSION API_URL
    [ $# -lt 2 ] && printf "Missing arguments\n" && return 1
    dirname_create_directory="${1##*/}" rootdir_create_directory="${2}"
    unset query_create_directory search_response_create_directory folder_id_create_directory
    escaped_dirname_create_directory="$(_json_escape j "${dirname_create_directory}")"
    print_dirname_create_directory="$(_json_escape p "${dirname_create_directory}")"

    "${EXTRA_LOG}" "justify" "Creating GDRIVE DIR:" " ${print_dirname_create_directory}" "-" 1>&2
    query_create_directory="$(_url_encode "mimeType='application/vnd.google-apps.folder' and name=\"${escaped_dirname_create_directory}\" and trashed=false and '${rootdir_create_directory}' in parents")"

    search_response_create_directory="$(_api_request "${CURL_PROGRESS_EXTRA}" \
        "${API_URL}/drive/${API_VERSION}/files?q=${query_create_directory}&fields=files(id)&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2

    if ! folder_id_create_directory="$(printf "%s\n" "${search_response_create_directory}" | _json_value id 1 1)"; then
        unset create_folder_post_data_create_directory create_folder_response_create_directory
        create_folder_post_data_create_directory="{\"mimeType\": \"application/vnd.google-apps.folder\",\"name\": \"${escaped_dirname_create_directory}\",\"parents\": [\"${rootdir_create_directory}\"]}"
        create_folder_response_create_directory="$(_api_request "${CURL_PROGRESS_EXTRA}" \
            -X POST \
            -H "Content-Type: application/json; charset=UTF-8" \
            -d "${create_folder_post_data_create_directory}" \
            "${API_URL}/drive/${API_VERSION}/files?fields=id&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2
    fi
    _clear_line 1 1>&2

    { folder_id_create_directory="${folder_id_create_directory:-$(printf "%s\n" "${create_folder_response_create_directory}" | _json_value id 1 1)}" && printf "%s\n" "${folder_id_create_directory}"; } ||
        { printf "%s\n" "${create_folder_response_create_directory}" 1>&2 && return 1; }
    return 0
}

###################################################
# Get information for a gdrive folder/file.
# Arguments: 2
#   ${1} = folder/file gdrive id
#   ${2} = information to fetch, e.g name, id
# Result: On
#   Success - print fetched value
#   Error   - print "message" field from the json
# Reference:
#   https://developers.google.com/drive/api/v3/search-files
###################################################
_drive_info() {
    export EXTRA_LOG CURL_PROGRESS_EXTRA API_URL API_VERSION
    [ $# -lt 2 ] && printf "Missing arguments\n" && return 1
    folder_id_drive_info="${1}" fetch_drive_info="${2}"
    unset search_response_drive_info

    "${EXTRA_LOG}" "justify" "Fetching info.." "-" 1>&2
    search_response_drive_info="$(_api_request "${CURL_PROGRESS_EXTRA}" \
        "${API_URL}/drive/${API_VERSION}/files/${folder_id_drive_info}?fields=${fetch_drive_info}&supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    printf "%b" "${search_response_drive_info:+${search_response_drive_info}\n}"
    return 0
}

###################################################
# Extract ID from a googledrive folder/file url.
# Arguments: 1
#   ${1} = googledrive folder/file url.
# Result: print extracted ID
###################################################
_extract_id() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    LC_ALL=C id_extract_id="${1}"
    case "${id_extract_id}" in
        *'drive.google.com'*'id='*) _tmp="${id_extract_id##*id=}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'file/d/'* | 'http'*'docs.google.com'*'/d/'*) _tmp="${id_extract_id##*\/d\/}" && _tmp="${_tmp%%\/*}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *'drive.google.com'*'drive'*'folders'*) _tmp="${id_extract_id##*\/folders\/}" && _tmp="${_tmp%%\?*}" && id_extract_id="${_tmp%%\&*}" ;;
        *) : ;;
    esac
    printf "%b" "${id_extract_id:+${id_extract_id}\n}"
}

###################################################
# Upload ( Create/Update ) files on gdrive.
# Interrupted uploads can be resumed.
# Arguments: 3
#   ${1} = update or upload ( upload type )
#   ${2} = file to upload
#   ${3} = root dir id for file
# Result: On
#   Success - Upload/Update file and export FILE_ID
#   Error - return 1
# Reference:
#   https://developers.google.com/drive/api/v3/create-file
#   https://developers.google.com/drive/api/v3/manage-uploads
#   https://developers.google.com/drive/api/v3/reference/files/update
###################################################
_upload_file() {
    export QUIET DESCRIPTION_FILE CHECK_MODE SKIP_DUPLICATES API_URL API_VERSION INFO_PATH
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    job_upload_file="${1}" input_upload_file="${2}" folder_id_upload_file="${3}"
    unset slug_upload_file inputname_upload_file extension_upload_file inputsize_upload_file readable_size_upload_file request_method_upload_file \
        url_upload_file postdata_upload_file uploadlink_upload_file upload_body_upload_file mime_type_upload_file description_upload_file \
        resume_args1_upload_file resume_args2_upload_file resume_args3_upload_file

    slug_upload_file="${input_upload_file##*/}"
    escaped_slug_upload_file="$(_json_escape j "${slug_upload_file}")" print_slug_upload_file="$(_json_escape p "${slug_upload_file}")"
    inputname_upload_file="${slug_upload_file%.*}"
    extension_upload_file="${slug_upload_file##*.}"
    inputsize_upload_file="$(($(wc -c < "${input_upload_file}")))" && content_length_upload_file="${inputsize_upload_file}"
    readable_size_upload_file="$(_bytes_to_human "${inputsize_upload_file}")"

    # Handle extension-less files
    [ "${inputname_upload_file}" = "${extension_upload_file}" ] && {
        mime_type_upload_file="$(file --brief --mime-type "${input_upload_file}" || mimetype --output-format %m "${input_upload_file}")" 2>| /dev/null || {
            "${QUIET:-_print_center}" "justify" "Error: file or mimetype command not found." "=" && printf "\n"
            exit 1
        }
    }

    # create description data
    [ -n "${DESCRIPTION_FILE}" ] && {
        description_upload_file="$(printf "%s\n" "${DESCRIPTION_FILE}" | sed -e "s|%f|${slug_upload_file}|g" -e "s|%f|${readable_size_upload_file}|g" -e "s|%m|${mime_type_upload_file}|g")"
        description_upload_file="$(_json_escape j "${description_upload_file}")" # escape for json
    }

    _print_center "justify" "${print_slug_upload_file}" " | ${readable_size_upload_file}" "="

    # Set proper variables for overwriting files
    [ "${job_upload_file}" = update ] && {
        unset file_check_json_upload_file check_value_upload_file
        case "${CHECK_MODE}" in
            2) check_value_type_upload_file="size" check_value_upload_file="${inputsize_upload_file}" ;;
            3)
                check_value_type_upload_file="md5Checksum"
                check_value_upload_file="$(md5sum "${input_upload_file}")" || {
                    "${QUIET:-_print_center}" "justify" "Error: cannot calculate md5sum of given file." "=" 1>&2
                    return 1
                }
                check_value_upload_file="${check_value_upload_file%% *}"
                ;;
            *) : ;;
        esac
        # Check if file actually exists, and create if not.
        if file_check_json_upload_file="$(_check_existing_file "${escaped_slug_upload_file}" "${folder_id_upload_file}" "${check_value_type_upload_file}" "${check_value_upload_file}")"; then
            if [ -n "${SKIP_DUPLICATES}" ]; then
                # Stop upload if already exists ( -d/--skip-duplicates )
                _collect_file_info "${file_check_json_upload_file}" "${print_slug_upload_file}" || return 1
                STRING="Skipped" _normal_logging_upload
                return 0
            else
                request_method_upload_file="PATCH"
                _file_id_upload_file="$(printf "%s\n" "${file_check_json_upload_file}" | _json_value id 1 1)" ||
                    { _error_logging_upload "${print_slug_upload_file}" "${file_check_json_upload_file}" || return 1; }
                url_upload_file="${API_URL}/upload/drive/${API_VERSION}/files/${_file_id_upload_file}?uploadType=resumable&supportsAllDrives=true&includeItemsFromAllDrives=true"
                # JSON post data to specify the file name and folder under while the file to be updated
                postdata_upload_file="{\"mimeType\": \"${mime_type_upload_file}\",\"name\": \"${escaped_slug_upload_file}\",\"addParents\": [\"${folder_id_upload_file}\"]${description_upload_file:+,\"description\":\"${description_upload_file}\"}}"
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
        postdata_upload_file="{\"mimeType\": \"${mime_type_upload_file}\",\"name\": \"${escaped_slug_upload_file}\",\"parents\": [\"${folder_id_upload_file}\"]${description_upload_file:+,\"description\":\"${description_upload_file}\"}}"
        STRING="Uploaded"
    }

    __file_upload_file="${INFO_PATH}/${print_slug_upload_file}__::__${folder_id_upload_file}__::__${inputsize_upload_file}"
    # https://developers.google.com/drive/api/v3/manage-uploads
    if [ -r "${__file_upload_file}" ]; then
        uploadlink_upload_file="$(cat "${__file_upload_file}" || :)"
        http_code_upload_file="$(curl --compressed -s -X PUT "${uploadlink_upload_file}" -o /dev/null --write-out %"{http_code}")" || :
        case "${http_code_upload_file}" in
            308) # Active Resumable URI give 308 status
                uploaded_range_upload_file="$(raw_upload_file="$(curl --compressed -s -X PUT \
                    -H "Content-Range: bytes */${content_length_upload_file}" \
                    --url "${uploadlink_upload_file}" --globoff -D - || :)" &&
                    printf "%s\n" "${raw_upload_file##*[R,r]ange: bytes=0-}" | while read -r line; do printf "%s\n" "${line%%"$(printf '\r')"}" && break; done)"
                if [ "${uploaded_range_upload_file}" -gt 0 ] 2>| /dev/null; then
                    _print_center "justify" "Resuming interrupted upload.." "-" && _newline "\n"
                    content_range_upload_file="$(printf "bytes %s-%s/%s\n" "$((uploaded_range_upload_file + 1))" "$((inputsize_upload_file - 1))" "${inputsize_upload_file}")"
                    content_length_upload_file="$((inputsize_upload_file - $((uploaded_range_upload_file + 1))))"
                    # Resuming interrupted uploads needs http1.1
                    resume_args1_upload_file='-s' resume_args2_upload_file='--http1.1' resume_args3_upload_file="Content-Range: ${content_range_upload_file}"
                    _upload_file_from_uri _clear_line
                    _collect_file_info "${upload_body_upload_file}" "${print_slug_upload_file}" || return 1
                    _normal_logging_upload
                    _remove_upload_session
                else
                    _full_upload || return 1
                fi
                ;;
            4[0-9][0-9] | 000) # Dead Resumable URI give 40* status
                _full_upload || return 1
                ;;
            201 | 200) # Completed Resumable URI give 20* status
                upload_body_upload_file="${http_code_upload_file}"
                _collect_file_info "${upload_body_upload_file}" "${print_slug_upload_file}" || return 1
                _normal_logging_upload
                _remove_upload_session
                ;;
            *) : ;;
        esac
    else
        _full_upload || return 1
    fi
    return 0
}

###################################################
# Sub functions for _upload_file function - Start
# generate resumable upload link
_generate_upload_link() {
    "${EXTRA_LOG:-}" "justify" "Generating upload link.." "-" 1>&2
    uploadlink_upload_file="$(_api_request "${CURL_PROGRESS_EXTRA:-}" \
        -X "${request_method_upload_file}" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -H "X-Upload-Content-Type: ${mime_type_upload_file}" \
        -H "X-Upload-Content-Length: ${inputsize_upload_file}" \
        -d "${postdata_upload_file}" \
        "${url_upload_file}" \
        -D - || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    case "${uploadlink_upload_file}" in
        *'ocation: '*'upload_id'*) uploadlink_upload_file="$(printf "%s\n" "${uploadlink_upload_file##*[L,l]ocation: }" | while read -r line; do printf "%s\n" "${line%%"$(printf '\r')"}" && break; done)" && return 0 ;;
        *) return 1 ;;
    esac

    return 0
}

# Curl command to push the file to google drive.
_upload_file_from_uri() {
    _print_center "justify" "Uploading.." "-"
    # shellcheck disable=SC2086,SC2248 # Because unnecessary to another check because ${CURL_PROGRESS} won't be anything problematic.
    upload_body_upload_file="$(_api_request ${CURL_PROGRESS:-} \
        -X PUT \
        -H "Content-Type: ${mime_type_upload_file}" \
        -H "Content-Length: ${content_length_upload_file}" \
        -H "Slug: ${print_slug_upload_file}" \
        -T "${input_upload_file}" \
        -o- \
        --url "${uploadlink_upload_file}" \
        --globoff \
        ${CURL_SPEED:-} ${resume_args1_upload_file:-} ${resume_args2_upload_file:-} \
        -H "${resume_args3_upload_file}" || :)"
    [ -z "${VERBOSE_PROGRESS:-}" ] && for _ in 1 2; do _clear_line 1; done && "${1:-:}"
    return 0
}

# logging in case of successful upload
_normal_logging_upload() {
    [ -z "${VERBOSE_PROGRESS:-}" ] && _clear_line 1
    "${QUIET:-_print_center}" "justify" "${slug_upload_file} " "| ${readable_size_upload_file} | ${STRING:-}" "="
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
    _generate_upload_link || { _error_logging_upload "${print_slug_upload_file}" "${uploadlink_upload_file}" || return 1; }
    _log_upload_session
    _upload_file_from_uri
    _collect_file_info "${upload_body_upload_file}" "${print_slug_upload_file}" || return 1
    _normal_logging_upload
    _remove_upload_session
    return 0
}
# Sub functions for _upload_file function - End
###################################################

###################################################
# Share a gdrive file/folder
# Arguments: 2
#   ${1} = gdrive ID of folder/file
#   ${2} = Email to which file will be shared ( optional )
# Result: read description
# Reference:
#   https://developers.google.com/drive/api/v3/manage-sharing
###################################################
_share_id() {
    [ $# -lt 2 ] && printf "Missing arguments\n" && return 1
    id_share_id="${1}" role_share_id="${2:?Missing role}" share_email_share_id="${3}" role_share_id="reader" type_share_id="${share_email_share_id:+user}"
    unset post_data_share_id response_share_id

    "${EXTRA_LOG}" "justify" "Sharing.." "-" 1>&2
    post_data_share_id="{\"role\":\"${role_share_id}\",\"type\":\"${type_share_id:-anyone}\"${share_email_share_id:+,\"emailAddress\":\"${share_email_share_id}\"}}"

    response_share_id="$(_api_request "${CURL_PROGRESS_EXTRA}" \
        -X POST \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "${post_data_share_id}" \
        "${API_URL}/drive/${API_VERSION}/files/${id_share_id}/permissions?supportsAllDrives=true&includeItemsFromAllDrives=true" || :)" && _clear_line 1 1>&2
    _clear_line 1 1>&2

    { printf "%s\n" "${response_share_id}" | _json_value id 1 1 2>| /dev/null 1>&2 && return 0; } ||
        { printf "%s\n" "Error: Cannot Share." 1>&2 && printf "%s\n" "${response_share_id}" 1>&2 && return 1; }
}
