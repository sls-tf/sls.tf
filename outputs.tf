output "parsed_config" {
  description = "Complete parsed Serverless Framework configuration object"
  value       = local.parsed_config
}

output "service_name" {
  description = "Service name extracted from configuration"
  value       = try(local.parsed_config.service, null)
}

output "provider_config" {
  description = "Provider configuration with defaults applied"
  value       = local.provider_with_defaults
}

output "functions" {
  description = "Map of function definitions with defaults applied"
  value       = local.functions_with_defaults
}

output "custom" {
  description = "Custom configuration section from serverless.yml"
  value       = try(local.parsed_config.custom, null)
}

output "resources" {
  description = "Resources section for custom AWS resources"
  value       = try(local.parsed_config.resources, null)
}

output "package" {
  description = "Packaging configuration section"
  value       = try(local.parsed_config.package, null)
}

output "lambda_packages" {
  description = "Lambda deployment package information (file paths and sizes)"
  value = {
    for key, archive in data.archive_file.lambda_code :
    key => {
      output_path      = archive.output_path
      output_size      = archive.output_size
      output_size_mb   = floor(archive.output_size / 1048576 * 100) / 100 # MB with 2 decimal places
      output_sha256    = archive.output_base64sha256
      within_aws_limit = archive.output_size <= 52428800 # 50 MB
    }
  }
}

output "function_arns" {
  description = "Map of Lambda function ARNs keyed by function name"
  value       = { for k, v in aws_lambda_function.functions : k => v.arn }
}

output "function_names" {
  description = "Map of Lambda function names keyed by function name"
  value       = { for k, v in aws_lambda_function.functions : k => v.function_name }
}

output "role_arns" {
  description = "Map of IAM role ARNs keyed by function name"
  value       = { for k, v in aws_iam_role.lambda_execution : k => v.arn }
}

output "function_invoke_arns" {
  description = "Map of Lambda function invoke ARNs for API Gateway integration"
  value       = { for k, v in aws_lambda_function.functions : k => v.invoke_arn }
}

output "policy_arns" {
  description = "Map of IAM custom policy ARNs keyed by function name (Roadmap #3)"
  value       = { for k, v in aws_iam_role_policy.lambda_custom_policy : k => v.id }
}

output "policy_names" {
  description = "Map of IAM custom policy names keyed by function name (Roadmap #3)"
  value       = { for k, v in aws_iam_role_policy.lambda_custom_policy : k => v.name }
}
