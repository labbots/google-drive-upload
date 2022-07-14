#!/usr/bin/env sh
# Install, Update or Uninstall google-drive-upload
# shellcheck source=/dev/null

_usage() {
    printf "%b" "
The script can be used to install google-drive-upload script in your system.\n
Usage: ${0##*/} [options.. ]\n
All flags are optional.\n
Options:\n
  -p | --path <dir_name> - Custom path where you want to install script.\nDefault Path: ${HOME}/.google-drive-upload. \n
  -c | --cmd <command_name> - Custom command name, after installation script will be available as the input argument.
      To change sync command name, use %s -c gupload sync='gsync'
      Default upload command: gupload
      Default sync command: gsync\n
  -r | --repo <Username/reponame> - Upload script from your custom repo,e.g --repo labbots/google-drive-upload, make sure your repo file structure is same as official repo.\n
  -R | --release <tag/release_tag> - Specify tag name for the github repo, applies to custom and default repo both.\n
  -b | -B | --branch <branch_name> - Specify branch name for the github repo, applies to custom and default repo both.\n
  -s | --shell-rc <shell_file> - Specify custom rc file, where PATH is supposed to be appended, by default script detects .zshrc and .bashrc.\n
  -t | --time 'no of days' - Specify custom auto update time ( given input will taken as number of days ) after which script will try to automatically update itself.\n
      Default: 5 days\n
  --skip-internet-check - Like the flag says.\n
  --sh | --posix - Force install posix scripts even if system has compatible bash binary present.\n
  -q | --quiet - Only show critical error/sucess logs.\n
  -U | --uninstall - Uninstall the script and remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Check if debug is enabled and enable command trace
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
            if _support_ansi_escapes; then
                if ! _required_column_size; then
                    _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }

                fi
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

    for program in curl find xargs mkdir rm grep sed sleep ps; do
        command -v "${program}" 2>| /dev/null 1>&2 || error_list="${error_list}\n${program}"
    done

    { ! command -v file && ! command -v mimetype; } 2>| /dev/null 1>&2 &&
        error_list="${error_list}\n\"file or mimetype\""

    [ "${posix_check_dependencies}" != 0 ] &&
        for program in awk cat date; do
            command -v "${program}" 2>| /dev/null 1>&2 || error_list="${error_list}\n${program}"
        done

    command -v tail 2>| /dev/null 1>&2 || warning_list="${warning_list}\ntail"

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
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
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
                _tmp="$(printf "%s\n" "${raw_get_latest_sha}" | grep "=\"/""${3:-${REPO}}""/commit" -i -m1 || :)" && _tmp="${_tmp##*commit\/}" && printf "%s\n" "${_tmp%%\"*}"
            )"
            ;;
        *) : ;;
    esac
    printf "%b" "${latest_sha_get_latest_sha:+${latest_sha_get_latest_sha}\n}"
}

###################################################
# Print a text to center interactively and fill the rest of the line with text specified.
# This function is fine-tuned to this script functionality, so may appear unusual.
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
    term_cols_print_center="${COLUMNS:-}"
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
# fetch column size and check if greater than the num ( see in function)
# return 1 or 0
###################################################
_required_column_size() {
    COLUMNS="$({ command -v bash 1>| /dev/null && bash -c 'shopt -s checkwinsize && (: && :); printf "%s\n" "${COLUMNS}" 2>&1'; } ||
        { command -v zsh 1>| /dev/null && zsh -c 'printf "%s\n" "${COLUMNS}"'; } ||
        { command -v stty 1>| /dev/null && _tmp="$(stty size)" && printf "%s\n" "${_tmp##* }"; } ||
        { command -v tput 1>| /dev/null && tput cols; })" || :

    [ "$((COLUMNS))" -gt 45 ] && return 0
}

###################################################
# Check if script terminal supports ansi escapes
# Result: return 1 or 0
###################################################
_support_ansi_escapes() {
    unset ansi_escapes
    case "${TERM}" in
        xterm* | rxvt* | urxvt* | linux* | vt* | screen*) ansi_escapes="true" ;;
        *) : ;;
    esac
    { [ -t 2 ] && [ -n "${ansi_escapes}" ] && return 0; } || return 1
}

###################################################
# Alternative to timeout command
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
    } 2>| /dev/null 1>&2
}

