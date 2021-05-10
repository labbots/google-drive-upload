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
