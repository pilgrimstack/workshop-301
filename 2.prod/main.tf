provider "openstack" {
  # variables took from OS_ environment variables
}

resource "openstack_compute_keypair_v2" "gw" {
  name = "gw"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

module "app" {
  source = "../terraform-modules/app"
  backend_flavor = "s1-8"
  loadbalancer_flavor = "s1-4"
  frontweb_flavor = "s1-4"
  count = 2
}
