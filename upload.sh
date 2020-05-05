#!/usr/bin/env bash
# Upload a file to Google Drive

usage() {
    printf "
The script can be used to upload file/directory to google drive.\n
Usage:\n %s [options.. ] <filename> <foldername>\n
Foldername argument is optional. If not provided, the file will be uploaded to preconfigured google drive.\n
File name argument is optional if create directory option is used.\n
Options:\n
  -C | --create-dir <foldername> - option to create directory. Will provide folder id. Can be used to provide input folder, see README.\n
  -r | --root-dir <google_folderid> or <google_folder_url> - google folder ID/URL to which the file/directory is going to upload.\n
  -s | --skip-subdirs - Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder, use this along with -p/--parallel option to speed up the uploads.\n
  -p | --parallel <no_of_files_to_parallely_upload> - Upload multiple files in parallel, Max value = 10.\n
  -o | --overwrite - Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders.\n
  -f | --[file|folder] - Specify files and folders explicitly in one command, use multiple times for multiple folder/files. See README for more use of this command.\n 
  -o | --overwrite - Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders.\n
  -S | --share <optional_email_address>- Share the uploaded input file/folder, grant reader permission to provided email address or to everyone with the shareable link.\n
  -i | --save-info <file_to_save_info> - Save uploaded files info to the given filename.\n
  -z | --config <config_path> - Override default config file with custom config file.\n
  -q | --quiet - Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.\n
  -v | --verbose - Display detailed message (only for non-parallel uploads).\n
  -V | --verbose-progress - Display detailed message and detailed upload progress(only for non-parallel uploads).\n
  -u | --update - Update the installed script in your system.\n
  --info - Show detailed info, only if script is installed system wide.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n\n" "${0##*/}"
    exit 0
}

shortHelp() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n\n"
    exit 0
}

# Exit if bash present on system is older than 4.x
checkBashVersion() {
    { ! [[ "${BASH_VERSINFO:-0}" -ge 4 ]] && printf "Bash version lower than 4.x not supported\n\n" && exit 1; } || :
}

# Check if we are running in a terminal.
isTerminal() {
    [[ -t 1 || -z $TERM ]] && return 0 || return 1
}

# Check for -q/--quiet
isNotQuiet() {
    [[ -z $QUIET ]] && return 0 || return 1
}

# Usage: bashSleep 1 ( where is time in seconds )
# https://github.com/dylanaraps/pure-bash-bible#use-read-as-an-alternative-to-the-sleep-command
bashSleep() {
    read -rt "$1" <> <(:) || :
}

# Move cursor to nth no. of line and clear it to the begining.
clearLine() {
    printf "\033[%sA\033[2K" "$1"
}

# Usage: dirname "path"
dirname() {
    declare tmp=${1:-.}

    [[ $tmp != *[!/]* ]] && { printf '/\n' && return; }
    tmp=${tmp%%"${tmp##*[!/]}"}

    [[ $tmp != */* ]] && { printf '.\n' && return; }
    tmp=${tmp%/*} && tmp=${tmp%%"${tmp##*[!/]}"}

    printf '%s\n' "${tmp:-/}"
}

# Update the script
update() {
    printf 'Fetching update script..\n'
    declare REPO="labbots/google-drive-upload" BRANCH="master"
    # shellcheck source=/dev/null
    if [[ -f "$HOME/.google-drive-upload/google-drive-upload.info" ]]; then
        source "$HOME/.google-drive-upload/google-drive-upload.info"
    fi
    if __SCRIPT="$(curl --compressed -s https://raw.githubusercontent.com/"$REPO"/"$BRANCH"/install.sh)"; then
        bash <<< "$__SCRIPT"
    else
        printf "Error: Cannot download update script..\n"
    fi
}

# Just print the "$HOME/.google-drive-upload/google-drive-upload.info"
versionInfo() {
    # shellcheck source=/dev/null
    if [[ -f "$HOME/.google-drive-upload/google-drive-upload.info" ]]; then
        cat "$HOME/.google-drive-upload/google-drive-upload.info"
    else
        printf "google-drive-upload is not installed system wide.\n"
    fi
}

# Print a text to center interactively and fill the rest of the line with text specified.
# This function is fine-tuned to this script functionality, so may appear unusual.
# https://gist.github.com/TrinityCoder/911059c83e5f7a351b785921cf7ecda
printCenter() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare -i TERM_COLS="$COLUMNS"
    declare type="$1" filler
    case "$type" in
        normal)
            declare out="$2" && symbol="$3"
            ;;
        justify)
            if [[ $# = 3 ]]; then
                declare input1="$2" symbol="$3" TO_PRINT out
                TO_PRINT="$((TERM_COLS * 95 / 100))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && out="[ ${input1:0:TO_PRINT}.. ]"; } || { out="[ $input1 ]"; }
            else
                declare input1="$2" input2="$3" symbol="$4" TO_PRINT temp out
                TO_PRINT="$((TERM_COLS * 40 / 100))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && temp+=" ${input1:0:TO_PRINT}.."; } || { temp+=" $input1"; }
                TO_PRINT="$((TERM_COLS * 55 / 100))"
                { [[ ${#input2} -gt ${TO_PRINT} ]] && temp+="${input2:0:TO_PRINT}.. "; } || { temp+="$input2 "; }
                out="[$temp]"
            fi
            ;;
        *) return 1 ;;
    esac

    declare -i str_len=${#out}
    [[ $str_len -ge $(((TERM_COLS - 1))) ]] && {
        printf "%s\n" "$out" && return 0
    }

    declare -i filler_len="$(((TERM_COLS - str_len) / 2))"
    [[ $# -ge 2 ]] && ch="${symbol:0:1}" || ch=" "
    for ((i = 0; i < filler_len; i++)); do
        filler="${filler}${ch}"
    done

    printf "%s%s%s" "$filler" "$out" "$filler"
    [[ $(((TERM_COLS - str_len) % 2)) -ne 0 ]] && printf "%s" "${ch}"
    printf "\n"

    return 0
}

# Usage: count < "file" or count <<< "$variable" or pipe some output.
# https://github.com/dylanaraps/pure-bash-bible#get-the-number-of-lines-in-a-file
count() {
    mapfile -tn 0 lines
    printf '%s\n' "${#lines[@]}"
}

# Method to extract data from json response.
# Usage: jsonValue key < json ( or use with a pipe output ).
jsonValue() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare LC_ALL=C num="${2:-1}"
    grep -o "\"""$1""\"\:.*" | sed -e "s/.*\"""$1""\": //" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/\"//" -n -e "${num}"p
}

# Remove array duplicates, maintain the order as original.
# https://stackoverflow.com/a/37962595
removeArrayDuplicates() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare -A Aseen
    Aunique=()
    for i in "$@"; do
        [[ ${Aseen[$i]} ]] && continue
        Aunique+=("$i") && Aseen[$i]=x
    done
    printf '%s\n' "${Aunique[@]}"
}

# Update Config. Incase of old value, update, for new value add.
# Usage: updateConfig valuename value configpath
updateConfig() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare VALUE_NAME="$1" VALUE="$2" CONFIG_PATH="$3" FINAL=()
    declare -A Aseen
    printf "" >> "$CONFIG_PATH" # If config file doesn't exist.
    mapfile -t VALUES < "$CONFIG_PATH" && VALUES+=("$VALUE_NAME=$VALUE")
    for i in "${VALUES[@]}"; do
        [[ $i =~ $VALUE_NAME\= ]] && FINAL+=("$VALUE_NAME=\"$VALUE\"") || FINAL+=("$i")
    done
    for i in "${FINAL[@]}"; do
        [[ ${Aseen[$i]} ]] && continue
        printf "%s\n" "$i" && Aseen[$i]=x
    done >| "$CONFIG_PATH"
}

# Extract file/folder ID from the given INPUT in case of gdrive URL.
# Usage: extractID gdriveurl
extractID() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare LC_ALL=C ID="${1//[[:space:]]/}"
    case "$ID" in
        *'drive.google.com'*'id='*) ID="${ID/*id=/}" && ID="${ID/&*/}" && ID="${ID/\?*/}" ;;
        *'drive.google.com'*'file/d/'* | 'http'*'docs.google.com/file/d/'*) ID="${ID/*\/d\//}" && ID="${ID/\/*/}" ;;
        *'drive.google.com'*'drive'*'folders'*) ID="${ID/*\/folders\//}" && ID="${ID/&*/}" && ID="${ID/\?*/}" ;;
    esac
    printf "%s\n" "$ID"
}

