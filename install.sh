#!/usr/bin/env sh
# Install, Update or Uninstall google-drive-upload

_usage() {
    printf "
The script can be used to install google-drive-upload script in your system.\n
Usage: %s [options.. ]\n
All flags are optional.\n
Options:\n
  -p | --path <dir_name> - Custom path where you want to install script.\nDefault Path: %s/.google-drive-upload \n
  -c | --cmd <command_name> - Custom command name, after installation script will be available as the input argument.
      To change sync command name, use %s -c gupload sync='gsync'
      Default upload command: gupload
      Default sync command: gsync\n
  -r | --repo <Username/reponame> - Upload script from your custom repo,e.g --repo labbots/google-drive-upload, make sure your repo file structure is same as official repo.\n
  -R | --release <tag/release_tag> - Specify tag name for the github repo, applies to custom and default repo both.\n
  -B | --branch <branch_name> - Specify branch name for the github repo, applies to custom and default repo both.\n
  -s | --shell-rc <shell_file> - Specify custom rc file, where PATH is appended, by default script detects .zshrc and .bashrc.\n
  -t | --time 'no of days' - Specify custom auto update time ( given input will taken as number of days ) after which script will try to automatically update itself.\n
      Default: 5 ( 5 days )\n
  --skip-internet-check - Like the flag says.\n
  -z | --config <fullpath> - Specify fullpath of the config file which will contain the credentials.\nDefault : %s/.googledrive.conf
  --sh | --posix - Force install posix scripts even if system has compatible bash binary present.\n
  -q | --quiet - Only show critical error/sucess logs.\n
  -U | --uninstall - Uninstall the script and remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n" "${0##*/}" "${HOME}" "${HOME}"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Check if debug is enabled and enable command trace
# Globals: 2 variables, 1 function
#   Varibles - DEBUG, QUIET
#   Function - _is_terminal
# Arguments: None
# Result: If DEBUG
#   Present - Enable command trace and change print functions to avoid spamming.
#   Absent  - Disable command trace
#             Check QUIET, then check terminal size and enable print functions accordingly.
###################################################
_check_debug() {
    _print_center_quiet() { { [ $# = 3 ] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
    if [ -n "${DEBUG}" ]; then
        _print_center() { { [ $# = 3 ] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _newline() { :; }
        set -x
    else
        if [ -z "${QUIET}" ]; then
            # check if running in terminal and support ansi escape sequences
            case "${TERM}" in
                xterm* | rxvt* | urxvt* | linux* | vt*) ansi_escapes="true" ;;
            esac
            if [ -t 2 ] && [ -n "${ansi_escapes}" ]; then
                ! COLUMNS="$(_get_columns_size)" || [ "${COLUMNS:-0}" -lt 45 ] 2> /dev/null &&
                    _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
            else
                _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                _clear_line() { :; }
            fi
            _newline() { printf "%b" "${1}"; }
        else
            _print_center() { :; } && _clear_line() { :; } && _newline() { :; }
        fi
        set +x
    fi
}

###################################################
# Check if the required executables are installed
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_dependencies() {
    posix_check_dependencies="${1:-0}"
    unset error_list warning_list

    for program in curl find xargs mkdir rm grep sed; do
        command -v "${program}" 2> /dev/null 1>&2 || error_list="${error_list}\n${program}"
    done

    { ! command -v file && ! command -v mimetype; } 2> /dev/null 1>&2 &&
        error_list="${error_list}\n\"file or mimetype\""

    [ "${posix_check_dependencies}" != 0 ] &&
        for program in awk cat date ps sleep; do
            command -v "${program}" 2> /dev/null 1>&2 || error_list="${error_list}\n${program}"
        done

    for program in ps tail; do
        command -v "${program}" 2> /dev/null 1>&2 || warning_list="${warning_list}\n${program}"
    done

    [ -n "${warning_list}" ] && {
        [ -z "${UNINSTALL}" ] && {
            printf "Warning: "
            printf "%b, " "${error_list}"
            printf "%b" "not found, sync script will be not installed/updated.\n"
        }
        SKIP_SYNC="true"
    }

    [ -n "${error_list}" ] && [ -z "${UNINSTALL}" ] && {
        printf "Error: "
        printf "%b, " "${error_list}"
        printf "%b" "not found, install before proceeding.\n"
        exit 1
    }
    return 0
}

###################################################
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Globals: 2 functions
#   _print_center, _clear_line
# Arguments: None
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    _print_center "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com --compressed; then
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
        exit 1
    fi
    _clear_line 1
}

###################################################
# Move cursor to nth no. of line and clear it to the begining.
# Globals: None
# Arguments: 1
#   ${1} = Positive integer ( line number )
# Result: Read description
###################################################
_clear_line() {
    printf "\033[%sA\033[2K" "${1}"
}

###################################################
# Detect profile rc file for zsh and bash.
# Detects for login shell of the user.
# Globals: 2 Variables
#   HOME, SHELL
# Arguments: None
# Result: On
#   Success - print profile file
#   Error   - print error message and exit 1
###################################################
_detect_profile() {
    CURRENT_SHELL="${SHELL##*/}"
    case "${CURRENT_SHELL}" in
        *bash*) DETECTED_PROFILE="${HOME}/.bashrc" ;;
        *zsh*) DETECTED_PROFILE="${HOME}/.zshrc" ;;
        *ksh*) DETECTED_PROFILE="${HOME}/.kshrc" ;;
        *) DETECTED_PROFILE="${HOME}/.profile" ;;
    esac
    printf "%s\n" "${DETECTED_PROFILE}"
}

###################################################
# Alternative to dirname command
# Globals: None
# Arguments: 1
#   ${1} = path of file or folder
# Result: read description
# Reference:
#   https://github.com/dylanaraps/pure-sh-bible#file-paths
###################################################
_dirname() {
    dir_dirname="${1:-.}"
    dir_dirname="${dir_dirname%%"${dir_dirname##*[!/]}"}" && [ "${dir_dirname##*/*}" ] && dir_dirname=.
    dir_dirname="${dir_dirname%/*}" && dir_dirname="${dir_dirname%%"${dir_dirname##*[!/]}"}"
    printf '%s\n' "${dir_dirname:-/}"
}

###################################################
# print column size
# use bash or zsh or stty or tput
###################################################
_get_columns_size() {
    { command -v bash 1>| /dev/null && bash -c 'shopt -s checkwinsize && (: && :); printf "%s\n" "${COLUMNS}" 2>&1'; } ||
        { command -v zsh 1>| /dev/null && zsh -c 'printf "%s\n" "${COLUMNS}"'; } ||
        { command -v stty 1>| /dev/null && _tmp="$(stty size)" && printf "%s\n" "${_tmp##* }"; } ||
        { command -v tput 1>| /dev/null && tput cols; } ||
        return 1
}

###################################################
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
# Globals: None
# Arguments: 3
#   ${1} = repo name
#   ${2} = sha sum or branch name or tag name
#   ${3} = path ( optional )
# Result: print fetched shas
###################################################
_get_files_and_commits() {
    repo_get_files_and_commits="${1:-${REPO}}" type_value_get_files_and_commits="${2:-${LATEST_CURRENT_SHA}}" path_get_files_and_commits="${3:-}"
    unset html_get_files_and_commits commits_get_files_and_commits files_get_files_and_commits

    # shellcheck disable=SC2086
    html_get_files_and_commits="$(curl -s --compressed "https://github.com/${repo_get_files_and_commits}/file-list/${type_value_get_files_and_commits}/${path_get_files_and_commits}")" ||
        { _print_center "normal" "Error: Cannot fetch" " update details" "=" 1>&2 && exit 1; }
    commits_get_files_and_commits="$(printf "%s\n" "${html_get_files_and_commits}" | grep -o "commit/.*\"" | sed -e 's/commit\///g' -e 's/\"//g' -e 's/>.*//g')"
    # shellcheck disable=SC2001
    files_get_files_and_commits="$(printf "%s\n" "${html_get_files_and_commits}" | grep -oE '(blob|tree)/'"${type_value_get_files_and_commits}"'.*\"' | sed -e 's/\"//g' -e 's/>.*//g')"

    total_files="$(($(printf "%s\n" "${files_get_files_and_commits}" | wc -l)))"
    total_commits="$(($(printf "%s\n" "${commits_get_files_and_commits}" | wc -l)))"
    if [ "$((total_files - 2))" -eq "${total_commits}" ]; then
        files_get_files_and_commits="$(printf "%s\n" "${files_get_files_and_commits}" | sed 1,2d)"
    elif [ "${total_files}" -gt "${total_commits}" ]; then
        files_get_files_and_commits="$(printf "%s\n" "${files_get_files_and_commits}" | sed 1d)"
    fi

    exec 4<< EOF
$(printf "%s\n" "${files_get_files_and_commits}")
EOF
    exec 5<< EOF
$(printf "%s\n" "${commits_get_files_and_commits}")
EOF
    while read -r file <&4 && read -r commit <&5; do
        printf "%s\n" "${file##blob\/${type_value_get_files_and_commits}\/}__.__${commit}"
    done | grep -v tree || :
    exec 4<&- && exec 5<&-

    return 0
}

###################################################
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
# Globals: None
# Arguments: 3
#   ${1} = "branch" or "release"
#   ${2} = branch name or release name
#   ${3} = repo name e.g labbots/google-drive-upload
# Result: print fetched sha
###################################################
_get_latest_sha() {
    unset latest_sha_get_latest_sha raw_get_latest_sha
    case "${1:-${TYPE}}" in
        branch)
            latest_sha_get_latest_sha="$(
                raw_get_latest_sha="$(curl --compressed -s https://github.com/"${3:-${REPO}}"/commits/"${2:-${TYPE_VALUE}}".atom -r 0-2000)"
                _tmp="$(printf "%s\n" "${raw_get_latest_sha}" | grep -o "Commit\\/.*<" -m1 || :)" && _tmp="${_tmp##*\/}" && printf "%s\n" "${_tmp%%<*}"
            )"
            ;;
        release)
            latest_sha_get_latest_sha="$(
                raw_get_latest_sha="$(curl -L --compressed -s https://github.com/"${3:-${REPO}}"/releases/"${2:-${TYPE_VALUE}}")"
                _tmp="$(printf "%s\n" "${raw_get_latest_sha}" | grep "=\"/""${3:-${REPO}}""/commit" -m1 || :)" && _tmp="${_tmp##*commit\/}" && printf "%s\n" "${_tmp%%\"*}"
            )"
            ;;
    esac
    printf "%b" "${latest_sha_get_latest_sha:+${latest_sha_get_latest_sha}\n}"
}

