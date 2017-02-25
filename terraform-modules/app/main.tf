variable "application_key" {
  type = "string"
}
variable "application_secret" {
  type = "string"
}
variable "consumer_key" {
  type = "string"
}
variable "count" {
  default = 1
}

resource "openstack_networking_subnet_v2" "internal" {
  network_id = "883f1487-4ca5-4d4d-8b12-94faa54fe7b9"
  cidr = "10.0.0.0/8"
  allocation_pools {
    start = "10.0.0.2"
    end = "10.1.254.254"
  }
}

resource "openstack_compute_instance_v2" "backend" {
  region = "GRA1"
  name = "backend"
  image_name = "Debian 8"
  flavor_name = "sp-60-ssd"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  } 
  network {
    name = "VLAN"
    fixed_ip_v4 = "10.1.254.254"
  }
  user_data = "${file("${path.module}/backend.yaml")}"
} 


resource "openstack_compute_instance_v2" "frontweb" {
  depends_on = ["openstack_compute_instance_v2.backend"]
  count = "${var.count}"
  stop_before_destroy = true
  region = "GRA1"
  name = "${format("frontweb-%02d", count.index+1)}"
  image_name = "Debian 8"
  flavor_name = "eg-7-ssd"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  } 
  network {
    name = "VLAN"
  }
  user_data = "${file("${path.module}/frontweb.yaml")}"
  metadata {
    application_key = "${var.application_key}"
    application_secret = "${var.application_secret}"
    consumer_key = "${var.consumer_key}"
  }
} 
