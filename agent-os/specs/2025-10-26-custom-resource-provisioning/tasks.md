# Task Breakdown: Custom Resource Provisioning

## Overview
Total Estimated Tasks: 70+ (grouped into 9 strategic task groups)

This task breakdown translates CloudFormation-style resource definitions from Serverless Framework's `resources` section to native Terraform resources. The implementation focuses on S3 buckets, DynamoDB tables, SNS topics, and SQS queues, with comprehensive intrinsic function resolution and dependency management.

## Task List

### Infrastructure & Foundation

#### Task Group 1: Core Resource Parsing Infrastructure
**Dependencies:** Roadmap Item #1 (Core Module Structure & YAML Parsing) - Complete

- [ ] 1.0 Complete core resource parsing infrastructure
  - [ ] 1.1 Write 2-8 focused tests for resource parsing
    - Test extraction of `resources.Resources` from parsed config
    - Test resource categorization by Type (S3, DynamoDB, SNS, SQS)
    - Test identification of unsupported resource types
    - Test empty/missing resources section handling
    - Test PascalCase to snake_case naming conversion
  - [ ] 1.2 Add resource parsing logic to `locals.tf`
    - Extract `resources.Resources` from core module output using `try()`
    - Create supported resource types set (AWS::S3::Bucket, AWS::DynamoDB::Table, AWS::SNS::Topic, AWS::SQS::Queue)
    - Build categorization maps for each resource type using `for` expressions
    - Implement PascalCase to snake_case conversion function
    - Create resource name mapping (logical ID → Terraform resource name)
    - Build resource reference mapping for intrinsic function resolution
  - [ ] 1.3 Add validation logic to `locals.tf`
    - Identify unsupported resources that are not in supported types set
    - Generate validation errors for unsupported resource types
    - Generate warnings for CloudFormation Condition field usage
    - Follow existing validation error collection pattern from core module
  - [ ] 1.4 Create `modules/custom_resources/` directory structure
    - Create directory: `modules/custom_resources/`
    - Create placeholder files: `variables.tf`, `outputs.tf`, `locals.tf`
    - Create service-specific files: `s3.tf`, `dynamodb.tf`, `sns.tf`, `sqs.tf`
    - Create `intrinsics.tf` for intrinsic function resolution
  - [ ] 1.5 Define module interface in `modules/custom_resources/variables.tf`
    - Input: `s3_buckets` (map of S3 bucket resources)
    - Input: `dynamodb_tables` (map of DynamoDB table resources)
    - Input: `sns_topics` (map of SNS topic resources)
    - Input: `sqs_queues` (map of SQS queue resources)
    - Input: `resource_name_map` (logical ID to Terraform name mapping)
    - Input: `service_name` (for default naming)
    - Input: `stage` (for tagging and naming)
  - [ ] 1.6 Ensure infrastructure layer tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify resource parsing and categorization works
    - Verify naming conversion is correct
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- Resources extracted and categorized correctly by type
- PascalCase to snake_case conversion handles edge cases (acronyms, numbers)
- Unsupported resource types identified with clear error messages
- Empty/missing resources section handled gracefully (no errors)
- Module directory structure created and ready for resource implementations


#### Task Group 2: Intrinsic Function Resolution Engine
**Dependencies:** Task Group 1

