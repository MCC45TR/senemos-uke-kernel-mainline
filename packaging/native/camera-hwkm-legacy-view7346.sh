#!/usr/bin/bash
# Preserve the complete historical helper, canonicalizing only its cache path.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
before=$kernel/hwkm-early/packaging/native/hwkm-early-legacy-view733.sh
printf '%s  %s\n' 843b8a86f469263b76d5e04b3b1acb56bb7efb2bad32e580ffe174f08a4e7adc "$before" | sha256sum -c --strict --quiet - >&2
state=$(realpath "$kernel/native-generated/hwkm-early733")
cache=$(realpath "$kernel/native-generated/camera-full7346")/hwkm-cache
mkdir -p "$cache"
for name in source-complete after.sha256 before;do
 [[ -e $state/$name ]]
 if [[ -L $cache/$name ]];then [[ $(readlink "$cache/$name") == "$state/$name" ]];
 else [[ ! -e $cache/$name ]];ln -s "$state/$name" "$cache/$name";fi
done
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '
 $0=="work=$kernel/native-generated/hwkm-early733"{$0="work=$(realpath \"$kernel/native-generated/camera-full7346/hwkm-cache\")";n++}
 {print}
 END{if(n!=1)exit 1}
' "$before" > "$work/helper.sh"
awk '
 $0=="work=$(realpath \"$kernel/native-generated/camera-full7346/hwkm-cache\")"{$0="work=$kernel/native-generated/hwkm-early733";n++}
 {print}
 END{if(n!=1)exit 1}
' "$work/helper.sh" | cmp - "$before"
bash "$work/helper.sh" "$kernel"
