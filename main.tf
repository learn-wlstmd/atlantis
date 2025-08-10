################################################################################################################################################
#                                                            Terraform Backend                                                                          #
################################################################################################################################################

resource "aws_s3_bucket" "backendS3" {
  bucket = "wlstmd-atlantis-tfstate"
}

resource "aws_s3_bucket_versioning" "backendS3_versioning" {
  bucket = aws_s3_bucket.backendS3.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "backendDynamo" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

################################################################################################################################################
#                                                                 VPC                                                                          #
################################################################################################################################################

module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"

    name            = "atlantis-vpc"
    cidr            = "10.0.0.0/16"
    azs             = ["ap-northeast-2a", "ap-northeast-2b"]

    public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
    public_subnet_names = ["atlantis-public-subnet-a" , "atlantis-public-subnet-b"]
    map_public_ip_on_launch = true

    private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
    private_subnet_names = ["atlantis-private-subnet-a" , "atlantis-private-subnet-b"]

    enable_nat_gateway = true
    single_nat_gateway = false
    one_nat_gateway_per_az = true

    enable_dns_hostnames = true
    enable_dns_support   = true
}

################################################################################################################################################
#                                                                 EC2                                                                          #
################################################################################################################################################

data "aws_ssm_parameter" "latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "keypair" {
  key_name = "atlantis"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "local_file" "keypair" {
  content = tls_private_key.rsa.private_key_pem
  filename = "atlantis.pem"
}

resource "aws_security_group" "bastion_sg" {
  name        = "atlantis-bastion-sg"
  description = "atlantis-bastion-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4141
    to_port     = 4141
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "atlantis-bastion-sg"
  }
}

resource "aws_iam_role" "bastion" {
  name = "atlantis-bastion-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

resource "aws_iam_instance_profile" "bastion" {
  name = "atlantis-bastion-role"
  role = aws_iam_role.bastion.name
}

resource "aws_eip" "bastion" {
  depends_on = [aws_instance.bastion]
}

resource "aws_instance" "bastion" {
  ami = data.aws_ssm_parameter.latest_ami.value
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  key_name               = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  user_data = <<-EOF
    #!/bin/bash
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo 'Skill53##' | passwd --stdin ec2-user

    mkdir -p /root/.aws
    cat << AWSEOF > /root/.aws/credentials
    [wlstmd]
    aws_access_key_id = ${var.aws_access_key}
    aws_secret_access_key = ${var.aws_secret_key}
    AWSEOF

    yum install -y yum-utils
    yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    yum -y install terraform
    yum -y install git
    wget https://github.com/runatlantis/atlantis/releases/download/v0.35.1/atlantis_linux_amd64.zip -P /root
    unzip /root/atlantis_linux_amd64.zip -d /root

    /root/atlantis server \
    --atlantis-url="${var.github_repo_url}" \
    --gh-user="${var.github_user}" \
    --gh-token="${var.github_token}" \
    --gh-webhook-secret="${var.github_webhook_secret}" \
    --repo-allowlist="github.com/${var.github_user}/${var.github_repo_name}"
  EOF

  tags = {
    Name = "atlantis-bastion"
  }
}

resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

output "bastion_details" {
  value = {
    ip_address        = aws_eip.bastion.public_ip
    instance_id       = aws_instance.bastion.id
    availability_zone = aws_instance.bastion.availability_zone
  }
}