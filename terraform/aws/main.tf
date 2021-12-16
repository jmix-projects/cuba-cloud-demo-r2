provider "aws" {
  region = "us-east-2"
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      package_update: true
      packages:
        - docker.io
      groups:
        - docker
      system_info:
        default_user:
          groups: [docker]
      runcmd:
        - /usr/bin/docker pull ${var.docker_image}
        - /usr/bin/docker run -d --restart=always ${local.ports} ${local.envs} ${var.docker_image}
    EOF
  }

}

locals {
  ports = join(" ", [
  for port in var.ports :
  "-p ${port}:${port}"
  ])
  envs  = join(" ", [
  for key, value in var.envs :
  "-e ${key}=${value}"
  ])
}

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

resource "aws_security_group" "instance-sg" {
  name   = "project-instance-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "instance-icmp-ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instance-sg.id
}

resource "aws_security_group_rule" "instance-ports-ingress" {
  count             = length(var.ports)
  type              = "ingress"
  from_port         = var.ports[count.index]
  to_port           = var.ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instance-sg.id
}

resource "aws_security_group_rule" "instance-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instance-sg.id
}

module "instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  name                        = "project-instance"
  ami                         = data.aws_ami.ubuntu.image_id
  instance_type               = "t2.nano"
  user_data_base64            = data.template_cloudinit_config.config.rendered
  monitoring                  = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.instance-sg.id, aws_security_group.main-db-access-sg.id]
  associate_public_ip_address = true
}

resource "aws_security_group" "main-db-access-sg" {
  name   = "main-db-access-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "main-db-sg" {
  name   = "main-db-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.main-db-access-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "project-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = local.azs
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  database_subnets     = ["10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
}

module "main-db" {
  source                 = "terraform-aws-modules/rds/aws"
  identifier             = "project-main-db"
  engine                 = "postgres"
  engine_version         = "p1"
  instance_class         = "db.t3.micro"
  allocated_storage      = "10"
  port                   = "3306"
  name                   = "main-db"
  username               = var.username
  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [aws_security_group.main-db-sg.id]
  skip_final_snapshot    = true
  password               = var.password
}

