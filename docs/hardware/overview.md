# Hardware and interfaces

The device tree targets Xiaomi Pad 7 and POCO Pad X1 on Qualcomm SM7675.
The standard Fedora boot enters EL1. See the
[Uke Linux hardware table](https://github.com/MCC45TR/uke-linux#hardware-support)
for current device-level results and limitations.

Device-tree inputs are under [Qualcomm DTS](../../kernel/overlay/arch/arm64/boot/dts/qcom/).
[Bindings](../../kernel/overlay/Documentation/devicetree/bindings/) specify
compatible strings and hardware resources. The
[sysfs ABI entries](../../kernel/overlay/Documentation/ABI/testing/) describe
available interfaces and their status. NT36532 touchscreen source and its
Kconfig are under the
[Linux touchscreen path](../../kernel/overlay/drivers/input/touchscreen/nt36532-uke/).
