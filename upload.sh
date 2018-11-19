#!/bin/bash

# Upload a file to Google Drive
# Usage: upload.sh <file> <folder_name>

#!/bin/bashset -e

function usage(){

	echo -e "\nThe script can be used to upload file/directory to google drive."
	echo -e "\nUsage:\n $0 [options..] <filename> <foldername> \n"
	echo -e "Foldername argument is optional. If not provided, the file will be uploaded to preconfigured google drive. \n"
	echo -e "File name argument is optional if create directory option is used. \n"
	echo -e "Options:\n"
	echo -e "-C | --create-dir <foldername> - Option to create directory. Will provide folder id."
	echo -e "-r | --root-dir <google_folderid> - Google folder id to which the file/directory to upload."
	echo -e "-g | --globoff - Turn off URL globbing parser to allow filenames with literal [] and/or {}."
	echo -e "-v | --verbose - Display detailed message."
	echo -e "-z | --config - Override default config file with custom config file."
	echo -e "-h | --help - Display usage instructions.\n"
	exit 0;
}

#Configuration variables
ROOT_FOLDER=""
CLIENT_ID=""
CLIENT_SECRET=""
REFRESH_TOKEN=""
SCOPE=${SCOPE:-"https://docs.google.com/feeds"}

#Internal variable
ACCESS_TOKEN=""
FILE=""
FOLDERNAME=""
curl_args=""

DIR="$( cd "$( dirname "$( readlink "${BASH_SOURCE[0]}" )" )" && pwd )"

if [ -e $HOME/.googledrive.conf ]
then
    . $HOME/.googledrive.conf
fi

PROGNAME=${0##*/}
SHORTOPTS="gvhr:C:z:"
LONGOPTS="globoff,verbose,help,create-dir:,root-dir:,config:"

set -o errexit -o noclobber -o pipefail #-o nounset
OPTS=$(getopt -s bash --options $SHORTOPTS --longoptions $LONGOPTS --name $PROGNAME -- "$@" )

# script to parse the input arguments
#if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

eval set -- "$OPTS"

GLOBOFF=false
VERBOSE=false
HELP=false
CONFIG=""
ROOTDIR=""

while true; do
  case "$1" in
		-g | --globoff ) GLOBOFF=true; shift ;;
    -v | --verbose ) VERBOSE=true; shift ;;
    -h | --help )    usage; shift ;;
    -C | --create-dir ) FOLDERNAME="$2"; shift 2 ;;
    -r | --root-dir ) ROOTDIR="$2";ROOT_FOLDER="$2"; shift 2 ;;
    -z | --config ) CONFIG="$2"; shift 2 ;;
    -- ) shift; break ;;
    * )  break ;;
  esac
done

# set curl arguments variable properly; should be rewritten with regex in future
if "$GLOBOFF" && "$VERBOSE"; then
	curl_args="--globoff --verbose"
elif "$VERBOSE"; then
  curl_args="--verbose"
elif "$GLOBOFF"; then
	curl_args="--globoff"
else
  curl_args=""
fi

if [ ! -z "$CONFIG" ]
	then
	if [ -e "$CONFIG" ]
	then
    	. $CONFIG
	fi
	if [ ! -z "$ROOTDIR" ]
		then
		ROOT_FOLDER="$ROOTDIR"
	fi

fi

if [ ! -z "$1" ]
then
	FILE=$1
fi

if [ ! -z "$2" ] && [ -z "$FOLDERNAME" ]
then
	FOLDERNAME=$2
fi

if [ "$#" = "0" ] && [ -z "$FOLDERNAME" ]
	then
		usage
fi

# Method to extract data from json response
function jsonValue() {
KEY=$1
num=$2
awk -F"[,:}][^://]" '{for(i=1;i<=NF;i++){if($i~/\042'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p | sed -e 's/[}]*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[,]*$//'
}

function log() {

	if [ "$VERBOSE" = true ]; then
		echo -e "${1}"

	fi
}

