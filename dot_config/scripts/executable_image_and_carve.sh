#!/usr/bin/env bash
set -euo pipefail

# ----------------- EDIT THESE -----------------
# Block device (e.g. /dev/sdb). If left empty the script will show lsblk and ask.
DEVICE="/dev/sdb"
# Output directory on another drive with enough free space
OUTDIR="/run/media/salman/Salman-Data/Family/Sultan/Camera/recovery"
# ddrescue retry passes (use -1 for infinite)
RETRY_PASSES=3
# ----------------------------------------------

# Tools we will use
REQUIRED_TOOLS=(ddrescue lsblk photorec recoverjpeg foremost exiftool xxd file)

# helper: check if tool exists
missing_tools=()
for t in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$t" >/dev/null 2>&1; then
    missing_tools+=("$t")
  fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
  echo "Warning: the following tools are missing (some are optional but recommended):"
  printf "  %s\n" "${missing_tools[@]}"
  echo "Install them before running the script (e.g. apt install gddrescue testdisk recoverjpeg foremost exiftool xxd file)."
  echo
fi

# Ask for device if not set
if [ -z "${DEVICE}" ]; then
  echo "Please identify your card's block device from the list below:"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
  echo
  read -rp "Enter block device (example /dev/sdb) and press Enter: " DEVICE
fi

# Basic sanity
if [ ! -b "$DEVICE" ]; then
  echo "ERROR: $DEVICE is not a block device. Aborting."
  exit 1
fi

# Prepare OUTDIR
mkdir -p "$OUTDIR"
IMGFILE="$OUTDIR/sdcard.img"
MAPFILE="$OUTDIR/sdcard.map"   # ddrescue mapfile (positional)
PHOTOREC_OUT="$OUTDIR/photorec_recovered"
RECOVER_OUT="$OUTDIR/recoverjpeg_out"
FOREMOST_OUT="$OUTDIR/foremost_out"
THUMBS_OUT="$OUTDIR/exif_thumbs"

mkdir -p "$PHOTOREC_OUT" "$RECOVER_OUT" "$FOREMOST_OUT" "$THUMBS_OUT"

echo "Device: $DEVICE"
echo "Output dir: $OUTDIR"
echo "Image will be: $IMGFILE"
echo "Mapfile (ddrescue) will be: $MAPFILE"
echo

read -rp "Make sure $OUTDIR is on a different drive and you have enough free space. Type 'yes' to continue: " CONF
if [ "$CONF" != "yes" ]; then
  echo "Aborted by user."
  exit 1
fi

# Unmount any mounted partitions for this device (attempt)
echo "Attempting to unmount any mounted partitions of $DEVICE..."
mounted_points=$(lsblk -ln -o NAME,MOUNTPOINT "$DEVICE" | awk 'NF==2{print $2}')
if [ -n "$mounted_points" ]; then
  echo "Found mountpoints:"
  printf "  %s\n" $mounted_points
  for mp in $mounted_points; do
    echo "  umount $mp"
    sudo umount "$mp" || { echo "Failed to unmount $mp — close programs using it and re-run."; exit 1; }
  done
else
  echo "No partitions appear to be mounted for $DEVICE."
fi

# Final check: where will mapfile and image live, enough space?
avail_bytes=$(df --output=avail -B1 "$OUTDIR" | tail -n1)
if [ -z "$avail_bytes" ]; then
  echo "Warning: could not determine free space of $OUTDIR."
else
  echo "Free bytes on OUTDIR: $avail_bytes"
fi

# Run ddrescue (GNU ddrescue expects: infile outfile mapfile)
echo
echo "Starting ddrescue (will run with -d for direct access and -r ${RETRY_PASSES})."
echo "Mapfile allows resuming the job later with the same command."
echo "Command:"
echo "  sudo ddrescue -d -r${RETRY_PASSES} \"$DEVICE\" \"$IMGFILE\" \"$MAPFILE\""
echo
read -rp "Type 'go' to start ddrescue now: " GO
if [ "$GO" != "go" ]; then
  echo "Quitting."
  exit 1
fi

# Run ddrescue and tee output to a log
sudo ddrescue -d -r"${RETRY_PASSES}" "$DEVICE" "$IMGFILE" "$MAPFILE" 2>&1 | tee "$OUTDIR/ddrescue_run.log"

