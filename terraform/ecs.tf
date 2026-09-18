# ============================================================
# ECS CLUSTER
# ============================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs"
  }
}

# ============================================================
# BACKEND TASK DEFINITION
# ============================================================

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-${var.environment}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
  {
    name      = "backend"
    image     = "${var.backend_ecr_repository_url}:9aed1b7e72237415c55436cf5cbca47a3346384b"
    essential = true

    portMappings = [
      {
        containerPort = 8000
        protocol      = "tcp"
      }
    ]

    environment = [
      {
        name  = "ENVIRONMENT"
        value = "production"
      },
      {
        name  = "APP_VERSION"
        value = "1.0.0"
      }
    ]

    secrets = [
      {
        name      = "DB_USERNAME"
        valueFrom = "${aws_db_instance.gambit.master_user_secret[0].secret_arn}:username::"
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${aws_db_instance.gambit.master_user_secret[0].secret_arn}:password::"
      },
      {
        name      = "DB_HOST"
        valueFrom = "${aws_db_instance.gambit.master_user_secret[0].secret_arn}:host::"
      },
      {
        name      = "DB_PORT"
        valueFrom = "${aws_db_instance.gambit.master_user_secret[0].secret_arn}:port::"
      },
      {
        name      = "DB_NAME"
        valueFrom = "${aws_db_instance.gambit.master_user_secret[0].secret_arn}:dbname::"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"

      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "backend"
      }
    }
  }
])

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-task"
  }
}

# ============================================================
# FRONTEND TASK DEFINITION
# ============================================================

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${var.frontend_ecr_repository_url}:9aed1b7e72237415c55436cf5cbca47a3346384b"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "frontend"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend-task"
  }
}

# ============================================================
# BACKEND ECS SERVICE
# ============================================================

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-${var.environment}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn

  desired_count = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  depends_on = [
    aws_lb_listener.http
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-service"
  }
}

# ============================================================
# FRONTEND ECS SERVICE
# ============================================================

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-${var.environment}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn

  desired_count = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  depends_on = [
    aws_lb_listener.http
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend-service"
  }
}