# Task Breakdown: EventBridge Rules & Schedulers

## Overview
Total Tasks: 28 across 4 task groups

This feature translates Serverless Framework `schedule` and `eventBridge` event definitions into AWS CloudWatch Event Rules and targets, supporting cron/rate expressions and custom event patterns for automated Lambda function invocation.

## Task List

### Event Parsing & Data Structures

#### Task Group 1: Event Flattening Logic
**Dependencies:** Roadmap items #1 (Core Module) and #2 (Lambda Translation)

**Specialist:** terraform-infrastructure-engineer

- [ ] 1.0 Complete event parsing and flattening logic
  - [ ] 1.1 Write 2-8 focused tests for event parsing logic
    - Test schedule event flattening (string syntax: `schedule: rate(5 minutes)`)
    - Test schedule event flattening (object syntax: `schedule: { rate: cron(...), enabled: false }`)
    - Test eventBridge event flattening with pattern and eventBus
    - Test multiple events per function with correct indexing
    - Test function with no events returns empty map
    - Test mixed event types (schedule and eventBridge) on same function
    - Limit to 6-8 highly focused tests maximum
  - [ ] 1.2 Create local value for schedule event flattening
    - Add to `locals.tf` in module root
    - Flatten `schedule` events from `var.functions_with_defaults`
    - Handle both string syntax (`schedule: "rate(5 minutes)"`) and object syntax (`schedule: { rate: ..., enabled: ... }`)
    - Extract fields: function_name, event_index, schedule_expression, enabled, description, input, inputPath, inputTransformer
    - Use `try()` for optional fields with proper defaults (enabled=true, eventBus="default")
    - Create unique event_key: `"${func_name}-schedule-${event_idx}"`
  - [ ] 1.3 Create local value for eventBridge event flattening
    - Add to `locals.tf` in module root
    - Flatten `eventBridge` events from `var.functions_with_defaults`
    - Extract fields: function_name, event_index, pattern, eventBus, enabled, description, input, inputPath, inputTransformer
    - Default eventBus to "default" if not specified
    - Create unique event_key: `"${func_name}-eventbridge-${event_idx}"`
  - [ ] 1.4 Create event map local values for for_each iteration
    - Transform `all_schedule_events` list into `schedule_event_map` keyed by event_key
    - Transform `all_eventbridge_events` list into `eventbridge_event_map` keyed by event_key
    - Ensure keys are unique across all functions
    - Pattern: `{ for event in local.all_schedule_events : event.event_key => event }`
  - [ ] 1.5 Add comments documenting event flattening logic
    - Explain why flattening is necessary (Terraform for_each requirement)
    - Document string vs object syntax handling for schedule events
    - Document event_key format and uniqueness guarantees
    - Add example event structure in comments
  - [ ] 1.6 Ensure event parsing tests pass
    - Run ONLY the 6-8 tests written in 1.1
    - Verify flattened event maps have correct structure
    - Verify unique event_key generation
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 6-8 tests written in 1.1 pass
- Schedule events correctly parsed from both string and object syntax
- EventBridge events correctly parsed with pattern and eventBus
- Unique event_key generated for each event
- Event maps ready for for_each iteration in resources
- Functions with no events result in empty maps (no errors)

---

### CloudWatch Event Rules

#### Task Group 2: Event Rule Resources
**Dependencies:** Task Group 1

**Specialist:** terraform-infrastructure-engineer

