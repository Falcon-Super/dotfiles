#!/usr/bin/env bash
set -euo pipefail

MOUNT="/run/media/salman/4E78-1F0B"

echo "1) Resolve device for mountpoint: $MOUNT"
DEV=$(findmnt -n -o SOURCE --target "$MOUNT" 2>/dev/null || true)
if [ -z "$DEV" ]; then
  echo "Could not resolve device from mountpoint. Showing block devices and mounts for manual selection:"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
  echo
  echo "If you know the device (example /dev/sdb1) set DEV and re-run."
  exit 1
fi
echo "Device is: $DEV"
echo

echo "2) Show processes using the mount (if any):"
sudo lsof +D "$MOUNT" 2>/dev/null || true
sudo fuser -vm "$MOUNT" 2>/dev/null || true
echo

# Try to unmount cleanly
echo "3) Attempting clean unmount of $MOUNT ..."
if sudo umount "$MOUNT"; then
  echo "Unmounted successfully."
else
  echo "Unmount failed (target busy). Will try to kill processes using the mount (fuser -km) and unmount again."
  sudo fuser -km "$MOUNT" || true
  sleep 1
  # try normal unmount again, then lazy as fallback
  if sudo umount "$MOUNT"; then
    echo "Unmounted after killing processes."
  else
    echo "Normal unmount still failed — trying lazy unmount (umount -l)."
    sudo umount -l "$MOUNT"
    echo "Lazy unmount issued."
  fi
fi
echo

# Re-evaluate the device node (it should still be same)
if [ -b "$DEV" ]; then
  echo "Device node $DEV exists."
else
  echo "Warning: device node $DEV not found. Listing block devices for you:"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL
  echo "If the device node changed, find the correct device (e.g. /dev/sdb1) and set DEV accordingly, then re-run fsck."
  exit 1
fi

# 4) Non-destructive check first
echo "4) Running non-destructive exFAT check (no changes):"
sudo fsck.exfat -n "$DEV" || true

echo
read -rp "If the above report shows fixable errors and you want to repair them, type 'repair' now (or Enter to skip): " CH
if [ "$CH" = "repair" ]; then
  echo "Running exfatfsck to repair (may modify filesystem) ..."
  sudo fsck.exfat "$DEV"
  echo "Repair finished."
else
  echo "Skipping repair step."
fi
echo

# 5) Remount with uid/gid so you (salman) own files on mount (adjust if you want group different)
echo "6) Remounting $DEV on $MOUNT with your UID/GID to give you ownership."
# ensure mountpoint exists
sudo mkdir -p "$MOUNT"
sudo mount -o uid=$(id -u salman),gid=$(id -g salman),umask=0022 "$DEV" "$MOUNT"
echo "Remounted. Now listing permissions:"
ls -ld "$MOUNT"
ls -l "$MOUNT" | sed -n '1,40p'
echo
echo "If everything looks good, you can now run chown/chmod on other directories (e.g. recovery folder)."


