---
title: Outputs
description: Complete reference for sls.tf module outputs
sidebar:
  order: 2
---

# Module Outputs

Complete reference for all outputs provided by the sls.tf module.

## Infrastructure Outputs

### api_gateway_invoke_url

**Description**: The invoke URL for the API Gateway REST API

**Type**: `string`

**Example**: `https://abc123.execute-api.us-east-1.amazonaws.com/dev`

**Usage**:
```hcl
output "api_url" {
  description = "API Gateway invoke URL"
  value       = module.serverless_service.api_gateway_invoke_url
}

# Use in other resources
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  alias {
    name                   = module.serverless_service.api_gateway_invoke_url
    zone_id               = module.serverless_service.api_gateway_zone_id
    evaluate_target_health = true
  }
}
```

### api_gateway_id

**Description**: The ID of the API Gateway REST API

**Type**: `string`

**Example**: `abc123def456`

**Usage**:
```hcl
output "api_id" {
  description = "API Gateway ID"
  value       = module.serverless_service.api_gateway_id
}
```

### api_gateway_stage_name

**Description**: The stage name for the API Gateway deployment

**Type**: `string`

**Example**: `dev`

**Usage**:
```hcl
output "stage_name" {
  description = "API Gateway stage name"
  value       = module.serverless_service.api_gateway_stage_name
}
```

### api_gateway_zone_id

**Description**: The CloudFront zone ID for the API Gateway

**Type**: `string`

**Example**: `Z2FDTNDATAQYW2`

**Usage**:
```hcl
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  alias {
    name                   = module.serverless_service.api_gateway_invoke_url
    zone_id               = module.serverless_service.api_gateway_zone_id
    evaluate_target_health = true
  }
}
```

## Lambda Function Outputs

### function_names

**Description**: List of all Lambda function names

**Type**: `list(string)`

**Example**: `["my-service-dev-hello", "my-service-dev-api"]`

**Usage**:
```hcl
output "lambda_functions" {
  description = "Deployed Lambda function names"
  value       = module.serverless_service.function_names
}

# Use in monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(module.serverless_service.function_names)

  alarm_name          = "${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "120"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = each.value
  }
}
```

### function_arns

**Description**: List of all Lambda function ARNs

**Type**: `list(string)`

**Example**: `["arn:aws:lambda:us-east-1:123456789012:function:my-service-dev-hello"]`

**Usage**:
```hcl
output "lambda_arns" {
  description = "Lambda function ARNs"
  value       = module.serverless_service.function_arns
}

# Use in event source mappings
resource "aws_lambda_event_source_mapping" "s3_to_lambda" {
  event_source_arn = aws_s3_bucket.data.arn
  function_name    = module.serverless_service.function_arns[0]
  starting_position = "LATEST"
}
```

### function_names_map

**Description**: Map of function logical names to actual function names

**Type**: `map(string)`

**Example**:
```json
{
  "hello": "my-service-dev-hello",
  "api": "my-service-dev-api"
}
```

**Usage**:
```hcl
output "function_map" {
  description = "Function name mapping"
  value       = module.serverless_service.function_names_map
}

# Access specific function by logical name
locals {
  hello_function_name = module.serverless_service.function_names_map["hello"]
}
```

### function_arns_map

**Description**: Map of function logical names to function ARNs

**Type**: `map(string)`

**Example**:
```json
{
  "hello": "arn:aws:lambda:us-east-1:123456789012:function:my-service-dev-hello",
  "api": "arn:aws:lambda:us-east-1:123456789012:function:my-service-dev-api"
}
```

**Usage**:
```hcl
output "function_arn_map" {
  description = "Function ARN mapping"
  value       = module.serverless_service.function_arns_map
}
```

### role_arn

**Description**: The ARN of the IAM role used by Lambda functions

**Type**: `string`

**Example**: `arn:aws:iam::123456789012:role/my-service-dev-lambda-role`

**Usage**:
```hcl
output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = module.serverless_service.role_arn
}

# Use in other resources that need the role
resource "aws_iam_role_policy_attachment" "additional_permissions" {
  role       = module.serverless_service.role_arn
  policy_arn = aws_iam_policy.additional.arn
}
```

## DynamoDB Outputs

### dynamodb_table_names

**Description**: List of DynamoDB table names

**Type**: `list(string)`

**Example**: `["my-service-dev-users", "my-service-dev-sessions"]`

**Usage**:
```hcl
output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.serverless_service.dynamodb_table_names
}
```

### dynamodb_table_arns

**Description**: List of DynamoDB table ARNs

**Type**: `list(string)`

**Example**: `["arn:aws:dynamodb:us-east-1:123456789012:table/my-service-dev-users"]`

**Usage**:
```hcl
output "dynamodb_table_arns" {
  description = "DynamoDB table ARNs"
  value       = module.serverless_service.dynamodb_table_arns
}

# Use in Lambda permissions
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "dynamodb-access"
  role = module.serverless_service.role_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = module.serverless_service.dynamodb_table_arns
      }
    ]
  })
}
```

### dynamodb_table_names_map

**Description**: Map of table logical names to actual table names

**Type**: `map(string)`

**Example**:
```json
{
  "UsersTable": "my-service-dev-users",
  "SessionsTable": "my-service-dev-sessions"
}
```

**Usage**:
```hcl
output "dynamodb_table_map" {
  description = "DynamoDB table name mapping"
  value       = module.serverless_service.dynamodb_table_names_map
}

# Access specific table by logical name
locals {
  users_table = module.serverless_service.dynamodb_table_names_map["UsersTable"]
}
```

## S3 Bucket Outputs

### s3_bucket_names