- [ ] 2.0 Complete CloudWatch Event Rule resources
  - [ ] 2.1 Write 2-8 focused tests for Event Rule resources
    - Test schedule rule creation with rate expression
    - Test schedule rule creation with cron expression
    - Test eventBridge rule creation with event pattern
    - Test rule state mapping (enabled: true → ENABLED, enabled: false → DISABLED)
    - Test custom event bus name in eventBridge rules
    - Test rule naming format: `{service}-{stage}-{function}-{type}-{index}`
    - Limit to 6-8 highly focused tests maximum
  - [ ] 2.2 Create aws_cloudwatch_event_rule resource for schedule events
    - Add to `eventbridge.tf` (create new file)
    - Use `for_each = local.schedule_event_map`
    - Set `name` following pattern: `"${var.service_name}-${var.stage}-${each.value.function_name}-schedule-${each.value.event_index}"`
    - Set `schedule_expression = each.value.schedule_expression`
    - Set `state = each.value.enabled ? "ENABLED" : "DISABLED"`
    - Set `description = each.value.description` (can be null)
    - Ensure name length stays under 64 characters
  - [ ] 2.3 Create aws_cloudwatch_event_rule resource for eventBridge events
    - Add to `eventbridge.tf`
    - Use `for_each = local.eventbridge_event_map`
    - Set `name` following pattern: `"${var.service_name}-${var.stage}-${each.value.function_name}-eventbridge-${each.value.event_index}"`
    - Set `event_bus_name = each.value.eventBus` (defaults to "default")
    - Set `event_pattern = jsonencode(each.value.pattern)`
    - Set `state = each.value.enabled ? "ENABLED" : "DISABLED"`
    - Set `description = each.value.description` (can be null)
  - [ ] 2.4 Add input validation for schedule expressions
    - Validate rate expressions match format: `rate(value unit)`
    - Validate cron expressions have 6 fields
    - Add validation blocks or rely on Terraform plan-time validation
    - Document expected formats in comments
  - [ ] 2.5 Add comments documenting rule resources
    - Explain schedule_expression vs event_pattern distinction
    - Document state values (ENABLED/DISABLED)
    - Note that event_pattern must be valid JSON
    - Reference AWS CloudWatch Events documentation for expression formats
  - [ ] 2.6 Ensure Event Rule tests pass
    - Run ONLY the 6-8 tests written in 2.1
    - Verify terraform plan shows correct number of rules
    - Verify rule names follow naming convention
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 6-8 tests written in 2.1 pass
- Schedule rules created with rate/cron expressions
- EventBridge rules created with JSON event patterns
- Rule state correctly maps enabled field to ENABLED/DISABLED
- Custom event buses referenced correctly
- Rule names follow naming convention and are under 64 chars
- Terraform plan succeeds without errors

---

### Event Targets & Permissions

#### Task Group 3: Lambda Integration Resources
**Dependencies:** Task Group 2, Roadmap item #2 (Lambda function ARNs)

**Specialist:** terraform-infrastructure-engineer

