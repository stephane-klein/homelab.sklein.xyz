# Playground

Test and learning deployments to get familiar with the homelab.

## Basic connectivity test — whoami

Deploy a minimal whoami application to verify the ingress works.

```sh
mise run deploy-whoami
```

Access from any Netbird peer:

```sh
curl https://whoami.sklein.internal/
```

You should see the whoami response (request headers and pod name).

To remove:

```sh
mise run destroy-whoami
```

## Authelia authentication demo

Deploy whoami behind Authelia ForwardAuth to see the authentication flow.

```sh
mise run deploy-authelia-demo
```

Access `https://whoami-authelia-demo.sklein.internal`. You should be
redirected to `https://auth.sklein.internal` for login.

To remove:

```sh
mise run destroy-authelia-demo
```
