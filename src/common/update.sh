#!/usr/bin/env sh

###################################################
# Automatic updater, only update if script is installed system wide.
# Result: On
#   Update if AUTO_UPDATE_INTERVAL + LAST_UPDATE_TIME less than printf "%(%s)T\\n" "-1"
###################################################
_auto_update() {
    export COMMAND_NAME INSTALL_PATH TYPE TYPE_VALUE REPO LAST_UPDATE_TIME AUTO_UPDATE_INTERVAL
    command -v "${COMMAND_NAME}" 1> /dev/null &&
        if [ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]; then
            current_time="$(_epoch)"
            [ "$((LAST_UPDATE_TIME + AUTO_UPDATE_INTERVAL))" -lt "$(_epoch)" ] && _update update
            _update_value LAST_UPDATE_TIME "${current_time}"
        fi
    return 0
}

###################################################
# Install/Update/uninstall the script.
# Arguments: 1
#   ${1} = uninstall or update
# Result: On
#   ${1} = nothing - Update the script if installed, otherwise install.
#   ${1} = uninstall - uninstall the script
###################################################
_update() {
    job_update="${1:-update}"
    [ "${GLOBAL_INSTALL:-}" = true ] && ! [ "$(id -u)" = 0 ] && printf "%s\n" "Error: Need root access to update." && return 0
    [ "${job_update}" = uninstall ] && job_uninstall="--uninstall"
    _print_center "justify" "Fetching ${job_update} script.." "-"
    repo_update="${REPO:-labbots/google-drive-upload}" type_value_update="${TYPE_VALUE:-latest}" cmd_update="${COMMAND_NAME:-gupload}" path_update="${INSTALL_PATH:-${HOME}/.gdrive-downloader/bin}"
    { [ "${TYPE:-}" != branch ] && type_value_update="$(_get_latest_sha release "${type_value_update}" "${repo_update}")"; } || :
    if script_update="$(curl --compressed -Ls "https://github.com/${repo_update}/raw/${type_value_update}/install.sh")"; then
        _clear_line 1

        # check if the downloaded script has any syntax errors
        printf "%s\n" "${script_update}" | sh -n || {
            printf "%s\n" "Install script downloaded but malformed, try again and if the issue persists open an issue on github."
            return 1
        }
        # shellcheck disable=SC2248
        printf "%s\n" "${script_update}" | sh -s -- ${job_uninstall:-} --skip-internet-check --cmd "${cmd_update}" --path "${path_update}"
        current_time="$(date +'%s')"
        [ -z "${job_uninstall}" ] && _update_value LAST_UPDATE_TIME "${current_time}"
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Cannot download" " ${job_update} script." "=" 1>&2
        return 1
    fi
    return 0
}

###################################################
# Update in-script values
###################################################
_update_value() {
    command_path="${INSTALL_PATH:?}/${COMMAND_NAME:?}"
    value_name="${1:?}" value="${2:-}"
    script_without_value_and_shebang="$(grep -v "${value_name}=\".*\".* # added values" -- "${command_path}" | sed 1d)"
    new_script="$(
        sed -n 1p -- "${command_path}"
        printf "%s\n" "${value_name}=\"${value}\" # added values"
        printf "%s\n" "${script_without_value_and_shebang}"
    )"
    # check if the downloaded script has any syntax errors
    printf "%s\n" "${new_script}" | "${INSTALLATION:-bash}" -n || {
        printf "%s\n" "Update downloaded but malformed, try again and if the issue persists open an issue on github."
        return 1
    }
    chmod u+w -- "${command_path}" && printf "%s\n" "${new_script}" >| "${command_path}" && chmod "a-w-r-x,${PERM_MODE:-u}+r+x" -- "${command_path}"
    return 0
}