- [ ] 2.0 Complete intrinsic function resolution engine
  - [ ] 2.1 Write 2-8 focused tests for intrinsic function resolution
    - Test !Ref / Fn::Ref resolution to Terraform resource references
    - Test !GetAtt / Fn::GetAtt resolution to Terraform attribute references
    - Test !Sub / Fn::Sub resolution to Terraform string interpolation
    - Test !Join / Fn::Join resolution to Terraform join() function
    - Test nested intrinsic functions (e.g., !Sub with !Ref inside)
    - Skip exhaustive testing of all CloudFormation attribute mappings
  - [ ] 2.2 Implement tag format converter in `modules/custom_resources/locals.tf`
    - Create `convert_cf_tags` function to convert array to map
    - Input format: `[{Key: "Name", Value: "value"}]`
    - Output format: `{Name = "value"}`
    - Handle empty tag arrays
  - [ ] 2.3 Build resource reference map in `modules/custom_resources/locals.tf`
    - Map S3 logical IDs to `aws_s3_bucket.{name}.id`
    - Map DynamoDB logical IDs to `aws_dynamodb_table.{name}.name`
    - Map SNS logical IDs to `aws_sns_topic.{name}.arn`
    - Map SQS logical IDs to `aws_sqs_queue.{name}.url`
    - Merge all reference maps into single lookup table
  - [ ] 2.4 Implement !Ref resolver in `modules/custom_resources/intrinsics.tf`
    - Parse both short form (!Ref) and long form (Fn::Ref)
    - Look up logical ID in resource reference map
    - Return Terraform resource reference syntax
    - Fall back to `var.{lower(logical_id)}` for parameters
  - [ ] 2.5 Implement !GetAtt resolver in `modules/custom_resources/intrinsics.tf`
    - Parse both short form (!GetAtt) and long form (Fn::GetAtt)
    - Extract logical ID and attribute name
    - Create CloudFormation to Terraform attribute mapping table
    - Map common attributes: Arn, StreamArn, DomainName, etc.
    - Return Terraform attribute reference syntax
  - [ ] 2.6 Implement !Sub resolver in `modules/custom_resources/intrinsics.tf`
    - Parse both short form (!Sub) and long form (Fn::Sub)
    - Use regex to find ${LogicalId} and ${LogicalId.Attribute} patterns
    - Replace with Terraform interpolation syntax
    - Support both simple substitution and template with variables
  - [ ] 2.7 Implement !Join resolver in `modules/custom_resources/intrinsics.tf`
    - Parse Fn::Join format: [delimiter, [list, of, values]]
    - Recursively resolve intrinsic functions in value list
    - Generate Terraform join() function call
  - [ ] 2.8 Implement !If and !Equals resolvers in `modules/custom_resources/intrinsics.tf`
    - Map !If to Terraform conditional expressions (condition ? true : false)
    - Map !Equals to Terraform equality operators (==)
    - Convert condition names to Terraform variable references
  - [ ] 2.9 Create main intrinsic resolver dispatcher
    - Detect intrinsic function type from input value
    - Route to appropriate resolver function
    - Support both YAML short form and long form syntax
    - Handle nested intrinsic functions recursively
  - [ ] 2.10 Ensure intrinsic function tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify !Ref, !GetAtt, !Sub, !Join resolution works
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- Tag format converter handles CloudFormation tag arrays correctly
- !Ref resolves to correct Terraform resource references
- !GetAtt maps CloudFormation attributes to Terraform equivalents
- !Sub performs string interpolation with variable substitution
- !Join generates correct Terraform join() calls
- Nested intrinsic functions resolve correctly


### Resource Translation Layers

#### Task Group 3: S3 Bucket Translation
**Dependencies:** Task Groups 1, 2

