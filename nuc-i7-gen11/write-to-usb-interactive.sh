#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/"

ISO_PATH="images/fedora-coreos-for-nuc-i7-gen11.iso"

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
    echo "Usage: $0 <iso-file>"
    exit 1
fi

echo "=== Fedora USB Writer ==="
echo "ISO: $ISO_PATH"
echo ""

# Detect USB drives
mapfile -t usb_drives < <(lsblk -d -n -o NAME,TRAN | grep usb | awk '{print "/dev/"$1}')

if [[ ${#usb_drives[@]} -eq 0 ]]; then
    echo "No USB drives found. Please insert one and try again."
    exit 1
fi

# Display options
echo "Available USB drives:"
i=1
for drive in "${usb_drives[@]}"; do
    info=$(lsblk -n -o SIZE,VENDOR,MODEL "$drive" 2>/dev/null | head -1)
    echo "  $i) $drive ($info)"
    ((i++))
done

echo ""
read -p "Select drive [1-${#usb_drives[@]}]: " selection

if [[ ! $selection =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#usb_drives[@]} ]]; then
    echo "Invalid selection"
    exit 1
fi

DEVICE="${usb_drives[$((selection-1))]}"

# Unmount any mounted partitions
echo "Unmounting partitions..."
sudo umount "${DEVICE}"?* 2>/dev/null || true

# Write ISO
echo "Writing ISO to $DEVICE..."
sudo dd if="$ISO_PATH" of="$DEVICE" bs=64M oflag=direct status=progress

echo ""
echo "✓ Done! USB drive is ready."
