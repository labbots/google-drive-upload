#!/usr/bin/env bash
# Sync a FOLDER to google drive forever using labbots/google-drive-upload
# shellcheck source=/dev/null

_usage() {
    printf "%b" "
The script can be used to sync your local folder to google drive.

Utilizes google-drive-upload bash scripts.\n
Usage: ${0##*/} [options.. ]\n
Options:\n
  -d | --directory - Gdrive foldername.\n
  -k | --kill - to kill the background job using pid number ( -p flags ) or used with input, can be used multiple times.\n
  -j | --jobs - See all background jobs that were started and still running.\n
     Use --jobs v/verbose to more information for jobs.\n
  -p | --pid - Specify a pid number, used for --jobs or --kill or --info flags, can be used multiple times.\n
  -i | --info - See information about a specific sync using pid_number ( use -p flag ) or use with input, can be used multiple times.\n
  -t | --time <time_in_seconds> - Amount of time to wait before try to sync again in background.\n
     To set wait time by default, use ${0##*/} -t default='3'. Replace 3 with any positive integer.\n
  -l | --logs - To show the logs after starting a job or show log of existing job. Can be used with pid number ( -p flag ).
     Note: If multiple pid numbers or inputs are used, then will only show log of first input as it goes on forever.
  -a | --arguments - Additional arguments for gupload commands. e.g: ${0##*/} -a '-q -o -p 4 -d'.\n
     To set some arguments by default, use ${0##*/} -a default='-q -o -p 4 -d'.\n
  -fg | --foreground - This will run the job in foreground and show the logs.\n
  -in | --include 'pattern' - Only include the files with the given pattern to upload.\n
       e.g: ${0##*/} local_folder --include "*1*", will only include with files with pattern '1' in the name.\n
  -ex | --exclude 'pattern' - Exclude the files with the given pattern from uploading.\n
       e.g: ${0##*/} local_folder --exclude "*1*", will exclude all files with pattern '1' in the name.\n
  -c | --command 'command name'- Incase if gupload command installed with any other name or to use in systemd service.\n
  --sync-detail-dir 'dirname' - Directory where a job information will be stored.
     Default: ${HOME}/.google-drive-upload\n
  -s | --service 'service name' - To generate systemd service file to setup background jobs on boot.\n
  -D | --debug - Display script command trace, use before all the flags to see maximum script trace.\n
  -h | --help - Display usage instructions.\n"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Check if a pid exists by using ps
# Globals: None
# Arguments: 1
#   ${1} = pid number of a sync job
# Result: return 0 or 1
###################################################
_check_pid() {
    { ps -p "${1}" 2>| /dev/null 1>&2 && return 0; } || return 1
}

###################################################
# Show information about a specific sync job
# Globals: 1 variable, 2 functions
#   Variable - SYNC_LIST
#   Functions - _check_pid, _setup_loop_variables
# Arguments: 1
#   ${1} = pid number of a sync job
#   ${2} = anything: Prints extra information ( optional )
#   ${3} = all information about a job ( optional )
# Result: show job info and set RETURN_STATUS
###################################################
_get_job_info() {
    declare input local_folder pid times extra
    pid="${1}" && input="${3:-$(grep "${pid}" "${SYNC_LIST}" || :)}"

    if [[ -n ${input} ]]; then
        if times="$(ps -p "${pid}" -o etimes --no-headers)"; then
            printf "\n%s\n" "PID: ${pid}"
            : "${input#*"|:_//_:|"}" && local_folder="${_%%"|:_//_:|"*}"

            printf "Local Folder: %s\n" "${local_folder}"
            printf "Drive Folder: %s\n" "${input##*"|:_//_:|"}"
            printf "Running Since: %s\n" "$(_display_time "${times}")"

            [[ -n ${2} ]] && {
                extra="$(ps -p "${pid}" -o %cpu,%mem --no-headers || :)"
                printf "CPU usage:%s\n" "${extra% *}"
                printf "Memory usage: %s\n" "${extra##* }"
                _setup_loop_variables "${local_folder}" "${input##*"|:_//_:|"}"
                printf "Success: %s\n" "$(_count < "${SUCCESS_LOG}")"
                printf "Failed: %s\n" "$(_count < "${ERROR_LOG}")"
            }
            RETURN_STATUS=0
        else
            RETURN_STATUS=1
        fi
    else
        RETURN_STATUS=11
    fi
    return 0
}

###################################################
# Remove a sync job information from database
# Globals: 2 variables
#   SYNC_LIST, SYNC_DETAIL_DIR
# Arguments: 1
#   ${1} = pid number of a sync job
# Result: read description
###################################################
_remove_job() {
    declare pid="${1}" input local_folder drive_folder new_list
    input="$(grep "${pid}" "${SYNC_LIST}" || :)"

    if [ -n "${pid}" ]; then
        : "${input##*"|:_//_:|"}" && local_folder="${_%%"|:_//_:|"*}"
        drive_folder="${input##*"|:_//_:|"}"
        new_list="$(grep -v "${pid}" "${SYNC_LIST}" || :)"
        printf "%s\n" "${new_list}" >| "${SYNC_LIST}"
    fi

    rm -rf "${SYNC_DETAIL_DIR:?}/${drive_folder_remove_job:-${2}}${local_folder_remove_job:-${3}}"
    # Cleanup dir if empty
    { [[ -z $(find "${SYNC_DETAIL_DIR:?}/${drive_folder_remove_job:-${2}}" -type f || :) ]] && rm -rf "${SYNC_DETAIL_DIR:?}/${drive_folder_remove_job:-${2}}"; } 2>| /dev/null 1>&2
    return 0
}

###################################################
# Kill a sync job and do _remove_job
# Globals: 1 function
#   _remove_job
# Arguments: 1
#   ${1} = pid number of a sync job
# Result: read description
###################################################
_kill_job() {
    declare pid="${1}"
    kill -9 "${pid}" 2>| /dev/null 1>&2 || :
    _remove_job "${pid}"
    printf "Killed.\n"
}

###################################################
# Show total no of sync jobs running
# Globals: 1 variable, 2 functions
#   Variable - SYNC_LIST
#   Functions - _get_job_info, _remove_job
# Arguments: 1
#   ${1} = v/verbose: Prints extra information ( optional )
# Result: read description
###################################################
_show_jobs() {
    declare list pid total=0
    list="$(grep -v '^$' "${SYNC_LIST}" || :)"
    printf "%s\n" "${list}" >| "${SYNC_LIST}"

    while read -r -u 4 line; do
        if [[ -n ${line} ]]; then
            : "${line%%"|:_//_:|"*}" && pid="${_##*: }"
            _get_job_info "${pid}" "${1}" "${line}"
            { [[ ${RETURN_STATUS} = 1 ]] && _remove_job "${pid}"; } || { ((total += 1)) && no_task="printf"; }
        fi
    done 4< "${SYNC_LIST}"

    printf "\nTotal Jobs Running: %s\n" "${total}"
    [[ -z ${1} ]] && "${no_task:-:}" "For more info: %s -j/--jobs v/verbose\n" "${0##*/}"
    return 0
}

###################################################
# Setup required variables for a sync job
# Globals: 1 Variable
#   SYNC_DETAIL_DIR
# Arguments: 1
#   ${1} = Local folder name which will be synced
# Result: read description
###################################################
_setup_loop_variables() {
    declare folder="${1}" drive_folder="${2}"
    DIRECTORY="${SYNC_DETAIL_DIR}/${drive_folder}${folder}"
    PID_FILE="${DIRECTORY}/pid"
    SUCCESS_LOG="${DIRECTORY}/success_list"
    ERROR_LOG="${DIRECTORY}/failed_list"
    LOGS="${DIRECTORY}/logs"
}

###################################################
# Create folder and files for a sync job
# Globals: 4 variables
#   DIRECTORY, PID_FILE, SUCCESS_LOG, ERROR_LOG
# Arguments: None
# Result: read description
###################################################
_setup_loop_files() {
    mkdir -p "${DIRECTORY}"
    for file in PID_FILE SUCCESS_LOG ERROR_LOG; do
        printf "" >> "${!file}"
    done
    PID="$(< "${PID_FILE}")"
}

###################################################
# Check for new files in the sync folder and upload it
# A list is generated everytime, success and error.
# Globals: 4 variables
#   SUCCESS_LOG, ERROR_LOG, COMMAND_NAME, ARGS, GDRIVE_FOLDER
# Arguments: None
# Result: read description
###################################################
_check_and_upload() {
    declare all initial new_files new_file

    mapfile -t initial < "${SUCCESS_LOG}"
    mapfile -t all <<< "$(printf "%s\n%s\n" "$(< "${SUCCESS_LOG}")" "$(< "${ERROR_LOG}")")"

    # check if folder is empty
    [[ $(printf "%b\n" ./*) = "./*" ]] && return 0

    all+=(*)
    # shellcheck disable=SC2086
    { [ -n "${INCLUDE_FILES}" ] && mapfile -t all <<< "$(printf "%s\n" "${all[@]}" | grep -E ${INCLUDE_FILES})"; } || :
    # shellcheck disable=SC2086
    mapfile -t new_files <<< "$(eval grep -vxEf <(printf "%s\n" "${initial[@]}") <(printf "%s\n" "${all[@]}") ${EXCLUDE_FILES} || :)"

    [[ -n ${new_files[*]} ]] && printf "" >| "${ERROR_LOG}" && {
        declare -A Aseen && for new_file in "${new_files[@]}"; do
            { [[ ${Aseen[new_file]} ]] && continue; } || Aseen[${new_file}]=x
            if eval "\"${COMMAND_NAME}\"" "\"${new_file}\"" "${ARGS}"; then
                printf "%s\n" "${new_file}" >> "${SUCCESS_LOG}"
            else
                printf "%s\n" "${new_file}" >> "${ERROR_LOG}"
                printf "%s\n" "Error: Input - ${new_file}"
            fi
            printf "\n"
        done
    }
    return 0
}

###################################################
# Loop _check_and_upload function, sleep for sometime in between
# Globals: 1 variable, 1 function
#   Variable - SYNC_TIME_TO_SLEEP
#   Function - _check_and_upload
# Arguments: None
# Result: read description
###################################################
_loop() {
    while :; do
        _check_and_upload
        sleep "${SYNC_TIME_TO_SLEEP}"
    done
}

###################################################
# Check if a loop exists with given input
# Globals: 3 variables, 3 function
#   Variable - FOLDER, PID, GDRIVE_FOLDER
#   Function - _setup_loop_variables, _setup_loop_files, _check_pid
# Arguments: None
# Result: return 0 - No existing loop, 1 - loop exists, 2 - loop only in database
#   if return 2 - then remove entry from database
###################################################
_check_existing_loop() {
    _setup_loop_variables "${FOLDER}" "${GDRIVE_FOLDER}"
    _setup_loop_files
    if [[ -z ${PID} ]]; then
        RETURN_STATUS=0
    elif _check_pid "${PID}"; then
        RETURN_STATUS=1
    else
        _remove_job "${PID}"
        _setup_loop_variables "${FOLDER}" "${GDRIVE_FOLDER}"
        _setup_loop_files
        RETURN_STATUS=2
    fi
    return 0
}

###################################################
# Start a new sync job by _loop function
# Print sync job information
# Globals: 7 variables, 1 function
#   Variable - LOGS, PID_FILE, INPUT, GDRIVE_FOLDER, FOLDER, SYNC_LIST, FOREGROUND
#   Function - _loop
# Arguments: None
# Result: read description
#   Show logs at last and don't hangup if SHOW_LOGS is set
###################################################
_start_new_loop() {
    if [[ -n ${FOREGROUND} ]]; then
        printf "%b\n" "Local Folder: ${INPUT}\nDrive Folder: ${GDRIVE_FOLDER}\n"
        trap '_clear_line 1 && printf "\n" && _remove_job "" "${GDRIVE_FOLDER}" "${FOLDER}"; exit' INT TERM
        trap 'printf "Job stopped.\n" ; exit' EXIT
        _loop
    else
        (_loop &> "${LOGS}") & # A double fork doesn't get killed if script exits
        PID="${!}"
        printf "%s\n" "${PID}" >| "${PID_FILE}"
        printf "%b\n" "Job started.\nLocal Folder: ${INPUT}\nDrive Folder: ${GDRIVE_FOLDER}"
        printf "%s\n" "PID: ${PID}"
        printf "%b\n" "PID: ${PID}|:_//_:|${FOLDER}|:_//_:|${GDRIVE_FOLDER}" >> "${SYNC_LIST}"
        [[ -n ${SHOW_LOGS} ]] && tail -f "${LOGS}"
    fi
    return 0
}

###################################################
# Triggers in case either -j & -k or -l flag ( both -k|-j if with positive integer as argument )
# Priority: -j > -i > -l > -k
# Globals: 5 variables, 6 functions
#   Variables - JOB, SHOW_JOBS_VERBOSE, INFO_PID, LOG_PID, KILL_PID ( all array )
#   Functions - _check_pid, _setup_loop_variables
#               _kill_job, _show_jobs, _get_job_info, _remove_job
# Arguments: None
# Result: show either job info, individual info or kill job(s) according to set global variables.
#   Script exits after -j and -k if kill all is triggered )
###################################################
_do_job() {
    case "${JOB[*]}" in
        *SHOW_JOBS*)
            _show_jobs "${SHOW_JOBS_VERBOSE:-}"
            exit
            ;;
        *KILL_ALL*)
            PIDS="$(_show_jobs | grep -o 'PID:.*[0-9]' | sed "s/PID: //g" || :)" && total=0
            [[ -n ${PIDS} ]] && {
                for _pid in ${PIDS}; do
                    printf "PID: %s - " "${_pid##* }"
                    _kill_job "${_pid##* }"
                    ((total += 1))
                done
            }
            printf "\nTotal Jobs Killed: %s\n" "${total}"
            exit
            ;;
        *PIDS*)
            for pid in "${ALL_PIDS[@]}"; do
                [[ ${JOB_TYPE} =~ INFO ]] && {
                    _get_job_info "${pid}" more
                    [[ ${RETURN_STATUS} -gt 0 ]] && {
                        [[ ${RETURN_STATUS} = 1 ]] && _remove_job "${pid}"
                        printf "No job running with given PID ( %s ).\n" "${pid}" 1>&2
                    }
                }
                [[ ${JOB_TYPE} =~ SHOW_LOGS ]] && {
                    input="$(grep "${pid}" "${SYNC_LIST}" || :)"
                    if [[ -n ${input} ]]; then
                        _check_pid "${pid}" && {
                            : "${input#*"|:_//_:|"}" && local_folder="${_/"|:_//_:|"*/}"
                            _setup_loop_variables "${local_folder}" "${input/*"|:_//_:|"/}"
                            tail -f "${LOGS}"
                        }
                    else
                        printf "No job running with given PID ( %s ).\n" "${pid}" 1>&2
                    fi
                }
                [[ ${JOB_TYPE} =~ KILL ]] && {
                    _get_job_info "${pid}"
                    if [[ ${RETURN_STATUS} = 0 ]]; then
                        _kill_job "${pid}"
                    else
                        [[ ${RETURN_STATUS} = 1 ]] && _remove_job "${pid}"
                        printf "No job running with given PID ( %s ).\n" "${pid}" 1>&2
                    fi
                }
            done
            [[ ${JOB_TYPE} =~ (INFO|SHOW_LOGS|KILL) ]] && exit 0
            ;;
    esac
    return 0
}

###################################################
# Process all arguments given to the script
# Globals: 1 variable, 3 functions
#   Variable - HOME
#   Functions - _kill_jobs, _show_jobs, _get_job_info
# Arguments: Many
#   ${@} = Flags with arguments
# Result: On
#   Success - Set all the variables
#   Error   - Print error message and exit
###################################################
_setup_arguments() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    unset SYNC_TIME_TO_SLEEP ARGS COMMAND_NAME DEBUG GDRIVE_FOLDER KILL SHOW_LOGS
    COMMAND_NAME="gupload"

    _check_longoptions() {
        [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' \
                "${0##*/}" "${1}" "${0##*/}" && exit 1
        return 0
    }

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help) _usage ;;
            -D | --debug) DEBUG="true" && export DEBUG && _check_debug ;;
            -d | --directory)
                _check_longoptions "${1}" "${2}"
                GDRIVE_FOLDER="${2}" && shift
                ARGS+=" -C \"${GDRIVE_FOLDER}\" "
                ;;
            -j | --jobs)
                [[ ${2} = v* ]] && SHOW_JOBS_VERBOSE="true" && shift
                JOB=(SHOW_JOBS)
                ;;
            -p | --pid)
                _check_longoptions "${1}" "${2}"
                if [[ ${2} -gt 0 ]]; then
                    ALL_PIDS+=("${2}") && shift
                    JOB+=(PIDS)
                else
                    printf "-p/--pid only takes postive integer as arguments.\n"
                    exit 1
                fi
                ;;
            -i | --info) JOB_TYPE+="INFO" && INFO="true" ;;
            -k | --kill)
                JOB_TYPE+="KILL" && KILL="true"
                [[ ${2} = all ]] && JOB=(KILL_ALL) && shift
                ;;
            -l | --logs) JOB_TYPE+="SHOW_LOGS" && SHOW_LOGS="true" ;;
            -t | --time)
                _check_longoptions "${1}" "${2}"
                if [[ ${2} -gt 0 ]]; then
                    [[ ${2} = default* ]] && UPDATE_DEFAULT_TIME_TO_SLEEP="_update_config"
                    TO_SLEEP="${2/default=/}" && shift
                else
                    printf "-t/--time only takes positive integers as arguments, min = 1, max = infinity.\n"
                    exit 1
                fi
                ;;
            -a | --arguments)
                _check_longoptions "${1}" "${2}"
                [[ ${2} = default* ]] && UPDATE_DEFAULT_ARGS="_update_config"
                ARGS+="${2/default=/} " && shift
                ;;
            -fg | --foreground) FOREGROUND="true" && SHOW_LOGS="true" ;;
            -in | --include)
                _check_longoptions "${1}" "${2}"
                INCLUDE_FILES="${INCLUDE_FILES} -e '${2}' " && shift
                ;;
            -ex | --exclude)
                _check_longoptions "${1}" "${2}"
                EXCLUDE_FILES="${EXCLUDE_FILES} -e '${2}' " && shift
                ;;
            -c | --command)
                _check_longoptions "${1}" "${2}"
                CUSTOM_COMMAND_NAME="${2}" && shift
                ;;
            --sync-detail-dir)
                _check_longoptions "${1}" "${2}"
                SYNC_DETAIL_DIR="${2}" && shift
                ;;
            -s | --service)
                _check_longoptions "${1}" "${2}"
                SERVICE_NAME="${2}" && shift
                CREATE_SERVICE="true"
                ;;
            *)
                # Check if user meant it to be a flag
                if [[ ${1} = -* ]]; then
                    printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                else
                    # If no "-" is detected in 1st arg, it adds to input
                    FINAL_INPUT_ARRAY+=("${1}")
                fi
                ;;
        esac
        shift
    done

    INFO_PATH="${HOME}/.google-drive-upload"
    [[ -f ${CONFIG_INFO} ]] && . "${CONFIG_INFO}"
    CONFIG="${CONFIG:-${HOME}/.googledrive.conf}"
    SYNC_DETAIL_DIR="${SYNC_DETAIL_DIR:-${INFO_PATH}/sync}"
    SYNC_LIST="${SYNC_DETAIL_DIR}/sync_list"
    mkdir -p "${SYNC_DETAIL_DIR}" && printf "" >> "${SYNC_LIST}"

    _do_job

    [[ -z ${FINAL_INPUT_ARRAY[*]} ]] && _short_help

    return 0
}