- [ ] 3.0 Complete Event Target and Lambda Permission resources
  - [ ] 3.1 Write 2-8 focused tests for targets and permissions
    - Test event target linking schedule rule to Lambda function
    - Test event target linking eventBridge rule to Lambda function
    - Test Lambda permission with correct principal (events.amazonaws.com)
    - Test Lambda permission source_arn references rule ARN
    - Test input transformation: static input JSON
    - Test input transformation: inputPath JSONPath expression
    - Test input transformation: inputTransformer with inputPathsMap and inputTemplate
    - Limit to 7-8 highly focused tests maximum
  - [ ] 3.2 Create aws_cloudwatch_event_target for schedule events
    - Add to `eventbridge.tf`
    - Use `for_each = local.schedule_event_map`
    - Set `rule = aws_cloudwatch_event_rule.schedule[each.key].name`
    - Set `target_id = each.key`
    - Set `arn = var.lambda_function_arns[each.value.function_name]`
    - Reference Lambda function ARN from roadmap item #2 output
  - [ ] 3.3 Create aws_cloudwatch_event_target for eventBridge events
    - Add to `eventbridge.tf`
    - Use `for_each = local.eventbridge_event_map`
    - Set `rule = aws_cloudwatch_event_rule.eventbridge[each.key].name`
    - Set `target_id = each.key`
    - Set `arn = var.lambda_function_arns[each.value.function_name]`
    - Reference Lambda function ARN from roadmap item #2 output
  - [ ] 3.4 Add input transformation support to event targets
    - For static input: Set `input = jsonencode(each.value.input)` when input is present
    - For inputPath: Set `input_path = each.value.inputPath` when present
    - For inputTransformer: Add dynamic `input_transformer` block
      - Set `input_paths = each.value.inputTransformer.inputPathsMap`
      - Set `input_template = each.value.inputTransformer.inputTemplate`
    - Use dynamic blocks to conditionally include transformation
  - [ ] 3.5 Create aws_lambda_permission for schedule events
    - Add to `eventbridge.tf`
    - Use `for_each = local.schedule_event_map`
    - Set `statement_id = "${var.service_name}-${var.stage}-${each.value.function_name}-eventbridge-${each.value.event_index}"`
    - Set `action = "lambda:InvokeFunction"`
    - Set `function_name = var.lambda_function_names[each.value.function_name]`
    - Set `principal = "events.amazonaws.com"`
    - Set `source_arn = aws_cloudwatch_event_rule.schedule[each.key].arn`
  - [ ] 3.6 Create aws_lambda_permission for eventBridge events
    - Add to `eventbridge.tf`
    - Use `for_each = local.eventbridge_event_map`
    - Set `statement_id = "${var.service_name}-${var.stage}-${each.value.function_name}-eventbridge-${each.value.event_index}"`
    - Set `action = "lambda:InvokeFunction"`
    - Set `function_name = var.lambda_function_names[each.value.function_name]`
    - Set `principal = "events.amazonaws.com"`
    - Set `source_arn = aws_cloudwatch_event_rule.eventbridge[each.key].arn`
  - [ ] 3.7 Add comments documenting target and permission resources
    - Explain target_id purpose (unique identifier for target)
    - Document input transformation options (input, inputPath, inputTransformer)
    - Note Lambda permission scoping to specific rule ARN for security
    - Document principal value (events.amazonaws.com)
  - [ ] 3.8 Ensure target and permission tests pass
    - Run ONLY the 7-8 tests written in 3.1
    - Verify event targets reference correct Lambda ARNs
    - Verify Lambda permissions have correct principals and source ARNs
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 7-8 tests written in 3.1 pass
- Event targets link rules to Lambda functions correctly
- Lambda permissions grant EventBridge invoke access
- Permissions scoped to specific rule ARNs (not wildcards)
- Input transformation configurations work (input, inputPath, inputTransformer)
- Terraform plan shows correct resource dependencies
- Implicit dependencies prevent resource ordering issues

---

### Testing & Integration

#### Task Group 4: Module Outputs and Integration Testing
**Dependencies:** Task Groups 1-3

**Specialist:** terraform-test-engineer

