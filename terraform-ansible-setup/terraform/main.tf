# This file contains the Terraform code to create an EC2 instance with Nginx and an Elastic IP
provider "aws" {
  region     = "us-east-1"  # or your preferred region
  profile    = "learner"
}

# Security Group for Nginx and SSH on port 22 and 22000
resource "aws_security_group" "nginx" {
  ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22000
    to_port     = 22000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance
resource "aws_instance" "nginx" {
  ami           = "ami-0664c8f94c2a2261b"
  instance_type = "t2.micro"
  key_name      = "Cloud"
  vpc_security_group_ids = [aws_security_group.nginx.id]

  associate_public_ip_address = true

  tags = {
    Name = "nginx"
  }
  
  user_data = <<-EOF
              # Configure SSH on port 22000 as well as 22
              echo "Port 22" | sudo tee -a /etc/ssh/sshd_config
              echo "Port 22000" | sudo tee -a /etc/ssh/sshd_config
              sudo systemctl restart sshd
              EOF
}

# Elastic IP for Nginx
resource "aws_eip" "nginx_eip" {
  instance = aws_instance.nginx.id
  tags = {
    Name = "Nginx"
  }
}

# Output the Elastic IP
output "elastic_ip" {
  value = aws_eip.nginx_eip.public_ip
}

# Save inventory with Elastic IP
resource "null_resource" "inventory_file" {
  provisioner "local-exec" {
    # Save the inventory file in the ansible directory
    # Replace <YOUR_PEM_PATH> with the path to your .pem file
    command = "echo ${aws_eip.nginx_eip.public_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=<YOUR_PEM_PATH> ansible_port=22000 > ../ansible/inventory.txt" 
  }

  depends_on = [aws_eip.nginx_eip]
}