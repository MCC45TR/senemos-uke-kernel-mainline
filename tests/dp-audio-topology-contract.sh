#!/usr/bin/env bash
# Validate the compiled digital-only graph, not merely the source spelling.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
alsatplg -c "$root/src/audio/POCO-Pad-X1-HDMI.conf" -o "$work/hdmi.bin"
alsatplg -d "$work/hdmi.bin" -o "$work/decoded.conf"
sed -n '/^SectionVendorTuples/,$p' "$work/decoded.conf" > "$work/tuples"
test "$(awk '$1=="token200" {print $2}' "$work/tuples" | sort -n)" = $'117444608\n117444611\n117444613\n117444713'
test "$(awk '$1=="token201" {print $2}' "$work/tuples" | sort -nu | wc -l)" -eq 4
awk '$1=="token1" {if($2!=0 && $2!=104) exit 1; n++} END {if(n<4) exit 1}' "$work/tuples"
awk '$1=="token101" {if($2!=184553473) exit 1; n++} END {if(n!=4) exit 1}' "$work/tuples"
test "$(awk '$1=="token206" {print $2}' "$work/tuples" | sort -n)" = $'0\n1\n1\n1'
grep -Fq "stream_name 'DISPLAY_PORT_RX_0 Playback'" "$work/decoded.conf"
grep -Fq "stream_name 'MultiMedia1 Playback'" "$work/decoded.conf"
if grep -E 'Capture|CODEC_DMA|TDM|SoundWire|Speaker' "$work/decoded.conf"; then exit 1; fi
printf 'Compiled DP topology: four allowlisted modules, unique instances, GC containers and DP-only playback passed; host only\n'
