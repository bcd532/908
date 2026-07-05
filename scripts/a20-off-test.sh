#!/bin/sh
# ============================================================================
# a20-off-test.sh  -  boot the OS with the A20 line forced OFF, to exercise
#                     your check_a20 / enable_a20 path.
# ----------------------------------------------------------------------------
# QEMU leaves A20 ENABLED by default, so check_a20 always passes and your
# enable code never runs. This assembles the bootloader with -dFORCE_A20_OFF,
# which calls disable_a20 (fast-A20 port 0x92) *before* check_a20. Then you can
# watch, in the screenshot, what your detect/enable/re-check logic actually does
# when A20 starts off.
#
# Expected results:
#   - enable code correct  -> A20 detected off, enabled, re-checked, boots kernel
#   - enable code broken    -> stalls at "a20 Failed!" (or reboots)
#
# NOTE: this leaves build/ holding the TEST image. Run ./init afterwards to
#       rebuild the normal (A20-on) image.
# ============================================================================
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$ROOT" || exit 1

BUILD=build
LOG=$BUILD/debug
IMG=$BUILD/main_floppy.img
SHOT=$LOG/a20-off.png
mkdir -p "$BUILD" "$LOG"

echo "==> Assembling bootloader WITH -dFORCE_A20_OFF"
nasm src/bootloader/boot.asm -f bin -dFORCE_A20_OFF -o "$BUILD/bootloader.bin" || {
  echo "bootloader assembly failed"; exit 1; }
nasm src/kernel/main.asm -f bin -o "$BUILD/kernel.bin" || {
  echo "kernel assembly failed"; exit 1; }

echo "==> Building floppy image"
dd if=/dev/zero of="$IMG" bs=512 count=2880 status=none
mkfs.fat -F 12 -n "NBOS" "$IMG" >/dev/null 2>&1
dd if="$BUILD/bootloader.bin" of="$IMG" conv=notrunc status=none
mcopy -i "$IMG" "$BUILD/kernel.bin" "::kernel.bin"

echo "==> Booting headless with A20 forced OFF (~3s)"
: > "$LOG/a20-off-qemu.log"
( sleep 3; printf 'screendump %s\n' "$LOG/a20-off.ppm"; sleep 1; printf 'quit\n' ) | \
  timeout 12 qemu-system-i386 \
    -drive file="$IMG",format=raw,if=floppy -boot a \
    -d cpu_reset -D "$LOG/a20-off-qemu.log" \
    -display none -monitor stdio >/dev/null 2>&1

if [ -f "$LOG/a20-off.ppm" ] && command -v python3 >/dev/null 2>&1; then
  python3 -c "from PIL import Image; Image.open('$LOG/a20-off.ppm').save('$SHOT')" 2>/dev/null \
    && echo "    screenshot: $SHOT"
fi
resets=$(grep -c -i 'CPU Reset' "$LOG/a20-off-qemu.log" 2>/dev/null); [ -z "$resets" ] && resets=0
if [ "$resets" -ge 5 ]; then
  echo "    NOTE: $resets CPU resets - the A20-off path is triple-faulting/rebooting."
fi

echo
echo "Look at the screenshot above. When you're done, run ./init to restore the"
echo "normal (A20-enabled) image."
