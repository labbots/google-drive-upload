#!/usr/bin/env sh
# helper functions related to main upload script
# shellcheck source=/dev/null

###################################################
# Function to cleanup config file
# Remove invalid access tokens on the basis of corresponding expiry
# Arguments: 1
#   ${1} = config file
###################################################
_cleanup_config() {
    config="${1:?Error: Missing config}" && unset values_regex _tmp

    ! [ -f "${config}" ] && return 0

    while read -r line <&4 && [ -n "${line}" ]; do
        expiry_value_name="${line%%=*}"
        token_value_name="${expiry_value_name%%_EXPIRY}"

        _tmp="${line##*=}" && _tmp="${_tmp%\"}" && expiry="${_tmp#\"}"
        [ "${expiry}" -le "$(_epoch)" ] &&
            values_regex="${values_regex:+${values_regex}|}${expiry_value_name}=\".*\"|${token_value_name}=\".*\""
    done 4<< EOF
$(grep -F ACCESS_TOKEN_EXPIRY -- "${config}" || :)
EOF

    chmod u+w -- "${config}" &&
        printf "%s\n" "$(grep -Ev "^\$${values_regex:+|${values_regex}}" -- "${config}")" >| "${config}" &&
        chmod "a-w-r-x,u+r" -- "${config}"
    return 0
}

###################################################
# Process all arguments given to the script
# Arguments: Many
#   ${@}" = Flags with argument and file/folder input
# Result: On
#   Success - Set all the variables
#   Error   - Print error message and exit
# Reference:
#   Email Regex - https://gist.github.com/guessi/82a73ee7eb2b1216eb9db17bb8d65dd1
###################################################
_setup_arguments() {
    [ $# = 0 ] && printf "Missing arguments\n" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset CONTINUE_WITH_NO_INPUT
    export CURL_PROGRESS="-s" EXTRA_LOG=":" CURL_PROGRESS_EXTRA="-s"
    INFO_PATH="${HOME}/.google-drive-upload" CONFIG_INFO="${INFO_PATH}/google-drive-upload.configpath"
    [ -f "${CONFIG_INFO}" ] && . "${CONFIG_INFO}"
    CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"

    # Configuration variables # Remote gDrive variables
    unset ROOT_FOLDER CLIENT_ID CLIENT_SECRET REFRESH_TOKEN ACCESS_TOKEN
    export API_URL="https://www.googleapis.com"
    export API_VERSION="v3" \
        SCOPE="${API_URL}/auth/drive" \
        REDIRECT_URI="http%3A//localhost" \
        TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    _parse_arguments "_parser_setup_flags" "${@}" || return 1
    _check_debug

    [ -n "${VERBOSE_PROGRESS}" ] && unset VERBOSE && export CURL_PROGRESS=""
    [ -n "${QUIET}" ] && export CURL_PROGRESS="-s"

    # create info path folder, can be missing if gupload was not installed with install.sh
    mkdir -p "${INFO_PATH}" || return 1

    # post processing for --account, --delete-account, --create-acount and --list-accounts
    # handle account related flags here as we want to use the flags independenlty even with no normal valid inputs
    # delete account, --delete-account flag
    # TODO: add support for deleting multiple accounts
    [ -n "${DELETE_ACCOUNT_NAME}" ] && _delete_account "${DELETE_ACCOUNT_NAME}"
    # list all configured accounts, --list-accounts flag
    [ -n "${LIST_ACCOUNTS}" ] && _all_accounts

    # If no input, then check if either -C option was used.
    [ -z "${INPUT_FILE_1:-${INPUT_ID_1:-${FOLDERNAME}}}" ] && {
        # if any account related option was used then don't show short help
        [ -z "${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-${NEW_ACCOUNT_NAME}}}" ] && _short_help
        # exit right away if --list-accounts or --delete-account flag was used
        [ -n "${DELETE_ACCOUNT_NAME:-${LIST_ACCOUNTS:-}}" ] && exit 0
        # don't exit right away when new account is created but also let the rootdir stuff execute
        [ -n "${NEW_ACCOUNT_NAME}" ] && CONTINUE_WITH_NO_INPUT="true"
    }

    # set CHECK_MODE if empty, below are check mode values
    # 1 = check only name, 2 = check name and size, 3 = check name and md5sum
    [ -z "${CHECK_MODE}" ] && {
        case "${SKIP_DUPLICATES:-${OVERWRITE}}" in
            "Overwrite") export CHECK_MODE="1" ;;
            "Skip Existing") export CHECK_MODE="2" ;;
            *) : ;;
        esac
    }

    return 0
}

