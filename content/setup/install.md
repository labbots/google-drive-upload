---
title : Installation 
description : Installation procedure to setup gupload script. 
date : 2021-05-10T18:06:06+01:00
lastmod : 2021-05-10T18:06:06+01:00
weight : 1
---
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

-   **-p | --path <dir_name>**

    Custom path where you want to install the script.

    Note: For global installs, give path outside of the home dir like /usr/bin and it must be in the executable path already.

    ---

-   **-c | --cmd <command_name>**

    Custom command name, after installation, script will be available as the input argument.

    To change sync command name, use install sh -c gupload sync='gsync'

    ---

-   **-r | --repo <Username/reponame>**

    Install script from your custom repo, e.g --repo labbots/google-drive-upload, make sure your repo file structure is same as official repo.

    ---

-   **-B | --branch <branch_name>**

    Specify branch name for the github repo, applies to custom and default repo both.

    ---

-   **-R | --release <tag/release_tag>**

    Specify tag name for the github repo, applies to custom and default repo both.

    ---

-   **-t | --time 'no of days'**

    Specify custom auto update time ( given input will taken as number of days ) after which script will try to automatically update itself.

    Default: 5 ( 5 days )

    ---

-   **-s | --shell-rc <shell_file>**

    Specify custom rc file, where PATH is appended, by default script detects .zshrc, .bashrc. and .profile.

    ---

-   **--sh | --posix**

    Force install posix scripts even if system has compatible bash binary present.

    ---

-   **-q | --quiet**

    Only show critical error/sucess logs.

    ---

-   **-U | --uninstall**

    Uninstall the script and remove related files.\n

    ---

-   **-D | --debug**

    Display script command trace.

    ---

-   **-h | --help**

    Display usage instructions.

    ---

Now, run the script and use flags according to your usecase.

E.g:

```shell
curl --compressed -Ls https://github.com/labbots/google-drive-upload/raw/master/install.sh | sh -s -- -r username/reponame -p somepath -s shell_file -c command_name -B branch_name
```
