# Agent Instructions

## Language Policy

- **All project content must be in English**: source code, comments, commit messages, and documentation.
- **Human conversations in OpenCode remain in French**.

## Safety Rules

- **Never run any `destroy-*` script or `helmfile destroy` command without explicit user confirmation** in the same conversation turn. Always ask first.
- If you must run `helmfile destroy`, always use `--selector name=<release>` to target only one release.
- When in doubt about a command's destructiveness, ask before executing.

## Architecture Overview

This project provisions Fedora CoreOS bare-metal servers, runs a two-node k3s
cluster across them, and manages the Netbird VPN mesh that connects everything.

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

### k3s cluster

[k3s](https://k3s.io/) is the single runtime platform for all services. It is
installed post-OS via the official `get.k3s.io` script, driven by
`scripts/deploy-k3s.sh`.

- **nuc-i7-gen11** — control-plane (server) with embedded etcd
- **nuc-i3-gen5** — worker (agent)
- **Netbird-local networking** — k3s binds on the Netbird VPN IP (`wt0`)
  interface. systemd units have `After=netbird.service` so the cluster only
  starts after the VPN is up.
- **Built-in components disabled** — embedded Traefik and ServiceLB are turned
  off; two standalone Traefik instances deployed via Helm serve as ingress
  controllers (internal on Netbird VPN, public on IPv6).
  See [Internal (Netbird VPN) Ingress](#internal-netbird-vpn-ingress) and
  [Public Internet Ingress](#public-internet-ingress) sections in README.md.
- **Two ingress controllers** — one internal on the Netbird VPN IP
  (`traefik` ingressClass, private CA) and one public on the static
  IPv6 address `::1000` (`traefik-public` ingressClass, Let's Encrypt via
  Cloudflare DNS-01, external-dns for automatic AAAA records).
  **Default opt-in:** services use `ingressClassName: traefik` (internal);
  public exposure requires explicit `ingressClassName: traefik-public`.
- **Deployment pattern** — **Helmfile is preferred over raw `helm upgrade
  --install`** whenever possible (see [why](https://notes.sklein.xyz/2025-05-01_1622/)). New workloads should use Helmfile. Existing
  `helm upgrade --install` scripts are candidates for migration. See the
  [Helmfile](#helmfile) section below.

### Public Internet Ingress

The public-facing Traefik (`traefik-public`) binds on the static IPv6
address `2001:861:8b91:6620::1000` via hostNetwork. Services opt-in with
`ingressClassName: traefik-public`. TLS is automated via Let's Encrypt
(DNS-01, Cloudflare API token in `.secret`), and DNS records are managed
by external-dns (watches Ingress resources, creates AAAA records in
Cloudflare for `*.ipv6.ingress.homelab.public.stephane-klein.info`).

### Grafana

[Grafana](https://grafana.com/) is a dashboard visualization tool deployed via
Helmfile (`helmfile/helmfile.yaml.gotmpl`) at `https://grafana.sklein.internal`
(protected by Authelia — all `*.sklein.internal` subdomains are behind
`ForwardAuth`). Scripts interact with the Grafana API bypassing Authelia via
`kubectl port-forward -n grafana svc/grafana`, since the internal k8s service
does not require authentication. Dashboards are provisioned from JSON files in
`grafana/dashboards/` via ConfigMaps labeled `grafana_dashboard: "1"`.

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
`config/authelia/`). Services using Helmfile have their definition in
`helmfile/helmfile.yaml.gotmpl` and values in `helmfile/values/`. All services
deploy as k3s workloads via Helm. The `scripts/` directory contains only
executable scripts. Scripts reference config via relative paths or invoke
`helmfile -f helmfile/helmfile.yaml.gotmpl`.

### Helmfile

[Helmfile](https://helmfile.readthedocs.io/) is for Helm what `docker-compose.yml`
is for Docker — a declarative way to define, version, and apply Helm releases.
It is the preferred deployment method over raw `helm upgrade --install`.

- Definitions live in `helmfile/helmfile.yaml.gotmpl` (Go-templated).
- Values live in `helmfile/values/<release>.yaml`.
- Scripts invoke it as `helmfile -f helmfile/helmfile.yaml.gotmpl apply`.

### Authelia

[Authelia](https://www.authelia.com/) provides SSO authentication before
Traefik via a `ForwardAuth` middleware. It runs as a k3s workload in the
`authelia` namespace, deployed via `scripts/deploy-authelia.sh`. Configuration
lives in `config/authelia/`. Access control rules use a wildcard
(`*.sklein.internal`, `one_factor`) so any new subdomain is automatically
protected.

### .opencode/skills/new-service-checklist/SKILL.md

Checklist to follow when deploying a new service with Helmfile in this project.
Read this file before adding a new service.

### Provisioning workflow

1. `mise run setup-secret` — populate `.secret` from Gopass
2. `tofu init && tofu apply` — apply Netbird configuration
3. `tofu output -raw setup_key_nuc_i3_gen5 >> .secret` — extract setup keys
4. `./nuc-*/create-custom-iso.sh` — build Fedora CoreOS ISO
5. `./scripts/deploy-k3s.sh` — install k3s (server + agent) over SSH
6. `./scripts/deploy-traefik.sh` — deploy internal Traefik + cert-manager + private CA
7. `./scripts/deploy-traefik-public.sh` — deploy public Traefik on IPv6
8. `./scripts/deploy-cert-manager-issuer-public.sh` — deploy Let's Encrypt ClusterIssuer (DNS-01 via Cloudflare)
9. `./scripts/deploy-external-dns.sh` — deploy external-dns for automatic Cloudflare DNS records