- [ ] 3.0 Complete S3 bucket translation with decomposition pattern
  - [ ] 3.1 Write 2-8 focused tests for S3 bucket translation
    - Test simple S3 bucket with BucketName only
    - Test S3 bucket with versioning enabled
    - Test S3 bucket with encryption configuration
    - Test S3 bucket with lifecycle rules
    - Test S3 bucket with multiple configuration resources (versioning + encryption + CORS)
    - Skip exhaustive testing of all S3 property combinations
  - [ ] 3.2 Implement base S3 bucket resource in `modules/custom_resources/s3.tf`
    - Create `aws_s3_bucket` resources using `for_each` on `var.s3_buckets`
    - Map BucketName property to `bucket` argument (optional)
    - Apply tag conversion using `convert_cf_tags()` helper
    - Use Terraform resource naming: `aws_s3_bucket.{logical_id_snake_case}`
  - [ ] 3.3 Implement S3 bucket ACL resource in `modules/custom_resources/s3.tf`
    - Create `aws_s3_bucket_acl` for buckets with AccessControl property
    - Use `for_each` to filter buckets with AccessControl
    - Map AccessControl values (e.g., "PublicRead" → "public-read")
    - Reference base bucket using `aws_s3_bucket.buckets[each.key].id`
  - [ ] 3.4 Implement S3 bucket versioning in `modules/custom_resources/s3.tf`
    - Create `aws_s3_bucket_versioning` for buckets with VersioningConfiguration
    - Map VersioningConfiguration.Status to versioning_configuration block
    - Handle Enabled/Suspended status values
  - [ ] 3.5 Implement S3 bucket encryption in `modules/custom_resources/s3.tf`
    - Create `aws_s3_bucket_server_side_encryption_configuration` resource
    - Map BucketEncryption.ServerSideEncryptionConfiguration to rule blocks
    - Support SSEAlgorithm and KMSMasterKeyID properties
    - Use dynamic blocks for encryption rules
  - [ ] 3.6 Implement S3 public access block in `modules/custom_resources/s3.tf`
    - Create `aws_s3_bucket_public_access_block` resource
    - Map all four public access block properties
    - BlockPublicAcls, BlockPublicPolicy, IgnorePublicAcls, RestrictPublicBuckets
  - [ ] 3.7 Implement S3 lifecycle configuration in `modules/custom_resources/s3.tf`
    - Create `aws_s3_bucket_lifecycle_configuration` resource
    - Map LifecycleConfiguration.Rules to rule blocks
    - Support Expiration, Transitions, Status properties
    - Use nested dynamic blocks for transitions
  - [ ] 3.8 Implement S3 CORS configuration in `modules/custom_resources/s3.tf`
    - Create `aws_s3_bucket_cors_configuration` resource
    - Map CorsConfiguration.CorsRules to cors_rule blocks
    - Support AllowedHeaders, AllowedMethods, AllowedOrigins, ExposedHeaders, MaxAge
  - [ ] 3.9 Add S3 outputs to `modules/custom_resources/outputs.tf`
    - Output `s3_bucket_ids` map (logical ID → bucket ID)
    - Output `s3_bucket_arns` map (logical ID → bucket ARN)
    - Output `s3_bucket_domain_names` map (logical ID → domain name)
  - [ ] 3.10 Ensure S3 translation tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify bucket decomposition creates correct resources
    - Verify property mappings are correct
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- Base `aws_s3_bucket` resources created for all S3 resources
- Bucket decomposition creates separate resources for ACL, versioning, encryption, etc.
- Property mappings follow AWS provider 6.0+ patterns
- Tags converted from CloudFormation array to Terraform map format
- Outputs provide bucket IDs and ARNs for cross-resource references


#### Task Group 4: DynamoDB Table Translation
**Dependencies:** Task Groups 1, 2

- [ ] 4.0 Complete DynamoDB table translation with indexes
  - [ ] 4.1 Write 2-8 focused tests for DynamoDB table translation
    - Test table with hash key only
    - Test table with hash key and range key
    - Test table with global secondary index (GSI)
    - Test table with local secondary index (LSI)
    - Test table with streams enabled
    - Skip exhaustive testing of all billing modes and throughput combinations
  - [ ] 4.2 Implement base DynamoDB table resource in `modules/custom_resources/dynamodb.tf`
    - Create `aws_dynamodb_table` resources using `for_each`
    - Map TableName to `name` argument (with fallback to generated name)
    - Map AttributeDefinitions to `attribute` blocks
    - Extract hash_key and range_key from KeySchema array
    - Map BillingMode to `billing_mode` (PROVISIONED or PAY_PER_REQUEST)
  - [ ] 4.3 Implement provisioned throughput mapping in `modules/custom_resources/dynamodb.tf`
    - Map ProvisionedThroughput only when BillingMode is PROVISIONED
    - Set read_capacity and write_capacity from ReadCapacityUnits and WriteCapacityUnits
    - Use conditional logic to avoid setting when PAY_PER_REQUEST
  - [ ] 4.4 Implement global secondary indexes in `modules/custom_resources/dynamodb.tf`
    - Create `global_secondary_index` dynamic blocks
    - Map IndexName, KeySchema (hash_key, range_key), Projection properties
    - Map ProvisionedThroughput for GSI
    - Extract projection_type and non_key_attributes
  - [ ] 4.5 Implement local secondary indexes in `modules/custom_resources/dynamodb.tf`
    - Create `local_secondary_index` dynamic blocks
    - Map IndexName, KeySchema (range_key only), Projection
    - LSIs share hash key with table
  - [ ] 4.6 Implement DynamoDB streams in `modules/custom_resources/dynamodb.tf`
    - Map StreamSpecification.StreamEnabled to `stream_enabled`
    - Map StreamSpecification.StreamViewType to `stream_view_type`
    - Support: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES
  - [ ] 4.7 Implement server-side encryption in `modules/custom_resources/dynamodb.tf`
    - Create `server_side_encryption` dynamic block
    - Map SSESpecification.SSEEnabled and KMSMasterKeyId
    - Use conditional dynamic block (only if SSESpecification exists)
  - [ ] 4.8 Implement TTL configuration in `modules/custom_resources/dynamodb.tf`
    - Create `ttl` dynamic block
    - Map TimeToLiveSpecification.Enabled and AttributeName
  - [ ] 4.9 Add DynamoDB outputs to `modules/custom_resources/outputs.tf`
    - Output `dynamodb_table_names` map (logical ID → table name)
    - Output `dynamodb_table_arns` map (logical ID → table ARN)
    - Output `dynamodb_stream_arns` map (logical ID → stream ARN)
  - [ ] 4.10 Ensure DynamoDB translation tests pass
    - Run ONLY the 2-8 tests written in 4.1
    - Verify table creation with correct keys and attributes
    - Verify GSI and LSI creation
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.1 pass
- DynamoDB tables created with correct hash and range keys
- AttributeDefinitions mapped to attribute blocks
- Global and local secondary indexes created with full configuration
- Billing mode and provisioned throughput handled correctly
- Streams, encryption, and TTL configurations mapped properly
- Outputs provide table names, ARNs, and stream ARNs


