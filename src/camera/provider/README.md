# Camera controller power prerequisite

23 October 2026, Linux 7.2.11 development source. These three inactive patches
address GDSC errors, controller runtime-PM references and registration cleanup. They do
not register a camera controller, change the clock catalog or enable a DT node.

The first patch preserves a failed collapse-write errno before status polling
or the votable fast path can replace it. Resources remain held after an
ambiguous transition; generic regulator/ICC retry accounting is not changed.

The second adds an explicit opt-in for permanent built-in controllers with
runtime PM and no user unbind interface. It accepts only software-controlled
OFF/ON domains without separate regulator, ICC, reset or memory-branch
ownership. This covers the shape of the eight SM7675 catalog entries; none
opts in yet. Existing domains make no new controller-PM calls.

An opted-in callback resumes the controller before MMIO, holds one reference
through ON and failed transitions, and releases it after a successful OFF
poll. Boot-ON initialization retains ownership; successful boot-OFF
initialization releases it. Retain-FF writes also propagate errors. An
inactive controller with an outstanding reference refuses MMIO. This guard
does not prevent forced suspend from removing power.

The host fixture imports the actual patched functions and header. It checks
normal cycles, resume/write/read/timeout errors, boot-state initialization,
unsupported contracts and eight independent owners of one model controller.
The kernel object check compiles the full patched `gdsc.c` for AArch64.

```bash
make test-camcc-power camcc_source=/path/to/linux-7.2.11 camcc_output=/path/to/prepared-arm64-output
```

The [power callback candidate](camcc-sm7675-power.h) uses the existing voltage
aggregator and exact OEM `vdd_mm`, `vdd_mx`, `vdd_mxc` and `iface` names. All
three supplies are required; absent providers cannot become dummy regulators.
One tracked MIN vote per class precedes interface-clock enable. Clean clock
enable failure unwinds those votes; any ambiguous voltage operation latches
a fault, records both primary and observed rollback errors, and stops retries.
An independent higher voltage vote survives removal of the controller vote.

Normal and forced suspend refuse active runtime users, children or any held
GDSC before changing resources. The checked regmap callbacks also refuse
unpowered, faulted, unaligned or out-of-range access. This gate is necessary
because forced suspend calls the driver directly and does not itself record
the callback error in the normal runtime error path. The native producer must
use `cam_cc_power_regmap_config` with a NULL regmap bus and `cam_cc_power` as
context, rather than the unguarded catalog format. Both const configurations
share the same format initializer.

```bash
make test-camcc-provider camcc_source=/path/to/linux-7.2.11 camcc_output=/path/to/prepared-arm64-output
```

The host test imports the real voltage aggregator and forced-suspend/resume
functions. The AArch64 fixture combines the complete clock catalog, patched
GDSC layout, power callbacks and regmap constructor. These checks measure API
ownership and modeled faults, not electrical rail state or system sleep on Uke.

The registration cleanup removes initialized genpds after a later domain,
parent-link or provider-registration failure. The fault fixture imports the
complete patched GDSC file and covers sparse domain arrays, both allocation
failures, each initialization/link failure, provider failure and normal removal.
Explicit parents, the controller parent and multi-parent attachment lists are
checked separately. The unpatched candidate reproduces leaked registrations.
The initialized-domain unwind follows the 14 October Qualcomm required-domain
RFC; its separate DVFS infrastructure is not imported.

This cleans up genpd objects, not the controller's power ownership. Boot-ON or
ambiguous GDSC transitions can still retain controller references after cleanup;
the future provider must retain its resources and callbacks for that state.

The native provider must still integrate the callbacks, GDSC opt-in, safe
firmware/proxy handoff, per-clock voltage operations and failed-probe lifetime.
Common GDSC registration/unregistration does not establish that lifetime: a PM
usage reference alone cannot retain devres or driver callbacks after a
failed probe. Registration failure, partial publication, domain removal and
shutdown remain unqualified. Clock prepare paths must also reject a latched
fault before trusting a cached active PM state. Do not activate this flag or
publish a provider
until those paths are implemented and tested. The Source4 inventory carries
the patches for review only; no kernel or tablet payload is produced here.
