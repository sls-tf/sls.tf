# ============================================================================
# Custom Resource Provisioning (Roadmap #9)
# CloudFormation-style resources from serverless.yml resources section
# ============================================================================

# ============================================================================
# S3 Buckets
# ============================================================================

# Base S3 bucket resource
# Maps from CloudFormation AWS::S3::Bucket to aws_s3_bucket
resource "aws_s3_bucket" "custom" {
  for_each = local.s3_buckets

  # Use BucketName property if specified, otherwise generate name
  bucket = try(each.value.Properties.BucketName, "${local.to_snake_case[each.key]}-${local.provider_with_defaults.stage}")

  # Force destroy for easier cleanup (can be made configurable)
  force_destroy = true

  tags = merge(
    {
      Name        = each.key
      ManagedBy   = "sls.tf"
      LogicalId   = each.key
      Environment = local.provider_with_defaults.stage
    },
    # Convert CloudFormation tag format to Terraform map
    try({
      for tag in each.value.Properties.Tags :
      tag.Key => tag.Value
    }, {})
  )
}

# S3 bucket versioning configuration
# Created when VersioningConfiguration exists in properties
resource "aws_s3_bucket_versioning" "custom" {
  for_each = {
    for logical_id, resource in local.s3_buckets :
    logical_id => resource
    if try(resource.Properties.VersioningConfiguration, null) != null
  }

  bucket = aws_s3_bucket.custom[each.key].id

  versioning_configuration {
    status = try(each.value.Properties.VersioningConfiguration.Status, "Disabled")
  }
}

# S3 bucket ACL configuration
# Created when AccessControl property exists
resource "aws_s3_bucket_acl" "custom" {
  for_each = {
    for logical_id, resource in local.s3_buckets :
    logical_id => resource
    if try(resource.Properties.AccessControl, null) != null
  }

  bucket = aws_s3_bucket.custom[each.key].id
  acl    = lower(each.value.Properties.AccessControl)

  depends_on = [aws_s3_bucket.custom]
}

# ============================================================================
# DynamoDB Tables
# ============================================================================

# DynamoDB Table resource
# Maps from CloudFormation AWS::DynamoDB::Table to aws_dynamodb_table
resource "aws_dynamodb_table" "custom" {
  for_each = local.dynamodb_tables

  # Use TableName property if specified, otherwise generate name
  name = try(
    each.value.Properties.TableName,
    "${local.to_snake_case[each.key]}-${local.provider_with_defaults.stage}"
  )

  # Billing mode - default to PROVISIONED if not specified
  billing_mode = try(each.value.Properties.BillingMode, "PROVISIONED")

  # Hash key (required)
  hash_key = try([
    for key in each.value.Properties.KeySchema :
    key.AttributeName if key.KeyType == "HASH"
  ][0], null)

  # Range key (optional)
  range_key = try([
    for key in each.value.Properties.KeySchema :
    key.AttributeName if key.KeyType == "RANGE"
  ][0], null)

  # Attribute definitions (required)
  dynamic "attribute" {
    for_each = try(each.value.Properties.AttributeDefinitions, [])
    content {
      name = attribute.value.AttributeName
      type = attribute.value.AttributeType
    }
  }

  # Provisioned throughput (required for PROVISIONED billing mode)
  read_capacity  = try(each.value.Properties.BillingMode, "PROVISIONED") == "PROVISIONED" ? try(each.value.Properties.ProvisionedThroughput.ReadCapacityUnits, 5) : null
  write_capacity = try(each.value.Properties.BillingMode, "PROVISIONED") == "PROVISIONED" ? try(each.value.Properties.ProvisionedThroughput.WriteCapacityUnits, 5) : null

  # Global Secondary Indexes
  dynamic "global_secondary_index" {
    for_each = try(each.value.Properties.GlobalSecondaryIndexes, [])
    content {
      name            = global_secondary_index.value.IndexName
      hash_key        = global_secondary_index.value.KeySchema[0].AttributeName
      range_key       = try(global_secondary_index.value.KeySchema[1].AttributeName, null)
      projection_type = global_secondary_index.value.Projection.ProjectionType
      read_capacity   = try(each.value.Properties.BillingMode, "PROVISIONED") == "PROVISIONED" ? try(global_secondary_index.value.ProvisionedThroughput.ReadCapacityUnits, 5) : null
      write_capacity  = try(each.value.Properties.BillingMode, "PROVISIONED") == "PROVISIONED" ? try(global_secondary_index.value.ProvisionedThroughput.WriteCapacityUnits, 5) : null
    }
  }

  # Stream specification
  stream_enabled   = try(each.value.Properties.StreamSpecification.StreamEnabled, false)
  stream_view_type = try(each.value.Properties.StreamSpecification.StreamViewType, null)

  # Tags
  tags = merge(
    {
      Name        = each.key
      ManagedBy   = "sls.tf"
      LogicalId   = each.key
      Environment = local.provider_with_defaults.stage
    },
    # Convert CloudFormation tag format to Terraform map
    try({
      for tag in each.value.Properties.Tags :
      tag.Key => tag.Value
    }, {})
  )
}