###################################################
# Check if script running in a terminal
# Globals: 1 variable
#   TERM
# Arguments: None
# Result: return 1 or 0
###################################################
_is_terminal() {
    { [ -t 1 ] || [ -z "${TERM}" ]; } && return 0 || return 1
}

###################################################
# Print a text to center interactively and fill the rest of the line with text specified.
# This function is fine-tuned to this script functionality, so may appear unusual.
# Globals: 1 variable
#   COLUMNS
# Arguments: 4
#   If ${1} = normal
#      ${2} = text to print
#      ${3} = symbol
#   If ${1} = justify
#      If remaining arguments = 2
#         ${2} = text to print
#         ${3} = symbol
#      If remaining arguments = 3
#         ${2}, ${3} = text to print
#         ${4} = symbol
# Result: read description
# Reference:
#   https://gist.github.com/TrinityCoder/911059c83e5f7a351b785921cf7ecda
###################################################
_print_center() {
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    term_cols_print_center="${COLUMNS}"
    type_print_center="${1}" filler_print_center=""
    case "${type_print_center}" in
        normal) out_print_center="${2}" && symbol_print_center="${3}" ;;
        justify)
            if [ $# = 3 ]; then
                input1_print_center="${2}" symbol_print_center="${3}" to_print_print_center="" out_print_center=""
                to_print_print_center="$((term_cols_print_center - 5))"
                { [ "${#input1_print_center}" -gt "${to_print_print_center}" ] && out_print_center="[ $(printf "%.${to_print_print_center}s\n" "${input1_print_center}")..]"; } ||
                    { out_print_center="[ ${input1_print_center} ]"; }
            else
                input1_print_center="${2}" input2_print_center="${3}" symbol_print_center="${4}" to_print_print_center="" temp_print_center="" out_print_center=""
                to_print_print_center="$((term_cols_print_center * 47 / 100))"
                { [ "${#input1_print_center}" -gt "${to_print_print_center}" ] && temp_print_center=" $(printf "%.${to_print_print_center}s\n" "${input1_print_center}").."; } ||
                    { temp_print_center=" ${input1_print_center}"; }
                to_print_print_center="$((term_cols_print_center * 46 / 100))"
                { [ "${#input2_print_center}" -gt "${to_print_print_center}" ] && temp_print_center="${temp_print_center}$(printf "%.${to_print_print_center}s\n" "${input2_print_center}").. "; } ||
                    { temp_print_center="${temp_print_center}${input2_print_center} "; }
                out_print_center="[${temp_print_center}]"
            fi
            ;;
        *) return 1 ;;
    esac

    str_len_print_center="${#out_print_center}"
    [ "${str_len_print_center}" -ge "$((term_cols_print_center - 1))" ] && {
        printf "%s\n" "${out_print_center}" && return 0
    }

    filler_print_center_len="$(((term_cols_print_center - str_len_print_center) / 2))"

    i_print_center=1 && while [ "${i_print_center}" -le "${filler_print_center_len}" ]; do
        filler_print_center="${filler_print_center}${symbol_print_center}" && i_print_center="$((i_print_center + 1))"
    done

    printf "%s%s%s" "${filler_print_center}" "${out_print_center}" "${filler_print_center}"
    [ "$(((term_cols_print_center - str_len_print_center) % 2))" -ne 0 ] && printf "%s" "${symbol_print_center}"
    printf "\n"

    return 0
}

