<h1 align="center">Google drive upload</h1>
<p align="center">
<a href="https://github.com/labbots/google-drive-upload/releases"><img src="https://img.shields.io/github/release/labbots/google-drive-upload.svg?style=for-the-badge" alt="Latest Release"></a>
<a href="https://github.com/labbots/google-drive-upload/stargazers"><img src="https://img.shields.io/github/stars/labbots/google-drive-upload.svg?color=blueviolet&style=for-the-badge" alt="Stars"></a>
<a href="https://github.com/labbots/google-drive-upload/blob/master/LICENSE"><img src="https://img.shields.io/github/license/labbots/google-drive-upload.svg?style=for-the-badge" alt="License"></a>
</p>
<p align="center">
<a href="https://www.codacy.com/manual/labbots/google-drive-upload?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=labbots/google-drive-upload&amp;utm_campaign=Badge_Grade"><img alt="Codacy grade" src="https://img.shields.io/codacy/grade/55b1591a28af473886c8dfdb3f2c9123?style=for-the-badge"></a>
<a href="https://github.com/labbots/google-drive-upload/actions"><img alt="Github Action Checks" src="https://img.shields.io/github/workflow/status/labbots/google-drive-upload/Checks?label=CI%20Checks&style=for-the-badge"></a>
</p>
</p>
<p align="center">
<a href="https://plant.treeware.earth/labbots/google-drive-upload"><img alt="Buy us a tree" src="https://img.shields.io/treeware/trees/labbots/google-drive-upload?color=green&label=Buy%20us%20a%20Tree%20%F0%9F%8C%B3&style=for-the-badge"></a>
</p>

> Google drive upload is a collection of shell scripts runnable on all POSIX compatible shells ( sh / ksh / dash / bash / zsh / etc ).
>
> It utilizes google drive api v3 and google OAuth2.0 to generate access tokens and to authorize application for uploading files/folders to your google drive.

- Minimal
- Upload or Update files/folders
- Recursive folder uploading
- Sync your folders
  - Overwrite or skip existing files.
- Resume Interrupted Uploads
- Share files/folders
  - To anyone or a specific email.
- Config file support
  - Easy to use on multiple machines.
