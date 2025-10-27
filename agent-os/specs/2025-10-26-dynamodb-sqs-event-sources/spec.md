# Specification: DynamoDB & SQS Event Sources

## Goal
Enable automatic creation of AWS Lambda event source mappings for DynamoDB Streams and SQS queues from Serverless Framework event configurations, supporting batch processing, error handling, and filtering capabilities with full validation and IAM permission auto-generation.

## User Stories
- As a Terraform user, I want to define DynamoDB stream events in my serverless.yml and have Lambda event source mappings automatically created, so I can process stream records without manual AWS resource configuration
- As a developer, I want to configure SQS queue events with batch size and error handling, so my Lambda functions can reliably consume messages from queues
- As an infrastructure engineer, I want event source mappings to validate configuration against AWS limits before deployment, so I catch errors early rather than at runtime
- As a team lead, I want IAM permissions automatically generated for stream and queue access matching Serverless Framework behavior, so developers don't need deep AWS knowledge to configure event sources
- As a migration architect, I want event source mapping configurations to match Serverless Framework behavior exactly, so application event processing remains consistent during Terraform migration

## Core Requirements

### Event Source Detection and Parsing
- Parse `events` array from each function in `functions_with_defaults` output
- Detect DynamoDB stream events by presence of `stream` field or `type: stream` with DynamoDB ARN pattern
- Detect SQS events by presence of `arn` field with SQS pattern or `type: sqs`
- Identify DynamoDB streams via ARN pattern: `arn:aws:dynamodb:*:*:table/*/stream/*`
- Identify SQS queues via ARN pattern: `arn:aws:sqs:*:*:*`
- Distinguish SQS FIFO queues by ARN suffix `.fifo` for different batch size limits
- Support functions with multiple event sources (create multiple mappings with unique identifiers)
- Support functions with no event sources (create no mappings, return empty outputs)
- Skip non-stream/non-sqs events (http, s3, schedule, eventBridge, etc.) without errors

### DynamoDB Stream Event Source Mappings
- Create `aws_lambda_event_source_mapping` resource for each DynamoDB stream event
- Map `event_source_arn` from `stream` field (full ARN required)
- Map `starting_position` (LATEST or TRIM_HORIZON, default: TRIM_HORIZON)
- Map `batch_size` (1-10000 records, default: 100)
- Map `maximum_batching_window_in_seconds` (0-300 seconds, optional)
- Map `enabled` flag (default: true)
- Map `parallelization_factor` (1-10, optional, DynamoDB-specific)
- Map `maximum_record_age_in_seconds` (60-604800 or -1 for infinite, optional)
- Map `maximum_retry_attempts` (0-10000, optional)
- Map `bisect_batch_on_function_error` (boolean, optional)
- Map `tumbling_window_in_seconds` (0-900 seconds, optional)
- Map `destination_config` for failure destinations (SNS/SQS ARNs only, optional)
- Map `filter_criteria` patterns (optional, AWS validates pattern syntax)

### SQS Queue Event Source Mappings
- Create `aws_lambda_event_source_mapping` resource for each SQS event
- Map `event_source_arn` from `arn` field (full ARN required)
- Map `batch_size` with queue-type-aware defaults:
  - Standard queues: 1-10 messages (default: 10)
  - FIFO queues: 1-10000 messages (default: 10)
- Map `maximum_batching_window_in_seconds` (0-300 seconds, optional)
- Map `enabled` flag (default: true)
- Map `function_response_types` (array containing ReportBatchItemFailures, optional)
- Map `scaling_config.maximum_concurrency` (2-1000, optional, SQS-specific)
- Map `filter_criteria` patterns (optional)

### Resource Naming and Identification
- Use unique resource identifiers: `{function_key}_{event_type}_{event_index}`
- Event type: `stream` for DynamoDB, `sqs` for SQS queues
- Event index: 0-based position in events array (increments across all events)
- Flatten nested function/events structure into flat map for `for_each` iteration
- Associate each mapping with corresponding Lambda function ARN
- Maintain Terraform implicit dependencies via function ARN references

