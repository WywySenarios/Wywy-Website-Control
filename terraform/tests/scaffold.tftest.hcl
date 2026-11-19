mock_provider "proxmox" {}

run "loads_network_contract" {
  command = plan

  assert {
    condition     = output.network.proxmox_sdn.zone != null
    error_message = "network contract must load from config/base/network.yaml."
  }
}
