# Spec Requirements: DynamoDB & SQS Event Sources

## Initial Description
DynamoDB & SQS Event Sources - Create aws_lambda_event_source_mapping resources for DynamoDB streams and SQS queues from Serverless stream and sqs events, including batch size, starting position, and error handling configuration `S`

## Requirements Discussion

### First Round Questions

**Q1: Serverless Framework Version Scope**
Which Serverless Framework versions should we target for schema compatibility?

**Answer:** Reference official Serverless Framework documentation for v2.x, v3.x, AND v4.x. Also update the roadmap to add v4.x support.

**Q2: Resource Reference Validation**
When validating event source ARNs (DynamoDB streams and SQS queues), should we check if the resources exist in Terraform state, or just validate the ARN format?

**Answer:** Check both - resources defined in the same serverless.yml/ts file AND resources in the Terraform state.

**Q3: Batch Size Validation Ranges**
Should we use AWS Lambda's documented limits for batch size validation, or allow more permissive ranges?

**Answer:** Yes, use AWS Lambda's documented limits:
- DynamoDB Streams: 1-10000 records
- SQS standard queues: 1-10 messages
- SQS FIFO queues: 1-10000 messages

**Q4: Starting Position for DynamoDB**
Which starting positions should we support for DynamoDB streams?

**Answer:** Support both LATEST and TRIM_HORIZON (AT_TIMESTAMP reserved for future if needed).

**Q5: Error Handling Scope**
For error handling destinations, should we support only SNS/SQS, or also include EventBridge and Lambda destinations?

**Answer:** SNS and SQS is fine for now.

**Q6: IAM Permission Auto-Generation**
Should the module automatically generate IAM permissions for Lambda to read from DynamoDB streams and SQS queues?

**Answer:** Research what Serverless Framework does and copy that behavior.

**Q7: Exclusions**
Is there anything specifically we should NOT include in this feature?

**Answer:** (Derived from spec - see Out of Scope section)
- Kinesis Stream event sources
- MSK and self-managed Kafka event sources
- Event source ARN data lookups (initial implementation requires full ARN)
- Advanced filter pattern validation
- Cross-account event sources
- At-timestamp starting position (reserved for future)
- DynamoDB Global Table streams
- Kinesis-specific features

### Existing Code to Reference

**Similar Features Identified:**
Based on the roadmap and product context:
- Roadmap Item #1 (Core Module Structure & YAML Parsing): Validation framework and error collection patterns
- Roadmap Item #2 (Lambda Function Translation): Resource creation patterns using for_each iteration, function ARN outputs
- Roadmap Item #3 (IAM Role & Policy Management): May inform IAM permission generation approach

**Integration Points:**
- Consume `functions_with_defaults` from core module
- Consume `function_arns` and `function_names` from Lambda module
- Follow validation error collection pattern from core module
- Use consistent naming conventions with existing roadmap items

### Follow-up Questions

**Follow-up 1: Serverless Framework Schema Reference**
Should we reference official Serverless Framework documentation for v2.x, v3.x, AND v4.x?

**Answer:** Yes, reference official Serverless Framework documentation for v2.x, v3.x, AND v4.x. ALSO UPDATE THE ROADMAP to add v4.x support.

**Follow-up 2: Resource Reference Validation**
Should we check resources defined in the same serverless.yml/ts file AND resources in the Terraform state?

**Answer:** Check both - resources defined in the same serverless.yml/ts file AND resources in the Terraform state.

**Follow-up 3: Batch Size Validation Ranges**
Should we use AWS Lambda's documented limits?

**Answer:** Yes, use AWS Lambda's documented limits.

**Follow-up 4: Starting Position for DynamoDB**
Support both LATEST and TRIM_HORIZON?

**Answer:** Support both LATEST and TRIM_HORIZON.

**Follow-up 5: Error Handling Scope**
SNS and SQS for error handling destinations?

**Answer:** SNS and SQS is fine for now.

**Follow-up 6: IAM Permission Auto-Generation**
Research what Serverless Framework does and copy that behavior?

**Answer:** Research what Serverless Framework does and copy that behavior.

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
Not applicable - no visual files found.

## Requirements Summary