###################################################
# Initialize default variables
# Arguments: None
# Result: read description
###################################################
_variables() {
    REPO="labbots/google-drive-upload"
    COMMAND_NAME="gupload"
    SYNC_COMMAND_NAME="gsync"
    INFO_PATH="${HOME}/.google-drive-upload"
    INSTALL_PATH="${HOME}/.google-drive-upload/bin"
    INSTALL_RC_STRING="[ -f \"\${HOME}/.google-drive-upload/bin/${COMMAND_NAME}\" ] && [ -x \"\${HOME}/.google-drive-upload/bin\" ] && PATH=\"\${HOME}/.google-drive-upload/bin:\${PATH}\""
    TYPE="release"
    TYPE_VALUE="latest"
    SHELL_RC="$(_detect_profile)"
    # If bash installation, then use bash printf else date
    LAST_UPDATE_TIME="$(if [ "${INSTALLATION}" = bash ]; then
        bash -c 'printf "%(%s)T\\n" "-1"'
    else
        date +'%s'
    fi)" && export LAST_UPDATE_TIME
    GLOBAL_INSTALL="false" PERM_MODE="u"
    export GUPLOAD_INSTALLED_WITH="script"

    [ -n "${SKIP_SYNC}" ] && SYNC_COMMAND_NAME=""
    export VALUES_LIST="REPO COMMAND_NAME ${SYNC_COMMAND_NAME:+SYNC_COMMAND_NAME} INSTALL_PATH TYPE TYPE_VALUE LAST_UPDATE_TIME AUTO_UPDATE_INTERVAL INSTALLATION GLOBAL_INSTALL PERM_MODE GUPLOAD_INSTALLED_WITH"

    VALUES_REGEX="" && for i in VALUES_LIST ${VALUES_LIST}; do
        VALUES_REGEX="${VALUES_REGEX:+${VALUES_REGEX}|}^${i}=\".*\".* # added values"
    done

    return 0
}

###################################################
# Download scripts
###################################################
_download_file() {
    cd "${INSTALL_PATH}" 2>| /dev/null 1>&2 || exit 1
    # make the file writable if present
    [ -f "${INSTALL_PATH}/${COMMAND_NAME}" ] && chmod u+w -- "${INSTALL_PATH}/${COMMAND_NAME}"
    _print_center "justify" "${COMMAND_NAME}" "-"
    # now download the binary
    if script_download_file="$(curl -Ls --compressed "https://github.com/${REPO}/raw/${LATEST_CURRENT_SHA}/release/${INSTALLATION:-}/gupload")"; then
        # check if the downloaded script has any syntax errors, return 2 will be used later
        printf "%s\n" "${script_download_file}" | "${INSTALLATION}" -n || return 2
        printf "%s\n" "${script_download_file}" >| "${COMMAND_NAME}" || return 1
    else
        return 1
    fi
    _clear_line 1

    [ -n "${SKIP_SYNC}" ] && return 0
    # make the file writable if present
    [ -f "${INSTALL_PATH}/${SYNC_COMMAND_NAME}" ] && chmod u+w -- "${INSTALL_PATH}/${SYNC_COMMAND_NAME}"
    _print_center "justify" "${SYNC_COMMAND_NAME}" "-"
    # now download the binary
    if script_download_file="$(curl -Ls --compressed "https://github.com/${REPO}/raw/${LATEST_CURRENT_SHA}/release/${INSTALLATION:-}/gsync")"; then
        # check if the downloaded script has any syntax errors, return 2 will be used later
        printf "%s\n" "${script_download_file}" | "${INSTALLATION}" -n || return 2
        printf "%s\n" "${script_download_file}" >| "${SYNC_COMMAND_NAME}" || return 1
    else
        return 1
    fi
    _clear_line 1
    cd - 2>| /dev/null 1>&2 || exit 1
    return 0
}

###################################################
# Inject installation values to gupload script
###################################################
_inject_values() {
    shebang="$(sed -n 1p "${INSTALL_PATH}/${COMMAND_NAME}")"
    script_without_values_and_shebang="$(grep -vE "${VALUES_REGEX}" -- "${INSTALL_PATH}/${COMMAND_NAME}" | sed 1d)"
    {
        printf "%s\n" "${shebang}"
        for i in VALUES_LIST ${VALUES_LIST}; do
            printf "%s\n" "${i}=\"$(eval printf "%s" \"\$"${i}"\")\" # added values"
        done
        printf "%s\n" "LATEST_INSTALLED_SHA=\"${LATEST_CURRENT_SHA}\" # added values"
        printf "%s\n" "${script_without_values_and_shebang}"
    } 1>| "${INSTALL_PATH}/${COMMAND_NAME}"

    [ -n "${SKIP_SYNC}" ] && return 0
    script_without_values_and_shebang="$(grep -vE "${VALUES_REGEX}" -- "${INSTALL_PATH}/${SYNC_COMMAND_NAME}" | sed 1d)"
    printf "%s\n" "${script_without_values_and_shebang}" | sed "s|gupload|${COMMAND_NAME}|g" 1>| "${INSTALL_PATH}/${SYNC_COMMAND_NAME}"
}