#### Task Group 5: SNS Topic Translation
**Dependencies:** Task Groups 1, 2

- [ ] 5.0 Complete SNS topic translation with subscriptions
  - [ ] 5.1 Write 2-8 focused tests for SNS topic translation
    - Test simple SNS topic with name only
    - Test SNS topic with display name and KMS key
    - Test SNS topic with embedded subscriptions
    - Test standalone AWS::SNS::Subscription resources
    - Skip exhaustive testing of all subscription protocol types
  - [ ] 5.2 Implement base SNS topic resource in `modules/custom_resources/sns.tf`
    - Create `aws_sns_topic` resources using `for_each`
    - Map TopicName to `name` (optional, AWS generates if not specified)
    - Map DisplayName to `display_name`
    - Map KmsMasterKeyId to `kms_master_key_id`
    - Apply tag conversion
  - [ ] 5.3 Implement SNS topic subscriptions in `modules/custom_resources/sns.tf`
    - Extract subscriptions from topic Subscription property
    - Create `aws_sns_topic_subscription` resources using `for_each`
    - Generate subscription keys from topic logical ID and index
    - Map Protocol (email, sqs, lambda, http, https, sms)
    - Map Endpoint (with intrinsic function resolution for !GetAtt references)
  - [ ] 5.4 Support standalone SNS subscriptions in `modules/custom_resources/sns.tf`
    - Handle AWS::SNS::Subscription resource type
    - Map TopicArn property (resolve !Ref to topic)
    - Map Protocol and Endpoint
    - Create separate resource for each standalone subscription
  - [ ] 5.5 Add SNS outputs to `modules/custom_resources/outputs.tf`
    - Output `sns_topic_arns` map (logical ID → topic ARN)
    - Output `sns_topic_names` map (logical ID → topic name)
  - [ ] 5.6 Ensure SNS translation tests pass
    - Run ONLY the 2-8 tests written in 5.1
    - Verify topic creation and subscription resources
    - Verify intrinsic function resolution in endpoints
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 5.1 pass
- SNS topics created with correct properties
- Embedded subscriptions extracted and created as separate resources
- Standalone AWS::SNS::Subscription resources translated
- Topic ARN references resolved in subscription endpoints
- Outputs provide topic ARNs for cross-resource references


#### Task Group 6: SQS Queue Translation
**Dependencies:** Task Groups 1, 2

