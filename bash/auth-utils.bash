#!/usr/bin/env bash
# auth utils for Google Drive
# shellcheck source=/dev/null

###################################################
# Check if account name is valid by a regex expression
# Globals: None
# Arguments: 1
#   ${1} = Account name
# Result: read description and return 1 or 0
###################################################
_account_name_valid() {
    declare name="${1:-}" account_name_regex='^([A-Za-z0-9_])+$'
    [[ ${name} =~ ${account_name_regex} ]] || return 1
    return 0
}

###################################################
# Check if account exists
# First check if the given account is in correct format
# then check if client [id|token] and refresh token is present
# Globals: 2 functions
#   _set_value, _account_name_valid
# Arguments: 1
#   ${1} = Account name
# Result: read description and return 1 or 0
###################################################
_account_exists() {
    declare name="${1:-}" client_id client_secret refresh_token
    _account_name_valid "${name}" || return 1
    _set_value indirect client_id "ACCOUNT_${name}_CLIENT_ID"
    _set_value indirect client_secret "ACCOUNT_${name}_CLIENT_SECRET"
    _set_value indirect refresh_token "ACCOUNT_${name}_REFRESH_TOKEN"
    [[ -z ${client_id:+${client_secret:+${refresh_token}}} ]] && return 1
    return 0
}

###################################################
# Show all accounts configured in config file
# Globals: 2 variables, 4 functions
#   Variable - CONFIG, QUIET
#   Functions - _account_exists, _set_value, _print_center, _reload_config
# Arguments: None
# Result: SHOW all accounts, export COUNT and ACC_${count}_ACC dynamic variables
#         or print "No accounts configured yet."
###################################################
_all_accounts() {
    { _reload_config && _handle_old_config; } || return 1
    declare all_accounts && COUNT=0
    mapfile -t all_accounts <<< "$(grep -oE '^ACCOUNT_.*_CLIENT_ID' "${CONFIG}" | sed -e "s/ACCOUNT_//g" -e "s/_CLIENT_ID//g")"
    for account in "${all_accounts[@]}"; do
        [[ -n ${account} ]] && _account_exists "${account}" &&
            { [[ ${COUNT} = 0 ]] && "${QUIET:-_print_center}" "normal" " All available accounts. " "=" || :; } &&
            printf "%b" "$((COUNT += 1)). ${account} \n" && _set_value direct "ACC_${COUNT}_ACC" "${account}"
    done
    { [[ ${COUNT} -le 0 ]] && "${QUIET:-_print_center}" "normal" " No accounts configured yet. " "=" 1>&2; } || printf '\n'
    return 0
}

###################################################
# Setup a new account name
# If given account name is configured already, then ask for name
# after name has been properly setup, export ACCOUNT_NAME var
# Globals: 1 variable, 5 functions
#   Variable  - QUIET
#   Functions - _print_center, _account_exists, _clear_line, _account_name_valid, _reload_config
# Arguments: 1
#   ${1} = Account name ( optional )
# Result: read description and export ACCOUNT_NAME NEW_ACCOUNT_NAME
###################################################
_set_new_account_name() {
    _reload_config || return 1
    declare new_account_name="${1:-}" name_valid
    [[ -z ${new_account_name} ]] && {
        _all_accounts 2>| /dev/null
        "${QUIET:-_print_center}" "normal" " New account name: " "="
        "${QUIET:-_print_center}" "normal" "Info: Account names can only contain alphabets / numbers / dashes." " " && printf '\n'
    }
    until [[ -n ${name_valid} ]]; do
        if [[ -n ${new_account_name} ]]; then
            if _account_name_valid "${new_account_name}"; then
                if _account_exists "${new_account_name}"; then
                    "${QUIET:-_print_center}" "normal" " Warning: Given account ( ${new_account_name} ) already exists, input different name. " "-" 1>&2
                    unset new_account_name && continue
                else
                    export NEW_ACCOUNT_NAME="${new_account_name}" ACCOUNT_NAME="${new_account_name}" && name_valid="true" && continue
                fi
            else
                "${QUIET:-_print_center}" "normal" " Warning: Given account name ( ${new_account_name} ) invalid, input different name. " "-" 1>&2
                unset new_account_name && continue
            fi
        else
            [[ -t 1 ]] || { "${QUIET:-_print_center}" "normal" " Error: Not running in an interactive terminal, cannot ask for new account name. " 1>&2 && return 1; }
            printf -- "-> \e[?7l"
            read -r new_account_name
            printf '\e[?7h'
        fi
        _clear_line 1
    done
    "${QUIET:-_print_center}" "normal" " Given account name: ${NEW_ACCOUNT_NAME} " "="
    export ACCOUNT_NAME="${NEW_ACCOUNT_NAME}"
    return 0
}

