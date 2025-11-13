# Specification: Custom Resource Provisioning

## Overview

This specification defines the custom resource translation module for sls.tf, which parses CloudFormation-style resource definitions from the Serverless Framework `resources` section and translates them to equivalent Terraform resources. This module focuses on the four most common AWS resources used in serverless applications: S3 buckets, DynamoDB tables, SNS topics, and SQS queues. It includes comprehensive property mapping, intrinsic function resolution, and resource dependency management.

**Roadmap Position:** Item #9 - Infrastructure resource provisioning
**Dependencies:** Roadmap item #1 (Core Module Structure & YAML Parsing) - required
**Target Completion:** Enable CloudFormation resource translation to Terraform for core AWS services

## Goal

Parse CloudFormation resource definitions from the Serverless Framework `resources.Resources` section and translate them to native Terraform resources with complete property mapping, intrinsic function resolution, and automatic dependency management.

## User Stories

- As a developer migrating from Serverless Framework, I want my S3 buckets defined in the `resources` section to be automatically translated to `aws_s3_bucket` and related resources so that I don't need to manually rewrite infrastructure code
- As a DevOps engineer, I want my DynamoDB tables with global secondary indexes to be correctly converted to Terraform with all attributes and indexes preserved so that my application data layer continues to work
- As a platform engineer, I want CloudFormation intrinsic functions like `!Ref`, `!GetAtt`, and `!Sub` to be mapped to Terraform equivalents so that resource references and dependencies are maintained
- As an infrastructure team member, I want SNS topics with subscriptions and SQS queues with dead letter configurations to be properly translated so that my messaging infrastructure is preserved
- As a migration architect, I want clear validation errors when unsupported CloudFormation features are encountered so that I can identify what needs manual translation

## Core Requirements

### Functional Requirements

