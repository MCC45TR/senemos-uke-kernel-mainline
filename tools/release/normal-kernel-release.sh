#!/usr/bin/bash
set -Eeuo pipefail
export LC_ALL=C

if [[ $# != 3 ]]; then
    printf 'Usage: %s LINUX_ARCHIVE PREVIOUS_RPM_VERSION PREVIOUS_RPM_RELEASE\n' "${0##*/}" >&2
    exit 2
fi

archive=$1
previous_version=$2
previous_release=$3
version_pattern='^[1-9][0-9]{0,8}\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$'
[[ $previous_version =~ $version_pattern ]]
[[ $previous_release =~ ^([1-9][0-9]{0,8})(\.fc[0-9]+)?$ ]]
previous_revision=${BASH_REMATCH[1]}

# Read the release from the same source archive that COPR will compile.
makefile=$(tar --extract --xz --to-stdout --wildcards --no-wildcards-match-slash \
    --file "$archive" 'linux-*/Makefile')
version=$(awk -F '=' '
    /^[[:space:]]*(VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION)[[:space:]]*=/ {
        key = $1
        value = $2
        gsub(/[[:space:]]/, "", key)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        if (NF != 2 || key in values)
            bad = 1
        values[key] = value
    }
    END {
        if (bad || !("VERSION" in values) || !("PATCHLEVEL" in values) ||
            !("SUBLEVEL" in values) || !("EXTRAVERSION" in values) || values["EXTRAVERSION"] != "")
            exit 1
        print values["VERSION"] "." values["PATCHLEVEL"] "." values["SUBLEVEL"]
    }' <<< "$makefile")
[[ $version =~ $version_pattern ]]

comparison=$(rpm --eval "%{lua:print(rpm.vercmp('$version', '$previous_version'))}")
case $comparison in
    1) revision=1 ;;
    0) revision=$((previous_revision + 1)) ;;
    -1) printf 'Linux %s precedes the published %s.\n' "$version" "$previous_version" >&2; exit 2 ;;
    *) exit 2 ;;
esac
(( revision <= 999999999 ))
printf '%s\t%s\t%s-%s\n' "$version" "$revision" "$version" "$revision"
