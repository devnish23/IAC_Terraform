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
              yum install -y containerd
              systemctl enable --now containerd

              # Enable IP Forwarding
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
              sysctl --system

              # Install Kubernetes
              cat <<EOF2 | tee /etc/yum.repos.d/kubernetes.repo
              [kubernetes]
              name=Kubernetes
              baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
              enabled=1
              gpgcheck=1
              gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
              EOF2

              yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
              systemctl enable --now kubelet

              yum update -y
              # Generate the default containerd configuration file if not present
              if [ ! -f /etc/containerd/config.toml ]; then
                  containerd config default | tee /etc/containerd/config.toml
              fi
              
              # Modify the containerd configuration
              sed -i 's/^disabled_plugins = \["cri"\]/#disabled_plugins = \["cri"\]/' /etc/containerd/config.toml
              
              # Add the enabled_plugins and endpoint configuration if not already present
              if ! grep -q 'enabled_plugins = \["cri"\]' /etc/containerd/config.toml; then
                   echo 'enabled_plugins = ["cri"]' >> /etc/containerd/config.toml
              fi

              if ! grep -q '\[plugins."io.containerd.grpc.v1.cri".containerd\]' /etc/containerd/config.toml; then
                   cat <<EOL3 | tee /etc/containerd/config.toml
              [plugins."io.containerd.grpc.v1.cri".containerd]
                endpoint = "unix:///var/run/containerd/containerd.sock"
              EOL3
              fi
              systemctl restart containerd
              systemctl enable containerd

              # Initialize Kubernetes master
              kubeadm init 
              mkdir -p $HOME/.kube
              sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
              sudo chown $(id -u):$(id -g) $HOME/.kube/config

              # Install Calico for networking
              kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml
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
              yum install -y containerd
              systemctl enable --now containerd

              # Enable IP Forwarding
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
              sysctl --system

              # Install Kubernetes
              cat <<EOF2 | tee /etc/yum.repos.d/kubernetes.repo
              [kubernetes]
              name=Kubernetes
              baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
              enabled=1
              gpgcheck=1
              gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
              EOF2

              yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
              systemctl enable --now kubelet
              systemctl restart containerd
              systemctl enable containerd

              # Generate the default containerd configuration file if not present
              if [ ! -f /etc/containerd/config.toml ]; then
                  containerd config default | tee /etc/containerd/config.toml
              fi
              
              # Modify the containerd configuration
              sed -i 's/^disabled_plugins = \["cri"\]/#disabled_plugins = \["cri"\]/' /etc/containerd/config.toml
              
              # Add the enabled_plugins and endpoint configuration if not already present
              if ! grep -q 'enabled_plugins = \["cri"\]' /etc/containerd/config.toml; then
                   echo 'enabled_plugins = ["cri"]' >> /etc/containerd/config.toml
              fi

              if ! grep -q '\[plugins."io.containerd.grpc.v1.cri".containerd\]' /etc/containerd/config.toml; then
                   cat <<EOL3 | tee /etc/containerd/config.toml
              [plugins."io.containerd.grpc.v1.cri".containerd]
                endpoint = "unix:///var/run/containerd/containerd.sock"
              EOL3
              fi
              systemctl restart containerd
              systemctl enable containerd
              EOF
}

# Output the public IP addresses of the instances
output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = [aws_instance.worker[*].public_ip]
}