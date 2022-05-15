#!/usr/bin/env sh

set -e

sh format_and_lint.sh

printf "Merging Scripts and minifying...\n"

_PARENT_DIR="${PWD}"

cd src || exit 1

_merge() (
    shell="${1:?Error: give folder name.}"
    { [ "${shell}" = "sh" ] && flag="-p"; } || flag=""

    mkdir -p "${_PARENT_DIR}/release/${shell}"
    release_path="${_PARENT_DIR}/release/${shell}"

    # gupload
    {
        sed -n 1p "upload.${shell}"
        printf "%s\n" 'SELF_SOURCE="true"'
        # shellcheck disable=SC2086
        {
            # this is to export the functions so that can used in parallel functions
            echo 'set -a'
            sed 1d "${shell}/common-utils.${shell}"
            for script in \
                update.sh \
                parser.sh \
                upload-flags.sh \
                auth-utils.sh \
                common-utils.sh \
                drive-utils.sh \
                upload-utils.sh \
                upload-common.sh; do
                sed 1d "common/${script}"
            done
            echo 'set +a'
            sed 1d "upload.${shell}"
        } | shfmt -mn ${flag}
    } >| "${release_path}/gupload"
    chmod +x "${release_path}/gupload"

    printf "%s\n" "${release_path}/gupload done."

    # gsync
    {
        sed -n 1p "sync.${shell}"
        printf "%s\n" 'SELF_SOURCE="true"'
        # shellcheck disable=SC2086
        {
            # this is to export the functions so that can used in parallel functions
            echo 'set -a'
            sed 1d "${shell}/common-utils.${shell}"
            for script in \
                parser.sh \
                sync-flags.sh \
                common-utils.sh; do
                sed 1d "common/${script}"
            done
            echo 'set +a'
            sed 1d "sync.${shell}"
        } | shfmt -mn ${flag}
    } >| "${release_path}/gsync"
    chmod +x "${release_path}/gsync"

    printf "%s\n" "${release_path}/gsync done."
)

_merge sh
_merge bash
