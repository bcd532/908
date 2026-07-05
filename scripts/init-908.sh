#!/bin/sh
# ============================================================================
# init-908.sh  -  build, validate, and smoke-test the 908 OS floppy image.
# ----------------------------------------------------------------------------
# Runs the whole pipeline (assemble -> image -> validate -> boot) and, when a
# step breaks, PARSES the failure so you get a diagnosis, not just a wall of
# tool output. Short alias: ./init
#
# Usage:
#   ./init          build + validate, then open a QEMU WINDOW (writes debug trace)
#   ./init -h       HEADLESS: build + validate + headless smoke test (screenshot)
#   ./init -m       MAKE only: build + validate, no emulator
#   ./init --help   show this header
# ============================================================================

set -u

# ---- locate repo root (script lives in scripts/; works via the ./init symlink)
SELF=$(readlink -f -- "$0" 2>/dev/null || printf '%s' "$0")
ROOT=$(CDPATH= cd -- "$(dirname -- "$SELF")/.." && pwd -P)
cd "$ROOT" || exit 1

SRC_DIR=src
BUILD_DIR=build
BOOT_ASM=$SRC_DIR/bootloader/boot.asm
KERNEL_ASM=$SRC_DIR/kernel/main.asm
BOOT_BIN=$BUILD_DIR/bootloader.bin
KERNEL_BIN=$BUILD_DIR/kernel.bin
IMG=$BUILD_DIR/main_floppy.img
LOGDIR=$BUILD_DIR/debug
SHOT=$LOGDIR/screen.png
LOGS_DIR=$LOGDIR/logs          # per-run rotated qemu traces live here
COUNTER_FILE=$LOGS_DIR/.counter
RECENT=$LOGS_DIR/recent.log    # symlink -> newest run's trace
KEEP_LOGS=20                   # prune older runs beyond this many
RUN_LOG=                       # set per run by alloc_run_log

MODE=window                 # default: build + validate + visible QEMU window
for a in "$@"; do
  case "$a" in
    -h|--headless) MODE=headless ;;
    -m|--make)     MODE=makeonly ;;
    --help)        sed -n '2,14p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s (try --help)\n' "$a"; exit 2 ;;
  esac
done

# ---- pretty output ---------------------------------------------------------
if [ -t 1 ]; then
  R=$(printf '\033[31m'); G=$(printf '\033[32m'); Y=$(printf '\033[33m')
  B=$(printf '\033[34m'); DIM=$(printf '\033[2m'); N=$(printf '\033[0m')
else
  R=; G=; Y=; B=; DIM=; N=
fi
FAILS=0
step() { printf '\n%s==>%s %s\n' "$B" "$N" "$1"; }
ok()   { printf '  %s[ ok ]%s %s\n' "$G" "$N" "$1"; }
warn() { printf '  %s[warn]%s %s\n' "$Y" "$N" "$1"; }
bad()  { printf '  %s[FAIL]%s %s\n' "$R" "$N" "$1"; FAILS=$((FAILS + 1)); }
die()  { printf '\n%sBuild stopped: %s%s\n' "$R" "$1" "$N"; exit 1; }

# ---------------------------------------------------------------------------
step "Checking required tools"
missing=
for t in nasm dd mkfs.fat mcopy minfo qemu-system-i386 python3 xxd; do
  if command -v "$t" >/dev/null 2>&1; then
    ok "$t"
  else
    warn "missing: $t (steps needing it will be skipped)"
    missing="$missing $t"
  fi
done

