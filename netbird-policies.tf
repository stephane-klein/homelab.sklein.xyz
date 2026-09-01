resource "netbird_policy" "homelab_internal" {
  name        = "Homelab Internal"
  description = "Allow all traffic between homelab servers"
  enabled     = true

  rule {
    name          = "Allow All Traffic"
    action        = "accept"
    bidirectional = true
    enabled       = true
    protocol      = "all"
    sources       = [netbird_group.homelab_servers.id]
    destinations  = [netbird_group.homelab_servers.id]
  }
}

resource "netbird_policy" "user_device_access" {
  name        = "User Device Access"
  description = "Allow user devices (laptops, phones) to access homelab servers"
  enabled     = true

  rule {
    name          = "All Protocols"
    action        = "accept"
    bidirectional = false
    enabled       = true
    protocol      = "all"
    sources       = [netbird_group.user_devices.id]
    destinations = [
      netbird_group.homelab_servers.id,
      netbird_group.dev_devices.id,
    ]
  }
}

resource "netbird_policy" "ssh_access" {
  name        = "SSH Access"
  description = "SSH access from user devices to servers via Netbird SSH proxy"
  enabled     = true

  rule {
    name          = "SSH via Netbird"
    action        = "accept"
    bidirectional = false
    enabled       = true
    protocol      = "netbird-ssh"
    sources       = [netbird_group.user_devices.id]
    destinations = [
      netbird_group.homelab_servers.id,
      netbird_group.dev_devices.id,
    ]

    authorized_groups = {
      (netbird_group.user_devices.id) = ["stephane"]
    }
  }
}

resource "netbird_policy" "incus_servers_access" {
  name        = "Incus to Homelab Servers"
  description = "Bidirectional access between incus group and homelab servers"
  enabled     = true

  rule {
    name          = "Incus to Homelab Servers"
    action        = "accept"
    bidirectional = true
    enabled       = true
    protocol      = "all"
    sources       = [netbird_group.incus.id]
    destinations  = [netbird_group.homelab_servers.id]
  }
}

resource "netbird_policy" "incus_user_devices_access" {
  name        = "Incus to User Devices"
  description = "Bidirectional access between incus group and user devices"
  enabled     = true

  rule {
    name          = "Incus to User Devices"
    action        = "accept"
    bidirectional = true
    enabled       = true
    protocol      = "all"
    sources       = [netbird_group.incus.id]
    destinations  = [netbird_group.user_devices.id]
  }
}

resource "netbird_policy" "fp5_to_t14s" {
  name        = "FP5 to t14s Access"
  description = "Allow FP5 to access t14s"
  enabled     = true

  rule {
    name          = "All Protocols"
    action        = "accept"
    bidirectional = false
    enabled       = true
    protocol      = "all"
    sources       = [netbird_group.fp5_device.id]
    destinations  = [netbird_group.t14s_device.id]
  }
}
