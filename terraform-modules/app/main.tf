variable "count" {
  default = 1
}

variable "backend_flavor" {
  default = "s1-2"
}

variable "loadbalancer_flavor" {
  default = "s1-2"
}

variable "frontweb_flavor" {
  default = "s1-2"
}

resource "openstack_networking_network_v2" "privatenet-test" {
  name           = "privatenet-test"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "internal" {
  network_id = "${openstack_networking_network_v2.privatenet-test.id}"
  cidr       = "10.0.0.0/8"

  allocation_pools {
    start = "10.0.0.2"
    end   = "10.1.254.254"
  }
}

## Generated an ssh keypair
resource "tls_private_key" "shared_ssh_key" {
  algorithm = "RSA"
}

data "template_file" "backend_userdata" {
  template = "${file("${path.module}/backend.yaml")}"
}

data "template_file" "frontend_userdata" {
  template = "${file("${path.module}/frontweb.yaml")}"

  vars {
    ssh_shared_pub_key = "${tls_private_key.shared_ssh_key.public_key_openssh}"
  }
}

data "template_file" "lb_userdata" {
  template = "${file("${path.module}/loadbalancer.yaml")}"

  vars {
    ssh_shared_pub_key = "${tls_private_key.shared_ssh_key.public_key_openssh}"
  }
}

resource "openstack_compute_instance_v2" "backend" {
  name            = "backend"
  image_name      = "Debian 8"
  flavor_name     = "${var.backend_flavor}"
  key_pair        = "gw"
  security_groups = ["default"]

  network {
    name           = "Ext-Net"
    access_network = true
  }

  network {
    name        = "${openstack_networking_network_v2.privatenet-test.name}"
    fixed_ip_v4 = "10.1.254.254"
  }

  user_data = "${data.template_file.backend_userdata.rendered}"
}

resource "openstack_compute_instance_v2" "loadbalancer" {
  name            = "loadbalancer"
  image_name      = "Debian 8"
  flavor_name     = "${var.loadbalancer_flavor}"
  key_pair        = "gw"
  security_groups = ["default"]

  network {
    name           = "Ext-Net"
    access_network = true
  }

  user_data = "${data.template_file.lb_userdata.rendered}"
}

resource "openstack_compute_instance_v2" "frontweb" {
  depends_on = [
    "openstack_compute_instance_v2.backend",
    "openstack_compute_instance_v2.loadbalancer",
  ]

  count               = "${var.count}"
  stop_before_destroy = true
  name                = "${format("frontweb-%02d", count.index+1)}"
  image_name          = "Debian 8"
  flavor_name         = "${var.frontweb_flavor}"
  key_pair            = "gw"
  security_groups     = ["default"]

  network {
    name           = "Ext-Net"
    access_network = true
  }

  network {
    name = "${openstack_networking_network_v2.privatenet-test.name}"
  }

  user_data = "${data.template_file.frontend_userdata.rendered}"

  metadata {
    iplb = "${openstack_compute_instance_v2.loadbalancer.access_ip_v4}"
  }
}
