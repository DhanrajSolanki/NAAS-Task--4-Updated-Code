provider "aws"{
 region = "ap-south-1"
 profile = "default"
}

 
variable cidr_vpc{
 description = "Network Range"
 default = "192.172.0.0/16"
}


variable cidr_subnet1{
 description = "Newtork Range of Public Subnet from VPC"
 default = "192.172.1.0/24"
}


variable cidr_subnet2{
 description = "Newtork Range of Public Subnet from VPC"
 default = "192.172.2.0/24"
}

// Create a VPC

resource "aws_vpc" "VPC1"{
 cidr_block = "${var.cidr_vpc}"
 enable_dns_hostnames = true 
 
  tags = {
    Name = "MyTeraVPC"
    }
}

//Create a Public Subnet

resource "aws_subnet" "Public_Sub_Tera"{
 cidr_block = "${var.cidr_subnet1}"
 vpc_id = "${aws_vpc.VPC1.id}"
 availability_zone = "ap-south-1a"
 map_public_ip_on_launch = true
 tags = {
  Name = "My-Public-Sub-Tera"
 }
}

// Create a Private Subnet

resource "aws_subnet" "Private_Sub_Tera"{
 cidr_block = "${var.cidr_subnet2}"
 vpc_id = "${aws_vpc.VPC1.id}"
 availability_zone = "ap-south-1b"
 tags = {
  Name = "My-Private-Sub-Tera" 
}
}

//Create a Internet Gateway

resource "aws_internet_gateway" "My_Tera_IG"{
 vpc_id = "${aws_vpc.VPC1.id}"
 tags = {
 Name = "My-Tera-IG"
}
}

//Create a Route Table and Edit the Route

resource "aws_route_table" "My_Tera_Route"{
 vpc_id = "${aws_vpc.VPC1.id}"
 
 route{
 cidr_block = "0.0.0.0/0"
 gateway_id = "${aws_internet_gateway.My_Tera_IG.id}"
}
 tags = {
 Name = "My-Tera-Route"
}
}

//Public Subnet Association in Route Table

resource "aws_route_table_association" "Subnet_Assoc"{
 subnet_id = "${aws_subnet.Public_Sub_Tera.id}"
 route_table_id = "${aws_route_table.My_Tera_Route.id}"
}

// Security Group From WP

resource "aws_security_group" "MY_SEC_WP"{
 name = "MySECWP"
 description = "allow http,ssh,icmp"
 vpc_id = "${aws_vpc.VPC1.id}"

 ingress{
  description = "allow HTTP"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 ingress{
  description = "allow SSH"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 egress{
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
 tags = {
  Name = "WP_SEC"
 }
}

//MYSQL SECURITY GROUP

resource "aws_security_group" "MY_SQL_SEC"{
 name= "MYSQLSEC"
 description= "allow only ssh from basition host and mysql 3306 port"
 vpc_id = "${aws_vpc.VPC1.id}"

 ingress{
    description = "allow MYSQL"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = ["${aws_security_group.MY_SEC_WP.id}"]
 }
 egress{
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
 tags = {
  Name = "MYSQL_SEC"
 }
}

variable "ami_WP"{
 type = string
 default = "ami-000cbce3e1b899ebd"
}
 
variable "ami_MYSQL"{
 type = string
 default = "ami-08706cb5f68222d09"
}

variable "ami_type"{
 type = string
 default = "t2.micro"
}


//Wordpress Instance

resource "aws_instance" "MY_WP"{
 ami = "${var.ami_WP}"
 instance_type = "${var.ami_type}"
 subnet_id = "${aws_subnet.Public_Sub_Tera.id}"
 vpc_security_group_ids = ["${aws_security_group.MY_SEC_WP.id}"]
 key_name = "dev"
 associate_public_ip_address = true

 tags = {
 Name= "Wordpress"
 }
 depends_on = [
  aws_security_group.MY_SEC_WP
 ]
}

//MYSQL Instance

resource "aws_instance" "MY_MYSQL"{
 ami = "${var.ami_MYSQL}"
 instance_type = "${var.ami_type}"
 subnet_id = "${aws_subnet.Private_Sub_Tera.id}"
 vpc_security_group_ids = ["${aws_security_group.MY_SQL_SEC.id}","${aws_security_group.BAS_SEC.id}"]
 key_name = "dev"
 associate_public_ip_address = false
 tags = {
 Name= "MYSQL"
 }
  depends_on = [
  aws_security_group.MY_SQL_SEC,
  aws_security_group.BAS_SEC
 ]
}


//Security Group From Basition Host

resource "aws_security_group" "BAS_SEC"{
 name = "BastionHost_Sec"
 description = "allow only port 22(ssh)"
 vpc_id = "${aws_vpc.VPC1.id}"
 
 ingress{
  description = "allow ssh only"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 egress{
 from_port = 0
 to_port = 0
 protocol ="-1"
 cidr_blocks = ["0.0.0.0/0"]
}
 tags = {
  Name = "Basition_Sec"
}
}

//Variable of Basition Host

variable "ami_Bastion"{
  type= string
  default =  "ami-0732b62d310b80e97" 
}

//Creating Bastion Host instance(Management Purpose)

resource "aws_instance" "Bastion_Host"{
 ami = "${var.ami_Bastion}"
 instance_type = "${var.ami_type}"
 subnet_id = "${aws_subnet.Public_Sub_Tera.id}"
 vpc_security_group_ids = ["${aws_security_group.BAS_SEC.id}"]
 key_name = "dev"
 associate_public_ip_address = true

 tags = {
 Name= "Bastion_Host"
 }
 depends_on = [
  aws_security_group.BAS_SEC
 ]
}



//Create Elastic IP

resource "aws_eip" "EIP" {
  vpc      = true
}


//Create NAT GATEWAY

resource "aws_nat_gateway" "GW_PUBLIC" {
  allocation_id = "${aws_eip.EIP.id}"
  subnet_id     = "${aws_subnet.Public_Sub_Tera.id}"
 
depends_on = [
   aws_eip.EIP
 ]
}

// Create Route Table(NAT)

resource "aws_route_table" "NAT_ROUTE"{
 vpc_id = "${aws_vpc.VPC1.id}"
 
 route{
 cidr_block = "0.0.0.0/0"
 gateway_id = "${aws_nat_gateway.GW_PUBLIC.id}"
}
 tags = {
 Name = "MY-NAT-Route"
}
}


//Subnet Association(Private)

resource "aws_route_table_association" "Route_Asso_Private"{
 subnet_id = "${aws_subnet.Private_Sub_Tera.id}"
 route_table_id = "${aws_route_table.NAT_ROUTE.id}"
}
 
  