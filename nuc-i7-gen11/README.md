# NUC i7 gen11

Hardware specifications:

- Model: [NUC11PAH](https://www.intel.com/content/dam/support/us/en/documents/intel-nuc/NUC11PA_TechProdSpec.pdf)
- CPU: A soldered-down 11th generation Intel® Core™ i7-1165G7 quad-core processor with up to a maximum 28 W TDP
- RAM: 32go ram
- SSD: 1To
- Maximum power: 28W

Product sheet on LDLC Website: https://www.ldlc.com/fiche/PB00405633.html

## NanoKVM

A [NanoKVM](https://wiki.sipeed.com/hardware/en/kvm/NanoKVM/quick_start.html) is plugged into NUC's USB and HDMI ports.

## Provision NUC i7 gen11 server

Apply prerequisites in [`../README.md`](../README.md).

Next, execute:

```sh
$ ./create-custom-iso.sh
Downloading Fedora CoreOS stable x86_64 metal image (iso) and signature
> Read disk 964.0 MiB/964.0 MiB (100%)
gpg: Signature faite le sam. 25 oct. 2025 06:46:36 CEST
gpg:                avec la clef RSA B0F4950458F69E1150C6C5EDC8AC4916105EF944
gpg: Bonne signature de « Fedora (42) <fedora-42-primary@fedoraproject.org> » [ultime]
/tmp/tmp.j18BeeZXOB/fedora-coreos-42.20251012.3.0-live-iso.x86_64.iso
Boot media will automatically install to /dev/nvme0n1 without confirmation.
CoreOS custom iso builded in: images/fedora-coreos-for-nuc-i7-gen11.iso
```

Next, plug USB key on workstation and execute:

```sh
$ ./write-to-usb-interactive.sh
=== Fedora USB Writer ===
ISO: images/fedora-coreos-for-nuc-i7-gen11.iso

Available USB drives:
  1) /dev/sda (14,5G Generic  STORAGE DEVICE)

Select drive [1-1]: 1
Unmounting partitions...
[sudo] Mot de passe de stephane :
Writing ISO to /dev/sda...
335544320 octets (336 MB, 320 MiB) copiés, 49 s, 6,9 MB/s

1010827264 octets (1,0 GB, 964 MiB) copiés, 145 s, 7,0 MB/s
15+1 enregistrements lus
15+1 enregistrements écrits
1010827264 octets (1,0 GB, 964 MiB) copiés, 145,745 s, 6,9 MB/s

✓ Done! USB drive is ready.
```

Now, plug bootable USB key on server and reboot on this device.

The installation is performed in two steps, requiring two reboots.

After installation, connect to the server with SSH:

```sh
$ ssh stephane@192.168.1.126
Fedora CoreOS 42.20251012.3.0
Tracker: https://github.com/coreos/fedora-coreos-tracker
Discuss: https://discussion.fedoraproject.org/tag/coreos

Last login: Tue Nov 11 21:16:37 2025
stephane@stephane-coreos:~$ rpm-ostree status
State: idle
AutomaticUpdatesDriver: Zincati
  DriverState: active; periodically polling for updates (last checked Tue 2025-11-11 20:16:37 UTC)
Deployments:
● ostree-image-signed:docker://quay.io/fedora/fedora-coreos:stable
                   Digest: sha256:1693b47dfccebdde19e81c3d0a0392010f0ec67e827f096d1b3f8aec662eb5cf
                  Version: 42.20251012.3.0 (2025-10-25T02:24:05Z)
          LayeredPackages: htop neovim

  ostree-image-signed:docker://quay.io/fedora/fedora-coreos:stable
                   Digest: sha256:1693b47dfccebdde19e81c3d0a0392010f0ec67e827f096d1b3f8aec662eb5cf
                  Version: 42.20251012.3.0 (2025-10-25T02:24:05Z)
```
