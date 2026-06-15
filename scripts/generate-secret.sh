cat <<EOF > ./.secret
NUC_I3_GEN5_STEPHANE_PASSWORD="$(gopass show nuc-i3-gen5.homelab.stephane-klein.info/stephane/password)"
NUC_I3_GEN5_NETBIRD_SETUP_KEY="$(gopass show nuc-i3-gen5.homelab.stephane-klein.info/netbird/setup_key)"

NUC_I7_GEN11_STEPHANE_PASSWORD="$(gopass show nuc-i7-gen11.homelab.stephane-klein.info/stephane/password)"
NUC_I7_GEN11_LUKS_PASSPHRASE="$(gopass show nuc-i7-gen11.homelab.stephane-klein.info/luks/passphrase)"
NUC_I7_GEN11_NETBIRD_SETUP_KEY="$(gopass show nuc-i7-gen11.homelab.stephane-klein.info/netbird/setup_key)"

NETBIRD_API_TOKEN="$(gopass show netbird/apikey)"
EOF
