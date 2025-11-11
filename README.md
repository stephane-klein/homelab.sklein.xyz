# homelab.sklein.xyz

The methods used in this repository are based on the content of [`atomic-os-playground`](https://github.com/stephane-klein/atomic-os-playground).

This repository contains the configuration files and scripts to create a bootable USB key for
automated and unattended Fedora CoreOS installation, on the following homelab NUC servers:

- [`NUC i3 gen 5`](https://notes.sklein.xyz/Serveur%20NUC%20i3%20gen%205/)
- [`NUC i7 gen 11`](https://notes.sklein.xyz/Serveur%20NUC%20i7%20gen%2011/)

Installation characteristics:

- Use Fedora CoreOS atomic distribution
- `/var/` mutable volume is encrypted with LUKS and unlock with TPM2 (Tang coming soon)

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

Fill the `.secret` file with the secret from my Bitwarden vault.

```sh
$ direnv allow
```

### Server provisionning

Go to:

- [`./nuc-i3-gen5/README.md`](./nuc-i3-gen5/)
- [`./nuc-i7-gen11/README.md`](./nuc-i7-gen11/)
