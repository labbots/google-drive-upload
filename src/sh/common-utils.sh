#!/usr/bin/env sh
# Functions that will used in core script
# posix functions

###################################################
# Check if something contains some
# Arguments:
#    ${1} = pattern to match, can be regex
#    ${2} = string where it should match the pattern
# Result: return 0 or 1
###################################################
_assert_regex() {
    grep -qE "${1:?Error: Missing pattern}" 0<< EOF
${2:?Missing string}
EOF
}

###################################################
# count number of lines using wc
###################################################
_count() {
    wc -l
}

###################################################
# Print epoch seconds
###################################################
_epoch() {
    date +'%s'
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
# Evaluates value1=value2
# Arguments: 3
#   ${1} = direct ( d ) or indirect ( i ) - ( evaluation mode )
#   ${2} = var name
#   ${3} = var value
# Result: export value1=value2
###################################################
_set_value() {
    case "${1:?}" in
        d | direct) export "${2:?}=${3}" ;;
        i | indirect) eval export "${2}"=\"\$"${3}"\" ;;
        *) return 1 ;;
    esac
}

###################################################
# Encode the given string to parse properly in network requests
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
