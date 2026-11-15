#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
[[ $# == 3 ]]
input=$(realpath "$1"); output=$(realpath -m "$2"); contract=$(realpath "$3")
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$contract")" "$input" | sha256sum -c --strict --quiet -
[[ ! -e $output ]]
perl - "$input" "$output" <<'PERL'
use strict; use warnings;
my ($input,$output)=@ARGV;
open my $in,'<',$input or die $!; local $/; my $before=<$in>;close $in;
my $after=$before;my @edits;
sub once {my($a,$b)=@_;die "Ambiguous full27 anchor\n" unless scalar(()=$after=~/\Q$a\E/g)==1;$after=~s/\Q$a\E/$b/;push @edits,[$a,$b];}
once("%global senemos_build_release 27\n","%global senemos_build_release 28\n");
once("Source192: uke-hwkm-early.tar.xz\n","Source192: uke-hwkm-early.tar.xz\nSource193: uke-qtee-information.tar.xz\n");
once("Provides: uke-kernel(hwkm-probe-profile-v1) = 1\n","Provides: uke-kernel(hwkm-probe-profile-v1) = 1\nProvides: uke-kernel(qtee-tpm-information-v1) = 1\n");
once("\n%build\n","\ntar -xJf %{SOURCE193}\n(cd qtee-information; jq -r '.source_assets[]|.sha256+\"  \"+.path' manifests/qtee-information-20261115.json | sha256sum -c --strict --quiet -)\n\n%build\n");
my $anchor='uke_hwkm_parent=$(bash hwkm-early/packaging/native/hwkm-early-legacy-view733.sh "$PWD")'."\n";
my $build='bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base \'%{krel}\' "$jobs"'."\n";
once($anchor.$build,$anchor.'bash qtee-information/packaging/native/prepare-qtee-information733.sh "$PWD" %{_uke_out} source'."\n".$build);
for my $phase ('linked','sealed') {
 my $line='bash hwkm-early/packaging/native/prepare-hwkm-early733.sh "$PWD" %{_uke_out} '.$phase."\n";
 once($line,$line.'bash qtee-information/packaging/native/prepare-qtee-information733.sh "$PWD" %{_uke_out} '.$phase."\n");
}
for my $phase ('install','check') {
 my $line='bash hwkm-early/packaging/native/prepare-hwkm-early733.sh "$PWD" %{_uke_out} '.$phase.' \'%{buildroot}\'' ."\n";
 once($line,$line.'bash qtee-information/packaging/native/prepare-qtee-information733.sh "$PWD" %{_uke_out} '.$phase.' \'%{buildroot}\'' ."\n");
}
once("%changelog\n","%changelog\n* Sun Nov 15 2026 Uke contributors - 7.3.3-28\n- Add explicit once-only kernel QTEE TPM metadata discovery; preserve full27 features.\n- Keep user ioctl restrictions, no TPM startup, no automatic firmware request.\n\n");
my $inverse=$after;
for my $e(reverse @edits){my($a,$b)=@$e;die "Ambiguous inverse\n" unless scalar(()=$inverse=~/\Q$b\E/g)==1;$inverse=~s/\Q$b\E/$a/;}
die "Unrelated full27 recipe changed\n" unless $inverse eq $before;
for my $section(qw(prep build check install changelog)){die "Duplicate section\n" unless scalar(()=$after=~/^%\Q$section\E$/mg)==1;}
open my $out,'>',$output or die $!;print {$out} $after;close $out;
PERL
printf 'Full28 recipe whole-file inverse passed; all parent full27 statements retained\n'
