---
title : Update 
description : Method to update gupload. 
date : 2021-05-10T18:06:06+01:00
lastmod : 2021-05-10T18:06:06+01:00
weight : 3
---
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
