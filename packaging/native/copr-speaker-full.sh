#!/usr/bin/env bash
# Retired independent kernel factory. Source assets are integrated by coordinator.
set -Eeuo pipefail
printf '%s\n' \
 'Standalone audio kernel production is retired under cross-chat coordination.' \
 'Use .kernel-coordination/hand-offs/audio.md and the camera coordinator queue.' \
 'Retain the complete qualified cumulative source, config, DT and admission gates.' \
 'Historical composition: commit6f2212c; do not rebuild or install its partial kernel.' >&2
exit 2
