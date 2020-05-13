<h1 align="center">Google drive upload</h1>
<p align="center">
<a href="https://github.com/labbots/google-drive-upload/stargazers"><img src="https://img.shields.io/github/stars/labbots/google-drive-upload.svg?color=blueviolet&style=for-the-badge" alt="Stars"></a>
<a href="https://github.com/labbots/google-drive-upload/releases"><img src="https://img.shields.io/github/release/labbots/google-drive-upload.svg?style=for-the-badge" alt="Latest Release"></a>
<a href="https://github.com/labbots/google-drive-upload/blob/master/LICENSE"><img src="https://img.shields.io/github/license/labbots/google-drive-upload.svg?style=for-the-badge" alt="License"></a>
</p>

> Google drive upload is a bash compliant script based on v3 google APIs.

> It utilizes google OAuth2.0 to generate access tokens and to authorize application for uploading files/folders to your google drive.

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
  - [First Run](#first-run)
  - [Upload](#upload)
  - [Custom Flags](#custom-flags)
  - [Resuming Interrupted Uploads](#resuming-interrupted-uploads)
- [Uninstall](#Uninstall)
- [Reporting Issues](#reporting-issues)
- [Contributing](#contributing)
- [Inspired By](#inspired-by)
- [License](#license)

## Compatibility

As this is a bash script, there aren't many dependencies. See [Native Dependencies](#native-dependencies) after this section for explicitly required program list.

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

The script explicitly requires the following programs:

| Program | Role In Script |
| --------| -------------- |
| Bash | Execution of script |
| Curl | All network requests |
| file/mimetype | Mimetype generation for extension less files |
| find | To find files and folders for recursive folder uploads |
| xargs | For parallel uploading |
| grep | Miscellaneous |
| sed | Miscellaneous |

### Installation

You can install the script by automatic installation script provided in the repository.

Default values set by automatic installation script:

**Repo:** `labbots/google-drive-upload`

**Command name:** `gupload`

**Installation path:** `$HOME/.google-drive-upload`

**Source:** `release` { can be `branch` }

**Source value:** `latest` { can be `branchname` }

**Shell file:** `.bashrc` or `.zshrc` or `.profile`

For custom command names, repo, shell file, etc, see advanced installation method.

**Now, for automatic install script, there are two ways:**

#### Basic Method

To install google-drive-upload in your system, you can run the below command:

```shell
bash <(curl --compressed -s https://raw.githubusercontent.com/labbots/google-drive-upload/master/install.sh)
```

and done.

#### Advanced Method

This section provides information on how to utilise the install.sh script for custom usescases.

These are the flags that are available in the install.sh script:

- **-i | --interactive**

    Install script interactively, will ask for all the variables one by one.

    Note: This will disregard all arguments given with below flags.

    ***

- **-p | --path <dir_name>**

    Custom path where you want to install the script.

    ***

- **-c | --cmd <command_name>**

    Custom command name, after installation, script will be available as the input argument.

    ***

- **-r | --repo <Username/reponame>**

    Install script from your custom repo, e.g --repo labbots/google-drive-upload, make sure your repo file structure is same as official repo.

    ***

- **-B | --branch <branch_name>**

    Specify branch name for the github repo, applies to custom and default repo both.

    ***

- **-R | --release <tag/release_tag>**

    Specify tag name for the github repo, applies to custom and default repo both.

    ***

- **-s | --shell-rc <shell_file>**

    Specify custom rc file, where PATH is appended, by default script detects .zshrc, .bashrc. and .profile.

    ***

- **-D | --debug**

    Display script command trace.

    ***

- **-h | --help**

    Display usage instructions.

    ***

Now, run the script and use flags according to your usecase.

E.g:

```shell
bash <(curl --compressed -s https://raw.githubusercontent.com/labbots/google-drive-upload/master/install.sh) -r username/reponame -p somepath -s shell_file -c command_name -B branch_name
```

### Updation

If you have followed the automatic method to install the script, then you can automatically update the script.

There are two methods:

1. Use the script itself to update the script.

    `gupload -u or gupload --update`

    This will update the script where it is installed.

    **If you use the this flag without actually installing the script,**

    **e.g just by `bash upload.sh -u` then it will install the script or update if already installed.**

2. Run the installation script again.

    Yes, just run the installation script again as we did in install section, and voila, it's done.

**Note: Above methods always obey the values set by user in advanced installation,**
**e.g if you have installed the script with different repo, say `myrepo/gdrive-upload`, then the update will be also fetched from the same repo.**

## Usage

First, we need to obtain our Oauth credentials, here's how to do it:

### Generating Oauth Credentials

- Log into google developer console at [google console](https://console.developers.google.com/).
- Create new Project or use existing project.
- Creating new OAuth 2.0 Credentials:
  - Select Application type "other".
  - Provide name for the new credentials. ( anything )
  - This would provide a new Client ID and Client Secret.
  - Download your credentials.json by clicking on the download button.
- Enable Google Drive API for the project under "Library".

Now, we have obtained our credentials, move to next section to use those credentials to setup:

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

### Upload

For uploading files, the syntax is simple;

`gupload filename/foldername gdrive_folder_name`

where `filename/foldername` is input file/folder and `gdrive_folder_name` is the name of the folder on gdrive, where the input file/folder will be uploaded.

If `gdrive_folder_name` is present on gdrive, then script will upload there, else will make a folder with that name.

Apart from basic usage, this script provides many flags for custom usecases, like parallel uploading, skipping upload of existing files, overwriting, etc.

### Custom Flags

These are the custom flags that are currently implemented:

- **-z | --config**

    Override default config file with custom config file.

    Default Config: `"${HOME}/.googledrive.conf`

    ***

- **-C | --create-dir <foldername>**

    Option to create directory. Will provide folder id. Can be used to specify workspace folder for uploading files/folders.

    ***

- **-r | --root-dir <google_folderid>**

    Google folder id or url to which the file/directory to upload.

    ***

- **-s | --skip-subdirs**

    Skip creation of sub folders and upload all files inside the INPUT folder/sub-folders in the INPUT folder, use this along with -p/--parallel option to speed up the uploads.

    ***

- **-p | --parallel <no_of_files_to_parallely_upload>**

    Upload multiple files in parallel, Max value = 10, use with folders.

    Note:
  - This command is only helpful if you are uploading many files which aren't big enough to utilise your full bandwidth, using it otherwise will not speed up your upload and even error sometimes,
  - 1 - 6 value is recommended, but can use upto 10. If errors with a high value, use smaller number.
  - Beaware, this isn't magic, obviously it comes at a cost of increased cpu/ram utilisation as it forks multiple bash processes to upload ( google how xargs works with -P option ).

  ***

- **-o | --overwrite**

    Overwrite the files with the same name, if present in the root folder/input folder, also works with recursive folders and single/multiple files.

    Note: If you use this flag along with -d/--skip-duplicates, the skip duplicates flag is preferred.

    ***

- **-d | --skip-duplicates**

    Do not upload the files with the same name, if already present in the root folder/input folder, also works with recursive folders.

    ***

- **-f | --[file/folder]**

    Specify files and folders explicitly in one command, use multiple times for multiple folder/files.

    For uploading multiple input into the same folder:

  - Use -C / --create-dir ( e.g `./upload.sh -f file1 -f folder1 -f file2 -C <folder_wherw_to_upload>` ) option.
  - Give two initial arguments which will use the second argument as the folder you wanna upload ( e.g: `./upload.sh filename <folder_where_to_upload> -f filename -f foldername` ).

    This flag can also be used for uploading files/folders which have `-` character in their name, normally it won't work, because of the flags, but using `-f -[file|folder]namewithhyphen` works. Applies for -C/--create-dir too.

    Also, as specified by longflags ( `--[file|folder]` ), you can simultaneously upload a folder and a file.

    Incase of multiple -f flag having duplicate arguments, it takes the last duplicate of the argument to upload, in the same order provided.

  ***

- **-S | --share <optional_email_address>**

    Share the uploaded input file/folder, grant reader permission to provided email address or to everyone with the shareable link.

    ***

- **-q | --quiet**

    Supress the normal output, only show success/error upload messages for files, and one extra line at the beginning for folder showing no. of files and sub folders.

    ***

- **-v | --verbose**

    Dislay detailed message (only for non-parallel uploads).

    ***

- **-V | --verbose-progress**

    Display detailed message and detailed upload progress(only for non-parallel uploads).

    ***

- **-i | --save-info <file_to_save_info>**

    Save uploaded files info to the given filename."

    ***

- **-u | --update**

    Update the installed script in your system, if not installed, then install.

    ***

- **--info**

    Show detailed info, only if script is installed system wide.

    ***

- **-h | --help**

    Display usage instructions.

    ***

- **-D | --debug**

    Display script command trace.

    ***

### Resuming Interrupted Uploads

Uploads interrupted either due to bad internet connection or manual interruption, can be resumed from the same position.

- Script checks 3 things, filesize, name and workspace folder. If an upload was interrupted, then resumable upload link is saved in `"$HOME/.google-drive-upload/"`, which later on when running the same command as before, if applicable, resumes the upload from the same position as before.
- Small files cannot be resumed, less that 1 MB, and the amount of size uploaded should be more than 1 MB to resume.
- No progress bars for resumable uploads as it messes up with output.
- You can interrupt many times you want, it will resume ( hopefully ).

## Uninstall

If you have followed the automatic method to install the script, then you can automatically uninstall the script.

There are two methods:

1. Use the script itself to uninstall the script.

    `gupload -U or gupload --uninstall`

    This will remove the script related files and remove path change from shell file.

2. Run the installation script again with -U/--uninstall flag

    ```shell
    bash <(curl --compressed -s https://raw.githubusercontent.com/labbots/google-drive-upload/master/install.sh) --uninstall
    ```

    Yes, just run the installation script again with the flag and voila, it's done.

**Note: Above methods always obey the values set by user in advanced installation.**

## Reporting Issues

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/614d326e3e514c81b1dbd698c0e9cd0b)](https://app.codacy.com/manual/labbots/google-drive-upload?utm_source=github.com&utm_medium=referral&utm_content=labbots/google-drive-upload&utm_campaign=Badge_Grade_Dashboard)
| Issues Status | [![GitHub issues](https://img.shields.io/github/issues/labbots/google-drive-upload.svg?label=&style=for-the-badge)](https://GitHub.com/labbots/google-drive-upload/issues/) | [![GitHub issues-closed](https://img.shields.io/github/issues-closed/labbots/google-drive-upload.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/labbots/google-drive-upload/issues?q=is%3Aissue+is%3Aclosed) |
| :--: | :--: | :--: |

Use the [GitHub issue tracker](https://github.com/labbots/google-drive-upload/issues) for any bugs or feature suggestions.

Before creating an issue, make sure to follow the guidelines specified in [CONTRIBUTION.md](https://github.com/labbots/google-drive-upload/blob/master/CONTRIBUTING.md#creating-an-issue)

## Contributing

| Total Contributers | [![GitHub contributors](https://img.shields.io/github/contributors/labbots/google-drive-upload.svg?style=for-the-badge&label=)](https://GitHub.com/labbots/google-drive-upload/graphs/contributors/) |
| :--: | :--: |

| Pull Requests | [![GitHub pull-requests](https://img.shields.io/github/issues-pr/labbots/google-drive-upload.svg?label=&style=for-the-badge&color=orange)](https://GitHub.com/labbots/google-drive-upload/issues?q=is%3Apr+is%3Aopen) | [![GitHub pull-requests closed](https://img.shields.io/github/issues-pr-closed/labbots/google-drive-upload.svg?label=&color=success&style=for-the-badge)](https://GitHub.com/labbots/google-drive-upload/issues?q=is%3Apr+is%3Aclosed) |
| :--: | :--: | :--: |

Submit patches to code or documentation as GitHub pull requests! Check out the [contribution guide](https://github.com/labbots/google-drive-upload/blob/master/CONTRIBUTING.md)

Contributions must be licensed under the MIT. The contributor retains the copyright.

## Inspired By

- [github-bashutils](https://github.com/soulseekah/bash-utils) - soulseekah/bash-utils
- [deanet-gist](https://gist.github.com/deanet/3427090) - Uploading File into Google Drive
- [Bash Bible](https://github.com/dylanaraps/pure-bash-bible) - A collection of pure bash alternatives to external processes

## License

[MIT](https://github.com/labbots/google-drive-upload/blob/master/LICENSE)