# ---------------------------------------------------------------------------
# assemble: run nasm and, on failure, diagnose the recurring NASM error modes.
assemble() { # $1=src  $2=out  $3=label
  step "Assembling $3 ($1)"
  mkdir -p "$BUILD_DIR"
  err=$(nasm "$1" -f bin -o "$2" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    bad "nasm failed:"
    printf '%s\n' "$err" | sed 's/^/      /'
    if printf '%s' "$err" | grep -q 'not defined'; then
      sym=$(printf '%s' "$err" | grep -o "symbol \`[^']*'" | head -1)
      printf '\n  %sdiagnosis:%s undefined %s\n' "$Y" "$N" "$sym"
      printf '  %sIn NASM a `.name` reference and its `.name:` definition must match\n' "$DIM"
      printf '  character-for-character, and both attach to the nearest non-local\n'
      printf '  label above them. Look for a typo or a missing leading dot.%s\n' "$N"
    fi
    if printf '%s' "$err" | grep -q 'changed during code generation'; then
      printf '\n  %snote:%s the "changed during code generation" lines are fallout from\n' "$Y" "$N"
      printf '  %sthe first undefined symbol above - fix that one and they all clear.%s\n' "$DIM" "$N"
    fi
    die "assembly of $3 failed"
  fi
  ok "$2 ($(wc -c < "$2" | tr -d ' ') bytes)"
}
assemble "$BOOT_ASM" "$BOOT_BIN" "bootloader"
assemble "$KERNEL_ASM" "$KERNEL_BIN" "kernel"

# ---------------------------------------------------------------------------
step "Building floppy image"
dd if=/dev/zero of="$IMG" bs=512 count=2880 status=none 2>/dev/null \
  && ok "zeroed 1.44MB image" || bad "dd zero failed"
mkfs.fat -F 12 -n "NBOS" "$IMG" >/dev/null 2>&1 \
  && ok "mkfs.fat (FAT12)" || bad "mkfs.fat failed"
dd if="$BOOT_BIN" of="$IMG" conv=notrunc status=none 2>/dev/null \
  && ok "bootloader written to sector 0" || bad "dd bootloader failed"
mco=$(mcopy -i "$IMG" "$KERNEL_BIN" "::kernel.bin" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  ok "kernel.bin copied into FAT"
else
  bad "mcopy failed:"
  printf '%s\n' "$mco" | sed 's/^/      /'
  if printf '%s' "$mco" | grep -qi 'non DOS media'; then
    printf '\n  %sdiagnosis:%s mtools cannot read the filesystem.\n' "$Y" "$N"
    printf '  %sThe bootloader dd`d over sector 0 carries its own BPB, and a field is\n' "$DIM"
    printf '  wrong or misaligned (classic: a missing field shifts the media descriptor\n'
    printf '  off offset 0x15). Check the BPB table below.%s\n' "$N"
  fi
fi

# ---------------------------------------------------------------------------
step "Validating boot sector / BPB (offsets per FAT12 spec)"
python3 - "$BOOT_BIN" "$IMG" <<'PY'
import sys, os
boot, img = sys.argv[1], sys.argv[2]
b = open(boot, 'rb').read()
tty = sys.stdout.isatty()
G = "\033[32m" if tty else ""; R = "\033[31m" if tty else ""
Y = "\033[33m" if tty else ""; N = "\033[0m"  if tty else ""
def u16(o): return b[o] | (b[o + 1] << 8)
fails = 0
def check(name, got, want, hx=False):
    global fails
    f = (lambda v: "0x%X" % v) if hx else str
    if want is None:
        print("      %-20s = %s" % (name, f(got)))
    elif got == want:
        print("    %s ok %s %-20s = %s" % (G, N, name, f(got)))
    else:
        print("    %sFAIL%s %-20s = %s  %s(expected %s)%s"
              % (R, N, name, f(got), R, f(want), N))
        fails += 1
print("      OEM                  = %r" % b[3:11].decode('latin1'))
check("bytes/sector",      u16(0x0B), 512)
check("sectors/cluster",   b[0x0D],   None)
check("reserved sectors",  u16(0x0E), None)
check("FAT count",         b[0x10],   2)
check("root entries",      u16(0x11), 224)
check("total sectors(16)", u16(0x13), 2880)          # offset 0x13 - the field that went missing once
check("media descriptor",  b[0x15],   0xF0, hx=True) # lands here ONLY if 0x13 is correct
check("sectors/FAT",       u16(0x16), None)
check("sectors/track",     u16(0x18), 18)
check("heads",             u16(0x1A), 2)
check("boot signature",    u16(0x1FE), 0xAA55, hx=True)
if len(b) != 512:
    print("    %sFAIL%s boot sector size     = %d  %s(must be exactly 512)%s"
          % (R, N, len(b), R, N)); fails += 1
else:
    print("    %s ok %s boot sector size     = 512" % (G, N))
isz = os.path.getsize(img); want = 2880 * 512
tag = (G + " ok " + N) if isz == want else (R + "FAIL" + N)
print("    %s image size           = %d  (want %d)" % (tag, isz, want))
if isz != want: fails += 1
t16 = u16(0x13)
if t16 and t16 * 512 != isz:
    print("    %snote%s: BPB total-sectors (%d) * 512 != image size - keep them in sync"
          % (Y, N, t16))
sys.exit(1 if fails else 0)
PY
if [ $? -eq 0 ]; then ok "BPB valid"; else bad "BPB validation found problems (see table)"; fi

# ---------------------------------------------------------------------------
if command -v minfo >/dev/null 2>&1; then
  step "Filesystem sanity (mtools)"
  if minfo -i "$IMG" >/dev/null 2>&1; then
    ok "mtools can mount the image"
    if mdir -i "$IMG" 2>/dev/null | grep -qi 'KERNEL'; then
      ok "kernel.bin present in FAT root"
    else
      warn "kernel.bin not found in FAT root directory"
    fi
  else
    bad "mtools cannot mount the image (BPB/geometry problem - see table above)"
  fi
fi

# ---------------------------------------------------------------------------
# Per-run rotated QEMU traces (build/debug/logs/).
#   alloc_run_log <mode> -> qemu-int-<DD-MM-YYYY-HH:MMam/pm>-RUN#####.log,
#                           bumps a persistent counter, sets $RUN_LOG.
#   finalize_run_log     -> prepend a header, point recent.log at it, prune.
#   parse_resets         -> console verdict (healthy vs triple-fault loop).
# Baseline (measured): healthy boot = 2 startup resets; a loop = dozens. Flag >=5.
# ---------------------------------------------------------------------------
alloc_run_log() {   # $1 = mode label
  mkdir -p "$LOGS_DIR"
  n=0; [ -f "$COUNTER_FILE" ] && n=$(cat "$COUNTER_FILE" 2>/dev/null)
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  n=$((n + 1)); printf '%s\n' "$n" > "$COUNTER_FILE"
  RUN_ID=$(printf 'RUN%05d' "$n")
  RUN_STAMP=$(date +'%d-%m-%Y-%I:%M%p')
  RUN_MODE=$1
  RUN_LOG="$LOGS_DIR/qemu-int-$RUN_STAMP-$RUN_ID.log"
}

finalize_run_log() {
  [ -f "$RUN_LOG" ] || return 0
  resets=$(grep -c -i 'CPU Reset' "$RUN_LOG" 2>/dev/null); [ -z "$resets" ] && resets=0
  verdict="healthy"; [ "$resets" -ge 5 ] && verdict="TRIPLE-FAULT / reboot loop"
  firstexc=$(grep -m1 -E 'v=0[0-9a-f] ' "$RUN_LOG" 2>/dev/null)
  tmp="$RUN_LOG.hdr"
  {
    printf '=========================================================================\n'
    printf ' 908 OS  --  QEMU trace  --  %s\n' "$RUN_ID"
    printf '   when    : %s\n' "$RUN_STAMP"
    printf '   mode    : %s\n' "$RUN_MODE"
    printf '   image   : %s\n' "$IMG"
    printf '   resets  : %s   (2 = healthy, >=5 = triple-fault loop)\n' "$resets"
    printf '   verdict : %s\n' "$verdict"
    [ -n "$firstexc" ] && printf '   1st exc : %s\n' "$firstexc"
    printf '=========================================================================\n\n'
    cat "$RUN_LOG"
  } > "$tmp" && mv "$tmp" "$RUN_LOG"
  ln -sf "$(basename "$RUN_LOG")" "$RECENT"
  # rotate: keep only the newest $KEEP_LOGS traces
  ls -1t "$LOGS_DIR"/qemu-int-*.log 2>/dev/null | tail -n +"$((KEEP_LOGS + 1))" | \
    while IFS= read -r old; do rm -f "$old"; done
}

parse_resets() {
  if [ -s "$RUN_LOG" ]; then
    resets=$(grep -c -i 'CPU Reset' "$RUN_LOG" 2>/dev/null); [ -z "$resets" ] && resets=0
    if [ "$resets" -ge 5 ]; then
      bad "CPU reset ${resets}x - reboot loop, almost certainly a triple fault"
      printf '  %s(bad jump/GDT/stack, or a fault with no handler).%s\n' "$DIM" "$N"
      printf '  %sfirst exception in trace:%s\n' "$DIM" "$N"
      grep -m1 -E 'v=0[0-9a-f] ' "$RUN_LOG" 2>/dev/null | sed 's/^/      /'
    else
      ok "no reboot loop (${resets} startup resets, baseline is 2)"
    fi
    printf '  %strace : %s%s\n' "$DIM" "$RUN_LOG" "$N"
    printf '  %srecent: %s (-> %s)%s\n' "$DIM" "$RECENT" "$(basename "$RUN_LOG")" "$N"
  else
    warn "no QEMU trace captured"
  fi
}

have_qemu() { command -v qemu-system-i386 >/dev/null 2>&1; }

case "$MODE" in
  makeonly)
    : # build + validation only; nothing more to do
    ;;

  headless)
    if have_qemu; then
      step "QEMU smoke test (headless, ~3s)"
      mkdir -p "$LOGDIR"; alloc_run_log headless
      ( sleep 3; printf 'screendump %s\n' "$LOGDIR/screen.ppm"; sleep 1; printf 'quit\n' ) | \
        timeout 12 qemu-system-i386 \
          -drive file="$IMG",format=raw,if=floppy -boot a \
          -d int,cpu_reset -D "$RUN_LOG" \
          -display none -monitor stdio >/dev/null 2>&1
      finalize_run_log
      if [ -f "$LOGDIR/screen.ppm" ] && command -v python3 >/dev/null 2>&1; then
        if python3 -c "from PIL import Image; Image.open('$LOGDIR/screen.ppm').save('$SHOT')" 2>/dev/null; then
          ok "screenshot saved: $SHOT"
        else
          warn "could not render screenshot (python PIL not installed?)"
        fi
      fi
      parse_resets
    else
      warn "qemu-system-i386 not found - skipping headless test"
    fi
    ;;

  window)
    # Static checks must pass before we hand you an interactive window.
    if [ "$FAILS" -ne 0 ]; then
      warn "static checks failed - not launching QEMU (fix the above first)"
    elif have_qemu; then
      step "Launching QEMU window (close it to finish; debug trace is being recorded)"
      mkdir -p "$LOGDIR"; alloc_run_log window
      # Visible window AND a full int+reset trace to a per-run txt file.
      qemu-system-i386 \
        -drive file="$IMG",format=raw,if=floppy -boot a \
        -d int,cpu_reset -D "$RUN_LOG"
      finalize_run_log   # runs after you close the window
      parse_resets
    else
      warn "qemu-system-i386 not found - skipping window"
    fi
    ;;
esac

# ---------------------------------------------------------------------------
echo
if [ "$FAILS" -eq 0 ]; then
  printf '%s==============  ALL CHECKS PASSED  ==============%s\n' "$G" "$N"
  [ -f "$SHOT" ] && [ "$MODE" = headless ] && printf 'Look at the running OS here: %s\n' "$SHOT"
  status=0
else
  printf '%s==========  %d CHECK(S) FAILED  ==========%s\n' "$R" "$FAILS" "$N"
  status=1
fi
exit $status
