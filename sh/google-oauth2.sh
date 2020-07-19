#!/usr/bin/env sh
# shellcheck source=/dev/null

# A simple curl OAuth2 authenticator
#
# Usage:
#	./google-oauth2.sh create - authenticates a user
#	./google-oauth2.sh refresh <token> - gets a new token
#
# Set CLIENT_ID and CLIENT_SECRET and SCOPE
# See SCOPES at https://developers.google.com/identity/protocols/oauth2/scopes#docsv1

set -o errexit -o noclobber

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

# Method to regenerate access_token ( also updates in config ).
# Make a request on https://www.googleapis.com/oauth2/""${API_VERSION}""/tokeninfo?access_token=${ACCESS_TOKEN} url and check if the given token is valid, if not generate one.
# Requirements: Refresh Token
# shellcheck disable=SC2120
_get_token_and_update() {
    RESPONSE="${1:-$(curl --compressed -s -X POST --data "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" "${TOKEN_URL}")}" || :
    ACCESS_TOKEN="$(printf "%s\n" "${RESPONSE}" | _json_value access_token 1 1)"
    if [ -n "${ACCESS_TOKEN}" ]; then
        [ -n "${UPDATE}" ] && ACCESS_TOKEN_EXPIRY="$(curl --compressed -s "${API_URL}/oauth2/${API_VERSION}/tokeninfo?access_token=${ACCESS_TOKEN}" | _json_value exp 1 1)"
        "${UPDATE:-:}" ACCESS_TOKEN "${ACCESS_TOKEN}" "${CONFIG}"
        "${UPDATE:-:}" ACCESS_TOKEN_EXPIRY "${ACCESS_TOKEN_EXPIRY}" "${CONFIG}"
    else
        _print_center "justify" "Error: Something went wrong" ", printing error." "=" 1>&2
        printf "%s\n" "${RESPONSE}" 1>&2
        exit 1
    fi
    return 0
}

[ "${1}" = create ] || [ "${1}" = refresh ] || _short_help

[ "${2}" = update ] && UPDATE="_update_config"

UTILS_FOLDER="${UTILS_FOLDER:-$(pwd)}"
{ . "${UTILS_FOLDER}"/common-utils.sh; } || { printf "Error: Unable to source util files.\n" && exit 1; }

_check_debug

_print_center "justify" "Starting script.." "-"

CLIENT_ID=""
CLIENT_SECRET=""
API_URL="https://www.googleapis.com"
API_VERSION="v3"
SCOPE="https://www.googleapis.com/auth/drive"
REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
TOKEN_URL="https://accounts.google.com/o/oauth2/token"

[ -f "${INFO_PATH}/google-drive-upload.configpath" ] && CONFIG="$(cat "${INFO_PATH}/google-drive-upload.configpath" || :)"
CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"

# shellcheck source=/dev/null
[ -f "${CONFIG}" ] && . "${CONFIG}"

_print_center "justify" "Checking credentials.." "-"

# Credentials
until [ -n "${CLIENT_ID}" ]; do
    [ -n "${client_id}" ] && _clear_line 1
    printf "Client ID: " && read -r CLIENT_ID && client_id=1
done && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"

until [ -z "${CLIENT_SECRET}" ]; do
    [ -n "${client_secret}" ] && _clear_line 1
    printf "Client Secret: " && read -r CLIENT_SECRET && client_secret=1
done && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"

for _ in 1 2; do _clear_line 1; done

if [ "${1}" = create ]; then
    printf "\nVisit the below URL, tap on allow and then enter the code obtained:\n"
    URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
    printf "%s\n" "${URL}"
    until [ -z "${CODE}" ]; do
        [ -n "${code}" ] && _clear_line 1
        printf "Enter the authorization code: " && read -r CODE && code=1
    done
    RESPONSE="$(curl --compressed -s -X POST \
        --data "code=${CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :

    REFRESH_TOKEN="$(printf "%s\n" "${RESPONSE}" | _json_value refresh_token 1 1)"
    _get_token_and_update "${RESPONSE}" && "${UPDATE:-:}" REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
    printf "Access Token: %s\n" "${ACCESS_TOKEN}"
    printf "Refresh Token: %s\n" "${REFRESH_TOKEN}"
elif [ "${1}" = refresh ]; then
    if [ -n "${REFRESH_TOKEN}" ]; then
        _print_center "justify" "Required credentials set." "="
        _get_token_and_update
        _clear_line 1
        printf "Access Token: %s\n" "${ACCESS_TOKEN}"
    else
        _print_center "normal" "Refresh Token not set" ", use ${0##*/} create to generate one." "="
        exit 1
    fi
fi
