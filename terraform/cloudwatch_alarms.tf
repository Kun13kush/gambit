# ============================================================
# ECS CPU ALARMS
# ============================================================

resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-cpu-high"
  alarm_description   = "Backend ECS service CPU utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-frontend-cpu-high"
  alarm_description   = "Frontend ECS service CPU utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }
}

# ============================================================
# ECS MEMORY ALARMS
# ============================================================

resource "aws_cloudwatch_metric_alarm" "backend_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-memory-high"
  alarm_description   = "Backend ECS service memory utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-frontend-memory-high"
  alarm_description   = "Frontend ECS service memory utilization is above 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }
}

# ============================================================
# ECS RUNNING TASK ALARMS
# ============================================================

resource "aws_cloudwatch_metric_alarm" "backend_no_running_tasks" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-no-running-tasks"
  alarm_description   = "Backend ECS service has no running tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_no_running_tasks" {
  alarm_name          = "${var.project_name}-${var.environment}-frontend-no-running-tasks"
  alarm_description   = "Frontend ECS service has no running tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }
}

# ============================================================
# ALB TARGET 5XX ALARMS
# ============================================================

resource "aws_cloudwatch_metric_alarm" "backend_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-5xx"
  alarm_description   = "Backend target is returning HTTP 5XX responses"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.gambit.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-frontend-5xx"
  alarm_description   = "Frontend target is returning HTTP 5XX responses"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.gambit.arn_suffix
    TargetGroup  = aws_lb_target_group.frontend.arn_suffix
  }
}

# ============================================================
# ALB UNHEALTHY TARGET ALARMS
# ============================================================

resource "aws_cloudwatch_metric_alarm" "backend_unhealthy_targets" {
  alarm_name          = "${var.project_name}-${var.environment}-backend-unhealthy-targets"
  alarm_description   = "Backend ALB target is unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.gambit.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "frontend_unhealthy_targets" {
  alarm_name          = "${var.project_name}-${var.environment}-frontend-unhealthy-targets"
  alarm_description   = "Frontend ALB target is unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.gambit_alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.gambit.arn_suffix
    TargetGroup  = aws_lb_target_group.frontend.arn_suffix
  }
}