- [ ] 6.0 Complete SQS queue translation with dead letter queues
  - [ ] 6.1 Write 2-8 focused tests for SQS queue translation
    - Test simple SQS queue with basic properties
    - Test FIFO queue with content-based deduplication
    - Test queue with dead letter queue (DLQ) configuration
    - Test queue with KMS encryption
    - Skip exhaustive testing of all timeout/size property combinations
  - [ ] 6.2 Implement base SQS queue resource in `modules/custom_resources/sqs.tf`
    - Create `aws_sqs_queue` resources using `for_each`
    - Map QueueName to `name` (optional)
    - Map FifoQueue to `fifo_queue` boolean
    - Map ContentBasedDeduplication to `content_based_deduplication` boolean
    - Apply tag conversion
  - [ ] 6.3 Implement SQS timeout and size properties in `modules/custom_resources/sqs.tf`
    - Map DelaySeconds to `delay_seconds`
    - Map MaximumMessageSize to `max_message_size`
    - Map MessageRetentionPeriod to `message_retention_seconds`
    - Map ReceiveMessageWaitTimeSeconds to `receive_wait_time_seconds`
    - Map VisibilityTimeout to `visibility_timeout_seconds`
  - [ ] 6.4 Implement SQS redrive policy in `modules/custom_resources/sqs.tf`
    - Map RedrivePolicy to `redrive_policy` JSON string
    - Use `jsonencode()` to convert object to JSON
    - Resolve deadLetterTargetArn using intrinsic function resolver
    - Map maxReceiveCount property
  - [ ] 6.5 Implement SQS encryption in `modules/custom_resources/sqs.tf`
    - Map KmsMasterKeyId to `kms_master_key_id`
    - Map KmsDataKeyReusePeriodSeconds if present
  - [ ] 6.6 Add SQS outputs to `modules/custom_resources/outputs.tf`
    - Output `sqs_queue_urls` map (logical ID → queue URL)
    - Output `sqs_queue_arns` map (logical ID → queue ARN)
  - [ ] 6.7 Ensure SQS translation tests pass
    - Run ONLY the 2-8 tests written in 6.1
    - Verify queue creation with correct properties
    - Verify DLQ references resolved correctly
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 6.1 pass
- SQS queues created with all standard properties mapped
- FIFO queue configuration handled correctly
- Redrive policy (DLQ) converted to JSON with resolved ARN references
- Encryption properties mapped correctly
- Outputs provide queue URLs and ARNs


### Integration & Wiring

#### Task Group 7: Module Integration and Main Configuration
**Dependencies:** Task Groups 1-6

- [ ] 7.0 Complete module integration into main configuration
  - [ ] 7.1 Write 2-8 focused tests for module integration
    - Test module receives correct inputs from main module
    - Test module outputs are accessible from main configuration
    - Test multi-resource configuration with cross-references
    - Test integration with empty resources section
    - Skip exhaustive testing of all resource combinations
  - [ ] 7.2 Wire custom_resources module in `main.tf`
    - Add `module "custom_resources"` block
    - Pass categorized resources from locals (s3_buckets, dynamodb_tables, etc.)
    - Pass resource_name_map from locals
    - Pass service_name and stage from parsed config
    - Set source to `./modules/custom_resources`
  - [ ] 7.3 Add custom resource outputs to root `outputs.tf`
    - Output `s3_bucket_ids` from module.custom_resources
    - Output `s3_bucket_arns` from module.custom_resources
    - Output `dynamodb_table_names` from module.custom_resources
    - Output `dynamodb_table_arns` from module.custom_resources
    - Output `dynamodb_stream_arns` from module.custom_resources
    - Output `sns_topic_arns` from module.custom_resources
    - Output `sqs_queue_urls` from module.custom_resources
    - Output `sqs_queue_arns` from module.custom_resources
    - Output `custom_resource_count` (total resources created)
  - [ ] 7.4 Update validation in `main.tf`
    - Add precondition to check validation_errors from locals
    - Include custom resource validation errors in error collection
    - Ensure validation happens before resource creation
  - [ ] 7.5 Ensure module integration tests pass
    - Run ONLY the 2-8 tests written in 7.1
    - Verify module wiring is correct
    - Verify outputs are accessible
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 7.1 pass
- custom_resources module properly instantiated in main.tf
- All resource categories passed to module as inputs
- Module outputs accessible from root module
- Validation errors collected and displayed properly


#### Task Group 8: Dependency Management
**Dependencies:** Task Groups 1-7

