variable "config_path" {
  description = "Path to the Serverless Framework configuration file (serverless.yml)"
  type        = string

  validation {
    condition     = var.config_path != ""
    error_message = "The config_path must be a non-empty string."
  }
}

variable "config_format" {
  description = "Format of the configuration file (yaml or typescript). Currently only yaml is supported."
  type        = string
  default     = "yaml"

  validation {
    condition     = contains(["yaml", "typescript"], var.config_format)
    error_message = "The config_format must be either 'yaml' or 'typescript'."
  }
}

variable "aws_region" {
  description = "Optional AWS region override. If specified and differs from serverless.yml region, a warning will be displayed and this value will be used."
  type        = string
  default     = null
}

variable "lambda_code_path" {
  description = "Path to Lambda function code directory to package. Defaults to current directory."
  type        = string
  default     = "."

  validation {
    condition     = var.lambda_code_path != ""
    error_message = "lambda_code_path must not be an empty string."
  }
}