### Functional Requirements

**Core Event Source Mapping Functionality:**
- Generate aws_lambda_event_source_mapping resources for DynamoDB Streams
- Generate aws_lambda_event_source_mapping resources for SQS queues
- Parse events array from function definitions in functions_with_defaults
- Support functions with multiple event sources (multiple stream/sqs events)
- Support functions with no event sources (no mappings created)
- Use unique resource identifiers combining function key and event index

**DynamoDB Stream Configuration:**
- Map stream ARN from stream field
- Map starting position (LATEST or TRIM_HORIZON, default: TRIM_HORIZON)
- Map batch size (1-10000, default: 100)
- Map maximum batching window (0-300 seconds, optional)
- Map enabled flag (default: true)
- Map parallelization factor (1-10, optional)
- Map maximum record age (60-604800 seconds or -1, optional)
- Map maximum retry attempts (0-10000, optional)
- Map bisect batch on error flag (boolean, optional)
- Map tumbling window (0-900 seconds, optional)
- Map failure destination configuration for SNS/SQS (optional)
- Map filter criteria/patterns (optional)

**SQS Queue Configuration:**
- Map queue ARN from arn field
- Map batch size (1-10 for standard, 1-10000 for FIFO, default: 10)
- Map maximum batching window (0-300 seconds, optional)
- Map enabled flag (default: true)
- Map function response types (ReportBatchItemFailures, optional)
- Map scaling configuration maximum concurrency (2-1000, optional)
- Map filter criteria/patterns (optional)

