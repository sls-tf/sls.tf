# Package Lambda function code
data "archive_file" "lambda_code" {
  for_each = local.functions_with_defaults

  type        = "zip"
  source_dir  = var.lambda_code_path
  output_path = "${path.module}/.terraform/lambda-${each.key}.zip"

  # Exclude directories and files that should never be in Lambda packages
  # This prevents massive bundles from including .git, .terraform, node_modules, etc.
  excludes = [
    # Version control
    ".git",
    ".git/**",
    "**/.git/**",

    # Terraform files and state
    ".terraform",
    ".terraform/**",
    "**/.terraform/**",
    "*.terraform.lock.hcl",
    "**/.terraform.lock.hcl",
    ".terraform.tfstate.lock.info",
    "**/.terraform.tfstate.lock.info",
    "**/*.tf",
    "**/*.tftest.hcl",
    "**/*.tfstate",
    "**/*.tfstate.backup",
    "**/*.tfvars",

    # IDE and editor directories
    ".idea",
    ".idea/**",
    "**/.idea/**",
    ".vscode",
    ".vscode/**",
    "**/.vscode/**",
    ".claude",
    ".claude/**",
    "**/.claude/**",

    # Dependencies
    "node_modules",
    "node_modules/**",
    "**/node_modules/**",

    # OS files
    "**/.DS_Store",
    "**/Thumbs.db",

    # Project-specific directories (tests, docs, etc.)
    "tests",
    "tests/**",
    "examples",
    "examples/**",
    "agent-os",
    "agent-os/**",
    "docs",
    "docs/**",
    "**/*.md",
    "*.md",
  ]
}

# Lambda package size validation
# Ensures deployment packages don't exceed AWS Lambda limits
resource "null_resource" "lambda_size_validation" {
  for_each = local.functions_with_defaults

  lifecycle {
    # Validate compressed package size (50 MB limit for direct upload)
    precondition {
      condition     = data.archive_file.lambda_code[each.key].output_size <= 52428800 # 50 MB in bytes
      error_message = "Lambda function '${each.key}' deployment package is ${floor(data.archive_file.lambda_code[each.key].output_size / 1048576)} MB (compressed), which exceeds AWS Lambda's 50 MB direct upload limit. Consider: 1) Using S3 for packages >50MB, 2) Reducing dependencies, 3) Using Lambda layers, or 4) Switching to container images for packages >250MB uncompressed."
    }

    # Warning for packages approaching the limit (>40 MB)
    precondition {
      condition     = data.archive_file.lambda_code[each.key].output_size <= 41943040 || data.archive_file.lambda_code[each.key].output_size > 41943040
      error_message = data.archive_file.lambda_code[each.key].output_size > 41943040 ? "WARNING: Lambda function '${each.key}' deployment package is ${floor(data.archive_file.lambda_code[each.key].output_size / 1048576)} MB, approaching the 50 MB limit. Consider optimizing your package size." : ""
    }
  }
}

# IAM execution role for each Lambda function
resource "aws_iam_role" "lambda_execution" {
  for_each = local.functions_with_defaults

  name = "${try(local.parsed_config.service, "unknown")}-${local.provider_with_defaults.stage}-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Service  = try(local.parsed_config.service, "unknown")
    Stage    = local.provider_with_defaults.stage
    Function = each.key
  }
}

# Attach basic execution policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  for_each = local.functions_with_defaults

  role       = aws_iam_role.lambda_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionPolicy"
}

# Custom IAM policies from iamRoleStatements (Roadmap #3)
resource "aws_iam_role_policy" "lambda_custom_policy" {
  for_each = local.functions_with_policies

  name = "${try(local.parsed_config.service, "unknown")}-${local.provider_with_defaults.stage}-${each.key}-policy"
  role = aws_iam_role.lambda_execution[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in each.value : {
        Effect   = stmt.Effect
        Action   = stmt.Action
        Resource = stmt.Resource
      }
    ]
  })
}

# Lambda function resources
resource "aws_lambda_function" "functions" {
  for_each = local.functions_with_defaults

  function_name = "${try(local.parsed_config.service, "unknown")}-${local.provider_with_defaults.stage}-${each.key}"
  role          = aws_iam_role.lambda_execution[each.key].arn

  filename         = data.archive_file.lambda_code[each.key].output_path
  source_code_hash = data.archive_file.lambda_code[each.key].output_base64sha256

  runtime     = each.value.runtime
  handler     = each.value.handler
  memory_size = each.value.memorySize
  timeout     = each.value.timeout

  description = try(each.value.description, null)

  dynamic "environment" {
    for_each = try(each.value.environment, null) != null ? [1] : []
    content {
      variables = each.value.environment
    }
  }

  tags = {
    Service  = try(local.parsed_config.service, "unknown")
    Stage    = local.provider_with_defaults.stage
    Function = each.key
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs
  ]
}

# Main validation resource
# This null_resource enforces parsing and schema validation before proceeding

resource "null_resource" "config_validation" {
  lifecycle {
    # Ensure file was read successfully
    precondition {
      condition     = local.file_content != null
      error_message = "Failed to read configuration file at '${var.config_path}'. Please verify the file exists and is readable."
    }

    # Ensure YAML parsing succeeded
    precondition {
      condition     = local.parsed_config != null
      error_message = "Failed to parse YAML configuration from '${var.config_path}'. Please verify the YAML syntax is valid."
    }

    # Ensure all schema validations passed
    precondition {
      condition     = length(local.validation_errors) == 0
      error_message = "Configuration validation failed with the following errors:\n- ${join("\n- ", local.validation_errors)}"
    }

    # Region override warning (non-blocking)
    precondition {
      condition     = length(local.region_warnings) == 0 || length(local.region_warnings) > 0
      error_message = join("\n", local.region_warnings)
    }
  }

  # Force display of warnings without blocking
  triggers = {
    warnings = length(local.region_warnings) > 0 ? join("\n", local.region_warnings) : ""
  }
}
