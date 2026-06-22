# Playground

Test and learning deployments to get familiar with the homelab.

## 1. Basic connectivity test — whoami

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

## 2. Authelia authentication demo

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

## 3. Create CloudNativePG Dummy database cluster on k3s

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

The operator creates a default database called `app` and a user `app`.

This cluster is configured with a daily backup (`barmanObjectStore`) to
Scaleway S3 at 04:00 UTC.

To connect interactively:

```sh
$ mise run enter-in-k3s-dummy-database
```

## 4. Populate the dummy database

Two local SQL files define the schema and sample data:

- `dummy-database/schema.sql` — creates the `contacts` table
- `dummy-database/data-fixtures.sql` — inserts 10 contacts

Import them into the CNPG cluster:

```sh
$ mise run import-db-schema-and-fixtures-from-local-files-to-k3s-dummy-cnpg-cluster
=== Importing schema ===
CREATE TABLE
CREATE INDEX
=== Importing fixtures ===
TRUNCATE TABLE
INSERT 0 10
=== Done ===
```

Verify the data:

```sh
$ kubectl cnpg psql dummy -n cnpg-demo
psql (18.4 (Debian 18.4-1))
Type "help" for help.

app=# \dt
              List of relations
 Schema |   Name   | Type  | Owner
--------+----------+-------+-------
 public | contacts | table | app
(1 row)

app=# SELECT * FROM contacts;
 contact_id | first_name | last_name  |          created_at         |         updated_at
------------+------------+------------+----------------------------+----------------------------
          1 | Alice      | Martin     | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          2 | Bob        | Johnson    | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          3 | Charlie    | Dupont     | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          4 | Diana      | Smith      | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          5 | Élodie     | Petit      | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          6 | Frank      | Williams   | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          7 | Ghita      | Benali     | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          8 | Hugo       | Lefebvre   | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
          9 | Irina      | Kuznetsova | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
         10 | James      | Brown      | 2026-06-22 12:00:00.123+00 | 2026-06-22 12:00:00.123+00
(10 rows)
```

## 5. Local PostgreSQL sandbox

A local PostgreSQL instance runs on the workstation via `podman-compose` for
experimentation and backup-restore drills.

### Start and stop PostgreSQL container

```sh
$ mise run start-local-postgres
$ mise run stop-local-postgres
```

### Connect interactively

```sh
$ mise run enter-in-local-db
```

This opens a `psql` session as `app` on the `app` database.

### Copy the CNPG cluster database to local

Dump the `dummydb` database from the running CNPG cluster and restore it into
the local `app` database:

```sh
$ mise run copy-db-from-k3s-dummy-cnpg-cluster-to-local-podman-postgres
```

This runs `pg_dump -Fc` on the CNPG primary (`dummy-1`), then
`pg_restore --no-owner --role=app` into the local PostgreSQL.

### Clean the local database

Drop and recreate the `app` database:

```sh
$ mise run clean-db-on-local-podman-postgres
```

## 6. Restore a backup from Scaleway Object Storage to the local database

The CNPG cluster sends daily backups to Scaleway S3 via
`barmanObjectStore`. The following workflow lets you restore data from
these backups into your local PostgreSQL instance.

### Trigger a fresh S3 backup

```sh
$ mise run force-cnpg-backup
```

### List backups on Scaleway Object Storage

```sh
$ mise run list-backups-on-scaleway-s3
[list-backups-on-scaleway-s3] $ scripts/list-barman-backups.sh
=== Barman backups for dummy ===

  5 backup(s) available:

    20260622T135813  2026-06-22T13:58:17.021478+00:00  [DONE]
    20260622T040000  2026-06-22T04:00:03.296015+00:00  [DONE]
    20260621T040000  2026-06-21T04:00:03.309562+00:00  [DONE]
    20260620T203605  2026-06-20T20:36:08.619407+00:00  [DONE]
    20260620T203532  2026-06-20T20:35:35.367567+00:00  [DONE]
```

### Extract a logical dump from the latest backup