### Configuration Validation
- Validate batch size ranges based on detected event source type:
  - DynamoDB Streams: 1-10000 records
  - SQS Standard queues: 1-10 messages
  - SQS FIFO queues: 1-10000 messages
- Validate `starting_position` is LATEST or TRIM_HORIZON (AT_TIMESTAMP reserved for future)
- Validate `maximum_retry_attempts` range: 0-10000
- Validate `parallelization_factor` range: 1-10
- Validate `maximum_batching_window_in_seconds` range: 0-300
- Validate `tumbling_window_in_seconds` range: 0-900
- Validate `scaling_config.maximum_concurrency` range: 2-1000
- Validate ARN format matches expected pattern for event source type
- Check that referenced DynamoDB tables/streams exist in serverless.yml resources section OR Terraform state
- Check that referenced SQS queues exist in serverless.yml resources section OR Terraform state
- Collect all validation errors before resource creation using error collection pattern from core module
- Halt execution with clear error messages using precondition lifecycle blocks

### IAM Permission Auto-Generation
- Research Serverless Framework source code/documentation for automatic IAM permission patterns
- Generate IAM policy statements for DynamoDB stream read permissions:
  - `dynamodb:GetRecords` - read stream records
  - `dynamodb:GetShardIterator` - navigate stream shards
  - `dynamodb:DescribeStream` - query stream metadata
  - `dynamodb:ListStreams` - discover available streams
- Generate IAM policy statements for SQS queue consume permissions:
  - `sqs:ReceiveMessage` - receive messages from queue
  - `sqs:DeleteMessage` - remove processed messages
  - `sqs:GetQueueAttributes` - query queue metadata
- Scope all permissions to specific resource ARNs from event configurations (no wildcards)
- Provide outputs that integrate with roadmap item #3 (IAM Role & Policy Management)

### Module Outputs
- Output map of event source mapping IDs keyed by resource identifier
- Output map of event source mapping ARNs keyed by resource identifier
- Output map of event source mapping states keyed by resource identifier
- Output total count of event source mappings created
- Return empty maps when no event sources are defined (graceful handling)

## Visual Design
No visual assets provided - this is infrastructure-as-code implementation.

## Reusable Components

### Existing Code to Leverage

**From Core Module (locals.tf):**
- Validation error collection pattern using `concat()` and conditional ternary expressions
- Default value application using `coalesce()` and `try()` for optional fields
- Precondition lifecycle blocks for validation enforcement before resource creation
- Error message formatting with `join("\n- ", local.validation_errors)` for readability
- Use of `flatten()` for converting nested structures to flat lists
- Pattern: `try(config.field, null) != null && (validation_check) ? ["error message"] : []`

**From Core Module (outputs.tf):**
- `functions_with_defaults` - function definitions with events array and inherited defaults
- `provider_config` - region, stage, and provider settings
- `service_name` - for constructing resource names and tags

**From Core Module (main.tf):**
- Null resource validation pattern with multiple precondition blocks
- Validation execution gate before any resource creation
- Consistent error message format and structure

**Terraform Built-in Functions:**
- `try()` - safely access optional event configuration fields without errors
- `coalesce()` - apply default values (batch_size, starting_position, enabled)
- `for_each` - iterate over flattened event source mappings to create resources
- `merge()` - combine event configuration with function metadata
- `flatten()` - convert nested function/events structure to flat map
- `jsonencode()` - format filter patterns as JSON strings
- `can()` and `regex()` - validate ARN formats and detect event types
- `contains()` - validate starting position enum values
- Dynamic blocks - conditional nested configurations (destination_config, filter_criteria, scaling_config)

**Naming Conventions from Core Module:**
- Follow snake_case for resource names and local variables
- Use descriptive names that reveal intent (e.g., `stream_events`, `sqs_events`, `event_validation_errors`)
- Resource identifiers: `{function_key}_{event_type}_{index}` pattern

