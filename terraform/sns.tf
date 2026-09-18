# ============================================================
# SNS ALERTING
# ============================================================

resource "aws_sns_topic" "gambit_alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = {
    Name = "${var.project_name}-${var.environment}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.gambit_alerts.arn
  protocol  = "email"
  endpoint  = "olakunle.kushehin@outlook.com"
}