**CloudFormation Resource Parsing:**
- Parse the `resources.Resources` section from Serverless configuration (via roadmap item #1 output)
- Extract resource logical IDs (e.g., "MyBucket", "UsersTable")
- Extract resource Type (e.g., "AWS::S3::Bucket", "AWS::DynamoDB::Table")
- Extract Properties object with all resource configuration
- Extract optional DependsOn field for explicit dependencies
- Extract optional Condition field (partial support only - validation warning)
- Support both YAML short syntax (`!Ref`, `!GetAtt`) and long syntax (`Fn::GetAtt`)

**S3 Bucket Translation:**
- Translate `AWS::S3::Bucket` to multiple Terraform resources (bucket decomposition pattern)
- Create `aws_s3_bucket` for base bucket resource
- Map BucketName property to `bucket` argument (optional, AWS generates if not specified)
- Create `aws_s3_bucket_acl` when AccessControl property exists
- Create `aws_s3_bucket_public_access_block` when PublicAccessBlockConfiguration exists
- Create `aws_s3_bucket_versioning` when VersioningConfiguration exists
- Create `aws_s3_bucket_lifecycle_configuration` when LifecycleConfiguration exists
- Create `aws_s3_bucket_cors_configuration` when CorsConfiguration exists
- Create `aws_s3_bucket_server_side_encryption_configuration` when ServerSideEncryptionConfiguration exists
- Create `aws_s3_bucket_policy` when BucketPolicy reference exists in resources

**DynamoDB Table Translation:**
- Translate `AWS::DynamoDB::Table` to `aws_dynamodb_table` resource
- Map TableName to `name` argument
- Map AttributeDefinitions array to `attribute` blocks (name, type)
- Map KeySchema to `hash_key` and `range_key` arguments
- Map BillingMode to `billing_mode` argument (PROVISIONED or PAY_PER_REQUEST)
- Map ProvisionedThroughput to `read_capacity` and `write_capacity` when BillingMode is PROVISIONED
- Map GlobalSecondaryIndexes to `global_secondary_index` blocks with all properties
- Map LocalSecondaryIndexes to `local_secondary_index` blocks with all properties
- Map StreamSpecification to `stream_enabled` and `stream_view_type` arguments
- Map SSESpecification to `server_side_encryption` block
- Map Tags array to `tags` map (convert CloudFormation tag format to Terraform)
- Map TimeToLiveSpecification to `ttl` block

**SNS Topic Translation:**
- Translate `AWS::SNS::Topic` to `aws_sns_topic` resource
- Map TopicName to `name` argument (optional)
- Map DisplayName to `display_name` argument
- Map KmsMasterKeyId to `kms_master_key_id` argument
- Map Tags array to `tags` map
- Translate Subscription array to separate `aws_sns_topic_subscription` resources
- Handle `AWS::SNS::Subscription` as standalone `aws_sns_topic_subscription` resources
- Map subscription Protocol and Endpoint properties
- Generate subscription resource names from topic name and index

**SQS Queue Translation:**
- Translate `AWS::SQS::Queue` to `aws_sqs_queue` resource
- Map QueueName to `name` argument (optional)
- Map FifoQueue to `fifo_queue` boolean
- Map ContentBasedDeduplication to `content_based_deduplication` boolean
- Map DelaySeconds to `delay_seconds` integer
- Map MaximumMessageSize to `max_message_size` integer
- Map MessageRetentionPeriod to `message_retention_seconds` integer
- Map ReceiveMessageWaitTimeSeconds to `receive_wait_time_seconds` integer
- Map VisibilityTimeout to `visibility_timeout_seconds` integer
- Map RedrivePolicy to `redrive_policy` JSON string with proper structure
- Map KmsMasterKeyId to `kms_master_key_id` argument
- Map Tags array to `tags` map

**Intrinsic Function Resolution:**
- Map `!Ref` (short) and `Fn::Ref` (long) to Terraform resource references
  - Example: `!Ref MyBucket` → `aws_s3_bucket.my_bucket.id`
  - Example: `!Ref UsersTable` → `aws_dynamodb_table.users_table.name`
- Map `!GetAtt` (short) and `Fn::GetAtt` (long) to Terraform attribute references
  - Example: `!GetAtt MyBucket.Arn` → `aws_s3_bucket.my_bucket.arn`
  - Example: `!GetAtt UsersTable.StreamArn` → `aws_dynamodb_table.users_table.stream_arn`
- Map `!Sub` (short) and `Fn::Sub` (long) to Terraform string interpolation
  - Example: `!Sub "arn:aws:s3:::${MyBucket}/*"` → `"arn:aws:s3:::${aws_s3_bucket.my_bucket.id}/*"`
  - Support both simple substitution and template with variables map
- Map `!Join` (short) and `Fn::Join` (long) to Terraform `join()` function
  - Example: `!Join ["-", ["prefix", !Ref Stage]]` → `join("-", ["prefix", var.stage])`
- Map `!If` (short) and `Fn::If` (long) to Terraform conditional expressions
  - Example: `!If [IsProd, "prod-value", "dev-value"]` → `var.is_prod ? "prod-value" : "dev-value"`
- Map `!Equals` (short) and `Fn::Equals` (long) to Terraform equality operators
  - Example: `!Equals [!Ref Stage, "prod"]` → `var.stage == "prod"`
- Handle Serverless Framework variable syntax: `${self:...}`, `${env:...}`, `${opt:...}`
  - Map to Terraform variables or locals as appropriate
  - Note: Full variable resolution requires roadmap item #10

**Resource Naming Convention:**
- Convert CloudFormation logical IDs (PascalCase) to Terraform resource names (snake_case)
  - Example: "MyDataBucket" → "my_data_bucket"
  - Example: "UsersTable" → "users_table"
- Generate unique Terraform resource identifiers: `aws_{service}_{resource_type}.{logical_id_snake_case}`
- Maintain resource reference mapping in local values for intrinsic function resolution
- Handle name collisions by appending numeric suffix if necessary

**Resource Dependency Management:**
- Parse DependsOn field from CloudFormation resources
- Map explicit dependencies to Terraform implicit dependencies via resource references
- Detect implicit dependencies from intrinsic function usage (`!Ref`, `!GetAtt`)
- Build dependency graph to determine resource creation order
- Use `depends_on` meta-argument when implicit dependencies insufficient

**Validation and Error Handling:**
- Validate that resource Type is supported (S3, DynamoDB, SNS, SQS)
- Emit error for unsupported resource types with clear message: "Resource type '{Type}' is not supported. Supported types: AWS::S3::Bucket, AWS::DynamoDB::Table, AWS::SNS::Topic, AWS::SQS::Queue"
- Warn when optional Condition field is present: "CloudFormation Conditions are not fully supported. Resource '{LogicalId}' may not be created conditionally."
- Validate required properties exist for each resource type
- Emit error when property cannot be mapped: "Property '{PropertyName}' on resource '{LogicalId}' cannot be translated. Manual Terraform configuration required."
- Provide clear error messages with resource name and location in serverless.yml

**Empty Resources Handling:**
- Support serverless.yml files without `resources` section (null or missing)
- Support `resources.Resources` that is empty or contains no supported resources
- Generate zero Terraform resources when no CloudFormation resources present
- No errors or warnings for missing resources section

### Module Structure

**File Organization:**
The custom resource logic will be added to the existing module structure:

```
sls.tf/
├── main.tf                    # Add custom resource generation logic
├── locals.tf                  # Add resource parsing and transformation locals
├── outputs.tf                 # Add custom resource outputs
├── versions.tf                # No changes needed
├── variables.tf               # No new variables needed (uses existing outputs)
└── modules/
    └── custom_resources/      # New: Resource-specific translation modules
        ├── s3.tf              # S3 bucket translation logic
        ├── dynamodb.tf        # DynamoDB table translation logic
        ├── sns.tf             # SNS topic translation logic
        ├── sqs.tf             # SQS queue translation logic
        ├── intrinsics.tf      # Intrinsic function resolution logic
        ├── variables.tf       # Module inputs
        ├── outputs.tf         # Module outputs
        └── locals.tf          # Shared transformation logic
```

**locals.tf Responsibilities:**
- Parse `resources.Resources` from core module output
- Filter resources by supported types
- Build resource type categorization maps (s3_buckets, dynamodb_tables, sns_topics, sqs_queues)
- Convert CloudFormation logical IDs to Terraform resource names
- Build resource reference mapping for intrinsic function resolution
- Collect validation errors for unsupported resources

**modules/custom_resources/ Module:**
- Accept parsed CloudFormation resources as input
- Generate Terraform resource blocks for each supported type
- Implement property mapping logic for each service
- Resolve intrinsic functions in property values
- Output resource ARNs, IDs, and attributes for cross-resource references

**outputs.tf Additions:**
- `s3_bucket_ids`: Map of S3 bucket IDs keyed by logical ID
- `s3_bucket_arns`: Map of S3 bucket ARNs keyed by logical ID
- `dynamodb_table_names`: Map of DynamoDB table names keyed by logical ID
- `dynamodb_table_arns`: Map of DynamoDB table ARNs keyed by logical ID
- `sns_topic_arns`: Map of SNS topic ARNs keyed by logical ID
- `sqs_queue_urls`: Map of SQS queue URLs keyed by logical ID
- `sqs_queue_arns`: Map of SQS queue ARNs keyed by logical ID
- `custom_resource_count`: Integer count of custom resources created

## Reusable Components

### Existing Code to Leverage

**From Core Module (Roadmap Item #1):**
- `resources` output: Contains `resources.Resources` CloudFormation definitions
- `service_name` output: For resource tagging and naming
- `provider_config` output: For region and stage information
- YAML parsing framework: Already handles CloudFormation YAML syntax
- Validation error collection pattern: Use `concat()` for error aggregation
- `try()` wrapper pattern: Safe property access for optional fields

**Terraform Built-in Functions:**
- `try()`: Safe access to optional CloudFormation properties
- `lookup()`: Map CloudFormation property names to Terraform arguments
- `for_each`: Iterate over resources to create Terraform resources
- `merge()`: Combine property maps and defaults
- `jsonencode()`: Convert objects to JSON for properties like RedrivePolicy
- `replace()`: Convert PascalCase to snake_case for naming
- `lower()`: Ensure lowercase resource names
- `regex()`: Parse intrinsic function syntax
- `join()`: Implement CloudFormation Join function

**Existing Terraform Patterns:**
- Error collection pattern from locals.tf: Aggregate validation errors before halting
- Resource iteration pattern: Use for_each to create multiple resources
- Conditional resource creation: Use count or for_each based on presence of properties
- Dynamic block pattern: Conditionally include nested blocks based on property existence

### New Components Required

**CloudFormation Parser:**
- Resource type filtering and categorization logic
- Required because: CloudFormation resources must be sorted by type for translation
- Location: `locals.tf` in main module

**Intrinsic Function Resolver:**
- Pattern matching for `!Ref`, `!GetAtt`, `!Sub`, `!Join`, `!If`, `!Equals`
- Substitution engine to replace CloudFormation syntax with Terraform syntax
- Required because: CloudFormation uses different reference syntax than Terraform
- Location: `modules/custom_resources/intrinsics.tf`

**PascalCase to snake_case Converter:**
- String transformation logic for logical ID conversion
- Required because: CloudFormation uses PascalCase, Terraform uses snake_case
- Location: `locals.tf` helper function

**S3 Bucket Decomposition Logic:**
- Split single CloudFormation S3 resource into multiple Terraform resources
- Required because: AWS provider 4.0+ requires separate resources for bucket configuration
- Location: `modules/custom_resources/s3.tf`

**Property Mapping Tables:**
- CloudFormation property to Terraform argument mapping for each service
- Required because: Property names differ between CloudFormation and Terraform
- Location: Each service-specific .tf file in `modules/custom_resources/`

**Tag Format Converter:**
- Convert CloudFormation tag array format to Terraform tag map format
- CloudFormation: `[{Key: "Name", Value: "MyBucket"}]`
- Terraform: `{Name = "MyBucket"}`
- Required because: Tag formats differ between CloudFormation and Terraform
- Location: `modules/custom_resources/locals.tf`

## Technical Approach

### CloudFormation Resource Parsing Strategy

**Resource Extraction Pattern:**
```hcl
locals {
  # Extract resources from core module output
  cf_resources = try(var.parsed_config.resources.Resources, {})

  # Filter by supported types
  supported_types = toset([
    "AWS::S3::Bucket",
    "AWS::DynamoDB::Table",
    "AWS::SNS::Topic",
    "AWS::SQS::Queue"
  ])

  # Categorize resources by type
  s3_buckets = {
    for id, resource in local.cf_resources :
    id => resource
    if try(resource.Type, "") == "AWS::S3::Bucket"
  }

  dynamodb_tables = {
    for id, resource in local.cf_resources :
    id => resource
    if try(resource.Type, "") == "AWS::DynamoDB::Table"
  }

  sns_topics = {
    for id, resource in local.cf_resources :
    id => resource
    if try(resource.Type, "") == "AWS::SNS::Topic"
  }

  sqs_queues = {
    for id, resource in local.cf_resources :
    id => resource
    if try(resource.Type, "") == "AWS::SQS::Queue"
  }

  # Identify unsupported resources
  unsupported_resources = {
    for id, resource in local.cf_resources :
    id => resource
    if !contains(local.supported_types, try(resource.Type, ""))
  }

  # Generate validation errors
  resource_validation_errors = [
    for id, resource in local.unsupported_resources :
    "Resource '${id}' has unsupported type '${resource.Type}'. Supported types: ${join(", ", local.supported_types)}"
  ]
}
```

### Naming Convention Implementation

**PascalCase to snake_case Conversion:**
```hcl
locals {
  # Convert CloudFormation logical ID to Terraform resource name
  resource_name_map = {
    for id in keys(local.cf_resources) :
    id => lower(replace(
      replace(id, "/([a-z])([A-Z])/", "$1_$2"),  # Insert underscore before caps
      "/([A-Z]+)([A-Z][a-z])/", "$1_$2"          # Handle acronyms
    ))
  }

  # Examples:
  # "MyDataBucket" → "my_data_bucket"
  # "UsersTable" → "users_table"
  # "DLQQueue" → "dlq_queue"
  # "APITopic" → "api_topic"
}
```

### S3 Bucket Translation Pattern

**Bucket Decomposition:**
```hcl
# Base bucket resource
resource "aws_s3_bucket" "buckets" {
  for_each = local.s3_buckets

  bucket = try(each.value.Properties.BucketName, null)

  tags = local.convert_cf_tags(try(each.value.Properties.Tags, []))
}

# Bucket ACL (if AccessControl specified)
resource "aws_s3_bucket_acl" "bucket_acls" {
  for_each = {
    for id, bucket in local.s3_buckets :
    id => bucket
    if try(bucket.Properties.AccessControl, null) != null
  }

  bucket = aws_s3_bucket.buckets[each.key].id
  acl    = lower(each.value.Properties.AccessControl)  # "PublicRead" → "public-read"
}

# Bucket versioning (if VersioningConfiguration specified)
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  for_each = {
    for id, bucket in local.s3_buckets :
    id => bucket
    if try(bucket.Properties.VersioningConfiguration, null) != null
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  versioning_configuration {
    status = try(each.value.Properties.VersioningConfiguration.Status, "Disabled")
  }
}

# Server-side encryption (if specified)
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  for_each = {
    for id, bucket in local.s3_buckets :
    id => bucket
    if try(bucket.Properties.BucketEncryption, null) != null
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  dynamic "rule" {
    for_each = try(each.value.Properties.BucketEncryption.ServerSideEncryptionConfiguration, [])
    content {
      apply_server_side_encryption_by_default {
        sse_algorithm     = try(rule.value.ServerSideEncryptionByDefault.SSEAlgorithm, "AES256")
        kms_master_key_id = try(rule.value.ServerSideEncryptionByDefault.KMSMasterKeyID, null)
      }
    }
  }
}

# Public access block (if specified)
resource "aws_s3_bucket_public_access_block" "bucket_public_access" {
  for_each = {
    for id, bucket in local.s3_buckets :
    id => bucket
    if try(bucket.Properties.PublicAccessBlockConfiguration, null) != null
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  block_public_acls       = try(each.value.Properties.PublicAccessBlockConfiguration.BlockPublicAcls, false)
  block_public_policy     = try(each.value.Properties.PublicAccessBlockConfiguration.BlockPublicPolicy, false)
  ignore_public_acls      = try(each.value.Properties.PublicAccessBlockConfiguration.IgnorePublicAcls, false)
  restrict_public_buckets = try(each.value.Properties.PublicAccessBlockConfiguration.RestrictPublicBuckets, false)
}

# Lifecycle configuration (if specified)
resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  for_each = {
    for id, bucket in local.s3_buckets :
    id => bucket
    if try(bucket.Properties.LifecycleConfiguration, null) != null
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  dynamic "rule" {
    for_each = try(each.value.Properties.LifecycleConfiguration.Rules, [])
    content {
      id     = try(rule.value.Id, "rule-${rule.key}")
      status = try(rule.value.Status, "Enabled")

      dynamic "expiration" {
        for_each = try(rule.value.ExpirationInDays, null) != null ? [1] : []
        content {
          days = rule.value.ExpirationInDays
        }
      }

      dynamic "transition" {
        for_each = try(rule.value.Transitions, [])
        content {
          days          = try(transition.value.TransitionInDays, null)
          storage_class = transition.value.StorageClass
        }
      }
    }
  }
}

# CORS configuration (if specified)
resource "aws_s3_bucket_cors_configuration" "bucket_cors" {
  for_each = {
    for id, bucket in local.s3_buckets :
    id => bucket
    if try(bucket.Properties.CorsConfiguration, null) != null
  }

  bucket = aws_s3_bucket.buckets[each.key].id

  dynamic "cors_rule" {
    for_each = try(each.value.Properties.CorsConfiguration.CorsRules, [])
    content {
      allowed_headers = try(cors_rule.value.AllowedHeaders, [])
      allowed_methods = cors_rule.value.AllowedMethods
      allowed_origins = cors_rule.value.AllowedOrigins
      expose_headers  = try(cors_rule.value.ExposedHeaders, [])
      max_age_seconds = try(cors_rule.value.MaxAge, null)
    }
  }
}
```

### DynamoDB Table Translation Pattern

**Table Resource with Indexes:**
```hcl
resource "aws_dynamodb_table" "tables" {
  for_each = local.dynamodb_tables

  name         = try(each.value.Properties.TableName, "${var.service_name}-${each.key}")
  billing_mode = try(each.value.Properties.BillingMode, "PROVISIONED")

  # Hash key (required)
  hash_key = [
    for key in try(each.value.Properties.KeySchema, []) :
    key.AttributeName if key.KeyType == "HASH"
  ][0]

  # Range key (optional)
  range_key = try([
    for key in try(each.value.Properties.KeySchema, []) :
    key.AttributeName if key.KeyType == "RANGE"
  ][0], null)

  # Attributes
  dynamic "attribute" {
    for_each = try(each.value.Properties.AttributeDefinitions, [])
    content {
      name = attribute.value.AttributeName
      type = attribute.value.AttributeType
    }
  }

  # Provisioned throughput (only if billing mode is PROVISIONED)
  read_capacity  = try(each.value.Properties.BillingMode, "PROVISIONED") == "PROVISIONED" ? try(each.value.Properties.ProvisionedThroughput.ReadCapacityUnits, 5) : null
  write_capacity = try(each.value.Properties.BillingMode, "PROVISIONED") == "PROVISIONED" ? try(each.value.Properties.ProvisionedThroughput.WriteCapacityUnits, 5) : null

  # Global secondary indexes
  dynamic "global_secondary_index" {
    for_each = try(each.value.Properties.GlobalSecondaryIndexes, [])
    content {
      name            = global_secondary_index.value.IndexName
      hash_key        = [for k in global_secondary_index.value.KeySchema : k.AttributeName if k.KeyType == "HASH"][0]
      range_key       = try([for k in global_secondary_index.value.KeySchema : k.AttributeName if k.KeyType == "RANGE"][0], null)
      projection_type = global_secondary_index.value.Projection.ProjectionType
      non_key_attributes = try(global_secondary_index.value.Projection.NonKeyAttributes, null)
      read_capacity   = try(global_secondary_index.value.ProvisionedThroughput.ReadCapacityUnits, null)
      write_capacity  = try(global_secondary_index.value.ProvisionedThroughput.WriteCapacityUnits, null)
    }
  }

  # Local secondary indexes
  dynamic "local_secondary_index" {
    for_each = try(each.value.Properties.LocalSecondaryIndexes, [])
    content {
      name            = local_secondary_index.value.IndexName
      range_key       = [for k in local_secondary_index.value.KeySchema : k.AttributeName if k.KeyType == "RANGE"][0]
      projection_type = local_secondary_index.value.Projection.ProjectionType
      non_key_attributes = try(local_secondary_index.value.Projection.NonKeyAttributes, null)
    }
  }

  # Streams
  stream_enabled   = try(each.value.Properties.StreamSpecification.StreamEnabled, false)
  stream_view_type = try(each.value.Properties.StreamSpecification.StreamViewType, null)

  # Server-side encryption
  dynamic "server_side_encryption" {
    for_each = try(each.value.Properties.SSESpecification, null) != null ? [1] : []
    content {
      enabled     = try(each.value.Properties.SSESpecification.SSEEnabled, false)
      kms_key_arn = try(each.value.Properties.SSESpecification.KMSMasterKeyId, null)
    }
  }

  # TTL
  dynamic "ttl" {
    for_each = try(each.value.Properties.TimeToLiveSpecification, null) != null ? [1] : []
    content {
      enabled        = try(each.value.Properties.TimeToLiveSpecification.Enabled, false)
      attribute_name = try(each.value.Properties.TimeToLiveSpecification.AttributeName, "")
    }
  }

  # Tags
  tags = local.convert_cf_tags(try(each.value.Properties.Tags, []))
}
```

### SNS Topic Translation Pattern

**Topic with Subscriptions:**
```hcl
resource "aws_sns_topic" "topics" {
  for_each = local.sns_topics

  name              = try(each.value.Properties.TopicName, null)
  display_name      = try(each.value.Properties.DisplayName, null)
  kms_master_key_id = try(each.value.Properties.KmsMasterKeyId, null)

  tags = local.convert_cf_tags(try(each.value.Properties.Tags, []))
}

# SNS subscriptions (embedded in topic definition)
resource "aws_sns_topic_subscription" "topic_subscriptions" {
  for_each = merge([
    for topic_id, topic in local.sns_topics : {
      for idx, sub in try(topic.Properties.Subscription, []) :
      "${topic_id}-${idx}" => {
        topic_arn = aws_sns_topic.topics[topic_id].arn
        protocol  = sub.Protocol
        endpoint  = sub.Endpoint
      }
    }
  ]...)

  topic_arn = each.value.topic_arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}
```

### SQS Queue Translation Pattern

**Queue with Dead Letter Queue:**
```hcl
resource "aws_sqs_queue" "queues" {
  for_each = local.sqs_queues

  name                       = try(each.value.Properties.QueueName, null)
  fifo_queue                 = try(each.value.Properties.FifoQueue, false)
  content_based_deduplication = try(each.value.Properties.ContentBasedDeduplication, false)
  delay_seconds              = try(each.value.Properties.DelaySeconds, 0)
  max_message_size           = try(each.value.Properties.MaximumMessageSize, 262144)
  message_retention_seconds  = try(each.value.Properties.MessageRetentionPeriod, 345600)
  receive_wait_time_seconds  = try(each.value.Properties.ReceiveMessageWaitTimeSeconds, 0)
  visibility_timeout_seconds = try(each.value.Properties.VisibilityTimeout, 30)
  kms_master_key_id          = try(each.value.Properties.KmsMasterKeyId, null)

  # Redrive policy (DLQ configuration)
  redrive_policy = try(each.value.Properties.RedrivePolicy, null) != null ? jsonencode({
    deadLetterTargetArn = local.resolve_ref(each.value.Properties.RedrivePolicy.deadLetterTargetArn)
    maxReceiveCount     = each.value.Properties.RedrivePolicy.maxReceiveCount
  }) : null

  tags = local.convert_cf_tags(try(each.value.Properties.Tags, []))
}
```

### Intrinsic Function Resolution

**Function Resolution Logic:**
```hcl
locals {
  # Build resource reference map
  resource_refs = merge(
    { for id in keys(local.s3_buckets) : id => "aws_s3_bucket.${local.resource_name_map[id]}.id" },
    { for id in keys(local.dynamodb_tables) : id => "aws_dynamodb_table.${local.resource_name_map[id]}.name" },
    { for id in keys(local.sns_topics) : id => "aws_sns_topic.${local.resource_name_map[id]}.arn" },
    { for id in keys(local.sqs_queues) : id => "aws_sqs_queue.${local.resource_name_map[id]}.url" }
  )

  # Resolve !Ref intrinsic function
  resolve_ref = function(ref) {
    # Handle string format: "!Ref LogicalId" or {"Ref": "LogicalId"}
    logical_id = is_string(ref) ? trimprefix(ref, "!Ref ") : try(ref.Ref, ref)

    # Look up in resource map
    return lookup(local.resource_refs, logical_id, "var.${lower(logical_id)}")
  }

  # Resolve !GetAtt intrinsic function
  resolve_getatt = function(getatt) {
    # Handle formats: "!GetAtt LogicalId.Attribute" or {"Fn::GetAtt": ["LogicalId", "Attribute"]}
    parts = is_string(getatt) ? split(".", trimprefix(getatt, "!GetAtt ")) : try(getatt["Fn::GetAtt"], [])
    logical_id = parts[0]
    attribute = parts[1]

    # Map CloudFormation attributes to Terraform attributes
    attribute_map = {
      "Arn" = "arn",
      "StreamArn" = "stream_arn",
      "DomainName" = "bucket_domain_name",
      "RegionalDomainName" = "bucket_regional_domain_name",
      # ... additional mappings
    }

    tf_attribute = lookup(attribute_map, attribute, lower(attribute))
    resource_type = local.get_resource_type(logical_id)

    return "${resource_type}.${local.resource_name_map[logical_id]}.${tf_attribute}"
  }

  # Resolve !Sub intrinsic function
  resolve_sub = function(sub) {
    # Handle format: "!Sub 'template string'" or {"Fn::Sub": "template string"}
    template = is_string(sub) ? trimprefix(sub, "!Sub ") : try(sub["Fn::Sub"], "")

    # Replace ${LogicalId} with Terraform reference syntax
    # Replace ${LogicalId.Attribute} with Terraform attribute reference
    return regex_replace_all(template, "\\$\\{([^.}]+)(?:\\.([^}]+))?\\}", function(match) {
      logical_id = match[1]
      attribute = try(match[2], null)

      if attribute != null {
        return "$${${local.resolve_getatt({"Fn::GetAtt": [logical_id, attribute]})}}"
      } else {
        return "$${${local.resolve_ref(logical_id)}}"
      }
    })
  }

  # Resolve !Join intrinsic function
  resolve_join = function(join_expr) {
    # Format: {"Fn::Join": [delimiter, [list, of, values]]}
    delimiter = join_expr["Fn::Join"][0]
    values = join_expr["Fn::Join"][1]

    # Resolve each value in the list
    resolved_values = [for v in values : is_string(v) ? v : local.resolve_intrinsic(v)]

    return "join(\"${delimiter}\", [${join(", ", [for v in resolved_values : "\"${v}\""])}])"
  }

  # Resolve !If intrinsic function
  resolve_if = function(if_expr) {
    # Format: {"Fn::If": [condition_name, true_value, false_value]}
    # Note: Conditions not fully supported, convert to basic ternary
    condition = if_expr["Fn::If"][0]
    true_val = if_expr["Fn::If"][1]
    false_val = if_expr["Fn::If"][2]

    # Convert to Terraform conditional
    return "var.${lower(condition)} ? ${jsonencode(true_val)} : ${jsonencode(false_val)}"
  }

  # Main intrinsic function resolver
  resolve_intrinsic = function(value) {
    if is_string(value) {
      if startswith(value, "!Ref ") {
        return local.resolve_ref(value)
      } else if startswith(value, "!GetAtt ") {
        return local.resolve_getatt(value)
      } else if startswith(value, "!Sub ") {
        return local.resolve_sub(value)
      } else {
        return value
      }
    } else if is_map(value) {
      if contains(keys(value), "Ref") {
        return local.resolve_ref(value)
      } else if contains(keys(value), "Fn::GetAtt") {
        return local.resolve_getatt(value)
      } else if contains(keys(value), "Fn::Sub") {
        return local.resolve_sub(value)
      } else if contains(keys(value), "Fn::Join") {
        return local.resolve_join(value)
      } else if contains(keys(value), "Fn::If") {
        return local.resolve_if(value)
      } else {
        return value
      }
    } else {
      return value
    }
  }
}
```

### Tag Format Conversion

**CloudFormation to Terraform Tag Conversion:**
```hcl
locals {
  # Convert CloudFormation tag array to Terraform tag map
  convert_cf_tags = function(cf_tags) {
    return {
      for tag in cf_tags :
      tag.Key => tag.Value
    }
  }

  # Example:
  # Input:  [{Key: "Environment", Value: "prod"}, {Key: "Owner", Value: "team"}]
  # Output: {Environment = "prod", Owner = "team"}
}
```

## Out of Scope

### Excluded from This Feature

**Unsupported Resource Types:**
- All CloudFormation resources except S3, DynamoDB, SNS, SQS
- AWS::Lambda::Function (covered by roadmap item #2)
- AWS::ApiGateway::* (covered by roadmap item #3)
- AWS::Events::Rule (covered by roadmap item #7)
- AWS::IAM::Role (covered by roadmap item #3)
- AWS::CloudFormation::CustomResource
- AWS::CloudFormation::Stack (nested stacks)
- Custom resources with Lambda backends

**Advanced CloudFormation Features:**
- CloudFormation Conditions (Conditions section)
  - Partial support only: warn when Condition field present on resources
  - Full conditional resource creation requires Terraform count or for_each logic
- CloudFormation Parameters (Parameters section)
  - Use Terraform variables instead
- CloudFormation Mappings (Mappings section)
  - Use Terraform locals or variables
- CloudFormation Outputs (Outputs section)
  - Use Terraform outputs directly
- CloudFormation Metadata (Metadata field)
  - Not applicable to Terraform
- CloudFormation DependsOn with complex DAGs
  - Simple DependsOn supported, complex dependency graphs may require manual adjustment

**Intrinsic Functions Not Supported:**
- `Fn::FindInMap` (use Terraform lookup or locals)
- `Fn::GetAZs` (use Terraform data source aws_availability_zones)
- `Fn::ImportValue` (cross-stack references, use Terraform data sources)
- `Fn::Select` (use Terraform element or index)
- `Fn::Split` (use Terraform split function)
- `Fn::Transform` (CloudFormation macros not supported)
- `Fn::Cidr` (use Terraform cidrsubnet)
- `Fn::Base64` (use Terraform base64encode)

**S3 Advanced Features:**
- Bucket policies inline in BucketPolicy property (create separate aws_s3_bucket_policy resource)
- Replication configuration
- Analytics configuration
- Inventory configuration
- Intelligent tiering configuration
- Object Lock configuration
- Accelerate configuration
- Request payment configuration

**DynamoDB Advanced Features:**
- Point-in-time recovery configuration
- Contributor insights configuration
- Kinesis streaming destination
- Global tables (multi-region replication)
- Table class configuration
- Deletion protection

**SNS Advanced Features:**
- Topic policies (create separate aws_sns_topic_policy resource)
- Subscription filter policies
- Subscription delivery policies
- Subscription redrive policies
- FIFO topics (AWS recently added, may not be in CloudFormation templates)

**SQS Advanced Features:**
- Queue policies (create separate aws_sqs_queue_policy resource)
- Redrive allow policy
- Deduplication scope (for FIFO queues)
- FIFO throughput limit

**Variable Resolution:**
- Full Serverless Framework variable syntax (`${self:...}`, `${env:...}`, etc.)
- Deferred to roadmap item #10
- Basic support: emit variable references as Terraform variables

**Cross-Service Resource References:**
- S3 event notifications to Lambda (roadmap item #5)
- S3 event notifications to SQS (roadmap item #5)
- DynamoDB streams to Lambda (roadmap item #8)
- EventBridge rules (roadmap item #7)

## Success Criteria

**Resource Parsing Success:**
- Module successfully parses `resources.Resources` from core module output
- CloudFormation resources categorized by type (S3, DynamoDB, SNS, SQS)
- Unsupported resource types identified and validation errors generated
- Empty or missing resources section handled gracefully (zero resources created)

**S3 Bucket Translation Success:**
- `AWS::S3::Bucket` generates `aws_s3_bucket` base resource
- Bucket name mapped from BucketName property (optional)
- AccessControl generates `aws_s3_bucket_acl` resource
- Versioning generates `aws_s3_bucket_versioning` resource
- Encryption generates `aws_s3_bucket_server_side_encryption_configuration` resource
- Lifecycle rules generate `aws_s3_bucket_lifecycle_configuration` resource
- CORS rules generate `aws_s3_bucket_cors_configuration` resource
- Public access block generates `aws_s3_bucket_public_access_block` resource
- Tags converted from CloudFormation array to Terraform map format

**DynamoDB Table Translation Success:**
- `AWS::DynamoDB::Table` generates `aws_dynamodb_table` resource
- Table name mapped from TableName property
- Hash key and range key correctly mapped from KeySchema
- Attributes mapped from AttributeDefinitions
- Billing mode mapped (PROVISIONED or PAY_PER_REQUEST)
- Provisioned throughput mapped when billing mode is PROVISIONED
- Global secondary indexes created with all properties
- Local secondary indexes created with all properties
- Stream configuration mapped (enabled, view type)
- Server-side encryption mapped
- TTL configuration mapped
- Tags converted to Terraform format

**SNS Topic Translation Success:**
- `AWS::SNS::Topic` generates `aws_sns_topic` resource
- Topic name mapped (optional, AWS generates if not specified)
- Display name and KMS key ID mapped
- Subscriptions generate separate `aws_sns_topic_subscription` resources
- Subscription protocol and endpoint mapped correctly
- Tags converted to Terraform format

**SQS Queue Translation Success:**
- `AWS::SQS::Queue` generates `aws_sqs_queue` resource
- Queue name mapped (optional)
- FIFO queue boolean mapped
- Content-based deduplication mapped
- All timeout and size properties mapped
- Redrive policy (DLQ) converted to JSON format
- KMS encryption key mapped
- Tags converted to Terraform format

**Intrinsic Function Resolution Success:**
- `!Ref` and `Fn::Ref` resolve to Terraform resource references
- `!GetAtt` and `Fn::GetAtt` resolve to Terraform attribute references
- `!Sub` and `Fn::Sub` resolve to Terraform string interpolation
- `!Join` and `Fn::Join` resolve to Terraform join() function
- `!If` and `Fn::If` resolve to Terraform conditional expressions
- `!Equals` and `Fn::Equals` resolve to Terraform equality operators
- Serverless variable syntax emitted as Terraform variable references

**Resource Naming Success:**
- CloudFormation logical IDs converted to snake_case Terraform names
- PascalCase conversion handles acronyms correctly (e.g., "DLQQueue" → "dlq_queue")
- Resource names unique and collision-free
- Terraform resource identifiers follow convention: `aws_{service}_{type}.{logical_id}`

**Resource Dependency Success:**
- DependsOn field parsed and mapped to Terraform dependencies
- Implicit dependencies detected from `!Ref` and `!GetAtt` usage
- Resource creation order correct based on dependency graph
- Terraform `depends_on` meta-argument used when needed

**Validation and Error Handling Success:**
- Unsupported resource types generate clear error messages
- Missing required properties generate validation errors
- CloudFormation Conditions generate warnings (not errors)
- Error messages include resource logical ID and property name
- All validation errors collected before halting execution

**Output Interface Success:**
- S3 bucket IDs and ARNs output as maps keyed by logical ID
- DynamoDB table names and ARNs output as maps
- SNS topic ARNs output as map
- SQS queue URLs and ARNs output as maps
- Custom resource count output for verification
- Empty maps when no resources of type created

**Integration Success:**
- Module consumes `resources` output from roadmap item #1
- Generated Terraform resources valid for terraform plan
- terraform apply creates actual AWS resources matching CloudFormation definitions
- Resources deletable via terraform destroy
- No conflicts with Lambda resources from roadmap item #2

## Testing Requirements

While test implementation is out of scope for this specification, the following test scenarios must be covered:

**S3 Bucket Tests:**
- Translate simple S3 bucket with BucketName only
- Translate S3 bucket with versioning enabled
- Translate S3 bucket with encryption configuration
- Translate S3 bucket with lifecycle rules (expiration, transitions)
- Translate S3 bucket with CORS configuration
- Translate S3 bucket with public access block
- Translate S3 bucket with multiple configuration resources
- Verify tag conversion from array to map

**DynamoDB Table Tests:**
- Translate table with hash key only
- Translate table with hash key and range key
- Translate table with global secondary index
- Translate table with local secondary index
- Translate table with multiple GSIs and LSIs
- Translate table with streams enabled
- Translate table with server-side encryption
- Translate table with TTL configuration
- Translate table with PAY_PER_REQUEST billing mode
- Translate table with PROVISIONED billing mode and throughput
- Verify attribute definitions mapped correctly

**SNS Topic Tests:**
- Translate simple SNS topic with name only
- Translate SNS topic with display name and KMS key
- Translate SNS topic with email subscriptions
- Translate SNS topic with SQS subscriptions
- Translate SNS topic with multiple subscriptions
- Verify subscription resources created separately

**SQS Queue Tests:**
- Translate simple SQS queue
- Translate FIFO queue with content-based deduplication
- Translate queue with custom timeout and retention settings
- Translate queue with dead letter queue configuration
- Translate queue with KMS encryption
- Verify redrive policy JSON format

**Intrinsic Function Tests:**
- Resolve !Ref to S3 bucket
- Resolve !Ref to DynamoDB table
- Resolve !GetAtt for S3 bucket ARN
- Resolve !GetAtt for DynamoDB stream ARN
- Resolve !Sub with single variable
- Resolve !Sub with multiple variables
- Resolve !Join with array of strings
- Resolve !If with condition
- Resolve nested intrinsic functions (e.g., !Sub with !Ref inside)

**Naming Convention Tests:**
- Convert PascalCase to snake_case for various patterns
- Handle acronyms in logical IDs (API, DLQ, etc.)
- Ensure no name collisions
- Verify Terraform resource naming convention followed

**Validation Tests:**
- Reject unsupported resource type (e.g., AWS::EC2::Instance)
- Warn on CloudFormation Condition usage
- Handle empty resources section (no errors)
- Handle missing resources section (no errors)
- Collect multiple validation errors together

**Dependency Tests:**
- Detect dependency from !Ref usage
- Detect dependency from !GetAtt usage
- Handle explicit DependsOn field
- Verify resource creation order correct

**Integration Tests:**
- Translate multi-resource configuration with cross-references
- Verify integration with Lambda resources (roadmap item #2)
- Test complete serverless.yml with functions and resources sections
- Verify terraform plan succeeds
- Verify terraform apply creates all resources
- Verify terraform destroy removes all resources

**Tag Conversion Tests:**
- Convert single tag from CloudFormation to Terraform
- Convert multiple tags
- Handle empty tags array
- Verify tag map format correct

## Example Translations

### Example 1: S3 Bucket with Versioning

**Input (serverless.yml):**
```yaml
resources:
  Resources:
    DataBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: my-data-bucket
        VersioningConfiguration:
          Status: Enabled
        Tags:
          - Key: Environment
            Value: production
          - Key: ManagedBy
            Value: Terraform
```

**Expected Terraform Output:**
```hcl
resource "aws_s3_bucket" "data_bucket" {
  bucket = "my-data-bucket"

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "data_bucket_versioning" {
  bucket = aws_s3_bucket.data_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

### Example 2: DynamoDB Table with GSI

**Input (serverless.yml):**
```yaml
resources:
  Resources:
    UsersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: users-table
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: userId
            AttributeType: S
          - AttributeName: email
            AttributeType: S
        KeySchema:
          - AttributeName: userId
            KeyType: HASH
        GlobalSecondaryIndexes:
          - IndexName: EmailIndex
            KeySchema:
              - AttributeName: email
                KeyType: HASH
            Projection:
              ProjectionType: ALL
        StreamSpecification:
          StreamEnabled: true
          StreamViewType: NEW_AND_OLD_IMAGES
```

**Expected Terraform Output:**
```hcl
resource "aws_dynamodb_table" "users_table" {
  name         = "users-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}
```

### Example 3: SQS Queue with DLQ

**Input (serverless.yml):**
```yaml
resources:
  Resources:
    MainQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: main-queue
        VisibilityTimeout: 300
        RedrivePolicy:
          deadLetterTargetArn: !GetAtt DeadLetterQueue.Arn
          maxReceiveCount: 3

    DeadLetterQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: dead-letter-queue
        MessageRetentionPeriod: 1209600  # 14 days
```

**Expected Terraform Output:**
```hcl
resource "aws_sqs_queue" "dead_letter_queue" {
  name                      = "dead-letter-queue"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "main_queue" {
  name                       = "main-queue"
  visibility_timeout_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = 3
  })

  depends_on = [aws_sqs_queue.dead_letter_queue]
}
```

### Example 4: SNS Topic with Subscription

**Input (serverless.yml):**
```yaml
resources:
  Resources:
    NotificationTopic:
      Type: AWS::SNS::Topic
      Properties:
        TopicName: notifications
        DisplayName: Application Notifications
        Subscription:
          - Protocol: email
            Endpoint: admin@example.com
          - Protocol: sqs
            Endpoint: !GetAtt AlertQueue.Arn

    AlertQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: alert-queue
```

**Expected Terraform Output:**
```hcl
resource "aws_sqs_queue" "alert_queue" {
  name = "alert-queue"
}

resource "aws_sns_topic" "notification_topic" {
  name         = "notifications"
  display_name = "Application Notifications"
}

resource "aws_sns_topic_subscription" "notification_topic_0" {
  topic_arn = aws_sns_topic.notification_topic.arn
  protocol  = "email"
  endpoint  = "admin@example.com"
}

resource "aws_sns_topic_subscription" "notification_topic_1" {
  topic_arn = aws_sns_topic.notification_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.alert_queue.arn
}
```

### Example 5: Intrinsic Functions

**Input (serverless.yml):**
```yaml
resources:
  Resources:
    ConfigBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: !Sub "${AWS::StackName}-config"

    ProcessQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: !Join ["-", ["process", !Ref Stage]]

    DataTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: data-table
        # ... other properties
```

**Expected Terraform Output:**
```hcl
resource "aws_s3_bucket" "config_bucket" {
  bucket = "${var.stack_name}-config"
}

resource "aws_sqs_queue" "process_queue" {
  name = join("-", ["process", var.stage])
}

resource "aws_dynamodb_table" "data_table" {
  name = "data-table"
  # ... other properties
}
```

## Non-Functional Requirements

**Maintainability:**
- Clear separation between resource type parsers (s3.tf, dynamodb.tf, etc.)
- Descriptive function names for intrinsic function resolvers
- Property mapping logic documented with CloudFormation → Terraform comments
- Complex transformations isolated in helper functions

**Extensibility:**
- Module structure supports adding new resource types (Lambda, API Gateway, etc.)
- Intrinsic function resolver extensible for new function types
- Property mapping tables easy to update for new CloudFormation properties
- Tag conversion logic reusable across all resource types

**Performance:**
- Resource parsing completes during Terraform plan phase
- for_each iteration efficient for large resource counts
- Intrinsic function resolution cached in locals (avoid recomputation)
- No unnecessary resource recreation on plan/apply

**Security:**
- No secrets or sensitive data in resource configurations
- Encryption properties preserved from CloudFormation definitions
- Public access block configurations honored for S3 buckets
- KMS key references preserved for encryption at rest

**Compatibility:**
- Works with existing core module from roadmap item #1
- Compatible with Lambda resources from roadmap item #2
- Follows Terraform AWS provider best practices
- CloudFormation compatibility for supported resource types and properties

**Documentation:**
- Clear comments for each property mapping
- Examples for each supported resource type
- Intrinsic function resolution logic documented
- Naming convention transformation explained

## Dependencies and Assumptions

**Dependencies:**
- Roadmap item #1 (Core Module Structure & YAML Parsing) must be complete
- `resources` output must contain CloudFormation resources structure
- Terraform 1.0.0+ installed
- AWS provider 6.0+ configured
- AWS credentials configured for resource creation

**Assumptions:**
- CloudFormation resources in serverless.yml use valid syntax
- Resource Type field present for all resources
- Only S3, DynamoDB, SNS, SQS resources need translation initially
- Intrinsic functions use standard CloudFormation syntax
- Logical IDs are unique within resources section
- Tag format follows CloudFormation convention (array of Key/Value objects)
- No custom resource types with Lambda backends
- CloudFormation Conditions can be warned about (not fully supported)
- Variable resolution (roadmap item #10) will enhance intrinsic function support

**Future Considerations:**
- Additional resource types will follow same translation pattern
- Lambda layers may require S3 bucket references (roadmap item dependencies)
- Event source mappings will reference DynamoDB and SQS resources (roadmap #8)
- API Gateway will need to reference resources for data sources (roadmap #3)
- Full variable resolution will enhance ${self:...} syntax support (roadmap #10)

## Implementation Notes

**Development Order:**
1. Add resource parsing logic to locals.tf (extract, categorize, validate)
2. Implement PascalCase to snake_case naming conversion
3. Create modules/custom_resources/ directory structure
4. Implement S3 bucket translation in s3.tf
5. Implement DynamoDB table translation in dynamodb.tf
6. Implement SNS topic translation in sns.tf
7. Implement SQS queue translation in sqs.tf
8. Implement intrinsic function resolver in intrinsics.tf
9. Implement tag format converter
10. Add custom resource outputs to outputs.tf
11. Test with examples for each resource type
12. Test intrinsic function resolution
13. Test multi-resource configurations with cross-references

**Key Implementation Challenges:**
- S3 bucket decomposition into multiple Terraform resources (AWS provider 4.0+ requirement)
- Intrinsic function pattern matching and substitution (complex regex and string manipulation)
- DynamoDB index creation with correct attribute references
- Dependency detection and ordering for resource creation
- Tag array to map conversion (different data structures)
- Handling optional properties that may or may not exist

**Code Quality Guidelines:**
- Run `terraform fmt` on all .tf files
- Use descriptive variable names for property mappings
- Add comments explaining CloudFormation → Terraform property mappings
- Keep resource blocks organized by service type
- Follow Terraform naming conventions (snake_case)
- Document intrinsic function resolution logic thoroughly

**Testing Approach:**
- Create test fixtures for each resource type in tests/fixtures/
- Test simple resource definitions first
- Test complex resources with all properties
- Test intrinsic function resolution with various patterns
- Test multi-resource configurations with dependencies
- Verify terraform plan output matches expectations
- Test actual resource creation with terraform apply
- Verify resources match CloudFormation behavior

**Integration Points:**
- Consume `module.serverless_parser.resources` (from roadmap item #1)
- Coordinate with Lambda resources (roadmap item #2) for permissions
- Output resource ARNs for event source integrations (roadmap #4, #5, #7, #8)
- Support future API Gateway integrations (roadmap #3)

---

**This specification is ready for implementation.** Developers should reference the core module implementation in `/home/tom/p/t/sls.tf/` for integration patterns, the Lambda translation specification for resource generation patterns, and the requirements document at `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-custom-resource-provisioning/planning/requirements.md` for detailed property mappings.