# Usage: urlEncode "string".
# https://github.com/dylanaraps/pure-bash-bible#percent-encode-a-string
urlEncode() {
    declare LC_ALL=C
    for ((i = 0; i < ${#1}; i++)); do
        : "${1:i:1}"
        case "$_" in
            [a-zA-Z0-9.~_-])
                printf '%s' "$_"
                ;;
            *)
                printf '%%%02X' "'$_"
                ;;
        esac
    done
    printf '\n'
}

# Method to get information for a gdrive folder/file.
# Requirements: Given file/folder ID, query, and access_token.
driveInfo() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare FOLDER_ID="$1" FETCH="$2" TOKEN="$3"
    declare SEARCH_RESPONSE FETCHED_DATA

    SEARCH_RESPONSE="$(curl \
        --compressed \
        --silent \
        -XGET \
        -H "Authorization: Bearer ${TOKEN}" \
        """$API_URL""/drive/""$API_VERSION""/files/""$FOLDER_ID""?fields=""$FETCH""&supportsAllDrives=true")"

    FETCHED_DATA="$(jsonValue "$FETCH" 1 <<< "$SEARCH_RESPONSE")"
    { [[ -z $FETCHED_DATA ]] && jsonValue message 1 <<< "$SEARCH_RESPONSE" && return 1; } || {
        printf "%s\n" "$FETCHED_DATA"
    }
}

# Search for an existing file with write permission.
# Requirements: Given file name, rootdir, and access_token.
checkExistingFile() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare NAME="$1" ROOTDIR="$2" TOKEN="$3"
    declare QUERY SEARCH_RESPONSE ID

    QUERY="$(urlEncode "name='$NAME' and '$ROOTDIR' in parents and trashed=false and 'me' in writers")"

    SEARCH_RESPONSE="$(curl \
        --compressed \
        --silent \
        -XGET \
        -H "Authorization: Bearer ${TOKEN}" \
        """$API_URL""/drive/""$API_VERSION""/files?q=${QUERY}&fields=files(id)")"

    ID="$(jsonValue id 1 <<< "$SEARCH_RESPONSE")"
    printf "%s\n" "$ID"
}

