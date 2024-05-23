
#  This project aims to automate the installation of WordPress and its dependencies (PHP, Apache, MySQL) using a configuration management tool. The goal is to streamline the setup process, reduce manual effort, and 
#  ensure consistency across deployments. This will enhance efficiency and reliability for all new WordPress projects at XYZ Ltd.


# Installation or pre-requisites (steps to install)
- Create AWS account

- Setup Ansible

### Ansible is needed in this project to automate and standardize the installation and configuration of WordPress and its dependencies 

`sudo apt-get install software-properties-common`

`sudo apt-add-repository ppa:ansible/ansible`

`sudo apt-get update`

`sudo apt-get install -y ansible

- Verify ansible installation
  
`ansible --version`

![ans-version](./images/ans-version.png)

- Setup Terraform

### Terraform automates the creation of resources such as EC2 instances, VPCs, security groups, and more, ensuring a consistent and efficient setup for Wordpress

- Installation steps
`wget https://releases.hashicorp.com/terraform/1.8.1/terraform_1.8.1_linux_amd64.zip`
`unzip terraform_1.8.1_linux_amd64.zip`
`sudo mv terraform /usr/local/bin`
`sudo cp /usr/local/bin/terraform /bin/terraform`

- Verify terraform installation

`terraform -version`

![terra-version](./images/terra-version.png)

- Setup Git

### Git is needed in this project to manage and version control the codebase, including Terraform scripts and Ansible playbooks. 

- Installation steps

`sudo apt install -y git`

- Verify git installation

`git --version`

![git-version](./images/git-version.png)


# Create AWS Key pair
- Create a key pair on AWS

![keypair-create](./images/pem-creation.png)

- Download the keypair & add it to the machine/lab

![key-copied](./images/pem-copied.png)

`nano terra-ans.pem`

![copied-machine](./images/copied-machine.png)

- Change the permission of the pem file

`sudo chmod 400 terra-ans.pem`

# Create/Download the Ansible playbook/roles to setup wordpress server

`nano terra-ans.yml`

### Copied the script below into the terra-ans.yml to automates the setup of a WordPress environment, including installing Apache, PHP, MySQL, and WordPress. It updates the apt cache, checks and installs Python if necessary, configures Apache, installs MySQL server, sets root password, creates a MySQL database and user for WordPress, downloads and extracts WordPress, and configures Apache for WordPress.


```  
---
- hosts: all
  become: yes
  vars:
    mysql_root_password: 'your_root_password'
    mysql_wordpress_db: 'wordpress'
    mysql_wordpress_user: 'wordpressuser'
    mysql_wordpress_password: 'your_password'

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Check if Python is installed
      command: python3 -V
      register: python_check
      ignore_errors: yes

    - name: Install Python if not installed
      apt:
        name: python3
        state: present
      when: python_check.rc != 0

    - name: Install MySQL client library for Python
      apt:
        name: python3-mysqldb
        state: present
    - name: Install Apache
      apt:
        name: apache2
        state: present

    - name: Install PHP and modules
      apt:
        name: "{{ item }}"
        state: present
      with_items:
        - php
        - libapache2-mod-php
        - php-mysql

    - name: Start and enable Apache
      service:
        name: apache2
        state: started
        enabled: yes

    - name: Install MySQL server
      apt:
        name: mysql-server
        state: present

    - name: Set MySQL root password
      mysql_user:
        name: root
        host: localhost
        password: "{{ mysql_root_password }}"
        priv: "*.*:ALL,GRANT"
        state: present
      vars:
        ansible_python_interpreter: /usr/bin/python3

    - name: Create MySQL database
      mysql_db:
        name: "{{ mysql_wordpress_db }}"
        state: present
        login_user: root
        login_password: "{{ mysql_root_password }}"
      vars:
        ansible_python_interpreter: /usr/bin/python3                                                                                               
    - name: Create MySQL user for WordPress
      mysql_user:
        name: "{{ mysql_wordpress_user }}"
        password: "{{ mysql_wordpress_password }}"
        priv: "{{ mysql_wordpress_db }}.*:ALL"
        state: present
        login_user: root
        login_password: "{{ mysql_root_password }}"
      vars:
        ansible_python_interpreter: /usr/bin/python3

    - name: Download and extract WordPress
      shell: |
        curl -O https://wordpress.org/latest.tar.gz
        tar -xzf latest.tar.gz
        mv wordpress/* /var/www/html/
        chown -R www-data:www-data /var/www/html
        rm -f latest.tar.gz
      args:
        creates: /var/www/html/wp-config.php

    - name: Configure Apache for WordPress
      copy:
        dest: /etc/apache2/sites-available/000-default.conf
        content: |
          <VirtualHost *:80>
              DocumentRoot /var/www/html
              <Directory /var/www/html>
                  Options Indexes FollowSymLinks MultiViews
                  AllowOverride All
                  Require all granted
              </Directory>
              ErrorLog ${APACHE_LOG_DIR}/error.log
              CustomLog ${APACHE_LOG_DIR}/access.log combined
          </VirtualHost>
      notify: restart apache

    - name: Enable Apache rewrite module
      command: a2enmod rewrite
      notify: restart apache

  handlers:
    - name: restart apache
      service:
        name: apache2
        state: restarted
 ```

