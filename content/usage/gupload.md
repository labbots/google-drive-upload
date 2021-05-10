---
title : Gupload Script 
description : Gupload Script usage and configurable arguments. 
date : 2021-05-10T18:06:06+01:00
lastmod : 2021-05-10T18:06:06+01:00
weight : 1
---

For uploading files/remote gdrive files, the syntax is simple;

`gupload filename/foldername/file_id/file_link -c gdrive_folder_name`

where `filename/foldername` is input file/folder and `gdrive_folder_name` is the name of the folder on gdrive, where the input file/folder will be uploaded.

and `file_id/file_link` is the accessible gdrive file link or id which will be uploaded without downloading.

If `gdrive_folder_name` is present on gdrive, then script will upload there, else will make a folder with that name.

Note: It's not mandatory to use -c / -C / --create-dir flag.

Apart from basic usage, this script provides many flags for custom usecases, like parallel uploading, skipping upload of existing files, overwriting, etc.

### Upload Script Custom Flags

These are the custom flags that are currently implemented:

-   **-z | --config**

    Override default config file with custom config file.

    Default Config: `${HOME}/.googledrive.conf`

    If you want to change the default value of the config path, then use this format,

    `gupload --config default=your_config_file_path`

    ---

-   **-a | --account 'account name'**

    Use different account than the default one.

    To change the default account name, do

    `gupload -a/--account default=account_name`

    ---

-   **-la | --list-accounts**

    Print all configured accounts in the config files.

    ---

-   **-ca | --create-account 'account name'**

    To create a new account with the given name if does not already exists. If the given account exists then script will ask for a new name.

    Note 1: Only for interactive terminal usage.

    Note 2: This flag is preferred over `--account`.

    ---

-   **-da | --delete-account 'account name'**

    To delete an account information from config file.

    ---

-   **-c | -C | --create-dir <foldername>**

    Option to create directory. Will provide folder id. Can be used to specify workspace folder for uploading files/folders.

    If this option is used, then input file is optional.

    ---

-   **-r | --root-dir <google_folderid>**

    Google folder id or url to which the file/directory to upload.

    If you want to change the default value of the rootdir stored in config, then use this format,

    `gupload --root-dir default=root_folder_[id/url]`

    ---

-   **-s | --skip-subdirs**

    Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder, use this along with -p/--parallel option to speed up the uploads.

    ---

-   **-p | --parallel <no_of_files_to_parallely_upload>**

    Upload multiple files in parallel, Max value = 10, use with folders.

    Note:

    - This command is only helpful if you are uploading many files which aren't big enough to utilise your full bandwidth, using it otherwise will not speed up your upload and even error sometimes,
    - 1 - 6 value is recommended, but can use upto 10. If errors with a high value, use smaller number.
    - Beaware, this isn't magic, obviously it comes at a cost of increased cpu/ram utilisation as it forks multiple shell processes to upload ( google how xargs works with -P option ).

    ---

-   **-o | --overwrite**

    Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders and single/multiple files.

    Note: If you use this flag along with -d/--skip-duplicates, the skip duplicates flag is preferred.

    ---

-   **-desc | --description | --description-all 'description'**

    Specify description for the given file.

    To use the respective metadata of a file, below is the format:

    File name ( fullname ): %f
    Size: %s
    Mime Type: %m

    Now to actually use it: `--description 'Filename: %f, Size: %s, Mime: %m'`

    Note: For files inside folders, use `--description-all` flag.

    ---

-   **-d | --skip-duplicates**

    Do not upload the files with the same name, if already present in the root folder/input folder, also works with recursive folders.

    ---

