#!/usr/bin/bash
# Late source layer only. Keep the complete already-prepared root parser intact.
set -Eeuo pipefail
[[ $# == 2 ]]
kernel=$(realpath "$1");result=$(realpath -m "$2")
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ -f $kernel/Makefile && ! -e $result && ! -L $result ]]
arch=$kernel/arch/arm64/kernel
[[ -f $arch/uke-root-selector.h && ! -L $arch/uke-root-selector.h &&
   -f $arch/uke-abl.c && ! -L $arch/uke-abl.c &&
   ! -e $arch/uke-super-root-selector.h && ! -L $arch/uke-super-root-selector.h ]]
mkdir "$result"
cp "$arch/uke-root-selector.h" "$result/parent-root-selector.h"
cp "$arch/uke-abl.c" "$result/parent-uke-abl.c"
awk '
 $0=="#include \"uke-root-selector.h\""{$0="#include \"uke-super-root-selector.h\"";n++}
 {print}END{if(n!=1)exit 1}
' "$arch/uke-abl.c" > "$result/uke-abl.c"
awk '
 $0=="#include \"uke-super-root-selector.h\""{$0="#include \"uke-root-selector.h\"";n++}
 {print}END{if(n!=1)exit 1}
' "$result/uke-abl.c" | cmp - "$arch/uke-abl.c"
install -m644 "$here/uke-super-root-selector.h" "$arch/uke-super-root-selector.h"
install -m644 "$result/uke-abl.c" "$arch/uke-abl.c"
cmp "$result/parent-root-selector.h" "$arch/uke-root-selector.h"
(cd "$kernel";sha256sum arch/arm64/kernel/{uke-root-selector.h,uke-super-root-selector.h,uke-abl.c,setup.c}) > "$result/source.sha256"
printf 'Prepared root parser retained byte-for-byte; only its original include site now selects the bounded role wrapper.\n'