###################################################
# Alternative to timeout command
# Globals: None
# Arguments: 1 and rest
#   ${1} = amount of time to sleep
#   rest = command to execute
# Result: Read description
# Reference:
#   https://stackoverflow.com/a/24416732
###################################################
_timeout() {
    timeout_timeout="${1:?Error: Specify Timeout}" && shift
    {
        "${@}" &
        child="${!}"
        trap -- "" TERM
        {
            sleep "${timeout_timeout}"
            kill -9 "${child}"
        } &
        wait "${child}"
    } 2> /dev/null 1>&2
}

###################################################
# Config updater
# Incase of old value, update, for new value add.
# Globals: None
# Arguments: 3
#   ${1} = value name
#   ${2} = value
#   ${3} = config path
# Result: read description
###################################################
_update_config() {
    [ $# -lt 3 ] && printf "Missing arguments\n" && return 1
    value_name_update_config="${1}" value_update_config="${2}" config_path_update_config="${3}"
    ! [ -f "${config_path_update_config}" ] && : "" >| "${config_path_update_config}" # If config file doesn't exist.
    printf "%s\n%s\n" "$(grep -v -e "^$" -e "^${value_name_update_config}=" "${config_path_update_config}" || :)" \
        "${value_name_update_config}=\"${value_update_config}\"" >| "${config_path_update_config}"
}

###################################################
# Initialize default variables
# Globals: 1 variable, 1 function
#   Variable - HOME
#   Function - _detect_profile
# Arguments: None
# Result: read description
###################################################
_variables() {
    REPO="labbots/google-drive-upload"
    COMMAND_NAME="gupload"
    SYNC_COMMAND_NAME="gsync"
    INFO_PATH="${HOME}/.google-drive-upload"
    INSTALL_PATH="${HOME}/.google-drive-upload/bin"
    CONFIG="${HOME}/.googledrive.conf"
    TYPE="release"
    TYPE_VALUE="latest"
    SHELL_RC="$(_detect_profile)"
    LAST_UPDATE_TIME="$(if [ "${INSTALLATION}" = bash ]; then
        bash -c 'printf "%(%s)T\\n" "-1"'
    else
        date +'%s'
    fi)" && export LAST_UPDATE_TIME

    # shellcheck source=/dev/null
    [ -r "${INFO_PATH}/google-drive-upload.info" ] && . "${INFO_PATH}"/google-drive-upload.info

    [ -n "${SKIP_SYNC}" ] && SYNC_COMMAND_NAME=""
    __VALUES_LIST="REPO COMMAND_NAME ${SYNC_COMMAND_NAME:+SYNC_COMMAND_NAME} INSTALL_PATH CONFIG TYPE TYPE_VALUE SHELL_RC LAST_UPDATE_TIME AUTO_UPDATE_INTERVAL INSTALLATION"
    return 0
}

