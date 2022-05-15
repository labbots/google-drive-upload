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
<p align="center">
<a href="https://plant.treeware.earth/labbots/google-drive-upload"><img alt="Buy us a tree" src="https://img.shields.io/treeware/trees/labbots/google-drive-upload?color=green&label=Buy%20us%20a%20Tree%20%F0%9F%8C%B3&style=for-the-badge"></a>
</p>
<p align="center">
<img src="https://labbots.github.io/google-drive-upload/images/banner.png" height="150"/>
</p>

Google drive upload is a collection of shell scripts runnable on all POSIX compatible shells ( sh / ksh / dash / bash / zsh / etc ).

It utilizes google drive api v3 and google OAuth2.0 to generate access tokens and to authorize application for uploading files/folders to your google drive.

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
  - Support for multiple accounts in a single config.
- Latest gdrive api used i.e v3
- Pretty logging
- Easy to install and update
  - Self update
  - [Auto update](https://labbots.github.io/google-drive-upload/setup/update/)
  - Can be per-user and invoked per-shell, hence no root access required or global install with root access.
- An additional sync script for background synchronisation jobs. Read [Synchronisation](https://labbots.github.io/google-drive-upload/usage/sync/) section for more info.



## Table of Contents

- [Documentation](#documentation)
- [Reporting Issues](#reporting-issues)
- [Contributing](#contributing)
- [Inspired By](#inspired-by)
- [License](#license)
- [Treeware](#treeware)

## Documentation

Installation and Usage documentation is available at [https://labbots.github.io/google-drive-upload/](https://labbots.github.io/google-drive-upload/)

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
