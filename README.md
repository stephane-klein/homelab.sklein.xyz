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

```sh
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

### Test with whoami

Deploy a minimal test application:

```sh
$ mise run deploy-whoami
```

Access from any Netbird peer:

```sh
$ curl -k https://whoami.sklein.internal/
```

Or with the CA trusted system-wide:

```sh
$ curl https://whoami.sklein.internal/
```

You should see the whoami response (request headers and pod name).

### Clean up the test app

```sh
$ mise run destroy-whoami
```

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
- **Perses Operator** — manages datasources and dashboards via CRDs
- **Community dashboards** — Kubernetes cluster dashboards (pre-built from [community-mixins](https://github.com/perses/community-mixins))

### Clean up

```sh
$ mise run destroy-perses
$ mise run destroy-exporters
$ mise run destroy-victoria-metrics
```

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
