provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "EXAMPLE-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

variable "key_name" {
}

resource "aws_instance" "web" {
  count = 6 #3 controllers, 3 workers

  instance_type = "t2.large"
  ami           = data.aws_ami.ubuntu.id

  key_name               = var.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.TotallyOpen.id]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.EXAMPLE-vpc.id
}

resource "aws_subnet" "public" {
  count                   = 1
  vpc_id                  = aws_vpc.EXAMPLE-vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.0.0/28"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet-0"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.EXAMPLE-vpc.id
  tags = {
    Name = "${terraform.workspace}-public-rt"
  }
}

resource "aws_route" "intoInstance" {
  route_table_id         = aws_route_table.public-rt.id
  depends_on             = [aws_route_table.public-rt]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public-rt" {
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_security_group" "TotallyOpen" {
  vpc_id = aws_vpc.EXAMPLE-vpc.id
  name   = "TotallyOpenSG"
}

resource "aws_security_group_rule" "totallyOpenIN" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.TotallyOpen.id
}

resource "aws_security_group_rule" "totallyOpenOUT" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.TotallyOpen.id
}

data "aws_availability_zones" "available" {
}

output "ip_of_instance" {
  value = aws_instance.web.*.public_ip
}

output "Private_ip_of_instance" {
  value = aws_instance.web.*.private_ip
}

resource "null_resource" "establish_ssh" {
  count = 6
  connection {
    user        = "ubuntu"
    host        = element(aws_instance.web.*.public_ip, count.index)
    private_key = file("~/.ssh/${var.key_name}.pem")
  }
  provisioner "remote-exec" {
    inline = ["touch ssh_completed"]
  }
}

resource "null_resource" "writeIPsall" {
  count      = 6
  depends_on = [null_resource.establish_ssh]
  provisioner "local-exec" {
    command = "echo ${element(aws_instance.web.*.public_ip, count.index)}  ${element(aws_instance.web.*.private_ip, count.index)} >> bothIPs.txt"
  }
}

