#!/usr/bin/bash
# Retain the Uke PAN queue while carrying the signed stable freezer fix.
set -Eeuo pipefail
[[ $# == 2 && -f $1 && ! -e $2 && ! -L $2 ]]
input=$(realpath "$1"); output=$(realpath -m "$2")
printf '%s  %s\n' a56b1b532137ec081e1bb46e6ee25cbcb40341599f62ca8570e9e931832c1c2d "$input" | sha256sum -c --strict --quiet -
awk '
 $0=="-\tschedule_work(&alt_port->work);" {$0="-\tqueue_work(system_freezable_wq, &alt_port->work);";removed++}
 $0=="+\t\tschedule_work(&port->work);" {$0="+\t\tqueue_work(system_freezable_wq, &port->work);";queued++}
 $0=="+\t\t\t\t\tschedule_work(&am->ports[i].work);" {$0="+\t\t\t\t\tqueue_work(system_freezable_wq, &am->ports[i].work);";lost++}
 {print} END {if(removed!=2||queued!=1||lost!=1)exit 1}
' "$input" > "$output"
printf '%s  %s\n' 0b3f7f46f612604ed01eb43f9ec6663eaa14e8c8efcf6f82ccdb8daa56053337 "$output" | sha256sum -c --strict --quiet -
awk '
 $0=="-\tqueue_work(system_freezable_wq, &alt_port->work);" {$0="-\tschedule_work(&alt_port->work);";removed++}
 $0=="+\t\tqueue_work(system_freezable_wq, &port->work);" {$0="+\t\tschedule_work(&port->work);";queued++}
 $0=="+\t\t\t\t\tqueue_work(system_freezable_wq, &am->ports[i].work);" {$0="+\t\t\t\t\tschedule_work(&am->ports[i].work);";lost++}
 {print} END {if(removed!=2||queued!=1||lost!=1)exit 1}
' "$output" | cmp - "$input"
printf 'PAN patch: exact four-line inverse, stable freezable event/loss queue and original ownership controls retained.\n'