###################################################
# Download scripts
###################################################
_download_files() {
    files_with_commits="$(_get_files_and_commits "${REPO}" "${LATEST_CURRENT_SHA}" "${INSTALLATION}" | grep -E "upload.${INSTALLATION}|utils.${INSTALLATION}|sync.${INSTALLATION}")"
    repo="${REPO}"

    cd "${INSTALL_PATH}" 2> /dev/null 1>&2 || exit 1

    while read -r line <&4; do
        file="${line%%__.__*}" && sha="${line##*__.__}"

        case "${file##${INSTALLATION}\/}" in
            upload.*) local_file="${COMMAND_NAME}" ;;
            sync.*) local_file="${SYNC_COMMAND_NAME}" && [ -n "${SKIP_SYNC}" ] && continue ;;
            *) local_file="${file##${INSTALLATION}\/}" ;;
        esac

        [ -f "${local_file}" ] && [ "$(sed -n -e '$p' "${local_file}" 2> /dev/null 1>&2 || :)" = "#${sha}" ] && continue
        _print_center "justify" "${local_file}" "-"
        # shellcheck disable=SC2086
        ! curl -s --compressed "https://raw.githubusercontent.com/${repo}/${sha}/${file}" -o "${local_file}" && return 1
        _clear_line 1

        printf "\n#%s\n" "${sha}" >> "${local_file}"
    done 4<< EOF