### New Components Required

**Event Flattening Logic:**
- Flatten nested function/events structure into flat map for `for_each`
- Why needed: Terraform `for_each` requires flat map, but events are nested under functions
- Pattern: Use nested for loops with merge to create flat structure keyed by unique identifier
- Cannot reuse: No existing event extraction logic in core module

**Event Type Detection Logic:**
- Detect DynamoDB vs SQS event types from configuration fields and ARN patterns
- Why needed: Different event types have different validation rules and default values
- Pattern: Use `can(regex())` to match ARN patterns for type detection
- Cannot reuse: New functionality specific to event source mappings

**Queue Type Detection (Standard vs FIFO):**
- Detect SQS queue type from ARN suffix to determine batch size limits
- Why needed: FIFO queues allow batch_size 1-10000, standard queues only 1-10
- Pattern: Use `can(regex("\\.fifo$", queue_arn))` to identify FIFO queues
- Cannot reuse: New validation logic not present in core module

**Resource Reference Validation:**
- Check if DynamoDB tables/streams exist in serverless.yml resources OR Terraform state
- Check if SQS queues exist in serverless.yml resources OR Terraform state
- Why needed: Prevent broken references that would fail at runtime
- Pattern: New validation logic, integrates with core module validation error collection
- Cannot reuse: No existing resource reference validation in core module

