#!/usr/bin/env sh
# Upload a file to Google Drive
# shellcheck source=/dev/null

main() {
    [ $# = 0 ] && {
        printf "No valid arguments provided, use -h/--help flag to see usage.\n"
        exit 0
    }

    export _SHELL="sh"
    if [ -z "${SELF_SOURCE}" ]; then
        export UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}"
        export COMMON_PATH="${UTILS_FOLDER}/common"
        # shellcheck disable=SC2089
        export SOURCE_UTILS=". '${UTILS_FOLDER}/sh/common-utils.sh' && 
        . '${COMMON_PATH}/parser.sh' &&
        . '${COMMON_PATH}/flags.sh' &&
        . '${COMMON_PATH}/auth-utils.sh' &&
        . '${COMMON_PATH}/common-utils.sh' &&
        . '${COMMON_PATH}/drive-utils.sh' &&
        . '${COMMON_PATH}/upload-utils.sh'
        . '${COMMON_PATH}/upload-common.sh'"
    else
        SCRIPT_PATH="$(cd "$(_dirname "${0}")" && pwd)/${0##*\/}" && export SCRIPT_PATH
        # shellcheck disable=SC2090
        export SOURCE_UTILS="SOURCED_GUPLOAD=true . '${SCRIPT_PATH}'"
    fi
    eval "${SOURCE_UTILS}" || { printf "Error: Unable to source util files.\n" && exit 1; }

    set -o noclobber

    # the kill signal which is used to kill the whole script and children in case of ctrl + c
    export _SCRIPT_KILL_SIGNAL="-9"

    # execute the main helper function which does the rest of stuff
    _main_helper "${@}" || exit 1
}

{ [ -z "${SOURCED_GUPLOAD}" ] && main "${@}"; } || :
