---
title : Configuration 
description : Configuration file of gupload. 
date : 2021-05-10T18:06:06+01:00
lastmod : 2021-05-10T18:06:06+01:00
weight : 4
---

After first run, the credentials are saved in config file. By default, the config file is `${HOME}/.googledrive.conf`.

To change the default config file or use a different one temporarily, see `-z / --config` custom in [Upload Script Custom Flags](#upload-script-custom-flags).

This is the format of a config file:

```shell
ACCOUNT_default_CLIENT_ID="client id"
ACCOUNT_default_CLIENT_SECRET="client secret"
ACCOUNT_default_REFRESH_TOKEN="refresh token"
SYNC_DEFAULT_ARGS="default args of gupload command for gsync"
ACCOUNT_default_ROOT_FOLDER_NAME="root folder name"
ACCOUNT_default_ROOT_FOLDER="root folder id"
ACCOUNT_default_ACCESS_TOKEN="access token"
ACCOUNT_default_ACCESS_TOKEN_EXPIRY="access token expiry"
```

where **default** is the name of the account.

You can use a config file in multiple machines, the values that are explicitly required are **CLIENT_ID**, **CLIENT_SECRET** and **REFRESH_TOKEN**.

If **ROOT_FOLDER** is not set, then it is asked if running in an interactive terminal, otherwise **root** is used.

**ROOT_FOLDER_NAME**, **ACCESS_TOKEN** and **ACCESS_TOKEN_EXPIRY** are automatically generated using **REFRESH_TOKEN**.

**SYNC_DEFAULT_ARGS** is optional.

A pre-generated config file can be also used where interactive terminal access is not possible, like Continuous Integration, docker, jenkins, etc

Just have to print values to `"${HOME}/.googledrive.conf"`, e.g:

```shell
printf "%s\n" '
ACCOUNT_default_CLIENT_ID="client id"
ACCOUNT_default_CLIENT_SECRET="client secret"
ACCOUNT_default_REFRESH_TOKEN="refresh token"
' >| "${HOME}/.googledrive.conf"
```

Note: If you have an old config, then nothing extra is needed, just need to run the script once and the default config will be automatically converted to the new format.
