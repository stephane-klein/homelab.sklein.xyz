NUC_I3_GEN5_STEPHANE_PASSWORD="{{ getpw "nuc-i3-gen5.homelab.stephane-klein.info/stephane/password" }}"

NUC_I7_GEN11_STEPHANE_PASSWORD="{{ getpw "nuc-i7-gen11.homelab.stephane-klein.info/stephane/password" }}"
NUC_I7_GEN11_LUKS_PASSPHRASE="{{ getpw "nuc-i7-gen11.homelab.stephane-klein.info/luks/passphrase" }}"

# NetBird Personal Access Token, used by OpenTofu provider (terraform-provider-netbird)
# Generate one in NetBird dashboard: Settings → API Keys → Create API Key
NB_PAT="{{ getpw "netbird/apikey" }}" 

K3S_TOKEN="{{ getpw "homelab/k3s_token" }}"

# https://auth.sklein.internal
AUTHELIA_PASSWORD="{{ getpw "auth.sklein.internal/stephane/password" }}"

# Scaleway API KEY for OpenTofu provider
SCW_ACCESS_KEY="{{ getpw "homelab/scaleway/SCW_ACCESS_KEY" }}"
SCW_SECRET_KEY="{{ getpw "homelab/scaleway/SCW_SECRET_KEY" }}"
SCW_DEFAULT_ORGANIZATION_ID="{{ getpw "homelab/scaleway/SCW_DEFAULT_ORGANIZATION_ID" }}"
SCW_DEFAULT_PROJECT_ID="{{ getpw "homelab/scaleway/SCW_DEFAULT_PROJECT_ID" }}"

# Scaleway object storage for CloudNativePG backup system
CNPG_BACKUPS_ACCESS_KEY="{{ getpw "homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY" }}"
CNPG_BACKUPS_SECRET_KEY="{{ getpw "homelab/scaleway/CNPG_BACKUPS_SECRET_KEY" }}"
