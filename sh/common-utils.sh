#!/usr/bin/env sh
# Functions that will used in core script
# posix functions

###################################################
# Convert bytes to human readable form
# Globals: None
# Required Arguments: 1
#   ${1} = Positive integer ( bytes )
# Result: Print human readable form.
# Reference:
#   https://unix.stackexchange.com/a/538015
###################################################
_bytes_to_human() {
    b_bytes_to_human="$(printf "%.0f\n" "${1:-0}")" s_bytes_to_human=0
    d_bytes_to_human='' type_bytes_to_human=''
    while [ "${b_bytes_to_human}" -gt 1024 ]; do
        d_bytes_to_human="$(printf ".%02d" $((b_bytes_to_human % 1024 * 100 / 1024)))"
        b_bytes_to_human=$((b_bytes_to_human / 1024)) && s_bytes_to_human=$((s_bytes_to_human += 1))
    done
    j=0 && for i in B KB MB GB TB PB EB YB ZB; do
        j="$((j += 1))" && [ "$((j - 1))" = "${s_bytes_to_human}" ] && type_bytes_to_human="${i}" && break
        continue
    done
    printf "%s\n" "${b_bytes_to_human}${d_bytes_to_human} ${type_bytes_to_human}"
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
    if [ -n "${DEBUG}" ]; then
        set -x && PS4='-> '
        _print_center() { { [ $# = 3 ] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _newline() { :; }
    else
        if [ -z "${QUIET}" ]; then
            # check if running in terminal and support ansi escape sequences
            if _support_ansi_escapes; then
                ! COLUMNS="$(_get_columns_size)" || [ "${COLUMNS:-0}" -lt 45 ] 2>| /dev/null &&
                    _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                export CURL_PROGRESS="-#" EXTRA_LOG="_print_center" CURL_PROGRESS_EXTRA="-#" SUPPORT_ANSI_ESCAPES="true"
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
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Globals: 3 functions
#   _print_center, _clear_line, _timeout
# Arguments: None
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    "${EXTRA_LOG}" "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com --compressed; then
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
        return 1
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
# Convert given time in seconds to readable form
# 110 to 1 minute(s) and 50 seconds
# Globals: None
# Arguments: 1
#   ${1} = Positive Integer ( time in seconds )
# Result: read description
# Reference:
#   https://stackoverflow.com/a/32164707
###################################################
_display_time() {
    t_display_time="${1}" day_display_time="$((t_display_time / 60 / 60 / 24))"
    hr_display_time="$((t_display_time / 60 / 60 % 24))" min_display_time="$((t_display_time / 60 % 60))" sec_display_time="$((t_display_time % 60))"
    [ "${day_display_time}" -gt 0 ] && printf '%d days ' "${day_display_time}"
    [ "${hr_display_time}" -gt 0 ] && printf '%d hrs ' "${hr_display_time}"
    [ "${min_display_time}" -gt 0 ] && printf '%d minute(s) ' "${min_display_time}"
    [ "${day_display_time}" -gt 0 ] || [ "${hr_display_time}" -gt 0 ] || [ "${min_display_time}" -gt 0 ] && printf 'and '
    printf '%d seconds\n' "${sec_display_time}"
}

###################################################
# print column size
# use zsh or stty or tput
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
# Encode the given string to parse properly as json
# Globals: None
# Arguments: 2
#   ${1} = json or something else
#   ${2} = input
# Result: if ${1} is j, then escape all chars, else only special chars
# Reference:
#   https://tools.ietf.org/html/rfc7159#section-7
###################################################
_json_escape() {
    mode_json_escape="${1:?Missing mode}" input_json_escape="${2:?Provide Input}" output_json_escape=""
    # just for refrence "s|'|\'|g"
    if [ "${mode_json_escape}" = "j" ]; then
        output_json_escape="$(printf "%s" "${input_json_escape}" | sed \
            -e "s|\\\|\\\\\\\|g" \
            -e "s|\/|\\\/|g" \
            -e 's/\"/\\\"/g' \
            -e "s/$(printf '\t')/\\t/g" \
            -e "s/$(printf '\r')/\\r/g" \
            -e "s/$(printf '\f')/\\f/g")"
    else
        output_json_escape="$(printf "%s" "${input_json_escape}" | sed \
            -e "s/$(printf '\t')/\\t/g" \
            -e "s/$(printf '\r')/\\r/g" \
            -e "s/$(printf '\f')/\\f/g")"
    fi
    # use awk because sed just messes up with newlines
    output_json_escape="$(printf "%s" "${output_json_escape}" | awk '{printf "%s%s",sep,$0; sep="\\n"} END{print ""}')"
    printf "%s" "${output_json_escape}"
}

###################################################
# Method to extract specified field data from json
# Globals: None
# Arguments: 2
#   ${1} - value of field to fetch from json
#   ${2} - Optional, no of lines to parse for the given field in 1st arg
#   ${3} - Optional, nth number of value from extracted values, default it 1.
# Input: file | pipe
#   _json_value "Arguments" < file
#   echo something | _json_value "Arguments"
# Result: print extracted value
###################################################
_json_value() {
    { [ "${2}" -gt 0 ] 2>| /dev/null && no_of_lines_json_value="${2}"; } || :
    { [ "${3}" -gt 0 ] 2>| /dev/null && num_json_value="${3}"; } || { ! [ "${3}" = all ] && num_json_value=1; }
    # shellcheck disable=SC2086
    _tmp="$(grep -o "\"${1}\"\:.*" ${no_of_lines_json_value:+-m} ${no_of_lines_json_value})" || return 1
    printf "%s\n" "${_tmp}" | sed -e "s/.*\"""${1}""\"://" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/^ //" -e 's/^"//' -n -e "${num_json_value}"p || :
    return 0
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
# Quiet version of _print_center
###################################################
_print_center_quiet() {
    { [ $# = 3 ] && printf "%s\n" "${2}"; } || printf "%s%s\n" "${2}" "${3}"
}

###################################################
# Evaluates value1=value2
# Globals: None
# Arguments: 3
#   ${1} = direct ( d ) or indirect ( i ) - ( evaluation mode )
#   ${2} = var name
#   ${3} = var value
# Result: export value1=value2
###################################################
_set_value() {
    mode_set_value="${1:?}" var_set_value="${2:?}" value_set_value="${3:?}"
    case "${mode_set_value}" in
        d | direct) export "${var_set_value}=${value_set_value}" ;;
        i | indirect) export "${var_set_value}=$(eval printf "%s" \"\$"${value_set_value}"\")" ;;
    esac
}

###################################################
# Check if script terminal supports ansi escapes
# Globals: 1 variable
#   TERM
# Arguments: None
# Result: return 1 or 0
###################################################
_support_ansi_escapes() {
    unset ansi_escapes
    case "${TERM}" in
        xterm* | rxvt* | urxvt* | linux* | vt* | screen*) ansi_escapes="true" ;;
    esac
    { [ -t 2 ] && [ -n "${ansi_escapes}" ] && return 0; } || return 1
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
    } 2>| /dev/null 1>&2
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
    ! [ -f "${config_path_update_config}" ] && : >| "${config_path_update_config}" # If config file doesn't exist.
    chmod u+w "${config_path_update_config}" || return 1
    printf "%s\n%s\n" "$(grep -v -e "^$" -e "^${value_name_update_config}=" "${config_path_update_config}" || :)" \
        "${value_name_update_config}=\"${value_update_config}\"" >| "${config_path_update_config}" || return 1
    chmod a-w-r-x,u+r "${config_path_update_config}" || return 1
    return 0
}

###################################################
# Encode the given string to parse properly in network requests
# Globals: None
# Arguments: 1
#   ${1} = string
# Result: print encoded string
# Reference:
#   https://stackoverflow.com/a/41405682
###################################################
_url_encode() (
    LC_ALL=C LANG=C
    awk 'BEGIN {while (y++ < 125) z[sprintf("%c", y)] = y
  while (y = substr(ARGV[1], ++j, 1))
  q = y ~ /[[:alnum:]]_.!~*\47()-]/ ? q y : q sprintf("%%%02X", z[y])
  print q}' "${1}"
)