- [ ] 8.0 Complete resource dependency management
  - [ ] 8.1 Write 2-8 focused tests for dependency management
    - Test dependency detection from !Ref usage
    - Test dependency detection from !GetAtt usage
    - Test explicit DependsOn field handling
    - Test resource creation order (DLQ before main queue)
    - Skip exhaustive testing of all dependency graph permutations
  - [ ] 8.2 Implement implicit dependency detection in `modules/custom_resources/locals.tf`
    - Scan all property values for intrinsic functions
    - Build dependency map from !Ref and !GetAtt usage
    - Track which resources reference which other resources
  - [ ] 8.3 Handle explicit DependsOn in resource translations
    - Parse DependsOn field from CloudFormation resources
    - Convert CloudFormation logical IDs to Terraform resource references
    - Add `depends_on` meta-argument where needed
  - [ ] 8.4 Implement resource ordering for S3 decomposition
    - Ensure base bucket created before ACL, versioning, encryption resources
    - Use implicit dependencies via bucket ID references
    - No explicit depends_on needed due to bucket references
  - [ ] 8.5 Implement resource ordering for SQS DLQ
    - Ensure DLQ queue created before main queue
    - Use implicit dependency via DLQ ARN reference in redrive_policy
    - Add explicit depends_on if needed for clarity
  - [ ] 8.6 Implement resource ordering for SNS subscriptions
    - Ensure topic created before subscriptions
    - Use implicit dependency via topic ARN references
  - [ ] 8.7 Ensure dependency management tests pass
    - Run ONLY the 2-8 tests written in 8.1
    - Verify correct resource creation order
    - Verify dependencies resolved properly
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 8.1 pass
- Implicit dependencies detected from intrinsic function usage
- Explicit DependsOn fields converted to Terraform dependencies
- Resource creation order correct (dependencies created first)
- S3 bucket decomposition resources created in correct order
- DLQ created before queues that reference it


### Testing & Documentation

#### Task Group 9: Comprehensive Testing and Integration Validation
**Dependencies:** Task Groups 1-8