- Latest gdrive api used i.e v3
- Pretty logging
- Easy to install and update
  - Self update
  - [Auto update](#updation)
  - Can be per-user and invoked per-shell, hence no root access required or global install with root access.
- An additional sync script for background synchronisation jobs. Read [Synchronisation](#synchronisation) section for more info.

## Table of Contents

- [Compatibility](#compatibility)
  - [Linux or MacOS](#linux-or-macos)
  - [Android](#android)
  - [iOS](#ios)
  - [Windows](#windows)
- [Installing and Updating](#installing-and-updating)
  - [Native Dependencies](#native-dependencies)
  - [Installation](#installation)
    - [Basic Method](#basic-method)
    - [Advanced Method](#advanced-method)
  - [Updation](#updation)
- [Usage](#usage)
  - [Generating Oauth Credentials](#generating-oauth-credentials)
  - [Enable Drive API](#enable-drive-api)
  - [First Run](#first-run)
  - [Config file](#config)
  - [Upload](#upload)
  - [Upload Script Custom Flags](#upload-script-custom-flags)
  - [Multiple Inputs](#multiple-inputs)  
  - [Resuming Interrupted Uploads](#resuming-interrupted-uploads)
- [Additional Usage](#additional-usage)
  - [Synchronisation](#synchronisation)
    - [Basic Usage](#basic-usage)
    - [Sync Script Custom Flags](#sync-script-custom-flags)
    - [Background Sync Job](#background-sync-jobs)
- [Uninstall](#Uninstall)
- [Reporting Issues](#reporting-issues)
- [Contributing](#contributing)
- [Inspired By](#inspired-by)
- [License](#license)
- [Treeware](#treeware)

## Compatibility

As this is a collection of shell scripts, there aren't many dependencies. See [Native Dependencies](#native-dependencies) after this section for explicitly required program list.

### Linux or MacOS

For Linux or MacOS, you hopefully don't need to configure anything extra, it should work by default.

### Android

Install [Termux](https://wiki.termux.com/wiki/Main_Page) and done.

It's fully tested for all usecases of this script.

### iOS

Install [iSH](https://ish.app/)

While it has not been officially tested, but should work given the description of the app. Report if you got it working by creating an issue.

### Windows

Use [Windows Subsystem](https://docs.microsoft.com/en-us/windows/wsl/install-win10)

Again, it has not been officially tested on windows, there shouldn't be anything preventing it from working. Report if you got it working by creating an issue.

## Installing and Updating

### Native Dependencies

This repo contains two types of scripts, posix compatible and bash compatible.

<strong>These programs are required in both bash and posix scripts.</strong>

| Program          | Role In Script                                         |
| ---------------- | ------------------------------------------------------ |
| curl             | All network requests                                   |
| file or mimetype | Mimetype generation for extension less files           |
| find             | To find files and folders for recursive folder uploads |
| xargs            | For parallel uploading                                 |
| mkdir            | To create folders                                      |
| rm               | To remove files and folders                            |
| grep             | Miscellaneous                                          |
| sed              | Miscellaneous                                          |
| mktemp           | To generate temporary files ( optional )               |
| sleep            | Self explanatory                                       |
| ps               | To manage different processes                          |

<strong>If BASH is not available or BASH is available but version is less tham 4.x, then below programs are also required:</strong>

| Program             | Role In Script                             |
| ------------------- | ------------------------------------------ |
| awk                 | For url encoding in doing api requests     |
| date                | For installation, update and Miscellaneous |
| cat                 | Miscellaneous                              |
| stty or zsh or tput | To determine column size ( optional )      |

<strong>These are the additional programs needed for synchronisation script:</strong>

| Program       | Role In Script            |
| ------------- | ------------------------- |
| tail          | To show indefinite logs   |

### Installation

You can install the script by automatic installation script provided in the repository.

This will also install the synchronisation script provided in the repo.

Installation script also checks for the native dependencies.

Default values set by automatic installation script, which are changeable:

**Repo:** `labbots/google-drive-upload`

**Command name:** `gupload`

**Sync command name:** `gsync`

**Installation path:** `$HOME/.google-drive-upload`

**Source:** `release` { can be `branch` }

**Source value:** `latest` { can be `branchname` }

**Shell file:** `.bashrc` or `.zshrc` or `.profile`

For custom command names, repo, shell file, etc, see advanced installation method.

**Now, for automatic install script, there are two ways:**

#### Basic Method

To install google-drive-upload in your system, you can run the below command:

```shell
curl --compressed -Ls https://github.com/labbots/google-drive-upload/raw/master/install.sh | sh -s
```

and done.

#### Advanced Method

This section provides information on how to utilise the install.sh script for custom usescases.

These are the flags that are available in the install.sh script:

<details>

<summary>Click to expand</summary>

-   <strong>-p | --path <dir_name></strong>

    Custom path where you want to install the script.

    Note: For global installs, give path outside of the home dir like /usr/bin and it must be in the executable path already.

    ---

-   <strong>-c | --cmd <command_name></strong>

    Custom command name, after installation, script will be available as the input argument.

    To change sync command name, use install sh -c gupload sync='gsync'

    ---

-   <strong>-r | --repo <Username/reponame></strong>

    Install script from your custom repo, e.g --repo labbots/google-drive-upload, make sure your repo file structure is same as official repo.

    ---

-   <strong>-B | --branch <branch_name></strong>

    Specify branch name for the github repo, applies to custom and default repo both.

    ---

-   <strong>-R | --release <tag/release_tag></strong>

    Specify tag name for the github repo, applies to custom and default repo both.

    ---

-   <strong>-t | --time 'no of days'</strong>

    Specify custom auto update time ( given input will taken as number of days ) after which script will try to automatically update itself.

    Default: 5 ( 5 days )

    ---

-   <strong>-s | --shell-rc <shell_file></strong>

    Specify custom rc file, where PATH is appended, by default script detects .zshrc, .bashrc. and .profile.

    ---

-   <strong>--sh | --posix</strong>

    Force install posix scripts even if system has compatible bash binary present.

    ---

-   <strong>-q | --quiet</strong>

    Only show critical error/sucess logs.

    ---

-   <strong>-U | --uninstall</strong>

    Uninstall the script and remove related files.\n

    ---

-   <strong>-D | --debug</strong>

    Display script command trace.

    ---

-   <strong>-h | --help</strong>

    Display usage instructions.

    ---

Now, run the script and use flags according to your usecase.

E.g:

```shell
curl --compressed -Ls https://github.com/labbots/google-drive-upload/raw/master/install.sh | sh -s -- -r username/reponame -p somepath -s shell_file -c command_name -B branch_name
```
</details>

### Updation

If you have followed the automatic method to install the script, then you can automatically update the script.

There are two methods:

1.  Use the script itself to update the script.

    `gupload -u or gupload --update`

    This will update the script where it is installed.

    <strong>If you use the this flag without actually installing the script,</strong>

    <strong>e.g just by `sh upload.sh -u` then it will install the script or update if already installed.</strong>

1.  Run the installation script again.

    Yes, just run the installation script again as we did in install section, and voila, it's done.

1.  Automatic updates

    By default, script checks for update after 5 days. Use -t / --time flag of install.sh to modify the interval.

**Note: Above methods always obey the values set by user in advanced installation,**
**e.g if you have installed the script with different repo, say `myrepo/gdrive-upload`, then the update will be also fetched from the same repo.**

## Usage

First, we need to obtain our oauth credentials, here's how to do it:

### Generating Oauth Credentials

- Follow [Enable Drive API](#enable-drive-api) section.
- Open [google console](https://console.developers.google.com/).
- Click on "Credentials".
- Click "Create credentials" and select oauth client id.
- Select Application type "Desktop app" or "other".
- Provide name for the new credentials. ( anything )
- This would provide a new Client ID and Client Secret.
- Download your credentials.json by clicking on the download button.

Now, we have obtained our credentials, move to the [First run](#first-run) section to use those credentials:

### Enable Drive API

- Log into google developer console at [google console](https://console.developers.google.com/).
- Click select project at the right side of "Google Cloud Platform" of upper left of window.

If you cannot see the project, please try to access to [https://console.cloud.google.com/cloud-resource-manager](https://console.cloud.google.com/cloud-resource-manager).

You can also create new project at there. When you create a new project there, please click the left of "Google Cloud Platform". You can see it like 3 horizontal lines.

By this, a side bar is opened. At there, select "API & Services" -> "Library". After this, follow the below steps:

- Click "NEW PROJECT" and input the "Project Name".
- Click "CREATE" and open the created project.
- Click "Enable APIs and get credentials like keys".
- Go to "Library"
- Input "Drive API" in "Search for APIs & Services".
- Click "Google Drive API" and click "ENABLE".

[Go back to oauth credentials setup](#generating-oauth-credentials)

### First Run

On first run, the script asks for all the required credentials, which we have obtained in the previous section.

Execute the script: `gupload filename`

Now, it will ask for following credentials:

**Client ID:** Copy and paste from credentials.json

**Client Secret:** Copy and paste from credentials.json

**Refresh Token:** If you have previously generated a refresh token authenticated to your account, then enter it, otherwise leave blank.
If you don't have refresh token, script outputs a URL on the terminal script, open that url in a web browser and tap on allow. Copy the code and paste in the terminal.

**Root Folder:** Gdrive folder url/id from your account which you want to set as root folder. You can leave it blank and it takes `root` folder as default.

If everything went fine, all the required credentials have been set, read the next section on how to upload a file/folder.

### Config

After first run, the credentials are saved in config file. By default, the config file is `${HOME}/.googledrive.conf`.

To change the default config file or use a different one temporarily, see `-z / --config` custom in [Upload Script Custom Flags](#upload-script-custom-flags).

This is the format of a config file:

```shell
CLIENT_ID="client id"
CLIENT_SECRET="client secret"
REFRESH_TOKEN="refresh token"
SYNC_DEFAULT_ARGS="default args of gupload command for gsync"
ROOT_FOLDER_NAME="root folder name"
ROOT_FOLDER="root folder id"
ACCESS_TOKEN="access token"
ACCESS_TOKEN_EXPIRY="access token expiry"
```

You can use a config file in multiple machines, the values that are explicitly required are `CLIENT_ID`, `CLIENT_SECRET` and `REFRESH_TOKEN`.

If `ROOT_FOLDER` is not set, then it is asked if running in an interactive terminal, otherwise `root` is used.

`ROOT_FOLDER_NAME`, `ACCESS_TOKEN` and `ACCESS_TOKEN_EXPIRY` are automatically generated using `REFRESH_TOKEN`.

`SYNC_DEFAULT_ARGS` is optional.

A pre-generated config file can be also used where interactive terminal access is not possible, like Continuous Integration, docker, jenkins, etc

Just have to print values to `"${HOME}/.googledrive.conf"`, e.g:

```shell
printf "%s\n" "CLIENT_ID=\"client id\"
CLIENT_SECRET=\"client secret\"
REFRESH_TOKEN=\"refresh token\"
" >| "${HOME}/.googledrive.conf"
```

Note: Don't skip those backslashes before the double qoutes, it's necessary to handle spacing.

### Upload

For uploading files/remote gdrive files, the syntax is simple;

`gupload filename/foldername/file_id/file_link -c gdrive_folder_name`

where `filename/foldername` is input file/folder and `gdrive_folder_name` is the name of the folder on gdrive, where the input file/folder will be uploaded.

and `file_id/file_link` is the accessible gdrive file link or id which will be uploaded without downloading.

If `gdrive_folder_name` is present on gdrive, then script will upload there, else will make a folder with that name.

Note: It's not mandatory to use -c / -C / --create-dir flag.

Apart from basic usage, this script provides many flags for custom usecases, like parallel uploading, skipping upload of existing files, overwriting, etc.

### Upload Script Custom Flags

These are the custom flags that are currently implemented:

-   <strong>-z | --config</strong>

    Override default config file with custom config file.

    Default Config: `${HOME}/.googledrive.conf`

    If you want to change the default value of the config path, then use this format,

    `gupload --config default=your_config_file_path`

    ---

-   <strong>-c | -C | --create-dir <foldername></strong>

    Option to create directory. Will provide folder id. Can be used to specify workspace folder for uploading files/folders.

    If this option is used, then input file is optional.

    ---

-   <strong>-r | --root-dir <google_folderid></strong>

    Google folder id or url to which the file/directory to upload.

    If you want to change the default value of the rootdir stored in config, then use this format,

    `gupload --root-dir default=root_folder_[id/url]`

    ---

-   <strong>-s | --skip-subdirs</strong>

    Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder, use this along with -p/--parallel option to speed up the uploads.

    ---

-   <strong>-p | --parallel <no_of_files_to_parallely_upload></strong>

    Upload multiple files in parallel, Max value = 10, use with folders.

    Note:

    - This command is only helpful if you are uploading many files which aren't big enough to utilise your full bandwidth, using it otherwise will not speed up your upload and even error sometimes,
    - 1 - 6 value is recommended, but can use upto 10. If errors with a high value, use smaller number.
    - Beaware, this isn't magic, obviously it comes at a cost of increased cpu/ram utilisation as it forks multiple shell processes to upload ( google how xargs works with -P option ).

    ---

-   <strong>-o | --overwrite</strong>

    Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders and single/multiple files.

    Note: If you use this flag along with -d/--skip-duplicates, the skip duplicates flag is preferred.

    ---

-   <strong>-d | --skip-duplicates</strong>

    Do not upload the files with the same name, if already present in the root folder/input folder, also works with recursive folders.

    ---

-   <strong>-f | --file/folder</strong>

    Specify files and folders explicitly in one command, use multiple times for multiple folder/files.

    For uploading multiple input into the same folder:

    - Use -C / --create-dir ( e.g `./upload.sh -f file1 -f folder1 -f file2 -C <folder_wherw_to_upload>` ) option.
    - Give two initial arguments which will use the second argument as the folder you wanna upload ( e.g: `./upload.sh filename <folder_where_to_upload> -f filename -f foldername` ).

        This flag can also be used for uploading files/folders which have `-` character in their name, normally it won't work, because of the flags, but using `-f -[file|folder]namewithhyphen` works. Applies for -C/--create-dir too.

        Also, as specified by longflags ( `--[file|folder]` ), you can simultaneously upload a folder and a file.

        Incase of multiple -f flag having duplicate arguments, it takes the last duplicate of the argument to upload, in the same order provided.

    ---

-   <strong>-cl | --clone</strong>

    Upload a gdrive file without downloading, require accessible gdrive link or id as argument.

    ---
-   <strong>-S | --share <optional_email_address></strong>

    Share the uploaded input file/folder, grant reader permission to provided email address or to everyone with the shareable link.

    ---

-   <strong>--speed 'speed'</strong>

    Limit the download speed, supported formats: 1K, 1M and 1G.

    ---

-   <strong>-R | --retry 'num of retries'</strong>

    Retry the file upload if it fails, postive integer as argument. Currently only for file uploads.

    ---

-   <strong>-in | --include 'pattern'</strong>

    Only include the files with the given pattern to upload - Applicable for folder uploads.

    e.g: gupload local_folder --include "*1*", will only include the files with pattern '1' in the name.

    Note: Only provide patterns which are supported by find -name option.

    ---

-   <strong>-ex | --exclude 'pattern'</strong>

    e.g: gupload local_folder --exclude "*1*", will exclude all the files with pattern '1' in the name.

    Note: Only provide patterns which are supported by find -name option.

    ---

-   <strong>--hide</strong>

    This flag will prevent the script to print sensitive information like root folder id or drivelink

    ---

-   <strong>-q | --quiet</strong>

    Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.

    ---

-   <strong>-v | --verbose</strong>

    Dislay detailed message (only for non-parallel uploads).

    ---

-   <strong>-V | --verbose-progress</strong>

    Display detailed message and detailed upload progress(only for non-parallel uploads).

    ---

-   <strong>--skip-internet-check</strong>

    Do not check for internet connection, recommended to use in sync jobs.

    ---

-   <strong>-i | --save-info <file_to_save_info></strong>

    Save uploaded files info to the given filename."

    ---

-   <strong>-u | --update</strong>

    Update the installed script in your system, if not installed, then install.

    ---

-   <strong>--uninstall</strong>

    Uninstall the script from your system.

    ---

-   <strong>--info</strong>

    Show detailed info, only if script is installed system wide.

    ---

-   <strong>-h | --help</strong>

    Display usage instructions.

    ---

-   <strong>-D | --debug</strong>

    Display script command trace.

    ---

### Multiple Inputs

For using multiple inputs at a single time, you can use the `-f/--file/--folder` or `-cl/--clone` flag as explained above.

Now, to achieve multiple inputs without flag, you can just use glob or just give them as arguments.

e.g:

-   <strong>gupload a b c d</strong>

    a/b/c/d will be treated as file/folder/gdrive_link_or_id.

    ---

-   <strong>gupload `*mp4 *mkv`</strong>

    This will upload all the mp4 and mkv files in the folder, if any.

    To upload all files, just use *. For more info, google how globs work in shell.

    ---

-   <strong>gupload a b -d c d -c e</strong>

    a/b/c/d will be treated as file/folder/gdrive_link_or_id and e as `gdrive_folder`.

    ---

### Resuming Interrupted Uploads

Uploads interrupted either due to bad internet connection or manual interruption, can be resumed from the same position.

- Script checks 3 things, filesize, name and workspace folder. If an upload was interrupted, then resumable upload link is saved in `"$HOME/.google-drive-upload/"`, which later on when running the same command as before, if applicable, resumes the upload from the same position as before.
- Small files cannot be resumed, less that 1 MB, and the amount of size uploaded should be more than 1 MB to resume.
- No progress bars for resumable uploads as it messes up with output.
- You can interrupt many times you want, it will resume ( hopefully ).

## Additional Usage

### Synchronisation

This repo also provides an additional script ( [sync.sh](https://github.com/labbots/google-drive-upload/blob/master/sync.sh) ) to utilise upload.sh for synchronisation jobs, i.e background jobs.

#### Basic Usage

To create a sync job, just run

`gsync folder_name -d gdrive_folder`

Here, `folder_name` is the local folder you want to sync and `gdrive_folder` is google drive folder name.

In the local folder, all the contents present or added in the future will be automatically uploaded.

Note: Giving `gdrive_folder` is optional, if you don't specify a name with -d/--directory flags, then it will upload in the root folder set by gupload command.

Also, gdrive folder creation works in the same way as gupload command.

Default wait time: 3 secs ( amount of time to wait before checking new files ).

Default gupload arguments: None ( see -a/--arguments section below ).

#### Sync Script Custom Flags

Read this section thoroughly to fully utilise the sync script, feel free to open an issue if any doubts regarding the usage.

<details>

<summary>Click to expand</summary>

-   <strong>-d | --directory</strong>

    Specify gdrive folder name, if not specified then local folder name is used.

    ---

-   <strong>-j | --jobs</strong>

    See all background jobs that were started and still running.

    Use -j/--jobs v/verbose to show additional information for jobs.

    Additional information includes: CPU usage & Memory usage and No. of failed & successful uploads.

    ---

-   <strong>-p | --pid</strong>

    Specify a pid number, used for --jobs or --kill or --info flags, multiple usage allowed.

    ---

-   <strong>-i | --info</strong>

    Print information for a specific job. These are the methods to do it:

    -   By specifying local folder and gdrive folder of an existing job,

        e.g: `gsync local_folder -d gdrive folder -i`

    -   By specifying pid number,

        e.g: `gsync -i -p pid_number`

    -   To show info of multiple jobs, use this flag multiple times,

        e.g: `gsync -i pid1 -p pid2 -p pid3`. You can also use it with multiple inputs by adding this flag.

    ---

-   <strong>-k | --kill</strong>

    Kill background jobs, following are methods to do it:

    -   By specifying local_folder and gdrive_folder,

        e.g. `gsync local_folder -d gdrive_folder -k`, will kill that specific job.

    -   pid ( process id ) number can be used as an additional argument to kill a that specific job,

        e.g: `gsync -k -p pid_number`.

    -   To kill multiple jobs, use this flag multiple times,

        e.g: `gsync -k pid1 -p pid2 -p pid3`. You can also using it with multiple inputs with this flag.

    -   This flag can also be used to kill all the jobs,

        e.g: `gsync -k all`. This will stop all the background jobs running.

    ---

-   <strong>-t | --time time_in_seconds</strong>

    The amount of time that sync will wait before checking new files in the local folder given to sync job.

    e.g: `gsync -t 4 local_folder`, here 4 is the wait time.

    To set default time, use `gsync local_folder -t default=4`, it will stored in your default config.

    ---

-   <strong>-l | --logs</strong>

    To show the logs after starting a job or show log of existing job.

    This option can also be used to make a job sync on foreground, rather in background, thus ctrl + c or ctrl +z can exit the job.

    -   By specifying local_folder and gdrive_folder,

        e.g. `gsync local_folder -d gdrive_folder -l`, will show logs of that specific job.

    -   pid ( process id ) number can be used as an additional argument to show logs of a specific job,

        e.g: `gsync -l -p pid_number`.

    Note: If used with multiple inputs or pid numbers, then only first pid/input log is shown, as it goes on indefinitely.

    ---

-   <strong>-a | --arguments</strong>

    As the script uses gupload, you can specify custom flags for background job,

    e.g: `gsync local_folder -a '-q -p 4 -d'`

    To set some arguments by default, use `gsync -a default='-q -p 4 -d'`.

    In this example, will skip existing files, 4 parallel upload in case of folder.

    ---

-   <strong>-fg | --foreground</strong>

    This will run the job in foreground and show the logs.

    Note: A already running job cannot be resumed in foreground, it will just show the existing logs.

    ---

-   <strong>-in | --include 'pattern'</strong>

    Only include the files with the given pattern to upload.

    e.g: gsync local_folder --include "*1*", will only include the files with pattern '1' in the name.\n

    Note: Only provide patterns which are supported by grep, and supported by -E option.

    ---

-   <strong>-ex | --exclude 'pattern'</strong>

    Exclude the files with the given pattern from uploading.

    e.g: gsync local_folder --exclude "*1*", will exclude all the files with pattern '1' in the name.\n

    Note: Only provide patterns which are supported by grep, and supported by -E option.

    ---

-   <strong>-c | --command command_name</strong>

    Incase if gupload command installed with any other name or to use in systemd service, which requires fullpath.

    ---

-   <strong>--sync-detail-dir 'dirname'</strong>

    Directory where a job information will be stored.

    Default: ${HOME}/.google-drive-upload

-   <strong>-s | --service 'service name'</strong>

    To generate systemd service file to setup background jobs on boot.

    Note: If this command is used, then only service files are created, no other work is done.

    ---

-   <strong>-d | --debug</strong>

    Display script command trace, use before all the flags to see maximum script trace.

    ---

Note: Flags that use pid number as input should be used at last, if you are not intending to provide pid number, say in case of a folder name with positive integers.

</details>

#### Background Sync Jobs

There are basically two ways to start a background job, first one we already covered in the above section.

It will indefinitely run until and unless the host machine is rebooted.

Now, a systemd service service can also be created which will start sync job after boot.

1.  To generate a systemd unit file, run the sync command with `--service service_name` at the end.

    e.g: If `gsync foldername -d drive_folder --service myservice`, where, myservice can be any name desired.

    This will generate a script and print the next required commands to start/stop/enable/disable the service.

    The commands that will be printed is explained below:

1.  Start the service `sh gsync-test.service.sh start`, where gsync-test is the service name

    This is same as starting a sync job with command itself as mentioned in previous section.

    To stop: `sh gsync-test.service.sh stop`

1.  If you want the job to automatically start on boot, run `sh gsync-test.service.sh enable`

    To disable: `sh gsync-test.service.sh disable`

1.  To see logs after a job has been started.

    `sh gsync-test.service.sh logs`

1.  To remove a job from system, `sh gsync-test.service.sh remove`

You can use multiple commands at once, e.g: `sh gsync-test.service.sh start logs`, will start and show the logs.

Note: The script is merely a wrapper, it uses `systemctl` to start/stop/enable/disable the service and `journalctl` is used to show the logs.

Extras: A sample service file has been provided in the repo just for reference, it is recommended to use `gsync` to generate the service file.

## Uninstall

If you have followed the automatic method to install the script, then you can automatically uninstall the script.

There are two methods:

1.  Use the script itself to uninstall the script.

    `gupload -U or gupload --uninstall`

    This will remove the script related files and remove path change from shell file.

1.  Run the installation script again with -U/--uninstall flag

    ```shell
    curl --compressed -Ls https://github.com/labbots/google-drive-upload/raw/master/install.sh | sh -s -- --uninstall
    ```

    Yes, just run the installation script again with the flag and voila, it's done.

**Note: Above methods always obey the values set by user in advanced installation.**

## Reporting Issues

| Issues Status | [![GitHub issues](https://img.shields.io/github/issues/labbots/google-drive-upload.svg?label=&style=for-the-badge)](https://GitHub.com/labbots/google-drive-upload/issues/) | [![GitHub issues-closed](https://img.shields.io/github/issues-closed/labbots/google-drive-upload.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/labbots/google-drive-upload/issues?q=is%3Aissue+is%3Aclosed) |
| :-----------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

Use the [GitHub issue tracker](https://github.com/labbots/google-drive-upload/issues) for any bugs or feature suggestions.

Before creating an issue, make sure to follow the guidelines specified in [CONTRIBUTION.md](https://github.com/labbots/google-drive-upload/blob/master/CONTRIBUTING.md#creating-an-issue)

## Contributing

| Total Contributers | [![GitHub contributors](https://img.shields.io/github/contributors/labbots/google-drive-upload.svg?style=for-the-badge&label=)](https://GitHub.com/labbots/google-drive-upload/graphs/contributors/) |
| :----------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

| Pull Requests | [![GitHub pull-requests](https://img.shields.io/github/issues-pr/labbots/google-drive-upload.svg?label=&style=for-the-badge&color=orange)](https://GitHub.com/labbots/google-drive-upload/issues?q=is%3Apr+is%3Aopen) | [![GitHub pull-requests closed](https://img.shields.io/github/issues-pr-closed/labbots/google-drive-upload.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/labbots/google-drive-upload/issues?q=is%3Apr+is%3Aclosed) |
| :-----------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |

Submit patches to code or documentation as GitHub pull requests! Check out the [contribution guide](https://github.com/labbots/google-drive-upload/blob/master/CONTRIBUTING.md)

Contributions must be licensed under the MIT. The contributor retains the copyright.

## Inspired By

- [github-bashutils](https://github.com/soulseekah/bash-utils) - soulseekah/bash-utils
- [deanet-gist](https://gist.github.com/deanet/3427090) - Uploading File into Google Drive
- [Bash Bible](https://github.com/dylanaraps/pure-bash-bible) - A collection of pure bash alternatives to external processes
- [sh bible](https://github.com/dylanaraps/pure-sh-bible) - A collection of posix alternatives to external processes

## License

[MIT](https://github.com/labbots/google-drive-upload/blob/master/LICENSE)

## Treeware

[![Buy us a tree](https://img.shields.io/treeware/trees/labbots/google-drive-upload?color=green&style=for-the-badge)](https://plant.treeware.earth/labbots/google-drive-upload)

This package is [Treeware](https://treeware.earth). You are free to use this package, but if you use it in production, then we would highly appreciate you [**buying the world a tree**](https://plant.treeware.earth/labbots/google-drive-upload) to thank us for our work. By contributing to the Treeware forest you’ll be creating employment for local families and restoring wildlife habitats.
