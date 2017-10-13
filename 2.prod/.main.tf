provider "openstack" {
  # variables took from OS_ environment variables
}

resource "openstack_compute_keypair_v2" "gw" {
  name = "gw"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

module "app" {
  source = "git::git@github.com:pilgrimstack/workshop-301.git/terraform-modules/app?ref=v2.0"
  backend_flavor = "s1-8"
  loadbalancer_flavor = "s1-2"
  frontweb_flavor = "s1-4"
  count = 2
}
