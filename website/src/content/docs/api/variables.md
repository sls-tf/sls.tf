---
title: Variables
description: Complete reference for sls.tf input variables
sidebar:
  order: 1
---

# Input Variables

Complete reference for all configurable input variables in the sls.tf module.

## Required Variables

### config_path

**Description**: Path to the Serverless Framework configuration file (YAML or TypeScript)

**Type**: `string`

**Required**: Yes

**Example**:
```hcl
config_path = "${path.module}/serverless.yml"
```

**Supported Formats**:
- `.yml` or `.yaml` - Standard Serverless Framework YAML
- `.ts` - TypeScript configuration (requires `config_format = "typescript"`)

### lambda_code_path

**Description**: Path to the directory containing Lambda function source code

**Type**: `string`

**Required**: Yes

**Example**:
```hcl
lambda_code_path = "${path.module}/src"
```

## Optional Variables

### aws_region

**Description**: AWS region where resources will be deployed

**Type**: `string`

**Default**: Provider's default region

**Example**:
```hcl
aws_region = "us-west-2"
```

### config_format

**Description**: Format of the configuration file

**Type**: `string`

**Default**: `"yaml"`

**Available Values**:
- `"yaml"` - Serverless Framework YAML configuration
- `"typescript"` - TypeScript configuration file

**Example**:
```hcl
config_format = "typescript"
```

### environment

**Description**: Environment variables to apply to all Lambda functions

**Type**: `map(string)`

**Default**: `{}`

**Example**:
```hcl
environment = {
  NODE_ENV = "production"
  LOG_LEVEL = "info"
  API_VERSION = "v1"
}
```

### tags

**Description**: Tags to apply to all created resources

**Type**: `map(string)`

**Default**: `{}`

**Example**:
```hcl
tags = {
  Project = "my-serverless-app"
  Environment = "production"
  Team = "platform"
  CostCenter = "engineering"
}
```

### prefix

**Description**: Prefix to add to all resource names

**Type**: `string`

**Default**: `""`

**Example**:
```hcl
prefix = "prod-"
```

### deployment_bucket

**Description**: S3 bucket for Lambda deployment packages

**Type**: `string`

**Default**: `""` (auto-generated)

**Example**:
```hcl
deployment_bucket = "my-app-deployments"
```

### role_arn

**Description**: Custom IAM role ARN for Lambda functions

**Type**: `string`

**Default**: `""` (auto-generated role)

**Example**:
```hcl
role_arn = "arn:aws:iam::123456789012:role/lambda-execution-role"
```

### vpc_config

**Description**: VPC configuration for Lambda functions

**Type**:
```hcl
object({
  security_group_ids = list(string)
  subnet_ids         = list(string)
})
```

**Default**: `null`

**Example**:
```hcl
vpc_config = {
  security_group_ids = ["sg-12345678"]
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
}
```

### log_retention

**Description**: CloudWatch log retention period in days

**Type**: `number`

**Default**: `14`

**Available Values**: `1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653`

**Example**:
```hcl
log_retention = 30
```

### memory_size

**Description**: Default memory size for Lambda functions (MB)

**Type**: `number`

**Default**: `256`

**Range**: `128 - 10240`

**Example**:
```hcl
memory_size = 512
```

### timeout

**Description**: Default timeout for Lambda functions (seconds)

**Type**: `number`

**Default**: `30`

**Range**: `1 - 900`

**Example**:
```hcl
timeout = 60
```

## Advanced Variables

### custom_variables

**Description**: Custom variables to inject into configuration parsing

**Type**: `map(string)`

**Default**: `{}`

**Example**:
```hcl
custom_variables = {
  API_KEY = "my-secret-key"
  DB_HOST = "my-db.example.com"
  REDIS_URL = "redis://my-redis.example.com:6379"
}
```

### enable_lambda_insights

**Description**: Enable Lambda CloudWatch Insights

**Type**: `bool`

**Default**: `false`

**Example**:
```hcl
enable_lambda_insights = true
```

### enable_xray_tracing

**Description**: Enable AWS X-Ray tracing for Lambda functions

**Type**: `bool`

**Default**: `false`

**Example**:
```hcl
enable_xray_tracing = true
```

### lambda_layers

**Description**: List of Lambda layer ARNs to attach to all functions

**Type**: `list(string)`

**Default**: `[]`

**Example**:
```hcl
lambda_layers = [
  "arn:aws:lambda:us-east-1:123456789012:layer:my-layer:1",
  "arn:aws:lambda:us-east-1:123456789012:layer:another-layer:1"
]
```

### reserved_concurrency

**Description**: Reserved concurrency for Lambda functions

**Type**: `number`

**Default**: `null`

**Example**:
```hcl
reserved_concurrency = 10
```

### provisioned_concurrency

**Description**: Provisioned concurrency configuration

**Type**:
```hcl
object({
    target = number
    alias  = string
  })
```

**Default**: `null`

**Example**:
```hcl
provisioned_concurrency = {
  target = 5
  alias  = "production"
}
```