$(printf "%s\n" "${files_with_commits}")
EOF

    cd - 2> /dev/null 1>&2 || exit 1
    return 0
}

###################################################
# Inject utils folder realpath to both upload and sync scripts
###################################################
_inject_utils_path() {
    unset upload_inject_utils_path sync_inject_utils_path

    ! grep -q "UTILS_FOLDER=\"${INSTALL_PATH}\"" "${INSTALL_PATH}/${COMMAND_NAME}" 2> /dev/null 1>&2 &&
        upload_inject_utils_path="$(
            read -r line < "${INSTALL_PATH}/${COMMAND_NAME}" && printf "%s\n" "${line}" &&
                printf "%s\n" "UTILS_FOLDER=\"${INSTALL_PATH}\"" &&
                sed 1d "${INSTALL_PATH}/${COMMAND_NAME}"
        )" &&
        printf "%s\n" "${upload_inject_utils_path}" >| "${INSTALL_PATH}/${COMMAND_NAME}"

    [ -n "${SKIP_SYNC}" ] && return 0
    ! grep -q "UTILS_FOLDER=\"${INSTALL_PATH}\"" "${INSTALL_PATH}/${SYNC_COMMAND_NAME}" 2> /dev/null 1>&2 &&
        sync_inject_utils_path="$(
            read -r line < "${INSTALL_PATH}/${SYNC_COMMAND_NAME}" && printf "%s\n" "${line}"
            printf "%s\n" "UTILS_FOLDER=\"${INSTALL_PATH}\""
            sed 1d "${INSTALL_PATH}/${SYNC_COMMAND_NAME}"
        )" &&
        printf "%s\n" "${sync_inject_utils_path}" >| "${INSTALL_PATH}/${SYNC_COMMAND_NAME}"

    return 0
}

