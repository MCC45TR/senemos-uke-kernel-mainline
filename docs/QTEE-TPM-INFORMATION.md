# Explicit kernel QTEE TPM information candidate

15 November 2026. Source preparation only. No new full kernel is reserved,
installed or booted. The fitted tablet remains on accepted kernel27; the
userspace diagnostic16 registered ordinary credentials but UID81 open returned
remote11 before either information query. That is not proof of TPM absence.

## Existing kernel contract

Linux v7.3.3 has no `tee_client_object_invoke_func()` in its public kernel TEE
API. Qualcomm's [TPM v4 series][tpm] depends on additional UEFI/QTEE patches
and automatically starts the TPM when registered. The shared service protocol
was tested on Glymur-crd, not Uke. This candidate neither imports that full
driver nor registers a TPM chip.

The existing [QTEE core][core] already obtains a privileged kernel environment
with a NULL credential and operation5 for its own firmware-version query.
The candidate uses that same internal invocation contract. The separate
userspace `qcomtee_root_object_check()` stays byte-for-byte unchanged.
Only the UID81 lookup and two fixed vendor information commands are exposed:
version0x1000 and type0x80000, each at locality0 with a four-byte input and an
exactly twelve-byte response. No arbitrary service, command or buffer is
accepted. There is no TPM2 Startup, Clear, PCR, NV, sealing, transfer, TA loader,
firmware update or key operation.

## Lifecycle and candidate interface

The unchanged provider owns its private context. The additional information
code attaches only on `xiaomi,uke` plus `qcom,sm7675` and refuses ambiguous
providers. It issues no request on module load, probe or cached-result reads.
Its root-only module parameter `qcomtee.uke_tpm_information` accepts exactly
`1`, after successful provider probe, once during the module lifetime. Invalid
input, missing CAP_SYS_ADMIN or an unavailable/ambiguous provider is refused.
No boot argument or initramfs option activates it.

One lifecycle mutex protects the borrowed provider context through invocation
and serializes teardown. A separate short result mutex allows cached reads
while the transport is busy. Provider removal clears availability before
closing the original context. Every acquired environment/service reference
and invocation allocation is released on success or failure. Local reference
release is not a remote TA teardown attestation. A request is marked before
invocation and never automatically retried, including uncertain failures.

The existing synchronous QTEE transport supplies no new hard wall-clock
deadline. The candidate bounds the request set and count; it does not claim
to cancel an in-flight secure monitor call. A busy request must not be retried
or followed by forced provider removal. There is no worker, polling loop,
timer or persistent file added by this diagnostic.

The cached report contains only request/busy/provider state, fixed stage and
type enums, transport/remote status, version and attempt counts. No key,
identity or private buffer is returned. Stages are unrequested0/context1/
environment2/service3/version4/type5/done6. Kinds are unknown0/fTPM1/dTPM2/
None3. Only done6 with valid status and a known type completes information
discovery; even that establishes no measured-boot or sealing policy.

## Qualification and delivery

The native candidate114 derives from the actual qualified full27 SRPM, not an
older generic profile. It retains all inherited sources, configuration and
source guards, changes only the four tuple fields and adds two diagnostic
composition fields. The full28 recipe must have an exact whole-file inverse
against full27. Actual full28 is still unreserved.

COPR will test the same production protocol core with transport doubles:
all three types,23 refusals, object ownership, error outputs, stale-reply
clearing and no automatic retries in GCC/Clang plain and sanitizer modes.
It will also compile the actual QTEE call/core/information AArch64 objects
with `-Werror`. No native source-check package is installed or firmware called.
Only after this qualification can the coordinator reserve the next cumulative
full kernel, audit signed outputs, deliver through DNF and request an actual
device test. Signed runtime modules remain in the existing kernel package.

Production release, OEM-to-Linux trust, hardware data I/O, conversion and
protected hibernate remain separate requirements. The information parameter
does not admit a boot role or grant storage-key authority.

[core]: https://github.com/gregkh/linux/blob/v7.3.3/drivers/tee/qcomtee/core.c
[tpm]: https://lore-kernel.gnuweeb.org/linux-integrity/20261019-tpm_qcom_driver-v4-2-6889b9804ba7@oss.qualcomm.com/
