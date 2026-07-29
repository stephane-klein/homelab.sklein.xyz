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

resource "netbird_group" "dev_devices" {
  name = "dev-devices"
}

resource "netbird_group" "fp5_device" {
  name = "fp5-device"
  peers = [
    netbird_peer.fp5.id,
  ]
}

resource "netbird_group" "t14s_device" {
  name = "t14s-device"
  peers = [
    netbird_peer.t14s.id,
  ]
}
