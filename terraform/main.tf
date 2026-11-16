locals {
  network = yamldecode(
    file("${path.module}/../config/base/network.yaml")
  )
}
