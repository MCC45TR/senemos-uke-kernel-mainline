# Camera controller power prerequisite

21 October 2026, Linux 7.2.11 development source. These two inactive patches
address GDSC error propagation and controller runtime-PM references. They do
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

The native provider must still implement its rail/interface-clock callbacks,
forced-suspend refusal and failed-probe resource lifetime. Existing common
GDSC registration/unregistration does not establish that lifetime: a PM
usage reference alone cannot retain devres or driver callbacks after a
failed probe. Registration failure, partial publication, domain removal and
shutdown remain unqualified. Do not activate this flag or publish a provider
until those paths are implemented and tested. The Source4 inventory carries
the patches for review only; no kernel or tablet payload is produced here.
