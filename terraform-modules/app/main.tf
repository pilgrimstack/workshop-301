variable "count" { default = 1 }
variable "backend_flavor" { default = "s1-2" }
variable "loadbalancer_flavor" { default = "s1-2" }
variable "frontweb_flavor" { default = "s1-2" }

resource "openstack_networking_network_v2" "privatenet-test" {
  name           = "privatenet-test"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "internal" {
  network_id = "${openstack_networking_network_v2.privatenet-test.id}"
  cidr = "10.0.0.0/8"
  allocation_pools {
    start = "10.0.0.2"
    end = "10.1.254.254"
  }
}

resource "openstack_compute_instance_v2" "backend" {
  name = "backend"
  image_name = "Debian 8"
  flavor_name = "${var.backend_flavor}"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  } 
  network {
    name = "${openstack_networking_network_v2.privatenet-test.name}"
    fixed_ip_v4 = "10.1.254.254"
  }
  user_data = "${file("${path.module}/backend.yaml")}"
} 

resource "openstack_compute_instance_v2" "loadbalancer" {
  name = "loadbalancer"
  image_name = "Debian 8"
  flavor_name = "${var.loadbalancer_flavor}"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  } 
  provisioner "local-exec" {
    command = "rm -f conf/shared_key_app ; mkdir conf ; ssh-keygen -t rsa -N '' -f conf/shared_key_app -q"
  }
  provisioner "file" {
    source      = "conf/shared_key_app.pub"
    destination = "/home/debian/authorized_keys"
    connection {
      type     = "ssh"
      user     = "debian"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/debian/authorized_keys /root/.ssh/",
      "sudo chmod 600 /root/.ssh/authorized_keys",
      "sudo chown root:root /root/.ssh/authorized_keys",
    ]
    connection {
      type     = "ssh"
      user     = "debian"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
  user_data = "${file("${path.module}/loadbalancer.yaml")}"
} 

resource "openstack_compute_instance_v2" "frontweb" {
  depends_on = [
    "openstack_compute_instance_v2.backend",
    "openstack_compute_instance_v2.loadbalancer",
  ]
  count = "${var.count}"
  stop_before_destroy = true
  name = "${format("frontweb-%02d", count.index+1)}"
  image_name = "Debian 8"
  flavor_name = "${var.frontweb_flavor}"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  } 
  network {
    name = "${openstack_networking_network_v2.privatenet-test.name}"
  }
  provisioner "file" {
    source      = "conf/shared_key_app"
    destination = "/home/debian/id_rsa"
    connection {
      type     = "ssh"
      user     = "debian"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/debian/id_rsa /root/.ssh/",
      "sudo chmod 600 /root/.ssh/id_rsa",
      "sudo chown root:root /root/.ssh/id_rsa",
    ]
    connection {
      type     = "ssh"
      user     = "debian"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
  user_data = "${file("${path.module}/frontweb.yaml")}"
  metadata {
    iplb = "${openstack_compute_instance_v2.loadbalancer.access_ip_v4}"
  }
} 