###################################################
# Grab config variables and modify defaults if necessary
# Globals: 5 variables, 2 functions
#   Variables - INFO_PATH, UPDATE_DEFAULT_CONFIG, DEFAULT_ARGS
#               UPDATE_DEFAULT_ARGS, UPDATE_DEFAULT_TIME_TO_SLEEP, TIME_TO_SLEEP
#   Functions - _print_center, _update_config
# Arguments: None
# Result: source .info file, grab COMMAND_NAME and CONFIG
#   source CONFIG, update default values if required
###################################################
_config_variables() {
    COMMAND_NAME="${CUSTOM_COMMAND_NAME:-${COMMAND_NAME}}"
    VALUES_LIST="REPO COMMAND_NAME INSTALL_PATH TYPE TYPE_VALUE"
    VALUES_REGEX="" && for i in ${VALUES_LIST}; do
        VALUES_REGEX="${VALUES_REGEX:+${VALUES_REGEX}|}^${i}=\".*\".* # added values"
    done

    # Check if command exist, not necessary but just in case.
    {
        COMMAND_PATH="$(command -v "${COMMAND_NAME}")" 1> /dev/null &&
            SCRIPT_VALUES="$(grep -E "${VALUES_REGEX}|^SELF_SOURCE=\".*\"" "${COMMAND_PATH}" || :)" && eval "${SCRIPT_VALUES}" &&
            [[ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]] && :
    } || { printf "Error: %s is not installed, use -c/--command to specify.\n" "${COMMAND_NAME}" 1>&2 && exit 1; }

    ARGS+=" -q "
    SYNC_TIME_TO_SLEEP="3"
    # Config file is created automatically after first run
    # shellcheck source=/dev/null
    [[ -r ${CONFIG} ]] && . "${CONFIG}"

    SYNC_TIME_TO_SLEEP="${TO_SLEEP:-${SYNC_TIME_TO_SLEEP}}"
    ARGS+=" ${SYNC_DEFAULT_ARGS:-} "
    "${UPDATE_DEFAULT_ARGS:-:}" SYNC_DEFAULT_ARGS " ${ARGS} " "${CONFIG}"
    "${UPDATE_DEFAULT_TIME_TO_SLEEP:-:}" SYNC_TIME_TO_SLEEP "${SYNC_TIME_TO_SLEEP}" "${CONFIG}"
    return 0
}

