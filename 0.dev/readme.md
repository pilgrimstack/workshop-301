This folder represents a development environment. The goal is to automatize with the minimum of action for a maximum of flexibility. Here, many things will still be manual but we can save precious time with simple bash scripts and post boot configuration files based on cloud-init. cloud-init is a tool installed on cloud images which simplifies the configuration of an instance.

> **Vocabulary**
>
> * *cloud-init* is the tool
> * *cloud-config* is the syntax
> * *user-data* is the way to provide a cloud-init file to an instance

# Target Infrastructure

This architecture is really simple. The backend server hosts the data on an NFS and a MySQL server, sharing it via a private network to the frontend web server running Apache (frontweb).

![Test architecture](./content/arch.png)

# Exercise

First exercise, we'll see the very first steps to start scripting with OpenStack. We'll use the OpenStack CLI and the cloud-init tool to easily bootstrap this environment.

You have 4 files with the private network and the NFS parts which are missing. Those parts are **in bold** in the following text and some explanations are given to help you to complete it and make it work. Take the time to look how each sections of the files are built.

## backend.yaml

A cloud-init file with cloud-config syntax to setup the backend server with MySQL and NFS.

This file contains, in order:

  * An apt update
  * Install MySQL
  * **Install NFS**
    * You can simply add a new entry in the "packages" section.
      ```
       - nfs-server
      ```
  * Install PHP
  * **Write the /etc/exports file**
    * A new section "write_files" has to be added between "packages" and "runcmd"
      ```
      write_files:
       - content: |
             /srv        10.0.0.0/8(rw,sync,fsid=0,crossmnt,no_subtree_check,no_root_squash)
             /srv/www    10.0.0.0/8(rw,sync,no_subtree_check,no_root_squash)
         path: /etc/exports
         owner: root:root
         permissions: '0644'
      ```
  * **DHCP request on eth1**
    * This should be the first command in the "runcmd" section.
    * This is required because the cloud images only request the eth0 interface by default
      ```
       - dhclient eth1
      ```
  * Create a MySQL database and the Wordpress user
  * Configure MySQL on private network
  * Export the wordpress folder on private network
  * Install and use wp (a wordpress deployment tool)
  * Remove Apache2

> If in doubt, you can have a look at the file .backend.yaml
>
> If you are really lost, just copy the .backend.yaml to backend.yaml
> ```bash
> cp .backend.yaml backend.yaml
> ```

## frontweb.yaml

A cloud-init file with cloud-config syntax to setup the frontweb server with Apache2 and an NFS mount point.

This file contains, in order:

  * **DHCP request on eth1**
    * As we need the network as the very first steps in the boot process, a new section "bootcmd" is required. It's almost the same as "runcmd" but it's ran very soon during the boot process.
      ```
      bootcmd:
       - dhclient eth1
      ```
  * **Mount NFS share**
    * Here we need another new section called "mounts". It should contain the elements of an fstab line as an array :
      ```
      mounts:
       - [ "10.1.254.254:/www", /var/www, nfs4, "defaults,_netdev", "0", "0" ]
      ```
  * An apt update
  * Install Apache2
  * Install PHP and library
  * **Install NFS client**
    * You can simply add a new entry in the "packages" section.
      ```
       - nfs-common
      ```
  * Restart Apache2
  * Clean the index

> If in doubt, you can have a look at the file .frontweb.yaml
>
> If you are really lost, just copy the .frontweb.yaml to frontweb.yaml
> ```bash
> cp .frontweb.yaml frontweb.yaml
> ```

## script-up

A bash script to start the environment

This file contains, in order:

  * Source the environment variable from ~/credentials file
  * Upload of an ssh public-key
  * **Create a private network**
    ```
    openstack network create privatenet-dev
    ```
  * **Create a subnet**
    * This network should address 10.0.0.0/8 with the pool starting from 10.0.0.2 and ending on 10.1.254.254
      ```
      openstack subnet create --allocation-pool start=10.0.0.2,end=10.1.254.254 --network privatenet-dev --subnet-range 10.0.0.0/8 --dns-nameserver 213.186.33.99 privatesub-dev
      ```
  * Sleep 2 seconds
  * **Get the id of the private network and the subnet**
    ```
    extnetid=$(openstack network show -f json Ext-Net | jq -r .id)
    privatenetdevid=$(openstack network show -f json privatenet-dev | jq -r .id)
    ```
  * **Create the backend server**
    * The command exists but the private network is missing as second network. Here we need a fixep-ip.
      ```
      openstack server create --image "Debian 8" --flavor s1-4 --key-name gw --nic net-id=$extnetid --nic net-id=$privatenetdevid,v4-fixed-ip=10.1.254.254 --user-data backend.yaml backend
      ```
  * Sleep 60 seconds
  * **Create the frontweb server**
    * The command exists but the private network is missing as second network
      ```
      openstack server create --image "Debian 8" --flavor s1-4 --key-name gw --nic net-id=$extnetid --nic net-id=$privatenetdevid --user-data frontweb.yaml frontweb
      ```

> If in doubt, you can have a look at the file .script-up
>
> If you are really lost, just copy the .script-up to script-up
> ```bash
> cp .script-up script-up
> ```

You can execute each command manually or run the script like that:
```bash
bash script-up
```

Once the script is terminated, wait few seconds and get the public IP of the frontweb server to test the wordpress installation in a browser.
```bash
source ~/credentials
openstack server list
```

## script-down

A bash script to stop the environment

This file contains, in order:

  * Delete the backend server
  * Delete the frontweb server
  * Sleep 5 seconds
  * Delete the ssh keypair
  * **Delete the subnet**
    ```
    openstack subnet delete privatesub-dev
    ```
  * **Delete the network**
    ```
    openstack network delete privatenet-dev
    ```

> If in doubt, you can have a look at the file .script-down
>
> If you are really lost, just copy the .script-down to script-down
> ```bash
> cp .script-down script-down
> ```

You can execute each command manually or run the script like that:
```bash
bash script-down
```

After few second, you can check if all servers have been deleted.
```bash
openstack server list
```

# Go to the next step

```bash
cd ../1.test
```
Let's go to the [test environment](../1.test) for more fun.