**Event Type Detection:**
- Detect stream events by presence of stream field or type: stream
- Detect SQS events by ARN pattern (arn:aws:sqs:) or type: sqs
- Identify DynamoDB streams by ARN pattern: arn:aws:dynamodb:*:*:table/*/stream/*
- Identify SQS queues by ARN pattern: arn:aws:sqs:*:*:*
- Skip non-stream/non-sqs events (http, s3, schedule, eventBridge, etc.)

**Validation Requirements:**
- Validate batch size ranges based on event source type (DynamoDB vs SQS standard vs FIFO)
- Validate starting position is LATEST or TRIM_HORIZON
- Validate maximum retry attempts range: 0-10000
- Validate parallelization factor range: 1-10
- Validate maximum batching window range: 0-300
- Validate tumbling window range: 0-900
- Validate scaling config maximum concurrency range: 2-1000
- Validate ARN format matches event source type pattern
- Check that referenced resources exist in serverless.yml/ts or Terraform state
- Collect all validation errors and halt before resource creation

**IAM Permissions:**
- Research Serverless Framework's automatic IAM permission generation behavior
- Implement equivalent behavior for DynamoDB stream read permissions
- Implement equivalent behavior for SQS queue consume permissions
- Ensure permissions are properly scoped to specific resources

**Output Interface:**
- Output map of event source mapping IDs keyed by resource identifier
- Output map of event source mapping ARNs keyed by resource identifier
- Output map of event source mapping states keyed by resource identifier
- Output total count of event source mappings created
- Return empty maps when no event source mappings defined

### Reusability Opportunities

**Components from Roadmap Item #1 (Core Module):**
- Validation framework and error collection patterns
- Error reporting format and structure
- Default value application patterns using coalesce() and try()
- Service name and provider config outputs

**Components from Roadmap Item #2 (Lambda Module):**
- Function ARN output for event source mapping references
- Function names output for identification
- Resource creation patterns using for_each iteration
- Terraform implicit dependency patterns

**Terraform Built-in Functions to Leverage:**
- try() for safely accessing optional event configuration fields
- coalesce() for applying default values
- for_each for iterating over flattened event maps
- merge() for combining event configuration with function metadata
- flatten() for converting nested function/event structure to flat map
- jsonencode() for formatting filter patterns
- can() and regex() for ARN format validation and event type detection
- contains() for validating starting position values
- Dynamic blocks for conditional nested configurations

**Validation Patterns:**
- Reuse validation error collection pattern from roadmap item #1
- Use precondition lifecycle blocks for validation enforcement
- Maintain consistent error message formatting

### Scope Boundaries

**In Scope:**
- DynamoDB Stream event source mappings with all supported configurations
- SQS queue event source mappings with all supported configurations
- Batch size, starting position, retry logic, and error handling
- Filter criteria and patterns for both event types
- Scaling configuration for SQS
- Destination configuration for failure handling (SNS/SQS only)
- Default value application matching Serverless Framework defaults
- Validation of all configuration parameters against AWS limits
- Resource reference validation (serverless.yml/ts and Terraform state)
- IAM permission auto-generation following Serverless Framework behavior
- Support for Serverless Framework v2.x, v3.x, and v4.x schemas
- Multiple event sources per function
- Functions with no event sources (graceful handling)

**Out of Scope:**
- Kinesis Stream event sources (different configuration, not in roadmap description)
- MSK and self-managed Kafka event sources (advanced, not common)
- Lambda permissions resources (not required for DynamoDB/SQS event sources)
- Event source ARN data lookups via data sources (future enhancement)
- Advanced filter pattern validation (AWS validates at resource creation)
- Event source state management outside Terraform
- Cross-account event sources (requires additional IAM setup)
- At-timestamp starting position (reserved for future)
- DynamoDB Global Table streams (complex multi-region setup)
- Kinesis-specific features (enhanced fan-out, consumer ARN)
- EventBridge and Lambda error handling destinations (future enhancement)

### Technical Considerations

**Serverless Framework Compatibility:**
- Must support v2.x, v3.x, AND v4.x schema versions
- Event configuration must match Serverless Framework schema
- Default values must align with framework defaults (batch size 100 for DynamoDB, 10 for SQS, starting position TRIM_HORIZON, enabled true)
- Event detection must handle both explicit type field and inferred type from ARN

**AWS Provider Constraints:**
- DynamoDB Stream batch size: 1-10000 records
- SQS standard queue batch size: 1-10 messages
- SQS FIFO queue batch size: 1-10000 messages
- Maximum batching window: 0-300 seconds
- Starting position: LATEST or TRIM_HORIZON only
- Parallelization factor: 1-10 for DynamoDB Streams
- Maximum retry attempts: 0-10000 (or -1 for infinite with DynamoDB)
- Tumbling window: 0-900 seconds
- Scaling config maximum concurrency: 2-1000

**Terraform Compatibility:**
- Must work with Terraform 1.0.0+ (inherited from core module)
- Must work with AWS provider 6.0+ (inherited from core module)
- Must use native HCL functions (no external dependencies)
- Must maintain pure HCL implementation (no external scripts)

**Implementation Constraints:**
- Must not modify core module or Lambda module outputs
- Must use consistent naming patterns with roadmap items #1 and #2
- Must support functions with no events gracefully (empty maps create no resources)
- Must support multiple events per function
- Resource naming must avoid collisions (function-key-event-type-event-index pattern)

**Integration Requirements:**
- Consume functions_with_defaults from core module
- Consume function_arns from Lambda module
- Use Terraform implicit dependencies via function ARN references
- Ensure Lambda functions created before event source mappings
- Support conditional creation based on event existence

**Resource Reference Validation:**
- Check if DynamoDB tables/streams are defined in serverless.yml/ts resources section
- Check if SQS queues are defined in serverless.yml/ts resources section
- Check if resources exist in Terraform state
- Validate both explicit ARNs and resource name references

**IAM Permission Auto-Generation:**
- Research Serverless Framework documentation for automatic IAM permission behavior
- Generate equivalent permissions for DynamoDB stream read access
- Generate equivalent permissions for SQS queue consume access
- Ensure permissions are scoped to specific resource ARNs
- Integrate with roadmap item #3 (IAM Role & Policy Management)

### Roadmap Update Required

**Action Item:**
Update `/home/tom/p/t/sls.tf/agent-os/product/roadmap.md` to add Serverless Framework v4.x support:

Item #13 currently reads:
"Schema Synchronization Tooling - Develop automated tooling to generate Terraform validation code from the Serverless Framework JSON schema, ensuring validation rules stay synchronized with schema evolution across Framework versions 2.x, 3.x, and 4.x"

Confirm this already includes v4.x support. No additional roadmap changes needed as v4.x is already documented in item #13.