###################################################
# Delete a account from config file
# Globals: 2 variables, 3 functions
#   Variables - CONFIG, QUIET
#   Functions - _account_exists, _print_center, _reload_config
# Arguments: None
# Result: check if account exists and delete from config, else print error message
###################################################
_delete_account() {
    { _reload_config && _handle_old_config; } || return 1
    declare account="${1:?Error: give account name}" regex config_without_values
    if _account_exists "${account}"; then
        regex="^ACCOUNT_${account}_(CLIENT_ID=|CLIENT_SECRET=|REFRESH_TOKEN=|ROOT_FOLDER=|ROOT_FOLDER_NAME=|ACCESS_TOKEN=|ACCESS_TOKEN_EXPIRY=)|DEFAULT_ACCOUNT=\"${account}\""
        config_without_values="$(grep -vE "${regex}" "${CONFIG}")"
        chmod u+w "${CONFIG}" || return 1 # change perms to edit
        printf "%s\n" "${config_without_values}" >| "${CONFIG}" || return 1
        chmod "a-w-r-x,u+r" "${CONFIG}" || return 1 # restore perms
        "${QUIET:-_print_center}" "normal" " Successfully deleted account ( ${account} ) from config. " "-"
        _reload_config # reload config if successfully deleted
    else
        "${QUIET:-_print_center}" "normal" " Error: Cannot delete account ( ${account} ) from config. No such account exists. " "-" 1>&2
    fi
    return 0
}

###################################################
# handle legacy config
# this will be triggered only if old config values are present, convert to new format
# new account will be created with "default" name, if default already taken, then add a number as suffix
# Globals: 7 variables, 2 functions
# Variables - CLIENT_ID  CLIENT_SECRET, REFRESH_TOKEN, ROOT_FOLDER, ROOT_FOLDER_NAME CONFIG, ACCOUNT_NAME
#   Functions - _account_exists, _reload_config
# Arguments: None
###################################################
_handle_old_config() {
    export CLIENT_ID CLIENT_SECRET REFRESH_TOKEN # to handle a shellcheck warning
    # only try to convert the if all three values are present
    [[ -n ${CLIENT_ID:+${CLIENT_SECRET:+${REFRESH_TOKEN}}} ]] && {
        declare account_name="default" regex config_without_values count=0
        # first try to name the new account as default, otherwise try to add numbers as suffix
        until ! _account_exists "${account_name}"; do
            account_name="${account_name}$((count += 1))"
        done
        # form a regex expression to remove values from config, _update_config isn't used here to prevent a loop and multiple grep calls
        regex="^(CLIENT_ID=|CLIENT_SECRET=|REFRESH_TOKEN=|ROOT_FOLDER=|ROOT_FOLDER_NAME=|ACCESS_TOKEN=|ACCESS_TOKEN_EXPIRY=)"
        config_without_values="$(grep -vE "${regex}" "${CONFIG}")"
        chmod u+w "${CONFIG}" || return 1 # change perms to edit
        printf "%s\n%s\n%s\n%s\n%s\n%s\n" \
            "ACCOUNT_${account_name}_CLIENT_ID=\"${CLIENT_ID}\"" \
            "ACCOUNT_${account_name}_CLIENT_SECRET=\"${CLIENT_SECRET}\"" \
            "ACCOUNT_${account_name}_REFRESH_TOKEN=\"${REFRESH_TOKEN}\"" \
            "ACCOUNT_${account_name}_ROOT_FOLDER=\"${ROOT_FOLDER}\"" \
            "ACCOUNT_${account_name}_ROOT_FOLDER_NAME=\"${ROOT_FOLDER_NAME}\"" \
            "${config_without_values}" >| "${CONFIG}" || return 1

        chmod "a-w-r-x,u+r" "${CONFIG}" || return 1 # restore perms

        _reload_config || return 1 # reload config file
    }
    return 0
}

