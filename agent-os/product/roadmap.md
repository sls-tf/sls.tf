# Product Roadmap

1. [x] Core Module Structure & YAML Parsing - Create the foundational Terraform module with variables for configuration file path and format, implement YAML parsing using yamldecode(), and establish the module's input/output interface including validation for required Serverless Framework fields `S` ✅ COMPLETED

2. [x] Lambda Function Translation - Parse Serverless Framework function definitions from configuration and generate aws_lambda_function resources with runtime, handler, memory, timeout, and environment variables, including automatic IAM role creation with basic execution permissions `M` ✅ COMPLETED

3. [ ] IAM Role & Policy Management - Implement translation of Serverless Framework iamRoleStatements to aws_iam_role_policy attachments, supporting action wildcards, resource ARN references, and automatic role association with Lambda functions `M`

4. [ ] API Gateway REST API Integration - Generate aws_api_gateway_rest_api, aws_api_gateway_resource, aws_api_gateway_method, and aws_api_gateway_integration resources from Serverless http events, including CORS configuration and deployment stage creation `L`

5. [ ] S3 Event Source Mapping - Provision S3 bucket notification configurations (aws_s3_bucket_notification) from Serverless s3 events with event type filtering, prefix/suffix patterns, and Lambda permission grants `S`

6. [ ] TypeScript Configuration Parsing - Implement external data source with Node.js/ts-node executor to parse serverless.ts files, handle async exports, and convert TypeScript configuration to JSON for Terraform consumption `M`

7. [ ] EventBridge Rules & Schedulers - Translate Serverless eventBridge and schedule events into aws_cloudwatch_event_rule and aws_cloudwatch_event_target resources, supporting both cron/rate expressions and custom event patterns `M`

8. [ ] DynamoDB & SQS Event Sources - Create aws_lambda_event_source_mapping resources for DynamoDB streams and SQS queues from Serverless stream and sqs events, including batch size, starting position, and error handling configuration `S`

9. [ ] Custom Resource Provisioning - Parse the Serverless resources section and translate CloudFormation-style resource definitions to equivalent Terraform resources for S3 buckets, DynamoDB tables, SNS topics, and SQS queues `L`

10. [ ] Variable Resolution Engine - Implement resolution for Serverless variable syntax (${self:}, ${env:}, ${opt:}, ${cf:}) by mapping to Terraform variables, local values, and data source lookups where applicable `M`

11. [ ] CloudFront Distribution Support - Generate aws_cloudfront_distribution resources from Serverless cloudFront configuration including origin settings, cache behaviors, SSL certificate integration, and custom error responses `M`

12. [ ] Route 53 & Custom Domain Management - Provision aws_route53_zone and aws_route53_record resources from Serverless customDomain configuration, with automatic API Gateway domain name and base path mapping creation `S`

13. [ ] Schema Synchronization Tooling - Develop automated tooling to generate Terraform validation code from the Serverless Framework JSON schema, ensuring validation rules stay synchronized with schema evolution across Framework versions 2.x, 3.x, and 4.x `M`

> Notes
> - Each item represents a complete, testable feature with both parsing logic and AWS resource generation
> - Items are ordered by technical dependencies: core infrastructure first, then basic resources, followed by event integrations and advanced features
> - Most direct path to mission: establish YAML parsing and Lambda translation (items 1-3) to enable basic function deployment, then add event sources and integrations (items 4-8) for complete serverless application support, finally advanced features (items 9-13) for production-grade deployments and maintainability
