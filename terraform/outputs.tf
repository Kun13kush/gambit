output "vpc_id" {
  description = "Gambit VPC ID"
  value       = aws_vpc.gambit.id
}

output "vpc_cidr" {
  description = "Gambit VPC CIDR"
  value       = aws_vpc.gambit.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "alb_dns_name" {
  description = "Public DNS name of the Gambit Application Load Balancer"
  value       = aws_lb.gambit.dns_name
}

output "alb_arn" {
  description = "ARN of the Gambit Application Load Balancer"
  value       = aws_lb.gambit.arn
}

output "backend_target_group_arn" {
  description = "ARN of the Gambit backend target group"
  value       = aws_lb_target_group.backend.arn
}
