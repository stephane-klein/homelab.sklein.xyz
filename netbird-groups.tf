data "netbird_group" "all" {
  name = "All"
}

resource "netbird_group" "homelab_servers" {
  name = "homelab-servers"
  peers = [
    data.netbird_peer.nuc_i3_gen5.id,
    data.netbird_peer.nuc_i7_gen11.id,
  ]
}

resource "netbird_group" "user_devices" {
  name = "user-devices"
  peers = [
    data.netbird_peer.fp5.id,
    data.netbird_peer.t14s.id,
  ]
}