echo
echo "ddrescue finished (or paused). Image: $IMGFILE"
ls -lh "$IMGFILE" || true
echo "Mapfile: $MAPFILE"

# Sanity: show partitions in image (if any)
echo
echo "Detecting partitions in image (losetup + partx will show if present)..."
if command -v losetup >/dev/null 2>&1; then
  loopdev=$(sudo losetup --show -fP "$IMGFILE") || true
  echo "Associated loop device: $loopdev"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$loopdev" || true
  # detach loop now if no need to keep it
  sudo losetup -d "$loopdev" || true
fi

# 1) Extract embedded thumbnails from any readable files (fast salvage)
if command -v exiftool >/dev/null 2>&1; then
  echo "Attempting to extract embedded thumbnails from DCIM path (if readable)..."
  # Note: user may prefer to extract directly from mounted path; this is optional and skipped if not applicable
  if [ -d "/run/media/salman/Salman-Data/Family/Sultan/Camera/DCIM" ]; then
    exiftool -r -if '$ThumbnailImage' -b -ThumbnailImage -w %f_thumb.jpg -ext JPG "/run/media/salman/Salman-Data/Family/Sultan/Camera/DCIM" -o "$THUMBS_OUT" || true
    echo "Thumbnails (if any) saved to $THUMBS_OUT"
  else
    echo "Original DCIM mount not found at expected path; skipping thumbnail extraction."
  fi
else
  echo "exiftool not installed; skipping thumbnail extraction step."
fi

# 2) Run photorec (carving). Photorec may run interactive; this invocation writes to PHOTOREC_OUT
if command -v photorec >/dev/null 2>&1; then
  echo
  echo "Running PhotoRec (signature-based carve) — output -> $PHOTOREC_OUT"
  echo "If PhotoRec becomes interactive, select the image file, partition (or No partition), and choose JPEG only."
  sudo photorec /d "$PHOTOREC_OUT" /log "$IMGFILE"
else
  echo "photorec not available; skip photorec carve."
fi

# 3) Run recoverjpeg (if installed)
if command -v recoverjpeg >/dev/null 2>&1; then
  echo
  echo "Running recoverjpeg (JPEG-specific carver) -> $RECOVER_OUT"
  sudo recoverjpeg -o "$RECOVER_OUT" "$IMGFILE" 2> "$RECOVER_OUT/recoverjpeg.log" || true
else
  echo "recoverjpeg not installed; skipping."
fi

# 4) Run foremost (if installed)
if command -v foremost >/dev/null 2>&1; then
  echo
  echo "Running foremost (JPEG carve) -> $FOREMOST_OUT"
  sudo foremost -t jpg -i "$IMGFILE" -o "$FOREMOST_OUT" 2> "$FOREMOST_OUT/foremost.log" || true
else
  echo "foremost not installed; skipping."
fi

# 5) Summarize recovered files
echo
echo "Summary of recovered JPEGs (counts):"
if [ -d "$PHOTOREC_OUT" ]; then
  echo "photorec jpg count: $(find "$PHOTOREC_OUT" -type f -iname '*.jpg' 2>/dev/null | wc -l)"
else
  echo "photorec output not present"
fi
if [ -d "$RECOVER_OUT" ]; then
  echo "recoverjpeg jpg count: $(find "$RECOVER_OUT" -type f -iname '*.jpg' 2>/dev/null | wc -l)"
else
  echo "recoverjpeg output not present"
fi
if [ -d "$FOREMOST_OUT" ]; then
  echo "foremost jpg count: $(find "$FOREMOST_OUT" -type f -iname '*.jpg' 2>/dev/null | wc -l)"
else
  echo "foremost output not present"
fi

echo
echo "Top 20 largest recovered files (likely better quality):"
find "$OUTDIR" -type f -iname '*.jpg' -exec ls -lh {} + 2>/dev/null | sort -k5 -h -r | head -n 20 || true

echo
echo "Done. Logs: $OUTDIR/ddrescue_run.log  and ddrescue mapfile: $MAPFILE"
echo "To resume ddrescue later, run the exact same ddrescue command again (it will use the mapfile)."
