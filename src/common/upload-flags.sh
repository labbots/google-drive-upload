#!/usr/bin/env sh
# shellcheck source=/dev/null

###################################################
# setup all the flags help, stuff to be executed for them and pre process
# todo: maybe post processing too
###################################################
_parser_setup_flags() {
    # add initial help text which will appear at start
    _parser_add_help "The script can be used to upload file/directory to google drive.

Usage: ${0##*/} filename/foldername/file_id/file_link -c gdrive_folder_name

where filename/foldername is input file/folder and file_id/file_link is the accessible gdrive file link or id which will be uploaded without downloading.

Note: It’s not mandatory to use gdrive_folder_name | -c / -C / –create-dir flag.

gdrive_folder_name is the name of the folder on gdrive, where the input file/folder will be uploaded. If gdrive_folder_name is present on gdrive, then script will upload there, else will make a folder with that name.

Apart from basic usage, this script provides many flags for custom usecases, like parallel uploading, skipping upload of existing files, overwriting, etc.

Options:"

    ###################################################

    # not a flag exactly, but will be used to process any arguments which is not a flag
    _parser_setup_flag "input" 0
    _parser_setup_flag_help \
        "Input files or drive ids to process."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset TOTAL_ID_INPUTS TOTAL_FILE_INPUTS
EOF
    _parser_setup_flag_process 4<< 'EOF'
# set INPUT_FILE|ID_num to the input, where num is rank of input
case "${1}" in
    *drive.google.com* | *docs.google.com*) _set_value d "INPUT_ID_$((TOTAL_ID_INPUTS += 1))" "$(_extract_id "${1}")" ;;
    *)
        [ -r "${1}" ] || {
            { "${QUIET:-_print_center}" 'normal' "[ Error: Invalid File - ${1} ]" "=" && printf "\n"; } 1>&2
            return
        }
        _set_value d "INPUT_FILE_$((TOTAL_FILE_INPUTS += 1))" "${1}"
        ;;
esac
EOF

    ###################################################

    _parser_setup_flag "-a --account" 1 required "account name"
    _parser_setup_flag_help \
        "Use a different account than the default one.

To change the default account name, use this format, -a/--account default=account_name"

    _parser_setup_flag_preprocess 4<< 'EOF'
unset OAUTH_ENABLED ACCOUNT_NAME ACCOUNT_ONLY_RUN CUSTOM_ACCOUNT_NAME UPDATE_DEFAULT_ACCOUNT
EOF

    _parser_setup_flag_process 4<< 'EOF'
export OAUTH_ENABLED="true" CUSTOM_ACCOUNT_NAME="${2##default=}"
[ -z "${2##default=*}" ] && export UPDATE_DEFAULT_ACCOUNT="_update_config"
_parser_shift
EOF

    ###################################################

    _parser_setup_flag "-la --list-accounts" 0
    _parser_setup_flag_help \
        "Print all configured accounts in the config files."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset LIST_ACCOUNTS
EOF

    _parser_setup_flag_process 4<< 'EOF'
export LIST_ACCOUNTS="true"
EOF

    ###################################################

    _parser_setup_flag "-ca --create-account" 1 required "account name"
    _parser_setup_flag_help \
        "To create a new account with the given name if does not already exists.

Note 1: Only for interactive terminal usage

Note 2: This flag is preferred over --account."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset OAUTH_ENABLED NEW_ACCOUNT_NAME
EOF

    _parser_setup_flag_process 4<< 'EOF'
export OAUTH_ENABLED="true"
export NEW_ACCOUNT_NAME="${2}" && _parser_shift 
EOF

    ###################################################

    _parser_setup_flag "-da --delete-account" 1 required "account name"
    _parser_setup_flag_help \
        "To delete an account information from config file."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset DELETE_ACCOUNT_NAME
EOF

    _parser_setup_flag_process 4<< 'EOF'
export DELETE_ACCOUNT_NAME="${2}" && _parser_shift 
EOF

    ###################################################

    _parser_setup_flag "-c -C --create-dir" 1 required "foldername"
    _parser_setup_flag_help \
        "Option to create directory on drive. Will print folder id.
If this option is used, then input files/folders are optional.

Also supports specifying sub folders, -c 'Folder1/folder2/test'.
Three folders will be created, test inside folder2, folder2 inside Folder1 and so on.
Input files and folders will be uploaded inside test folder."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset FOLDERNAME
EOF

    _parser_setup_flag_process 4<< 'EOF'
export FOLDERNAME="${2}" && _parser_shift
EOF

    ###################################################

    _parser_setup_flag "-r --root-dir" 1 required "google folder id or folder url containing id"
    _parser_setup_flag_help \
        "Google folder ID/URL to which the file/directory is going to upload.
