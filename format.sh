#!/usr/bin/env sh

if ! command -v shfmt 2> /dev/null 1>&2; then
    printf 'Install shfmt to format script\n\n'
    printf 'Check https://github.com/mvdan/sh/releases\n'
    exit 1
fi

CURRENT_DIR="$(pwd)"
TEMPFILE="${CURRENT_DIR}/$(date +%s)"

trap 'rm -f "${TEMPFILE}".failedlog "${TEMPFILE}".passedlog' INT TERM EXIT

for k in . sh bash; do
    cd "${k}" 2> /dev/null 1>&2 || exit 1
    for i in *.*sh; do
        if ! shfmt -w "${i}"; then
            printf "%s\n\n" "${k}/${i}: ERROR" >> "${TEMPFILE}".failedlog
        else
            printf "%s\n" "${k}/${i}: SUCCESS" >> "${TEMPFILE}".passedlog
        fi
    done
    cd - 2> /dev/null 1>&2 || exit 1
done

if [ -f "${TEMPFILE}.failedlog" ]; then
    printf '\nError: Cannot format some files.\n\n'
    grep '.*' "${TEMPFILE}".failedlog && printf "\n"
    grep '.*' "${TEMPFILE}".passedlog
    exit 1
else
    printf 'All files formatted successfully.\n\n'
    grep '.*' "${TEMPFILE}".passedlog
    exit 0
fi
