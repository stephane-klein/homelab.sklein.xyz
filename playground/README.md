# Playground

Test and learning deployments to get familiar with the homelab.

## Basic connectivity test — whoami

Deploy a minimal whoami application to verify the ingress works.

```sh
$ mise run deploy-whoami
```

Access from any Netbird peer:

```sh
$ curl https://whoami.sklein.internal/
```

You should see the whoami response (request headers and pod name).

To remove:

```sh
$ mise run destroy-whoami
```

## Authelia authentication demo

Deploy whoami behind Authelia ForwardAuth to see the authentication flow.

```sh
$ mise run deploy-authelia-demo
```

Access `https://whoami-authelia-demo.sklein.internal`. You should be
redirected to `https://auth.sklein.internal` for login.

To remove:

```sh
$ mise run destroy-authelia-demo
```

## Deploy CloudNativePG dummy cluster demo

```sh
$ mise run deploy-cnpg-dummy-cluster
=== Deploying CloudNativePG dummy cluster ===
  Waiting for postgres instance to be ready...

=== Done ===
  Cluster dummy in namespace cnpg-demo
  Connect: kubectl port-forward -n cnpg-demo service/dummy-rw 5432:5432
  Password: kubectl get secret -n cnpg-demo dummy-app -o jsonpath='{.data.password}' | base64 -d
  User: app

  Destroy with: mise run destroy-cnpg-dummy-cluster
```

```sh
$ kubectl get cluster -A
NAMESPACE   NAME    AGE   INSTANCES   READY   STATUS                     PRIMARY
cnpg-demo   dummy   64s   1           1       Cluster in healthy state   dummy-1
```

```sh
$ kubectl cnpg status dummy -n cnpg-demo
Cluster Summary
Name                     cnpg-demo/dummy
System ID:               7653571698302464024
PostgreSQL Image:        ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie
Primary instance:        dummy-1
Primary promotion time:  2026-06-20 20:07:11 +0000 UTC (32m17s)
Status:                  Cluster in healthy state
Instances:               1
Ready instances:         1
Size:                    144M
Current Write LSN:       0/70000C8 (Timeline: 1 - WAL File: 000000010000000000000007)

Continuous Backup status
First Point of Recoverability:  2026-06-20T20:35:35Z
Working WAL archiving:          OK
WALs waiting to be archived:    0
Last Archived WAL:              000000010000000000000006.00000028.backup   @   2026-06-20T20:36:10.404511Z
Last Failed WAL:                -

Streaming Replication status
Not configured

Instances status
Name     Current LSN  Replication role  Status  QoS         Manager Version  Node
----     -----------  ----------------  ------  ---         ---------------  ----
dummy-1  0/70000C8    Primary           OK      BestEffort  1.29.1           nuc-i7-gen11.homelab.stephane-klein.info
```

```sh
$ kubectl cnpg psql dummy -n cnpg-demo
postgres=# \l
                                                List of databases
   Name    |  Owner   | Encoding | Locale Provider | Collate | Ctype | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+---------+-------+--------+-----------+-----------------------
 app       | app      | UTF8     | libc            | C       | C     |        |           |
 postgres  | postgres | UTF8     | libc            | C       | C     |        |           |
 template0 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | C       | C     |        |           | =c/postgres          +
           |          |          |                 |         |       |        |           | postgres=CTc/postgres
(4 rows)
```

```sh
$ kubectl describe scheduledbackup daily -n cnpg-demo
Name:         daily
Namespace:    cnpg-demo
Labels:       <none>
Annotations:  <none>
API Version:  postgresql.cnpg.io/v1
Kind:         ScheduledBackup
Metadata:
  Creation Timestamp:  2026-06-20T20:31:38Z
  Generation:          1
  Resource Version:    245313
  UID:                 0fa386d7-fca8-475f-880f-6c81a3ae98a3
Spec:
  Backup Owner Reference:  self
  Cluster:
    Name:    dummy
  Method:    barmanObjectStore
  Schedule:  0 0 4 * * *
Status:
  Last Check Time:  2026-06-20T20:31:38Z
Events:
  Type    Reason          Age    From                            Message
  ----    ------          ----   ----                            -------
  Normal  BackupSchedule  6m15s  cloudnative-pg-scheduledbackup  Scheduled first backup by 2026-06-21 04:00:00 +0000 UTC
```
