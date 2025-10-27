# Task Breakdown: S3 Event Source Mapping

## Overview
**Roadmap Item:** #5 - S3 Event Source Integration
**Dependencies:**
- Roadmap item #1 (Core Module Structure & YAML Parsing)
- Roadmap item #2 (Lambda Function Translation)

**Total Tasks:** 5 task groups with 31 sub-tasks

## Task List

### Phase 1: S3 Event Parsing & Normalization

#### Task Group 1: Event Extraction and Syntax Normalization
**Dependencies:** Core Module (#1) and Lambda Translation (#2) complete
**Files Modified:** `locals.tf`

- [ ] 1.0 Complete S3 event extraction and normalization
  - [ ] 1.1 Write 2-8 focused tests for event parsing
    - Test shorthand syntax parsing (`- s3: bucketname`)
    - Test full object syntax parsing (bucket, event, rules, existing, forceDeploy)
    - Test mixed syntax in same serverless.yml
    - Test functions with no S3 events (graceful skip)
    - Test default event type application
    - Limit to core parsing behaviors only
  - [ ] 1.2 Add `s3_events_raw` local for initial extraction
    - Use `flatten()` to collect all S3 events from all functions
    - Extract from `functions[name].events` array where `event.s3` exists
    - Capture function name, event index, and s3_config for each event
    - Filter out null values (non-S3 events)
    - Follow pattern from spec lines 237-252
  - [ ] 1.3 Add `s3_events_normalized` local for syntax normalization
    - Normalize shorthand string syntax to consistent object format
    - Use `try()` to safely access optional fields
    - Extract bucket_key from either object.bucket or string value
    - Apply default event type `s3:ObjectCreated:*` when not specified
    - Preserve all fields: function_name, event_index, bucket_key, bucket_name, event_type, rules, existing, force_deploy
    - Follow pattern from spec lines 256-275
  - [ ] 1.4 Add `s3_buckets_custom_properties` local
    - Parse `provider.s3` section from parsed_config
    - Use `try(local.parsed_config.provider.s3, {})` with safe fallback
    - Store custom bucket configurations by bucket key
  - [ ] 1.5 Ensure event parsing tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify shorthand and object syntax both normalize correctly
    - Verify default values applied properly
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- Both shorthand and object syntax parse correctly
- All S3 events extracted from functions array
- Normalized events have consistent structure
- Default event type applied when not specified
- Functions without S3 events handled gracefully

---

### Phase 2: Bucket Management & Custom Properties

#### Task Group 2: Bucket Identification and Configuration
**Dependencies:** Task Group 1
**Files Modified:** `locals.tf`

- [ ] 2.0 Complete bucket identification and configuration logic
  - [ ] 2.1 Write 2-8 focused tests for bucket management
    - Test new bucket identification (existing: false)
    - Test existing bucket handling (existing: true)
    - Test custom bucket name resolution from provider.s3 section
    - Test bucket name fallback to bucket key
    - Test multiple functions sharing same bucket
    - Limit to critical bucket management scenarios
  - [ ] 2.2 Add `s3_buckets_to_create` local
    - Use `distinct()` to identify unique buckets needing creation
    - Filter for buckets where `existing: false` (default)
    - Create map keyed by bucket_key
    - Resolve bucket name from custom properties or use bucket_key
    - Store both name and custom properties for each bucket
    - Follow pattern from spec lines 279-296
  - [ ] 2.3 Integrate bucket name resolution
    - Update `s3_events_normalized` to resolve bucket_name from custom properties
    - Use `try(local.s3_buckets_custom_properties[bucket_key].name, bucket_key)` pattern
    - Ensure existing buckets and new buckets both resolve names correctly
  - [ ] 2.4 Ensure bucket management tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify new buckets identified correctly
    - Verify custom bucket names resolved from provider.s3
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- New buckets correctly identified for creation
- Existing buckets excluded from creation list
- Custom bucket names resolved from provider.s3 section
- Bucket key used as fallback name when no custom name

---

### Phase 3: Validation Logic

#### Task Group 3: S3 Event Configuration Validation
**Dependencies:** Task Groups 1-2
**Files Modified:** `locals.tf`

- [ ] 3.0 Complete S3 event validation logic
  - [ ] 3.1 Write 2-8 focused tests for validation
    - Test rejection of empty bucket name
    - Test rejection of invalid event type
    - Test rejection of forceDeploy without existing
    - Test rejection of bucket names violating S3 naming conventions
    - Test rejection of duplicate event configurations on same bucket
    - Limit to critical validation scenarios
  - [ ] 3.2 Add `s3_event_validations` local for configuration validation
    - Validate bucket name not empty
    - Validate event type is valid S3 notification event type
    - Use `contains()` with full list of valid event types (spec lines 388-394)
    - Validate forceDeploy only used with existing: true
    - Validate S3 bucket naming conventions using `can(regex())` pattern
    - Include function name and event index in all error messages
    - Follow pattern from spec lines 379-405
  - [ ] 3.3 Add `s3_duplicate_validations` local
    - Group events by bucket name using `s3_notifications_aggregated`
    - Detect duplicate configurations: same event type + same filter rules
    - Use hash pattern: `"${event_type}-${prefix}-${suffix}"`
    - Compare hash list length to distinct hash list length
    - Generate clear error message identifying the bucket
    - Follow pattern from spec lines 407-415
  - [ ] 3.4 Add `all_s3_validations` local
    - Combine `s3_event_validations` and `s3_duplicate_validations`
    - Use `concat()` to merge both validation arrays
    - Filter out null values from duplicate validations
  - [ ] 3.5 Integrate S3 validations into existing validation framework
    - Add `local.all_s3_validations` to existing `validation_errors` concat
    - Ensure S3 validations only run when `parsed_config != null`
    - Follow existing validation pattern from core module
    - Reference spec lines 429-437 for integration approach
  - [ ] 3.6 Ensure validation tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify all critical validation errors detected
    - Verify error messages include function name and event index
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- Empty bucket names rejected with clear error
- Invalid event types rejected with clear error
- forceDeploy without existing rejected with clear error
- S3 naming conventions enforced
- Duplicate event configurations detected and rejected
- All error messages include function name and event index

---

### Phase 4: Notification Aggregation & Resource Generation

#### Task Group 4: Notification Aggregation and Terraform Resources
**Dependencies:** Task Groups 1-3
**Files Modified:** `locals.tf`, `s3.tf` (new), `outputs.tf`

- [ ] 4.0 Complete notification aggregation and resource generation
  - [ ] 4.1 Write 2-8 focused tests for resources
    - Test S3 bucket creation for new buckets
    - Test Lambda permission creation
    - Test notification aggregation (multiple functions on same bucket)
    - Test filter rule transformation (prefix, suffix, both)
    - Test existing bucket reference (no bucket creation)
    - Limit to critical resource generation scenarios
  - [ ] 4.2 Add `s3_notifications_aggregated` local for notification grouping
    - Use `distinct()` to get unique bucket names
    - Group all S3 events by bucket_name
    - Create lambda_function configuration blocks for each event
    - Extract filter_prefix from rules array (first prefix found)
    - Extract filter_suffix from rules array (first suffix found)
    - Reference Lambda function ARNs: `aws_lambda_function.functions[function_name].arn`
    - Follow pattern from spec lines 299-319
  - [ ] 4.3 Create new `s3.tf` file with S3 bucket resources
    - Add file header comment: "# S3 Event Source Mapping Resources"
    - Create `aws_s3_bucket.event_buckets` resource
    - Use `for_each = local.s3_buckets_to_create`
    - Set bucket name from `each.value.name`
    - Follow pattern from spec lines 322-332
  - [ ] 4.4 Add Lambda permission resources to `s3.tf`
    - Create `aws_lambda_permission.s3_triggers` resource
    - Use `for_each` over normalized S3 events (keyed by "${function_name}-${bucket_name}")
    - Set statement_id: `"AllowExecutionFromS3-${bucket_name}"`
    - Set action: `"lambda:InvokeFunction"`
    - Set principal: `"s3.amazonaws.com"`
    - Set function_name from Lambda function resource reference
    - Set source_arn conditionally: existing bucket ARN vs. created bucket ARN
    - Follow pattern from spec lines 336-350
  - [ ] 4.5 Add S3 bucket notification resources to `s3.tf`
    - Create `aws_s3_bucket_notification.lambda_triggers` resource
    - Use `for_each = local.s3_notifications_aggregated`
    - Set bucket to `each.key` (bucket name)
    - Use dynamic `lambda_function` block for each notification
    - Set lambda_function_arn, events, filter_prefix, filter_suffix
    - Add `depends_on = [aws_lambda_permission.s3_triggers]`
    - Follow pattern from spec lines 354-373
  - [ ] 4.6 Add S3 outputs to `outputs.tf`
    - Add `s3_bucket_arns` output: map of bucket ARNs by bucket name
    - Add `s3_bucket_names` output: map of bucket names by bucket key
    - Add `s3_notification_ids` output: map of notification IDs by bucket name
    - Include descriptions for each output
    - Follow pattern from spec lines 227-230
  - [ ] 4.7 Run `terraform fmt` on all modified files
    - Format `locals.tf`
    - Format `s3.tf`
    - Format `outputs.tf`
    - Ensure consistent Terraform style
  - [ ] 4.8 Ensure resource generation tests pass
    - Run ONLY the 2-8 tests written in 4.1
    - Verify S3 buckets created for new bucket references
    - Verify Lambda permissions created with correct principals
    - Verify notifications aggregated correctly
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.1 pass
- S3 buckets created only for non-existing bucket references
- Lambda permissions created with s3.amazonaws.com principal
- Single notification resource per bucket with multiple lambda_function blocks
- Filter rules correctly transformed (prefix and suffix)
- Outputs expose bucket ARNs, names, and notification IDs
- All Terraform files properly formatted

---

### Phase 5: Integration Testing & Examples

#### Task Group 5: Example Configurations and Integration Testing
**Dependencies:** Task Groups 1-4
**Files Created:** `examples/s3-events/` directory and files

- [ ] 5.0 Complete integration testing and examples
  - [ ] 5.1 Review tests from Task Groups 1-4
    - Review the 2-8 tests written for event parsing (Task 1.1)
    - Review the 2-8 tests written for bucket management (Task 2.1)
    - Review the 2-8 tests written for validation (Task 3.1)
    - Review the 2-8 tests written for resource generation (Task 4.1)
    - Total existing tests: approximately 8-32 tests
  - [ ] 5.2 Analyze test coverage gaps for S3 feature only
    - Identify critical end-to-end workflows lacking coverage
    - Focus ONLY on gaps related to S3 event source mapping requirements
    - Do NOT assess entire application test coverage
    - Prioritize integration scenarios: shorthand + object syntax, multiple buckets, notification aggregation
  - [ ] 5.3 Write up to 10 additional strategic tests maximum
    - Add maximum of 10 new tests to fill identified critical gaps
    - Focus on end-to-end workflows and integration points
    - Test shorthand syntax example (Example 1 from spec)
    - Test full object syntax with filters (Example 2 from spec)
    - Test notification aggregation (Example 3 from spec)
    - Test existing bucket reference (Example 4 from spec)
    - Test custom bucket properties (Example 5 from spec)
    - Do NOT write comprehensive coverage for all edge cases
  - [ ] 5.4 Create example: shorthand syntax
    - Create `examples/s3-events/shorthand-syntax/`
    - Add `serverless.yml` with shorthand S3 event
    - Add minimal Lambda handler file
    - Add README explaining the example
    - Reference Example 1 from spec lines 797-846
  - [ ] 5.5 Create example: full object syntax with filters
    - Create `examples/s3-events/full-object-syntax/`
    - Add `serverless.yml` with full object S3 event configuration
    - Include event type, rules (prefix, suffix)
    - Add minimal Lambda handler file
    - Add README explaining filter behavior
    - Reference Example 2 from spec lines 848-905
  - [ ] 5.6 Create example: multiple functions on same bucket
    - Create `examples/s3-events/notification-aggregation/`
    - Add `serverless.yml` with multiple functions on same bucket
    - Different event types (ObjectCreated vs ObjectRemoved)
    - Add minimal Lambda handler files for each function
    - Add README explaining notification aggregation
    - Reference Example 3 from spec lines 907-977
  - [ ] 5.7 Create example: existing bucket reference
    - Create `examples/s3-events/existing-bucket/`
    - Add `serverless.yml` with existing: true and forceDeploy: true
    - Add README explaining existing bucket behavior
    - Add note about bucket must pre-exist
    - Reference Example 4 from spec lines 979-1030
  - [ ] 5.8 Create example: custom bucket properties
    - Create `examples/s3-events/custom-bucket-properties/`
    - Add `serverless.yml` with provider.s3 section
    - Include custom name and versioningConfiguration
    - Add README explaining custom properties
    - Reference Example 5 from spec lines 1032-1096
  - [ ] 5.9 Test each example with terraform plan
    - Navigate to each example directory
    - Run `terraform init`
    - Run `terraform plan`
    - Verify correct number of resources shown (buckets, permissions, notifications)
    - Verify no errors or warnings
  - [ ] 5.10 Run feature-specific tests only
    - Run ONLY tests related to S3 event source mapping (tests from 1.1, 2.1, 3.1, 4.1, and 5.3)
    - Expected total: approximately 18-42 tests maximum
    - Do NOT run entire application test suite
    - Verify all critical S3 workflows pass
  - [ ] 5.11 Document visual assets reference
    - Verify all four visual diagrams exist in `planning/visuals/`
    - Add note in main README or module documentation referencing diagrams
    - Ensure diagrams accurately reflect implemented behavior

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 18-42 tests total)
- Five complete examples created covering all syntax variations
- Each example runs `terraform plan` successfully
- Examples demonstrate shorthand, full object, aggregation, existing bucket, and custom properties
- Visual diagrams referenced in documentation
- No more than 10 additional tests added when filling testing gaps
- Testing focused exclusively on S3 event source mapping requirements