###################################################
# Process all the values in "${FINAL_INPUT_ARRAY[@]}"
# Globals: 20 variables, 15 functions
#   Variables - FINAL_INPUT_ARRAY ( array ), GDRIVE_FOLDER, PID_FILE, SHOW_LOGS, LOGS
#   Functions - _setup_loop_variables, _setup_loop_files, _start_new_loop, _check_pid, _kill_job
#               _remove_job, _start_new_loop
# Arguments: None
# Result: Start the sync jobs for given folders, if running already, don't start new.
#   If a pid is detected but not running, remove that job.
###################################################
_process_arguments() {
    declare current_folder && declare -A Aseen
    for INPUT in "${FINAL_INPUT_ARRAY[@]}"; do
        { [[ ${Aseen[${INPUT}]} ]] && continue; } || Aseen[${INPUT}]=x
        ! [[ -d ${INPUT} ]] && printf "\nError: Invalid Input ( %s ), no such directory.\n" "${INPUT}" && continue
        current_folder="$(pwd)"
        FOLDER="$(cd "${INPUT}" && pwd)" || exit 1
        GDRIVE_FOLDER="${GDRIVE_FOLDER:-${ROOT_FOLDER_NAME:-Unknown}}"

        [[ -n ${CREATE_SERVICE} ]] && {
            ALL_ARGUMNETS="\"${FOLDER}\" ${TO_SLEEP:+-t \"${TO_SLEEP}\"} -a \"${ARGS//  / }\""
            # shellcheck disable=SC2016
            CONTENTS='# Systemd service file - start
[Unit]
Description=google-drive-upload synchronisation service
After=network.target

[Service]
Type=simple
User='"'${LOGNAME}'"'
Restart=on-abort
RestartSec=3
EnvironmentFile='"'${HOME}/.google-drive-upload/google-drive-upload.info'"'
ExecStart=/usr/bin/env bash "${INSTALL_PATH}/${SYNC_COMMAND_NAME}" --foreground --command "${INSTALL_PATH}/${COMMAND_NAME}" --sync-detail-dir "/tmp/sync" '"${ALL_ARGUMNETS}"'

# Security
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
PrivateDevices=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK
RestrictNamespaces=true
RestrictRealtime=true
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
# Systemd service file - end'
            num="${num+$((num += 1))}"
            service_name="gsync-${SERVICE_NAME}${num:+_${num}}"
            # shellcheck disable=SC2016
            SCRIPT='#!/usr/bin/env bash
set -e
while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
        start) { sudo printf "%s\n" '"'${CONTENTS}'"' >| /etc/systemd/system/'"${service_name}"'.service && sudo systemctl daemon-reload && sudo systemctl start '"'${service_name}'"' && printf "%s\n" '"'${service_name} started.'"' ;} || {
                printf "%s\n" '"'Error: Cannot start ${service_name}'"' && exit 1 ;} ;;
        stop) { sudo systemctl stop '"'${service_name}'"' && printf "%s\n" '"'${service_name} stopped.'"' ;} || { printf "%s\n" '"'Error: Cannot stop ${service_name}'"' && exit 1 ;} ;;
        enable) { sudo systemctl enable '"'${service_name}'"' && printf "%s\n" '"'${service_name} boot service enabled.'"' ;} || { printf "%s\n" '"'Error: Cannot enable ${service_name}'"' && exit 1 ;} ;;
        disable) { sudo systemctl disable '"'${service_name}'"' && printf "%s\n" '"'${service_name} boot service disabled.'"' ;} || { printf "%s\n" '"'Error: Cannot disabled ${service_name}'"' && exit 1 ;} ;;
        logs) sudo journalctl -u '"'${service_name}'"' -f ;;
        remove) { sudo systemctl stop '"'${service_name}'"' && sudo rm -f /etc/systemd/system/'"'${service_name}'"'.service && sudo systemctl daemon-reload && printf "%s\n" '"'${service_name} removed.'"' ;} || {
                printf "%s\n" '"'Error: Cannot remove ${service_name}'"' && exit 1 ;} ;;
    esac
    shift
