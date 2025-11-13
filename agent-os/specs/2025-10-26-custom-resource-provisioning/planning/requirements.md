# Requirements: Custom Resource Provisioning

## Overview
Parse the Serverless Framework `resources` section and translate CloudFormation-style resource definitions to equivalent Terraform resources for S3 buckets, DynamoDB tables, SNS topics, and SQS queues.

## Feature Context
This feature is part of roadmap item 9, enabling translation of custom infrastructure resources defined in Serverless Framework configuration files to Terraform. It focuses on the most common AWS resources used in serverless applications.

## User Stories

### As a developer migrating from Serverless Framework to Terraform
- I want my custom S3 buckets defined in the `resources` section to be automatically translated to `aws_s3_bucket` resources
- I want my DynamoDB tables to be converted to `aws_dynamodb_table` resources with proper attributes and indexes
- I want my SNS topics to be translated to `aws_sns_topic` resources
- I want my SQS queues to be converted to `aws_sqs_queue` resources
- I want CloudFormation intrinsic functions (Ref, GetAtt, Sub, Join) to be mapped to Terraform equivalents

### As a DevOps engineer
- I want resource dependencies and references to be preserved in the Terraform translation
- I want resource naming to follow Terraform conventions while maintaining logical relationships
- I want validation errors when unsupported CloudFormation features are encountered

## Functional Requirements

### 1. CloudFormation Resource Parsing
- Parse the `resources.Resources` section from Serverless configuration
- Support both YAML and TypeScript configuration formats
- Extract resource Type, Properties, DependsOn, and Condition fields
- Validate resource structure against CloudFormation schema

### 2. S3 Bucket Translation
- Translate `AWS::S3::Bucket` to `aws_s3_bucket` and related resources
- Map bucket properties:
  - BucketName → bucket
  - AccessControl → aws_s3_bucket_acl
  - PublicAccessBlockConfiguration → aws_s3_bucket_public_access_block
  - VersioningConfiguration → aws_s3_bucket_versioning
  - LifecycleConfiguration → aws_s3_bucket_lifecycle_configuration
  - CorsConfiguration → aws_s3_bucket_cors_configuration
  - ServerSideEncryptionConfiguration → aws_s3_bucket_server_side_encryption_configuration
- Handle bucket policies via `aws_s3_bucket_policy` resource

### 3. DynamoDB Table Translation
- Translate `AWS::DynamoDB::Table` to `aws_dynamodb_table`
- Map table properties:
  - TableName → name
  - AttributeDefinitions → attribute blocks
  - KeySchema → hash_key and range_key
  - BillingMode → billing_mode
  - ProvisionedThroughput → read_capacity and write_capacity
  - GlobalSecondaryIndexes → global_secondary_index blocks
  - LocalSecondaryIndexes → local_secondary_index blocks
  - StreamSpecification → stream_enabled and stream_view_type
  - SSESpecification → server_side_encryption block
  - Tags → tags map
- Support TimeToLiveSpecification via `aws_dynamodb_table_item` if needed

### 4. SNS Topic Translation
- Translate `AWS::SNS::Topic` to `aws_sns_topic`
- Map topic properties:
  - TopicName → name
  - DisplayName → display_name
  - KmsMasterKeyId → kms_master_key_id
  - Subscription → aws_sns_topic_subscription resources
  - Tags → tags map
- Support `AWS::SNS::Subscription` as separate `aws_sns_topic_subscription` resources

### 5. SQS Queue Translation
- Translate `AWS::SQS::Queue` to `aws_sqs_queue`
- Map queue properties:
  - QueueName → name
  - FifoQueue → fifo_queue
  - ContentBasedDeduplication → content_based_deduplication
  - DelaySeconds → delay_seconds
  - MaximumMessageSize → max_message_size
  - MessageRetentionPeriod → message_retention_seconds
  - ReceiveMessageWaitTimeSeconds → receive_wait_time_seconds
  - VisibilityTimeout → visibility_timeout_seconds
  - RedrivePolicy → redrive_policy (JSON string)
  - KmsMasterKeyId → kms_master_key_id
  - Tags → tags map
