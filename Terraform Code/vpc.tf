//Create VPC named "project8-vpc" in the AWS region specified by the variable "aws_region"
resource "aws_vpc" "project8_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

    tags = {
        Name = var.vpc_name
    }
}

//Create Data Source for the AWS Availability Zones in the region specified by the variable "aws_region" 
data "aws_availability_zones" "available" {
  state = "available"
}

//Create public subnet named "public-us-east-1a"
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.project8_vpc.id
  cidr_block              = var.public_subnet_1_cidr_block
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

    tags = {
        Name = "public-us-east-1a"
        "kubernetes.io/cluster/kubernetes-fortress" = "shared"
        "kubernetes.io/role/elb" = "1"
    }
}

//Create public subnet named "public-us-east-1b"
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.project8_vpc.id
  cidr_block              = var.public_subnet_2_cidr_block
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

    tags = {
        Name = "public-us-east-1b"
        "kubernetes.io/cluster/kubernetes-fortress" = "shared"
        "kubernetes.io/role/elb" = "1"
    }
}

//Create private subnet named "private-us-east-1a"
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.project8_vpc.id
  cidr_block              = var.private_subnet_1_cidr_block
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

    tags = {
        Name = "private-us-east-1a"
        "kubernetes.io/cluster/kubernetes-fortress" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

//Create private subnet named "private-us-east-1b"
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.project8_vpc.id
  cidr_block              = var.private_subnet_2_cidr_block
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

    tags = {
        Name = "private-us-east-1b"
        "kubernetes.io/cluster/kubernetes-fortress" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

//Create Internet Gateway named "fortress-igw"
resource "aws_internet_gateway" "fortress_igw" {
  vpc_id = aws_vpc.project8_vpc.id

    tags = {
        Name = "fortress-igw"
    }
}

//Create Elastic IP for the NAT Gateway
resource "aws_eip" "fortress_eip" {
    tags = {
        Name = "fortress-eip"
    }
}

//Create NAT Gateway named "fortress-nat" in public subnet 1
resource "aws_nat_gateway" "fortress_nat" {
  allocation_id = aws_eip.fortress_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

    tags = {
        Name = "fortress-nat"
    }
}

// --- PUBLIC ROUTING --- //

//Create Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.project8_vpc.id

    tags = {
        Name = "public-rt"
    }
}

//Route 0.0.0.0/0 to the Internet Gateway
resource "aws_route" "public_rt_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.fortress_igw.id
}

//Associate Public Subnet 1 with Public Route Table
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

//Associate Public Subnet 2 with Public Route Table
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

// --- PRIVATE ROUTING --- //

// Create Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.project8_vpc.id

  tags = {
    Name = "private-rt"
  }
}

// Map the 0.0.0.0/0 route in the Private Table to the NAT Gateway
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.fortress_nat.id
}

// Associate Private Subnet 1 with the Private Route Table
resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

// Associate Private Subnet 2 with the Private Route Table
resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}