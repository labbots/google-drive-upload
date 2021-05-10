---
title : Initial Setup 
description : Initial setup guide. 
date : 2021-05-10T18:06:06+01:00
lastmod : 2021-05-10T18:06:06+01:00
weight : 2
---
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