---

## Execution Order

Recommended implementation sequence:

1. **Phase 1: S3 Event Parsing & Normalization** (Task Group 1)
   - Extract S3 events from function definitions
   - Normalize shorthand and object syntax
   - Parse custom bucket properties

2. **Phase 2: Bucket Management & Custom Properties** (Task Group 2)
   - Identify buckets to create vs. reference
   - Resolve custom bucket names and properties

3. **Phase 3: Validation Logic** (Task Group 3)
   - Validate event configurations
   - Detect duplicate configurations
   - Integrate with existing validation framework

4. **Phase 4: Notification Aggregation & Resource Generation** (Task Group 4)
   - Aggregate notifications by bucket
   - Generate Terraform resources (buckets, permissions, notifications)
   - Add outputs

5. **Phase 5: Integration Testing & Examples** (Task Group 5)
   - Create comprehensive examples
   - Run integration tests
   - Verify end-to-end functionality

---

## Key Implementation Areas

### S3 Event Parsing (Phase 1)
- Extract S3 events from mixed event arrays
- Normalize shorthand string (`- s3: bucketname`) to object format
- Handle optional fields safely with `try()`
- Apply default event type when not specified

### Validation (Phase 3)
- Bucket name required validation
- Event type must be valid S3 notification event
- S3 naming convention validation (lowercase, 3-63 chars, etc.)
- forceDeploy requires existing: true
- Duplicate event configuration detection