###################################################
# handle old config values, new account creation, custom account name, updating default config and account
# start token service if applicable
# Globals: 12 variables, 7 functions
#   Variables - DEFAULT_CONFIG, NEW_ACCOUNT_NAME, CUSTOM_ACCOUNT_NAME, DELETE_ACCOUNT_NAME, LIST_ACCOUNTS, QUIET
#               UPDATE_DEFAULT_ACCOUNT, UPDATE_DEFAULT_CONFIG, CONFIG_INFO, CONTINUE_WITH_NO_INPUT
#   Functions - _reload_config, _handle_old_config, _set_new_account_name, _account_exists, _all_accounts
#               _check_account_credentials, _token_bg_service, _print_center, _update_config, _set_value
# Arguments: None
# Result: read description and start access token check in bg if required
###################################################
_check_credentials() {
    { _reload_config && _handle_old_config; } || return 1
    # set account name to default account name
    ACCOUNT_NAME="${DEFAULT_ACCOUNT}"

    if [[ -n ${NEW_ACCOUNT_NAME} ]]; then
        # create new account, --create-account flag
        _set_new_account_name "${NEW_ACCOUNT_NAME}" || return 1
        _check_account_credentials "${ACCOUNT_NAME}" || return 1
    else
        # use custom account, --account flag
        if [[ -n ${CUSTOM_ACCOUNT_NAME} ]]; then
            if _account_exists "${CUSTOM_ACCOUNT_NAME}"; then
                ACCOUNT_NAME="${CUSTOM_ACCOUNT_NAME}"
            else
                # error out in case CUSTOM_ACCOUNT_NAME is invalid
                "${QUIET:-_print_center}" "normal" " Error: No such account ( ${CUSTOM_ACCOUNT_NAME} ) exists. " "-" && return 1
            fi
        elif [[ -n ${DEFAULT_ACCOUNT} ]]; then
            # check if default account if valid or not, else set account name to nothing and remove default account in config
            _account_exists "${DEFAULT_ACCOUNT}" || {
                _update_config DEFAULT_ACCOUNT "" "${CONFIG}" && unset DEFAULT_ACCOUNT ACCOUNT_NAME && UPDATE_DEFAULT_ACCOUNT="_update_config"
            }
            # UPDATE_DEFAULT_ACCOUNT to true so that default config is updated later
        else
            UPDATE_DEFAULT_ACCOUNT="_update_config" # as default account doesn't exist
        fi

        # in case no account name is set at this point of script
        if [[ -z ${ACCOUNT_NAME} ]]; then
            # if accounts are configured but default account is not set
            # COUNT comes from _all_accounts function
            if _all_accounts 2>| /dev/null && [[ ${COUNT} -gt 0 ]]; then
                # set ACCOUNT_NAME without asking if only one account available
                if [[ ${COUNT} -eq 1 ]]; then
                    _set_value indirect ACCOUNT_NAME "ACC_1_ACC" # ACC_1_ACC comes from _all_accounts function
                else
                    "${QUIET:-_print_center}" "normal" " Above accounts are configured, but default one not set. " "="
                    if [[ -t 1 ]]; then
                        \  "${QUIET:-_print_center}" "normal" " Choose default account: " "-"
                        until [[ -n ${ACCOUNT_NAME} ]]; do
                            printf -- "-> \e[?7l"
                            read -r account_name
                            printf '\e[?7h'
                            if [[ ${account_name} -gt 0 && ${account_name} -le ${COUNT} ]]; then
                                _set_value indirect ACCOUNT_NAME "ACC_${COUNT}_ACC"
                            else
                                _clear_line 1
                            fi
                        done
                    else
                        # if not running in a terminal then choose 1st one as default
                        printf "%s\n" "Warning: Script is not running in a terminal, choosing first account as default."
                        _set_value indirect ACCOUNT_NAME "ACC_1_ACC" # ACC_1_ACC comes from _all_accounts function
                    fi
                fi
            else
                _set_new_account_name "" || return 1
                _check_account_credentials "${ACCOUNT_NAME}" || return 1
            fi
        fi
        _check_account_credentials "${ACCOUNT_NAME}" || return 1
    fi

    "${UPDATE_DEFAULT_ACCOUNT:-:}" DEFAULT_ACCOUNT "${ACCOUNT_NAME}" "${CONFIG}" # update default account if required
    "${UPDATE_DEFAULT_CONFIG:-:}" CONFIG "${CONFIG}" "${CONFIG_INFO}"            # update default config if required

    # only launch the token service if there was some input
    [[ -n ${CONTINUE_WITH_NO_INPUT} ]] || _token_bg_service # launch token bg service
    return 0
}

