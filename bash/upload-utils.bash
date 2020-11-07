#!/usr/bin/env bash
# shellcheck source=/dev/null

###################################################
# A simple wrapper to check tempfile for access token and make authorized oauth requests to drive api
###################################################
_api_request() {
    . "${TMPFILE}_ACCESS_TOKEN"

    curl --compressed \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "${@}"
}

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
    declare json="${1}" info
    FILE_ID="$(_json_value id 1 1 <<< "${json}")" || { _error_logging_upload "${2}" "${json}" || return 1; }
    [[ -z ${LOG_FILE_ID} || -d ${LOG_FILE_ID} ]] && return 0
    info="Link: https://drive.google.com/open?id=${FILE_ID}
Name: $(_json_value name 1 1 <<< "${json}" || :)
ID: ${FILE_ID}
Type: $(_json_value mimeType 1 1 <<< "${json}" || :)"
    printf "%s\n\n" "${info}" >> "${LOG_FILE_ID}"
    return 0
}

###################################################
# Error logging wrapper
###################################################
_error_logging_upload() {
    declare log="${2}"
    "${QUIET:-_print_center}" "justify" "Upload ERROR" ", ${1:-} not ${STRING:-uploaded}." "=" 1>&2
    case "${log}" in
        # https://github.com/rclone/rclone/issues/3857#issuecomment-573413789
        *'"message": "User rate limit exceeded."'*)
            printf "%s\n\n%s\n" "${log}" \
                "Today's upload limit reached for this account. Use another account to upload or wait for tomorrow." 1>&2
            # Never retry if upload limit reached
            export RETRY=0
            ;;
        '' | *) printf "%s\n" "${log}" 1>&2 ;;
    esac
    printf "\n\n\n" 1>&2
    return 1
}

###################################################
# A small function to get rootdir id for files in sub folder uploads
# Globals: 1 variable, 1 function
#   Variables - DIRIDS
#   Functions - _dirname
# Arguments: 1
#   ${1} = filename
# Result: read discription
###################################################
_get_rootdir_id() {
    declare file="${1:?Error: give filename}" __rootdir __temp
    __rootdir="$(_dirname "${file}")"
    __temp="$(grep -F "|:_//_:|${__rootdir}|:_//_:|" <<< "${DIRIDS:?Error: DIRIDS Missing}" || :)"
    printf "%s\n" "${__temp%%"|:_//_:|${__rootdir}|:_//_:|"}"
    return 0
}