# Method to create directory in google drive.
# Requirements: Foldername, Root folder ID ( the folder in which the new folder will be created ) and access_token.
createDirectory() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare DIRNAME="$1" ROOTDIR="$2" TOKEN="$3"
    declare QUERY SEARCH_RESPONSE FOLDER_ID

    QUERY="$(urlEncode "mimeType='application/vnd.google-apps.folder' and name='$DIRNAME' and trashed=false and '$ROOTDIR' in parents")"

    SEARCH_RESPONSE="$(curl \
        --compressed \
        --silent \
        -XGET \
        -H "Authorization: Bearer ${TOKEN}" \
        """$API_URL""/drive/""$API_VERSION""/files?q=${QUERY}&fields=files(id)&supportsAllDrives=true")"

    FOLDER_ID="$(printf "%s\n" "$SEARCH_RESPONSE" | jsonValue id 1)"

    if [[ -z $FOLDER_ID ]]; then
        declare CREATE_FOLDER_POST_DATA CREATE_FOLDER_RESPONSE
        CREATE_FOLDER_POST_DATA="{\"mimeType\": \"application/vnd.google-apps.folder\",\"name\": \"$DIRNAME\",\"parents\": [\"$ROOTDIR\"]}"
        CREATE_FOLDER_RESPONSE="$(curl \
            --compressed \
            --silent \
            -X POST \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json; charset=UTF-8" \
            -d "$CREATE_FOLDER_POST_DATA" \
            """$API_URL""/drive/""$API_VERSION""/files?fields=id&supportsAllDrives=true")"
        FOLDER_ID="$(jsonValue id <<< "$CREATE_FOLDER_RESPONSE")"
    fi
    printf "%s\n" "$FOLDER_ID"
}

# Method to upload ( create or update ) files to google drive.
# Requirements: Given file path, Google folder ID and access_token.
uploadFile() {
    [[ $# -lt 4 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare JOB="$1" INPUT="$2" FOLDER_ID="$3" TOKEN="$4" PARALLEL="$5"
    declare SLUG INPUTNAME EXTENSION INPUTSIZE READABLE_SIZE REQUEST_METHOD URL POSTDATA UPLOADLINK UPLOAD_BODY STRING

    SLUG="${INPUT##*/}"
    INPUTNAME="${SLUG%.*}"
    EXTENSION="${SLUG##*.}"
    INPUTSIZE="$(wc -c < "$INPUT")"
    if type -p awk > /dev/null 2>&1; then
        # https://unix.stackexchange.com/a/374877
        READABLE_SIZE="$(awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.2f %s", $1, v[s] }' <<< "$INPUTSIZE")"
    else
        READABLE_SIZE=$(__SIZE=$(du -h "$INPUT") && printf "%s\n" "${__SIZE/[[:space:]]*/}")
    fi

    if [[ $INPUTNAME = "$EXTENSION" ]]; then
        declare MIME_TYPE
        if type -p mimetype > /dev/null 2>&1; then
            MIME_TYPE="$(mimetype --output-format %m "$INPUT")"
        elif type -p file > /dev/null 2>&1; then
            MIME_TYPE="$(file --brief --mime-type "$INPUT")"
        else
            printCenter "justify" "Error: file or mimetype command not found." && printf "\n"
            exit 1
        fi
    fi

    # Set proper variables for overwriting files
    if [[ $JOB = update ]]; then
        declare EXISTING_FILE_ID
        # Check if file actually exists, and create if not.
        EXISTING_FILE_ID=$(checkExistingFile "$SLUG" "$FOLDER_ID" "$ACCESS_TOKEN")
        if [[ -n $EXISTING_FILE_ID ]]; then
            # https://developers.google.com/drive/api/""$API_VERSION""/reference/files/update
            REQUEST_METHOD=PATCH
            URL="""$API_URL""/upload/drive/""$API_VERSION""/files/""$EXISTING_FILE_ID""?uploadType=resumable&supportsAllDrives=true&supportsTeamDrives=true"
            # JSON post data to specify the file name and folder under while the file to be updated
            POSTDATA="{\"mimeType\": \"$MIME_TYPE\",\"name\": \"$SLUG\",\"addParents\": [\"$FOLDER_ID\"]}"
            STRING=Updated
        else
            JOB=create
        fi
    fi

    # Set proper variables for creating files
    if [[ $JOB = create ]]; then
        URL="""$API_URL""/upload/drive/""$API_VERSION""/files?uploadType=resumable&supportsAllDrives=true&supportsTeamDrives=true"
        REQUEST_METHOD=POST
        # JSON post data to specify the file name and folder under while the file to be created
        POSTDATA="{\"mimeType\": \"$MIME_TYPE\",\"name\": \"$SLUG\",\"parents\": [\"$FOLDER_ID\"]}"
        STRING=Uploaded
    fi

    [[ -z $PARALLEL ]] && printCenter "justify" "${INPUT##*/}" " | ""$READABLE_SIZE""" "="

    # Curl command to initiate resumable upload session and grab the location URL
    [[ -z $PARALLEL ]] && printCenter "justify" "Generating upload link.." "-"
    UPLOADLINK="$(curl \
        --compressed \
        --silent \
        -X "$REQUEST_METHOD" \
        -H "Host: www.googleapis.com" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -H "X-Upload-Content-Type: $MIME_TYPE" \
        -H "X-Upload-Content-Length: $INPUTSIZE" \
        -d "$POSTDATA" \
        "$URL" \
        -D -)"
    UPLOADLINK="$(read -r firstline <<< "${UPLOADLINK/*[L,l]ocation: /}" && printf "%s\n" "${firstline//$'\r'/}")"
    if [[ -n $UPLOADLINK ]]; then
        # Curl command to push the file to google drive.
        # If the file size is large then the content can be split to chunks and uploaded.
        # In that case content range needs to be specified. # Not implemented yet.
        [[ -z $PARALLEL ]] && clearLine 1 && printCenter "justify" "Uploading.." "-"
        # shellcheck disable=SC2086 # Because unnecessary to another check because $CURL_ARGS won't be anything problematic.
        UPLOAD_BODY="$(curl \
            --compressed \
            -X PUT \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: $MIME_TYPE" \
            -H "Content-Length: $INPUTSIZE" \
            -H "Slug: $SLUG" \
            -T "$INPUT" \
            -o- \
            --url "$UPLOADLINK" \
            --globoff \
            $CURL_ARGS)"

        FILE_LINK="$(: "$(printf "%s\n" "$UPLOAD_BODY" | jsonValue id)" && printf "%s\n" "${_/$_/https://drive.google.com/open?id=$_}")"
        FILE_ID="$(printf "%s\n" "$UPLOAD_BODY" | jsonValue id)"
        # Log to the filename provided with -i/--save-id flag.
        if [[ -n $LOG_FILE_ID && ! -d $LOG_FILE_ID && -n $UPLOAD_BODY ]]; then
            # shellcheck disable=SC2129
            # https://github.com/koalaman/shellcheck/issues/1202#issuecomment-608239163
            {
                printf "%s\n" "Link: $FILE_LINK"
                : "$(printf "%s\n" "$UPLOAD_BODY" | jsonValue name)" && printf "%s\n" "${_/*/Name: $_}"
                : "$(printf "%s\n" "$UPLOAD_BODY" | jsonValue id)" && printf "%s\n" "${_/*/ID: $_}"
                : "$(printf "%s\n" "$UPLOAD_BODY" | jsonValue mimeType)" && printf "%s\n" "${_/*/Type: $_}"
                printf '\n'
            } >> "$LOG_FILE_ID"
        fi

        if [[ -n $VERBOSE_PROGRESS ]]; then
            if isNotQuiet; then
                printCenter "justify" "$SLUG " "| $READABLE_SIZE | $STRING" "="
            else
                printCenterQuiet "[ $SLUG | $READABLE_SIZE | $STRING ]"
            fi
        else
            if isNotQuiet; then
                [[ -z "$PARALLEL" ]] && for _ in {1..3}; do clearLine 1; done
                printCenter "justify" "$SLUG " "| $READABLE_SIZE | $STRING" "="
            else
                printCenterQuiet "[ $SLUG | $READABLE_SIZE | $STRING ]"
            fi
        fi
    else
        if isNotQuiet; then
            printCenter "justify" "Upload link generation ERROR" ", $SLUG not $STRING." "=" 1>&2 && [[ -z "$PARALLEL" ]] && printf "\n\n\n"
        else
            printCenterQuiet "Upload link generation ERROR, $SLUG not $STRING." 1>&2
        fi
        UPLOAD_STATUS=ERROR && export UPLOAD_STATUS # Send a error status, used in folder uploads.
    fi
}