###################################################
# check credentials for a given account name
# Globals: 3 functions
# Functions - _check_client, _check_refresh_token, _check_access_token
# Arguments: 2
#   ${1} = Account name ( optional )
# Result: read description, return 1 or 0
###################################################
_check_account_credentials() {
    declare account_name="${1:-}"
    {
        _check_client ID "${account_name}" &&
            _check_client SECRET "${account_name}" &&
            _check_refresh_token "${account_name}" &&
            _check_access_token "${account_name}" check
    } || return 1
    return 0
}

###################################################
# Check client id or secret and ask if required
# Globals: 4 variables, 3 functions
# Variables - CONFIG, QUIET, CLIENT_ID_${ACCOUNT_NAME}, CLIENT_SECRET_${ACCOUNT_NAME}
#   Functions - _print_center, _update_config, _set_value
# Arguments: 2
#   ${1} = ID or SECRET
#   ${2} = Account name ( optional - if not given, then just CLIENT_[ID|SECRET] var is used )
# Result: read description and export ACCOUNT_name_CLIENT_[ID|SECRET] CLIENT_[ID|SECRET]
###################################################
_check_client() {
    declare type="CLIENT_${1:?Error: ID or SECRET}" account_name="${2:-}" \
        type_name type_value type_regex valid client message
    export client_id_regex='[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com' client_secret_regex='[0-9A-Za-z_-]+'
    type_name="${account_name:+ACCOUNT_${account_name}_}${type}"

    # set the type_value to the actual value of ACCOUNT_${account_name}_[ID|SECRET]
    _set_value indirect type_value "${type_name}"
    # set the type_regex to the actual value of client_id_regex or client_secret_regex
    _set_value indirect type_regex "${type}_regex"

    until [[ -n ${type_value} && -n ${valid} ]]; do
        [[ -n ${type_value} ]] && {
            if [[ ${type_value} =~ ${type_regex} ]]; then
                [[ -n ${client} ]] && { _update_config "${type_name}" "${type_value}" "${CONFIG}" || return 1; }
                valid="true" && continue
            else
                { [[ -n ${client} ]] && message="- Try again"; } || message="in config ( ${CONFIG} )"
                "${QUIET:-_print_center}" "normal" " Invalid Client ${1} ${message} " "-" && unset "${type_name}" client
            fi
        }
        [[ -z ${client} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter Client ${1} " "-"
        [[ -n ${client} ]] && _clear_line 1
        printf -- "-> "
        read -r "${type_name?}" && client=1
        _set_value indirect type_value "${type_name}"
    done

    # export ACCOUNT_name_CLIENT_[ID|SECRET]
    _set_value direct "${type_name}" "${type_value}"
    # export CLIENT_[ID|SECRET]
    _set_value direct "${type}" "${type_value}"

    return 0
}

###################################################
# Check refresh token and ask if required
# Globals: 8 variables, 4 functions
#   Variables -  CLIENT_ID, CLIENT_SECRET, REDIRECT_URI, TOKEN_URL, CONFIG, QUIET
#   Functions - _set_value, _print_center, _update_config, _check_access_token
# Arguments: 1
#   ${1} = Account name ( optional - if not given, then just REFRESH_TOKEN var is used )
# Result: read description & export REFRESH_TOKEN ACCOUNT_${account_name}_REFRESH_TOKEN
###################################################
_check_refresh_token() {
    # bail out before doing anything if client id and secret is not present, unlikely to happen but just in case
    [[ -z ${CLIENT_ID:+${CLIENT_SECRET}} ]] && return 1
    declare account_name="${1:-}" \
        refresh_token_regex='[0-9]//[0-9A-Za-z_-]+' authorization_code_regex='[0-9]/[0-9A-Za-z_-]+'
    declare refresh_token_name="${account_name:+ACCOUNT_${account_name}_}REFRESH_TOKEN" check_error

    _set_value indirect refresh_token_value "${refresh_token_name}"

    [[ -n ${refresh_token_value} ]] && {
        ! [[ ${refresh_token_value} =~ ${refresh_token_regex} ]] &&
            "${QUIET:-_print_center}" "normal" " Error: Invalid Refresh token in config file, follow below steps.. " "-" && unset refresh_token_value
    }

    [[ -z ${refresh_token_value} ]] && {
        printf "\n" && "${QUIET:-_print_center}" "normal" "If you have a refresh token generated, then type the token, else leave blank and press return key.." " "
        printf "\n" && "${QUIET:-_print_center}" "normal" " Refresh Token " "-" && printf -- "-> "
        read -r refresh_token_value
        if [[ -n ${refresh_token_value} ]]; then
            "${QUIET:-_print_center}" "normal" " Checking refresh token.. " "-"
            if [[ ${refresh_token_value} =~ ${refresh_token_regex} ]]; then
                _set_value direct REFRESH_TOKEN "${refresh_token_value}"
                { _check_access_token "${account_name}" skip_check &&
                    _update_config "${refresh_token_name}" "${refresh_token_value}" "${CONFIG}" &&
                    _clear_line 1; } || check_error=true
            else
                check_error=true
            fi
            [[ -n ${check_error} ]] && "${QUIET:-_print_center}" "normal" " Error: Invalid Refresh token given, follow below steps to generate.. " "-" && unset refresh_token_value
        else
            "${QUIET:-_print_center}" "normal" " No Refresh token given, follow below steps to generate.. " "-" && unset refresh_token_value
        fi

        [[ -z ${refresh_token_value} ]] && {
            printf "\n" && "${QUIET:-_print_center}" "normal" "Visit the below URL, tap on allow and then enter the code obtained" " "
            URL="https://accounts.google.com/o/oauth2/auth?client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}&scope=${SCOPE}&response_type=code&prompt=consent"
            printf "\n%s\n" "${URL}"
            declare AUTHORIZATION_CODE authorization_code AUTHORIZATION_CODE_VALID response
            until [[ -n ${AUTHORIZATION_CODE} && -n ${AUTHORIZATION_CODE_VALID} ]]; do
                [[ -n ${AUTHORIZATION_CODE} ]] && {
                    if [[ ${AUTHORIZATION_CODE} =~ ${authorization_code_regex} ]]; then
                        AUTHORIZATION_CODE_VALID="true" && continue
                    else
                        "${QUIET:-_print_center}" "normal" " Invalid CODE given, try again.. " "-" && unset AUTHORIZATION_CODE authorization_code
                    fi
                }
                { [[ -z ${authorization_code} ]] && printf "\n" && "${QUIET:-_print_center}" "normal" " Enter the authorization code " "-"; } || _clear_line 1
                printf -- "-> \e[?7l"
                read -r AUTHORIZATION_CODE && authorization_code=1
                printf '\e[?7h'
            done
            response="$(curl --compressed "${CURL_PROGRESS}" -X POST \
                --data "code=${AUTHORIZATION_CODE}&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&redirect_uri=${REDIRECT_URI}&grant_type=authorization_code" "${TOKEN_URL}")" || :
            _clear_line 1 1>&2

            refresh_token_value="$(_json_value refresh_token 1 1 <<< "${response}")" ||
                { printf "%s\n" "Error: Cannot fetch refresh token, make sure the authorization code was correct." && return 1; }

            _set_value direct REFRESH_TOKEN "${refresh_token_value}"
            { _check_access_token "${account_name}" skip_check "${response}" &&
                _update_config "${refresh_token_name}" "${refresh_token_value}" "${CONFIG}"; } || return 1
        }
        printf "\n"
    }

    # export ACCOUNT_name_REFRESH_TOKEN
    _set_value direct "${refresh_token_name}" "${refresh_token_value}"
    # export REFRESH_TOKEN
    _set_value direct REFRESH_TOKEN "${refresh_token_value}"

    return 0
}

###################################################
# Check access token and create/update if required
# Also update in config
# Globals: 9 variables, 3 functions
#   Variables - CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN, TOKEN_URL, CONFIG, API_URL, API_VERSION, QUIET
#   Functions - _print_center, _update_config, _set_value
# Arguments: 2
#   ${1} = Account name ( optional - if not given, then just ACCESS_TOKEN var is used )
#   ${2} = if skip_check, then force create access token, else check with regex and expiry
#   ${3} = json response ( optional )
# Result: read description & export ACCESS_TOKEN ACCESS_TOKEN_EXPIRY
###################################################
_check_access_token() {
    # bail out before doing anything if client id|secret or refresh token is not present, unlikely to happen but just in case
    [[ -z ${CLIENT_ID:+${CLIENT_SECRET:+${REFRESH_TOKEN}}} ]] && return 1

    declare account_name="${1:-}" no_check="${2:-false}" response_json="${3:-}" \
        token_name token_expiry_name token_value token_expiry_value response \
        access_token_regex='ya29\.[0-9A-Za-z_-]+'
    declare token_name="${account_name:+ACCOUNT_${account_name}_}ACCESS_TOKEN"
    declare token_expiry_name="${token_name}_EXPIRY"

    _set_value indirect token_value "${token_name}"
    _set_value indirect token_expiry_value "${token_expiry_name}"

    [[ ${no_check} = skip_check || -z ${token_value} || ${token_expiry_value:-0} -lt "$(printf "%(%s)T\\n" "-1")" || ! ${token_value} =~ ${access_token_regex} ]] && {
        response="${response_json:-$(curl --compressed -s -X POST --data \
            "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&refresh_token=${REFRESH_TOKEN}&grant_type=refresh_token" "${TOKEN_URL}")}" || :

        if token_value="$(_json_value access_token 1 1 <<< "${response}")"; then
            token_expiry_value="$(($(printf "%(%s)T\\n" "-1") + $(_json_value expires_in 1 1 <<< "${response}") - 1))"
            _update_config "${token_name}" "${token_value}" "${CONFIG}" || return 1
            _update_config "${token_expiry_name}" "${token_expiry_value}" "${CONFIG}" || return 1
        else
            "${QUIET:-_print_center}" "justify" "Error: Something went wrong" ", printing error." "=" 1>&2
            printf "%s\n" "${response}" 1>&2
            return 1
        fi
    }

    # export ACCESS_TOKEN and ACCESS_TOKEN_EXPIRY
    _set_value direct ACCESS_TOKEN "${token_value}"
    _set_value direct ACCESS_TOKEN_EXPIRY "${token_expiry_value}"

    # export INITIAL_ACCESS_TOKEN which is used on script cleanup
    _set_value direct INITIAL_ACCESS_TOKEN "${ACCESS_TOKEN}"
    return 0
}

###################################################
# load config file if available, else create a empty file
# uses global variable CONFIG
###################################################
_reload_config() {
    { [[ -r ${CONFIG} ]] && . "${CONFIG}"; } || { printf "" >> "${CONFIG}" || return 1; }
    return 0
}

###################################################
# launch a background service to check access token and update it
# checks ACCESS_TOKEN_EXPIRY, try to update before 5 mins of expiry, a fresh token gets 60 mins
# process will be killed when script exits or "${MAIN_PID}" is killed
# Globals: 4 variables, 1 function
#   Variables - ACCESS_TOKEN, ACCESS_TOKEN_EXPIRY, MAIN_PID, TMPFILE
#   Functions - _check_access_token
# Arguments: None
# Result: read description & export ACCESS_TOKEN_SERVICE_PID
###################################################
_token_bg_service() {
    [[ -z ${MAIN_PID} ]] && return 0 # don't start if MAIN_PID is empty
    printf "%b\n" "ACCESS_TOKEN=\"${ACCESS_TOKEN}\"\nACCESS_TOKEN_EXPIRY=\"${ACCESS_TOKEN_EXPIRY}\"" >| "${TMPFILE}_ACCESS_TOKEN"
    {
        until ! kill -0 "${MAIN_PID}" 2>| /dev/null 1>&2; do
            . "${TMPFILE}_ACCESS_TOKEN"
            CURRENT_TIME="$(printf "%(%s)T\\n" "-1")"
            REMAINING_TOKEN_TIME="$((ACCESS_TOKEN_EXPIRY - CURRENT_TIME))"
            if [[ ${REMAINING_TOKEN_TIME} -le 300 ]]; then
                # timeout after 30 seconds, it shouldn't take too long anyway, and update tmp config
                CONFIG="${TMPFILE}_ACCESS_TOKEN" _timeout 30 _check_access_token "" skip_check || :
            else
                TOKEN_PROCESS_TIME_TO_SLEEP="$(if [[ ${REMAINING_TOKEN_TIME} -le 301 ]]; then
                    printf "0\n"
                else
                    printf "%s\n" "$((REMAINING_TOKEN_TIME - 300))"
                fi)"
                sleep "${TOKEN_PROCESS_TIME_TO_SLEEP}"
            fi
            sleep 1
        done
    } &
    export ACCESS_TOKEN_SERVICE_PID="${!}"
    return 0
}

ALL_FUNCTIONS=(_account_name_valid
    _account_exists
    _all_accounts
    _set_new_account_name
    _delete_account
    _handle_old_config
    _check_credentials
    _check_account_credentials
    _check_client
    _check_refresh_token
    _check_access_token
    _reload_config)
export -f "${ALL_FUNCTIONS[@]}"
