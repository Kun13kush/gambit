variable "aws_region" {
  description = "AWS region for the Gambit platform"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "gambit"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the Gambit VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "frontend_ecr_repository_url" {
  description = "ECR repository URI for the Gambit frontend"
  type        = string
}

variable "backend_ecr_repository_url" {
  description = "ECR repository URI for the Gambit backend"
  type        = string
}