done'
            printf "%s\n" "${SCRIPT}" >| "${service_name}.service.bash"
            _print_center "normal" "=" "="
            printf "%s\n" "Service Name: ${service_name}"
            printf "\n%s\n%s\n" "Folder: ${FOLDER}" "Gdrive Folder: ${GDRIVE_FOLDER}"
            printf "\n%b\n" "# To start or stop the service\nbash ${service_name}.service.bash start / stop"
            printf "\n%b\n" "# To enable or disable as a boot service:\nbash ${service_name}.service.bash enable / disable"
            printf "\n%b\n" "# To see logs\nbash ${service_name}.service.bash logs"
            printf "\n%b\n" "# To remove\nbash ${service_name}.service.bash remove"
            _print_center "normal" "=" "="
            continue
        }

        cd "${FOLDER}" || exit 1
        _check_existing_loop
        case "${RETURN_STATUS}" in
            0 | 2) _start_new_loop ;;
            1)
                printf "%b\n" "Job is already running.."
                if [[ -n ${INFO} ]]; then
                    _get_job_info "${PID}" more "PID: ${PID}|:_//_:|${FOLDER}|:_//_:|${GDRIVE_FOLDER}"
                else
                    printf "%b\n" "Local Folder: ${INPUT}\nDrive Folder: ${GDRIVE_FOLDER}"
                    printf "%s\n" "PID: ${PID}"
                fi

                [[ -n ${KILL} ]] && _kill_job "${PID}" && exit
                [[ -n ${SHOW_LOGS} ]] && tail -f "${LOGS}"
                ;;
        esac
        cd "${current_folder}" || exit 1
    done
    return 0
}

main() {
    [[ $# = 0 ]] && _short_help

    set -o errexit -o noclobber -o pipefail

    [[ -z ${SELF_SOURCE} ]] && {
        UTILS_FOLDER="${UTILS_FOLDER:-${PWD}}"
        { . "${UTILS_FOLDER}"/common-utils.bash; } || { printf "Error: Unable to source util files.\n" && exit 1; }
    }

    trap '' TSTP # ignore ctrl + z

    _setup_arguments "${@}"
    _check_debug
    _config_variables
    _process_arguments
}

main "${@}"