- Support dead letter queue configuration

### 6. Intrinsic Function Resolution
- Map CloudFormation intrinsic functions to Terraform equivalents:
  - `!Ref` / `Ref` → resource references (e.g., `aws_s3_bucket.name.id`)
  - `!GetAtt` / `Fn::GetAtt` → resource attribute references
  - `!Sub` / `Fn::Sub` → Terraform string interpolation
  - `!Join` / `Fn::Join` → Terraform `join()` function
  - `!If` / `Fn::If` → Terraform conditional expressions
  - `!Equals` / `Fn::Equals` → Terraform equality operators
- Handle variable references: `${self:...}`, `${env:...}`, `${opt:...}`

### 7. Resource Naming and References
- Generate Terraform resource names from CloudFormation logical IDs
- Convert PascalCase CloudFormation names to snake_case Terraform names
- Maintain resource reference mappings for cross-resource dependencies
- Handle DependsOn by using implicit Terraform dependencies

### 8. Validation and Error Handling
- Validate that resource types are supported (S3, DynamoDB, SNS, SQS)
- Warn on unsupported CloudFormation features
- Report errors for required properties that cannot be mapped
- Provide clear error messages with resource name and location

## Technical Requirements

### Module Structure
- Create `modules/custom_resources/` directory
- Implement resource parsers for each supported type
- Create Terraform resource generators for each type
- Build intrinsic function resolver

### Input Processing
- Accept parsed Serverless configuration with `resources` section
- Extract CloudFormation resources from `resources.Resources`
- Parse resource properties and metadata

### Output Generation
- Generate Terraform resource blocks
- Create `outputs.tf` for resource references
- Generate `locals.tf` for resource mappings

### Dependencies
- Leverage core YAML parsing from roadmap item 1
- Integrate with variable resolution (roadmap item 10) when available
- Coordinate with Lambda function resources (roadmap item 2) for permissions

## Testing Requirements

### Unit Tests
- Test CloudFormation resource parsing for each supported type
- Test intrinsic function resolution with various patterns
- Test resource naming conversion (PascalCase → snake_case)
- Test property mapping for all supported properties

### Integration Tests
- Test complete resource translation for S3 buckets with various configurations
- Test DynamoDB table translation with GSI and LSI
- Test SNS topic with subscriptions
- Test SQS queue with dead letter queue configuration
- Test cross-resource references (e.g., S3 bucket referencing SQS queue)

### Example Configurations
Provide examples translating:
1. S3 bucket with versioning, encryption, and lifecycle rules
2. DynamoDB table with GSI, LSI, and streams
3. SNS topic with email and SQS subscriptions
4. SQS queue with dead letter queue
5. Multi-resource configuration with Ref and GetAtt

## Acceptance Criteria

1. CloudFormation S3 bucket resources are translated to complete Terraform configurations
2. DynamoDB tables with indexes and streams are correctly converted
3. SNS topics with subscriptions are properly translated
4. SQS queues with DLQ configuration work correctly
5. Intrinsic functions (Ref, GetAtt, Sub, Join) are correctly mapped
6. Resource dependencies are preserved in Terraform
7. Unsupported resources produce clear error messages
8. All tests pass with >90% coverage
9. Example configurations successfully deploy with `terraform apply`

## Out of Scope

- Resources other than S3, DynamoDB, SNS, SQS
- CloudFormation custom resources (AWS::CloudFormation::CustomResource)
- CloudFormation stack outputs (handled separately)
- CloudFormation conditions (partial support only)
- CloudFormation parameters (use Terraform variables instead)
- Complex nested CloudFormation transforms

## Dependencies

- Roadmap item 1: Core Module Structure & YAML Parsing (required)
- Roadmap item 10: Variable Resolution Engine (nice to have)

## Size Estimate
Large (L) - Comprehensive resource mapping with multiple AWS services and intrinsic function resolution
