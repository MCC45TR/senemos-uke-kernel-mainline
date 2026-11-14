#!/usr/bin/env bash
# Native runtime fixture only. No build, package, mode or persistent setting.
set -Eeuo pipefail
umask 077
export LC_ALL=C
[[ $EUID != 0 ]]
tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fx xiaomi,uke >/dev/null
[[ -n ${XDG_RUNTIME_DIR:-} && -n ${WAYLAND_DISPLAY:-} ]]
test -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
owner=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
input=$owner/tests/fixtures/iris-ball-320x240-12.h264
input_sha256=b1a12f7472263e61d254e9ce98ae962e15d9b5ac014db92d0268171e14578da0
expected_sha256=ba190fee469e02229c522ae5065213c7b8f144d52966177b9ac1a86a033e3777
printf '%s  %s\n' "$input_sha256" "$input" | sha256sum -c --strict - >/dev/null
output=$(realpath -m "${1:?New empty private evidence directory}")
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output"
chmod 0700 "$output"
kernel=$(uname -r)
decoder=
for node in /sys/class/video4linux/video*; do
  if [[ $(< "$node/name") == qcom-iris-decoder ]]; then
    [[ -z $decoder ]]
    decoder=/dev/${node##*/}
  fi
done
[[ -n $decoder && -r $decoder && -w $decoder ]]

# Independent CPU reference is deliberately separate from hardware delivery.
timeout --signal=TERM --kill-after=2s 12s ffmpeg -nostdin -hide_banner -loglevel error \
  -c:v libopenh264 -i "$input" -an -fps_mode passthrough -pix_fmt yuv420p \
  -f rawvideo "$output/reference.i420" > "$output/reference.log" 2>&1
printf '%s  %s\n' "$expected_sha256" "$output/reference.i420" | sha256sum -c --strict - >/dev/null

# CPU mapping/conversion is used only to inspect and compare decoded pixels.
timeout --signal=TERM --kill-after=2s 12s gst-launch-1.0 -e -v \
  filesrc location="$input" ! h264parse ! v4l2h264dec device="$decoder" capture-io-mode=mmap \
  ! 'video/x-raw,format=NV12' ! videoconvert ! 'video/x-raw,format=I420' \
  ! filesink location="$output/decoded.i420" > "$output/decode.log" 2> "$output/decode-error.log"
test "$(stat -c %s "$output/decoded.i420")" = 1382400
cmp "$output/reference.i420" "$output/decoded.i420"
grep -F 'Got EOS' "$output/decode.log" >/dev/null

# No conversion element is present in this delivery path; require DMABUF caps.
env GST_DEBUG=v4l2*:4,waylandsink:4 WAYLAND_DEBUG=client \
  timeout --signal=TERM --kill-after=2s 12s gst-launch-1.0 -e -v \
  filesrc location="$input" ! h264parse ! v4l2h264dec device="$decoder" capture-io-mode=dmabuf \
  ! 'video/x-raw(memory:DMABuf),format=DMA_DRM,drm-format=NV12' \
  ! identity silent=false ! waylandsink sync=true \
  > "$output/dmabuf.log" 2> "$output/dmabuf-debug.log"
buffers=$(grep -cF 'last-message = chain' "$output/dmabuf.log")
test "$buffers" = 12
grep -F 'Got EOS' "$output/dmabuf.log" >/dev/null
grep -F 'video/x-raw(memory:DMABuf)' "$output/dmabuf.log" >/dev/null
imports=$(grep -cE 'zwp_linux_buffer_params_v1#[0-9]+\.created\(new id wl_buffer' "$output/dmabuf-debug.log")
test "$imports" -gt 0
test "$(uname -r)" = "$kernel"
rpm -qf /usr/bin/gst-launch-1.0 /usr/bin/ffmpeg \
  /usr/lib64/gstreamer-1.0/libgstvideo4linux2.so \
  /usr/lib64/gstreamer-1.0/libgstwaylandsink.so > "$output/packages.txt"
jq -n --arg kernel "$kernel" --arg input_sha256 "$input_sha256" \
  --arg pixels_sha256 "$expected_sha256" --argjson frames "$buffers" --argjson imports "$imports" \
  '{kernel:$kernel,input_sha256:$input_sha256,pixels_sha256:$pixels_sha256,frames:$frames,compositor_dmabuf_imports:$imports,independent_pixels_equal:true,dmabuf_delivery_eos:true,scope:"12-frame320x240 H264 correctness and NV12 DMABUF delivery only; no optical, general zero-copy, higher-profile or throughput acceptance"}' \
  > "$output/summary.json"
cat "$output/summary.json"
