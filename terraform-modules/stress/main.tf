variable "count" {
  default = 1
}
variable "id_keys" {
  type = "string"
}

resource "openstack_compute_instance_v2" "stress-master" {
  region = "GRA1"
  name = "stress-master"
  image_name = "Debian 8"
  flavor_name = "vps-ssd-1"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
    fixed_ip_v4 = "213.32.73.114"
  }
  user_data = "${file("${path.module}/master.yaml")}"
  block_device {
    uuid = "d0e79eb7-5dbe-4ff2-84f9-d5ce26ef074e"
    source_type = "image"
    destination_type = "local"
    delete_on_termination = true
    boot_index = 0
  }
  block_device {
    source_type = "snapshot"
    uuid = "${var.id_keys}"
    destination_type = "volume"
    volume_size = 1
    delete_on_termination = true
    boot_index = 1
  }
} 


resource "openstack_compute_instance_v2" "stress-injector" {
  depends_on = ["openstack_compute_instance_v2.stress-master"]
  count = "${var.count}"
  region = "GRA1"
  name = "${format("stress-injector-%02d", count.index+1)}"
  image_name = "Debian 8"
  flavor_name = "vps-ssd-1"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  } 
  user_data = "${file("${path.module}/injector.yaml")}"
  block_device {
    source_type = "image"
    uuid = "d0e79eb7-5dbe-4ff2-84f9-d5ce26ef074e"
    destination_type = "local"
    delete_on_termination = true
    boot_index = 0
  }
  block_device {
    source_type = "snapshot"
    uuid = "${var.id_keys}"
    destination_type = "volume"
    volume_size = 1
    delete_on_termination = true
    boot_index = 1
  }
} 
