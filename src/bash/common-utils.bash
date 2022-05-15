#!/usr/bin/env bash
# Functions that will used in core script

###################################################
# Check if something contains some
# Arguments:
#    ${1} = pattern to match, can be regex
#    ${2} = string where it should match the pattern
# Result: return 0 or 1
###################################################
_assert_regex() {
    declare pattern="${1:?Error: Missing pattern}" string="${2:?Missing string}"
    if [[ ${string} =~ ${pattern} ]]; then
        return 0
    else
        return 1
    fi
}

###################################################
# Alternative to cat command, just the basic function
# Arguments: 1 or many, file names
###################################################
cat() {
    for file in "${@}"; do
        printf "%s\n" "$(< "${file}")"
    done
}

###################################################
# Alternative to wc -l command
# Arguments: 1  or pipe
#   ${1} = file, _count < file
#          variable, _count <<< variable
#   pipe = echo something | _count
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#get-the-number-of-lines-in-a-file
###################################################
_count() {
    mapfile -tn 0 lines
    printf '%s\n' "${#lines[@]}"
}

###################################################
# Print epoch seconds
###################################################
_epoch() {
    printf "%(%s)T\\n" "-1"
}

###################################################
# fetch column size and check if greater than the num ( see in function)
# set trap on sigwinch to update COLUMNS variable
# return 1 or 0
###################################################
_required_column_size() {
    shopt -s checkwinsize && (: && :)
    if [[ ${COLUMNS} -gt 45 ]]; then
        trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
        return 0
    else
        return 1
    fi
}

###################################################
# Evaluates value1=value2
# Arguments: 3
#   ${1} = direct ( d ) or indirect ( i ) - ( evaluation mode )  #   ${2} = var name
#   ${3} = var value
# Result: export value1=value2
###################################################
_set_value() {
    case "${1:?}" in
        d | direct) export "${2:?}=${3}" ;;
        i | indirect) export "${2:?}=${!3}" ;;
        *) return 1 ;;
    esac
}

###################################################
# remove the given character from the given string
# 1st arg - character
# 2nd arg - string
# 3rd arg - var where to save the output
# print trimmed string if 3rd arg empty else set
###################################################
_trim() {
    declare char="${1}" str="${2}" var="${3}"

    if [[ -n ${var} ]]; then
        _set_value d "${var}" "${str//${char}/}"
    else
        printf "%s" "${str//${char}/}"
    fi
}

###################################################
# Encode the given string to parse properly in network requests
# Arguments: 1
#   ${1} = string
# Result: print encoded string
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#percent-encode-a-string
###################################################
_url_encode() {
    declare LC_ALL=C
    for ((i = 0; i < ${#1}; i++)); do
        : "${1:i:1}"
        case "${_}" in
            [a-zA-Z0-9.~_-])
                printf '%s' "${_}"
                ;;
            *)
                printf '%%%02X' "'${_}"
                ;;
        esac
    done 2>| /dev/null
    printf '\n'
}
