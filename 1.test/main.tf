provider "openstack" {
  # variables took from OS_ environment variables
}

module "app" {
  source = "../terraform-modules/app"
  backend_flavor = "s1-8"
  loadbalancer_flavor = "s1-2"
  frontweb_flavor = "s1-4"
  count = 2
}

module "stress" {
  source = "../terraform-modules/stress"
  count = 2
}
