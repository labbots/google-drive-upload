---
title : "Google Drive Upload"
description : "Bash scripts to upload files to google drive."
date : 2021-05-10T18:04:06+01:00
weight : 1
chapter : true
display : true
---

![Google Drive Upload](/images/banner.png?featherlight=false "Google Drive Upload")

Google drive upload is a collection of shell scripts runnable on all POSIX compatible shells ( sh / ksh / dash / bash / zsh / etc ).

It utilizes google drive api v3 and google OAuth2.0 to generate access tokens and to authorize application for uploading files/folders to your google drive.

- Minimal
- Upload or Update files/folders
- Recursive folder uploading
- Sync your folders
- Sync with overwrite or skip existing files support.
- Resume Interrupted Uploads
- Share files/folders to anyone or a specific email.
- Config file support
- Easy to use on multiple operating system.
- Support for multiple accounts in a single config.
- Latest gdrive api used i.e v3
- Pretty logging
- Easy to install and update
  - Self update
  - [Auto update](/setup/update)
  - Can be per-user and invoked per-shell, hence no root access required or global install with root access.
- An additional sync script for background synchronisation jobs. Read [Synchronisation](/usage/sync) section for more info.
