variable "aws_region" {
  type    = string
  default = "us-east-1" # You can provide a default value or leave it empty
}

variable "instance_type" {
  type    = string
  default = "us-east-1" # You can provide a default value or leave it empty
}

variable "key_name" {
  type    = string
  default = "us-east-1" # You can provide a default value or leave it empty
}

variable "ami_id" {
  description = "AWS AMI ID"
  type    = string
#  default = "ami-0160f1827d9bb0fe6"
}

variable "instance_name" {
  type    = string
}


provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "windows" {
#  ami           = var.ami_id
  ami           = var.ami_id
  instance_type = var.instance_type
#  key_name      = var.key_name

  # Other instance configurations...

tags = {
    Name = var.instance_name
  }

  provisioner "local-exec" {
    command = "sleep 100 && ansible-playbook -i /etc/ansible/inventory/aws_ec2.yaml  -e @/etc/ansible/group_vars/windows.yaml /etc/ansible/win_ping_playbook.yaml && ansible -i /etc/ansible/inventory/aws_ec2.yaml  -e @/etc/ansible/group_vars/windows.yaml -m setup --tree /etc/ansible/out/ all  && ansible-cmdb /etc/ansible/out/ > /home/ansibleadm/overview.html"
  }
}


