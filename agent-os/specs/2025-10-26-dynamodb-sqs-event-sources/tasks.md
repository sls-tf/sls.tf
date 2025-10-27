# Task Breakdown: DynamoDB & SQS Event Sources

## Overview
Total Tasks: 5 Task Groups
Feature: Implement aws_lambda_event_source_mapping resources for DynamoDB Streams and SQS queues with comprehensive validation and IAM permission auto-generation

## Task List

### Event Source Detection and Flattening

#### Task Group 1: Event Parsing and Type Detection
**Dependencies:** None (consumes existing core module outputs)

- [ ] 1.0 Complete event source detection and flattening logic
  - [ ] 1.1 Write 2-8 focused tests for event flattening and type detection
    - Limit to 2-8 highly focused tests maximum
    - Test only critical behaviors:
      - Flatten nested function/events structure to flat map for for_each
      - Detect DynamoDB stream events by ARN pattern (arn:aws:dynamodb:*:*:table/*/stream/*)
      - Detect SQS events by ARN pattern (arn:aws:sqs:*:*:*)
      - Detect FIFO vs standard SQS queues by .fifo suffix
      - Handle functions with multiple event sources (unique identifiers)
      - Handle functions with no event sources (empty output)
      - Skip non-stream/non-sqs events without errors
    - Use Terraform native test framework (.tftest.hcl files)
    - Create minimal test fixtures in tests/fixtures/ directory
    - Skip exhaustive edge case coverage
  - [ ] 1.2 Add event flattening logic to locals.tf
    - Flatten nested functions.events structure into flat map
    - Create unique resource identifiers: `{function_key}_{event_type}_{event_index}`
    - Use nested for loops with merge to create flat structure
    - Pattern: `for func_name, func in local.functions_with_defaults : for idx, event in try(func.events, []) : ...`
    - Include function metadata (name, handler, etc.) in flattened structure
    - Reference pattern from core module's functions_with_defaults flattening
  - [ ] 1.3 Add event type detection logic to locals.tf
    - Detect DynamoDB streams: check for `stream` field or `type: stream` with DynamoDB ARN pattern
    - Detect SQS queues: check for `arn` field with SQS pattern or `type: sqs`
    - Use `can(regex())` for ARN pattern matching
    - Create local values: `stream_events` and `sqs_events` as filtered subsets
    - Validate ARN formats match expected patterns
  - [ ] 1.4 Add SQS queue type detection logic to locals.tf
    - Detect FIFO queues by ARN suffix `.fifo` using `can(regex("\\.fifo$", arn))`
    - Create local value for queue type mapping (standard vs FIFO)
    - Use for queue-type-aware batch size validation
    - Store as boolean: `is_fifo_queue` property in event metadata
  - [ ] 1.5 Ensure event detection tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify event flattening produces correct structure
    - Verify type detection works for DynamoDB and SQS
    - Verify FIFO queue detection works
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- Nested function/events structure flattened to map keyed by unique identifiers
- DynamoDB stream events correctly identified by ARN pattern
- SQS events correctly identified by ARN pattern
- FIFO vs standard queue type correctly detected
- Functions with zero events produce empty maps
- Non-stream/non-sqs events skipped without errors

### Validation Logic

#### Task Group 2: Configuration Validation and Error Collection
**Dependencies:** Task Group 1

- [ ] 2.0 Complete validation logic for event source configurations
  - [ ] 2.1 Write 2-8 focused tests for validation logic
    - Limit to 2-8 highly focused tests maximum
    - Test only critical validation behaviors:
      - Invalid DynamoDB batch size (< 1 or > 10000) rejected
      - Invalid SQS standard batch size (< 1 or > 10) rejected
      - Invalid SQS FIFO batch size (< 1 or > 10000) rejected
      - Invalid starting_position (not LATEST or TRIM_HORIZON) rejected
      - Invalid ARN format detected and reported
      - Multiple validation errors collected together (not one at a time)
      - Valid configurations pass validation
    - Use expect_failures pattern for invalid configs
    - Skip exhaustive parameter validation (AWS will validate at runtime)
  - [ ] 2.2 Add batch size validation to locals.tf
    - DynamoDB Streams: validate range 1-10000 records
    - SQS Standard queues: validate range 1-10 messages
    - SQS FIFO queues: validate range 1-10000 messages
    - Use queue type detection from Task Group 1
    - Pattern: `try(event.batchSize, null) != null && (condition) ? ["error message"] : []`
    - Follow core module validation error collection pattern
  - [ ] 2.3 Add parameter range validations to locals.tf
    - Validate `starting_position` is LATEST or TRIM_HORIZON using `contains()`
    - Validate `maximum_retry_attempts`: 0-10000
    - Validate `parallelization_factor`: 1-10 (DynamoDB only)
    - Validate `maximum_batching_window_in_seconds`: 0-300
    - Validate `tumbling_window_in_seconds`: 0-900 (DynamoDB only)
    - Validate `scaling_config.maximum_concurrency`: 2-1000 (SQS only)
    - Collect all errors using concat() pattern
  - [ ] 2.4 Add ARN format validation to locals.tf
    - Validate DynamoDB stream ARN matches: `arn:aws:dynamodb:*:*:table/*/stream/*`
    - Validate SQS queue ARN matches: `arn:aws:sqs:*:*:*`
    - Use `can(regex())` for pattern matching
    - Add descriptive error messages identifying function, event index, and field
    - Pattern: `!can(regex("pattern", arn)) ? ["error"] : []`
  - [ ] 2.5 Add resource reference validation to locals.tf
    - Check if DynamoDB tables/streams exist in local.parsed_config.resources section
    - Check if SQS queues exist in local.parsed_config.resources section
    - Extract table/queue names from ARNs using regex
    - Look up resources in serverless.yml resources section
    - Future: Add Terraform state lookup (deferred - requires data sources)
    - Collect missing resource errors
  - [ ] 2.6 Create validation error collection local value
    - Concatenate all validation errors from 2.2-2.5
    - Follow core module pattern: `local.event_source_validation_errors = concat(...)`
    - Include function name, event index, field name in error messages
    - Format: "Function 'myFunc' event 0: Invalid batch_size. Must be between X and Y, got: Z."
  - [ ] 2.7 Add validation enforcement to main.tf
    - Add precondition to null_resource.config_validation (or create new validation resource)
    - Check: `length(local.event_source_validation_errors) == 0`
    - Error message: `join("\n- ", local.event_source_validation_errors)`
    - Ensures validation runs before event source mapping creation
  - [ ] 2.8 Ensure validation tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify invalid configurations are rejected with clear messages
    - Verify valid configurations pass validation
    - Verify multiple errors collected together
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- Batch size validation enforces correct ranges based on event type
- Starting position validation accepts only LATEST or TRIM_HORIZON
- Parameter range validations enforce AWS Lambda limits
- ARN format validation detects malformed ARNs
- Resource reference validation identifies missing resources
- All validation errors collected before resource creation
- Error messages include function name, event index, and field context

### Event Source Mapping Resources

#### Task Group 3: Resource Generation and Default Application
**Dependencies:** Task Groups 1, 2

- [ ] 3.0 Complete event source mapping resource generation
  - [ ] 3.1 Write 2-8 focused tests for resource generation
    - Limit to 2-8 highly focused tests maximum
    - Test only critical resource generation behaviors:
      - DynamoDB stream event creates aws_lambda_event_source_mapping with correct ARN
      - SQS event creates aws_lambda_event_source_mapping with correct ARN
      - Default values applied correctly (batch_size: 100 for DynamoDB, 10 for SQS)
      - Default starting_position: TRIM_HORIZON for DynamoDB
      - Default enabled: true
      - Optional parameters only included when specified (not null values)
      - Multiple events per function create multiple resources
    - Verify resource attributes in plan output
    - Skip exhaustive parameter combination testing
  - [ ] 3.2 Add default value application logic to locals.tf
    - DynamoDB defaults: `batch_size=100`, `starting_position=TRIM_HORIZON`, `enabled=true`
    - SQS defaults: `batch_size=10`, `enabled=true`
    - Use `coalesce(try(event.batchSize, null), default_value)` pattern
    - Apply defaults in enriched event map for resource consumption
    - Reference Serverless Framework documentation for exact default values
  - [ ] 3.3 Research IAM permissions in Serverless Framework source
    - Review Serverless Framework GitHub repository for IAM auto-generation
    - Document required DynamoDB stream permissions: GetRecords, GetShardIterator, DescribeStream, ListStreams
    - Document required SQS queue permissions: ReceiveMessage, DeleteMessage, GetQueueAttributes
    - Identify permission scoping patterns (specific ARNs vs wildcards)
    - Create reference document in planning/ directory with findings
  - [ ] 3.4 Create aws_lambda_event_source_mapping resources in main.tf
    - Use `for_each = local.stream_events` for DynamoDB resources
    - Use `for_each = local.sqs_events` for SQS resources
    - Map `function_name` from Lambda function ARN reference
    - Map `event_source_arn` from event configuration
    - Map all required and optional parameters from event config
    - Use dynamic blocks for optional nested configurations:
      - `destination_config` for failure destinations
      - `filter_criteria` for event filtering
      - `scaling_config` for SQS maximum concurrency
    - Apply defaults from 3.2
    - Follow Terraform resource naming: `aws_lambda_event_source_mapping.stream["function_stream_0"]`
  - [ ] 3.5 Add DynamoDB-specific configurations
    - Map `starting_position` (required for streams)
    - Map `parallelization_factor` (optional, 1-10)
    - Map `maximum_record_age_in_seconds` (optional, 60-604800 or -1)
    - Map `bisect_batch_on_function_error` (optional, boolean)
    - Map `tumbling_window_in_seconds` (optional, 0-900)
    - Only include when specified (use try() to check existence)
  - [ ] 3.6 Add SQS-specific configurations
    - Map `function_response_types` (optional, array with ReportBatchItemFailures)
    - Map `scaling_config.maximum_concurrency` (optional, 2-1000)
    - Use dynamic block for scaling_config when specified
    - Only include when specified (use try() to check existence)
  - [ ] 3.7 Add shared optional configurations
    - Map `batch_size` with type-aware defaults
    - Map `maximum_batching_window_in_seconds` (optional, 0-300)
    - Map `enabled` (default: true)
    - Map `maximum_retry_attempts` (optional, 0-10000)
    - Use dynamic block for `destination_config` when specified
    - Use dynamic block for `filter_criteria` when patterns specified
  - [ ] 3.8 Ensure resource generation tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify resources created with correct attributes
    - Verify defaults applied correctly
    - Verify optional parameters only included when specified
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- DynamoDB stream events create aws_lambda_event_source_mapping resources
- SQS events create aws_lambda_event_source_mapping resources
- Default values match Serverless Framework behavior exactly
- Optional parameters only included when explicitly specified
- DynamoDB-specific configurations mapped correctly
- SQS-specific configurations mapped correctly
- Shared configurations (batch size, retry, filtering) work for both types
- Multiple events per function create multiple unique resources

### Outputs and IAM Integration

#### Task Group 4: Module Outputs and IAM Permission Generation
**Dependencies:** Task Groups 1, 2, 3

- [ ] 4.0 Complete module outputs and IAM integration
  - [ ] 4.1 Write 2-8 focused tests for outputs and IAM permissions
    - Limit to 2-8 highly focused tests maximum
    - Test only critical output behaviors:
      - Output maps keyed by resource identifier (function_event_type_index)
      - Event source mapping IDs outputted correctly
      - Event source mapping ARNs outputted correctly
      - Empty maps when no event sources defined
      - IAM permission statements generated for DynamoDB streams
      - IAM permission statements generated for SQS queues
      - Permissions scoped to specific resource ARNs
    - Verify output structure and content
    - Skip exhaustive permission combination testing
  - [ ] 4.2 Add event source mapping outputs to outputs.tf
    - Output `event_source_mapping_ids`: map of IDs keyed by resource identifier
    - Output `event_source_mapping_arns`: map of ARNs keyed by resource identifier
    - Output `event_source_mapping_states`: map of states keyed by resource identifier
    - Output `event_source_mapping_count`: total count of mappings created
    - Use `for` expressions to build maps from resources
    - Handle empty case gracefully (return empty map when no mappings)
    - Pattern: `{ for k, v in aws_lambda_event_source_mapping.stream : k => v.id }`
  - [ ] 4.3 Generate IAM policy statements for DynamoDB streams
    - Create local value `dynamodb_stream_permissions` in locals.tf
    - Generate policy statements with actions: GetRecords, GetShardIterator, DescribeStream, ListStreams
    - Scope to specific stream ARN from event configuration (no wildcards)
    - Format as list of policy statement objects for IAM module consumption
    - Structure: `{ Effect = "Allow", Action = [...], Resource = [...] }`
    - Follow Serverless Framework permission patterns from research in 3.3
  - [ ] 4.4 Generate IAM policy statements for SQS queues
    - Create local value `sqs_queue_permissions` in locals.tf
    - Generate policy statements with actions: ReceiveMessage, DeleteMessage, GetQueueAttributes
    - Scope to specific queue ARN from event configuration (no wildcards)
    - Format as list of policy statement objects for IAM module consumption
    - Structure: `{ Effect = "Allow", Action = [...], Resource = [...] }`
    - Follow Serverless Framework permission patterns from research in 3.3
  - [ ] 4.5 Add IAM permission outputs to outputs.tf
    - Output `event_source_iam_permissions`: combined list of DynamoDB and SQS permissions
    - Concatenate `local.dynamodb_stream_permissions` and `local.sqs_queue_permissions`
    - Format for integration with roadmap item #3 (IAM Role & Policy Management)
    - Return empty list when no event sources defined
    - Add documentation describing integration with IAM module
  - [ ] 4.6 Update module documentation
    - Document all outputs in README.md or outputs.tf description fields
    - Document IAM permission auto-generation behavior
    - Document integration points with core module and Lambda module
    - Document resource naming conventions
    - Provide example usage snippets
  - [ ] 4.7 Ensure output and IAM tests pass
    - Run ONLY the 2-8 tests written in 4.1
    - Verify output maps have correct structure
    - Verify IAM permissions generated correctly
    - Verify empty event sources handled gracefully
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.1 pass
- Event source mapping IDs, ARNs, and states output as maps
- Total mapping count output correctly
- Empty maps returned when no event sources defined
- IAM policy statements generated for DynamoDB stream permissions
- IAM policy statements generated for SQS queue permissions
- Permissions scoped to specific resource ARNs (no wildcards)
- IAM outputs formatted for integration with IAM module
- Module documentation updated with outputs and IAM behavior

### End-to-End Testing and Documentation

#### Task Group 5: Integration Testing and Examples
**Dependencies:** Task Groups 1, 2, 3, 4

- [ ] 5.0 Complete end-to-end integration testing
  - [ ] 5.1 Review all existing tests from Task Groups 1-4
    - Review the 2-8 tests written by event-detection-engineer (Task 1.1)
    - Review the 2-8 tests written by validation-engineer (Task 2.1)
    - Review the 2-8 tests written by resource-engineer (Task 3.1)
    - Review the 2-8 tests written by output-engineer (Task 4.1)
    - Total existing tests: approximately 8-32 tests
  - [ ] 5.2 Analyze test coverage gaps for THIS feature only
    - Identify critical end-to-end workflows that lack test coverage
    - Focus ONLY on gaps related to DynamoDB & SQS event sources feature
    - Do NOT assess entire application test coverage
    - Prioritize integration scenarios:
      - Complete DynamoDB stream event workflow (parse -> validate -> resource -> IAM)
      - Complete SQS queue event workflow (parse -> validate -> resource -> IAM)
      - Functions with both DynamoDB and SQS events
      - Functions with multiple events of same type
      - Mixed configurations (valid and invalid) error handling
    - Skip: edge cases, performance tests, accessibility tests
  - [ ] 5.3 Write up to 10 additional strategic tests maximum
    - Add maximum of 10 new tests to fill identified critical gaps
    - Focus on end-to-end integration workflows
    - Test complete feature pipeline: event detection -> validation -> resource creation -> outputs
    - Create comprehensive test fixtures demonstrating real-world scenarios
    - Test Serverless Framework v2.x, v3.x, and v4.x compatibility
    - Do NOT write comprehensive coverage for all parameter combinations
    - Skip: exhaustive validation permutations, error message formatting edge cases
  - [ ] 5.4 Run feature-specific tests only
    - Run ONLY tests related to DynamoDB & SQS event sources feature
    - Tests from 1.1, 2.1, 3.1, 4.1, and 5.3
    - Expected total: approximately 18-42 tests maximum
    - Do NOT run the entire application test suite
    - Verify all critical workflows pass
    - Use: `terraform test -filter=event_source` or similar filtering
  - [ ] 5.5 Create integration examples
    - Add example serverless.yml with DynamoDB stream events to examples/ directory
    - Add example serverless.yml with SQS queue events to examples/ directory
    - Add example with mixed event types (stream + sqs + http)
    - Document expected Terraform plan output for each example
    - Demonstrate queue type detection (standard vs FIFO)
  - [ ] 5.6 Verify integration with existing modules
    - Verify consumption of `local.functions_with_defaults` from core module
    - Verify Lambda function ARN references work (when roadmap #2 implemented)
    - Verify validation errors integrate with core module validation framework
    - Verify IAM permission outputs ready for IAM module integration (roadmap #3)
    - Test with real serverless.yml fixtures from examples/
  - [ ] 5.7 Document Serverless Framework compatibility
    - Document v2.x, v3.x, and v4.x schema support
    - Document field name mappings (camelCase in YAML -> snake_case in Terraform)
    - Document default value behavior matching Serverless Framework
    - Document any known limitations or differences from Serverless Framework
    - Reference Serverless Framework documentation for event configuration

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 18-42 tests total)
- Critical end-to-end workflows covered by integration tests
- No more than 10 additional tests added when filling gaps
- Integration examples demonstrate real-world usage
- Serverless Framework v2.x, v3.x, and v4.x compatibility verified
- Integration with core module, Lambda module, and IAM module verified
- Documentation complete and accurate

## Execution Order

Recommended implementation sequence:
1. Event Source Detection and Flattening (Task Group 1) - Foundation for all other work
2. Validation Logic (Task Group 2) - Ensures data quality before resource creation
3. Event Source Mapping Resources (Task Group 3) - Core AWS resource generation
4. Outputs and IAM Integration (Task Group 4) - Module interface and permission management
5. End-to-End Testing and Documentation (Task Group 5) - Integration verification and examples

## Important Notes

### Testing Strategy
- Each task group (1-4) writes 2-8 focused tests covering ONLY critical behaviors
- Task group 5 adds maximum 10 strategic tests to fill integration gaps
- Total expected tests: approximately 18-42 tests for entire feature
- Run only feature-specific tests during development, not entire suite
- Use Terraform native test framework (.tftest.hcl files)

### Integration Points
- **Consumes from Core Module**: `functions_with_defaults`, `service_name`, `provider_with_defaults`, `parsed_config.resources`
- **Consumes from Lambda Module**: Function ARNs (via roadmap item #2)
- **Provides to IAM Module**: IAM policy statements (for roadmap item #3)
- **Validation Framework**: Integrates with core module validation error collection pattern

### Terraform Patterns to Follow
- **Error Collection**: Use `concat()` with conditional ternary expressions
- **Default Application**: Use `coalesce(try(field, null), default)` pattern
- **Validation**: Use precondition lifecycle blocks in null_resource
- **Iteration**: Use `for_each` with flattened maps for resource creation
- **Optional Fields**: Use `try()` and dynamic blocks for conditional configurations

### Serverless Framework Compatibility
- Support v2.x, v3.x, and v4.x schemas (roadmap item #13 already includes v4.x)
- Match default values exactly: DynamoDB batch_size=100, SQS batch_size=10, starting_position=TRIM_HORIZON
- Handle both explicit `type` field and inferred type from ARN patterns
- Support all documented event configuration options

### Resource Naming Convention
- Resource identifier format: `{function_key}_{event_type}_{event_index}`
- Event types: `stream` for DynamoDB, `sqs` for SQS
- Event index: 0-based position in events array (increments across all events)
- Example: `myFunction_stream_0`, `myFunction_sqs_1`

### Out of Scope
- Kinesis Stream event sources (different feature)
- MSK and self-managed Kafka event sources
- AT_TIMESTAMP starting position (reserved for future)
- Lambda permissions resources (not required for DynamoDB/SQS)
- Cross-account event sources
- Event source ARN data lookups (future enhancement)
- DynamoDB table/stream creation (roadmap item #9)
- SQS queue creation (roadmap item #9)