If you want to change the default value, then use this format, -r/--root-dir default=root_folder_id/root_folder_url"

    _parser_setup_flag_preprocess 4<< 'EOF'
unset ROOTDIR UPDATE_DEFAULT_ROOTDIR 
EOF

    _parser_setup_flag_process 4<< 'EOF'
ROOTDIR="${2##default=}"
[ -z "${2##default=*}" ] && export UPDATE_DEFAULT_ROOTDIR="_update_config"
_parser_shift
EOF

    ###################################################

    _parser_setup_flag "-s --skip-subdirs" 0
    _parser_setup_flag_help \
        "Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder.
Use this along with -p/--parallel option to speed up the uploads."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset SKIP_SUBDIRS
EOF

    _parser_setup_flag_process 4<< 'EOF'
export SKIP_SUBDIRS="true"
EOF

    ###################################################

    _parser_setup_flag "-p --parallel" 1 required "no of files to parallely upload"
    _parser_setup_flag_help \
        "Upload multiple files in parallel, Max value = 10.

Note:
    This command is only helpful if you are uploading many files which aren’t big enough to utilise your full bandwidth.
    Using it otherwise will not speed up your upload and even error sometimes,

    1 - 6 value is recommended, but can use upto 10. If errors with a high value, use smaller number. "

    _parser_setup_flag_preprocess 4<< 'EOF'
unset NO_OF_PARALLEL_JOBS PARALLEL_UPLOAD
EOF

    _parser_setup_flag_process 4<< 'EOF'
if [ "${2}" -gt 0 ] 2>| /dev/null 1>&2; then
    export NO_OF_PARALLEL_JOBS="${2}"
else
    printf "\nError: -p/--parallel accepts values between 1 to 10.\n"
    return 1
fi
export PARALLEL_UPLOAD="parallel" && _parser_shift
EOF

    ###################################################

    _parser_setup_flag "-cl --clone" 1 required "gdrive id or link"
    _parser_setup_flag_help \
        "Upload a gdrive file without downloading."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset TOTAL_ID_INPUTS
EOF

    _parser_setup_flag_process 4<< 'EOF'
# set INPUT_FILE|ID_num to the input, where num is rank of input
case "${1}" in
    *drive.google.com* | *docs.google.com*) _set_value d "INPUT_ID_$((TOTAL_ID_INPUTS += 1))" "$(_extract_id "${1}")" ;;
esac
_parser_shift
EOF

    ###################################################

    _parser_setup_flag "-o --overwrite" 0
    _parser_setup_flag_help \
        "Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders.

Note: If you use this flag along with -d/–skip-duplicates, the skip duplicates flag is preferred."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset OVERWRITE UPLOAD_MODE
EOF

    _parser_setup_flag_process 4<< 'EOF'
export OVERWRITE="Overwrite" UPLOAD_MODE="update"
EOF

    ###################################################

    _parser_setup_flag "-d --skip-duplicates" 0
    _parser_setup_flag_help \
        "Do not upload the files with the same name and size, if already present in the root folder/input folder.
Also works with recursive folders."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset SKIP_DUPLICATES UPLOAD_MODE
EOF

    _parser_setup_flag_process 4<< 'EOF'
export SKIP_DUPLICATES="Skip Existing" UPLOAD_MODE="update"
EOF

    ###################################################

    _parser_setup_flag "-cm --check-mode" 1 required "size or md5"
    _parser_setup_flag_help \
        "Additional flag for --overwrite and --skip-duplicates flag. Can be used to change check mode in those flags.
Available modes are 'size' and 'md5'."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset CHECK_MODE
EOF

    _parser_setup_flag_process 4<< 'EOF'
case "${2}" in
    size) export CHECK_MODE="2" && _parser_shift ;;
    md5) export CHECK_MODE="3" && _parser_shift ;;
    *) printf "\nError: -cm/--check-mode takes size and md5 as argument.\n" ;;
esac
EOF

    ###################################################

    _parser_setup_flag "-desc --description --description-all" 1 required "description of file"
    _parser_setup_flag_help \
        "Specify description for the given file. To use the respective metadata of a file, below is the format:

File name ( fullname ): %f | Size: %s | Mime Type: %m

Now to actually use it: --description 'Filename: %f, Size: %s, Mime: %m'

Note: For files inside folders, use --description-all flag."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset DESCRIPTION DESCRIPTION_ALL
EOF

    _parser_setup_flag_process 4<< 'EOF'
[ "${1}" = "--description-all" ] && export DESCRIPTION_ALL="true"
export DESCRIPTION="${2}" && _parser_shift
EOF

    ###################################################

    _parser_setup_flag "-S --share" 1 required "email address"
    _parser_setup_flag_help \
        "Share the uploaded input file/folder, grant reader permission to provided email address OR
To everyone with the shareable link."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset SHARE EMAIL_REGEX SHARE_EMAIL
EOF

    _parser_setup_flag_process 4<< 'EOF'
