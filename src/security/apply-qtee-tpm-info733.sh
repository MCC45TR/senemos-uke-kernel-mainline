#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); layer=$(realpath "$2")
target=$kernel/drivers/tee/qcomtee
[[ -d $target && ! -e $target/qtee-tpm-info.c ]]
printf '%s  %s\n' 5e0074ab8be6cb9e5595bb73b805b202686fd6f7b89f70ca719da5dc1babf33f "$target/call.c" | sha256sum -c --strict --quiet -
[[ $(git hash-object "$target/Makefile") == 7c466c9f32af372b88d1755c18a4f4ce946b7518 ]]
perl - "$target/call.c" <<'PERL'
use strict; use warnings;
my $path = shift; open my $in, '<', $path or die $!; local $/; my $before = <$in>; close $in;
my $after = $before; my @edits;
sub once {
 my ($a, $b) = @_;
 die "Ambiguous QTEE source anchor\n" unless scalar(() = $after =~ /\Q$a\E/g) == 1;
 $after =~ s/\Q$a\E/$b/; push @edits, [$a, $b];
}
once("#include \"qcomtee.h\"\n", "#include \"qcomtee.h\"\n#include \"qtee-tpm-info.h\"\n");
once("\t\tQTEE_VERSION_GET_PATCH(qcomtee->qtee_version));\n\n\treturn 0;\n",
     "\t\tQTEE_VERSION_GET_PATCH(qcomtee->qtee_version));\n\n\tuke_qtee_tpm_info_attach(qcomtee);\n\treturn 0;\n");
once("\tstruct qcomtee *qcomtee = platform_get_drvdata(pdev);\n\n\tteedev_close_context(qcomtee->ctx);",
     "\tstruct qcomtee *qcomtee = platform_get_drvdata(pdev);\n\n\tuke_qtee_tpm_info_detach(qcomtee);\n\tteedev_close_context(qcomtee->ctx);");
my $inverse = $after;
for my $edit (reverse @edits) { my ($a, $b) = @$edit; die "Ambiguous inverse\n" unless scalar(() = $inverse =~ /\Q$b\E/g) == 1; $inverse =~ s/\Q$b\E/$a/; }
die "Unrelated QTEE source changed\n" unless $inverse eq $before;
open my $out, '>', $path or die $!; print {$out} $after; close $out;
PERL
printf 'qcomtee-objs += qtee-tpm-info.o\n' >> "$target/Makefile"
for file in qtee-tpm-info.c qtee-tpm-info.h qtee-tpm-info-core.h; do
 install -m644 "$layer/src/security/$file" "$target/$file"
done
printf 'QTEE source whole-file inverse passed; userspace root-object restriction unchanged\n'
