provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

variable "key_name" {
  description = "SSH Keypair for EC2 access"
  default     = "kubernetes"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}

variable "ami" {
  description = "RHEL 8 AMI for Kubernetes"
  default     = "ami-0583d8c7a9c35822c"  # Replace with a valid RHEL 8 AMI for your region
}

# Security group for Kubernetes master and worker nodes
resource "aws_security_group" "k8s_sg" {
  name        = "k8s_security_group"
  description = "Allow traffic for Kubernetes Cluster"
  vpc_id      = data.aws_vpc.default.id 

  # Allow SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow API server communication
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic between nodes
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define the master node
resource "aws_instance" "master" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  security_groups        = [aws_security_group.k8s_sg.name]
  associate_public_ip_address = true

  tags = {
    Name = "Kubernetes-Master"
  }

}
# Define the worker nodes
resource "aws_instance" "worker" {
  count                  = 2
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  security_groups        = [aws_security_group.k8s_sg.name]
  associate_public_ip_address = true

  tags = {
    Name = "Kubernetes-Worker-${count.index + 1}"
  }
}

# Output the public IP addresses of the instances
output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = [aws_instance.worker[*].public_ip]
}