SHARE="_share_id"
EMAIL_REGEX="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
case "${2}" in
    -* | '') : ;;
    *)
        if _assert_regex "${EMAIL_REGEX}" "${2}"; then
            SHARE_EMAIL="${2}" && _parser_shift && export SHARE_EMAIL
        fi
        ;;
esac
SHARE_ROLE="${SHARE_ROLE:-reader}"
EOF

    ###################################################

    _parser_setup_flag "-SM -sm --share-mode" 1 required "share mode - r/w/c"
    _parser_setup_flag_help \
        "Specify the share mode for sharing file.

        Share modes are: r / reader - Read only permission.

                       : w / writer - Read and write permission.

                       : c / commenter - Comment only permission.

Note: This flag is independent of --share flag but when email is needed, then --share flag use is neccessary."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset SHARE_ROLE SHARE
EOF

    _parser_setup_flag_process 4<< 'EOF'
case "${2}" in
    r | read*) SHARE_ROLE="reader" ;;
    w | write*) SHARE_ROLE="writer" ;;
    c | comment*) SHARE_ROLE="commenter" ;;
    *)
        printf "%s\n" "Invalid share mode given ( ${2} ). Supported values are r or reader / w or writer / c or commenter." &&
            exit 1
        ;;
esac
SHARE="_share_id"
_parser_shift
EOF

    ###################################################

    _parser_setup_flag "--speed" 1 required "speed"
    _parser_setup_flag_help \
        "Limit the download speed, supported formats: 1K, 1M and 1G."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset CURL_SPEED
EOF

    _parser_setup_flag_process 4<< 'EOF'
_tmp_regex='^([0-9]+)([k,K]|[m,M]|[g,G])+$'
if _assert_regex "${_tmp_regex}" "${2}"; then
    export CURL_SPEED="--limit-rate ${2}" && _parser_shift
else
    printf "Error: Wrong speed limit format, supported formats: 1K , 1M and 1G\n" 1>&2
    exit 1
fi
EOF

    ###################################################

    _parser_setup_flag "-i --save-info" 1 required "file where to save info"
    _parser_setup_flag_help \
        "Save uploaded files info to the given filename."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset LOG_FILE_ID
EOF

    _parser_setup_flag_process 4<< 'EOF'
export LOG_FILE_ID="${2}" && _parser_shift
EOF

    ###################################################

    _parser_setup_flag "-z --config" 1 required "config path"
    _parser_setup_flag_help \
        "Override default config file with custom config file.

Default Config: \${HOME}/.googledrive.conf

If you want to change default value, then use this format -z/--config default=default=your_config_file_path."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset UPDATE_DEFAULT_CONFIG
_check_config() {
    [ -z "${1##default=*}" ] && export UPDATE_DEFAULT_CONFIG="_update_config"
    { [ -r "${2}" ] && CONFIG="${2}"; } || {
        printf "Error: Given config file (%s) doesn't exist/not readable,..\n" "${1}" 1>&2 && exit 1
    }
    return 0
}
EOF

    _parser_setup_flag_process 4<< 'EOF'
_check_config "${2}" "${2/default=/}"
_parser_shift
EOF

    ###################################################

    _parser_setup_flag "-q --quiet" 0
    _parser_setup_flag_help \
        "Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset QUIET
EOF

    _parser_setup_flag_process 4<< 'EOF'
export QUIET="_print_center_quiet"
EOF

    ###################################################

    _parser_setup_flag "-R --retry" 1 required "num of retries"
    _parser_setup_flag_help \
        "Retry the file upload if it fails, postive integer as argument. Currently only for file uploads."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset RETRY
EOF

    _parser_setup_flag_process 4<< 'EOF'
if [ "$((2))" -gt 0 ] 2>| /dev/null 1>&2; then
    export RETRY="${2}" && _parser_shift
else
    printf "Error: -R/--retry only takes positive integers as arguments, min = 1, max = infinity.\n"
    exit 1
fi
EOF

    ###################################################

    _parser_setup_flag "-in --include" 1 required "pattern"
    _parser_setup_flag_help \
        "Only upload the files which contains the given pattern - Applicable for folder uploads.

