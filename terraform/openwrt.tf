resource "uapi_dhcp_dnsmasq" "dnsmasq" {
  authoritative = true
  boguspriv     = true
  cachesize     = 1000
  domain        = "lan"
  domainneeded  = true
  expandhosts   = true
  filterwin2k   = false
  leasefile     = "/tmp/dhcp.leases"
  local         = "/lan/"
  nonwildcard   = true
  noresolv      = false
  readethers    = true

  rebind_protection = true
  resolvfile        = "/tmp/resolv.conf.d/resolv.conf.auto"

  # A server entry with no address makes the domain local: dnsmasq answers
  # from hosts/leases and never forwards .internal queries upstream.
  server = ["/${local.network.openwrt.dns_domain}/"]

  # Static physical names. PVE IPAM-derived names are added once Terraform
  # has a source for their addresses.
  address = [
    "/gateway.internal/192.168.235.1",
    "/operator.internal/${local.network.openwrt.operator_source}",
  ]
}

resource "uapi_firewall_zone" "lan" {
  id            = "lan"
  name          = "lan"
  family        = "any"
  input         = "ACCEPT"
  output_policy = "ACCEPT"
  forward       = "ACCEPT"
  network       = ["lan"]
  masq          = false
  mtu_fix       = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "uapi_firewall_zone" "wan" {
  id            = "wan"
  name          = "wan"
  family        = "any"
  input         = "REJECT"
  output_policy = "ACCEPT"
  forward       = "DROP"
  network       = ["wan", "wan6"]
  masq          = true
  mtu_fix       = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "uapi_network_interface" "lan" {
  id        = "lan"
  proto     = "static"
  device    = "br-lan"
  ipaddrs   = ["192.168.235.1/24"]
  ip6assign = 60
  auto      = true
  disabled  = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "uapi_network_interface" "wan" {
  id       = "wan"
  proto    = "dhcp"
  device   = "wan"
  auto     = true
  disabled = false

  lifecycle {
    prevent_destroy = true
  }
}
