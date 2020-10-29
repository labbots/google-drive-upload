#!/usr/bin/env sh

set -e

command -v shfmt 1>| /dev/null && ./format.sh && printf "\n"

_merge() (
    shell="${1:?Error: give folder name.}"

    cd "${shell}" 2>| /dev/null 1>&2 || exit 1
    mkdir -p release

    for file in upload sync; do
        {
            sed -n 1p "${file}.${shell}"
            printf "%s\n" "SELF_SOURCE=\"true\""
            sed 1d common-utils."${shell}"
            [ "${file}" = upload ] && sed 1d drive-utils."${shell}" && sed 1d upload-utils."${shell}"
            sed 1d "${file}.${shell}"
        } >| "release/g${file}"
        chmod +x "release/g${file}"
    done

    printf "%s\n" "${shell} done."
)

_merge sh
_merge bash