**IAM Policy Statement Generation:**
- Generate IAM policy document for stream/queue read permissions
- Why needed: Auto-generate permissions like Serverless Framework does
- Pattern: Create policy statements output for consumption by IAM module (roadmap item #3)
- Cannot reuse: New component, will integrate with future IAM module

## Technical Approach

### Module Structure
Integrate into existing Terraform module (not a separate module):
- `main.tf` - add event source mapping resources
- `locals.tf` - add event flattening, validation, defaults logic
- `outputs.tf` - add event source mapping outputs
- `versions.tf` - no changes (already supports required versions)

### Input Sources
Consume from existing module outputs:
- `local.functions_with_defaults` - from core module locals.tf
- Lambda function ARNs - from aws_lambda_function resources (roadmap item #2)
- `local.service_name` - from core module locals.tf
- `local.provider_with_defaults` - from core module locals.tf

### Event Flattening Strategy
Transform nested structure:
```
functions:
  myFunc:
    events:
      - stream: arn:aws:dynamodb:...
      - sqs: arn:aws:sqs:...
```

Into flat map for `for_each`:
```
{
  "myFunc_stream_0": {
    function: "myFunc",
    event: {...},
    type: "stream",
    function_arn: "arn:aws:lambda:..."
  }
  "myFunc_sqs_1": {
    function: "myFunc",
    event: {...},
    type: "sqs",
    function_arn: "arn:aws:lambda:..."
  }
}
```

### Validation Strategy
- Collect all validation errors in local value before any resource creation
- Use null_resource with precondition blocks to enforce validation (follows core module pattern)
- Fail fast with clear messages identifying function, event index, field, and expected values
- Validate batch sizes based on detected event source type (DynamoDB vs SQS standard vs FIFO)
- Validate ARN formats match expected patterns using regex
- Check resource references exist in serverless.yml resources OR Terraform state

### IAM Integration
- Research Serverless Framework documentation and source code for permission generation patterns
- Create local values containing required IAM policy statements for discovered event sources
- Provide outputs with permission requirements for integration with IAM module (roadmap item #3)
- Scope permissions to specific ARNs from event configurations (not wildcards)
- Follow least-privilege principle

### Default Value Application
Match Serverless Framework defaults exactly:
- DynamoDB: `batch_size=100`, `starting_position=TRIM_HORIZON`, `enabled=true`
- SQS: `batch_size=10`, `enabled=true`
- Apply using `coalesce()` pattern: `coalesce(try(event.batchSize, null), 100)`

### Resource Dependencies
- Event source mappings reference Lambda function ARNs (creates implicit dependency)
- Terraform ensures Lambda functions exist before creating mappings
- No explicit `depends_on` needed - implicit dependencies via resource references
- Null resource validation executes before event source mapping resources

### Serverless Framework Version Support
- Support v2.x, v3.x, and v4.x schema versions as specified in requirements
- Event configuration must match Serverless Framework schema for all versions
- Event detection must handle both explicit `type` field and inferred type from ARN
- Note: Roadmap item #13 already includes v4.x support, no roadmap update needed

## Out of Scope

**Event Sources Not Included:**
- Kinesis Stream event sources (different configuration, not in roadmap description)
- MSK (Managed Streaming for Apache Kafka) event sources (advanced, not common)
- Self-managed Kafka event sources (advanced setup)
- Any other event source types handled by other roadmap items (http, s3, schedule, eventBridge)

**Advanced Features:**
- AT_TIMESTAMP starting position (requires starting_position_timestamp attribute, reserved for future)
- DynamoDB Global Table streams (complex multi-region setup)
- EventBridge and Lambda error handling destinations (future enhancement, initial scope SNS/SQS only)
- Cross-account event sources (requires additional IAM setup and resource policies)
- Event source ARN data lookups via data sources (future enhancement for improved DX)
- Advanced filter pattern syntax validation (AWS validates at resource creation time)
- Event source state management outside Terraform lifecycle
- Lambda permissions resources (not required for DynamoDB/SQS event sources)

**Infrastructure Concerns Not Included:**
- Lambda function creation (handled by roadmap item #2)
- DynamoDB table/stream creation (handled by roadmap item #9)
- SQS queue creation (handled by roadmap item #9)
- VPC configuration for Lambda functions
- Dead letter queue configuration (separate from event source mapping failure destinations)

## Success Criteria

### Functional Success
- DynamoDB stream events in serverless.yml produce valid `aws_lambda_event_source_mapping` resources
- SQS queue events in serverless.yml produce valid `aws_lambda_event_source_mapping` resources
- Functions with multiple events create multiple mappings with unique identifiers
- Functions with no events create zero mappings and produce empty output maps
- Default values match Serverless Framework behavior exactly (batch_size, starting_position, enabled)
- Optional configurations only included when specified (not null values)

### Validation Success
- Invalid batch sizes caught with clear error messages before resource creation
- Batch size validation accounts for queue type (standard vs FIFO)
- Invalid starting positions rejected with helpful guidance (expected: LATEST or TRIM_HORIZON)
- Malformed ARNs detected and reported with specific field and function reference
- Missing resource references identified in validation phase
- All validation errors collected and displayed together (not one at a time)
- Error message format matches core module validation pattern

### Integration Success
- Module consumes `functions_with_defaults` from core module without modification
- Module consumes Lambda function ARNs from roadmap item #2 resources
- IAM permission outputs integrate with IAM module (roadmap item #3)
- Terraform dependencies ensure correct resource creation order (functions before mappings)
- Module outputs provide complete mapping information for downstream consumers
- No interference with other roadmap item features

### Compatibility Success
- Configuration parsing supports Serverless Framework v2.x, v3.x, and v4.x schemas
- Event detection works with both explicit `type` field and inferred type from ARN pattern
- ARN pattern matching handles all valid AWS ARN formats for DynamoDB and SQS
- Module works with Terraform 1.0.0+ and AWS provider 6.0+ (inherited from core module)
- Pure HCL implementation with no external dependencies

### Performance Success
- Validation completes before any resource creation (fail fast principle)
- Event flattening handles large numbers of functions and events efficiently
- No external data sources or API calls required during plan phase
- Module can be applied idempotently without recreating mappings unnecessarily

### User Experience Success
- Error messages clearly identify which function and event has the problem
- Validation messages include expected ranges and actual values provided
- Missing required fields produce actionable guidance for resolution
- Resource identifiers follow predictable, debuggable naming pattern
- Empty event configurations handled gracefully without errors
