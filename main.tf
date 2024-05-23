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
