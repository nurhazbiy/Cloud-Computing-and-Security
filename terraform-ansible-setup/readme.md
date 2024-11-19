
# Terraform and Ansible Setup for Deploying an AWS EC2 Instance with Nginx

## **Step 1: Install Required Tools**

### Update Ubuntu

```bash
sudo apt update && sudo apt upgrade -y
```

### Install AWS CLI

1. Download the AWS CLI installation package:

   ```bash
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   ```

2. Unzip the package:

   ```bash
   unzip awscliv2.zip
   ```

3. Install AWS CLI:

   ```bash
   sudo ./aws/install
   ```

4. Verify the installation:

   ```bash
   aws --version
   ```

### Install Terraform CLI

1. Add the HashiCorp GPG key and repository:

   ```bash
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   ```

2. Install Terraform:

   ```bash
   sudo apt update && sudo apt install terraform -y
   ```

3. Verify the installation:

   ```bash
   terraform --version
   ```

### Install Ansible

1. Add Ansible PPA:

   ```bash
   sudo apt update
   sudo apt install -y software-properties-common
   sudo add-apt-repository --yes --update ppa:ansible/ansible
   ```

2. Install Ansible:

   ```bash
   sudo apt install ansible -y
   ```

3. Verify the installation:

   ```bash
   ansible --version
   ```

## **Step 2: Configure AWS CLI**

1. Run the AWS CLI configuration:

   ```bash
   aws configure
   ```

2. Provide:
   - **Access Key ID**: Your AWS Access Key.
   - **Secret Access Key**: Your AWS Secret Key.
   - **Default Region**: e.g., `us-east-1`.

## **Step 3: Terraform and Ansible Deployment**

### Create a Working Directory

```
📦 terraform-ansible-setup
├─ ansible
│  ├─ playbook.yaml
│  └─ inventory.txt
└─ terraform
   └─ main.tf
```

```bash
mkdir -p terraform-ansible-setup/ansible
mkdir -p terraform-ansible-setup/terraform
```

### Write Terraform Configuration Files

#### `main.tf`

```tf
provider "aws" {
  region = "us-east-1"
}

# Create an EC2 instance
resource "aws_instance" "nginx" {
  ami           = "ami-0664c8f94c2a2261b"
  instance_type = "t2.micro"
  key_name      = "<YOUR_KEYNAME_FILE>" # Replace to your own keyname
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
    command = "echo ${aws_eip.nginx_eip.public_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=<YOUR_PEM_PATH> ansible_port=22000 > ../ansible/inventory.txt"
  }

  depends_on = [aws_eip.nginx_eip]
}
```

#### `outputs.tf`

```tf
output "instance_public_ip" {
  value = aws_instance.example.public_ip
}
```

#### `variables.tf` (Optional)

```tf
variable "aws_region" {
  default = "us-east-1"
}
variable "ami_id" {
  default = "ami-0664c8f94c2a2261b"
}
```

### Initialize and Apply Terraform

1. Initialize Terraform:

   ```bash
   terraform init
   ```

2. Apply Terraform configuration:

   ```bash
   terraform apply -auto-approve
   ```

3. The Elastic IP will be printed to the terminal, and an `inventory.txt` file will be generated for Ansible.

### Write Ansible Playbook

#### `nginx-playbook.yml`

```yaml
- hosts: all
  become: yes
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        update_cache: yes
        state: latest

    - name: Config nginx
      shell: echo "Hello World" > /var/www/html/index.html

    - name: Start Nginx service
      service:
        name: nginx
        state: started
        enabled: yes
```

### Run Ansible Playbook

1. Ensure the `inventory.txt` file contains the Elastic IP, SSH user, private key, and custom port:

   ```bash
   <elastic_ip> ansible_ssh_user=ubuntu ansible_ssh_private_key_file=<YOUR_PEM_PATH> ansible_port=22000
   ```

2. Run the playbook:

   ```bash
   ansible-playbook -i inventory.txt nginx-playbook.yml
   ```

## **Step 4: Verify Deployment**

1. Open your browser and navigate to the Elastic IP:  
   ```http://<elastic_ip>```  
   You should see the default Nginx welcome page.

### Security Group Reminder

- **SSH (port 22000)**: Ensure the security group allows inbound traffic from your IP address.
- **HTTP (port 80)**: Ensure the security group allows inbound traffic from `0.0.0.0/0` for public access.
