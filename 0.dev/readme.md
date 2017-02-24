This folder represent a developpment environment. It's automatized with the minimum of action for a maximum of fexibility.

# backend.yaml

A cloud-init file with cloud-config syntaxe

  * DHCP request on eth1
  * Install PHP
  * Install MySQL
  * Install NFS
  * Install wp (a tool for wordpress deployment)
  * Export the wordpress folder on private network
  * Configure MySQL on private network
  * Create the Wordpress user on MySQL

# frontweb.yaml

A cloud-init file with cloud-config syntaxe

  * DHCP request on eth1
  * Mount NFS share
  * Install PHP
  * Install NFS client
  * Install Apache2

# script-up

A bash script to start the environment

  * UUIDs are specific to the tenant, change it with your own values
  * IPs are specific too, change it with your own values

# script-down

A bash script to stop the environment
