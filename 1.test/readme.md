This folder represents a test environment. The goal is to automatize it to the maximum to be able to start tests easily. It should also be really close to the production environment.

We'll use an orchestration tool which is called Terraform. This is an open source tool from Hashicop often used to manage cloud infrastructures. It has an OpenStack driver offering the possibility to speak directly to the APIs and stay standard.

# Target Infrastructure

We still have the backend server with NFS and MySQL to serve the datas to the 3 frontwebs. On front of the frontwebs, we have a load balancer which route the HTTP requests to the frontwebs.

As we want to run tests, we'll also create some servers to run Apache JMeter. It works with one master and many injectors to load the tested infrastructure.

![Test architecture](./content/arch.png)

# Exercise

In this exercise we'll see how it works and what is the Terraform syntax. We'll also reuse the cloud-init we had in the 0.dev environment and we'll improve it to add the load balancing capability.

You have some files with missing part and you'll have to complete it. Those parts are **in bold** in the following text and some explanations are given to help you to complete it and make it work. Take the time to look how each sections of the files are build.

## main.tf

This is the orchestration for the whole environment with the Terraform syntax. The main instructions are in the modules "stress" and "app" called from here.

This file contains in the order:

  * An OpenStack provider which takes his configuration from the environment variables
  * **A keypair resource**
    * This is one of the simplest resources, it create an OpenStack keypair pushing your user's public key
    * Add those lines between provider "openstack" and module "app"
      ```
      resource "openstack_compute_keypair_v2" "gw" {
        name = "gw"
        public_key = "${file("~/.ssh/id_rsa.pub")}"
      }
      ```
  * A module "app"
    * The source code is outside our 1.test folder to be shared if needed
    * Some variables are defined
  * A module "stress" similar to "app"

> In case of doubt, you can have a look on the file main.tf
> 
> If you are really lost, just copy the main.tf to main.tf
> ```bash
> cp main.tf main.tf
> ```

## The stress module

The stress tests runs on JMeter composed by a master and many workers. The master can distribute its jobs to the workers called "injectors" here. The master need to know the address of the injectors in a central configuration file.

We'll start by booting the master, then each injector will annouce their own address to the master configuration file using SSH. So, the injectors should know the master address to connect on. An SSH keypair need to be installed, the private part will be shared by all the injectors to connect on the master which will authorize those connections with the public part of the SSH key pair.


### ../terraform-modules/stress/main.tf

This is the orchestration of the stress resources. It's the occasion to see some simple definitions of resources.

This file contains in the order:

  * Some variables
  * A "stress-master" instance
    * Some definitions
    * The nework definition on Ext-Net
    * A local-exec provisioner creating the keypair localy
    * A file provisioner which send a file on the instance
    * A remote-exec provisioner which execute commands on the instance created
      * Here we install the SSH key public part
    * **The user_data definition**
      * This is the location of the cloud-init file
      * Before the end of this resource section, add this line:
        ```
          user_data = "${file("${path.module}/master.yaml")}"
        ```
  * A "stress-injector" resource
    * **A dependency definition**
      * The injectors need to know the master to be active to connect on, we'll define a dependancy like that:
        ```
          depends_on      = ["openstack_compute_instance_v2.stress-master"]
        ```
    * A number of instances started from this template defined by the special "count" variable
    * A name including a number based on the count variable
    * Some definitions
    * A file provisioner which send a file on the instance
    * A remote-exec provisioner which execute commands on the instance created
      * Here we install the SSH key private part
    * A user_data definition
    * **A metadata section**
      * We'll use it to give the master ip address to the injectors
      * This information will be available on the meta-data server available only for this instance
      * We'll be able to get this information from the isntance and we'll do it in the injector.yaml
      * Here add those lines:
        ```
          metadata {
            master = "${openstack_compute_instance_v2.stress-master.access_ip_v4}"
          }
        ```

> In case of doubt, you can have a look on the file .main.tf
> 
> If you are really lost, just copy the .main.tf to main.tf
> ```bash
> cp ../terraform-modules/stress/.main.tf ../terraform-modules/stress/main.tf
> ```

### ../terraform-modules/stress/injector.yaml

A cloud-init file with cloud-config syntax to setup the injector servers.

This file contains in the order:

  * An apt update
  * Some packages installation
  * A runcmd section
    * Get the IP of this instance
    * A configuration in /etc/hosts
    * **Get the ip_master from the meta-data server**
      * The meta-data are always served on a link-local address 169.254.169.254
      * Add this line
        ```
         - ip_master=$(curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq .meta.master | sed s'/\"//g')
        ```
    * An SSH command to master to inject the IP address in the configuration
    * Run the jmeter-server binnary

