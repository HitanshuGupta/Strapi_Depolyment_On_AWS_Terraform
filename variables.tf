# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A name for the project to prefix resources."
  type        = string
  default     = "strapi"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "The EC2 instance type for the Strapi server."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of the EC2 Key Pair to use for SSH access."
  type        = string
}

variable "strapi_repo_url" {
  description = "The HTTPS URL of your Strapi git repository."
  type        = string
}

variable "db_instance_class" {
  description = "The instance class for the RDS database."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "The name of the RDS database."
  type        = string
  default     = "strapi_db"
}

variable "db_username" {
  description = "The master username for the RDS database."
  type        = string
}

variable "db_password" {
  description = "The master password for the RDS database."
  type        = string
  sensitive   = true
}