### Notification Aggregation (Phase 4)
- Group events by bucket name using `distinct()`
- Create single `aws_s3_bucket_notification` per bucket
- Multiple `lambda_function` blocks within each notification
- AWS constraint: only one notification resource per bucket

### Resource Dependencies (Phase 4)
```
aws_lambda_function (from Lambda module)
  ↓
aws_s3_bucket (for new buckets only)
  ↓
aws_lambda_permission (S3 → Lambda)
  ↓
aws_s3_bucket_notification (aggregated)
```

### Filter Rule Transformation (Phase 4)
- Extract prefix from rules array: `[for rule in rules : rule.prefix if try(rule.prefix, null) != null][0]`
- Extract suffix from rules array: `[for rule in rules : rule.suffix if try(rule.suffix, null) != null][0]`
- No rules = no filters (all objects trigger)
- Both prefix and suffix create AND condition

---

## Testing Strategy

### Focused Testing Approach
- **Phase 1-4:** Each task group writes 2-8 tests covering critical behaviors only
- **Phase 5:** Up to 10 additional tests to fill strategic gaps
- **Total:** Approximately 18-42 tests maximum
- **Scope:** Test ONLY S3 event source mapping feature requirements

### Test Coverage Areas
1. **Parsing:** Shorthand vs. object syntax, default values
2. **Bucket Management:** New vs. existing buckets, custom properties
3. **Validation:** Required fields, event types, naming conventions, duplicates
4. **Resource Generation:** Buckets, permissions, notifications, aggregation
5. **Integration:** End-to-end examples with `terraform plan`

