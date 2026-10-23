# SearXNG

[SearXNG](https://github.com/searxng/searxng) is a privacy-respecting metasearch engine.

## Chart choice

This app uses the `kubitodev/searxng` chart
([source](https://github.com/kubitodev/helm/tree/main/charts/searxng),
repository `https://charts.kubito.dev`).

## Dependencies

- A Gopass entry `homelab/searxng/secret-key`, read by the deploy script to
  create the `searxng` namespace Secret. Create it with:

  ```sh
  $ gopass insert -m homelab/searxng/secret-key <<< "$(openssl rand -hex 32)"
  ```

## Deploy

```sh
$ mise run //apps/searxng:deploy
```

The script ensures the namespace, creates the Secret from Gopass, then runs
`helmfile apply`.

## Destroy

```sh
$ mise run //apps/searxng:destroy
```

Runs `helmfile -f helmfile.yaml destroy` (scoped to this application only).

## URLs

- UI: <https://searxng.sklein.internal>
- JSON API: <https://searxng.sklein.internal/search?q=homelab&format=json>
