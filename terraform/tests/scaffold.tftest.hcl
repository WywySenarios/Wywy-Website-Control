mock_provider "uapi" {}

run "loads_network_contract" {
  command = plan

  assert {
    condition     = output.network.proxmox_sdn.zone != null
    error_message = "network contract must load from config/base/network.yaml."
  }

  assert {
    condition     = output.network.openwrt.dns_domain != null
    error_message = "network contract must include openwrt.dns_domain."
  }
}
