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

Deployed services:

- **Network**
  - [Netbird](https://github.com/netbirdio/netbird) VPN mesh (managed by OpenTofu)
  - Static IPv6 `::1000` on `nuc-i7-gen11` for public internet ingress
- **Kubernetes cluster**
  - [k3s](https://github.com/k3s-io/k3s) multi-node
  - [Traefik](https://github.com/traefik/traefik) (ingress controller)
  - [cert-manager](https://github.com/cert-manager/cert-manager) (TLS certificates)
  - [Authelia](https://github.com/authelia/authelia) (SSO authentication)
  - [CloudNativePG](https://cloudnative-pg.io/) (PostgreSQL operator with backup to Scaleway Object Storage)
  - [External Secrets Operator](https://external-secrets.io/) (cross-namespace secret sharing)
- **Environment monitoring**
  - [Mosquitto](https://mosquitto.org/) — MQTT broker for IoT sensor data
  - [Zigbee2MQTT](https://www.zigbee2mqtt.io/) — Zigbee coordinator at `https://zigbee2mqtt.sklein.internal`
  - MQTT → VictoriaMetrics bridge (Python, deployed as k8s Deployment)
  - **Hardware**:
    - [SONOFF ZBDongle-E](https://sonoff.tech/fr-fr/products/sonoff-zigbee-3-0-usb-dongle-plus-zbdongle-e) — USB Zigbee coordinator (EFR32MG21, `ember` driver), plugged on `nuc-i7-gen11`
    - 2× [SONOFF SNZB-02D](https://sonoff.tech/fr-fr/products/sonoff-snzb-02d-zigbee-lcd-smart-temperature-humidity-sensor) — temperature & humidity sensors with LCD display (Zigbee 3.0, CR2450 battery)
- **AI / Agent memory**
  - [Hindsight](https://github.com/vectorize-io/hindsight) at `https://hindsight.sklein.internal`
    — agent memory system with pgvector + pg_search (ParadeDB)
- **Application dashboard**
  - [Homepage](https://gethomepage.dev/) at `https://homepage.sklein.internal`
    — central dashboard with Kubernetes resources, per-node CPU/RAM/disk metrics
    via VictoriaMetrics PromQL, and a disk gauge for `/var`
- **Monitoring**
  - [VictoriaMetrics](https://github.com/VictoriaMetrics/VictoriaMetrics) (metric store)
  - [vmagent](https://github.com/VictoriaMetrics/VictoriaMetrics) (metric scraping)
  - [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) (cluster state metrics)
  - [prometheus-node-exporter](https://github.com/prometheus/node_exporter) (per-node system metrics)
  - [Perses](https://github.com/perses/perses) (dashboards)
  - [Perses Operator](https://github.com/perses/perses-operator) (CRD management)

My databases:

- Memex

## Roadmap

Here are some service ideas I plan to deploy on my homelab.

- [x] **Database operator**: [CloudNativePG](https://cloudnative-pg.io/) — with backup to Scaleway Object Storage
- [x] **Agent memory system**: [Hindsight](https://github.com/vectorize-io/hindsight) - agents that learn over time, not just remember
- [ ] [Deploy Netbird Reverse Proxy (self-hosted) on nuc-i7-gen11 for public HTTPS ingress](https://github.com/stephane-klein/homelab.sklein.xyz/issues/1)
- [ ] **Internal certificate authority**: [step-ca](https://github.com/smallstep/certificates) [untested]
- [ ] **GPS tracking server**: [gpstracker](https://git.fabiomanganiello.com/gpstracker) - connected to [GPSLogger for Android](https://github.com/mendhak/gpslogger/) [untested]
- [ ] **File sync & share**: [Nextcloud](https://nextcloud.com/) - with backup on Scaleway Object Storage
- [ ] **RSS feed reader**: [Miniflux](https://miniflux.app/)
- [ ] **Virtual machine management**: [KubeVirt](https://kubevirt.io/) [untested]
  - [ ] **Development VM**: instance based on [sklein-devbox-chezmoi](https://github.com/stephane-klein/sklein-devbox-chezmoi) - to access OpenCode from my smartphone
- [ ] **LLM chat interface**: [OpenWebUI](https://github.com/open-webui/open-webui) or [LibreChat](https://github.com/danny-avila/LibreChat)
- [ ] **LLM provider proxy**: [LiteLLM](https://github.com/BerriAI/litellm) — centralizes LLM API calls (OpenAI, Anthropic, etc.), archives threads, and provides a single endpoint (self-hosted OpenRouter equivalent)
- [ ] **XMPP instant messaging server**: [ejabberd](https://github.com/processone/ejabberd)
  - [ ] **Team messaging**: [fluux-messenger](https://github.com/processone/fluux-messenger/) - Mattermost-like group chat built on XMPP, for communities and organizations [untested]
- [ ] **Autonomous AI agent framework**: [Hermes Agent](https://github.com/NousResearch/hermes-agent) [untested]
- [ ] **Dashboard / startpage**: [Glance](https://github.com/glanceapp/glance/)
- [ ] **Home automation platform**: [Home Assistant](https://www.home-assistant.io/) [untested]
- [ ] **Hike sharing**: [Wanderer](https://github.com/open-wanderer/wanderer) - self-hosted trail database to share hikes [untested]
- [ ] **Photo management**: [Memories](https://memories.gallery/) or [Immich](https://immich.app/) or [PhotoPrism](https://photoprism.org/) [untested]
- [ ] **Private metasearch engine**: [SearXNG](https://github.com/searxng/searxng)
  - [ ] possibly complemented by [Hister](https://hister.org) [untested]
- [ ] **File synchronization relay**: [syncthing](https://syncthing.net)
- [ ] **Backup server**: [Borg](https://www.borgbackup.org/) - TimeMachine-like backups for workstations via [Pika Backup](https://apps.gnome.org/PikaBackup/)
- [ ] **Email & message archiving**: [msgvault](https://www.msgvault.io/) — archive Fastmail (IMAP) and Gmail (Google API) locally, with fast keyword search and optional semantic search [untested]

I'm not sure I will actually deploy and use all these services. Some will likely be changed or dropped as I experiment.

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
$ cp .secret.tpl .secret
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

## Kubernetes cluster with k3s

> **Prerequisite:** the two servers must be provisioned first (see
> [Server provisioning](#server-provisionning) above).

A multi-node [k3s](https://k3s.io/) cluster spans the two servers:

| NUC | k3s role | Hardware |
|---|---|---|
| `nuc-i7-gen11` | **Server** (control-plane) | 32 GB RAM, 1 To SSD |
| `nuc-i3-gen5` | **Agent** (worker) | 8 GB RAM, 120 Go SSD |

### Generate the K3S token

```sh
$ mise run generate-k3s-token
```

This generates a random token via `openssl rand -base64 48` and writes
`K3S_TOKEN` to `.secret`.

### Deploy the cluster

```sh
$ ./scripts/deploy-k3s.sh
```

What the script does:

1. Installs k3s control-plane on `nuc-i7-gen11` — binds on the Netbird VPN IP (`wt0`),
   disables Traefik.
2. Waits for the Kubernetes API to be ready.
3. Installs k3s agent on `nuc-i3-gen5` — joins the server over the Netbird VPN.
4. Retrieves the kubeconfig to `./k3s.kubeconfig` (added to `.gitignore`).
5. Saves the kubeconfig to Gopass (`homelab/k3s.kubeconfig`).

```sh
$ mise run install-local-kubeconfig    # Restore from Gopass
$ mise run k3s-health
[k3s-health] $ bash scripts/k3s-health.sh
=== k3s Cluster Health Check ===

--- Nodes ---
NAME                                       STATUS   ROLES           AGE    VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                        KERNEL-VERSION                  CONTAINER-RUNTIME
nuc-i3-gen5.homelab.stephane-klein.info    Ready    <none>          150m   v1.36.1+k3s1   100.91.182.98   <none>        Fedora CoreOS 44.20260523.3.1   7.0.9-205.fc44.x86_64 (amd64)   containerd://2.2.3-k3s1
nuc-i7-gen11.homelab.stephane-klein.info   Ready    control-plane   14h    v1.36.1+k3s1   100.91.106.71   <none>        Fedora CoreOS 44.20260523.3.1   7.0.9-205.fc44.x86_64 (amd64)   containerd://2.2.3-k3s1

--- Control-plane components ---
NAME                 STATUS    MESSAGE   ERROR
etcd-0               Healthy   ok
scheduler            Healthy   ok
controller-manager   Healthy   ok

--- All pods ---
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-6648f7576f-d65zg                  1/1     Running   0          14h
kube-system   local-path-provisioner-58d557dc48-75wcc   1/1     Running   0          14h
kube-system   metrics-server-7c86f97b8d-b6dfc           1/1     Running   0          14h

--- Recent events (last 20) ---

--- Resource usage ---
NAME                                       CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
nuc-i3-gen5.homelab.stephane-klein.info    51m          2%       2079Mi          26%
nuc-i7-gen11.homelab.stephane-klein.info   99m          1%       1579Mi          4%

=== Done ===
```

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

## Ingress controller (Traefik)

[Traefik](https://traefik.io/) is the ingress controller. It listens on ports 80 and 443
via `hostPort` on `nuc-i7-gen11`. No LoadBalancer or additional nftables rules are needed.
The Netbird DNS wildcard `*.sklein.internal` (configured in `netbird-dns.tf`) resolves
all subdomains to the ingress node.

### Deploy

```sh
$ mise run deploy-traefik
```

This installs:

- `cert-manager` in the `cert-manager` namespace
- A `ClusterIssuer` named `homelab-ca` signed by the private CA in `certs/ca/`
- Traefik in the `traefik` namespace, pinned to `nuc-i7-gen11` via the label
  `node-role.kubernetes.io/ingress=true`

### Destroy

```sh
$ mise run destroy-traefik
```

This removes Traefik, cert-manager, and the ClusterIssuer.

### Disable k3s ServiceLB (optional)

Since Traefik no longer uses a LoadBalancer service, the k3s ServiceLB
controller is no longer needed. To disable it:

```sh
$ mise run disable-servicelb
```

This SSHes into `nuc-i7-gen11`, adds `servicelb` to the k3s `disable` list,
and restarts the k3s server. The cluster is briefly unavailable (~30s).

> Test the ingress connectivity with a whoami application —
> see [`playground/README.md`](./playground/README.md).

### Deploying your own apps

Any workload can be exposed by creating an `Ingress` resource with a host under
`*.sklein.internal` (e.g. `myapp.sklein.internal`). cert-manager automatically
issues a TLS certificate signed by the private CA.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    cert-manager.io/cluster-issuer: homelab-ca
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - myapp.sklein.internal
    secretName: myapp-tls
  rules:
  - host: myapp.sklein.internal
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

### Authentication with Authelia

[Authelia](https://www.authelia.com/) protects apps by requiring
authentication before Traefik routes the request. Once deployed, add the
annotation `traefik.ingress.kubernetes.io/router.middlewares:
traefik-forwardauth-authelia@kubernetescrd` to any Ingress to protect it.

```sh
$ mise run deploy-authelia
```

Users (credentials in `.secret`) authenticate via `https://auth.sklein.internal`.
The user database lives in `config/authelia/users.yml` (gitignored). After
manual edits, push changes to the running pod:

```sh
$ mise run push-authelia-config
```

> See [`playground/README.md`](./playground/README.md) for an Authelia authentication demo.

## IPv6 ingress exposure

A static IPv6 address (`::1000`) is assigned to `nuc-i7-gen11` to make the
Traefik ingress reachable from the Internet over IPv6. The address is
derived from the server's prefix (first 4 hextets of the global unicast
address), which is dynamically detected.

The static address is configured at first boot via a systemd oneshot unit
in the CoreOS Butane config (`nuc-i7-gen11/coreos-custom-iso-config.bu.tmpl`).
For already-provisioned servers, run:

```sh
$ mise run assign-static-ipv6
```

This SSHes into `nuc-i7-gen11` and adds the address via `nmcli`.

## External Secrets Operator

[External Secrets Operator](https://external-secrets.io/) synchronises secrets from
external APIs into Kubernetes. It is used to replicate secrets across namespaces
(e.g., sharing the Memex database password with other workloads).

```sh
$ mise run deploy-external-secrets
```

## CloudNativePG Operator

[CloudNativePG](https://cloudnative-pg.io/) is the PostgreSQL operator. It manages PostgreSQL
clusters on Kubernetes, with built-in backup to S3-compatible object storage (Scaleway).

```sh
$ mise run deploy-cnpg
```

Verify:

```sh
$ kubectl get deployment -n cnpg-system
$ kubectl get crd | grep cloudnative-pg
```

This installs:

- **CloudNativePG operator** in the `cnpg-system` namespace, pinned to `nuc-i7-gen11`
- Webhook TLS certificates managed by the operator (self-signed CA)
- Requires `CNPG_BACKUPS_ACCESS_KEY` and `CNPG_BACKUPS_SECRET_KEY` in `.secret`,
  and `CNPG_BACKUPS_BUCKET` + `CNPG_BACKUPS_REGION` in `config/cnpg/env`

> See [`playground/README.md`](./playground/README.md) for CloudNativePG admin operations.

### Destroy CNPG operator

```sh
$ mise run destroy-cnpg
```

This removes the operator and the `cnpg-system` namespace.

## Monitoring

[VictoriaMetrics](https://victoriametrics.com/) (single-node) provides the metric store, [Perses](https://perses.dev/) provides the dashboards, and [vmagent](https://docs.victoriametrics.com/vmagent/) handles metric scraping.

Access:
- Metrics API: `https://metrics.sklein.internal`
- Perses dashboards: `https://perses.sklein.internal`

### Deploy

```sh
# 1. Metrics storage
$ mise run deploy-victoria-metrics

# 2. Exporters + vmagent (scraping)
$ mise run deploy-exporters

# 3. Perses dashboards
$ mise run deploy-perses
```

This installs:

- **VictoriaMetrics** — single-node TSDB, retention 30d, PVC 10Gi
- **kube-state-metrics** — Kubernetes cluster state metrics
- **prometheus-node-exporter** — per-node system metrics (CPU, memory, disk)
- **vmagent** — lightweight scrape agent, sends data to VictoriaMetrics via remote write
- **Perses** — dashboard UI at `https://perses.sklein.internal`
- **Perses Operator** — manages datasources and dashboards via ConfigMaps
- **Custom dashboards** — node-hardware and node-overview, deployed from `perses/dashboards/`

### Clean up

```sh
$ mise run destroy-perses
$ mise run destroy-exporters
$ mise run destroy-victoria-metrics
```

### Dashboards

Dashboards are defined as YAML files in `perses/dashboards/` and synced
to the cluster via ConfigMaps labeled `perses.dev/resource: "true"`. The Perses
operator watches these ConfigMaps and syncs them to the Perses internal database
under the `homelab` project.

**Push (local → cluster):**

```sh
$ mise run push-perses-dashboards
```

This creates or updates ConfigMaps from each `perses/dashboards/*.yaml` and
removes dashboards that no longer exist locally. No need to redeploy Perses.

**Pull (UI → local):**

After editing dashboards in the Perses UI, pull them back to YAML:

```sh
$ mise run pull-perses-dashboards
```

This reaches Perses internally via `kubectl port-forward` (bypassing Authelia)
and saves each dashboard to `perses/dashboards/<name>.yaml`.

## Homepage — Application Dashboard

[Homepage](https://gethomepage.dev/) is a centralized dashboard

**Access:** `https://homepage.sklein.internal`

Deploy:

```sh
$ mise run deploy-homepage
```

Destroy:

```sh
$ mise run destroy-homepage
```

### Configuration

The YAML configuration lives in `config/homepage/values.yaml`.
Deployed behind Traefik, Homepage automatically benefits from TLS
certificates (cert-manager) and Authelia authentication
(`forwardauth-authelia` middleware).

## Zigbee Environment Monitoring

Temperature and humidity monitoring via Zigbee sensors, deployed in the `zigbee` namespace.

**Architecture:** Zigbee2MQTT (k3s StatefulSet) → Mosquitto (k3s Service) → Python bridge → VictoriaMetrics

**Access:**
- Zigbee2MQTT UI: `https://zigbee2mqtt.sklein.internal`
- Metrics dashboard: `zigbee-sensors` in Perses (`https://perses.sklein.internal`)

**Deploy:**

```sh
$ mise run deploy-zigbee
```

**Pair a sensor:**

1. Open `https://zigbee2mqtt.sklein.internal`
2. Click **Permit Join**
3. Hold the button on the back of the SNZB-02D for 5 seconds
4. The sensor appears in the UI within a few seconds
5. Disable Permit Join

**Destroy:**

```sh
$ mise run destroy-zigbee
```

**Configuration files:**

- `helmfile/values/zigbee2mqtt.yaml` — Zigbee2MQTT Helm values
- `helmfile/values/mosquitto.yaml` — Mosquitto Helm values
- `config/zigbee/bridge.py` — Python bridge script (MQTT → VictoriaMetrics)

## Managed databases

Databases deployed with CloudNativePG:

### Memex

Deploy `Memex`:

```sh
$ mise run deploy-cnpg-memex
```

Get the password:

```sh
$ kubectl get secret memex-cluster-memex -n memex \
    -o jsonpath='{.data.password}' | base64 -d
```

Connect:

```sh
$ kubectl cnpg psql memex-cluster -n memex
```

List backups:

```sh
$ mise run list-cnpg-memex-backups
```

Trigger an immediate backup:

```sh
$ mise run backup-cnpg-memex
```

Delete a backup (by name):

```sh
$ mise run delete-cnpg-memex-backup <backup-name>
```

Destroy:

```sh
$ mise run destroy-cnpg-memex
```

### Hindsight

[Hindsight](https://github.com/vectorize-io/hindsight) is an agent memory
system that persists context, learns from interactions, and provides MCP tools
for agents (OpenCode, Claude Code, etc.).

Hindsight use PostgreSQL with pgvector + pg_search ([ParadeDB](https://github.com/paradedb/paradedb)).

#### Model Configuration


| Component | Provider | Model | Price (as of 2026-07-01) |
|---|---|---|---|
| LLM | OpenCode Go | `deepseek-v4-flash` | via [OpenCode Go](https://opencode.ai/docs/en/go/#usage-limits) |
| Embeddings | DeepInfra | `Qwen/Qwen3-Embedding-8B` (1024d) | $0.01 / 1M tokens |
| Reranker | OpenRouter → Cohere | `cohere/rerank-4-fast` | $0.001 / search |

Config: [`helmfile/values/hindsight.yaml`](helmfile/values/hindsight.yaml)

#### Deploy the CNPG cluster (once)

```sh
$ mise run deploy-cnpg-hindsight
```

Get the database password:

```sh
$ kubectl get secret hindsight-cnpg-cluster-app -n hindsight \
    -o jsonpath='{.data.password}' | base64 -d
```

Connect:

```sh
$ kubectl cnpg psql hindsight-cnpg-cluster -n hindsight
```

#### Deploy the Hindsight app

```sh
$ mise run deploy-hindsight
```

#### Backup

Logical backups (`pg_dump -Fc`) are taken nightly at 3am Paris time,
uploaded to Scaleway S3 (`homelab-cnpg-backups/hindsight-logical/`)
with 7-day retention via a Kubernetes CronJob.

```sh
$ mise run list-hindsight-backups                 # List backups on S3 + recent jobs
$ mise run backup-hindsight-now                   # Trigger an immediate backup
$ mise run verify-hindsight-backup                # Validate the latest backup (pg_restore -l)
$ mise run verify-hindsight-backup -- <file>      # Validate a specific backup file
```

#### Restore into a temporary local container

For testing purposes only, restore a backup into a temporary ParadeDB container with full pgvector + pg_search
support and an interactive `psql` session. The container is removed on exit.

```sh
$ mise run try-restore-hindsight-backup                 # Latest backup
$ mise run try-restore-hindsight-backup -- <file>       # Specific backup file
```

#### Destroy

Destroy the app (preserves the CNPG cluster):

```sh
$ mise run destroy-hindsight
```

Destroy everything (app + database):

```sh
$ mise run destroy-hindsight
$ mise run destroy-cnpg-hindsight
```

## toggl-pg-mirror

[toggl-pg-mirror](https://github.com/stephane-klein/toggl-pg-mirror) mirrors
Toggl time-tracking data into the Memex PostgreSQL database via a periodic
sync daemon. Tables are stored in the `toggl` schema.

```sh
$ mise run deploy-toggl-pg-mirror
```

Config: `helmfile/values/toggl-pg-mirror.yaml` 

## Contribution

### Secret detection with gitleaks

[Gitleaks](https://github.com/gitleaks/gitleaks) scans for secrets before they
reach the remote repository. It runs at two points:

- **`git commit`** — the `git-hooks/pre-commit` hook checks staged files.
- **`jj publish`** — local alias that runs `mise run gitleaks-check-push` before
  `jj git push`.

Both scans skip known safe paths (`.secret`, `certs/`, `*.tfstate*`,
`k3s.kubeconfig`, `README.md`) and use a lowered entropy threshold (2.0 vs 3.5)
for the `generic-api-key` rule.

Configuration is in `.gitleaks.toml`.

**One-time setup after clone:**

```
mise install
mise run setup-git-hooks
mise run setup-jj-alias
```

**Manual scan** (outside of hooks):

```
mise run gitleaks-scan        # full project scan
mise run gitleaks-check-push  # pre-push scan (called by `jj publish`)
```
