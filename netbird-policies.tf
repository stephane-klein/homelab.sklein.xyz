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
    destinations  = [netbird_group.homelab_servers.id]
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
    destinations  = [netbird_group.homelab_servers.id]

    authorized_groups = {
      (netbird_group.user_devices.id) = ["stephane"]
    }
  }
}
