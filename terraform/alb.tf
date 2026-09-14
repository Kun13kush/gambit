resource "aws_lb" "gambit" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# -----------------------------
# Backend Target Group
# -----------------------------

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-${var.environment}-backend"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"

  vpc_id = aws_vpc.gambit.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "8000"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-tg"
  }
}

# -----------------------------
# Frontend Target Group
# -----------------------------

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-${var.environment}-frontend"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"

  vpc_id = aws_vpc.gambit.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend-tg"
  }
}

# -----------------------------
# HTTP Listener
# -----------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.gambit.arn
  port              = 80
  protocol          = "HTTP"

  # Frontend is the default application
  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.frontend.arn
      }
    }
  }
}


# =========================================================
# Backend API Routes
# =========================================================

resource "aws_lb_listener_rule" "backend_health" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.backend.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }
}


resource "aws_lb_listener_rule" "backend_info" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 110

  action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.backend.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/info"]
    }
  }
}


resource "aws_lb_listener_rule" "backend_services" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 120

  action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.backend.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/services", "/services/*"]
    }
  }
}


resource "aws_lb_listener_rule" "backend_deployments" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 130

  action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.backend.arn
      }
    }
  }

  condition {
    path_pattern {
      values = ["/deployments", "/deployments/*"]
    }
  }
}