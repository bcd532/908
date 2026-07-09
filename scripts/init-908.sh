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
# --- C kernel toolchain + intermediate objects ---
KERNEL_DIR=$SRC_DIR/kernel
ENTRY_ASM=$KERNEL_DIR/entry.asm
KMAIN_C=$KERNEL_DIR/kmain.c
LINKER_LD=$KERNEL_DIR/linker.ld
ENTRY_OBJ=$BUILD_DIR/entry.o
KMAIN_OBJ=$BUILD_DIR/kmain.o
KERNEL_ELF=$BUILD_DIR/kernel.elf
CC=i686-elf-gcc
LD=i686-elf-ld
OBJCOPY=i686-elf-objcopy
CFLAGS="-ffreestanding -m32 -fno-stack-protector -fno-tree-loop-distribute-patterns -Wall -Wextra"
IMG=$BUILD_DIR/main_floppy.img
LOGDIR=$BUILD_DIR/debug
BOOT_LST=$BUILD_DIR/bootloader.lst
KERNEL_LST=$BUILD_DIR/kernel.lst
BOOT_ORG=0x7C00                 # bootloader link/load address (org)
KERNEL_ORG=0x7E00              # kernel link/load address (org)
RUNS_DIR=$LOGDIR/runs          # per-run archive folders (RUN#####/) - kept forever
COUNTER_FILE=$LOGDIR/logs/.counter   # persistent run counter (continues old numbering)
RECENT=$RUNS_DIR/recent        # symlink -> newest run's folder
TRACE_DIR=$ROOT/scripts/trace  # symbols.py / gdbdrive.py / debrief.py
# per-run state, set by alloc_run:
RUN_ID= ; RUN_STAMP= ; RUN_MODE= ; RUNDIR= ; RUN_RAW=

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
for t in nasm i686-elf-gcc i686-elf-ld i686-elf-objcopy dd mkfs.fat mcopy minfo qemu-system-i386 gdb python3 xxd; do
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
  # -l emits a listing (addr/bytecode per line) that the tracer turns into a
  # label->address map, so breakpoints are named, not hand-counted offsets.
  lst="${2%.bin}.lst"
  err=$(nasm "$1" -f bin -o "$2" -l "$lst" 2>&1); rc=$?
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
# build_kernel_c: entry.asm (-f elf32) + kmain.c (freestanding) -> ld -> objcopy.
# The bootloader stays a flat binary; the kernel is now compiled+linked C.
build_kernel_c() {
  step "Building kernel (asm entry + C)"
  for t in "$CC" "$LD" "$OBJCOPY"; do
    command -v "$t" >/dev/null 2>&1 || { bad "$t not found - install the i686-elf cross toolchain"; die "kernel build failed"; }
  done
  # 1. entry stub -> LINKABLE object (not flat bin); listing feeds the tracer
  err=$(nasm "$ENTRY_ASM" -f elf32 -o "$ENTRY_OBJ" -l "$KERNEL_LST" 2>&1) \
    && ok "entry.asm -> $(basename "$ENTRY_OBJ")" \
    || { bad "nasm (entry.asm) failed:"; printf '%s\n' "$err" | sed 's/^/      /'; die "kernel build failed"; }
  # 2. compile EVERY freestanding C source in the kernel dir (no libc/host headers)
  KOBJS=""
  found_c=0
  for cfile in "$KERNEL_DIR"/*.c; do
    [ -e "$cfile" ] || break            # nothing matched the glob
    found_c=1
    cobj="$BUILD_DIR/$(basename "${cfile%.c}").o"
    err=$($CC $CFLAGS -c "$cfile" -o "$cobj" 2>&1); rc=$?
    { [ "$rc" -eq 0 ] && ok "$(basename "$cfile") -> $(basename "$cobj")"; } \
      || { bad "$CC ($(basename "$cfile")) failed:"; printf '%s\n' "$err" | sed 's/^/      /'; die "kernel build failed"; }
    KOBJS="$KOBJS $cobj"
  done
  [ "$found_c" -eq 1 ] || { bad "no C sources in $KERNEL_DIR - write your C kernel first"; die "kernel build failed"; }
  # 3. link entry stub + all C objects at 0x7E00 per linker.ld (ELF keeps symbols)
  err=$($LD -T "$LINKER_LD" "$ENTRY_OBJ" $KOBJS -o "$KERNEL_ELF" 2>&1) \
    && ok "linked -> $(basename "$KERNEL_ELF")" \
    || { bad "$LD failed:"; printf '%s\n' "$err" | sed 's/^/      /'; die "kernel build failed"; }
  # 4. flatten to the raw image the bootloader loads
  $OBJCOPY -O binary "$KERNEL_ELF" "$KERNEL_BIN" \
    && ok "$(basename "$KERNEL_BIN") ($(wc -c < "$KERNEL_BIN" | tr -d ' ') bytes)" \
    || { bad "objcopy failed"; die "kernel build failed"; }
}
assemble "$BOOT_ASM" "$BOOT_BIN" "bootloader"
build_kernel_c

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
# Per-run DEEP trace subsystem (build/debug/runs/RUN#####/).
#
# `qemu -d int` does NOT log real-mode software interrupts, so the disk reads,
# A20 negotiation and BIOS prints are invisible in a plain trace. We drive QEMU
# under GDB and breakpoint named milestones (resolved from the nasm listings)
# to capture what the hardware was actually asked to do - e.g. the true sector
# count handed to INT 13h. debrief.py then turns each run into a permanent,
# dissectable record. Every run is kept forever; nothing is pruned.
#
#   alloc_run <mode>  -> bump the persistent counter, make RUN#####/ folder.
#   deep_capture      -> QEMU+GDB milestone capture -> raw.log/gdb-events.jsonl,
#                        then debrief.py -> annotated.log/debrief.md/meta.json.
#   report_run        -> console headline (verdict, sector read, paths).
# Baseline (measured): healthy boot = 2 startup resets; a loop = dozens.
# ---------------------------------------------------------------------------
have_qemu() { command -v qemu-system-i386 >/dev/null 2>&1; }
have_gdb()  { command -v gdb >/dev/null 2>&1; }

alloc_run() {   # $1 = mode label -> sets RUN_ID/RUN_STAMP/RUN_MODE/RUNDIR/RUN_RAW
  mkdir -p "$RUNS_DIR" "$(dirname "$COUNTER_FILE")"
  n=0; [ -f "$COUNTER_FILE" ] && n=$(cat "$COUNTER_FILE" 2>/dev/null)
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  n=$((n + 1)); printf '%s\n' "$n" > "$COUNTER_FILE"
  RUN_ID=$(printf 'RUN%05d' "$n")
  RUN_STAMP=$(date +'%d-%m-%Y-%I:%M%p')
  RUN_MODE=$1
  RUNDIR="$RUNS_DIR/$RUN_ID"
  RUN_RAW="$RUNDIR/raw.log"
  mkdir -p "$RUNDIR"
}

write_context() {   # emit RUNDIR/context.json consumed by debrief.py
  cat > "$RUNDIR/context.json" <<EOF
{
  "run_id": "$RUN_ID",
  "run_stamp": "$RUN_STAMP",
  "run_mode": "$RUN_MODE",
  "image": "$IMG",
  "boot_bin": "$BOOT_BIN",
  "kernel_bin": "$KERNEL_BIN",
  "boot_src": "$BOOT_ASM",
  "host": "$(uname -sr)",
  "qemu_ver": "$(qemu-system-i386 --version 2>/dev/null | head -1)",
  "gdb_ver": "$(gdb --version 2>/dev/null | head -1)",
  "nasm_ver": "$(nasm -v 2>/dev/null)"
}
EOF
}

# deep_capture: run QEMU under GDB, capture milestones + a pristine raw trace,
# then debrief. Per design, GDB *tooling* breakage is a HARD FAIL (surfaced
# loudly); a merely-broken boot is captured as a finding, not fatal.
deep_capture() {
  # 1. symbol map: bootloader/entry labels from the NASM listings, plus the C
  #    kernel symbols (kmain) and the for(;;) spin address pulled from the ELF.
  if ! python3 "$TRACE_DIR/symbols.py" \
        "$BOOT_LST:$BOOT_ORG" "$KERNEL_LST:$KERNEL_ORG" \
        --elf "$KERNEL_ELF" \
        > "$RUNDIR/syms.json" 2>"$RUNDIR/symbols.err"; then
    bad "symbol map failed:"; sed 's/^/      /' "$RUNDIR/symbols.err"
    die "cannot build symbol map"
  fi

  # 2. launch QEMU halted (-S) with a gdbstub on a PID-derived port
  port=$(( 40000 + ($$ % 20000) ))
  qemu-system-i386 \
    -drive file="$IMG",format=raw,if=floppy -boot a \
    -d int,cpu_reset -D "$RUN_RAW" \
    -S -gdb "tcp::$port" -display none >/dev/null 2>"$RUNDIR/qemu.err" &
  QPID=$!

  # 3. wait for the gdbstub port to accept before connecting
  if command -v ss >/dev/null 2>&1; then
    i=0; while [ $i -lt 50 ]; do
      ss -ltn 2>/dev/null | grep -q ":$port " && break
      sleep 0.1; i=$((i + 1))
    done
  else
    sleep 1
  fi

  # 4. drive under GDB (batch). Non-zero exit == tooling failure -> hard fail.
  GDBDRIVE_PORT="$port" \
  GDBDRIVE_SYMS="$RUNDIR/syms.json" \
  GDBDRIVE_OUT="$RUNDIR/gdb-events.jsonl" \
  GDBDRIVE_HEAVY=1 \
    timeout 60 gdb -q -batch -x "$TRACE_DIR/gdbdrive.py" \
      >"$RUNDIR/gdb.out" 2>"$RUNDIR/gdb.err"
  grc=$?
  kill "$QPID" 2>/dev/null; wait "$QPID" 2>/dev/null

  if [ "$grc" -ne 0 ]; then
    bad "GDB deep-capture FAILED (exit $grc) - the deep trace is broken:"
    tail -20 "$RUNDIR/gdb.err" | sed 's/^/      /'
    die "gdb tooling failure (full stderr in $RUNDIR/gdb.err)"
  fi

  # 5. debrief: annotated.log + debrief.md + meta.json + INDEX append
  write_context
  if ! python3 "$TRACE_DIR/debrief.py" "$RUNDIR" "$RUNDIR/context.json" \
        > "$RUNDIR/verdict.txt" 2>"$RUNDIR/debrief.err"; then
    bad "debrief failed:"; sed 's/^/      /' "$RUNDIR/debrief.err"
    die "debrief.py failure"
  fi
  ln -sfn "$RUN_ID" "$RECENT"
}

report_run() {
  verdict=$(cat "$RUNDIR/verdict.txt" 2>/dev/null)
  case "$verdict" in HEALTHY*) ok "$verdict" ;; *) bad "$verdict" ;; esac
  sect=$(python3 -c "import json;r=(json.load(open('$RUNDIR/meta.json')).get('sector_read') or {});print('%s %s sector(s) from LBA33 -> %s'%(r.get('op','?'),r.get('sectors','?'),r.get('dest','?')))" 2>/dev/null)
  [ -n "$sect" ] && printf '  %sdisk   : %s%s\n' "$DIM" "$sect" "$N"
  printf '  %sdebrief: %s/debrief.md%s\n' "$DIM" "$RUNDIR" "$N"
  printf '  %sraw    : %s/raw.log  (annotated: %s/annotated.log)%s\n' "$DIM" "$RUNDIR" "$RUNDIR" "$N"
  printf '  %srecent : %s -> %s%s\n' "$DIM" "$RECENT" "$RUN_ID" "$N"
}

capture_screenshot() {   # separate short run -> screen.png in the run folder
  ppm="$RUNDIR/screen.ppm"; png="$RUNDIR/screen.png"
  ( sleep 3; printf 'screendump %s\n' "$ppm"; sleep 1; printf 'quit\n' ) | \
    timeout 12 qemu-system-i386 \
      -drive file="$IMG",format=raw,if=floppy -boot a \
      -display none -monitor stdio >/dev/null 2>&1
  if [ -f "$ppm" ] && command -v python3 >/dev/null 2>&1; then
    python3 -c "from PIL import Image; Image.open('$ppm').save('$png')" 2>/dev/null \
      && ok "screenshot: $png" || warn "could not render screenshot (PIL missing?)"
  fi
}

case "$MODE" in
  makeonly)
    : # build + validation only; nothing more to do
    ;;

  headless)
    if have_qemu && have_gdb; then
      step "Deep trace capture (headless, GDB-driven)"
      alloc_run headless
      deep_capture
      capture_screenshot
      report_run
    else
      warn "deep trace needs both qemu-system-i386 and gdb - skipping"
    fi
    ;;

  window)
    # Static checks must pass before we hand you an interactive window.
    if [ "$FAILS" -ne 0 ]; then
      warn "static checks failed - not launching QEMU (fix the above first)"
    elif have_qemu && have_gdb; then
      step "Deep trace capture (GDB-driven) - archiving the full record"
      alloc_run window
      deep_capture
      report_run
      step "Opening QEMU window (close it to finish; trace already archived)"
      qemu-system-i386 \
        -drive file="$IMG",format=raw,if=floppy -boot a \
        -d int,cpu_reset -D "$RUNDIR/window-int.log"
    else
      warn "deep trace needs both qemu-system-i386 and gdb - skipping"
    fi
    ;;
esac

# ---------------------------------------------------------------------------
echo
if [ "$FAILS" -eq 0 ]; then
  printf '%s==============  ALL CHECKS PASSED  ==============%s\n' "$G" "$N"
  if [ -n "$RUNDIR" ] && [ -f "$RUNDIR/debrief.md" ]; then
    printf 'Full run debrief: %s/debrief.md\n' "$RUNDIR"
    [ -f "$RUNDIR/screen.png" ] && printf 'Screenshot: %s/screen.png\n' "$RUNDIR"
  fi
  status=0
else
  printf '%s==========  %d CHECK(S) FAILED  ==========%s\n' "$R" "$FAILS" "$N"
  status=1
fi
exit $status