**Description**: List of S3 bucket names

**Type**: `list(string)`

**Example**: `["my-service-dev-uploads", "my-service-dev-static"]`

**Usage**:
```hcl
output "s3_buckets" {
  description = "S3 bucket names"
  value       = module.serverless_service.s3_bucket_names
}
```

### s3_bucket_arns

**Description**: List of S3 bucket ARNs

**Type**: `list(string)`

**Example**: `["arn:aws:s3:::my-service-dev-uploads"]`

**Usage**:
```hcl
output "s3_bucket_arns" {
  description = "S3 bucket ARNs"
  value       = module.serverless_service.s3_bucket_arns
}
```

### s3_bucket_domain_names

**Description**: List of S3 bucket domain names

**Type**: `list(string)`

**Example**: `["my-service-dev-uploads.s3.amazonaws.com"]`

**Usage**:
```hcl
output "s3_domains" {
  description = "S3 bucket domain names"
  value       = module.serverless_service.s3_bucket_domain_names
}
```

## EventBridge Outputs

### event_bus_names

**Description**: List of EventBridge event bus names

**Type**: `list(string)`

**Example**: `["my-service-dev-events"]`

**Usage**:
```hcl
output "event_buses" {
  description = "EventBridge event bus names"
  value       = module.serverless_service.event_bus_names
}
```

### event_rule_names

**Description**: List of EventBridge rule names

**Type**: `list(string)`

**Example**: `["my-service-dev-user-created", "my-service-dev-payment-processed"]`

**Usage**:
```hcl
output "event_rules" {
  description = "EventBridge rule names"
  value       = module.serverless_service.event_rule_names
}
```

## SNS/SQS Outputs

### sns_topic_arns

**Description**: List of SNS topic ARNs

**Type**: `list(string)`

**Example**: `["arn:aws:sns:us-east-1:123456789012:my-service-dev-notifications"]`

**Usage**:
```hcl
output "sns_topics" {
  description = "SNS topic ARNs"
  value       = module.serverless_service.sns_topic_arns
}
```

### sqs_queue_urls

**Description**: List of SQS queue URLs

**Type**: `list(string)`

**Example**: `["https://sqs.us-east-1.amazonaws.com/123456789012/my-service-dev-jobs"]`

**Usage**:
```hcl
output "sqs_queues" {
  description = "SQS queue URLs"
  value       = module.serverless_service.sqs_queue_urls
}
```

## CloudWatch Outputs

### log_group_names

**Description**: List of CloudWatch log group names

**Type**: `list(string)`

**Example**: `["/aws/lambda/my-service-dev-hello", "/aws/lambda/my-service-dev-api"]`

**Usage**:
```hcl
output "log_groups" {
  description = "CloudWatch log group names"
  value       = module.serverless_service.log_group_names
}
```

### log_group_arns

**Description**: List of CloudWatch log group ARNs

**Type**: `list(string)`

**Example**: `["arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/my-service-dev-hello"]`

**Usage**:
```hcl
output "log_group_arns" {
  description = "CloudWatch log group ARNs"
  value       = module.serverless_service.log_group_arns
}
```

## Configuration Outputs

### service_name

**Description**: The service name from the Serverless configuration

**Type**: `string`

**Example**: `my-service`

**Usage**:
```hcl
output "service" {
  description = "Service name"
  value       = module.serverless_service.service_name
}
```

### stage

**Description**: The deployment stage

**Type**: `string`

**Example**: `dev`

**Usage**:
```hcl
output "stage" {
  description = "Deployment stage"
  value       = module.serverless_service.stage
}
```

### region

**Description**: The AWS region

**Type**: `string`

**Example**: `us-east-1`

**Usage**:
```hcl
output "region" {
  description = "AWS region"
  value       = module.serverless_service.region
}
```

### runtime

**Description**: The Lambda runtime

**Type**: `string`

**Example**: `nodejs18.x`

**Usage**:
```hcl
output "runtime" {
  description = "Lambda runtime"
  value       = module.serverless_service.runtime
}
```

## Complete Output Example

```hcl
# Main terraform configuration
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path      = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"
}

# Output all important values
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.serverless_service.api_gateway_invoke_url
}

output "lambda_functions" {
  description = "Deployed Lambda function names"
  value       = module.serverless_service.function_names
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.serverless_service.dynamodb_table_names
}

output "s3_buckets" {
  description = "S3 bucket names"
  value       = module.serverless_service.s3_bucket_names
}

output "service_info" {
  description = "Service information"
  value = {
    name    = module.serverless_service.service_name
    stage   = module.serverless_service.stage
    region  = module.serverless_service.region
    runtime = module.serverless_service.runtime
  }
}
```

## Usage in Terraform Workspaces

```hcl
# Use outputs in other modules or resources
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = module.serverless_service.api_gateway_invoke_url
    origin_id   = "api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ... rest of configuration
}

# Conditional outputs
locals {
  is_production = module.serverless_service.stage == "prod"
}

resource "aws_cloudwatch_metric_alarm" "production_alerts" {
  count = local.is_production ? 1 : 0

  alarm_name          = "${module.serverless_service.service_name}-production-errors"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "5"
  # ... rest of configuration
}
```

## Next Steps

- 📖 [Resource Types](../api/resource-types) - Complete resource type reference
- 🔧 [Advanced Features](../advanced/custom-resources) - Advanced configuration
- 📚 [Examples](../examples/basic-service) - Real-world examples

---

<div class="hero-buttons">
  <a href="../api/resource-types" class="btn">Next: Resource Types</a>
  <a href="../features/lambda-functions" class="btn secondary">Learn About Features</a>
</div>