#!/usr/bin/env bash
# Upload a file to Google Drive
# shellcheck source=/dev/null

main() {
    [[ $# = 0 ]] && {
        printf "No valid arguments provided, use -h/--help flag to see usage.\n"
        exit 0
    }

    [[ -z ${SELF_SOURCE} ]] && {
        # this is to export the functions so that can used in parallel functions
        set -a
        export UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}"
        export COMMON_PATH="${UTILS_FOLDER}/common"
        { . "${UTILS_FOLDER}/bash/common-utils.bash" &&
            . "${COMMON_PATH}/parser.sh" &&
            . "${COMMON_PATH}/upload-flags.sh" &&
            . "${COMMON_PATH}/auth-utils.sh" &&
            . "${COMMON_PATH}/common-utils.sh" &&
            . "${COMMON_PATH}/drive-utils.sh" &&
            . "${COMMON_PATH}/upload-utils.sh" &&
            . "${COMMON_PATH}/upload-common.sh"; } ||
            { printf "Error: Unable to source util files.\n" && exit 1; }
        set +a
    }
    # this var is used for posix scripts in download folder function inside xargs, but we don't need that here
    export SOURCE_UTILS=""

    [[ ${BASH_VERSINFO:-0} -ge 4 ]] || { printf "Bash version lower than 4.x not supported.\n" && return 1; }
    set -o noclobber -o pipefail || exit 1

    # the kill signal which is used to kill the whole script and children in case of ctrl + c
    export _SCRIPT_KILL_SIGNAL="--"

    # execute the main helper function which does the rest of stuff
    _main_helper "${@}" || exit 1
}

{ [[ -z ${SOURCED_GUPLOAD} ]] && main "${@}"; } || :
