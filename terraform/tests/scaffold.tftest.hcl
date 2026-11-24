mock_provider "proxmox" {}
mock_provider "cloudflare" {}

variables {
  cloudflare_account_id = "00000000000000000000000000000000"
  cloudflare_zone_id    = "00000000000000000000000000000000"
}

run "loads_contracts" {
  command = plan

  assert {
    condition     = output.network.proxmox_sdn.zone != null
    error_message = "network contract must load from config/base/network.yaml."
  }

  assert {
    condition     = output.k8s_api_vip != null
    error_message = "kubernetes api vip must load from config/base/network.yaml."
  }

  assert {
    condition     = length(output.cloudflare.tunnel_names) > 0
    error_message = "cloudflare contract must load from terraform/cloudflare/env/dev/cloudflare.yaml."
  }

  assert {
    condition     = contains(output.cloudflare.tunnel_names, "immich-dev")
    error_message = "dev cloudflare contract must contain the immich-dev tunnel."
  }
}
