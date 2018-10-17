variable "count" {
  default = 1
}

resource "openstack_compute_instance_v2" "stress-master" {
  name            = "stress-master"
  image_name      = "Debian 8"
  flavor_name     = "s1-4"
  key_pair        = "gw"
  security_groups = ["default"]

  network {
    name           = "Ext-Net"
    access_network = true
  }

  provisioner "local-exec" {
    command = "rm -f conf/shared_key_stress ; mkdir conf ; ssh-keygen -t rsa -N '' -f conf/shared_key_stress -q"
  }

  provisioner "file" {
    source      = "conf/shared_key_stress.pub"
    destination = "/home/debian/authorized_keys"

    connection {
      type        = "ssh"
      user        = "debian"
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
      type        = "ssh"
      user        = "debian"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
} 

resource "openstack_compute_instance_v2" "stress-injector" {
  count           = "${var.count}"
  name            = "${format("stress-injector-%02d", count.index+1)}"
  image_name      = "Debian 8"
  flavor_name     = "s1-4"
  key_pair        = "gw"
  security_groups = ["default"]

  network {
    name           = "Ext-Net"
    access_network = true
  } 

  provisioner "file" {
    source      = "conf/shared_key_stress"
    destination = "/home/debian/id_rsa"

    connection {
      type        = "ssh"
      user        = "debian"
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
      type        = "ssh"
      user        = "debian"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }

  user_data = "${file("${path.module}/injector.yaml")}"
} 
