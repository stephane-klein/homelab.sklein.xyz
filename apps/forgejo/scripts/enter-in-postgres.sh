#!/usr/bin/env bash
set -euo pipefail

kubectl cnpg psql forgejo-cluster -n forgejo