# Method to share a gdrive file/folder
# Requirements: Given file/folder ID, type, role and access_token.
shareID() {
    [[ $# -lt 2 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare LC_ALL=C ID="$1" TOKEN="$2" SHARE_EMAIL="$3" ROLE="reader"
    declare TYPE SHARE_POST_DATA SHARE_POST_DATA SHARE_RESPONSE SHARE_ID

    if [[ -n $SHARE_EMAIL ]]; then
        TYPE="user"
        SHARE_POST_DATA="{\"role\":\"$ROLE\",\"type\":\"$TYPE\",\"emailAddress\":\"$SHARE_EMAIL\"}"
    else
        TYPE="anyone"
        SHARE_POST_DATA="{\"role\":\"$ROLE\",\"type\":\"$TYPE\"}"
    fi
    SHARE_RESPONSE="$(curl \
        --compressed \
        --silent \
        --output /dev/null \
        -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "$SHARE_POST_DATA" \
        """$API_URL""/drive/""$API_VERSION""/files/""$ID""/permissions")"

    SHARE_ID="$(jsonValue id 1 <<< "$SHARE_RESPONSE")"
    [[ -z "$SHARE_ID" ]] && jsonValue message 1 <<< "$SHARE_RESPONSE" && return 1
}

# Setup the varibles and process getopts flags.
setupArguments() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    # Internal variables
    # De-initialize if any variables set already.
    unset FIRST_INPUT FOLDER_INPUT FOLDERNAME FINAL_INPUT_ARRAY INPUT_ARRAY
    unset PARALLEL NO_OF_PARALLEL_JOBS SHARE SHARE_EMAIL OVERWRITE SKIP_SUBDIRS CONFIG ROOTDIR QUIET
    unset VERBOSE VERBOSE_PROGRESS DEBUG LOG_FILE_ID
    CURL_ARGS="-#"

    # Grab the first and second argument and shift, only if $1 doesn't contain -.
    { ! [[ $1 = -* ]] && INPUT_ARRAY+=("$1") && shift && [[ $1 != -* ]] && FOLDER_INPUT="$1" && shift; } || :

    # Configuration variables # Remote gDrive variables
    unset ROOT_FOLDER CLIENT_ID CLIENT_SECRET REFRESH_TOKEN ACCESS_TOKEN
    API_URL="https://www.googleapis.com"
    API_VERSION="v3"
    SCOPE="""$API_URL""/auth/drive"
    REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"
    TOKEN_URL="https://accounts.google.com/o/oauth2/token"

    SHORTOPTS=":qvVi:sp:of:Shur:C:Dz:-:"
    while getopts "${SHORTOPTS}" OPTION; do
        case "$OPTION" in
            # Parse longoptions # https://stackoverflow.com/questions/402377/using-getopts-to-process-long-and-short-command-line-options/28466267#28466267
            -)
                checkLongoptions() { { [[ -n ${!OPTIND} ]] && printf '%s: --%s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "$OPTARG" "${0##*/}" && exit 1; } || :; }
                case "$OPTARG" in
                    help)
                        usage
                        ;;
                    update)
                        update
                        exit $?
                        ;;
                    info)
                        versionInfo
                        exit $?
                        ;;
                    create-dir)
                        checkLongoptions
                        FOLDERNAME="${!OPTIND}" && OPTIND=$((OPTIND + 1))
                        ;;
                    root-dir)
                        checkLongoptions
                        ROOTDIR="${!OPTIND}" && OPTIND=$((OPTIND + 1))
                        ;;
                    config)
                        checkLongoptions
                        CONFIG="${!OPTIND}" && OPTIND=$((OPTIND + 1))
                        # shellcheck source=/dev/null
                        [[ -n $CONFIG && -f $CONFIG ]] && source "$CONFIG" || printf "Warning: Given config file (%s) doesn't exist, will use existing config or prompt for credentials..\n" "$OPTARG"
                        ;;
                    save-info)
                        checkLongoptions
                        LOG_FILE_ID="${!OPTIND}" && OPTIND=$((OPTIND + 1))
                        ;;
                    skip-subdirs)
                        SKIP_SUBDIRS=true
                        ;;
                    parallel)
                        checkLongoptions
                        NO_OF_PARALLEL_JOBS="${!OPTIND}"
                        case "$NO_OF_PARALLEL_JOBS" in
                            '' | *[!0-9]*)
                                printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                                exit 1
                                ;;
                            *)
                                [[ $NO_OF_PARALLEL_JOBS -gt 10 ]] && { NO_OF_PARALLEL_JOBS=10 || NO_OF_PARALLEL_JOBS="${!OPTIND}"; }
                                ;;
                        esac
                        PARALLEL_UPLOAD=true && OPTIND=$((OPTIND + 1))
                        ;;
                    overwrite)
                        OVERWRITE=true
                        ;;
                    file | folder)
                        checkLongoptions
                        INPUT_ARRAY+=("${!OPTIND}") && OPTIND=$((OPTIND + 1))
                        ;;
                    share)
                        SHARE=true
                        if [[ -n ${!OPTIND} && ! ${!OPTIND} =~ ^(\-|\-\-) ]]; then
                            SHARE_EMAIL="${!OPTIND}" && ! [[ $SHARE_EMAIL =~ ${EMAIL_REGEX} ]] && printf "\nError: Provided email address for share option is invalid.\n" && exit 1
                            OPTIND=$((OPTIND + 1))
                        fi
                        ;;
                    quiet)
                        QUIET=true
                        CURL_ARGS="-s"
                        ;;
                    verbose)
                        VERBOSE=true
                        ;;
                    verbose-progress)
                        VERBOSE_PROGRESS=true
                        CURL_ARGS=""
                        ;;
                    debug)
                        DEBUG=true
                        ;;
                    '')
                        shorthelp
                        ;;
                    *)
                        printf '%s: --%s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "$OPTARG" "${0##*/}" && exit 1
                        ;;
                esac
                ;;
            h)
                usage
                ;;
            u)
                update
                exit $?
                ;;
            C)
                FOLDERNAME="$OPTARG"
                ;;
            r)
                ROOTDIR="$OPTARG"
                ;;
            z)
                CONFIG="$OPTARG"
                # shellcheck source=/dev/null
                [[ -n $CONFIG && -f $CONFIG ]] && source "$CONFIG" || printf "Warning: Given config file (%s) doesn't exist, will use existing config or prompt for credentials..\n" "$OPTARG"
                ;;
            i)
                LOG_FILE_ID="$OPTARG"
                ;;
            s)
                SKIP_SUBDIRS=true
                ;;
            p)
                NO_OF_PARALLEL_JOBS="$OPTARG"
                case "$NO_OF_PARALLEL_JOBS" in
                    '' | *[!0-9]*)
                        printf "\nError: -p/--parallel value ranges between 1 to 10.\n"
                        exit 1
                        ;;
                    *)
                        [[ $NO_OF_PARALLEL_JOBS -gt 10 ]] && { NO_OF_PARALLEL_JOBS=10 || NO_OF_PARALLEL_JOBS="$OPTARG"; }
                        ;;
                esac
                PARALLEL_UPLOAD=true
                ;;
            o)
                OVERWRITE=true
                ;;
            f)
                INPUT_ARRAY+=("$OPTARG")
                ;;
            S)
                # https://stackoverflow.com/a/57295993
                # Optional arguments # https://stackoverflow.com/questions/402377/using-getopts-to-process-long-and-short-command-line-options/28466267#28466267
                EMAIL_REGEX="^([A-Za-z]+[A-Za-z0-9]*\+?((\.|\-|\_)?[A-Za-z]+[A-Za-z0-9]*)*)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
                if [[ -n ${!OPTIND} && ! ${!OPTIND} =~ ^(\-|\-\-) ]]; then
                    SHARE_EMAIL="${!OPTIND}" && ! [[ $SHARE_EMAIL =~ ${EMAIL_REGEX} ]] && printf "\nError: Provided email address for share option is invalid.\n" && exit 1
                    OPTIND=$((OPTIND + 1))
                fi
                SHARE=true
                ;;
            q)
                QUIET=true
                CURL_ARGS="-s"
                ;;
            v)
                VERBOSE=true
                ;;
            V)
                VERBOSE_PROGRESS=true
                CURL_ARGS=""
                ;;
            D)
                DEBUG=true
                ;;
            :)
                printf '%s: -%s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "$OPTARG" "${0##*/}" && exit 1
                ;;
            ?)
                printf '%s: -%s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "$OPTARG" "${0##*/}" && exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))

    # Incase $1 argument was not taken as input, check if any arguments after all the valid flags have been passed, for INPUT and FOLDERNAME.
    # Also check, if folder or dir, else exit.
    if [[ -z ${INPUT_ARRAY[*]} ]]; then
        if [[ -n $1 && -f $1 || -d $1 ]]; then
            FINAL_INPUT_ARRAY+=("$1")
            { [[ -n $2 && $2 != -* ]] && FOLDER_INPUT="$2"; } || :
        elif [[ -z $FOLDERNAME ]]; then
            shortHelp
        fi
    else
        for array in "${INPUT_ARRAY[@]}"; do
            { [[ -f $array || -d $array ]] && FINAL_INPUT_ARRAY+=("${array[@]}"); } || {
                printf "\nError: Invalid Input ( %s ), no such file or directory.\n\n" "$array"
                exit 1
            }
        done
    fi
    mapfile -t FINAL_INPUT_ARRAY <<< "$(removeArrayDuplicates "${FINAL_INPUT_ARRAY[@]}")"

    # Get foldername, prioritise the input given by -C/--create-dir option.
    { [[ -n $FOLDER_INPUT && -z $FOLDERNAME ]] && FOLDERNAME="${FOLDER_INPUT}"; } || :

    { [[ -n $VERBOSE_PROGRESS && -n $VERBOSE ]] && unset "$VERBOSE"; } || :
}

# To avoid spamming in debug mode.
checkDebug() {
    printCenterQuiet() { printf "%s\n" "$1"; }
    if [[ -n $DEBUG ]]; then
        set -x
        printCenter() { { [[ $# = 3 ]] && printf "%s\n" "$2"; } || { printf "%s%s\n" "$2" "$3"; }; }
        clearLine() { :; } && newLine() { :; }
    else
        set +x
        if isNotQuiet; then
            if isTerminal; then
                # This refreshes the interactive shell so we can use the $COLUMNS variable in the printCenter function.
                shopt -s checkwinsize && (: && :)
                if [[ $COLUMNS -lt 40 ]]; then
                    printCenter() { { [[ $# = 3 ]] && printf "%s\n" "[ $2 ]"; } || { printf "%s\n" "[ $2$3 ]"; }; }
                else
                    trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
                fi
            else
                printCenter() { { [[ $# = 3 ]] && printf "%s\n" "[ $2 ]"; } || { printf "%s\n" "[ $2$3 ]"; }; }
                clearLine() { :; }
            fi
            newLine() { printf "%b" "$1"; }
        else
            printCenter() { :; } && clearLine() { :; } && newLine() { :; }
        fi
    fi
}

# If internet connection is not available.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# curl -m option is unreliable in some cases.
# https://unix.stackexchange.com/a/18711 to timeout without any external program.
checkInternet() {
    printCenter "justify" "Checking Internet connection.." "-"
    if isTerminal; then
        CHECK_INTERNET="$(sh -ic 'exec 3>&1 2>/dev/null; { curl --compressed -Is google.com 1>&3; kill 0; } | { sleep 10; kill 0; }' || :)"
    else
        CHECK_INTERNET="$(curl --compressed -Is google.com -m 10)"
    fi
    if [[ -z $CHECK_INTERNET ]]; then
        clearLine 1 && newLine "\n" && printCenter "justify" "Error: Internet connection not available" "=" && newLine "\n"
        exit 1
    else
        clearLine 1
    fi
}

# Set the path and random name for temp file ( used for showing parallel uploads progress ).
setupTempfile() {
    type -p mktemp > /dev/null && { TMPFILE="$(mktemp -u)" || TMPFILE="$PWD/$((RANDOM * 2)).LOG"; }
    trap '[[ -f "$TMPFILE"SUCCESS ]] && rm "$TMPFILE"SUCCESS ; [[ -f "$TMPFILE"ERROR ]] && rm "$TMPFILE"ERROR' EXIT
}

# Credentials
checkCredentials() {
    # shellcheck source=/dev/null
    # Config file is created automatically after first run
    [[ -f $HOME/.googledrive.conf ]] && source "$HOME"/.googledrive.conf

    [[ -z $CLIENT_ID ]] && read -r -p "Client ID: " CLIENT_ID && {
        updateConfig CLIENT_ID "$CLIENT_ID" "$HOME"/.googledrive.conf
    }

    [[ -z $CLIENT_SECRET ]] && read -r -p "Client Secret: " CLIENT_SECRET && {
        updateConfig CLIENT_SECRET "$CLIENT_SECRET" "$HOME"/.googledrive.conf
    }

    # Method to obtain refresh_token.
    # Requirements: client_id, client_secret and authorization code.
    if [[ -z $REFRESH_TOKEN ]]; then
        read -r -p "If you have a refresh token generated, then type the token, else leave blank and press return key..
    Refresh Token: " REFRESH_TOKEN && REFRESH_TOKEN="${REFRESH_TOKEN//[[:space:]]/}"
        if [[ -n $REFRESH_TOKEN ]]; then
            updateConfig REFRESH_TOKEN "$REFRESH_TOKEN" "$HOME"/.googledrive.conf
        else
            printf "\nVisit the below URL, tap on allow and then enter the code obtained:\n"
            URL="https://accounts.google.com/o/oauth2/auth?client_id=$CLIENT_ID&redirect_uri=$REDIRECT_URI&scope=$SCOPE&response_type=code&prompt=consent"
            printf "%s\n\n" "$URL"
            read -r -p "Enter the authorization code: " CODE
            CODE="${CODE//[[:space:]]/}"
            if [[ -n $CODE ]]; then
                RESPONSE="$(curl --compressed -s -X POST --data "code=$CODE&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&redirect_uri=$REDIRECT_URI&grant_type=authorization_code" "$TOKEN_URL")"

                ACCESS_TOKEN="$(jsonValue access_token <<< "$RESPONSE")"
                REFRESH_TOKEN="$(jsonValue refresh_token <<< "$RESPONSE")"

                updateConfig REFRESH_TOKEN "$REFRESH_TOKEN" "$HOME"/.googledrive.conf
                updateConfig ACCESS_TOKEN "$ACCESS_TOKEN" "$HOME"/.googledrive.conf
            else
                printf "\n"
                printCenter "normal" "No code provided, run the script and try again" " "
                exit 1
            fi
        fi
    fi

    # Method to regenerate access_token.
    # Make a request on https://www.googleapis.com/oauth2/""$API_VERSION""/tokeninfo?access_token=$ACCESS_TOKEN url and check if the given token is valid, if not generate one.
    # Requirements: Refresh Token
    if [[ -z $ACCESS_TOKEN ]]; then
        RESPONSE="$(curl --compressed -s -X POST --data "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN&grant_type=refresh_token" "$TOKEN_URL")"
        ACCESS_TOKEN="$(jsonValue access_token <<< "$RESPONSE")"
        updateConfig ACCESS_TOKEN "$ACCESS_TOKEN" "$HOME"/.googledrive.conf
    elif curl --compressed -s """$API_URL""/oauth2/""$API_VERSION""/tokeninfo?access_token=$ACCESS_TOKEN" | jsonValue error_description > /dev/null 2>&1; then
        RESPONSE="$(curl --compressed -s -X POST --data "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN&grant_type=refresh_token" "$TOKEN_URL")"
        ACCESS_TOKEN="$(jsonValue access_token <<< "$RESPONSE")"
        updateConfig ACCESS_TOKEN "$ACCESS_TOKEN" "$HOME"/.googledrive.conf
    fi
}

# Setup root directory where all file/folders will be uploaded.
setupRootdir() {
    if [[ -n $ROOTDIR ]]; then
        ROOT_FOLDER="${ROOTDIR//[[:space:]]/}"
        if [[ -n $ROOT_FOLDER ]]; then
            ROOT_FOLDER="$(driveInfo "$(extractID "$ROOT_FOLDER")" "id" "$ACCESS_TOKEN")" || {
                { [[ $ROOT_FOLDER =~ "File not found" ]] && printCenter "justify" "Given root folder " " ID/URL invalid." "="; } || { printf "%s\n" "$ROOT_FOLDER"; }
                exit 1
            }
            if [[ -n $ROOT_FOLDER ]]; then
                updateConfig ROOT_FOLDER "$ROOT_FOLDER" "$HOME"/.googledrive.conf
            else
                printCenter "justify" "Given root folder " " ID/URL invalid." "="
                exit 1
            fi
        fi
    elif [[ -z $ROOT_FOLDER ]]; then
        read -r -p "Root Folder ID or URL (Default: root): " ROOT_FOLDER
        ROOT_FOLDER="${ROOT_FOLDER//[[:space:]]/}"
        if [[ -n $ROOT_FOLDER ]]; then
            ROOT_FOLDER="$(driveInfo "$(extractID "$ROOT_FOLDER")" "id" "$ACCESS_TOKEN")" || {
                { [[ $ROOT_FOLDER =~ "File not found" ]] && printCenter "justify" "Given root folder " " ID/URL invalid." "="; } || { printf "%s\n" "$ROOT_FOLDER"; }
                exit 1
            }
            if [[ -n $ROOT_FOLDER ]]; then
                updateConfig ROOT_FOLDER "$ROOT_FOLDER" "$HOME"/.googledrive.conf
            else
                printCenter "justify" "Given root folder " " ID/URL invalid." "="
                exit 1
            fi
        else
            ROOT_FOLDER=root
            updateConfig ROOT_FOLDER "$ROOT_FOLDER" "$HOME"/.googledrive.conf
        fi
    fi
}

# Check to find whether the folder exists in google drive. If not then the folder is created in google drive under the configured root folder.
setupWorkspace() {
    if [[ -z $FOLDERNAME ]]; then
        WORKSPACE_FOLDER_ID="$ROOT_FOLDER"
    else
        WORKSPACE_FOLDER_ID="$(createDirectory "$FOLDERNAME" "$ROOT_FOLDER" "$ACCESS_TOKEN")"
    fi
    WORKSPACE_FOLDER_NAME="$(driveInfo """$WORKSPACE_FOLDER_ID""" name """$ACCESS_TOKEN""")"
}

# Loop through all the input.
processArguments() {
    for INPUT in "${FINAL_INPUT_ARRAY[@]}"; do
        # Check if the argument is a file or a directory.
        if [[ -f $INPUT ]]; then
            printCenter "justify" "Given Input" ": FILE" "="
            if [[ -n $OVERWRITE ]]; then
                printCenter "justify" "Upload Method" ": Overwrite" "-" && newLine "\n"
                uploadFile update "$INPUT" "$WORKSPACE_FOLDER_ID" "$ACCESS_TOKEN"
            else
                printCenter "justify" "Upload Method" ": Create" "-" && newLine "\n"
                uploadFile create "$INPUT" "$WORKSPACE_FOLDER_ID" "$ACCESS_TOKEN"
            fi
            [[ $UPLOAD_STATUS = ERROR ]] && for _ in {1..2}; do clearLine 1; done && return 1
            if [[ -n "$SHARE" ]]; then
                printCenter "justify" "Sharing the file.." "-"
                if SHARE_MSG="$(shareID "$FILE_ID" "$ACCESS_TOKEN" "$SHARE_EMAIL")"; then
                    printf "%s\n" "$SHARE_MSG"
                else
                    clearLine 1
                fi
                printCenter "justify" "DriveLink" " (SHARED)" "-"
            else
                printCenter "justify" "DriveLink" "-"
            fi
            isTerminal && printCenter "normal" "$(printf "\xe2\x86\x93 \xe2\x86\x93 \xe2\x86\x93\n")" " "
            printCenter "normal" "$FILE_LINK" " "
            printf "\n"
        elif [[ -d $INPUT ]]; then
            # Unset PARALLEL value if input is file, for preserving the logging output.
            [[ -n $PARALLEL_UPLOAD ]] && { parallel=true || unset parallel; }

            FOLDER_NAME="${INPUT##*/}"

            if [[ -n $OVERWRITE ]]; then
                printCenter "justify" "Upload Method" ": Overwrite" "="
            else
                printCenter "justify" "Upload Method" ": Create" "="
            fi

            printCenter "justify" "Given Input" ": FOLDER" "-" && newLine "\n"
            printCenter "justify" "Folder: $FOLDER_NAME" "="

            NEXTROOTDIRID="$WORKSPACE_FOLDER_ID"

            # Skip the sub folders and find recursively all the files and upload them.
            if [[ -n $SKIP_SUBDIRS ]]; then
                printCenter "justify" "Indexing files recursively.." "-"
                FILENAMES="$(find "$INPUT" -type f)"
                [[ -z $FILENAMES ]] && clearLine 1 && printCenter "justify" "No files inside the folder.." "=" && break # Check in case of zero files.
                NO_OF_FILES="$(count <<< "$FILENAMES")"
                for _ in {1..2}; do clearLine 1; done
                if isNotQuiet; then
                    printCenter "justify" "Folder: $FOLDER_NAME " "| ""$NO_OF_FILES"" File(s)" "=" && printf "\n"
                else
                    printCenterQuiet "[ Folder: $FOLDER_NAME | ""$NO_OF_FILES"" File(s) ]"
                fi
                ID="$(createDirectory "$INPUT" "$NEXTROOTDIRID" "$ACCESS_TOKEN")"
                DIRIDS="$ID"
                if [[ -n $parallel ]]; then
                    { [[ $NO_OF_PARALLEL_JOBS -gt $NO_OF_FILES ]] && NO_OF_PARALLEL_JOBS_FINAL="$NO_OF_FILES"; } || { NO_OF_PARALLEL_JOBS_FINAL="$NO_OF_PARALLEL_JOBS"; }
                    # Export because xargs cannot access if it is just an internal variable.
                    export ID CURL_ARGS="-s" PARALLEL ACCESS_TOKEN STRING OVERWRITE COLUMNS API_URL API_VERSION LOG_FILE_ID
                    export -f uploadFile printCenter clearLine jsonValue urlEncode checkExistingFile isNotQuiet

                    [[ -f "$TMPFILE"SUCCESS ]] && rm "$TMPFILE"SUCCESS
                    [[ -f "$TMPFILE"ERROR ]] && rm "$TMPFILE"ERROR

                    # shellcheck disable=SC2016
                    printf "%s\n" "$FILENAMES" | xargs -n1 -P"$NO_OF_PARALLEL_JOBS_FINAL" -i bash -c '
            if [[ -n $OVERWRITE ]]; then
        uploadFile update "{}" "$ID" "$ACCESS_TOKEN" parallel
            else
        uploadFile create "{}" "$ID" "$ACCESS_TOKEN" parallel
            fi
            ' 1>| "$TMPFILE"SUCCESS 2>| "$TMPFILE"ERROR &

                    while true; do [[ -f "$TMPFILE"SUCCESS || -f "$TMPFILE"ERROR ]] && { break || bashSleep 0.5; }; done
                    newLine "\n"
                    ERROR_STATUS=0 SUCCESS_STATUS=0
                    while true; do
                        SUCCESS_STATUS="$(count < "$TMPFILE"SUCCESS)"
                        ERROR_STATUS="$(count < "$TMPFILE"ERROR)"
                        bashSleep 1
                        if isNotQuiet; then
                            if [[ $(((SUCCESS_STATUS + ERROR_STATUS))) != "$TOTAL" ]]; then
                                clearLine 1 && printCenter "justify" "Status" ": ""$SUCCESS_STATUS"" UPLOADED | ""$ERROR_STATUS"" FAILED" "="
                            fi
                        else
                            if [[ $(((SUCCESS_STATUS + ERROR_STATUS))) != "$TOTAL" ]]; then
                                clearLine 1 && printCenterQuiet "Status: ""$SUCCESS_STATUS"" UPLOADED | ""$ERROR_STATUS"" FAILED"
                            fi
                        fi
                        TOTAL="$(((SUCCESS_STATUS + ERROR_STATUS)))"
                        [[ $TOTAL = "$NO_OF_FILES" ]] && break
                    done
                    for _ in {1..2}; do clearLine 1; done
                    [[ -z $VERBOSE && -z $VERBOSE_PROGRESS ]] && newLine "\n\n"
                else
                    [[ -z $VERBOSE && -z $VERBOSE_PROGRESS ]] && newLine "\n"

                    ERROR_STATUS=0 SUCCESS_STATUS=0
                    while IFS= read -r -u 4 file; do
                        DIRTOUPLOAD="$ID"
                        if [[ -n $OVERWRITE ]]; then
                            uploadFile update "$file" "$DIRTOUPLOAD" "$ACCESS_TOKEN"
                        else
                            uploadFile create "$file" "$DIRTOUPLOAD" "$ACCESS_TOKEN"
                        fi
                        [[ $UPLOAD_STATUS = ERROR ]] && ERROR_STATUS="$((ERROR_STATUS + 1))" || SUCCESS_STATUS="$((SUCCESS_STATUS + 1))" || :
                        if [[ $VERBOSE = true || $VERBOSE_PROGRESS = true ]]; then
                            printCenter "justify" "Status: ""$SUCCESS_STATUS "" UPLOADED " "| ""$ERROR_STATUS"" FAILED" "=" && newLine "\n"
                        else
                            for _ in {1..2}; do clearLine 1; done
                            printCenter "justify" "Status: ""$SUCCESS_STATUS "" UPLOADED " "| ""$ERROR_STATUS"" FAILED" "="

                        fi
                    done 4<<< "$FILENAMES"
                fi
            else
                printCenter "justify" "Indexing files/sub-folders" " recursively.." "-"
                # Do not create empty folders during a recursive upload. Use of find in this section is important.
                # If below command is used, it lists the folder in stair structure, which we later assume while creating sub folders( if applicable ) and uploading files.
                mapfile -t DIRNAMES <<< "$(find "$INPUT" -type d -not -empty)"
                NO_OF_FOLDERS="${#DIRNAMES[@]}" && NO_OF_SUB_FOLDERS="$((NO_OF_FOLDERS - 1))"
                # Create a loop and make folders according to list made above.
                if [[ $NO_OF_SUB_FOLDERS != 0 ]]; then
                    clearLine 1
                    printCenter "justify" """$((NO_OF_FOLDERS - 1))"" Sub-folders found" "="
                fi
                printCenter "justify" "Indexing files.." "="
                FILENAMES="$(find "$INPUT" -type f)"
                if [[ -n $FILENAMES ]]; then
                    NO_OF_FILES="$(count <<< "$FILENAMES")"
                    for _ in {1..3}; do clearLine 1; done
                    if isNotQuiet; then
                        if [[ $NO_OF_SUB_FOLDERS != 0 ]]; then
                            printCenter "justify" "$FOLDER_NAME " "| ""$NO_OF_FILES"" File(s) | ""$NO_OF_SUB_FOLDERS"" Sub-folders" "="
                        else
                            printCenter "justify" "$FOLDER_NAME " "| ""$NO_OF_FILES"" File(s)" "="
                        fi
                    else
                        if [[ $NO_OF_SUB_FOLDERS != 0 ]]; then
                            printCenterQuiet "[ $FOLDER_NAME | ""$NO_OF_FILES"" File(s) | ""$NO_OF_SUB_FOLDERS"" Sub-folders ]"
                        else
                            printCenterQuiet "[ $FOLDER_NAME | ""$NO_OF_FILES"" File(s) ]"
                        fi
                    fi
                    newLine "\n"
                    printCenter "justify" "Creating Folder(s).." "-"
                    { [[ $NO_OF_SUB_FOLDERS != 0 ]] && newLine "\n"; } || :

                    unset status DIRIDS
                    for dir in "${DIRNAMES[@]}"; do
                        NEWDIR="${dir##*/}"
                        [[ $NO_OF_SUB_FOLDERS != 0 ]] && printCenter "justify" "Name: ""$NEWDIR""" "-"
                        ID="$(createDirectory "$NEWDIR" "$NEXTROOTDIRID" "$ACCESS_TOKEN")"
                        # Store sub-folder directory IDs and it's path for later use.
                        DIRIDS+=("$(printf "%s '%s'\n" "$ID" "$dir")")
                        NEXTROOTDIRID="$({ [[ "$(dirname "$dir")" = "." ]] && printf "%s\n" "$ID"; } || { : "$(printf "%s\n" "${DIRIDS[@]}" | grep \'"$(dirname "$dir")"\')" && printf "%s\n" "${_%% *}"; })"

                        ((status += 1))
                        if [[ $NO_OF_SUB_FOLDERS != 0 ]]; then
                            for _ in {1..2}; do clearLine 1; done
                            printCenter "justify" "Status" ": ""$status"" / ""$NO_OF_FOLDERS""" "="
                        fi
                    done
                    if [[ $NO_OF_SUB_FOLDERS != 0 ]]; then
                        for _ in {1..2}; do clearLine 1; done
                    else
                        clearLine 1
                    fi
                    printCenter "justify" "Preparing to upload.." "-"
                    # shellcheck disable=SC2001
                    FILES_ROOTDIR="$(while IFS= read -r -u 4 i; do
                        : "${i##*/}" && : "$((${#_} + 1))" && printf "%s\n" "${i::-$_}"
                    done 4<<< "$FILENAMES")"

                    # Create a final table of subfolders + files, use |:_//_:| as a seperator to handle weird filenames.
                    FINAL_LIST="$(while IFS= read -r -u 4 ROOTDIRPATH && IFS= read -r -u 5 file; do
                        printf "%s\n" "$ROOTDIRPATH|:_//_:|$(__DIRID="$(grep "'$ROOTDIRPATH'" <<< "$(printf "%s\n" "${DIRIDS[@]}")")" && printf "%s\n" "${__DIRID/ "'$ROOTDIRPATH'"/}")|:_//_:|$file"
                    done 4<<< "$FILES_ROOTDIR" 5<<< "$FILENAMES")"

                    if [[ -n $parallel ]]; then
                        { [[ $NO_OF_PARALLEL_JOBS -gt $NO_OF_FILES ]] && NO_OF_PARALLEL_JOBS_FINAL="$NO_OF_FILES"; } || { NO_OF_PARALLEL_JOBS_FINAL="$NO_OF_PARALLEL_JOBS"; }
                        # Export because xargs cannot access if it is just an internal variable.
                        export CURL_ARGS="-s" ACCESS_TOKEN STRING OVERWRITE COLUMNS API_URL API_VERSION LOG_FILE_ID QUIET
                        export -f uploadFile printCenter clearLine jsonValue urlEncode checkExistingFile isNotQuiet printCenterQuiet newLine

                        [[ -f "$TMPFILE"SUCCESS ]] && rm "$TMPFILE"SUCCESS
                        [[ -f "$TMPFILE"ERROR ]] && rm "$TMPFILE"ERROR

                        # shellcheck disable=SC2016
                        printf "%s\n" "$FINAL_LIST" | xargs -n1 -P"$NO_OF_PARALLEL_JOBS_FINAL" -i bash -c '
            LIST="{}"
            FILETOUPLOAD="${LIST//*"|:_//_:|"}"
            DIRTOUPLOAD="$(: "|:_//_:|""$FILETOUPLOAD" && : "${LIST::-${#_}}" && printf "%s\n" "${_//*"|:_//_:|"}")"
            if [[ -n $OVERWRITE ]]; then
        uploadFile update "$FILETOUPLOAD" "$DIRTOUPLOAD" "$ACCESS_TOKEN" parallel
            else
        uploadFile create "$FILETOUPLOAD" "$DIRTOUPLOAD" "$ACCESS_TOKEN" parallel
            fi
            ' 1>| "$TMPFILE"SUCCESS 2>| "$TMPFILE"ERROR &

                        while true; do [[ -f "$TMPFILE"SUCCESS || -f "$TMPFILE"ERROR ]] && { break || bashSleep 0.5; }; done

                        clearLine 1 && newLine "\n"
                        while true; do
                            SUCCESS_STATUS="$(count < "$TMPFILE"SUCCESS)"
                            ERROR_STATUS="$(count < "$TMPFILE"ERROR)"
                            bashSleep 1
                            if isNotQuiet; then
                                if [[ $(((SUCCESS_STATUS + ERROR_STATUS))) != "$TOTAL" ]]; then
                                    clearLine 1 && printCenter "justify" "Status" ": ""$SUCCESS_STATUS"" UPLOADED | ""$ERROR_STATUS"" FAILED" "="
                                fi
                            else
                                if [[ $(((SUCCESS_STATUS + ERROR_STATUS))) != "$TOTAL" ]]; then
                                    clearLine 1 && printCenterQuiet "Status: ""$SUCCESS_STATUS"" UPLOADED | ""$ERROR_STATUS"" FAILED"
                                fi
                            fi
                            TOTAL="$(((SUCCESS_STATUS + ERROR_STATUS)))"
                            [[ $TOTAL = "$NO_OF_FILES" ]] && break
                        done
                        clearLine 1

                        [[ -z $VERBOSE && -z $VERBOSE_PROGRESS ]] && newLine "\n"
                    else
                        clearLine 1 && newLine "\n"
                        ERROR_STATUS=0 SUCCESS_STATUS=0
                        while IFS= read -r -u 4 LIST; do
                            FILETOUPLOAD="${LIST//*"|:_//_:|"/}"
                            DIRTOUPLOAD="$(: "|:_//_:|""$FILETOUPLOAD" && : "${LIST::-${#_}}" && printf "%s\n" "${_//*"|:_//_:|"/}")"
                            if [[ -n $OVERWRITE ]]; then
                                uploadFile update "$FILETOUPLOAD" "$DIRTOUPLOAD" "$ACCESS_TOKEN"
                            else
                                uploadFile create "$FILETOUPLOAD" "$DIRTOUPLOAD" "$ACCESS_TOKEN"
                            fi
                            [[ $UPLOAD_STATUS = ERROR ]] && ERROR_STATUS="$((ERROR_STATUS + 1))" || SUCCESS_STATUS="$((SUCCESS_STATUS + 1))" || :
                            if [[ -n $VERBOSE || -n $VERBOSE_PROGRESS ]]; then
                                printCenter "justify" "Status" ": ""$SUCCESS_STATUS"" UPLOADED | ""$ERROR_STATUS"" FAILED" "=" && newLine "\n"
                            else
                                for _ in {1..2}; do clearLine 1; done
                                printCenter "justify" "Status" ": ""$SUCCESS_STATUS"" UPLOADED | ""$ERROR_STATUS"" FAILED" "="
                            fi
                        done 4<<< "$FINAL_LIST"
                    fi
                else
                    EMPTY=1
                fi
            fi
            if [[ $EMPTY != 1 ]]; then
                [[ -z $VERBOSE && -z $VERBOSE_PROGRESS ]] && for _ in {1..2}; do clearLine 1; done

                if [[ $SUCCESS_STATUS -gt 0 ]]; then
                    if [[ -n $SHARE ]]; then
                        printCenter "justify" "Sharing the folder.." "-"
                        if SHARE_MSG="$(shareID "$(read -r firstline <<< "${DIRIDS[1]}" && printf "%s\n" "${firstline%% *}")" "$ACCESS_TOKEN" "$SHARE_EMAIL")"; then
                            printf "%s\n" "$SHARE_MSG"
                        else
                            clearLine 1
                        fi
                        printCenter "justify" "FolderLink " " (SHARED)" "="
                    else
                        printCenter "justify" "FolderLink" "="
                    fi
                    isTerminal && printCenter "normal" "$(printf "\xe2\x86\x93 \xe2\x86\x93 \xe2\x86\x93\n")" " "
                    printCenter "normal" "$(: "$(read -r firstline <<< "${DIRIDS[1]}" && printf "%s\n" "${firstline%% *}")" && printf "%s\n" "${_/$_/https://drive.google.com/open?id=$_}")" " "
                fi
                newLine "\n"
                if isNotQuiet; then
                    [[ $SUCCESS_STATUS -gt 0 ]] && printCenter "justify" "Total Files " "Uploaded: ""$SUCCESS_STATUS""" "="
                    [[ $ERROR_STATUS -gt 0 ]] && printCenter "justify" "Total Files " "Failed: ""$ERROR_STATUS""" "="
                else
                    [[ $SUCCESS_STATUS -gt 0 ]] && printCenterQuiet "[ Total Files Uploaded: ""$SUCCESS_STATUS"" ]"
                    [[ $ERROR_STATUS -gt 0 ]] && printCenterAuiet "[ Total Files Failed: ""$ERROR_STATUS"" ]"
                fi
                printf "\n"
            else
                if isNotQuiet; then
                    for _ in {1..2}; do clearLine 1; done
                    printCenter 'justify' "Empty Folder" "-"
                else
                    printCenterQuiet "Empty Folder\n"
                fi
                printf "\n"
            fi
        fi
    done
}

main() {
    [[ $# = 0 ]] && shortHelp

    # To cleanup subprocesses.
    trap 'exit' INT TERM && trap 'kill -- $$' EXIT

    set -o errexit -o noclobber -o pipefail
    checkBashVersion

    setupArguments "$@"
    checkDebug && checkInternet
    setupTempfile

    START=$(printf "%(%s)T\\n" "-1")
    printCenter "justify" "Starting script" "-"

    printCenter "justify" "Checking credentials.." "-"
    checkCredentials && for _ in {1..2}; do clearLine 1; done
    printCenter "justify" "Required credentials available." "-"

    printCenter "justify" "Checking root dir and workspace folder.." "-"
    setupRootdir && for _ in {1..2}; do clearLine 1; done
    printCenter "justify" "Root dir properly configured." "-"

    printCenter "justify" "Checking Workspace Folder.." "-"
    setupWorkspace && for _ in {1..2}; do clearLine 1; done
    printCenter "justify" "Workspace Folder: ""$WORKSPACE_FOLDER_NAME""" "="
    printCenter "normal" " $WORKSPACE_FOLDER_ID " "-" && newLine "\n"

    processArguments

    END="$(printf "%(%s)T\\n" "-1")"
    DIFF="$((END - START))"
    if isNotQuiet; then
        printCenter "normal" " Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds " "="
    else
        printCenterQuiet "Time Elapsed: ""$((DIFF / 60))"" minute(s) and ""$((DIFF % 60))"" seconds"
    fi
}

main "$@"
