terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

#  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

resource "aws_instance" "windows_2019" {
  ami           = "ami-093693792d26e4373"
  instance_type = "t2.micro"

launch_template {

   id = "lt-02c7908af0a6039ec"
}
  tags = {
    Name = "windows_2019"
  }
}


resource "aws_instance" "windows_2016" {
  ami           = "ami-0b1577dc927b1052f"
  instance_type = "t2.micro"

launch_template {

     id = "lt-0cb264a75aba1f422"
}
  tags = {
    Name = "windows_2016"
  }
}


resource "aws_instance" "redhat" {
  ami           = "ami-023c11a32b0207432"
  instance_type = "t2.micro"

launch_template {

     id = "lt-017c5362b550df2ff"
}
  tags = {
    Name = "linux_RHL9.3"
  }
}