-   **-f | --file/folder**

    Specify files and folders explicitly in one command, use multiple times for multiple folder/files.

    For uploading multiple input into the same folder:

    - Use -C / --create-dir ( e.g `./upload.sh -f file1 -f folder1 -f file2 -C <folder_wherw_to_upload>` ) option.
    - Give two initial arguments which will use the second argument as the folder you wanna upload ( e.g: `./upload.sh filename <folder_where_to_upload> -f filename -f foldername` ).

        This flag can also be used for uploading files/folders which have `-` character in their name, normally it won't work, because of the flags, but using `-f -[file|folder]namewithhyphen` works. Applies for -C/--create-dir too.

        Also, as specified by longflags ( `--[file|folder]` ), you can simultaneously upload a folder and a file.

        Incase of multiple -f flag having duplicate arguments, it takes the last duplicate of the argument to upload, in the same order provided.

    ---

-   **-cl | --clone**

    Upload a gdrive file without downloading, require accessible gdrive link or id as argument.

    ---
-   **-S | --share <optional_email_address>**

    Share the uploaded input file/folder, grant reader permission to provided email address or to everyone with the shareable link.

    ---

-   **-SM | -sm | --share-mode 'share mode'**

    Specify the share mode for sharing file.

    Share modes are:

    - r / reader - Read only permission.
    - w / writer - Read and write permission.
    - c / commenter - Comment only permission.

    Note: Although this flag is independent of --share flag but when email is needed, then --share flag use is neccessary.

    ---

-   **--speed 'speed'**

    Limit the download speed, supported formats: 1K, 1M and 1G.

    ---

-   **-R | --retry 'num of retries'**

    Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.

    ---

-   **-in | --include 'pattern'**

    Only include the files with the given pattern to upload - Applicable for folder uploads.

    e.g: gupload local_folder --include "*1*", will only include the files with pattern '1' in the name.

    Note: Only provide patterns which are supported by find -name option.

    ---

-   **-ex | --exclude 'pattern'**

    e.g: gupload local_folder --exclude "*1*", will exclude all the files with pattern '1' in the name.

    Note: Only provide patterns which are supported by find -name option.

    ---

-   **--hide**

    This flag will prevent the script to print sensitive information like root folder id or drivelink

    ---

-   **-q | --quiet**

    Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.

    ---

-   **-v | --verbose**

    Dislay detailed message (only for non-parallel uploads).

    ---

-   **-V | --verbose-progress**

    Display detailed message and detailed upload progress(only for non-parallel uploads).

    ---

-   **--skip-internet-check**

    Do not check for internet connection, recommended to use in sync jobs.

    ---

-   **-i | --save-info <file_to_save_info>**

    Save uploaded files info to the given filename."

    ---

-   **-u | --update**

    Update the installed script in your system, if not installed, then install.

    ---

-   **--uninstall**

    Uninstall the script from your system.

    ---

-   **--info**

    Show detailed info, only if script is installed system wide.

    ---

-   **-h | --help**

    Display usage instructions.

    ---

-   **-D | --debug**

    Display script command trace.

    ---

### Multiple Inputs

For using multiple inputs at a single time, you can use the `-f/--file/--folder` or `-cl/--clone` flag as explained above.

Now, to achieve multiple inputs without flag, you can just use glob or just give them as arguments.

e.g:

-   `gupload a b c d`

    a/b/c/d will be treated as file/folder/gdrive_link_or_id.

    ---

-   `gupload *mp4 *mkv`

    This will upload all the mp4 and mkv files in the folder, if any.

    To upload all files, just use *. For more info, google how globs work in shell.

    ---

-   `gupload a b -d c d -c e`

    a/b/c/d will be treated as file/folder/gdrive_link_or_id and e as `gdrive_folder`.

    ---

### Resuming Interrupted Uploads

Uploads interrupted either due to bad internet connection or manual interruption, can be resumed from the same position.

- Script checks 3 things, filesize, name and workspace folder. If an upload was interrupted, then resumable upload link is saved in `"$HOME/.google-drive-upload/"`, which later on when running the same command as before, if applicable, resumes the upload from the same position as before.
- Small files cannot be resumed, less that 1 MB, and the amount of size uploaded should be more than 1 MB to resume.
- No progress bars for resumable uploads as it messes up with output.
- You can interrupt many times you want, it will resume ( hopefully ).