# Create the Terraform configuration file - to create Ubuntu server on AWS - automate the Wordpress setup inside this server

- Find the VPC ID & AMI -> aws rss configuration

- Create the configuration file (.tf)

`mkdir terra-ans-setup && nano main.tf`

### Copied this into the file to set up an AWS EC2 instance with specified security groups and SSH access. It defines local variables, configures the AWS provider, creates security group rules for SSH, HTTP, and HTTPS, and provisions the EC2 instance with SSH connections. Finally, it runs an Ansible playbook and outputs the instance's public IP.

```
locals {
  ami_id = "ami-080e1f13689e07408"
  vpc_id = "vpc-05b6b7e494f7b8eb0"
  ssh_user = "ubuntu"
  key_name = "terra-ans"
  private_key_path = "/home/labsuser/terra-ans-setup/terra-ans.pem"
}

# Provider section
provider "aws" {
  access_key = "ASIAQG3NLTRNAWI3CD6C"
  secret_key = "QjfdoN+IKbXO2T5eE+L286xiE2mG+synWoUnr2g2"
  token = "FwoGZXIvYXdzEAsaDLam1feKBi5/4juvUiK5ASwbQNFZzKg3IsD5HNAj0zhSoyQFNd/yeuANifATYIjWV+/nsTZI3wuY2rh5rIR+v796ZDe3puQrxR2GeMBQ1dlBnQ7xgta3LNyjm+5BXeX9PTE+4AVAnESsje89Gd/RKOEaALKquPlTNJ4IGitDBKZg0yLbzzG2aiqokTq6zZSA5KPrGvEqhaY8ld8JVh35JzIGuqZgPEQLWMLeqvhBmO7qIoxch3Z5s1Gd8RozUerEPATB7+7RdmsjKMyjvLIGMi11WoqjSu6eNpvMWujLDJkYMOPL/X9ljq/TBbEt0HEAKJB2zbdupmIPhlSrDKM="
  region = "us-east-1"
}

# AWS security group resource block - 2 inbound & 1 outbound rule added
resource "aws_security_group" "demoaccess" {
  name = "demoaccess"
  vpc_id = local.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# AWS EC2 instance resource block
resource "aws_instance" "web" {
  ami = local.ami_id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.demoaccess.id]
  key_name = local.key_name

  tags = {
    Name = "Demo Test"
  }

  # SSH Connection block which will be used by the provisioners - remote-exec
  connection {
    type = "ssh"
    host = self.public_ip
    user = local.ssh_user
    private_key = file(local.private_key_path)
    timeout = "4m"
  }

  # Remote-exec Provisioner Block - wait for SSH connection
  provisioner "remote-exec" {
    inline = [
      "echo 'wait for SSH connection to be ready...'",
      "touch /home/ubuntu/demo-file-from-terraform.txt"
    ]
  }

  # Local-exec Provisioner Block - create an Ansible Dynamic Inventory
  provisioner "local-exec" {
    command = "echo ${self.public_ip} > myhosts"
  }

  # Local-exec Provisioner Block - execute an ansible playbook
  provisioner "local-exec" {
    command = "ansible-playbook -i myhosts --user ${local.ssh_user} --private-key ${local.private_key_path} terra-ans.yml"
  }

}

# Output block to print the public ip of instance
output "instance_ip" {
  value = aws_instance.web.public_ip
}
```
`terraform init`

[terraform-init](./images/terraform-init.png)

`terraform plan`

[terraform-plan](./images/terraform-plan.png)

`terraform validate`

`terraform apply --auto-approve`

[terraform-apply](./images/terraform-auto-approve.png)

- locals - local variables

![locals](./images/locals.png)

- provider - aws - access_key, secret_key, token & region

![access](./images/access-info.png)

- resource - aws_security_group - ingress & egress rules

![security](./images/security-rule.png)

- resource - aws_instance - ami, instance_type, vpc_security_group_ids, key_name, tags

![instance-resource](./images/resource-instance-creation.png)

- provisioner - remote-exec - connection - check the SSH connectivity - using the public_ip

![ssh](./images/ssh.png)

- provisioner - local-exec - create dynamic inventory file - add the public_ip of instance created to the inventory file

![create-dynamic-inventory](./images/invoke-ans-createdynamic.png)

- provisioner - local-exec - invoke the ansible-playbook (setup wordpress) - with custom inventory -i - with the instance user -u, private_key

![playbook](./images/invoke-ans-playbook.png)

![invoke-ans-playbook](./images/invoke-ans-createdynamic.png)

- output - print the public ip of newly created instance

![output-ip](./images/output-instance.png)

[output-instance](./images/output-instance.png)



#### After excuting this commands successfully, instead of landing on the wordpress page, i was landing on the apache webserver page. I had to ssh into the instance and renamed the index.html file inside the /var/www/html before it could serve the wordpress page and used the index.php instead.

[apache-page](./images/apache-page.png)

### ssh into the instance

`ssh -i "terra-ans.pem" ubuntu@100.27.190.137`

`cd /var/www/html`

`sudo mv index.html index.html.backup`

[ssh-instance](./images/ssh-into-ins.png)




- browse this to get the WP page

[wordpress-page](./images/wordpress-page.png)