e.g: ${0##*/} local_folder --include 1, will only include with files with pattern 1 in the name.
Regex can be used which works with grep -E command."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset INCLUDE_FILES
EOF

    _parser_setup_flag_process 4<< 'EOF'
export INCLUDE_FILES="${INCLUDE_FILES:+${INCLUDE_FILES}|}${2}" && _parser_shift
EOF

    ###################################################

    _parser_setup_flag "-ex --exclude" 1 required "pattern"
    _parser_setup_flag_help \
        "Only download the files which does not contain the given pattern - Applicable for folder downloads.

e.g: ${0##*/} local_folder --exclude 1, will only include with files with pattern 1 not present in the name.
Regex can be used which works with grep -E command."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset EXCLUDE_FILES
EOF

    _parser_setup_flag_process 4<< 'EOF'
export EXCLUDE_FILES="${EXCLUDE_FILES:+${EXCLUDE_FILES}|}${2}" && _parser_shift
EOF

    ###################################################

    _parser_setup_flag "--hide" 0
    _parser_setup_flag_help \
        "This flag will prevent the script to print sensitive information like root folder id and drivelink."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset HIDE_INFO
EOF

    _parser_setup_flag_process 4<< 'EOF'
HIDE_INFO=":"
EOF

    ###################################################

    _parser_setup_flag "-v --verbose" 0
    _parser_setup_flag_help \
        "Display detailed message (only for non-parallel uploads)."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset VERBOSE
EOF

    _parser_setup_flag_process 4<< 'EOF'
export VERBOSE="true"
EOF

    ###################################################

    _parser_setup_flag "-V --verbose-progress" 0
    _parser_setup_flag_help \
        "Display detailed message and detailed upload progress(only for non-parallel uploads)."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset VERBOSE_PROGRESS
EOF

    _parser_setup_flag_process 4<< 'EOF'
export VERBOSE_PROGRESS="true"
EOF

    ###################################################

    _parser_setup_flag "--skip-internet-check" 0
    _parser_setup_flag_help \
        "Do not check for internet connection, recommended to use in sync jobs."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset SKIP_INTERNET_CHECK
EOF

    _parser_setup_flag_process 4<< 'EOF'
export SKIP_INTERNET_CHECK=":"
EOF

    ###################################################

    _parser_setup_flag "-V --version --info" 0
    _parser_setup_flag_help \
        "Show detailed info, only if script is installed system wide."

    _parser_setup_flag_preprocess 4<< 'EOF'
###################################################
# Print info if installed
###################################################
_version_info() {
    export COMMAND_NAME REPO INSTALL_PATH TYPE TYPE_VALUE
    if command -v "${COMMAND_NAME}" 1> /dev/null && [ -n "${REPO:+${COMMAND_NAME:+${INSTALL_PATH:+${TYPE:+${TYPE_VALUE}}}}}" ]; then
        for i in REPO INSTALL_PATH INSTALLATION TYPE TYPE_VALUE LATEST_INSTALLED_SHA CONFIG; do
            value_version_info=""
            _set_value i value_version_info "${i}"
            printf "%s\n" "${i}=${value_version_info}"
        done | sed -e "s/=/: /g"
    else
        printf "%s\n" "google-drive-upload is not installed system wide."
    fi
    exit 0
}
EOF

    _parser_setup_flag_process 4<< 'EOF'
_version_info
EOF

    ###################################################

    _parser_setup_flag "-D --debug" 0
    _parser_setup_flag_help \
        "Display script command trace."

    _parser_setup_flag_preprocess 4<< 'EOF'
unset DEBUG
EOF

    _parser_setup_flag_process 4<< 'EOF'
export DEBUG="true"
EOF

    ###################################################

    _parser_setup_flag "-h --help" 1 optional "flag name"
    _parser_setup_flag_help \
        "Print help for all flags and basic usage instructions.

To see help for a specific flag, --help flag_name ( with or without dashes )
    e.g: ${0##*/} --help aria"

    _parser_setup_flag_preprocess 4<< 'EOF'
###################################################
# 1st arg - can be flag name
# if 1st arg given, print specific flag help
# otherwise print full help
###################################################
_usage() {
    [ -n "${1}" ] && {
        help_usage_usage=""
        _flag_help "${1}" help_usage_usage

        if [ -z "${help_usage_usage}" ]; then
            printf "%s\n" "Error: No help found for ${1}"
        else
            printf "%s\n%s\n%s\n" "${__PARSER_BAR}" "${help_usage_usage}" "${__PARSER_BAR}"
        fi
        exit 0
    }

    printf "%s\n" "${_PARSER_ALL_HELP}"
    exit 0
}
EOF

    _parser_setup_flag_process 4<< 'EOF'
_usage "${2}"
EOF
    ###################################################

    # should be only available if installed using install script
    [ "${GUPLOAD_INSTALLED_WITH:-}" = script ] && {
        _parser_setup_flag "-u --update" 0
        _parser_setup_flag_help \
            "Update the installed script in your system."

        _parser_setup_flag_process 4<< 'EOF'
_check_debug && _update && { exit 0 || exit 1; }
EOF

        #########################

        _parser_setup_flag "--uninstall" 0
        _parser_setup_flag_help \
            "Uninstall script, remove related files."

        _parser_setup_flag_process 4<< 'EOF'
_check_debug && _update uninstall && { exit 0 || exit 1; }
EOF
    }

    ###################################################
    return 0
}