# Method to create directory in google drive. Requires 3 arguments foldername,root directory id and access token.
function createDirectory(){
	DIRNAME="$1"
	ROOTDIR="$2"
	ACCESS_TOKEN="$3"
	FOLDER_ID=""
    QUERY="mimeType='application/vnd.google-apps.folder' and title='$DIRNAME'"
    QUERY=$(echo $QUERY | sed -f ${DIR}/url_escape.sed)

	SEARCH_RESPONSE=`/usr/bin/curl \
					--silent \
					-XGET \
					-H "Authorization: Bearer ${ACCESS_TOKEN}" \
					 "https://www.googleapis.com/drive/v2/files/${ROOTDIR}/children?orderBy=title&q=${QUERY}&fields=items%2Fid"`

	FOLDER_ID=`echo $SEARCH_RESPONSE | jsonValue id`


	if [ -z "$FOLDER_ID" ]
	then
		CREATE_FOLDER_POST_DATA="{\"mimeType\": \"application/vnd.google-apps.folder\",\"title\": \"$DIRNAME\",\"parents\": [{\"id\": \"$ROOTDIR\"}]}"
		CREATE_FOLDER_RESPONSE=`/usr/bin/curl \
								--silent  \
								-X POST \
								-H "Authorization: Bearer ${ACCESS_TOKEN}" \
								-H "Content-Type: application/json; charset=UTF-8" \
								-d "$CREATE_FOLDER_POST_DATA" \
								"https://www.googleapis.com/drive/v2/files?fields=id"`
		FOLDER_ID=`echo $CREATE_FOLDER_RESPONSE | jsonValue id`

	fi
	echo "$FOLDER_ID"
}

# Method to upload files to google drive. Requires 3 arguments file path, google folder id and access token.
function uploadFile(){

	FILE="$1"
	FOLDER_ID="$2"
	ACCESS_TOKEN="$3"
	SLUG=`basename "$FILE"`
	FILENAME="${SLUG%.*}"
	EXTENSION="${SLUG##*.}"
	if [ "$FILENAME" == "$EXTENSION" -o ! "$(command -v mimetype)" ]
   	then
     		MIME_TYPE=`file --brief --mime-type "$FILE"`
   	else
        	MIME_TYPE=`mimetype --output-format %m  "$FILE"`

	fi


	FILESIZE=$(stat -c%s "$FILE")

	# JSON post data to specify the file name and folder under while the file to be created
	postData="{\"mimeType\": \"$MIME_TYPE\",\"title\": \"$SLUG\",\"parents\": [{\"id\": \"$FOLDER_ID\"}]}"
	postDataSize=$(echo $postData | wc -c)

	# Curl command to initiate resumable upload session and grab the location URL
	log "Generating upload link for file $FILE ..."
	uploadlink=`/usr/bin/curl \
				--silent \
				-X POST \
				-H "Host: www.googleapis.com" \
				-H "Authorization: Bearer ${ACCESS_TOKEN}" \
				-H "Content-Type: application/json; charset=UTF-8" \
				-H "X-Upload-Content-Type: $MIME_TYPE" \
				-H "X-Upload-Content-Length: $FILESIZE" \
				-d "$postData" \
				"https://www.googleapis.com/upload/drive/v2/files?uploadType=resumable" \
				--dump-header - | sed -ne s/"Location: "//pi | tr -d '\r\n'`

	# Curl command to push the file to google drive.
	# If the file size is large then the content can be split to chunks and uploaded.
	# In that case content range needs to be specified.
	log "Uploading file $FILE to google drive..."
	curl \
	-X PUT \
	-H "Authorization: Bearer ${ACCESS_TOKEN}" \
	-H "Content-Type: $MIME_TYPE" \
	-H "Content-Length: $FILESIZE" \
	-H "Slug: $SLUG" \
	--upload-file "$FILE" \
	--output /dev/null \
	"$uploadlink" \
	$curl_args
}

old_umask=`umask`
umask 0077

