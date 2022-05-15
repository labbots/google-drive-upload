#!/usr/bin/env sh

# shfmt - beautify scripts
if command -v shfmt 1>| /dev/null; then
    printf "Beautifying scripts with shfmt... \n"
    for k in . src/common src/sh src/bash; do
        cd "${k}" 2>| /dev/null 1>&2 || exit 1
        for i in *.*sh; do
            if ! shfmt -w "${i}"; then
                printf "%s\n\n" "${k}/${i}: ERROR"
                format_status=1
            else
                printf "%s\n" "${k}/${i}: SUCCESS"
            fi
        done
        cd - 2>| /dev/null 1>&2 || exit 1
    done
    format_status="${format_status:-0}"
    printf "\n"
else
    printf 'Install shfmt to format script\n\n'
    printf 'Check https://github.com/mvdan/sh/releases\n\n'
fi

# shell check - lint script
if command -v shellcheck 1>| /dev/null; then
    printf "Linting scripts with shellcheck... \n"
    for k in . src/common src/sh src/bash; do
        cd "${k}" 2>| /dev/null 1>&2 || exit 1
        for i in *.*sh; do
            if ! shellcheck -o all -e SC2312 "${i}"; then
                printf "\n%s\n\n" "${k}/${i}: ERROR"
                lint_status=1
            else
                printf "%s\n" "${k}/${i}: SUCCESS"
            fi
        done
        cd - 2>| /dev/null 1>&2 || exit 1
    done
    lint_status="${lint_status:-0}"
    printf "\n"
else
    printf 'Install shellcheck to lint script.\n'
    printf 'Check https://www.shellcheck.net/ or https://github.com/koalaman/shellcheck\n\n'
fi

[ "${format_status}" = 1 ] &&
    printf "Error: Some files not formatted succesfully.\n"

[ "${lint_status}" = 1 ] &&
    printf "Error: Some shellcheck warnings need to be fixed.\n"

if [ "${lint_status}" = 1 ] || [ "${format_status}" = 1 ]; then
    exit 1
else
    exit 0
fi
