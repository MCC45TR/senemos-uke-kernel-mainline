# Userdata filesystem expansion

Date: 22 October 2026. Scope: shared source design and host contracts.
Physical expansion under this kernel variant is not yet accepted.

The root-selector v2 ABI admits explicit F2FS, EXT4, XFS or single-device Btrfs
userdata. For F2FS, the first capable boot checks the unmounted filesystem and
expands it before `sysroot.mount`.
The actual block count is its persistent completion record. Subsequent boots
perform only a small read-only size check and skip fsck and resize. A completed
oneshot remains active in the initrd, so a second mount dependency cannot
restart it against an already mounted root. Invalid identity or geometry fails
admission. Neither formatting nor partition-table changes belong here.

The packaged updater checks power before staging a new boot image. Keep USB
power and adequate battery available when installing or flashing an image.
Battery RPC depends on DSP firmware from the real root; waiting for that RPC
before mounting root creates a dependency cycle. The initrd therefore does not
require that post-root service. Charging-control safeguards are unchanged.

Image composition and the installed consumer must agree on one filesystem:

| Filesystem | Growth phase | Existing implementation to use |
| --- | --- | --- |
| F2FS | Before mounting root | Original Fedora `fsck.f2fs` and `resize.f2fs` |
| EXT4 | After mounting root | Original systemd growfs / kernel resize ioctl |
| XFS | After mounting root | Original systemd growfs / kernel resize ioctl |
| Btrfs | After mounting root | Original systemd growfs / kernel resize ioctl |

[systemd growfs](https://www.freedesktop.org/software/systemd/man/latest/systemd-growfs.html)
supports online EXT4, XFS and Btrfs growth. Installation profile 1.3.1 delegates
to that original helper and records successful completion. Its service condition
prevents repeating the operation on subsequent boots; an initrd's
empty machine ID does not establish that this is the installation's first boot.
No new filesystem-specific daemon or duplicate online resize implementation
is needed.

Support is not complete until kernel configuration/modules, the retained
root-selector capability, initrd root admission, installed updater, image
manifest/fstab, composition and preservation/refusal tests agree on the same
filesystem. Old F2FS-only kernels are not valid rollback kernels for a new
EXT4/XFS/Btrfs userdata image. Preserve matched rollback image and boot pairs.

The native configuration includes all four filesystems as built-ins. The
physical-root guard and v2 consumer admit the selected format; a Btrfs root must
have one physical member and no duplicate discovered UUID. Host VM preservation
tests and a mainline F2FS tablet result do not qualify this variant or a physical
EXT4/XFS/Btrfs boot. Do not convert or reformat an installed filesystem as part
of its capacity expansion.
