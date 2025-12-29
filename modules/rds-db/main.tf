# RDS Database Module
# This module creates an RDS database instance with automated backups, monitoring, and security features

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Create RDS Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "${var.cluster_name}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-rds-subnet-group"
    }
  )
}

# Create RDS Parameter Group
resource "aws_db_parameter_group" "this" {
  name        = "${var.cluster_name}-rds-parameter-group"
  family      = var.parameter_group_family
  description = "RDS Parameter Group for ${var.cluster_name}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-rds-parameter-group"
    }
  )
}

# Create RDS Option Group
resource "aws_db_option_group" "this" {
  name                     = "${var.cluster_name}-rds-option-group"
  option_group_description = "RDS Option Group for ${var.cluster_name}"
  engine_name              = var.engine
  major_engine_version     = var.engine_version

  dynamic "option" {
    for_each = var.options
    content {
      option_name = option.value.option_name

      dynamic "option_settings" {
        for_each = option.value.option_settings
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-rds-option-group"
    }
  )
}

# Create RDS Instance
resource "aws_db_instance" "this" {
  identifier = var.db_name

  # Engine and version
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.kms_key_id

  # Database settings
  db_name  = var.database_name
  username = var.username
  password = var.password != null ? var.password : random_password.db_password[0].result

  # Network and security
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.this.name
  publicly_accessible    = var.publicly_accessible

  # Backup and maintenance
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Monitoring and performance
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn
  performance_insights_enabled = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period

  # Deletion protection
  deletion_protection = var.deletion_protection

  # IAM database authentication
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # Copy tags to snapshot
  copy_tags_to_snapshot = var.copy_tags_to_snapshot

  # Skip final snapshot
  skip_final_snapshot = var.skip_final_snapshot

  # Tags
  tags = merge(
    var.common_tags,
    {
      Name        = var.db_name
      Environment = var.env
      Account     = var.account
      Cluster     = var.cluster_name
    },
    var.additional_tags
  )

  # Depends on
  depends_on = [
    aws_db_subnet_group.this,
    aws_db_parameter_group.this,
    aws_db_option_group.this
  ]
}

# Create random password if not provided
resource "random_password" "db_password" {
  count = var.password == null ? 1 : 0

  length  = var.password_length
  special = var.password_special_chars
}

# Create CloudWatch Log Group for RDS logs
resource "aws_cloudwatch_log_group" "rds_logs" {
  name              = "/aws/rds/instance/${var.db_name}/${var.engine}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.db_name}-rds-logs"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Enable RDS Enhanced Monitoring (if monitoring role is provided)
resource "aws_rds_integration" "enhanced_monitoring" {
  count = var.monitoring_role_arn != null ? 1 : 0

  source_resource_arn = aws_db_instance.this.arn
  kms_key_id         = var.kms_key_id
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.db_name}-enhanced-monitoring"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Create SNS Topic for RDS notifications (optional)
resource "aws_sns_topic" "rds_notifications" {
  count = var.enable_notifications ? 1 : 0

  name = "${var.db_name}-rds-notifications"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.db_name}-rds-notifications"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Create RDS Event Subscription
resource "aws_db_event_subscription" "this" {
  count = var.enable_notifications && aws_sns_topic.rds_notifications[0].arn != null ? 1 : 0

  name = "${var.db_name}-rds-event-subscription"

  event_categories = var.event_categories
  source_type      = "db-instance"
  source_ids       = [aws_db_instance.this.id]

  sns_topic = aws_sns_topic.rds_notifications[0].arn

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.db_name}-rds-event-subscription"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Create IAM role for RDS monitoring (if needed)
resource "aws_iam_role" "rds_monitoring" {
  count = var.create_monitoring_role ? 1 : 0

  name = "${var.cluster_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-rds-monitoring-role"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Attach RDS monitoring policy to the role
resource "aws_iam_policy_attachment" "rds_monitoring" {
  count = var.create_monitoring_role ? 1 : 0

  name       = "${var.cluster_name}-rds-monitoring-attachment"
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Create Secrets Manager secret for database credentials (optional)
resource "aws_secretsmanager_secret" "db_credentials" {
  count = var.create_secrets_manager_secret ? 1 : 0

  name = "${var.db_name}-credentials"

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.db_name}-credentials"
      Environment = var.env
      Account     = var.account
      Cluster     = var.cluster_name
    }
  )
}

# Create Secrets Manager secret version
resource "aws_secretsmanager_secret_version" "db_credentials" {
  count = var.create_secrets_manager_secret ? 1 : 0

  secret_id = aws_secretsmanager_secret.db_credentials[0].id

  secret_string = jsonencode({
    username = var.username
    password = var.password != null ? var.password : random_password.db_password[0].result
    engine   = var.engine
    host     = aws_db_instance.this.endpoint
    port     = aws_db_instance.this.port
    dbname   = var.database_name
  })
}

# Create IAM policy for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_access" {
  count = var.create_secrets_manager_secret ? 1 : 0

  name        = "${var.cluster_name}-secrets-manager-access"
  description = "Policy to access RDS database credentials in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_credentials[0].arn
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-secrets-manager-access"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Create IAM role for application access to Secrets Manager
resource "aws_iam_role" "app_secrets_access" {
  count = var.create_secrets_manager_secret ? 1 : 0

  name = "${var.cluster_name}-app-secrets-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-app-secrets-access"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Attach Secrets Manager access policy to the role
resource "aws_iam_role_policy_attachment" "app_secrets_access" {
  count = var.create_secrets_manager_secret ? 1 : 0

  role       = aws_iam_role.app_secrets_access[0].name
  policy_arn = aws_iam_policy.secrets_manager_access[0].arn
}

# Create CloudWatch Alarms for RDS metrics (optional)
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.db_name}-cpu-utilization-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.db_name}-cpu-utilization-alarm"
      Environment = var.env
      Account     = var.account
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "free_storage_space" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.db_name}-free-storage-space-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.storage_alarm_threshold
  alarm_description   = "This metric monitors free storage space"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.db_name}-free-storage-space-alarm"
      Environment = var.env
      Account     = var.account
    }
  )
}

# Outputs
output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "The RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "The connection endpoint"
  value       = aws_db_instance.this.endpoint
}

output "db_port" {
  description = "The database port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The database name"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "The master username"
  value       = aws_db_instance.this.username
}

output "db_password" {
  description = "The master password"
  value       = var.password != null ? var.password : random_password.db_password[0].result
  sensitive   = true
}

output "db_subnet_group_name" {
  description = "The RDS subnet group name"
  value       = aws_db_subnet_group.this.name
}

output "db_parameter_group_name" {
  description = "The RDS parameter group name"
  value       = aws_db_parameter_group.this.name
}

output "db_option_group_name" {
  description = "The RDS option group name"
  value       = aws_db_option_group.this.name
}

output "cloudwatch_log_group_name" {
  description = "The CloudWatch log group name for RDS logs"
  value       = aws_cloudwatch_log_group.rds_logs.name
}

output "secrets_manager_secret_arn" {
  description = "The Secrets Manager secret ARN (if created)"
  value       = var.create_secrets_manager_secret ? aws_secretsmanager_secret.db_credentials[0].arn : null
}

output "monitoring_role_arn" {
  description = "The IAM role ARN for RDS monitoring (if created)"
  value       = var.create_monitoring_role ? aws_iam_role.rds_monitoring[0].arn : null
}

output "app_secrets_access_role_arn" {
  description = "The IAM role ARN for application Secrets Manager access (if created)"
  value       = var.create_secrets_manager_secret ? aws_iam_role.app_secrets_access[0].arn : null
}