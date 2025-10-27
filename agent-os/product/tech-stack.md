# Tech Stack

## Infrastructure as Code
- **Primary Language:** Terraform (HCL) - Infrastructure definition, resource provisioning, state management
- **Terraform Version:** 1.0+ (requires yamldecode function and external data source support)
- **Module Pattern:** Reusable Terraform module with variable-driven configuration

## Configuration Parsing
- **YAML Parser:** Terraform's native yamldecode() function - Parse serverless.yml without external dependencies
- **TypeScript Runtime:** Node.js with ts-node - Execute and parse serverless.ts files via external data source
- **Node.js Version:** 14+ (for TypeScript configuration support)
- **Package Manager:** npm (for ts-node and TypeScript dependencies in parsing scripts)

## AWS Services (Managed via Terraform)
- **Compute:** AWS Lambda (aws_lambda_function, aws_lambda_permission, aws_lambda_event_source_mapping)
- **API Gateway:** AWS API Gateway REST API and HTTP API (aws_api_gateway_*, aws_apigatewayv2_*)
- **Storage:** AWS S3 (aws_s3_bucket, aws_s3_bucket_notification)
- **Database:** AWS DynamoDB (aws_dynamodb_table, DynamoDB Streams integration)
- **Event Management:** AWS EventBridge (aws_cloudwatch_event_rule, aws_cloudwatch_event_target)
- **Messaging:** AWS SQS, SNS (aws_sqs_queue, aws_sns_topic)
- **CDN:** AWS CloudFront (aws_cloudfront_distribution)
- **DNS:** AWS Route 53 (aws_route53_zone, aws_route53_record)
- **IAM:** AWS IAM (aws_iam_role, aws_iam_role_policy, aws_iam_role_policy_attachment)

## Testing & Quality
- **Test Framework:** Terraform testing framework (terraform test) or Terratest (Go-based integration testing)
- **Validation:** Terraform validation (terraform validate, variable validation rules)
- **Linting:** TFLint - Terraform linting and best practices enforcement
- **Formatting:** terraform fmt - Consistent HCL code formatting
- **Security Scanning:** tfsec or Checkov - Infrastructure security and compliance scanning

## Development & Tooling
- **Version Control:** Git
- **Configuration Format Support:** YAML (serverless.yml) and TypeScript (serverless.ts)
- **External Data Sources:** Terraform external data source for TypeScript parsing scripts
- **Dynamic Resource Generation:** Terraform for_each, dynamic blocks, conditional expressions

## CI/CD & Deployment
- **CI/CD Platform:** GitHub Actions, GitLab CI, or Jenkins (user's choice)
- **Terraform Backend:** S3 + DynamoDB for state locking (recommended) or Terraform Cloud
- **State Management:** Terraform remote state with workspace support
- **Deployment Pattern:** GitOps with pull request-based terraform plan review

## Documentation & Examples
- **Documentation Format:** Markdown (README.md, example configurations)
- **Module Documentation:** terraform-docs for automatic variable and output documentation generation
- **Example Configurations:** Sample serverless.yml and serverless.ts files demonstrating supported features

## Third-Party Integrations
- **Serverless Framework Compatibility:** Support for Serverless Framework 2.x and 3.x configuration schema
- **TypeScript Support:** TypeScript 4.x+ for type-safe serverless.ts configurations
- **Policy as Code:** Open Policy Agent (OPA) or HashiCorp Sentinel for infrastructure policy enforcement (optional)

## Monitoring & Observability (User-Configured)
- **AWS CloudWatch:** Lambda logs, metrics, and alarms (provisioned by module if configured)
- **Terraform State Monitoring:** State drift detection via scheduled terraform plan runs
- **Infrastructure Tracking:** Terraform state outputs for integration with external monitoring tools
