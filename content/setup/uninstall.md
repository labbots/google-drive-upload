---
title : Uninstallation 
description : Uninstallation procedure for gupload. 
date : 2021-05-10T18:06:06+01:00
lastmod : 2021-05-10T18:06:06+01:00
weight : 5
---

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
