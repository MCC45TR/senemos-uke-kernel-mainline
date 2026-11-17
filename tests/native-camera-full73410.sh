#!/usr/bin/bash
# Reuse the exact signed source33 qualification after the historical full9 gate.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");layer=$(realpath "$3");proof=$(realpath "$4")
qualified=$layer/front-stage734
(cd "$qualified";sha256sum -c --strict --quiet SHA256SUMS)
cmp "$qualified/SHA256SUMS" "$proof/SHA256SUMS"
cmp "$qualified/source-commit" "$proof/source-commit"
for file in apply.sh pre.sha256 post.sha256 activation.patch;do
 cmp "$qualified/src/camera/front-eeprom734/$file" "$kernel/camera-full7349/src/camera/front-eeprom734/$file"
done
# Source33 starts from the exact source32 caller. Undo only the completed
# historical full9 activation, then run the unchanged qualified 33 script.
(cd "$kernel";sha256sum -c --strict --quiet "$qualified/src/camera/front-stage734/pre.sha256")
patch --batch --fuzz=0 --reverse -d "$kernel" -p1 < "$qualified/src/camera/front-eeprom734/activation.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$qualified/src/camera/front-eeprom734/pre.sha256")
bash "$qualified/tests/native-front-stage734.sh" "$kernel" "$out" "$qualified" "$kernel/front-stage734-result"
cmp "$proof/source.sha256" "$kernel/front-stage734-result/source.sha256"
cmp "$proof/qualification.json" "$kernel/front-stage734-result/qualification.json"
bash "$layer/tests/front-observed734-contract.sh" "$kernel" "$layer" "$kernel/front-observed734-result"
bash "$layer/seal-camera-full73410.sh" "$kernel"