# ============================================================================
# SNS Topics
# ============================================================================

# SNS Topic resource
# Maps from CloudFormation AWS::SNS::Topic to aws_sns_topic
resource "aws_sns_topic" "custom" {
  for_each = local.sns_topics

  # Use TopicName property if specified, otherwise generate name
  name = try(
    each.value.Properties.TopicName,
    "${local.to_snake_case[each.key]}-${local.provider_with_defaults.stage}"
  )

  # Display name for SMS messages
  display_name = try(each.value.Properties.DisplayName, null)

  # FIFO topic settings
  fifo_topic                  = try(each.value.Properties.FifoTopic, false)
  content_based_deduplication = try(each.value.Properties.ContentBasedDeduplication, false)

  # KMS encryption
  kms_master_key_id = try(each.value.Properties.KmsMasterKeyId, null)

  # Tags
  tags = merge(
    {
      Name        = each.key
      ManagedBy   = "sls.tf"
      LogicalId   = each.key
      Environment = local.provider_with_defaults.stage
    },
    # Convert CloudFormation tag format to Terraform map
    try({
      for tag in each.value.Properties.Tags :
      tag.Key => tag.Value
    }, {})
  )
}

# ============================================================================
# SQS Queues
# ============================================================================

# SQS Queue resource
# Maps from CloudFormation AWS::SQS::Queue to aws_sqs_queue
resource "aws_sqs_queue" "custom" {
  for_each = local.sqs_queues

  # Use QueueName property if specified, otherwise generate name
  name = try(
    each.value.Properties.QueueName,
    "${local.to_snake_case[each.key]}-${local.provider_with_defaults.stage}"
  )

  # FIFO queue settings
  fifo_queue                  = try(each.value.Properties.FifoQueue, false)
  content_based_deduplication = try(each.value.Properties.ContentBasedDeduplication, false)

  # Message retention and delays
  message_retention_seconds = try(each.value.Properties.MessageRetentionPeriod, 345600)  # 4 days default
  delay_seconds             = try(each.value.Properties.DelaySeconds, 0)
  visibility_timeout_seconds = try(each.value.Properties.VisibilityTimeout, 30)

  # Delivery policy
  receive_wait_time_seconds = try(each.value.Properties.ReceiveMessageWaitTimeSeconds, 0)
  max_message_size          = try(each.value.Properties.MaximumMessageSize, 262144)  # 256 KB default

  # Dead letter queue configuration
  redrive_policy = try(each.value.Properties.RedrivePolicy, null) != null ? jsonencode({
    deadLetterTargetArn = try(each.value.Properties.RedrivePolicy.deadLetterTargetArn, null)
    maxReceiveCount     = try(each.value.Properties.RedrivePolicy.maxReceiveCount, 5)
  }) : null

  # KMS encryption
  kms_master_key_id                 = try(each.value.Properties.KmsMasterKeyId, null)
  kms_data_key_reuse_period_seconds = try(each.value.Properties.KmsDataKeyReusePeriodSeconds, 300)

  # Tags
  tags = merge(
    {
      Name        = each.key
      ManagedBy   = "sls.tf"
      LogicalId   = each.key
      Environment = local.provider_with_defaults.stage
    },
    # Convert CloudFormation tag format to Terraform map
    try({
      for tag in each.value.Properties.Tags :
      tag.Key => tag.Value
    }, {})
  )
}
