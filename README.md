# Senemos Uke mainline kernel

Mainline Linux development for POCO Pad X1 and Xiaomi Pad 7 (`uke`, SM7675). The kernel product is **`senemos-uke-kernel-mainline`**; the first fixed upstream baseline is Linux **7.2.8**. Hardware results remain scoped to the tested commercial model and SKU.

[Uke Linux](https://github.com/MCC45TR/uke-linux) · [Kernel architecture](docs/ARCHITECTURE.md) · [Hardware status](https://github.com/MCC45TR/uke-linux/blob/main/DEVICE-STATUS.md) · [Releases](https://github.com/MCC45TR/senemos-uke-kernel-mainline/releases)

## Development scope

The first platform path covers CPU and firmware interfaces, clocks and power, pin control, USB, storage and an early console. A standalone mainline device tree follows the stock-DT transition profile. Display, touch, GPU, wireless, audio, sensors, charging, suspend and camera work are tracked independently in the [device matrix](https://github.com/MCC45TR/uke-linux/blob/main/DEVICE-STATUS.md).

The Uke Linux 6.12 community port and OEM/Android sources are evidence for a forward port, not a substitute for mainline validation. Kernel changes are split by subsystem with source attribution, build checks and focused error-path tests. Android 6.1 vendor modules are not reused as Linux 7.2 modules.

## Downloads

**There is no kernel image or RPM release yet.** Release candidates will identify the upstream base, patch series, config, compiler, device-tree profile, module ABI and compatible firmware. Fedora packages will first appear in the [uke-linux-test COPR channel](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) after source and package checks. Physical compatibility is recorded separately.

The active source checkout is created from a pinned upstream revision under `src/upstream/`; large unchanged reference repositories live locally in `referances/`. [The workspace plan](https://github.com/MCC45TR/uke-linux/blob/main/PLAN.md) defines the ordered bring-up. Kernel code follows Linux C/assembly conventions; native companion tools use C++. See [AGENTS.md](AGENTS.md) and the original source licenses before contributing.
