#!/usr/bin/env osh
set -e

cd "$(dirname "$0")/"

mkdir -p images/

tmpdir=$(mktemp -d)

... coreos-installer download
    -s stable
    -a x86_64
    -p metal
    -f iso
    -d
    -C "$tmpdir";

mv "$tmpdir"/* images/fedora-coreos-live-iso.x86_64.iso
rmdir "$tmpdir"

export NUC_I7_GEN11_STEPHANE_PASSWORD_HASH="$(echo \"${NUC_I7_GEN11_STEPHANE_PASSWORD}\" | mkpasswd --method=yescrypt -s)"

gomplate -f coreos-custom-iso-config.bu.tmpl -o coreos-custom-iso-config.bu
butane coreos-custom-iso-config.bu > coreos-custom-iso-config.ign

rm -f images/fedora-coreos-for-nuc-i7-gen11.iso

... coreos-installer iso customize
    --pre-install run-wipefs.sh
    --dest-ignition coreos-custom-iso-config.ign
    --dest-console ttyS0,115200n8
    --dest-console tty0
    --dest-device /dev/nvme0n1
    --live-karg-append "vconsole.keymap=fr-bepo locale.LANG=fr_FR.UTF-8"
    -o images/fedora-coreos-for-nuc-i7-gen11.iso
    images/fedora-coreos-live-iso.x86_64.iso;

cat << 'EOF' 
CoreOS custom iso builded in: images/fedora-coreos-for-nuc-i7-gen11.iso

Execute:

$ ./write-to-usb-interactive.sh

to write ISO image on USB key
EOF