- [ ] 4.0 Complete module outputs and comprehensive testing
  - [ ] 4.1 Review existing tests from Task Groups 1-3
    - Review 6-8 tests from Task 1.1 (event parsing)
    - Review 6-8 tests from Task 2.1 (event rules)
    - Review 7-8 tests from Task 3.1 (targets and permissions)
    - Total existing tests: approximately 19-24 tests
  - [ ] 4.2 Add module output definitions
    - Add to `outputs.tf`
    - Output `eventbridge_rule_arns`: Map of event_key to rule ARN
    - Output `eventbridge_rule_names`: Map of event_key to rule name
    - Include both schedule and eventBridge rules in outputs
    - Add descriptions to output definitions
  - [ ] 4.3 Analyze test coverage gaps for EventBridge feature
    - Identify critical workflows missing test coverage
    - Focus on integration points between rules, targets, and Lambda
    - Focus on end-to-end scenarios (event triggers Lambda invocation)
    - Do NOT assess entire Terraform module test coverage
    - Prioritize integration tests over additional unit tests
  - [ ] 4.4 Write up to 10 additional strategic tests maximum
    - Integration test: Single function with rate expression triggers Lambda
    - Integration test: Single function with cron expression triggers Lambda
    - Integration test: EventBridge rule with pattern matches and triggers Lambda
    - Integration test: Multiple events on one function create multiple rules
    - Integration test: Disabled rule does not trigger invocations
    - Integration test: Input transformation delivers correct payload to Lambda
    - Edge case test: Function with no events creates no resources
    - Edge case test: Invalid schedule expression fails at plan time
    - Edge case test: Multiple functions with same schedule work independently
    - Validation test: Rule names under 64 character limit
    - Add maximum of 10 new tests to fill critical gaps
  - [ ] 4.5 Create comprehensive example configuration
    - Create `examples/eventbridge/serverless.yml` with:
      - Simple rate expression example
      - Cron expression with description
      - EventBridge with custom pattern
      - Multiple events per function
      - Input transformation examples
      - Disabled rule example
    - Create `examples/eventbridge/main.tf` that references the module
    - Create `examples/eventbridge/README.md` documenting the examples
  - [ ] 4.6 Run feature-specific tests only
    - Run tests from tasks 1.1, 2.1, 3.1, and 4.4
    - Expected total: approximately 29-34 tests maximum
    - Verify critical EventBridge workflows pass
    - Verify integration with Lambda module (roadmap #2)
    - Do NOT run entire Terraform module test suite
  - [ ] 4.7 Perform manual verification (if possible)
    - Run `terraform plan` on examples/eventbridge configuration
    - Verify resource counts match expected (rules, targets, permissions)
    - Optionally run `terraform apply` to create resources in test AWS account
    - Verify schedule triggers Lambda invocation in CloudWatch Logs
    - Verify disabled rules do not trigger invocations
    - Run `terraform destroy` to clean up test resources

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 29-34 tests total)
- Module outputs provide rule ARNs and names
- Critical EventBridge workflows validated end-to-end
- No more than 10 additional tests added when filling gaps
- Example configurations demonstrate all feature capabilities
- Terraform plan/apply succeed with example configurations
- Manual verification confirms Lambda invocations work
- Testing focused exclusively on EventBridge feature

---

## Execution Order

Recommended implementation sequence:

1. **Event Parsing & Data Structures** (Task Group 1)
   - Foundation for all other work
   - Creates flattened event maps for resource iteration
   - No dependencies on AWS resources

2. **CloudWatch Event Rules** (Task Group 2)
   - Depends on Task Group 1 for event maps
   - Creates core EventBridge/CloudWatch Event resources
   - Required before targets can be created

3. **Event Targets & Permissions** (Task Group 3)
   - Depends on Task Group 2 for rule resources
   - Depends on Roadmap item #2 for Lambda function ARNs
   - Links rules to Lambda functions

4. **Testing & Integration** (Task Group 4)
   - Depends on Task Groups 1-3 being complete
   - Validates entire feature end-to-end
   - Fills any critical testing gaps

---

## Implementation Notes

### Key Technical Challenges

**Event Flattening Complexity:**
- Serverless Framework supports both string syntax (`schedule: "rate(5 minutes)"`) and object syntax (`schedule: { rate: "...", enabled: false }`)
- Must handle nested iteration (functions → events) and flatten to single map
- Must preserve function context and generate unique event keys
- Solution: Use nested `for` loops with `flatten()` and `try()` for optional fields

**Resource Dependency Management:**
- CloudWatch Event Rule must exist before Event Target
- Lambda Permission must reference Rule ARN (implicit dependency)
- Event Target depends on Lambda function existing
- Solution: Use Terraform implicit dependencies via attribute references (no explicit `depends_on` needed)

**Input Transformation Variations:**
- Three mutually exclusive options: `input`, `inputPath`, `inputTransformer`
- Must conditionally include the correct transformation in event target
- Solution: Use dynamic blocks with conditional logic based on which field is present

**Unique Resource Naming:**
- Must support multiple events per function without naming collisions
- Must keep rule names under 64 characters
- Must be consistent with Serverless Framework naming patterns
- Solution: Use `{service}-{stage}-{function}-{type}-{index}` pattern with event_index from original events array

### Terraform Best Practices

**Local Value Organization:**
- Keep all event flattening logic in `locals.tf`
- Use descriptive names: `all_schedule_events`, `schedule_event_map`
- Add comments explaining transformation logic
- Group related locals together (schedule events, eventBridge events)

