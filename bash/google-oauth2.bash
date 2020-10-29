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

UTILS_FOLDER="${UTILS_FOLDER:-$(pwd)}"
{ . "${UTILS_FOLDER}"/common-utils.bash && . "${UTILS_FOLDER}"/drive-utils.bash; } || { printf "Error: Unable to source util files.\n" && exit 1; }

[[ ${1} = create ]] || [[ ${1} = refresh ]] || _short_help

[[ ${2} = update ]] || _update_config() { :; }

_check_debug

CLIENT_ID=""
CLIENT_SECRET=""
SCOPE="https://www.googleapis.com/auth/drive"
REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
TOKEN_URL="https://accounts.google.com/o/oauth2/token"

INFO_PATH="${HOME}/.google-drive-upload" CONFIG_INFO="${INFO_PATH}/google-drive-upload.configpath"
[[ -f ${CONFIG_INFO} ]] && . "${CONFIG_INFO}"
CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"

[[ -f ${CONFIG} ]] && . "${CONFIG}"

! [[ -t 2 ]] && [[ -z ${CLIENT_ID:+${CLIENT_SECRET:+${REFRESH_TOKEN}}} ]] && {
    printf "%s\n" "Error: Script is not running in a terminal, cannot ask for credentials."
    printf "%s\n" "Add in config manually if terminal is not accessible. CLIENT_ID, CLIENT_SECRET and REFRESH_TOKEN is required." && return 1
}

_print_center "justify" "Checking credentials.." "-"

# Following https://developers.google.com/identity/protocols/oauth2#size
CLIENT_ID_REGEX='[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com'
CLIENT_SECRET_REGEX='[0-9A-Za-z_-]+'
AUTHORIZATION_CODE_REGEX='[0-9]/[0-9A-Za-z_-]+' # 256 bytes

until [[ -n ${CLIENT_ID} && -n ${CLIENT_ID_VALID} ]]; do
    [[ -n ${CLIENT_ID} ]] && {
        if [[ ${CLIENT_ID} =~ ${CLIENT_ID_REGEX} ]]; then
            [[ -n ${client_id} ]] && _update_config CLIENT_ID "${CLIENT_ID}" "${CONFIG}"
            CLIENT_ID_VALID="true" && continue
        else
            { [[ -n ${client_id} ]] && message="- Try again"; } || message="in config ( ${CONFIG} )"
            "${QUIET:-_print_center}" "normal" " Invalid Client ID ${message} " "-" && unset CLIENT_ID client_id
        fi
    }
    [[ -z ${client_id} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter Client ID " "-"
    [[ -n ${client_id} ]] && _clear_line 1
    printf -- "-> "
    read -r CLIENT_ID && client_id=1
done

until [[ -n ${CLIENT_SECRET} && -n ${CLIENT_SECRET_VALID} ]]; do
    [[ -n ${CLIENT_SECRET} ]] && {
        if [[ ${CLIENT_SECRET} =~ ${CLIENT_SECRET_REGEX} ]]; then
            [[ -n ${client_secret} ]] && _update_config CLIENT_SECRET "${CLIENT_SECRET}" "${CONFIG}"
            CLIENT_SECRET_VALID="true" && continue
        else
            { [[ -n ${client_secret} ]] && message="- Try again"; } || message="in config ( ${CONFIG} )"
            "${QUIET:-_print_center}" "normal" " Invalid Client Secret ${message} " "-" && unset CLIENT_SECRET client_secret
        fi
    }
    [[ -z ${client_secret} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter Client Secret " "-"
    [[ -n ${client_secret} ]] && _clear_line 1
    printf -- "-> "
    read -r CLIENT_SECRET && client_secret=1
done

_clear_line 1

if [[ ${1} = create ]]; then
    printf "\n" && "${QUIET:-_print_center}" "normal" "Visit the below URL, tap on allow and then enter the code obtained" " "
    URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
    printf "\n%s\n" "${URL}"
    until [[ -n ${AUTHORIZATION_CODE} && -n ${AUTHORIZATION_CODE_VALID} ]]; do
        [[ -n ${AUTHORIZATION_CODE} ]] && {
            if grep -qE "${AUTHORIZATION_CODE_REGEX}" <<< "${AUTHORIZATION_CODE}"; then
                AUTHORIZATION_CODE_VALID="true" && continue
            else
                "${QUIET:-_print_center}" "normal" " Invalid CODE given, try again.. " "-" && unset AUTHORIZATION_CODE authorization_code
            fi
        }
        { [[ -z ${authorization_code} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter the authorization code " "-"; } || _clear_line 1
        printf -- "-> "
        read -r AUTHORIZATION_CODE && authorization_code=1
    done
    RESPONSE="$(curl --compressed "${CURL_PROGRESS}" -X POST \
        --data "code=${AUTHORIZATION_CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :
    _clear_line 1 1>&2

    REFRESH_TOKEN="$(_json_value refresh_token 1 1 <<< "${RESPONSE}" || :)"
    if _get_access_token_and_update "${RESPONSE}"; then
        _update_config REFRESH_TOKEN "${REFRESH_TOKEN}" "${CONFIG}"
        printf "Access Token: %s\n" "${ACCESS_TOKEN}"
        printf "Refresh Token: %s\n" "${REFRESH_TOKEN}"
    else
        return 1
    fi
elif [[ ${1} = refresh ]]; then
    if [[ -n ${REFRESH_TOKEN} ]]; then
        _print_center "justify" "Required credentials set." "="
        { _get_access_token_and_update && _clear_line 1; } || return 1
        printf "Access Token: %s\n" "${ACCESS_TOKEN}"
    else
        "${QUIET:-_print_center}" "normal" "Refresh Token not set" ", use ${0##*/} create to generate one." "="
        exit 1
    fi
fi
