# =========================================================
# RDS SUBNET GROUP
# =========================================================

resource "aws_db_subnet_group" "gambit" {
  name = "${var.project_name}-${var.environment}-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id,
    aws_subnet.private_3.id
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}


# =========================================================
# RDS POSTGRESQL
# =========================================================

resource "aws_db_instance" "gambit" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16.15"

  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "platform"
  username = "platform"

  manage_master_user_password = true

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.gambit.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  multi_az = false

  deletion_protection = true

  skip_final_snapshot = false

  final_snapshot_identifier = "${var.project_name}-${var.environment}-postgres-final"

  apply_immediately = false

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres"
  }
}
