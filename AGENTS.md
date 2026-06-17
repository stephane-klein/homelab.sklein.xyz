# Agent Instructions

## Language Policy

- **All project content must be in English**: source code, comments, commit messages, and documentation.
- **Human conversations in OpenCode remain in French**.

## Architecture Overview

This project provisions Fedora CoreOS bare-metal servers and manages the Netbird
VPN mesh network that connects them.

### Netbird management with OpenTofu

[Netbird](https://netbird.io/) provides the WireGuard-based VPN mesh for all
devices (servers, laptops, phones) in the homelab. The network configuration is
managed declaratively with [OpenTofu](https://opentofu.org/) via the
[terraform-provider-netbird](https://github.com/netbirdio/terraform-provider-netbird).

Key choices:

- **OpenTofu over Terraform** — fully open-source (Apache 2.0), community-driven
  under Linux Foundation governance.
- **Local state backend** — `terraform.tfstate` at the project root (gitignored).
- **Provider version pinned** — `~> 0.0.9` in `versions.tf`.
- **Manual workflow** — `tofu init && tofu apply` is run manually.

### Resource structure

- **`homelab-servers`** group — the two NUC servers.
- **`user-devices`** group — personal devices (fp5 phone, t14s laptop).
- Policies enforce unidirectional access: user devices reach servers, servers
  cannot initiate connections to user devices.
- **Netbird SSH proxy** (`ssh_enabled`, `netbird-ssh` protocol) avoids manual
  SSH key distribution — user identities are managed in Netbird.
- **Setup keys** are created by `tofu apply` and extracted via `tofu output -raw`.

### Secret detection with gitleaks

[Gitleaks](https://github.com/gitleaks/gitleaks) prevents committing secrets
accidentally. It runs as:

- **Git pre-commit hook** (`git-hooks/pre-commit`) — checks staged files on `git commit`.
- **`mise run gitleaks-check-push`** — scan the whole project before `jj git push`.
- **`jj publish`** — local alias that updates the `main` bookmark, runs gitleaks, then pushes.

Configuration:

- `.gitleaks.toml` — extends default rules with lower entropy threshold (2.0 vs 3.5)
  for `generic-api-key`, and allowlists for known safe paths (`.secret`, `certs/`,
  `*.tfstate*`, `README.md`).
- Gitleaks is installed via `mise` and pinned to version `8.30.1`.

Setup (one-time, after clone):

```
mise install
mise run setup-git-hooks
mise run setup-jj-alias
```

## Config directory

Service-specific configuration files live in `config/<service>/` (e.g.,
`config/perses/values.yaml`). The `scripts/` directory contains only
executable scripts. Scripts reference config via relative paths:
`-f config/perses/values.yaml`.

### Authelia

[Authelia](https://www.authelia.com/) provides SSO authentication before
Traefik via a `ForwardAuth` middleware. Configuration lives in
`config/authelia/`. Access control rules use a wildcard
(`*.sklein.internal`, `one_factor`) so any new subdomain is automatically
protected.

### Provisioning workflow

1. `mise run setup-secret` — populate `.secret` from Gopass
2. `tofu init && tofu apply` — apply Netbird configuration
3. `tofu output -raw setup_key_nuc_i3_gen5 >> .secret` — extract setup keys
4. `./nuc-*/create-custom-iso.sh` — build Fedora CoreOS ISO
