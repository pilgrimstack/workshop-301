resource "openstack_compute_keypair_v2" "gw" {
  region = "GRA1"
  name = "gw"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCYKqrx4AjQmLN6ecEhzS5j6Ar0YKoc/oCQ/bF9NMOTAQV9cExDvrSVJIqBxOazC9Cs1w8M2++4S0P5NpJ1JvfKhXE+viByGtacuQHr02TU7J6cbrJ5VZLMT0tI7VbHeisWJPtTcVjeQLleDuelZg4Hm2ei6hEHbgYJaQlXo+vu47ARHk93187GEe3WaTCTpcdvKgfRYcpca87nkaiOSm4k/TCPc211PNJl+1AQYCJqie3Qcuhtbzzi3Grgv8EYRKxvlhHn1+mwxor6IbzF6Tx/8tWUrJ0w/lLMsv6TAyM/jsHU26FG+Sh8PwJjag/0P7zEBYP15YQI2Ps+ih+t2SGP admin@gw-out"
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
  user_data = "${file("backend.yaml")}"
} 

variable "count" {
  default = 5
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
  user_data = "${file("frontweb.yaml")}"
  metadata {
    application_key = "${var.mapplication_key}"
    application_secret = "${var.mapplication_secret}"
    consumer_key = "${var.mconsumer_key}"
  }
} 
