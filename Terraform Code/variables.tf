//declare variables for the AWS provider
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

//Declare Variables for the vpc name
variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "project8-vpc"
}

//Declare Variables for the vpc cidr block
variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

//Declare Variables for the public subnet 1
variable "public_subnet_1_cidr_block" {
  description = "The CIDR block for the public subnet 1"
  type        = string
  default     = "10.0.1.0/20"
}

//Declare Variables for the public subnet 2
variable "public_subnet_2_cidr_block" {
  description = "The CIDR block for the public subnet 2"
  type        = string
  default     = "10.0.16.0/20"
}

//Declare Variables for the private subnet 1
variable "private_subnet_1_cidr_block" {
  description = "The CIDR block for the private subnet 1"
  type        = string
  default     = "10.0.128.0/20"
}

//Declare Variables for the private subnet 2
variable "private_subnet_2_cidr_block" {
  description = "The CIDR block for the private subnet 2"
  type        = string
  default     = "10.0.144.0/20"
}

