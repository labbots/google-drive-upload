---
title : Sync Script 
description : Sync Script usage and configurable arguments. 
date : 2021-05-10T18:06:06+01:00
lastmod : 2021-05-10T18:06:06+01:00
weight : 2
---

This repo also provides an additional script ( [sync.bash](https://github.com/labbots/google-drive-upload/blob/master/bash/sync.bash) or [sync.sh](https://github.com/labbots/google-drive-upload/blob/master/sh/sync.sh) ) to utilise gupload for synchronisation jobs, i.e background jobs.

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

-   **-d | --directory**

    Specify gdrive folder name, if not specified then local folder name is used.

    ---

-   **-j | --jobs**

    See all background jobs that were started and still running.

    Use -j/--jobs v/verbose to show additional information for jobs.

    Additional information includes: CPU usage & Memory usage and No. of failed & successful uploads.

    ---

-   **-p | --pid**

    Specify a pid number, used for --jobs or --kill or --info flags, multiple usage allowed.

    ---

-   **-i | --info**

    Print information for a specific job. These are the methods to do it:

    -   By specifying local folder and gdrive folder of an existing job,

        e.g: `gsync local_folder -d gdrive folder -i`

    -   By specifying pid number,

        e.g: `gsync -i -p pid_number`

    -   To show info of multiple jobs, use this flag multiple times,

        e.g: `gsync -i pid1 -p pid2 -p pid3`. You can also use it with multiple inputs by adding this flag.

    ---

-   **-k | --kill**

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

-   **-t | --time time_in_seconds**

    The amount of time that sync will wait before checking new files in the local folder given to sync job.

    e.g: `gsync -t 4 local_folder`, here 4 is the wait time.

    To set default time, use `gsync local_folder -t default=4`, it will stored in your default config.

    ---

-   **-l | --logs**

    To show the logs after starting a job or show log of existing job.

    This option can also be used to make a job sync on foreground, rather in background, thus ctrl + c or ctrl +z can exit the job.

    -   By specifying local_folder and gdrive_folder,

        e.g. `gsync local_folder -d gdrive_folder -l`, will show logs of that specific job.

    -   pid ( process id ) number can be used as an additional argument to show logs of a specific job,

        e.g: `gsync -l -p pid_number`.

    Note: If used with multiple inputs or pid numbers, then only first pid/input log is shown, as it goes on indefinitely.

    ---

-   **-a | --arguments**

    As the script uses gupload, you can specify custom flags for background job,

    e.g: `gsync local_folder -a '-q -p 4 -d'`

    To set some arguments by default, use `gsync -a default='-q -p 4 -d'`.

    In this example, will skip existing files, 4 parallel upload in case of folder.

    ---

-   **-fg | --foreground**

    This will run the job in foreground and show the logs.

    Note: A already running job cannot be resumed in foreground, it will just show the existing logs.

    ---

-   **-in | --include 'pattern'**

    Only include the files with the given pattern to upload.

    e.g: gsync local_folder --include "*1*", will only include the files with pattern '1' in the name.\n

    Note: Only provide patterns which are supported by grep, and supported by -E option.

    ---

-   **-ex | --exclude 'pattern'**

    Exclude the files with the given pattern from uploading.

    e.g: gsync local_folder --exclude "*1*", will exclude all the files with pattern '1' in the name.\n

    Note: Only provide patterns which are supported by grep, and supported by -E option.

    ---

-   **-c | --command command_name**

    Incase if gupload command installed with any other name or to use in systemd service, which requires fullpath.

    ---

-   **--sync-detail-dir 'dirname'**

    Directory where a job information will be stored.

    Default: ${HOME}/.google-drive-upload

-   **-s | --service 'service name'**

    To generate systemd service file to setup background jobs on boot.

    Note: If this command is used, then only service files are created, no other work is done.

    ---

-   **-d | --debug**

    Display script command trace, use before all the flags to see maximum script trace.

    ---

***Note:*** Flags that use pid number as input should be used at last, if you are not intending to provide pid number, say in case of a folder name with positive integers.


#### Background Sync Jobs

There are basically two ways to start a background job, first one we already covered in the above section.

It will indefinitely run until and unless the host machine is rebooted.

Now, a systemd service service can also be created which will start sync job after boot.

1.  To generate a systemd unit file, run the sync command with `--service service_name` at the end.

    e.g: If `gsync foldername -d drive_folder --service myservice`, where, myservice can be any name desired.

    This will generate a script and print the next required commands to start/stop/enable/disable the service.

    The commands that will be printed is explained below:

2.  First add the service to the system by `bash "gsync-test.service.sh" add`, where gsync-test is the service name.

3.  Start the service `bash "gsync-test.service.sh" start`.

    This is same as starting a sync job with command itself as mentioned in previous section.

    To stop: `bash "gsync-test.service.sh" stop`

4.  If you want the job to automatically start on boot, run `bash "gsync-test.service.sh" enable`

    To disable: `bash "gsync-test.service.sh" disable`

5.  To see logs after a job has been started.

    `bash "gsync-test.service.sh" logs`

6.  To remove a job from system, `bash "gsync-test.service.sh" remove`

You can use multiple commands at once, e.g: `bash "gsync-test.service.sh" start logs`, will start and show the logs.

***Note:*** To print the systemd service, use `bash "gsync-test.service.sh" print`.

***Note:*** The script is merely a wrapper, it uses `systemctl` to start/stop/enable/disable the service and `journalctl` is used to show the logs.

***Extras:*** A sample service file has been provided in the repo just for reference, it is recommended to use `gsync` to generate the service file.