###################################################
# Install/Update the upload and sync script
# Globals: 10 variables, 6 functions
#   Variables - INSTALL_PATH, INFO_PATH, UTILS_FILE, COMMAND_NAME, SYNC_COMMAND_NAME, SHELL_RC, CONFIG,
#               TYPE, TYPE_VALUE, REPO, __VALUES_LIST ( array )
#   Functions - _print_center, _newline, _clear_line
#               _get_latest_sha, _update_config
# Arguments: None
# Result: read description
#   If cannot download, then print message and exit
###################################################
_start() {
    job="${1:-install}"

    [ "${job}" = install ] && mkdir -p "${INSTALL_PATH}" && _print_center "justify" 'Installing google-drive-upload..' "-"

    _print_center "justify" "Fetching latest version info.." "-"
    LATEST_CURRENT_SHA="$(_get_latest_sha "${TYPE}" "${TYPE_VALUE}" "${REPO}")"
    [ -z "${LATEST_CURRENT_SHA}" ] && "${QUIET:-_print_center}" "justify" "Cannot fetch remote latest version." "=" && exit 1
    _clear_line 1

    [ "${job}" = update ] && {
        [ "${LATEST_CURRENT_SHA}" = "${LATEST_INSTALLED_SHA}" ] && "${QUIET:-_print_center}" "justify" "Latest google-drive-upload already installed." "=" && return 0
        _print_center "justify" "Updating.." "-"
    }

    _print_center "justify" "Downloading scripts.." "-"
    if _download_files; then
        _inject_utils_path || { "${QUIET:-_print_center}" "justify" "Cannot edit installed files" ", check if create a issue on github with proper log." "=" && exit 1; }
        chmod +x "${INSTALL_PATH}"/*

        # Add/Update config and inject shell rc
        for i in ${__VALUES_LIST}; do
            _update_config "${i}" "$(eval printf "%s" \"\$"${i}"\")" "${INFO_PATH}"/google-drive-upload.info
        done
        _update_config LATEST_INSTALLED_SHA "${LATEST_CURRENT_SHA}" "${INFO_PATH}"/google-drive-upload.info
        _update_config PATH "${INSTALL_PATH}:"\$\{PATH\} "${INFO_PATH}"/google-drive-upload.binpath
        printf "%s\n" "${CONFIG}" >| "${INFO_PATH}"/google-drive-upload.configpath
        ! grep -qE "(.|source) ${INFO_PATH}/google-drive-upload.binpath" "${SHELL_RC}" 2> /dev/null &&
            printf "\n%s\n" ". ${INFO_PATH}/google-drive-upload.binpath" >> "${SHELL_RC}"

        for _ in 1 2; do _clear_line 1; done

        if [ "${job}" = install ]; then
            "${QUIET:-_print_center}" "justify" "Installed Successfully" "="
            "${QUIET:-_print_center}" "normal" "[ Command name: ${COMMAND_NAME} ]" "="
            [ -z "${SKIP_SYNC}" ] && "${QUIET:-_print_center}" "normal" "[ Sync command name: ${SYNC_COMMAND_NAME} ]" "="
            _print_center "justify" "To use the command, do" "-"
            _newline "\n" && _print_center "normal" ". ${SHELL_RC}" " "
            _print_center "normal" "or" " "
            _print_center "normal" "restart your terminal." " "
            _newline "\n" && _print_center "normal" "To update the script in future, just run ${COMMAND_NAME} -u/--update." " "
        else
            "${QUIET:-_print_center}" "justify" 'Successfully Updated.' "="
        fi
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Cannot download the scripts." "="
        exit 1
    fi
    return 0
}

###################################################
# Uninstall the script
# Globals: 5 variables, 2 functions
#   Variables - INSTALL_PATH, INFO_PATH, UTILS_FILE, COMMAND_NAME, SHELL_RC
#   Functions - _print_center, _clear_line
# Arguments: None
# Result: read description
#   If cannot edit the SHELL_RC, then print message and exit
#   Kill all sync jobs that are running
###################################################
_uninstall() {
    _print_center "justify" "Uninstalling.." "-"
    __bak="${INFO_PATH}/google-drive-upload.binpath"
    if _new_rc="$(sed -e "s|. ${__bak}||g" -e "s|source ${__bak}||g" "${SHELL_RC}")" && printf "%s\n" "${_new_rc}" >| "${SHELL_RC}"; then
        # Kill all sync jobs and remove sync folder
        [ -z "${SKIP_SYNC}" ] && command -v "${SYNC_COMMAND_NAME}" 2> /dev/null 1>&2 && {
            "${SYNC_COMMAND_NAME}" -k all 2> /dev/null 1>&2 || :
            rm -rf "${INFO_PATH}"/sync "${INSTALL_PATH:?}"/"${SYNC_COMMAND_NAME}"
        }
        rm -f "${INSTALL_PATH}"/"${COMMAND_NAME}" "${INSTALL_PATH}"/*utils."${INSTALLATION}" \
            "${INFO_PATH}"/google-drive-upload.info "${INFO_PATH}"/google-drive-upload.binpath \
            "${INFO_PATH}"/google-drive-upload.configpath "${INFO_PATH}"/update.log
        [ -z "$(find "${INFO_PATH}" -type f)" ] && rm -rf "${INFO_PATH}"
        _clear_line 1
        _print_center "justify" "Uninstall complete." "="
    else
        _print_center "justify" 'Error: Uninstall failed.' "="
    fi
    return 0
}

###################################################
# Process all arguments given to the script
# Globals: 1 variable, 1 function
#   Variable - SHELL_RC
#   Functions - _is_terminal
# Arguments: Many
#   ${@} = Flags with arguments
# Result: read description
#   If no shell rc file found, then print message and exit
###################################################
_setup_arguments() {
    _check_longoptions() {
        [ -z "${2}" ] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" &&
            exit 1
        return 0
    }

    while [ $# -gt 0 ]; do
        case "${1}" in
            -h | --help) _usage ;;
            -p | --path)
                _check_longoptions "${1}" "${2}"
                INSTALL_PATH="${2}" && shift
                ;;
            -r | --repo)
                _check_longoptions "${1}" "${2}"
                REPO="${2}" && shift
                ;;
            -c | --cmd)
                _check_longoptions "${1}" "${2}"
                COMMAND_NAME="${2}" && shift
                case "${2}" in
                    sync*) SYNC_COMMAND_NAME="${2##sync=}" && shift ;;
                esac
                ;;
            -B | --branch)
                _check_longoptions "${1}" "${2}"
                TYPE_VALUE="${2}" && shift
                TYPE=branch
                ;;
            -R | --release)
                _check_longoptions "${1}" "${2}"
                TYPE_VALUE="${2}" && shift
                TYPE=release
                ;;
            -s | --shell-rc)
                _check_longoptions "${1}" "${2}"
                SHELL_RC="${2}" && shift
                ;;
            -t | --time)
                _check_longoptions "${1}" "${2}"
                if [ "${2}" -gt 0 ] 2> /dev/null; then
                    AUTO_UPDATE_INTERVAL="$((2 * 86400))" && shift
                else
                    printf "\nError: -t/--time value can only be a positive integer.\n"
                    exit 1
                fi
                ;;
            -z | --config)
                _check_longoptions "${1}" "${2}"
                if [ -d "${2}" ]; then
                    printf "Error: -z/--config only takes filename as argument, given input ( %s ) is a directory." "${2}" 1>&2 && exit 1
                elif [ -f "${2}" ]; then
                    if [ -r "${2}" ]; then
                        CONFIG="$(_dirname "$(cd "${2}" && pwd)")" && shift
                    else
                        printf "Error: Current user doesn't have read permission for given config file ( %s ).\n" "${2}" 1>&2 && exit 1
                    fi
                else
                    CONFIG="${2}" && shift
                fi
                ;;
            --sh | --posix) INSTALLATION="sh" ;;
            -q | --quiet) QUIET="_print_center_quiet" ;;
            --skip-internet-check) SKIP_INTERNET_CHECK=":" ;;
            -U | --uninstall) UNINSTALL="true" ;;
            -D | --debug) DEBUG="true" && export DEBUG ;;
            *) printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1 ;;
        esac
        shift
    done

    # 86400 secs = 1 day
    AUTO_UPDATE_INTERVAL="${AUTO_UPDATE_INTERVAL:-432000}"

    [ -z "${SHELL_RC}" ] && printf "No default shell file found, use -s/--shell-rc to use custom rc file\n" && exit 1

    _check_debug

    return 0
}

main() {
    { command -v bash && [ "$(bash --version | grep -oE '[0-9]+\.[0-9]' | grep -o '^[0-9]')" -ge 4 ] && INSTALLATION="bash"; } 2> /dev/null 1>&2
    _check_dependencies "${?}" && INSTALLATION="${INSTALLATION:-sh}"

    set -o errexit -o noclobber

    _variables && _setup_arguments "${@}"

    _check_existing_command() {
        if command -v "${COMMAND_NAME}" 2> /dev/null 1>&2; then
            if grep -q COMMAND_NAME "${INFO_PATH}"/google-drive-upload.info 2> /dev/null 1>&2; then
                return 0
            else
                printf "%s\n" "Error: Cannot validate existing installation, make sure no other program is installed as ${COMMAND_NAME}."
                printf "%s\n" "You can use -c / --cmd flag to specify custom command name."
                printf "%s\n" "Otherwise uninstall the ${COMMAND_NAME} command manually and run this script again."
                exit 1
            fi
        else
            return 1
        fi
    }

    if [ -n "${UNINSTALL}" ]; then
        { _check_existing_command && _uninstall; } || {
            "${QUIET:-_print_center}" "justify" "google-drive-upload is not installed." "="
            exit 0
        }
    else
        "${SKIP_INTERNET_CHECK:-_check_internet}"
        { _check_existing_command && INSTALL_PATH="$(_dirname "$(command -v "${COMMAND_NAME}")")" &&
            _start update; } || {
            _start install
        }
    fi

    return 0
}

main "${@}"
