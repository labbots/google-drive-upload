#!/usr/bin/env sh
# Common functions which will be used in both bash and posix scripts
# shellcheck source=/dev/null

###################################################
# Convert bytes to human readable form
# Required Arguments: 1
#   ${1} = Positive integer ( bytes )
# Result: Print human readable form.
# Reference:
#   https://unix.stackexchange.com/a/259254
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
# Result: If DEBUG
#   Present - Enable command trace and change print functions to avoid spamming.
#   Absent  - Disable command trace
#             Check QUIET, then check terminal size and enable print functions accordingly.
###################################################
_check_debug() {
    export DEBUG QUIET
    if [ -n "${DEBUG}" ]; then
        set -x && PS4='-> '
        _print_center() { { [ $# = 3 ] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _move_cursor() { :; } && _newline() { :; }
    else
        if [ -z "${QUIET}" ]; then
            # check if running in terminal and support ansi escape sequences
            if _support_ansi_escapes; then
                if ! _required_column_size; then
                    _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }

                fi
                export EXTRA_LOG="_print_center" CURL_PROGRESS="-#" CURL_PROGRESS_EXTRA="-#" SUPPORT_ANSI_ESCAPES="true"
            else
                _print_center() { { [ $# = 3 ] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                _clear_line() { :; } && _move_cursor() { :; }
            fi
            _newline() { printf "%b" "${1}"; }
        else
            _print_center() { :; } && _clear_line() { :; } && _move_cursor() { :; } && _newline() { :; }
        fi
        set +x
    fi
}

###################################################
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    "${EXTRA_LOG:-}" "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com --compressed; then
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
        return 1
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
# Alternative to dirname command
# Arguments: 1
#   ${1} = path of file or folder
# Result: read description
# Reference:
#   https://github.com/dylanaraps/pure-sh-bible#file-paths
###################################################
_dirname() {
    dir_dirname="${1:-.}"
    dir_dirname="${dir_dirname%%"${dir_dirname##*[!/]}"}" && [ -n "${dir_dirname##*/*}" ] && dir_dirname=.
    dir_dirname="${dir_dirname%/*}" && dir_dirname="${dir_dirname%%"${dir_dirname##*[!/]}"}"
    printf '%s\n' "${dir_dirname:-/}"
}

###################################################
# Convert given time in seconds to readable form
# 110 to 1 minute(s) and 50 seconds
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
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
# Arguments: 3
#   ${1} = "branch" or "release"
#   ${2} = branch name or release name
#   ${3} = repo name e.g labbots/google-drive-upload
# Result: print fetched sha
###################################################
_get_latest_sha() {
    export TYPE TYPE_VALUE REPO
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
        *) : ;;
    esac
    printf "%b" "${latest_sha_get_latest_sha:+${latest_sha_get_latest_sha}\n}"
}

###################################################
# Encode the given string to parse properly as json
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
    printf "%s\n" "${_tmp}" | sed -e "s|.*\"""${1}""\":||" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/^ //" -e 's/^"//' -n -e "${num_json_value}"p || :
    return 0
}

###################################################
# Function to parse config in format a=b
# Arguments: 2
#   ${1} - path to config file
#   ${2} - optional, if true will print the config
# Input: file
#   _parse_config file
# Result: all the values in the config file will be exported as variables
###################################################
_parse_config() {
    _config_file_parse_config="${1:?Error: Profile config file}"
    print_parse_config="${2:-false}"

    # check if the config file accessible
    [ -r "${_config_file_parse_config}" ] || {
        printf "%s\n" "Error: Given config file ( ${_config_file_parse_config} ) is not readable."
        return 1
    }

    # Setting 'IFS' tells 'read' where to split the string.
    while IFS='=' read -r key val; do
        # Skip Lines starting with '#'
        # Also skip lines if key and val variable is empty
        { [ -n "${key}" ] && [ -n "${val}" ] && [ -n "${key##\#*}" ]; } || continue

        # trim all leading white space
        key="${key#"${key%%[![:space:]]*}"}"
        val="${val#"${val%%[![:space:]]*}"}"

        # trim all trailing white space
        key="${key%"${key##*[![:space:]]}"}"
        val="${val%"${val##*[![:space:]]}"}"

        # trim the first and last qoute if present on both sides
        case "${val}" in
            \"*\") val="${val#\"}" val="${val%\"}" ;;
            \'*\') val="${val#\'}" val="${val%\'}" ;;
            *) : ;;
        esac

        # '$key' stores the key and '$val' stores the value.
        # Throw a warning if cannot export the variable
        export "${key}=${val}" 2> /dev/null || printf "%s\n" "Warning: ${key} is not a valid variable name."

        [ "${print_parse_config}" = true ] && echo "${key}=${val}"
    done < "${_config_file_parse_config}"

    return 0
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
# print_center arguments but normal print
###################################################
_print_center_quiet() {
    { [ $# = 3 ] && printf "%s\n" "${2}"; } ||
        { printf "%s%s\n" "${2}" "${3}"; }
}

###################################################
# Split a string on a delimiter
# Arguments: 2
#   ${1} = string
#   ${2} = delimiter
# Print each list value on its own line.
# Reference: https://github.com/dylanaraps/pure-sh-bible#split-a-string-on-a-delimiter
###################################################
_split() {
    # Disable globbing. This ensures that the word-splitting is safe.
    set -f

    # Store the current value of 'IFS' so we can restore it later.
    # shellcheck disable=2250
    old_ifs_split=$IFS

    # Change the field separator to what we're
    # splitting on.
    IFS=$2

    # Create an argument list splitting at each
    # occurance of '$2'.
    # This is safe to disable as it just warns against
    # word-splitting which is the behavior we expect.
    # shellcheck disable=2086
    set -- $1

    # Print each list value on its own line.
    printf '%s\n' "$@"

    # Restore the value of 'IFS'.
    # shellcheck disable=2250
    IFS=$old_ifs_split

    # Re-enable globbing.
    set +f
}

###################################################
# Check if script terminal supports ansi escapes
# Result: return 1 or 0
###################################################
_support_ansi_escapes() {
    unset ansi_escapes
    case "${TERM:-}" in
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
# Config updater
# Incase of old value, update, for new value add.
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
    chmod u+w -- "${config_path_update_config}" || return 1
    printf "%s\n%s\n" "$(grep -v -e "^$" -e "^${value_name_update_config}=" -- "${config_path_update_config}" || :)" \
        "${value_name_update_config}=\"${value_update_config}\"" >| "${config_path_update_config}" || return 1
    chmod a-w-r-x,u+r -- "${config_path_update_config}" || return 1
    return 0
}