if [ -z "$ROOT_FOLDER" ]
then
    read -p "Root Folder ID (Default: root): " ROOT_FOLDER
    if [ -z "$ROOT_FOLDER" ] || [ `echo $ROOT_FOLDER | tr [:upper:] [:lower:]` = `echo "root" | tr [:upper:] [:lower:]` ]
    	then
    		ROOT_FOLDER="root"
    		echo "ROOT_FOLDER=$ROOT_FOLDER" >> $HOME/.googledrive.conf
    	else
		    if expr "$ROOT_FOLDER" : '^[A-Za-z0-9_-]\{28\}$' > /dev/null
		    then
				echo "ROOT_FOLDER=$ROOT_FOLDER" >> $HOME/.googledrive.conf
			else
				echo "Invalid root folder id"
				exit -1
			fi
		fi
fi

if [ -z "$CLIENT_ID" ]
then
    read -p "Client ID: " CLIENT_ID
    echo "CLIENT_ID=$CLIENT_ID" >> $HOME/.googledrive.conf
fi

if [ -z "$CLIENT_SECRET" ]
then
    read -p "Client Secret: " CLIENT_SECRET
    echo "CLIENT_SECRET=$CLIENT_SECRET" >> $HOME/.googledrive.conf
fi

if [ -z "$REFRESH_TOKEN" ]
then
    RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/device/code" --data "client_id=$CLIENT_ID&scope=$SCOPE"`
	DEVICE_CODE=`echo "$RESPONSE" | jsonValue "device_code"`
	USER_CODE=`echo "$RESPONSE" | jsonValue "user_code"`
	URL=`echo "$RESPONSE" | jsonValue "verification_url"`

	echo -n "Go to $URL and enter $USER_CODE to grant access to this application. Hit enter when done..."
	read

	RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/token" --data "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&code=$DEVICE_CODE&grant_type=http://oauth.net/grant_type/device/1.0"`

	ACCESS_TOKEN=`echo "$RESPONSE" | jsonValue access_token`
	REFRESH_TOKEN=`echo "$RESPONSE" | jsonValue refresh_token`

    echo "REFRESH_TOKEN=$REFRESH_TOKEN" >> $HOME/.googledrive.conf
fi

if [ -z "$ACCESS_TOKEN" ]
	then
	# Access token generation
	RESPONSE=`curl --silent "https://accounts.google.com/o/oauth2/token" --data "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN&grant_type=refresh_token"`
	ACCESS_TOKEN=`echo $RESPONSE | jsonValue access_token`
fi

# Check to find whether the folder exists in google drive. If not then the folder is created in google drive under the configured root folder
if [ -z "$FOLDERNAME" ] || [[ `echo "$FOLDERNAME" | tr [:upper:] [:lower:]` = `echo "root" | tr [:upper:] [:lower:]` ]]
	then
	if [[ `echo "$FOLDERNAME" | tr [:upper:] [:lower:]` = `echo "root" | tr [:upper:] [:lower:]` ]]
	then
		ROOT_FOLDER="root"
	fi
    FOLDER_ID=$ROOT_FOLDER
else
	FOLDER_ID=`createDirectory "$FOLDERNAME" "$ROOT_FOLDER" "$ACCESS_TOKEN"`

fi
	log "Folder ID for folder name $FOLDERNAME : $FOLDER_ID"

# Check whether the given file argument is valid and check whether the argument is file or directory.
# based on the type, if the argument is directory do a recursive upload.
if [ ! -z "$FILE" ]; then
	if [ -f "$FILE" ];then
		uploadFile "$FILE" "$FOLDER_ID" "$ACCESS_TOKEN"
	elif [ -d "$FILE" ];then
			FOLDERNAME=$(basename $FILE)
			FOLDER_ID=`createDirectory "$FOLDERNAME" "$ROOT_FOLDER" "$ACCESS_TOKEN"`
			for file in $(find "$FILE" -type f);
			do
				uploadFile "$file" "$FOLDER_ID" "$ACCESS_TOKEN"
			done
	fi
fi
