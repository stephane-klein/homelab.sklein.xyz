# NUC i3 gen5

Hardware specifications:

- Model: [`5i3MYHE`](https://www.intel.fr/content/www/fr/fr/products/sku/84860/intel-nuc-kit-nuc5i3myhe/specifications.html)
- CPU: [Intel Core i3-5010U CPU @ 2.10GHz](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Core+i3-5010U+%40+2.10GHz&id=2467)
- RAM: 8go ram
- SSD: 120go
- No TPM2 support

## Provision NUC i3 gen5 server

Apply prerequisites in [`../README.md`](../README.md).

Ensure `.secret` contains `NETBIRD_API_TOKEN` (create one in NetBird dashboard → Settings → API Keys), then generate a Netbird setup key for this machine:

```sh
$ ./scripts/prepare-netbird-key.sh
=== NetBird Setup Key Generator ===
  Machine: nuc-i3-gen5.homelab.stephane-klein.info
  Key type: one-time
  Secret file: ../.secret

Calling NetBird API...
  Key created: B808DE39...
  NUC_I3_GEN5_NETBIRD_SETUP_KEY written to: ../.secret
```

Next, execute:

```sh
$ ./create-custom-iso.sh
Downloading Fedora CoreOS stable x86_64 metal image (iso) and signature
> Read disk 964.0 MiB/964.0 MiB (100%)
gpg: Signature faite le sam. 25 oct. 2025 06:46:36 CEST
gpg:                avec la clef RSA B0F4950458F69E1150C6C5EDC8AC4916105EF944
gpg: Bonne signature de « Fedora (42) <fedora-42-primary@fedoraproject.org> » [ultime]
/tmp/tmp.BXqsNYMyjs/fedora-coreos-42.20251012.3.0-live-iso.x86_64.iso
Boot media will automatically install to /dev/nvme0n1 without confirmation.
CoreOS custom iso builded in: images/fedora-coreos-for-nuc-i3-gen5.iso
```

Next, plug USB key on workstation and execute:

```sh
$ ./write-to-usb-interactive.sh
=== Fedora USB Writer ===
ISO: images/fedora-coreos-for-nuc-i3-gen5.iso

Available USB drives:
  1) /dev/sda (14,5G Generic  STORAGE DEVICE)

Select drive [1-1]: 1
Unmounting partitions...
[sudo] Mot de passe de stephane :
Writing ISO to /dev/sda...
1010827264 octets (1,0 GB, 964 MiB) copiés, 142 s, 7,1 MB/s
15+1 enregistrements lus
15+1 enregistrements écrits
1010827264 octets (1,0 GB, 964 MiB) copiés, 142,078 s, 7,1 MB/s

✓ Done! USB drive is ready.
```

Now, plug bootable USB key on server and reboot on this device.

The installation is performed in two steps, requiring two reboots.

After installation, connect to the server with SSH:

```
$ ssh stephane@nuc-i3-gen5.homelab.stephane-klein.info
stephane@stephane-coreos:~$ rpm
rpm          rpm-ostree   rpm2archive  rpm2cpio     rpmdb        rpmkeys      rpmquery     rpmsort      rpmverify
stephane@stephane-coreos:~$ rpm-ostree status
State: idle
AutomaticUpdatesDriver: Zincati
  DriverState: active; periodically polling for updates (last checked Tue 2025-11-11 19:40:52 UTC)
Deployments:
●   ostree-image-signed:docker://quay.io/fedora/fedora-coreos:stable
                   Digest: sha256:1693b47dfccebdde19e81c3d0a0392010f0ec67e827f096d1b3f8aec662eb5cf
                  Version: 42.20251012.3.0 (2025-10-25T02:24:05Z)
          LayeredPackages: htop neovim

  ostree-image-signed:docker://quay.io/fedora/fedora-coreos:stable
                   Digest: sha256:1693b47dfccebdde19e81c3d0a0392010f0ec67e827f096d1b3f8aec662eb5cf
                  Version: 42.20251012.3.0 (2025-10-25T02:24:05Z)
```

## Post-installation: Cockpit web console

Install [Cockpit](https://cockpit-project.org/) on the server (accessible only via the Netbird VPN):

```sh
$ ./scripts/install-cockpit.sh
=== Cockpit Installation for nuc-i3-gen5.homelab.stephane-klein.info ===

--- Phase 1: Installation and configuration ---
--- Phase 2: Post-reboot configuration ---
  Waiting for host to come back up...
  Host is back online.
  Configuring firewall...
--- Phase 3: Netbird DNS configuration ---
  Looking up peer...
  Zone found: <zone-id>
  Creating DNS A record...
  Record created: <record-id>

=== Done ===
  Access Cockpit at: https://cockpit.nuc-i3-gen5.homelab.stephane-klein.info:9090
```

Prerequisites:
- `mise` must be installed (see [`../README.md`](../README.md))
- `minijinja-cli` is automatically installed by `mise` (defined in `.mise.toml`)
- `NETBIRD_API_TOKEN` must be present in `.secret` (loaded by `mise`)
- The server must be online and reachable via SSH on the Netbird VPN

For fresh provisioned machines (via `create-custom-iso.sh`), Cockpit is already included
in the Butane template — no manual script needed.
```
