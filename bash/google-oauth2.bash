#!/usr/bin/env bash
# shellcheck source=/dev/null

# A simple curl OAuth2 authenticator
#
# Usage:
#	./google-oauth2.sh create - authenticates a user
#	./google-oauth2.sh refresh <token> - gets a new token
#
# Set CLIENT_ID and CLIENT_SECRET and SCOPE
# See SCOPES at https://developers.google.com/identity/protocols/oauth2/scopes#docsv1

set -o errexit -o noclobber -o pipefail

_short_help() {
    printf "
No valid arguments provided.
Usage:

 ./%s create - authenticates a user.
 ./%s refresh - gets a new access token.

  Use update as second argument to update the local config with the new REFRESH TOKEN.
  e.g: ./%s create/refresh update\n" "${0##*/}" "${0##*/}" "${0##*/}"
    exit 0
}

###################################################
# Method to regenerate access_token ( also updates in config ).
# Make a request on https://www.googleapis.com/oauth2/""${API_VERSION}""/tokeninfo?access_token=${ACCESS_TOKEN} url and check if the given token is valid, if not generate one.
# Globals: 8 variables, 2 functions
#   Variables - CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN, TOKEN_URL, CONFIG, API_URL, API_VERSION and QUIET
#   Functions - _update_config and _print_center
# Result: Update access_token and expiry else print error
###################################################
_get_access_token_and_update() {
    RESPONSE="${1:-$(curl --compressed -s -X POST --data "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" "${TOKEN_URL}")}" || :
    if ACCESS_TOKEN="$(_json_value access_token 1 1 <<< "${RESPONSE}")"; then
        [[ -n ${UPDATE} ]] && {
            _update_config ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
            _update_config ACCESS_TOKEN_EXPIRY "$(($(printf "%(%s)T\\n" "-1") + $(_json_value expires_in 1 1 <<< "${RESPONSE}")))" "${CONFIG}"
        }
    else
        _print_center "justify" "Error: Something went wrong" ", printing error." 1>&2
        printf "%s\n" "${RESPONSE}" 1>&2
        return 1
    fi
    return 0
}

[[ ${1} = create ]] || [[ ${1} = refresh ]] || _short_help

{ [[ ${2} = update ]] && UPDATE="true"; } || unset UPDATE

UTILS_FOLDER="${UTILS_FOLDER:-$(pwd)}"
{ . "${UTILS_FOLDER}"/common-utils.bash; } || { printf "Error: Unable to source util files.\n" && exit 1; }

_check_debug

_print_center "justify" "Starting script.." "-"

CLIENT_ID=""
CLIENT_SECRET=""
SCOPE="https://www.googleapis.com/auth/drive"
REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
TOKEN_URL="https://accounts.google.com/o/oauth2/token"

[[ -f "${INFO_PATH}/google-drive-upload.configpath" ]] && CONFIG="$(< "${INFO_PATH}/google-drive-upload.configpath")"
CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"

# shellcheck source=/dev/null
[[ -f ${CONFIG} ]] && source "${CONFIG}"

! [[ -t 2 ]] && [[ -z ${CLIENT_ID:+${CLIENT_SECRET:+${REFRESH_TOKEN}}} ]] && {
    printf "%s\n" "Error: Script is not running in a terminal, cannot ask for credentials."
    printf "%s\n" "Add in config manually if terminal is not accessible. CLIENT_ID, CLIENT_SECRET and REFRESH_TOKEN is required." && return 1
}

_print_center "justify" "Checking credentials.." "-"

# Credentials
until [[ -n ${CLIENT_ID} ]]; do
    [[ -n ${client_id} ]] && for _ in 1 2 3; do _clear_line 1; done
    printf "\n" && "${QUIET:-_print_center}" "normal" " Client ID " "-" && printf -- "-> "
    read -r CLIENT_ID && client_id=1
done && [[ -n ${client_id} ]] && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"

until [[ -n ${CLIENT_SECRET} ]]; do
    [[ -n ${client_secret} ]] && for _ in 1 2 3; do _clear_line 1; done
    printf "\n" && "${QUIET:-_print_center}" "normal" " Client Secret " "-" && printf -- "-> "
    read -r CLIENT_SECRET && client_secret=1
done && [[ -n ${client_secret} ]] && _update_config CLIENT_SECRET "${CLIENT_SECRET}" "${CONFIG}"

for _ in 1 2; do _clear_line 1; done

if [[ ${1} = create ]]; then
    "${QUIET:-_print_center}" "normal" "Visit the below URL, tap on allow and then enter the code obtained" " "
    URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
    printf "\n%s\n" "${URL}"
    until [[ -n ${CODE} ]]; do
        [[ -n ${code} ]] && for _ in 1 2 3; do _clear_line 1; done
        printf "\n" && "${QUIET:-_print_center}" "normal" "Enter the authorization code" "-" && printf -- "-> "
        read -r CODE && code=1
    done
    RESPONSE="$(curl --compressed -s -X POST \
        --data "code=${CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :

    REFRESH_TOKEN="$(_json_value refresh_token 1 1 <<< "${RESPONSE}" || :)"
    if _get_access_token_and_update "${RESPONSE}"; then
        "${UPDATE:-:}" REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
        printf "Access Token: %s\n" "${ACCESS_TOKEN}"
        printf "Refresh Token: %s\n" "${REFRESH_TOKEN}"
    fi
elif [[ ${1} = refresh ]]; then
    if [[ -n ${REFRESH_TOKEN} ]]; then
        _print_center "justify" "Required credentials set." "="
        _get_access_token_and_update
        _clear_line 1
        printf "Access Token: %s\n" "${ACCESS_TOKEN}"
    else
        "${QUIET:-_print_center}" "normal" "Refresh Token not set" ", use ${0##*/} create to generate one." "="
        exit 1
    fi
fi
