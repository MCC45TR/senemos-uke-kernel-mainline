# Linux 7.3.0-51 video source

29 October 2026. This source overlay adds four bounded SM7675 Iris decoder
changes to the exact release-50 source from
[COPR 11222548](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/build/11222548/).
The base SRPM SHA256 is
`e76815db7f6d88758e0709574f69137467005d4d331a31e8eeaa7c4ed796ac44`;
its source commit is `8cbe0435f05c8a26dd891bd842ec8533a1504421`.

The archive contains the complete source patch, four GPL kernel patches,
source-function contracts, the updated source manifest and release-51 spec.
The video source commit is `1024dc8aa5cddc73c5bb8f6f7949f62f1bda941f`.
The base kernel's display/DSC changes and boot recipe remain intact.
The checksum file binds the archive used by the COPR custom source recipe.
This archive contains no compiled payload, firmware or media sample.

Release-51 compilation and contracts run in Fedora Rawhide AArch64 COPR.
Earlier release-49 native and Chrome measurements do not establish release-51
installation, boot, sustained presentation or HDR support. No device result is
claimed by this source publication.