> In case of doubt, you can have a look on the file .injector.yaml
> 
> If you are really lost, just copy the .injector.yaml to injector.yaml
> ```bash
> cp ../terraform-modules/stress/.injector.yaml ../terraform-modules/stress/injector.yaml
> ```

### ../terraform-modules/stress/master.yaml

A cloud-init file with cloud-config syntax to setup the master server.

Nothing is really interesting here, just have a look if you are curious.

### ../terraform-modules/stress/test_plan.jmx

A JMeter base configuration file, just in case you really want to try. We won't to it in this workshop.

### Start using Terraform booting the stress infrastructure

We need to import the modules. Its will copyed into the local .terraform folder as an active copy.
```bash
terraform get
```

To intialize the Terraform environment and especially the providers, run this command:
```bash
terraform init
```

Now we'll see in advance what Terraform plans to do.
```bash
terraform plan
```

Then run it!
```bash
terraform apply -target openstack_compute_keypair_v2.gw -target module.stress
```

Here we said to Terraform to deplay only the key and the stress module (bypassing the app module in fact).

## The app module

Here we'll see some more advanced usages with Terraform. We'll reuse the cloud-init files we have in 0.dev and we'll add to the frontweb.yaml the subscription to the load balancer. We need the same SSH key mechanism that we had in the stress module but we can do it in a more nice way.

### ../terraform-modules/app/main.tf

This is the orchestration of the app resources. This is the occasion to see how Terraform templates can help writing nice "Infrastructure as Code".

This file contains in the order:

  * Some variables
  * A private network
  * A subnet
  * An SSH key generation
  * **A template file to generate the frontweb cloud-init file**
    * This section will take the frontweb.yaml file as a template
    * In this file, it will replace the variable ssh_shared_priv_key with the indented private key certificate
      ```
      data "template_file" "frontend_userdata" {
        template = "${file("${path.module}/frontweb.yaml")}"
      
        vars {
          ssh_shared_priv_key = "${indent(7, tls_private_key.shared_ssh_key.private_key_pem)}"
        }
      }
      ```
  * A template file to generate the loadbalancer cloud-init file
    * It's almost the same thing. Here it's the public key part and there is no indentation
  * A backend instance
    * Some definitions
    * An Ext-Net definition
    * **A privatenet-test definition with a fixed IP**
      ```
      network {
        name        = "${openstack_networking_network_v2.privatenet-test.name}"
        fixed_ip_v4 = "10.1.254.254"
      }
      ```
    * A user_data definition
  * A loadbalancer instance
    * Some definitions
    * An Ext-Net definition
    * **A user_data definition**
      * Here is where we'll use our generated data from the template
        ```
          user_data = "${data.template_file.lb_userdata.rendered}"
        ```
  * A frontweb instance
    * You already known all those definition ;)
    * Just have a look on the dependencies, the count variable and the meta-data definition to keep in mind how it works

> In case of doubt, you can have a look on the file .main.tf
> 
> If you are really lost, just copy the .main.tf to main.tf
> ```bash
> cp ../terraform-modules/app/.main.tf ../terraform-modules/app/main.tf
> ```

### ../terraform-modules/app/loadbalancer.yaml

A cloud-init file with cloud-config syntax to setup the loadbalancer server.

This file contains in the order:

  * **A user definition**
    * We need the default user 
    * We also need a root user defined with the previoulsy generated public key in the authorized SSH keys
    * We'll use our ssh_shared_pub_key variable defined to generate the template
    * Add those lines at the beginning
      ```
      users:
        - default
        - name: root
          ssh-authorized-keys:
            - ${ssh_shared_pub_key}
      ```
  * An apt update
  * Some packages installation
  * A write_file section
  * A runcmd section

> In case of doubt, you can have a look on the file .loadbalancer..yaml
> 
> If you are really lost, just copy the .loadbalancer..yaml to loadbalancer.yaml
> ```bash
> cp ../terraform-modules/stress/.loadbalancer..yaml ../terraform-modules/stress/loadbalancer.yaml
> ```

### ../terraform-modules/app/frontweb.yaml

A cloud-init file with cloud-config syntax to setup the frontweb servers.

This file contains in the order:

  * A bootcmd section
  * A mount section
  * An apt update
  * Some packages installation
  * A write_file section
    * **A /root/.ssh/id_rsa file**
    * The content will be provided by the SSH private part variable in the template
    * Add those lines:
      ```
      - content: |
            ${ssh_shared_priv_key}
        path: /root/.ssh/id_rsa
        owner: root:root
        permissions: '0600'
     ```
    * Some other files to setup systemd
  * A runcmd section

> In case of doubt, you can have a look on the file .frontweb..yaml
> 
> If you are really lost, just copy the .frontweb..yaml to frontweb.yaml
> ```bash
> cp ../terraform-modules/stress/.frontweb..yaml ../terraform-modules/stress/frontweb.yaml
> ```
