# Configure the OpenStack Provider
provider "openstack" {
}

resource "openstack_compute_keypair_v2" "gw" {
  name = "gw"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

module "app" {
  source = "../terraform-modules/app"
  count = 1
}

module "stress" {
  source = "../terraform-modules/stress"
  count = 2
}
