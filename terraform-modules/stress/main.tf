variable "count" {
  default = 1
}

data "openstack_images_image_v2" "debian" {
  name = "Debian 8"
  most_recent = true
  visibility = "public"
}

resource "openstack_compute_instance_v2" "stress-master" {
  name = "stress-master"
  image_name = "Debian 8"
  flavor_name = "s1-2"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  }
  user_data = "${file("${path.module}/master.yaml")}"
  block_device {
    uuid = "${data.openstack_images_image_v2.debian.id}"
    source_type = "image"
    destination_type = "local"
    delete_on_termination = true
    boot_index = 0
  }
  block_device {
    source_type = "blank"
    destination_type = "volume"
    volume_size = 1
    delete_on_termination = true
    boot_index = 1
  }
  provisioner "remote-exec" {
    inline = [
      "while [ -f /mnt/id_rsa.pub ]; do sleep 1; done",
    ]
    connection {
      type     = "ssh"
      user     = "debian"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
} 

resource "openstack_blockstorage_volume_v1" "snapshot" {
  depends_on = ["openstack_compute_instance_v2.stress-master"]
  name     = "snapshot"
  size     = 1
  source_vol_id = "${openstack_compute_instance_v2.stress-master.block_device.1}"
  volume_type = "snapshot"
}

resource "openstack_compute_instance_v2" "stress-injector" {
  depends_on = [
    "openstack_compute_instance_v2.stress-master",
    "openstack_blockstorage_volume_v1.snapshot",
  ]
  count = "${var.count}"
  region = "GRA1"
  name = "${format("stress-injector-%02d", count.index+1)}"
  image_name = "Debian 8"
  flavor_name = "s1-2"
  key_pair = "gw"
  security_groups = ["default"]
  network {
    name = "Ext-Net"
    access_network = true
  } 
  user_data = "${file("${path.module}/injector.yaml")}"
  block_device {
    source_type = "image"
    uuid = "${data.openstack_images_image_v2.debian.id}"
    destination_type = "local"
    delete_on_termination = true
    boot_index = 0
  }
  block_device {
    source_type = "snapshot"
    uuid = "${openstack_blockstorage_volume_v1.snapshot.id}"
    destination_type = "volume"
    volume_size = 1
    delete_on_termination = true
    boot_index = 1
  }
  metadata {
    master = "${openstack_compute_instance_v2.stress-master.access_ip_v4}"
  }
} 