# setup cleanup after exit using traps
_setup_traps() {
    export SUPPORT_ANSI_ESCAPES TMPFILE ACCESS_TOKEN ACCESS_TOKEN_EXPIRY INITIAL_ACCESS_TOKEN ACCOUNT_NAME CONFIG ACCESS_TOKEN_SERVICE_PID
    _cleanup() {
        # unhide the cursor if hidden
        [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\033[?25h\033[?7h"
        {
            # update the config with latest ACCESS_TOKEN and ACCESS_TOKEN_EXPIRY only if changed
            [ -f "${TMPFILE}_ACCESS_TOKEN" ] && {
                . "${TMPFILE}_ACCESS_TOKEN"
                [ "${INITIAL_ACCESS_TOKEN}" = "${ACCESS_TOKEN}" ] || {
                    _update_config "ACCOUNT_${ACCOUNT_NAME}_ACCESS_TOKEN" "${ACCESS_TOKEN}" "${CONFIG}"
                    _update_config "ACCOUNT_${ACCOUNT_NAME}_ACCESS_TOKEN_EXPIRY" "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"
                }
            } || : 1>| /dev/null

            # grab all chidren processes of access token service
            # https://askubuntu.com/a/512872
            [ -n "${ACCESS_TOKEN_SERVICE_PID}" ] && {
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

            export abnormal_exit && if [ -n "${abnormal_exit}" ]; then
                printf "\n\n%s\n" "Script exited manually."
                kill "${_SCRIPT_KILL_SIGNAL:--9}" -$$ &
            else
                { _cleanup_config "${CONFIG}" && [ "${GUPLOAD_INSTALLED_WITH:-}" = script ] && _auto_update; } 1>| /dev/null &
            fi
        } 2>| /dev/null || :
        return 0
    }

    trap 'abnormal_exit="1" ; exit' INT TERM
    trap '_cleanup' EXIT
    trap '' TSTP # ignore ctrl + z

    export MAIN_PID="$$"
}

###################################################
# Setup root directory where all file/folders will be uploaded/updated
# Result: read description
#   If root id not found then print message and exit
#   Update config with root id and root id name if specified
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#use-read-as-an-alternative-to-the-sleep-command
###################################################
_setup_root_dir() {
    export ROOTDIR ROOT_FOLDER ROOT_FOLDER_NAME QUIET ACCOUNT_NAME CONFIG UPDATE_DEFAULT_ROOTDIR
    _check_root_id() {
        _setup_root_dir_json="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "id")"
        if ! rootid_setup_root_dir="$(printf "%s\n" "${_setup_root_dir_json}" | _json_value id 1 1)"; then
            if printf "%s\n" "${_setup_root_dir_json}" | grep "File not found" -q; then
                "${QUIET:-_print_center}" "justify" "Given root folder" " ID/URL invalid." "=" 1>&2
            else
                printf "%s\n" "${_setup_root_dir_json}" 1>&2
            fi
            return 1
        fi

        ROOT_FOLDER="${rootid_setup_root_dir}"
        "${1:-:}" "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER" "${ROOT_FOLDER}" "${CONFIG}" || return 1
        return 0
    }
    _check_root_id_name() {
        ROOT_FOLDER_NAME="$(_drive_info "$(_extract_id "${ROOT_FOLDER}")" "name" | _json_value name 1 1 || :)"
        "${1:-:}" "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER_NAME" "${ROOT_FOLDER_NAME}" "${CONFIG}" || return 1
        return 0
    }

    _set_value indirect ROOT_FOLDER "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER"
    _set_value indirect ROOT_FOLDER_NAME "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER_NAME"

    if [ -n "${ROOTDIR:-}" ]; then
        ROOT_FOLDER="${ROOTDIR}" && { _check_root_id "${UPDATE_DEFAULT_ROOTDIR}" || return 1; } && unset ROOT_FOLDER_NAME
    elif [ -z "${ROOT_FOLDER}" ]; then
        { [ -t 1 ] && "${QUIET:-_print_center}" "normal" "Enter root folder ID or URL, press enter for default ( root )" " " && printf -- "-> " &&
            read -r ROOT_FOLDER && [ -n "${ROOT_FOLDER}" ] && { _check_root_id _update_config || return 1; }; } || {
            ROOT_FOLDER="root"
            _update_config "ACCOUNT_${ACCOUNT_NAME}_ROOT_FOLDER" "${ROOT_FOLDER}" "${CONFIG}" || return 1
        } && printf "\n\n"
    elif [ -z "${ROOT_FOLDER_NAME}" ]; then
        _check_root_id_name _update_config || return 1 # update default root folder name if not available
    fi

    # fetch root folder name if rootdir different than default
    [ -z "${ROOT_FOLDER_NAME}" ] && { _check_root_id_name "${UPDATE_DEFAULT_ROOTDIR}" || return 1; }

    return 0
}

###################################################
# Setup Workspace folder
# Check if the given folder exists in google drive.
# If not then the folder is created in google drive under the configured root folder.
# Result: Read Description
###################################################
_setup_workspace() {
    export FOLDERNAME ROOT_FOLDER ROOT_FOLDER_NAME WORKSPACE_FOLDER_ID WORKSPACE_FOLDER_NAME
    if [ -z "${FOLDERNAME}" ]; then
        WORKSPACE_FOLDER_ID="${ROOT_FOLDER}"
        WORKSPACE_FOLDER_NAME="${ROOT_FOLDER_NAME}"
    else
        # split the string on / and use each value to create folder on drive
        # it is safe to do as folder names can't contain /
        while read -r foldername <&4 && { [ -n "${foldername}" ] || continue; }; do
            # use WORKSPACE_FOLDER_ID folder id when available so the next folder is created inside the previous folder
            WORKSPACE_FOLDER_ID="$(_create_directory "${foldername}" "${WORKSPACE_FOLDER_ID:-${ROOT_FOLDER}}")" ||
                { printf "%s\n" "${WORKSPACE_FOLDER_ID}" 1>&2 && return 1; }
            WORKSPACE_FOLDER_NAME="$(_drive_info "${WORKSPACE_FOLDER_ID}" name | _json_value name 1 1)" ||
                { printf "%s\n" "${WORKSPACE_FOLDER_NAME}" 1>&2 && return 1; }
        done 4<< EOF
$(_split "${FOLDERNAME}" "/")
EOF
    fi

    return 0
}

###################################################
# Process all the values in "${ID_INPUT_ARRAY}"
###################################################
_process_arguments() {
    export SHARE SHARE_ROLE SHARE_EMAIL HIDE_INFO QUIET SKIP_DUPLICATES OVERWRITE \
        WORKSPACE_FOLDER_ID SOURCE_UTILS EXTRA_LOG SKIP_SUBDIRS INCLUDE_FILES EXCLUDE_FILES \
        QUIET PARALLEL_UPLOAD VERBOSE VERBOSE_PROGRESS CHECK_MODE DESCRIPTION DESCRIPTION_ALL \
        UPLOAD_MODE HIDE_INFO

    # on successful uploads
    _share_and_print_link() {
        "${SHARE:-:}" "${1:-}" "${SHARE_ROLE}" "${SHARE_EMAIL}"
        [ -z "${HIDE_INFO}" ] && {
            _print_center "justify" "DriveLink" "${SHARE:+ (SHARED[$(printf "%.1s" "${SHARE_ROLE}")])}" "-"
            _support_ansi_escapes && [ "$((COLUMNS))" -gt 45 ] 2>| /dev/null && _print_center "normal" '^ ^ ^' ' '
            "${QUIET:-_print_center}" "normal" "https://drive.google.com/open?id=${1:-}" " "
        }
        return 0
    }

    _SEEN="" index_process_arguments=0
    # TOTAL_INPUTS and INPUT_FILE_* is exported in _parser_process_input function, see flags.sh
    TOTAL_FILE_INPUTS="$((TOTAL_FILE_INPUTS < 0 ? 0 : TOTAL_FILE_INPUTS))"
    until [ "${index_process_arguments}" -eq "${TOTAL_FILE_INPUTS}" ]; do
        input=""
        _set_value i input "INPUT_FILE_$((index_process_arguments += 1))"
        # check if the arg was already done
        case "${_SEEN}" in
            *"${input}"*) continue ;;
            *) _SEEN="${_SEEN}${input}" ;;
        esac

        # Check if the argument is a file or a directory.
        if [ -f "${input}" ]; then
            # export DESCRIPTION_FILE, used for descriptions in _upload_file function
            export DESCRIPTION_FILE="${DESCRIPTION}"

            _print_center "justify" "Given Input" ": FILE" "="
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            _upload_file_main noparse "${input}" "${WORKSPACE_FOLDER_ID}"
            if [ "${RETURN_STATUS:-}" = 1 ]; then
                _share_and_print_link "${FILE_ID:-}"
                printf "\n"
            else
                for _ in 1 2; do _clear_line 1; done && continue
            fi
        elif [ -d "${input}" ]; then
            input="$(cd "${input}" && pwd)" || return 1 # to handle dirname when current directory (.) is given as input.
            unset EMPTY                                 # Used when input folder is empty

            # export DESCRIPTION_FILE only if DESCRIPTION_ALL var is available, used for descriptions in _upload_file function
            export DESCRIPTION_FILE="${DESCRIPTION_ALL+:${DESCRIPTION}}"

            _print_center "justify" "Given Input" ": FOLDER" "-"
            _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
            FOLDER_NAME="${input##*/}" && "${EXTRA_LOG}" "justify" "Folder: ${FOLDER_NAME}" "="

            NEXTROOTDIRID="${WORKSPACE_FOLDER_ID}"

            "${EXTRA_LOG}" "justify" "Processing folder.." "-"

            [ -z "${SKIP_SUBDIRS}" ] && "${EXTRA_LOG}" "justify" "Indexing subfolders.." "-"
            # Do not create empty folders during a recursive upload. Use of find in this section is important.
            DIRNAMES="$(find "${input}" -type d -not -empty)"

            # include or exlude the files if -in or -ex flag was used, use grep
            [ -n "${INCLUDE_FILES}" ] && _tmp_dirnames="$(printf "%s\n" "${DIRNAMES}" | grep -E "${INCLUDE_FILES}")" &&
                DIRNAMES="${_tmp_dirnames}"
            [ -n "${EXCLUDE_FILES}" ] && _tmp_dirnames="$(printf "%s\n" "${DIRNAMES}" | grep -Ev "${INCLUDE_FILES}")" &&
                DIRNAMES="${_tmp_dirnames}"

            NO_OF_FOLDERS="$(($(printf "%s\n" "${DIRNAMES}" | wc -l)))" && NO_OF_SUB_FOLDERS="$((NO_OF_FOLDERS - 1))"
            [ -z "${SKIP_SUBDIRS}" ] && _clear_line 1
            [ "${NO_OF_SUB_FOLDERS}" = 0 ] && SKIP_SUBDIRS="true"

            "${EXTRA_LOG}" "justify" "Indexing files.." "-"
            FILENAMES="$(find "${input}" -type f)"

            # include or exlude the files if -in or -ex flag was used, use grep
            [ -n "${INCLUDE_FILES}" ] && _tmp_filenames="$(printf "%s\n" "${FILENAMES}" | grep -E "${EXCLUDE_FILES}")" &&
                FILENAMES="${_tmp_filenames}"
            [ -n "${EXCLUDE_FILES}" ] && _tmp_filenames="$(printf "%s\n" "${FILENAMES}" | grep -Ev "${EXCLUDE_FILES}")" &&
                FILENAMES="${_tmp_filenames}"

            _clear_line 1

            # Skip the sub folders and find recursively all the files and upload them.
            if [ -n "${SKIP_SUBDIRS}" ]; then
                if [ -n "${FILENAMES}" ]; then
                    NO_OF_FILES="$(($(printf "%s\n" "${FILENAMES}" | wc -l)))"
                    for _ in 1 2; do _clear_line 1; done

                    "${QUIET:-_print_center}" "justify" "Folder: ${FOLDER_NAME} " "| ${NO_OF_FILES} File(s)" "=" && printf "\n"
                    "${EXTRA_LOG}" "justify" "Creating folder.." "-"
                    { ID="$(_create_directory "${input}" "${NEXTROOTDIRID}")" && export ID; } ||
                        { "${QUIET:-_print_center}" "normal" "Folder creation failed" "-" && printf "%s\n\n\n" "${ID}" 1>&2 && continue; }
                    _clear_line 1 && DIRIDS="${ID}"

                    [ -z "${PARALLEL_UPLOAD:-${VERBOSE:-${VERBOSE_PROGRESS}}}" ] && _newline "\n"
                    _upload_folder "${PARALLEL_UPLOAD:-normal}" noparse "${FILENAMES}" "${ID}"
                    [ -n "${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}}" ] && _newline "\n\n"
                else
                    for _ in 1 2; do _clear_line 1; done && EMPTY=1
                fi
            else
                if [ -n "${FILENAMES}" ]; then
                    NO_OF_FILES="$(($(printf "%s\n" "${FILENAMES}" | wc -l)))"
                    for _ in 1 2; do _clear_line 1; done
                    "${QUIET:-_print_center}" "justify" "${FOLDER_NAME} " "| $((NO_OF_FILES)) File(s) | $((NO_OF_SUB_FOLDERS)) Sub-folders" "="

                    _newline "\n" && "${EXTRA_LOG}" "justify" "Creating Folder(s).." "-" && _newline "\n"
                    unset status
                    while read -r dir <&4 && { [ -n "${dir}" ] || continue; }; do
                        [ -n "${status}" ] && __dir="$(_dirname "${dir}")" &&
                            __temp="$(printf "%s\n" "${DIRIDS}" | grep -F "|:_//_:|${__dir}|:_//_:|")" &&
                            NEXTROOTDIRID="${__temp%%"|:_//_:|${__dir}|:_//_:|"}"

                        NEWDIR="${dir##*/}" && _print_center "justify" "Name: ${NEWDIR}" "-" 1>&2
                        ID="$(_create_directory "${NEWDIR}" "${NEXTROOTDIRID}")" ||
                            { "${QUIET:-_print_center}" "normal" "Folder creation failed" "-" && printf "%s\n\n\n" "${ID}" 1>&2 && continue; }

                        # Store sub-folder directory IDs and it's path for later use.
                        DIRIDS="$(printf "%b%s|:_//_:|%s|:_//_:|\n" "${DIRIDS:+${DIRIDS}\n}" "${ID}" "${dir}")"

                        for _ in 1 2; do _clear_line 1 1>&2; done
                        "${EXTRA_LOG}" "justify" "Status" ": $((status += 1)) / $((NO_OF_FOLDERS))" "=" 1>&2
                    done 4<< EOF
$(printf "%s\n" "${DIRNAMES}")
EOF
                    export DIRIDS

                    _clear_line 1

                    _upload_folder "${PARALLEL_UPLOAD:-normal}" parse "${FILENAMES}"
                    [ -n "${PARALLEL_UPLOAD:+${VERBOSE:-${VERBOSE_PROGRESS}}}" ] && _newline "\n\n"
                else
                    for _ in 1 2 3; do _clear_line 1; done && EMPTY=1
                fi
            fi
            export SUCCESS_STATUS ERROR_STATUS ERROR_FILES
            if [ "${EMPTY}" != 1 ]; then
                [ -z "${VERBOSE:-${VERBOSE_PROGRESS}}" ] && for _ in 1 2; do _clear_line 1; done

                FOLDER_ID="$(_tmp="$(printf "%s\n" "${DIRIDS}" | while read -r line; do printf "%s\n" "${line}" && break; done)" && printf "%s\n" "${_tmp%%"|:_//_:|"*}")"

                [ "${SUCCESS_STATUS}" -gt 0 ] && _share_and_print_link "${FOLDER_ID}"

                _newline "\n"
                [ "${SUCCESS_STATUS}" -gt 0 ] && "${QUIET:-_print_center}" "justify" "Total Files " "Uploaded: ${SUCCESS_STATUS}" "="
                [ "${ERROR_STATUS}" -gt 0 ] && "${QUIET:-_print_center}" "justify" "Total Files " "Failed: ${ERROR_STATUS}" "=" && {
                    # If running inside a terminal, then check if failed files are more than 25, if not, then print, else save in a log file
                    if [ -t 1 ]; then
                        { [ "${ERROR_STATUS}" -le 25 ] && printf "%s\n" "${ERROR_FILES}"; } || {
                            epoch_time="$(date +'%s')" log_file_name="${0##*/}_${FOLDER_NAME}_${epoch_time}.failed"
                            # handle in case the vivid random file name was already there
                            i=0 && until ! [ -f "${log_file_name}" ]; do
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

    _SEEN="" index_process_arguments=0
    # TOTAL_ID_INPUTS and INPUT_ID_* is exported in _parser_process_input function, see flags.sh
    TOTAL_ID_INPUTS="$((TOTAL_ID_INPUTS < 0 ? 0 : TOTAL_ID_INPUTS))"
    until [ "${index_process_arguments}" -eq "${TOTAL_ID_INPUTS}" ]; do
        gdrive_id=""
        _set_value gdrive_id "INPUT_ID_$((index_process_arguments += 1))"
        # check if the arg was already done
        case "${_SEEN}" in
            *"${gdrive_id}"*) continue ;;
            *) _SEEN="${_SEEN}${gdrive_id}" ;;
        esac
        _print_center "justify" "Given Input" ": ID" "="
        "${EXTRA_LOG}" "justify" "Checking if id exists.." "-"
        [ "${CHECK_MODE}" = "md5Checksum" ] && param="md5Checksum"
        json="$(_drive_info "${gdrive_id}" "name,mimeType,size${param:+,${param}}")" || :
        if ! printf "%s\n" "${json}" | _json_value code 1 1 2>| /dev/null 1>&2; then
            type="$(printf "%s\n" "${json}" | _json_value mimeType 1 1 || :)"
            name="$(printf "%s\n" "${json}" | _json_value name 1 1 || :)"
            size="$(printf "%s\n" "${json}" | _json_value size 1 1 || :)"
            [ "${CHECK_MODE}" = "md5Checksum" ] && md5="$(printf "%s\n" "${json}" | _json_value md5Checksum 1 1 || :)"
            for _ in 1 2; do _clear_line 1; done
            case "${type}" in
                *folder*)
                    # export DESCRIPTION_FILE only if DESCRIPTION_ALL var is available, used for descriptions in _clone_file function
                    export DESCRIPTION_FILE="${DESCRIPTION_ALL+:${DESCRIPTION}}"

                    "${QUIET:-_print_center}" "justify" "Folder not supported." "=" 1>&2 && _newline "\n" 1>&2 && continue
                    ## TODO: Add support to clone folders
                    ;;
                *)
                    # export DESCRIPTION_FILE, used for descriptions in _clone_file function
                    export DESCRIPTION_FILE="${DESCRIPTION}"

                    _print_center "justify" "Given Input" ": File ID" "="
                    _print_center "justify" "Upload Method" ": ${SKIP_DUPLICATES:-${OVERWRITE:-Create}}" "=" && _newline "\n"
                    _clone_file "${UPLOAD_MODE:-create}" "${gdrive_id}" "${WORKSPACE_FOLDER_ID}" "${name}" "${size}" "${md5}" ||
                        { for _ in 1 2; do _clear_line 1; done && continue; }
                    ;;
            esac
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

# this function is called from _main function for respective sh and bash scripts
_main_helper() {
    _setup_arguments "${@}" || exit 1
    "${SKIP_INTERNET_CHECK:-_check_internet}" || exit 1

    TMPFILE="$(command -v mktemp 1>| /dev/null && mktemp -u)" || TMPFILE="$(pwd)/.$(_t="$(_epoch)" && printf "%s\n" "$((_t * _t))").tmpfile"
    export TMPFILE

    # setup a cleanup function and use it with traps, also export MAIN_PID
    _setup_traps

    "${EXTRA_LOG}" "justify" "Checking credentials.." "-"
    { _check_credentials && _clear_line 1; } ||
        { "${QUIET:-_print_center}" "normal" "[ Error: Credentials checking failed ]" "=" && exit 1; }
    "${QUIET:-_print_center}" "normal" " Account: ${ACCOUNT_NAME} " "="

    "${EXTRA_LOG}" "justify" "Checking root dir.." "-"
    { _setup_root_dir && _clear_line 1; } ||
        { "${QUIET:-_print_center}" "normal" "[ Error: Rootdir setup failed ]" "=" && exit 1; }
    _print_center "justify" "Root dir properly configured." "="

    # only execute next blocks if there was some input
    [ -n "${CONTINUE_WITH_NO_INPUT}" ] && exit 0

    "${EXTRA_LOG}" "justify" "Checking Workspace Folder.." "-"
    { _setup_workspace && for _ in 1 2; do _clear_line 1; done; } ||
        { "${QUIET:-_print_center}" "normal" "[ Error: Workspace setup failed ]" "=" && exit 1; }
    _print_center "justify" "Workspace Folder: ${WORKSPACE_FOLDER_NAME}" "="
    "${HIDE_INFO:-_print_center}" "normal" " ${WORKSPACE_FOLDER_ID} " "-" && _newline "\n"

    START="$(_epoch)"

    # hide the cursor if ansi escapes are supported
    [ -n "${SUPPORT_ANSI_ESCAPES}" ] && printf "\033[?25l"

    _process_arguments

    END="$(_epoch)"
    DIFF="$((END - START))"
    "${QUIET:-_print_center}" "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds. " "="

}