###################################################
# Install/Update the download script
# Arguments: None
# Result: read description
#   If cannot upload, then print message and exit
###################################################
_start() {
    job="${1:-install}"

    [ "${job}" = install ] && {
        mkdir -p "${INSTALL_PATH}"
        _print_center "justify" 'Installing google-drive-upload..' "-"
    }

    _print_center "justify" "Fetching latest version info.." "-"
    LATEST_CURRENT_SHA="$(_get_latest_sha "${TYPE}" "${TYPE_VALUE}" "${REPO}")"
    [ -z "${LATEST_CURRENT_SHA}" ] && "${QUIET:-_print_center}" "justify" "Cannot fetch remote latest version." "=" && exit 1
    _clear_line 1

    [ "${job}" = update ] && {
        [ "${LATEST_CURRENT_SHA}" = "${LATEST_INSTALLED_SHA}" ] && "${QUIET:-_print_center}" "justify" "Latest google-drive-upload already installed." "=" && return 0
        _print_center "justify" "Updating.." "-"
    }

    _print_center "justify" "Downloading scripts.." "-"
    _download_file
    status_download_file="${?}"
    if [ "${status_download_file}" = 0 ]; then
        if ! _inject_values; then
            "${QUIET:-_print_center}" "normal" "Cannot edit installed files" ", check if create a issue on github with proper log." "="
            exit 1
        fi

        chmod "a-w-r-x,${PERM_MODE:-u}+x+r" -- "${INSTALL_PATH}/${COMMAND_NAME}"
        chmod "a-w-r-x,${PERM_MODE:-u}+x+r" -- "${INSTALL_PATH}/${SYNC_COMMAND_NAME}"

        for _ in 1 2; do _clear_line 1; done

        if [ "${job}" = install ]; then
            "${QUIET:-_print_center}" "justify" "Installed Successfully" "="
            "${QUIET:-_print_center}" "normal" "[ Command name: ${COMMAND_NAME} ]" "="

            [ "${GLOBAL_INSTALL}" = false ] && {
                "${QUIET:-_print_center}" "normal" " Add below line to your shell rc manually " "-" && printf "\n"
                "${QUIET:-_print_center}" "normal" "${INSTALL_RC_STRING}" " " && printf "\n"
                "${QUIET:-_print_center}" "normal" "Run below command" " " && printf "\n"
                printf "%s\n\n" "echo '${INSTALL_RC_STRING}' >> ${SHELL_RC}"
            }

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

        if [ "${status_download_file}" = 1 ]; then
            "${QUIET:-_print_center}" "justify" "Cannot download the scripts." "="
        else
            printf "%s\n" "Script downloaded but malformed, try again and if the issue persists open an issue on github."
        fi
        exit 1
    fi
    return 0
}

###################################################
# Uninstall the script
# Arguments: None
# Result: read description
#   If cannot edit the SHELL_RC if required, then print message and exit
###################################################
_uninstall() {
    _print_center "justify" "Uninstalling.." "-"

    chmod -f u+w -- "${INSTALL_PATH}/${COMMAND_NAME}"
    rm -f -- "${INSTALL_PATH:?}/${COMMAND_NAME:?}"

    [ -z "${SKIP_SYNC}" ] && command -v "${SYNC_COMMAND_NAME}" 2>| /dev/null 1>&2 && {
        chmod -f u+w -- "${INSTALL_PATH}/${SYNC_COMMAND_NAME}"
        rm -f -- "${INSTALL_PATH:?}/${SYNC_COMMAND_NAME:?}"
    }

    [ "${GLOBAL_INSTALL}" = false ] && [ -z "$(find "${INSTALL_PATH}" -type f 2>| /dev/null)" ] && rm -rf -- "${INSTALL_PATH:?}"
    [ -z "$(find "${INFO_PATH}" -type f 2>| /dev/null)" ] && rm -rf -- "${INFO_PATH:?}"

    [ "${GLOBAL_INSTALL}" = false ] && {
        "${QUIET:-_print_center}" "normal" " Remove below line from your shell rc manually " "-" && printf "\n"
        "${QUIET:-_print_center}" "normal" " Shell rc: ${SHELL_RC} " " " && printf "\n"
        printf "%s\n\n" "${INSTALL_RC_STRING}"
    }

    _print_center "justify" "Uninstall complete." "="
    return 0
}

