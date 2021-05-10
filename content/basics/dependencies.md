---
title: "Dependencies"
date: 2021-05-10T18:04:06+01:00
---

This repo contains two types of scripts, posix compatible and bash compatible.

<strong>These programs are required in both bash and posix scripts.</strong>

| Program          | Role In Script                                         |
| ---------------- | ------------------------------------------------------ |
| curl             | All network requests                                   |
| file or mimetype | Mimetype generation for extension less files           |
| find             | To find files and folders for recursive folder uploads |
| xargs            | For parallel uploading                                 |
| mkdir            | To create folders                                      |
| rm               | To remove files and folders                            |
| grep             | Miscellaneous                                          |
| sed              | Miscellaneous                                          |
| mktemp           | To generate temporary files ( optional )               |
| sleep            | Self explanatory                                       |
| ps               | To manage different processes                          |

<strong>If BASH is not available or BASH is available but version is less tham 4.x, then below programs are also required:</strong>

| Program             | Role In Script                             |
| ------------------- | ------------------------------------------ |
| awk                 | For url encoding in doing api requests     |
| date                | For installation, update and Miscellaneous |
| cat                 | Miscellaneous                              |
| stty or zsh or tput | To determine column size ( optional )      |

<strong>These are the additional programs needed for synchronisation script:</strong>

| Program       | Role In Script            |
| ------------- | ------------------------- |
| tail          | To show indefinite logs   |
