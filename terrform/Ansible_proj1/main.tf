provider "aws" {
  region = "us-east-1"  # Set your desired AWS region
}


# Create an EC2 instance using the Launch Template
resource "aws_instance" "ec2_instance" {
  ami             = aws_launch_template.windows_2019.image_id
  instance_type   = aws_launch_template.windows_2019.instance_type
  key_name        = aws_launch_template.windows_2019.key_name
  instance_initiated_shutdown_behavior = "terminate" # or "stop" depending on your preference
  
  network_interface {
    network_interface_id = aws_launch_template.windows_2019
  }

  tags = {
    Name = "windows"
  }
}
