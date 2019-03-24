variable "access_key" {
  type    = "string"
}

variable "secret_key" {
  type    = "string"
}

variable "region" {
  type    = "string"
}

provider "aws" {
  version    = "~> 2.3"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/24"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.example.id}"
}

# Subnet configuration
resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.example.id}"
  cidr_block = "10.0.0.0/24"
}

resource "aws_route_table" "public_route_table" {
  vpc_id = "${aws_vpc.example.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  route_table_id = "${aws_route_table.public_route_table.id}"
  subnet_id      = "${aws_subnet.public_subnet.id}"
}

# EC2 instance
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

resource "aws_security_group" "nginx" {
  name        = "nginx"
  description = "Allow web and ssh traffic."
  vpc_id      = "${aws_vpc.example.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP web traffic."
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH."
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "nginx" {
  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "t2.micro"
  key_name               = "terraform-example"
  subnet_id              = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.nginx.id}"]

  # Required for the provisioner to run
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash

# Drop all befault.
iptables -P INPUT DROP

# Allow on loopback interface
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Open HTTP and SSH porsts.
iptables -A INPUT -i ens5 -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i ens5 -p tcp --dport 22 -j ACCEPT

# Allow incoming traffic from outgoing connections (e.g. from apt).
iptables -I INPUT -i ens5 -m state --state ESTABLISHED,RELATED -j ACCEPT
# Allow outgoing connections to respond to HTTP requests.
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT

# Install docker
apt update 
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt update
apt install -y docker-ce docker-ce-cli containerd.io

mkdir /home/ubuntu/output
chown ubuntu:ubuntu /home/ubuntu/output

# Run docker
docker run -v /home/ubuntu/output:/usr/share/nginx/html/output:ro -p 80:80 -d --name nginx nginx

# A bit kludgy, could echo multiple lines in same command etc. 
# This is a bit more symetrical and aesthetically pleasing (for me at least).
echo '* * * * * ubuntu /home/ubuntu/check_usage.sh'           >> /etc/cron.d/nginx
echo '* * * * * ubuntu sleep 10; /home/ubuntu/check_usage.sh' >> /etc/cron.d/nginx
echo '* * * * * ubuntu sleep 20; /home/ubuntu/check_usage.sh' >> /etc/cron.d/nginx
echo '* * * * * ubuntu sleep 30; /home/ubuntu/check_usage.sh' >> /etc/cron.d/nginx
echo '* * * * * ubuntu sleep 40; /home/ubuntu/check_usage.sh' >> /etc/cron.d/nginx
echo '* * * * * ubuntu sleep 50; /home/ubuntu/check_usage.sh' >> /etc/cron.d/nginx
EOF

  # Run provision in here to that files are copied on creation of the instance
  # since the EIP is only created once.
  connection {
    host        = "${self.public_ip}"
    type        = "ssh"
    user        = "ubuntu"
    private_key = "${file("terraform-example.pem")}"
  }

  provisioner "file" {
    source      = "health_check.sh"
    destination = "/home/ubuntu/health_check.sh"
  }

  provisioner "file" {
    source      = "check_usage.sh"
    destination = "/home/ubuntu/check_usage.sh"
  }

  provisioner "file" {
    source      = "home_page.sh"
    destination = "/home/ubuntu/home_page.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod +x home_page.sh check_usage.sh health_check.sh"]
  }
}

# Easier to handle recreation of instance without needing to update IP address.
resource "aws_eip" "nginx" {
  instance = "${aws_instance.nginx.id}"
  vpc      = true
}
