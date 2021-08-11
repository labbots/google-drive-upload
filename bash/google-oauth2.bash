#!/usr/bin/env bash
# shellcheck source=/dev/null

set -o errexit -o noclobber -o pipefail

_usage() {
    printf "%s\n" "
A simple curl OAuth2 authenticator for google drive. Utilizing api v3.

Usage:

    ./${0##*/} create - authenticates a new user with a fresh client id and secret.

    ./${0##*/} add - authenticates a new user but will use the client id and secret if available. If not, then same as create flag.

    ./${0##*/} refresh - gets a new access token. Make sure CLIENT_SECRET, CLIENT_ID and REFRESH_TOKEN is exported as an environment variable or CONFIG 

    ./${0##*/} help - show this help.

Make sure to export CONFIG as an environment variable if you want to use save new changes or want to use values from it. It should be in the format required by gupload.

Variable names - CLIENT_SECRET, CLIENT_ID and REFRESH_TOKEN

You can also export CLIENT_SECRET, CLIENT_ID and REFRESH_TOKEN as an environment variable if you don't want to use above method."
    exit 0
}

UTILS_FOLDER="${UTILS_FOLDER:-$(pwd)}"
{ . "${UTILS_FOLDER}"/common-utils.bash && . "${UTILS_FOLDER}"/auth-utils.bash; } || { printf "Error: Unable to source util files.\n" && exit 1; }

[[ $# = 0 ]] && _usage

_check_debug

_cleanup() {
    # unhide the cursor if hidden
    [[ -n ${SUPPORT_ANSI_ESCAPES} ]] && printf "\033[?25h\033[?7h"
    {
        # grab all script children pids
        script_children_pids="$(ps --ppid="${MAIN_PID}" -o pid=)"

        # kill all grabbed children processes
        # shellcheck disable=SC2086
        kill ${script_children_pids} 1>| /dev/null

        export abnormal_exit && if [[ -n ${abnormal_exit} ]]; then
            printf "\n\n%s\n" "Script exited manually."
            kill -- -$$ &
        fi
    } 2>| /dev/null || :
    return 0
}

trap 'abnormal_exit="1"; exit' INT TERM
trap '_cleanup' EXIT
trap '' TSTP # ignore ctrl + z

export MAIN_PID="$$"

export API_URL="https://www.googleapis.com"
export API_VERSION="v3" \
    SCOPE="${API_URL}/auth/drive" \
    REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob" \
    TOKEN_URL="https://accounts.google.com/o/oauth2/token"

# the credential functions require a config file to update, so just provide /dev/null if CONFIG variable is not exported
export CONFIG="${CONFIG:-"/dev/null"}"
_reload_config || return 1

case "${1}" in
    help) _usage ;;
    create) unset CLIENT_SECRET CLIENT_ID REFRESH_TOKEN ACCESS_TOKEN && CREATE_ACCOUNT="true" ;;
    add) unset REFRESH_TOKEN ACCESS_TOKEN && CREATE_ACCOUNT="true" ;;
    refresh)
        unset ACCESS_TOKEN
        [[ -z ${CLIENT_ID} ]] && printf "%s\n" "Missing CLIENT_ID variable, make sure to export to use refresh option." && _usage
        [[ -z ${CLIENT_SECRET} ]] && printf "%s\n" "Missing CLIENT_SECRET variable, make sure to export to use refresh option." && _usage
        [[ -z ${REFRESH_TOKEN} ]] && printf "%s\n" "Missing REFRESH_TOKEN variable, make sure to export to use refresh option." && _usage
        ;;
esac

_check_account_credentials || exit 1
[[ -n ${CREATE_ACCOUNT} ]] && printf "Refresh Token: %s\n\n" "${REFRESH_TOKEN}" 1>&2
printf "Access Token: %s\n" "${ACCESS_TOKEN}" 1>&2
exit 0
