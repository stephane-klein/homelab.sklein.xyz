---
status: accepted
date: 2026-08-19
decision-makers:
  - Stéphane Klein
ai-assistants:
  - DeepSeek V4 Flash (OpenCode Go)
---

# ADR 001 — Per-application Helmfile directories

## Context and Problem Statement

I declare all Helm releases for the homelab in a single
`helmfile/helmfile.yaml.gotmpl` aggregating 8 releases (memex, toggl-pg-mirror,
mosquitto, zigbee2mqtt, hindsight-cnpg, hindsight, grafana, …).

Every `scripts/deploy-<service>.sh` invokes `helmfile -f helmfile/helmfile.yaml.gotmpl apply`,
which evaluates **all** releases. This couples every service to every other one:
a broken or misconfigured unrelated release can block an unrelated deployment.
Destroying a single release requires `helmfile destroy --selector name=<release>`,
a footgun reflected in a project safety rule in `AGENTS.md`.

While working on `playground/sveltekit-ssr-skeleton/`, I realised that
application secrets cannot be created declaratively by Helmfile and must be
created with `kubectl create secret` (values pulled from Gopass). This means a
script is required in every case to deploy an application. If a script is
needed anyway, I prefer **one script per application**. I also prefer to group
each application's script together with its values and configuration into a
single self-contained directory per application
([colocated code](https://notes.sklein.xyz/Colocated%20code/)).

## Decision Drivers

- Secret creation requires `kubectl create secret`, so a deploy script is
  mandatory for every application. Since a script is required anyway, I prefer
  **one script per application**, and I prefer to group each script with its
  values into one self-contained directory per application.
- Decouple services from each other so deploying one cannot be blocked by another.
- Make each application self-contained (chart, values, secrets, tasks, docs in one place).
- Scope `helmfile destroy` naturally, without needing `--selector name=`.
- Keep the existing manual workflow (scripts + mise tasks), no GitOps controller.

## Considered Options

- Option 1: Keep the single monolith `helmfile/helmfile.yaml.gotmpl`.
- Option 2: One self-contained directory per application, on the model of
  `playground/sveltekit-ssr-skeleton/`, hosted under `apps/<app>/`.
- Option 3: Adopt a GitOps controller (ArgoCD / Flux).

## Decision Outcome

Chosen option: "Option 2 — per-application directory under `apps/<app>/`",
because it decouples services, scopes destroy naturally, and keeps the manual
workflow while matching the mainstream GitOps layout convention.

Flux remains a candidate for a future evaluation; the per-application directory
layout is chosen now and is compatible with a later migration to a GitOps
controller (e.g. Flux).

Each `apps/<app>/` directory contains:

- `helmfile.yaml` — the single release definition for the app
- `values.yaml` — Helm values
- `scripts/deploy.sh` — creates namespace/secrets from Gopass, then `helmfile apply`
- `scripts/destroy.sh` — `helmfile destroy` (naturally scoped)
- `.mise.toml` — deploy/destroy tasks
- `README.md` — deployment instructions and dependencies

### Consequences

- Good, because releases are independent; `helmfile apply` only touches one app.
- Good, because `helmfile destroy` is scoped by construction (no `--selector` needed).
- Good, because each app carries its own secret-creation logic next to its values.

## Pros and Cons of the Options

### Option 1 — Single monolith helmfile

- Good, because a single overview of all releases.
- Bad, because deploying one service evaluates and can be blocked by all others.
- Bad, because destroy requires `--selector name=` (error-prone).
- Bad, because the secret-creation script for a service is far from its values.

### Option 2 — Per-application directory (`apps/<app>/`)

- Good, because full decoupling and self-containment (script + values + secrets together).
- Good, because destroy is scoped by construction.

### Option 3 — Flux (GitOps controller)

- Good, because declarative reconciliation and git-as-source-of-truth.
- Good, because it would remove the need for manual deploy scripts.
- Bad, because introduces a new control plane and diverges from the current
  manual workflow (scripts + mise tasks) used throughout the project.
- Not chosen for now, but planned to be evaluated in the future.