- [ ] 9.0 Review existing tests and fill critical gaps
  - [ ] 9.1 Review tests from Task Groups 1-8
    - Review tests from infrastructure layer (Group 1: ~5 tests)
    - Review tests from intrinsic functions (Group 2: ~6 tests)
    - Review tests from S3 translation (Group 3: ~6 tests)
    - Review tests from DynamoDB translation (Group 4: ~6 tests)
    - Review tests from SNS translation (Group 5: ~5 tests)
    - Review tests from SQS translation (Group 6: ~5 tests)
    - Review tests from module integration (Group 7: ~5 tests)
    - Review tests from dependency management (Group 8: ~5 tests)
    - Total existing tests: approximately 43 tests
  - [ ] 9.2 Analyze test coverage gaps for custom resource provisioning feature
    - Identify critical end-to-end workflows lacking coverage
    - Focus on multi-resource configurations with cross-references
    - Identify integration scenarios with Lambda functions (roadmap item #2)
    - Prioritize real-world serverless.yml translation scenarios
    - Do NOT assess entire application test coverage
    - Focus ONLY on custom resource provisioning feature
  - [ ] 9.3 Write up to 10 additional strategic tests maximum
    - Add test for complete multi-resource serverless.yml (S3 + DynamoDB + SNS + SQS)
    - Add test for cross-resource references (SQS → SNS subscription, bucket → DLQ)
    - Add test for S3 bucket with all optional configurations combined
    - Add test for DynamoDB table with multiple GSIs and LSIs
    - Add test for unsupported resource type error handling
    - Add test for CloudFormation Condition warning generation
    - Add integration test with Terraform plan/apply (if infrastructure available)
    - Add test for tag format conversion across all resource types
    - Do NOT write exhaustive edge case tests
    - Do NOT write performance or load tests
  - [ ] 9.4 Run feature-specific tests only
    - Run ONLY tests related to custom resource provisioning feature
    - Expected total: approximately 53 tests maximum (43 existing + up to 10 new)
    - Do NOT run entire test suite for other roadmap items
    - Verify all critical user workflows pass
  - [ ] 9.5 Create test fixtures in `tests/fixtures/`
    - Create `serverless-s3.yml` with S3 bucket examples
    - Create `serverless-dynamodb.yml` with DynamoDB table examples
    - Create `serverless-sns.yml` with SNS topic examples
    - Create `serverless-sqs.yml` with SQS queue examples
    - Create `serverless-multi-resource.yml` with cross-references
    - Create expected Terraform output files for comparison
  - [ ] 9.6 Document example translations in spec
    - Verify examples in spec.md match actual implementation
    - Update examples if implementation differs
    - Add additional examples for complex scenarios if needed

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 53 tests maximum)
- Critical user workflows for custom resource provisioning are covered
- No more than 10 additional tests added to fill gaps
- Multi-resource configurations with cross-references tested
- Integration with core module (roadmap item #1) verified
- Test fixtures provide clear examples of supported patterns
- Example translations in spec match implementation


## Execution Order

Recommended implementation sequence:

1. **Infrastructure Foundation** (Task Group 1)
   - Sets up resource parsing, categorization, and module structure
   - Creates foundation for all resource translations

2. **Intrinsic Functions** (Task Group 2)
   - Enables property value resolution across all resource types
   - Required before implementing any resource translations

3. **S3 Buckets** (Task Group 3)
   - Most complex resource due to decomposition pattern
   - Establishes pattern for property mapping and tag conversion

4. **DynamoDB Tables** (Task Group 4)
   - Complex nested structures (indexes, streams)
   - Tests dynamic block patterns extensively

5. **SNS Topics** (Task Group 5)
   - Introduces subscription resource creation pattern
   - Tests cross-resource reference resolution

6. **SQS Queues** (Task Group 6)
   - Implements JSON policy encoding
   - Tests DLQ dependency pattern

7. **Module Integration** (Task Group 7)
   - Wires everything together in main configuration
   - Exposes outputs for cross-feature integration

8. **Dependency Management** (Task Group 8)
   - Ensures correct resource creation order
   - Critical for complex multi-resource configurations

9. **Testing & Validation** (Task Group 9)
   - Validates complete feature implementation
   - Fills any critical test coverage gaps

## Key Implementation Notes

### Terraform-Specific Patterns

**S3 Bucket Decomposition (AWS Provider 6.0+):**
- Use separate resources for bucket configuration properties
- Base bucket only contains `bucket` and `tags` arguments
- All other properties split into dedicated resources
- Example: `aws_s3_bucket_versioning`, `aws_s3_bucket_encryption`, etc.

**Dynamic Blocks for Nested Configuration:**
- Use `dynamic` blocks for optional nested structures
- Example: DynamoDB GSI/LSI, S3 lifecycle rules, encryption rules
- Use `for_each` with conditional filtering to include only when properties exist

**Tag Format Conversion:**
- CloudFormation: `[{Key: "Name", Value: "value"}]`
- Terraform: `{Name = "value"}`
- Use `for` expression to convert array to map

**Intrinsic Function Resolution:**
- Must resolve during Terraform locals processing
- Cannot use external data sources or scripts
- Pure Terraform string manipulation using regex and replace functions

**Resource Naming Convention:**
- CloudFormation logical IDs: PascalCase (e.g., "MyDataBucket")
- Terraform resource names: snake_case (e.g., "my_data_bucket")
- Conversion handles acronyms (e.g., "APIGateway" → "api_gateway")

### Integration Points

**Core Module (Roadmap Item #1):**
- Consumes `resources` output from core module
- Uses same validation error collection pattern
- Follows same `try()` wrapper approach for safe property access

**Lambda Functions (Roadmap Item #2):**
- May need to reference S3 buckets for Lambda code storage
- DynamoDB and SQS outputs used for event source mappings
- SNS topic ARNs used for Lambda subscriptions

**Future Roadmap Items:**
- Event source mappings (Item #4, #5, #8) will reference SQS and DynamoDB outputs
- API Gateway (Item #3) may reference resources for data access
- Variable resolution (Item #10) will enhance intrinsic function support

### Testing Strategy

**Unit Test Focus Areas:**
- Resource parsing and categorization
- PascalCase to snake_case conversion
- Intrinsic function resolution
- Property mapping for each resource type
- Tag format conversion

**Integration Test Focus Areas:**
- Multi-resource configurations
- Cross-resource references (intrinsic functions)
- Dependency ordering
- Empty/missing resources section handling
- Complete serverless.yml translation

**Test Fixtures:**
- Provide realistic serverless.yml examples
- Cover common serverless application patterns
- Include edge cases (empty configs, unsupported resources)
- Test both simple and complex resource configurations

### Code Quality Guidelines

- Run `terraform fmt` on all .tf files before committing
- Use descriptive variable names for property mappings
- Add comments explaining CloudFormation → Terraform mappings
- Keep resource blocks organized by service type in separate files
- Follow DRY principle for common transformation logic (tags, naming)
- Document intrinsic function resolution logic with examples

---

**This task breakdown is ready for execution.** Each task group is designed to be implemented by a specialist (infrastructure engineer, testing engineer) with clear acceptance criteria and dependencies. The total scope includes approximately 53 tests maximum across all task groups, with focused testing during development and strategic gap-filling in the final task group.
