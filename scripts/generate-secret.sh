cat <<EOF > ./.secret
NUC_I3_GEN5_STEPHANE_PASSWORD="$(gopass show nuc-i3-gen5.homelab.stephane-klein.info/stephane/password)"

NUC_I7_GEN11_STEPHANE_PASSWORD="$(gopass show nuc-i7-gen11.homelab.stephane-klein.info/stephane/password)"
NUC_I7_GEN11_LUKS_PASSPHRASE="$(gopass show nuc-i7-gen11.homelab.stephane-klein.info/luks/passphrase)"

# NetBird Personal Access Token, used by OpenTofu provider (terraform-provider-netbird)
# Generate one in NetBird dashboard: Settings → API Keys → Create API Key
NB_PAT="$(gopass show netbird/apikey)" 

K3S_TOKEN="$(gopass show homelab/k3s_token)"

# https://auth.sklein.internal
AUTHELIA_PASSWORD="$(gopass show auth.sklein.internal/stephane/password)"
EOF
