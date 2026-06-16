data "netbird_peer" "nuc_i3_gen5" {
  name = "nuc-i3-gen5.homelab.stephane-klein.info"
}

resource "netbird_peer" "nuc_i3_gen5" {
  id   = data.netbird_peer.nuc_i3_gen5.id
  name = data.netbird_peer.nuc_i3_gen5.name

  ssh_enabled                   = true
  login_expiration_enabled      = false
  inactivity_expiration_enabled = false
  approval_required             = false
}

data "netbird_peer" "nuc_i7_gen11" {
  name = "nuc-i7-gen11.homelab.stephane-klein.info"
}

resource "netbird_peer" "nuc_i7_gen11" {
  id   = data.netbird_peer.nuc_i7_gen11.id
  name = data.netbird_peer.nuc_i7_gen11.name

  ssh_enabled                   = true
  login_expiration_enabled      = false
  inactivity_expiration_enabled = false
  approval_required             = false
}

data "netbird_peer" "fp5" {
  name = "FP5"
}

resource "netbird_peer" "fp5" {
  id   = data.netbird_peer.fp5.id
  name = data.netbird_peer.fp5.name

  ssh_enabled                   = false
  login_expiration_enabled      = false
  inactivity_expiration_enabled = false
  approval_required             = false
}

data "netbird_peer" "t14s" {
  name = "t14s"
}

resource "netbird_peer" "t14s" {
  id   = data.netbird_peer.t14s.id
  name = data.netbird_peer.t14s.name

  ssh_enabled                   = false
  login_expiration_enabled      = false
  inactivity_expiration_enabled = false
  approval_required             = false
}