**Resource Organization:**
- Keep all EventBridge-related resources in `eventbridge.tf`
- Group by resource type: rules, targets, permissions
- Use consistent for_each patterns across resources
- Add blank lines between resource types for readability

**Variable Consumption:**
- Consume `var.service_name` and `var.stage` from Core Module (roadmap #1)
- Consume `var.lambda_function_arns` and `var.lambda_function_names` from Lambda module (roadmap #2)
- Consume `var.functions_with_defaults` from Core Module for event parsing
- No new variables needed (all inputs come from existing modules)

**Output Design:**
- Provide rule ARNs for potential future use (monitoring, dashboards)
- Provide rule names for CloudWatch API operations
- Use descriptive output names with clear descriptions
- No downstream roadmap items depend on these outputs (EventBridge is terminal)

### Testing Strategy

**Unit Testing Focus:**
- Test event parsing logic with various input formats
- Test resource attribute mapping (schedule_expression, event_pattern, state)
- Test naming and indexing logic
- Keep tests fast and focused on single behaviors

**Integration Testing Focus:**
- Verify end-to-end flow: serverless.yml → Terraform resources → AWS resources
- Test rule triggers Lambda invocation (requires actual AWS deployment)
- Test input transformation delivers correct payload
- Test multiple events per function work independently

**Edge Case Coverage:**
- Functions with no events (should create no resources)
- Invalid schedule expressions (should fail at plan time)
- Event pattern size limits
- Rule name length limits
- Mixed event types on same function

### Code Quality Guidelines

**Formatting:**
- Run `terraform fmt` on all modified files before committing
- Use consistent indentation (2 spaces)
- Align attribute assignment with `=` operators
- Keep lines under 120 characters where possible

**Comments:**
- Add comments explaining complex logic (event flattening, indexing)
- Document schedule vs cron expression formats
- Explain input transformation options
- Reference AWS documentation for EventBridge concepts
- Keep comments evergreen (no temporary notes about changes)

**Naming:**
- Use snake_case for all Terraform identifiers
- Use descriptive names that reveal intent
- Avoid abbreviations except standard ones (arn, id)
- Prefix local values with context (schedule_event_map, not just events)

---

## Dependencies

**Required Roadmap Items:**
- Roadmap #1: Core Module
  - Provides: `service_name`, `stage`, `functions_with_defaults`
  - Must be implemented first
- Roadmap #2: Lambda Function Translation
  - Provides: `lambda_function_arns`, `lambda_function_names`
  - Must be implemented first

**External Dependencies:**
- Terraform 1.13.4+
- AWS Provider 6.0+
- AWS credentials with permissions for:
  - CloudWatch Events (create rules, targets)
  - Lambda (add permissions)
  - IAM (create permission policies)

**No Downstream Dependencies:**
- EventBridge is a terminal integration (no other roadmap items depend on it)
- Outputs provided for completeness but not required by other modules

---

## Success Metrics

**Functional Success:**
- All 29-34 feature tests pass
- Terraform plan succeeds with example configurations
- Terraform apply creates EventBridge rules, targets, and permissions
- Schedule expressions trigger Lambda invocations on expected schedule
- EventBridge patterns match events and trigger Lambda invocations
- Input transformations deliver correct payloads to Lambda functions

**Code Quality Success:**
- All Terraform files pass `terraform fmt` check
- Event flattening logic is clear and well-commented
- Resource naming follows consistent patterns
- No hardcoded values (use variables and outputs)
- Minimal code duplication between schedule and eventBridge resources

**Integration Success:**
- Module consumes Lambda ARNs from roadmap item #2 without issues
- Module consumes service/stage from roadmap item #1 correctly
- No modifications to existing Lambda or Core modules required
- Event rules integrate seamlessly with existing Lambda functions

**Documentation Success:**
- Example configurations demonstrate all features
- README explains how to use schedule and eventBridge events
- Comments explain complex logic and design decisions
- Output descriptions clearly state what each output provides
