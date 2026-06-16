resource "netbird_setup_key" "nuc_i3_gen5" {
  name                   = "nuc-i3-gen5.homelab.stephane-klein.info"
  expiry_seconds         = 604800 # 7 days
  type                   = "reusable"
  allow_extra_dns_labels = true
  auto_groups            = [netbird_group.homelab_servers.id]
  ephemeral              = false
  usage_limit            = 1
}

resource "netbird_setup_key" "nuc_i7_gen11" {
  name                   = "nuc-i7-gen11.homelab.stephane-klein.info"
  expiry_seconds         = 604800 # 7 days
  type                   = "reusable"
  allow_extra_dns_labels = true
  auto_groups            = [netbird_group.homelab_servers.id]
  ephemeral              = false
  usage_limit            = 1
}