### Test Execution
- Run tests incrementally after each task group
- Run ONLY newly written tests, not entire suite
- Final test run includes all S3-related tests (18-42 total)

---

## File Organization

### Files Modified
- `locals.tf` - S3 event parsing, normalization, validation, aggregation
- `outputs.tf` - S3 bucket ARNs, names, notification IDs

### Files Created
- `s3.tf` - S3 buckets, Lambda permissions, bucket notifications
- `examples/s3-events/shorthand-syntax/` - Basic example
- `examples/s3-events/full-object-syntax/` - Advanced example with filters
- `examples/s3-events/notification-aggregation/` - Multiple functions example
- `examples/s3-events/existing-bucket/` - Existing bucket example
- `examples/s3-events/custom-bucket-properties/` - Custom properties example

### Visual Assets (Already Created)
- `planning/visuals/configuration-flow.md` - Parsing and normalization flow
- `planning/visuals/module-integration.md` - Integration with existing module
- `planning/visuals/notification-aggregation.md` - Aggregation pattern
- `planning/visuals/resource-dependencies.md` - Resource dependency graph

---

## Integration with Existing Module

### Consumes from Core Module (#1)
- `local.parsed_config` - Access functions and provider.s3
- `local.service_name` - For resource naming
- `local.provider_with_defaults` - For stage information
- `local.functions_with_defaults` - For event arrays

### Consumes from Lambda Module (#2)
- `aws_lambda_function.functions` - Lambda function resources
- Lambda function ARNs for notification configuration
- Function naming convention: `{service}-{stage}-{function}`

### Extends Core Module
- Adds S3 validations to `validation_errors` concat
- Follows existing validation error collection pattern
- Uses existing default application patterns (`try()`, `coalesce()`, `merge()`)

---

## Important Notes

### AWS Constraints
- Only ONE `aws_s3_bucket_notification` per bucket (must aggregate)
- S3 bucket names must be globally unique
- Lambda permissions required before notifications

### Serverless Framework Compatibility
- Must match exact behavior of Serverless Framework
- Default event type: `s3:ObjectCreated:*`
- Support both shorthand and full object syntax
- Notification aggregation follows AWS constraints

### Edge Cases
- Functions with no S3 events: Skip S3 processing
- Empty events array: No S3 resources created
- Multiple functions on same bucket: Aggregate into single notification
- Existing buckets: Reference only, do not create

### Code Quality
- Run `terraform fmt` on all .tf files
- Use descriptive local variable names
- Add comments explaining notification aggregation
- Follow Terraform naming conventions (snake_case)
- Include function name and event index in all validation errors
