provider "aws" {
  region = "us-west-2"
}

variable "key_name" {
  description = "SSH Keypair for EC2 access"
  default     = "your-keypair"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}

variable "ami" {
  description = "RHEL 8 AMI for Kubernetes"
  default     = "ami-0e4724df9f8e6af9a"  # Replace with a valid RHEL 8 AMI for your region
}

# Security group for Kubernetes master and worker nodes
resource "aws_security_group" "k8s_sg" {
  name        = "k8s_security_group"
  description = "Allow traffic for Kubernetes Cluster"
  vpc_id      = "your-vpc-id"

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

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Disable SELinux
              setenforce 0
              sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux

              # Disable swap
              swapoff -a
              sed -i '/swap/d' /etc/fstab

              # Install Docker
              yum install -y yum-utils
              yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
              yum install -y docker-ce docker-ce-cli containerd.io
              systemctl enable --now docker

              # Enable IP Forwarding
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
              sysctl --system

              # Install Kubernetes
              cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
              [kubernetes]
              name=Kubernetes
              baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
              enabled=1
              gpgcheck=1
              repo_gpgcheck=1
              gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
              EOF

              yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
              systemctl enable --now kubelet

              # Initialize Kubernetes master
              kubeadm init --pod-network-cidr=192.168.0.0/16
              mkdir -p $HOME/.kube
              cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
              chown $(id -u):$(id -g) $HOME/.kube/config

              # Install Calico for networking
              kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml
              EOF
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

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Disable SELinux
              setenforce 0
              sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux

              # Disable swap
              swapoff -a
              sed -i '/swap/d' /etc/fstab

              # Install Docker
              yum install -y yum-utils
              yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
              yum install -y docker-ce docker-ce-cli containerd.io
              systemctl enable --now docker

              # Enable IP Forwarding
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
              sysctl --system

              # Install Kubernetes
              cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
              [kubernetes]
              name=Kubernetes
              baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
              enabled=1
              gpgcheck=1
              repo_gpgcheck=1
              gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
              EOF

              yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
              systemctl enable --now kubelet
              EOF
}

# Output the public IP addresses of the instances
output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = [aws_instance.worker[*].public_ip]
}