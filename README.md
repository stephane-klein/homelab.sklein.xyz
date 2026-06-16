# homelab.sklein.xyz

The methods used in this repository are based on the content of [`atomic-os-playground`](https://github.com/stephane-klein/atomic-os-playground).

This repository contains the configuration files and scripts to create a bootable USB key for
automated and unattended Fedora CoreOS installation, on the following homelab NUC servers:

- [`NUC i3 gen 5`](https://notes.sklein.xyz/Serveur%20NUC%20i3%20gen%205/)
- [`NUC i7 gen 11`](https://notes.sklein.xyz/Serveur%20NUC%20i7%20gen%2011/)

Installation characteristics:

- Use Fedora CoreOS atomic distribution
- `/var/` mutable volume is encrypted with LUKS and unlock with TPM2 (Tang coming soon)
- Servers automatically join the [Netbird](https://netbird.io/) VPN mesh network (managed by OpenTofu)

## Getting started

### Prerequisites

I install this prerequisites on my Fedora Workstation:

```
$ sudo dnf install \
    mise \
    butane \
    coreos-installer
```

To improve my developer experience, I like to use [Oils](https://oils.pub/) shell.
To install it, I follow instructions: <https://github.com/oils-for-unix/oils/wiki/Oils-Deployments>.

```
$ mise install
```

### Set secret file

```sh
$ cp .secret.skel .secret
```

For Stéphane Klein (gopass user), generate `.secret` directly from the Gopass store:

```bash
$ mise run setup-secret
```

### Netbird VPN configuration with OpenTofu

The [Netbird](https://netbird.io/) VPN mesh is configured using [OpenTofu](https://opentofu.org/)
via the [`terraform-provider-netbird`](https://github.com/netbirdio/terraform-provider-netbird).

Prerequisites:

- `NB_PAT` must be present in `.secret` (Netbird Personal Access Token — generate one in
  Settings → API Keys)
- OpenTofu is automatically installed by `mise` (defined in `.mise.toml`)

```bash
$ tofu init
$ tofu apply
```

This manages the following resources:

- **Groups**: `homelab-servers` (the two NUCs) and `user-devices` (laptop, phone)
- **Peers**: SSH enabled on servers via Netbird SSH proxy (no manual SSH key distribution)
- **Policies**: unidirectional access — user devices can reach servers, servers cannot
  initiate connections to user devices
- **Setup keys**: generated for ISO builds

To list existing resources and their IDs (useful for `tofu import`):

```bash
$ ./scripts/list-netbird-resources.sh
```

### Server provisionning

Go to:

- [`./nuc-i3-gen5/README.md`](./nuc-i3-gen5/)
- [`./nuc-i7-gen11/README.md`](./nuc-i7-gen11/)

## Private CA for internal services

A private Certificate Authority is used to issue trusted TLS certificates for internal
services (Cockpit, etc.). This avoids browser warnings for self-signed certificates.

### Create the CA (once)

```sh
$ ./scripts/setup-ca.sh
  Generating CA key...
  Generating CA certificate...
  CA created: certs/ca/ca.crt

To trust this CA on Fedora:
  sudo cp certs/ca/ca.crt /etc/pki/ca-trust/source/anchors/homelab-ca.crt
  sudo update-ca-trust
```

### Trust the CA on your workstation (Fedora)

```sh
$ sudo cp certs/ca/ca.crt /etc/pki/ca-trust/source/anchors/homelab-ca.crt
$ sudo update-ca-trust
```

The CA is now trusted system-wide, including Firefox (uses the system trust store)
and Chromium/Chrome.