## API Gateway Variables

### api_gateway_endpoint_type

**Description**: API Gateway endpoint type

**Type**: `string`

**Default**: `"REGIONAL"`

**Available Values**: `"REGIONAL"`, `"EDGE"`, `"PRIVATE"`

**Example**:
```hcl
api_gateway_endpoint_type = "EDGE"
```

### api_gateway_stage_variables

**Description**: Stage variables for API Gateway

**Type**: `map(string)`

**Default**: `{}`

**Example**:
```hcl
api_gateway_stage_variables = {
  lambda_version = "v1.0"
  debug_level    = "info"
}
```

### enable_api_gateway_logging

**Description**: Enable API Gateway access logging

**Type**: `bool`

**Default**: `true`

**Example**:
```hcl
enable_api_gateway_logging = true
```

### api_gateway_log_format

**Description**: API Gateway log format

**Type**: `string`

**Default**: JSON format

**Example**:
```hcl
api_gateway_log_format = "{ \"requestId\":\"$context.requestId\", \"ip\": \"$context.identity.sourceIp\" }"
```

## Security Variables

### enable_resource_based_policy

**Description**: Enable resource-based policies for API Gateway

**Type**: `bool`

**Default**: `true`

**Example**:
```hcl
enable_resource_based_policy = true
```

### cors_enabled

**Description**: Enable CORS for all HTTP endpoints

**Type**: `bool`

**Default**: `true`

**Example**:
```hcl
cors_enabled = true
```

### cors_origins

**Description**: Allowed CORS origins

**Type**: `list(string)`

**Default**: `["*"]`

**Example**:
```hcl
cors_origins = ["https://myapp.example.com", "https://admin.myapp.example.com"]
```

### cors_headers

**Description**: Allowed CORS headers

**Type**: `list(string)`

**Default**: `["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token"]`

**Example**:
```hcl
cors_headers = ["Content-Type", "Authorization", "X-Custom-Header"]
```

## Monitoring Variables

### enable_cloudwatch_alarms

**Description**: Enable CloudWatch alarms for Lambda functions

**Type**: `bool`

**Default**: `false`

**Example**:
```hcl
enable_cloudwatch_alarms = true
```

### alarm_threshold

**Description**: CloudWatch alarm thresholds

**Type**:
```hcl
object({
    error_rate    = number
    duration      = number
    throttles     = number
    invocations   = number
  })
```

**Default**:
```hcl
{
  error_rate  = 5.0
  duration    = 300
  throttles   = 10
  invocations = 100
}
```

### sns_notification_arn

**Description**: SNS topic ARN for alarm notifications

**Type**: `string`

**Default**: `""`

**Example**:
```hcl
sns_notification_arn = "arn:aws:sns:us-east-1:123456789012:my-alerts"
```

## Variable Validation

### Validation Rules

sls.tf validates variables with the following rules:

1. **config_path** must exist and be readable
2. **lambda_code_path** must exist and be a directory
3. **aws_region** must be a valid AWS region
4. **memory_size** must be between 128 and 10240 MB
5. **timeout** must be between 1 and 900 seconds
6. **log_retention** must be a valid CloudWatch retention period

### Error Examples

**Invalid config_path**:
```
Error: Configuration file '/path/to/serverless.yml' does not exist or is not readable
```

**Invalid memory_size**:
```
Error: memory_size must be between 128 and 10240 MB, got: 2048
```

**Invalid aws_region**:
```
Error: 'invalid-region' is not a valid AWS region
```

## Usage Examples

### Basic Configuration
```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path      = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"
}
```

### Production Configuration
```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path      = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/dist"
  config_format    = "typescript"

  aws_region = "us-east-1"
  environment = {
    NODE_ENV = "production"
    LOG_LEVEL = "error"
  }

  tags = {
    Project     = "my-api"
    Environment = "production"
    ManagedBy   = "terraform"
  }

  memory_size = 512
  timeout     = 60

  enable_lambda_insights = true
  enable_xray_tracing    = true

  log_retention = 30

  vpc_config = {
    security_group_ids = [data.aws_security_group.app.id]
    subnet_ids         = data.aws_subnets.private.ids
  }

  enable_cloudwatch_alarms = true
  sns_notification_arn     = aws_sns_topic.alerts.arn
}
```

### Development Configuration
```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path      = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"

  aws_region = "us-west-2"
  environment = {
    NODE_ENV = "development"
    DEBUG    = "true"
  }

  tags = {
    Project     = "my-api"
    Environment = "development"
  }

  memory_size = 256
  timeout     = 30

  log_retention = 7
}
```

## Next Steps

- 📖 [Outputs Reference](../api/outputs) - Learn about module outputs
- 🔧 [Advanced Configuration](../advanced/custom-resources) - Advanced configuration options
- 📚 [Examples](../examples/basic-service) - Real-world usage examples

---

<div class="hero-buttons">
  <a href="../api/outputs" class="btn">Next: Outputs</a>
  <a href="../examples/basic-service" class="btn secondary">View Examples</a>
</div>