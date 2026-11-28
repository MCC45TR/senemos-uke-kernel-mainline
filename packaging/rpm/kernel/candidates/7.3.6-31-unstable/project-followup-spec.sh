#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C

if [[ $# != 3 ]]; then
    printf '%s\n' "Usage: $0 PARENT_SPEC RELIABILITY_ARCHIVE SOURCE_INDEX" >&2
    exit 2
fi
parent=$1
archive=$2
source=$3
[[ $source =~ ^[1-9][0-9]{2,3}$ && $source -ge 492 ]]
[[ ${archive##*/} == uke-post31-reliability-followups.tar.xz ]]
digest=$(sha256sum -- "$archive")
digest=${digest%% *}
output=$(mktemp)
trap 'rm -f -- "$output"' EXIT

awk -v source="$source" -v digest="$digest" -v archive="${archive##*/}" '
    BEGIN {
        collision = "^source0*" source "[ \t]*:"
        continuation = " " sprintf("%c", 92)
    }
    tolower($0) ~ collision {
        print "Source" source " is already assigned" > "/dev/stderr"
        invalid = 1
        exit 1
    }
    /^%global uke_reliability_followup_dir / {
        print "reliability source is already present" > "/dev/stderr"
        invalid = 1
        exit 1
    }
    /^bash "\$runtime_736_assets\/build-with-runtime-layer\.sh" / {
        print "late_followups=$PWD/%{uke_reliability_followup_dir}"
        print "echo " digest " \"%{SOURCE" source "}\" | sha256sum -c --strict"
        print "mkdir \"$late_followups\""
        print "tar -xJf %{SOURCE" source "} -C \"$late_followups\""
        print "(cd \"$late_followups\"; sha256sum --strict -c SHA256SUMS)"
        extract++
    }
    { print }
    /^%global uke_dock_followup_dir / {
        print "%global uke_reliability_followup_dir native-generated/uke-post31-reliability"
        macro++
    }
    /^Source491: uke-dock-journal-followups\.tar\.xz$/ {
        print "Source" source ": " archive
        member++
    }
    /^ *bash "\$dock_followup\/build-with-dock-followups\.sh" .*\\$/ {
        print "        bash \"$late_followups/build-with-five-followups.sh\" \"$PWD\" \"$late_followups\"" continuation
        apply++
    }
    /^bash "\$dock_followup\/check-runtime-objects\.sh" / {
        print "mkdir -p %{_uke_out}/uke-post31-reliability"
        print "bash \"$late_followups/check-built-objects.sh\" %{_uke_out} \"$late_followups\"" continuation
        print "    > %{_uke_out}/uke-post31-reliability/candidate-objects.sha256"
        verify++
    }
    /^install -Dm644 %{_uke_out}\/uke-dock-followups\/candidate-objects\.sha256 / {
        print "install -Dm644 \"%{uke_reliability_followup_dir}/postimages.sha256\" \"$identity/post31-reliability-source.sha256\""
        print "install -Dm644 \"%{uke_reliability_followup_dir}/qualified-features.tsv\" \"$identity/post31-reliability-features.tsv\""
        print "install -Dm644 %{_uke_out}/uke-post31-reliability/candidate-objects.sha256 \"$identity/post31-reliability-objects.sha256\""
        receipts++
    }
    END {
        if (invalid)
            exit 1
        if (macro != 1 || member != 1 || extract != 1 || apply != 1 || verify != 1 || receipts != 1) {
            print "expected exactly one anchor for each reliability insertion" > "/dev/stderr"
            exit 1
        }
    }
' "$parent" > "$output"
cat -- "$output"