```sh
$ mise run dump-db-from-scaleway-dummy-cnpg-barman-s3-backup-to-file
[dump-db-from-scaleway-dummy-cnpg-barman…] $ scripts/dump-db-from-barman-s3-to-file.sh
=== Dumping database dummydb from barman S3 backup ===
  S3 URL: s3://homelab-cnpg-backups/dummy
  CNPG image: ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie

  Fetching latest backup ID...
  Latest backup ID: 20260622T135813
  Creating temp volume...
  Restoring PGDATA from S3...
  Adjusting config for temporary PostgreSQL...
Write-ahead log reset
  Starting temporary PostgreSQL...
  Waiting for PostgreSQL to be ready...
 ?column?
----------
        1
(1 row)

  Dumping database dummydb to dumps/dummydb_20260622T135813.dump...
  Cleaning up temporary container and volume...

=== Done ===
  Dump saved to: dumps/dummydb_20260622T135813.dump
  Size: 4.0K

  Import with:
    mise run restore-dump-to-local-podman-postgres dumps/dummydb_20260622T135813.dump
```

### Restore the dump file into the local database

```sh
$ mise run restore-dump-to-local-podman-postgres dumps/dummydb_20260622T135813.dump
[restore-dump-to-local-podman-postgres] $ scripts/restore-dump-to-local.sh $@ dumps/dummydb_20260622T135813.dump
=== Restoring dump to local PostgreSQL (app) ===
  Dump file: dumps/dummydb_20260622T135813.dump
  Size: 4.0K
  Target database: app
  Target user: app

  Waiting for PostgreSQL to be ready...

=== Done ===
  Dump restored to database app.
  Connect with: mise enter-in-local-db
```

```sh
$ mise enter-in-local-db
[enter-in-local-db] $ podman exec -e PGPASSWORD=app -it pg-dummy-local psql -U app -d app -h 127.0.0.1
psql (18.4 (Debian 18.4-1.pgdg13+1))
Type "help" for help.

app=# \dt
          List of tables
 Schema |   Name   | Type  | Owner
--------+----------+-------+-------
 public | contacts | table | app
(1 row)

app=# select * from contacts limit 1;
 contact_id | first_name | last_name |          created_at           |          updated_at
------------+------------+-----------+-------------------------------+-------------------------------
          1 | Alice      | Martin    | 2026-06-22 12:31:35.340959+00 | 2026-06-22 12:31:35.340959+00
(1 row)
```

### Retoration d'un backup en une seule commande

If you just want to overwrite your local database with the latest backup
data, run a single command:

```sh
$ mise run restore-db-from-scaleway-dummy-cnpg-barman-s3-backup-to-local-podman-postgres
=== Restoring database dummydb from barman S3 backup to local app ===
  S3 URL: s3://homelab-cnpg-backups/dummy
  CNPG image: ghcr.io/cloudnative-pg/postgresql:18.3-system-trixie
  barman-cloud-restore version: 3.18.0

  Fetching latest backup ID...
  Latest backup ID: 20260622T135813

  Ensuring local PostgreSQL is running...
  Waiting for local PostgreSQL to be ready...
 ?column?
----------
        1
(1 row)

  Creating temp volume...
  Restoring PGDATA from S3...
  Adjusting config for temporary PostgreSQL...
Write-ahead log reset
  Starting temporary PostgreSQL...
  Waiting for temporary PostgreSQL to be ready...
 ?column?
----------
        1
(1 row)

  Dumping database dummydb from backup...
  Cleaning up temporary container and volume...
  Cleaning local app database...
=== Cleaning local database (app) ===
DROP DATABASE
CREATE DATABASE
=== Done ===
  Restoring to local PostgreSQL (app)...

=== Done ===
  Database dummydb restored to local PostgreSQL (app).
  Connect with: mise enter-in-local-db
```


### Teardown (container + volume)

Stop the container and delete its named volume (all data is lost):

```sh
$ mise run teardown-local-postgres
```

## Destroy CloudNativePG dummy database cluster on k3s

```sh
$ mise run destroy-cnpg-dummy-cluster
```

## Delete all backups from Scaleway Object Storage

This permanently removes ALL S3 objects (base backups and WAL archives) for
the `dummy` cluster from the Scaleway bucket.

```sh
$ mise run delete-all-barman-backups
=== Delete ALL S3 objects for dummy ===
  S3 URL: s3://homelab-cnpg-backups/dummy
  Endpoint: https://s3.fr-par.scw.cloud

  WARNING: This will permanently delete ALL backups (base + WAL)
           for cluster 'dummy' from Scaleway Object Storage.

  Are you sure? Type 'yes' to confirm: yes

  Deleting all objects under s3://homelab-cnpg-backups/dummy ...


=== Done ===
  All objects deleted under s3://homelab-cnpg-backups/dummy
```
