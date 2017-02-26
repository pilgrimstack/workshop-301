This is a "Infrastructure as Code" demo. It shows 3 environments (dev, test, prod) using:
* [cloud-init](https://cloudinit.readthedocs.io/en/latest/): a configurable boot script manager for cloud instance
* [Terraform](https://www.terraform.io/): a IaaS orchestrator from Hashicorp
* [OVH Public Cloud](http://www.ovh.com/cloud): a IaaS soltution based on OpenStack by OVH
* OVH IPLB: a IP Load Balancer service by OVH

# 0.dev

This is the dev environment. It uses basic cloud-init scripts and OpenStack CLI to start 2 instances:
* backend: it's the MySQL + NFS server with a wordpress directory shared
* frontweb: it's the web server mounting the NFS share

# 1.test

This is the test environment. It uses more advenced cloud-init scripts and Terraform to start:
* the app platform:
  * 1 backend: as 0.dev
  * N frontwebs: as 0.dev + IPLB auto subscription for each instance
* the stress platform:
  * 1 master: jmeter master with GUI tools
  * N infectors: jmeter workers with a master auto subscription

# 2.prod

This is the production environment. Everything like 1.test without the stress platform

# terraform-modules

The terraform modules app and stress described above.