###################################################
# A extra wrapper for _upload_file function to properly handle retries
# also handle uploads in case uploading from folder
# Globals: 2 variables, 1 function
#   Variables - RETRY, UPLOAD_MODE
#   Functions - _upload_file
# Arguments: 3
#   ${1} = parse or norparse
#   ${2} = file path
#   ${3} = if ${1} != parse; gdrive folder id to upload; fi
# Result: set SUCCESS var on success
###################################################
_upload_file_main() {
    [[ $# -lt 2 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare file="${2}" dirid _sleep
    { [[ ${1} = parse ]] && dirid="$(_get_rootdir_id "${file}")"; } || dirid="${3}"

    retry="${RETRY:-0}" && unset RETURN_STATUS
    until [[ ${retry} -le 0 ]] && [[ -n ${RETURN_STATUS} ]]; do
        if [[ -n ${4} ]]; then
            { _upload_file "${UPLOAD_MODE:-create}" "${file}" "${dirid}" 2>| /dev/null 1>&2 && RETURN_STATUS=1 && break; } || RETURN_STATUS=2
        else
            { _upload_file "${UPLOAD_MODE:-create}" "${file}" "${dirid}" && RETURN_STATUS=1 && break; } || RETURN_STATUS=2
        fi
        # decrease retry using -=, skip sleep if all retries done
        [[ $((retry -= 1)) -lt 1 ]] && sleep "$((_sleep += 1))"
        # on every retry, sleep the times of retry it is, e.g for 1st, sleep 1, for 2nd, sleep 2
        continue
    done
    [[ -n ${4} ]] && {
        { [[ ${RETURN_STATUS} = 1 ]] && printf "%s\n" "${file}"; } || printf "%s\n" "${file}" 1>&2
    }
    return 0
}

###################################################
# Upload all files in the given folder, parallelly or non-parallely and show progress
# Globals: 7 variables, 3 functions
#   Variables - VERBOSE, VERBOSE_PROGRESS, NO_OF_PARALLEL_JOBS, NO_OF_FILES, TMPFILE, UTILS_FOLDER and QUIET
#   Functions - _clear_line, _newline, _print_center and _upload_file_main
# Arguments: 4
#   ${1} = parallel or normal
#   ${2} = parse or norparse
#   ${3} = filenames with full path
#   ${4} = if ${2} != parse; then gdrive folder id to upload; fi
# Result: read discription, set SUCCESS_STATUS & ERROR_STATUS
###################################################
_upload_folder() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare mode="${1}" files="${3}" && PARSE_MODE="${2}" ID="${4:-}" && export PARSE_MODE ID
    unset SUCCESS_STATUS SUCCESS_FILES ERROR_STATUS ERROR_FILES
    case "${mode}" in
        normal)
            [[ ${PARSE_MODE} = parse ]] && _clear_line 1 && _newline "\n"

            while read -u 4 -r file; do
                _upload_file_main "${PARSE_MODE}" "${file}" "${ID}"
                { [[ ${RETURN_STATUS} = 1 ]] && : "$((SUCCESS_STATUS += 1))" && SUCCESS_FILES+="${file}"$'\n'; } ||
                    { : "$((ERROR_STATUS += 1))" && ERROR_FILES+="${file}"$'\n'; }
                if [[ -n ${VERBOSE:-${VERBOSE_PROGRESS}} ]]; then
                    _print_center "justify" "Status: ${SUCCESS_STATUS} Uploaded" " | ${ERROR_STATUS} Failed" "=" && _newline "\n"
                else
                    for _ in 1 2; do _clear_line 1; done
                    _print_center "justify" "Status: ${SUCCESS_STATUS} Uploaded" " | ${ERROR_STATUS} Failed" "="
                fi
            done 4<<< "${files}"
            ;;
        parallel)
            NO_OF_PARALLEL_JOBS_FINAL="$((NO_OF_PARALLEL_JOBS > NO_OF_FILES ? NO_OF_FILES : NO_OF_PARALLEL_JOBS))"
            [[ -f "${TMPFILE}"SUCCESS ]] && rm "${TMPFILE}"SUCCESS
            [[ -f "${TMPFILE}"ERROR ]] && rm "${TMPFILE}"ERROR

            # shellcheck disable=SC2016
            printf "%s\n" "${files}" | xargs -n1 -P"${NO_OF_PARALLEL_JOBS_FINAL}" -I {} bash -c '
            _upload_file_main "${PARSE_MODE}" "{}" "${ID}" true
            ' 1>| "${TMPFILE}"SUCCESS 2>| "${TMPFILE}"ERROR &
            pid="${!}"

            until [[ -f "${TMPFILE}"SUCCESS ]] || [[ -f "${TMPFILE}"ERORR ]]; do sleep 0.5; done
            [[ ${PARSE_MODE} = parse ]] && _clear_line 1
            _newline "\n"

            until ! kill -0 "${pid}" 2>| /dev/null 1>&2; do
                SUCCESS_STATUS="$(_count < "${TMPFILE}"SUCCESS)"
                ERROR_STATUS="$(_count < "${TMPFILE}"ERROR)"
                sleep 1
                [[ $((SUCCESS_STATUS + ERROR_STATUS)) != "${TOTAL}" ]] &&
                    _clear_line 1 && "${QUIET:-_print_center}" "justify" "Status" ": ${SUCCESS_STATUS} Uploaded | ${ERROR_STATUS} Failed" "="
                TOTAL="$((SUCCESS_STATUS + ERROR_STATUS))"
            done
            SUCCESS_STATUS="$(_count < "${TMPFILE}"SUCCESS)" SUCCESS_FILES="$(< "${TMPFILE}"SUCCESS)"
            ERROR_STATUS="$(_count < "${TMPFILE}"ERROR)" ERROR_FILES="$(< "${TMPFILE}"ERROR)"
            ;;
    esac
    return 0
}
