variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "my-web-app"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro" # Free tier eligible
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}