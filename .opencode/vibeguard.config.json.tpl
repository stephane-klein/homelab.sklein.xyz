{
  "enabled": true,
  "debug": false,
  "placeholder_prefix": "__VG_",
  "session": {
    "ttl": "1h",
    "max_mappings": 100000
  },
  "patterns": {
    "keywords": [
      { "value": "{{ getpw "nuc-i3-gen5.homelab.stephane-klein.info/stephane/password" }}" },
      { "value": "{{ getpw "nuc-i7-gen11.homelab.stephane-klein.info/stephane/password" }}" },
      { "value": "{{ getpw "nuc-i7-gen11.homelab.stephane-klein.info/luks/passphrase" }}" },
      { "value": "{{ getpw "netbird/apikey" }}" },
      { "value": "{{ getpw "homelab/k3s_token" }}" },
      { "value": "{{ getpw "auth.sklein.internal/stephane/password" }}" },
      { "value": "{{ getpw "homelab/scaleway/SCW_ACCESS_KEY" }}" },
      { "value": "{{ getpw "homelab/scaleway/SCW_SECRET_KEY" }}" },
      { "value": "{{ getpw "homelab/scaleway/SCW_DEFAULT_ORGANIZATION_ID" }}" },
      { "value": "{{ getpw "homelab/scaleway/SCW_DEFAULT_PROJECT_ID" }}" },
      { "value": "{{ getpw "homelab/scaleway/CNPG_BACKUPS_ACCESS_KEY" }}" },
      { "value": "{{ getpw "homelab/scaleway/CNPG_BACKUPS_SECRET_KEY" }}" }
    ]
  }
}


