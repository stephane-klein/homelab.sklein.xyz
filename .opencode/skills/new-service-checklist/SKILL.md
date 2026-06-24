# New service deployment checklist

Checklist to follow when deploying a new k3s workload with Helmfile in this project:

1. Load the global skill `sklein-helper-scripts` — it defines the script boilerplate convention
2. `helmfile/values/<service>.yaml` — create values file
3. `helmfile/helmfile.yaml.gotmpl` — add release at the **end** of the `releases:` list
4. `scripts/deploy-<service>.sh` — create deploy script (see `sklein-helper-scripts` for boilerplate)
5. `scripts/destroy-<service>.sh` — same conventions
6. `.mise.toml` — add `[tasks.deploy-<service>]` and `[tasks.destroy-<service>]` at the end
7. `README.md` — add a section for the service

## Reminders

- Releases go at the end of `helmfile/helmfile.yaml.gotmpl`, not the beginning
- Scripts must be `chmod +x`
- Mise tasks go at the end of `.mise.toml`
- `run` commands in mise are relative to `{{config_root}}`