###################################################
# Process all arguments given to the script
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
                _INSTALL_PATH="${2}" && shift
                ;;
            -r | --repo)
                _check_longoptions "${1}" "${2}"
                REPO="${2}" && shift
                ;;
            -c | --cmd)
                _check_longoptions "${1}" "${2}"
                COMMAND_NAME="${2}" && shift
                ;;
            -b | -B | --branch)
                _check_longoptions "${1}" "${2}"
                TYPE_VALUE="${2}" && shift
                TYPE=branch
                ;;
            -s | --shell-rc)
                _check_longoptions "${1}" "${2}"
                SHELL_RC="${2}" && shift
                ;;
            -t | --time)
                _check_longoptions "${1}" "${2}"
                if [ "${2}" -gt 0 ] 2>| /dev/null; then
                    AUTO_UPDATE_INTERVAL="$((2 * 86400))" && shift
                else
                    printf "\nError: -t/--time value can only be a positive integer.\n"
                    exit 1
                fi
                ;;
            --sh | --posix) INSTALLATION="sh" ;;
            -q | --quiet) QUIET="_print_quiet" ;;
            --skip-internet-check) SKIP_INTERNET_CHECK=":" ;;
            -U | --uninstall) UNINSTALL="true" ;;
            -D | --debug) DEBUG="true" && export DEBUG ;;
            *) printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1 ;;
        esac
        shift
    done

    # 86400 secs = 1 day
    AUTO_UPDATE_INTERVAL="${AUTO_UPDATE_INTERVAL:-432000}"

    INSTALL_PATH="${_INSTALL_PATH:-${INSTALL_PATH}}"
    mkdir -p "${INSTALL_PATH}" 2> /dev/null || :
    INSTALL_PATH="$(cd "${INSTALL_PATH%\/*}" && pwd)/${INSTALL_PATH##*\/}" || exit 1
    { printf "%s\n" "${PATH}" | grep -q -e "${INSTALL_PATH}:" -e "${INSTALL_PATH}/:" && IN_PATH="true"; } || :
    # modify install string literal if path changed
    if [ -n "${_INSTALL_PATH}" ]; then
        INSTALL_RC_STRING="[ -f \"${INSTALL_PATH}/${COMMAND_NAME}\" ] && [ -x \"${INSTALL_PATH}/${COMMAND_NAME}\" ] && PATH=\"${INSTALL_PATH}:\${PATH}\""
    fi

    # check if install path outside home dir and running as root
    [ -n "${INSTALL_PATH##"${HOME}"*}" ] && PERM_MODE="a" && GLOBAL_INSTALL="true" && ! [ "$(id -u)" = 0 ] &&
        printf "%s\n" "Error: Need root access to run the script for given install path ( ${INSTALL_PATH} )." && exit 1

    # global dir must be in executable path
    [ "${GLOBAL_INSTALL}" = true ] && [ -z "${IN_PATH}" ] &&
        printf "%s\n" "Error: Install path ( ${INSTALL_PATH} ) must be in executable path if it's outside user home directory." && exit 1

    _check_debug

    return 0
}

main() {
    { command -v bash && [ "$(bash -c 'printf "%s\n" ${BASH_VERSINFO:-0}')" -ge 4 ] && INSTALLATION="bash"; } 1>| /dev/null
    _check_dependencies "${?}" && INSTALLATION="${INSTALLATION:-sh}"

    set -o noclobber

    _variables && _setup_arguments "${@}"

    _check_existing_command() {
        if COMMAND_PATH="$(command -v "${COMMAND_NAME}")"; then
            if SCRIPT_VALUES="$(grep -E "${VALUES_REGEX}|^LATEST_INSTALLED_SHA=\".*\".* # added values|^SELF_SOURCE=\".*\"" -- "${COMMAND_PATH}" || :)" &&
                eval "${SCRIPT_VALUES}" 2> /dev/null && [ -n "${LATEST_INSTALLED_SHA:+${SELF_SOURCE}}" ]; then
                return 0
            else
                printf "%s\n" "Error: Cannot validate existing installation, make sure no other program is installed as ${COMMAND_NAME}."
                printf "%s\n\n" "You can use -c / --cmd flag to specify custom command name."
                printf "%s\n\n" "Create a issue on github with proper log if above mentioned suggestion doesn't work."
                exit 1
            fi
        else
            return 1
        fi
    }

    if [ -n "${UNINSTALL}" ]; then
        { _check_existing_command && _uninstall; } || {
            _uninstall 2>| /dev/null 1>&2 || :
            "${QUIET:-_print_center}" "justify" "google-drive-upload is not installed." "="
            exit 0
        }
    else
        "${SKIP_INTERNET_CHECK:-_check_internet}"
        { _check_existing_command && _start update; } || {
            _start install
        }
    fi

    return 0
}

main "${@}"
