# Specification: EventBridge Rules & Schedulers

## Goal

Translate Serverless Framework `schedule` and `eventBridge` event definitions into AWS CloudWatch Event Rules and targets, supporting cron/rate expressions and custom event patterns for automated Lambda function invocation.

## User Stories

- As a developer, I want my Serverless schedule events to automatically create CloudWatch Event Rules so that my Lambda functions execute on defined schedules
- As a platform engineer, I want eventBridge configurations to translate to event rules with custom patterns so that functions respond to AWS service events
- As a DevOps engineer, I want proper Lambda permissions automatically created so that EventBridge can invoke my functions without manual IAM configuration
- As a migration architect, I want rule naming to follow Serverless Framework conventions so that existing monitoring and CloudWatch dashboards continue to work
- As an operations engineer, I want support for both rate and cron expressions so that I maintain the same scheduling flexibility as the Serverless Framework

## Core Requirements

### Functional Requirements

**Event Type Support:**
- Parse `schedule` events from function definitions in serverless.yml
- Parse `eventBridge` events from function definitions in serverless.yml
- Support both event types on a single function (multiple event sources)
- Support multiple schedule/eventBridge events per function
- Gracefully handle functions without schedule or eventBridge events (no resources created)

**Schedule Event Properties:**
- `rate` expressions: `rate(X minutes|hours|days)` format
- `cron` expressions: Standard AWS cron format `cron(min hour day month weekday year)`
- Optional `enabled` field: Enable/disable the rule (default: true)
- Optional `description` field: Human-readable rule description
- Optional `input` field: Static JSON input to pass to Lambda
- Optional `inputPath` field: JSONPath to filter event data
- Optional `inputTransformer` field: Transform input before Lambda invocation

**EventBridge Event Properties:**
- `eventBus` field: Custom event bus name (default: "default")
- `pattern` field: Event pattern as JSON object for event matching
- `input` field: Static JSON input to pass to Lambda
- `inputPath` field: JSONPath to filter event data
- `inputTransformer` field: Input transformation configuration
- Optional `enabled` field: Enable/disable the rule (default: true)
- Optional `description` field: Human-readable rule description

**AWS Resource Generation:**
- Generate `aws_cloudwatch_event_rule` for each schedule/eventBridge event
- Generate `aws_cloudwatch_event_target` linking rule to Lambda function
- Generate `aws_lambda_permission` allowing EventBridge to invoke Lambda
- Use Terraform `for_each` to iterate over events per function
- Ensure unique resource names per rule across all functions

**Resource Naming Conventions:**
- Rule name pattern: `{service}-{stage}-{function_key}-{event_type}-{index}`
- Example schedule: `my-service-dev-processDaily-schedule-0`
- Example eventBridge: `my-service-dev-handleOrder-eventbridge-1`
- Permission statement ID: `{service}-{stage}-{function_key}-eventbridge-{index}`
- Index starts at 0 for each event type within a function

**Lambda Permission Configuration:**
- Principal: `events.amazonaws.com`
- Source ARN: Reference to the CloudWatch Event Rule ARN
- Action: `lambda:InvokeFunction`
- Function name: Reference to Lambda function from roadmap item #2

**Input Transformation Support:**
- Static `input`: Pass JSON string directly to Lambda event
- `inputPath`: JSONPath expression to extract specific event fields
- `inputTransformer`: Map input paths to custom input template
  - `inputPathsMap`: Map of path names to JSONPath expressions
  - `inputTemplate`: Template string with path name placeholders

**Rule State Management:**
- Default state: enabled (unless explicitly set to false)
- Disabled rules created but not triggered
- Map `enabled: false` to `state = "DISABLED"` in Terraform
- Map `enabled: true` or unspecified to `state = "ENABLED"`

### Module Integration

**Input from Previous Roadmap Items:**
- Core Module (#1): `service_name`, `provider_config.stage`, `functions_with_defaults`
- Lambda Translation (#2): `lambda_function_arns`, `lambda_function_names` outputs

**Event Detection Logic:**
Parse function definitions for events array and filter for schedule/eventBridge types:

```yaml
functions:
  myFunc:
    handler: handler.main
    events:
      - schedule: rate(5 minutes)
      - eventBridge:
          eventBus: custom-bus
          pattern:
            source:
              - aws.ec2
```

**Local Value Transformations:**
Create flattened map of all schedule and eventBridge events across all functions:

```hcl
locals {
  # Flatten schedule events with function context
  schedule_events = flatten([
    for func_name, func in var.functions : [
      for event_idx, event in try(func.events, []) : {
        function_name = func_name
        event_index   = event_idx
        schedule      = event.schedule
        enabled       = try(event.enabled, true)
        description   = try(event.description, null)
        input         = try(event.input, null)
        # ... other fields
      } if can(event.schedule)
    ]
  ])

  # Similar for eventBridge events
  eventbridge_events = flatten([...])
}
```

**Output Interface:**
- Output map of EventBridge rule ARNs: `{ rule_key = arn }`
- Output map of EventBridge rule names: `{ rule_key = name }`
- No outputs needed for downstream roadmap items (EventBridge is terminal integration)

### Technical Approach

**Schedule Expression Validation:**
- Rate expressions: Validate format `rate(value unit)` where value is integer and unit is `minute|minutes|hour|hours|day|days`
- Cron expressions: Validate AWS cron format (6 fields with wildcards and ranges supported)
- Pass expressions directly to `aws_cloudwatch_event_rule.schedule_expression`
- Terraform will validate during plan if expression is invalid

**Event Pattern Handling:**
- Accept event pattern as JSON object in serverless.yml
- Use `jsonencode()` to convert Terraform map to JSON string
- Set `aws_cloudwatch_event_rule.event_pattern` attribute
- Support complex patterns with multiple conditions and arrays

**Resource Dependency Management:**
- CloudWatch Event Rule must exist before Event Target
- Lambda Permission must reference Rule ARN (implicit dependency)
- Event Target depends on Lambda function existing (reference function ARN)
- Use Terraform implicit dependencies via attribute references

**Event Indexing Strategy:**
To support multiple events per function and ensure unique resource identifiers:

```hcl
locals {
  # Create unique key for each event
  schedule_event_map = {
    for idx, event in local.schedule_events :
    "${event.function_name}-schedule-${event.event_index}" => event
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  for_each = local.schedule_event_map

  name                = "${var.service_name}-${var.stage}-${each.value.function_name}-schedule-${each.value.event_index}"
  description         = each.value.description
  schedule_expression = each.value.schedule
  state              = each.value.enabled ? "ENABLED" : "DISABLED"
}
```

## Reusable Components

### Existing Code to Leverage

**From Core Module (Roadmap Item #1):**
- `functions_with_defaults` output: Function definitions with events array
- `service_name` output: For rule and permission naming
- `provider_config.stage` output: For resource naming
- Event parsing from YAML configuration (already handled by yamldecode)

**From Lambda Translation (Roadmap Item #2):**
- `lambda_function_arns` output: Required for event target and permission
- `lambda_function_names` output: Required for Lambda permission resource
- IAM role structure: EventBridge permissions may extend existing roles

**Terraform Patterns:**
- `flatten()` and `for` loops: Create flattened event lists from nested structure
- `for_each` with computed maps: Generate resources for each event
- `jsonencode()`: Convert event patterns to JSON
- `try()`: Safe access to optional event fields
- Dynamic blocks: Conditionally include input transformation

### New Components Required

**EventBridge Rule Resources:**
- `aws_cloudwatch_event_rule` for schedule events
- `aws_cloudwatch_event_rule` for eventBridge events
- Required because: Core scheduling and event-driven functionality

**Event Target Resources:**
- `aws_cloudwatch_event_target` linking rules to Lambda functions
- Support for input, inputPath, and inputTransformer configurations
- Required because: Rules need targets to invoke functions

**Lambda Permission Resources:**
- `aws_lambda_permission` granting EventBridge invoke permissions
- Scoped to specific rule ARNs for security
- Required because: Lambda functions deny invocation by default

**Event Flattening Logic:**
- Local values to flatten nested event structures into iteration-friendly maps
- Required because: Functions can have multiple events and Terraform needs flat structures for for_each

## Technical Constraints

**Terraform Compatibility:**
- Must work with Terraform 1.13.4+ (inherited from module #1)
- Must work with AWS provider 6.0+ (inherited from module #1)
- No additional provider dependencies required

**AWS Service Limits:**
- CloudWatch Event Rule name: 64 characters max
- Event pattern size: 2048 characters max (JSON string)
- Event targets per rule: 5 max (we use 1 per rule for simplicity)
- Rate expressions: minimum interval of 1 minute

**Serverless Framework Compatibility:**
- Support schedule syntax: string (rate/cron) or object with rate/cron property
- Support eventBridge object structure with pattern and eventBus
- Match framework defaults: enabled = true, eventBus = "default"

**Implementation Constraints:**
- Must not recreate Lambda functions (consume from roadmap item #2)
- Must handle functions with no events gracefully (empty for_each)
- Must support multiple events per function with unique naming
- Event pattern JSON must be valid against AWS EventBridge schema

## Out of Scope

### Excluded from This Feature

**CloudWatch Logs Event Sources:**
- Subscription filters for CloudWatch Logs
- Log group event triggers
- Not part of standard Serverless Framework schedule/eventBridge events
- Future enhancement if needed

**EventBridge Pipes:**
- AWS EventBridge Pipes for streaming integrations
- Not covered by Serverless Framework eventBridge syntax
- Future enhancement (separate roadmap item if needed)

**EventBridge Scheduler:**
- New AWS EventBridge Scheduler service (separate from CloudWatch Events)
- Not used by Serverless Framework (uses CloudWatch Events)
- Future consideration for enhanced scheduling features

**Dead Letter Queue Configuration:**
- DLQ configuration for failed event invocations
- Retry policies and error handling at rule level
- Future enhancement (not in standard Serverless syntax)

**Cross-Account Event Patterns:**
- Event patterns matching events from different AWS accounts
- Cross-account IAM permissions
- Advanced enterprise use case (future enhancement)

**Event Replay and Archive:**
- EventBridge event archive and replay features
- Not part of Serverless Framework configuration
- Future enhancement for disaster recovery scenarios

**Custom Event Bus Creation:**
- Provisioning custom event buses (not just referencing them)
- Event bus policies and permissions
- Deferred to roadmap item #9 (Custom Resource Provisioning)

**Input Transformation Advanced Features:**
- Complex JSONPath expressions beyond basic field extraction
- Nested transformations and conditional logic
- Will support basic inputTransformer but not all edge cases

**CloudWatch Event Rate Limiting:**
- Throttling and rate limiting configuration
- Not exposed in Serverless Framework configuration
- AWS default behavior applies

## Success Criteria

**Schedule Event Success:**
- Module generates `aws_cloudwatch_event_rule` for each schedule event
- Schedule expressions (rate and cron) correctly mapped to rule
- Rules created with correct enabled/disabled state
- Event targets link rules to correct Lambda functions
- Lambda permissions grant EventBridge invoke access

**EventBridge Event Success:**
- Module generates rules for eventBridge events with custom patterns
- Event patterns correctly encoded as JSON strings
- Custom event bus names referenced in rules
- Default event bus used when not specified
- Event pattern validation passes during Terraform plan

**Multiple Events Success:**
- Functions with multiple schedule/eventBridge events create multiple rules
- Each rule has unique name using function name and event index
- All events properly targeted to same Lambda function
- No naming collisions between events across functions

**Input Handling Success:**
- Static input JSON passed to event targets when configured
- InputPath JSONPath expressions correctly configured
- InputTransformer with inputPathsMap and inputTemplate working
- Functions receive expected event payload structure

**Lambda Permission Success:**
- One permission resource per rule created
- Permissions reference correct rule ARN as source
- Permission statement IDs unique and collision-free
- Lambda functions invocable by EventBridge

**Disabled Rule Success:**
- Rules with `enabled: false` created in DISABLED state
- Disabled rules do not trigger Lambda invocations
- Rules can be enabled later by updating configuration

**Integration Success:**
- Module consumes Lambda function ARNs from roadmap item #2
- No modification to existing Lambda resources required
- Event rules deploy successfully via terraform apply
- Scheduled Lambda invocations occur on expected schedule

**Error Handling Success:**
- Invalid schedule expressions fail during terraform plan with clear errors
- Invalid event patterns fail during terraform plan
- Missing Lambda function references cause dependency errors
- Terraform state accurately tracks rule and target resources

## Testing Requirements

**Valid Configuration Tests:**
- Parse single schedule event with rate expression
- Parse single schedule event with cron expression
- Parse eventBridge event with simple event pattern
- Parse eventBridge event with custom event bus
- Parse function with multiple schedule events
- Parse function with both schedule and eventBridge events
- Parse multiple functions each with schedule events

**Schedule Expression Tests:**
- Validate rate(5 minutes) format
- Validate rate(1 hour) format
- Validate rate(7 days) format
- Validate cron(0 12 * * ? *) format
- Validate cron with specific days and months

**Event Pattern Tests:**
- Simple source-based pattern (filter by AWS service)
- Complex pattern with detail-type and detail matching
- Pattern with arrays and multiple conditions
- Custom event bus with pattern

**Input Configuration Tests:**
- Static input JSON string to Lambda
- InputPath with JSONPath expression
- InputTransformer with inputPathsMap and inputTemplate
- No input configuration (default event structure)

**State Management Tests:**
- Default enabled state (enabled field not specified)
- Explicitly enabled rule (enabled: true)
- Disabled rule (enabled: false)
- Update rule from disabled to enabled

**Resource Naming Tests:**
- Unique rule names for multiple events per function
- Unique permission statement IDs
- Rule names under 64 character limit
- No collisions between functions with same event types

**Integration Tests:**
- Reference Lambda function ARNs from roadmap item #2
- Create rule, target, and permission resources
- Verify terraform plan shows correct resource counts
- Verify terraform apply creates AWS resources
- Verify scheduled Lambda invocation occurs
- Verify terraform destroy removes all resources

**Edge Cases:**
- Function with no events (no rules created)
- Function with only http events (no schedule rules)
- Empty schedule string or invalid format
- Event pattern exceeding size limit
- Multiple functions with same schedule expression

## Non-Functional Requirements

**Maintainability:**
- Clear separation between schedule and eventBridge logic
- Descriptive local value names for event maps
- Comments explaining event flattening and indexing
- Consistent resource naming patterns

**Extensibility:**
- Event flattening logic extensible to other event types
- Input transformation structure supports future enhancements
- Rule configuration supports additional AWS features
- Output interface can be extended for additional metadata

**Performance:**
- Event flattening completes during Terraform plan phase
- for_each iteration efficient for large event counts
- No unnecessary resource recreation on configuration updates
- Minimal API calls during plan (data sources avoided)

**Security:**
- Lambda permissions scoped to specific rule ARNs (not wildcard)
- Event patterns validated before deployment
- No plaintext secrets in event inputs (use environment variables)
- Principle of least privilege for EventBridge permissions

**Compatibility:**
- Works with existing Lambda module outputs (roadmap item #2)
- Event syntax matches Serverless Framework documentation
- AWS CloudWatch Events API compatibility maintained
- Backward compatible with future EventBridge enhancements

**Documentation:**
- Clear variable descriptions for event configuration
- Example serverless.yml with schedule and eventBridge events
- Comments explaining schedule vs cron expression formats
- Inline documentation for input transformation syntax

## Dependencies and Assumptions

**Dependencies:**
- Roadmap item #1: Core Module with YAML parsing and validation
- Roadmap item #2: Lambda Function Translation with function ARN outputs
- Terraform 1.13.4+ installed
- AWS provider 6.0+ configured
- AWS credentials with permissions for EventBridge and Lambda

**Assumptions:**
- Lambda functions already created by roadmap item #2
- Function ARNs available as module outputs for reference
- Users understand rate vs cron expression syntax
- Event patterns follow AWS EventBridge JSON schema
- Custom event buses already exist if referenced (not provisioned by this module)
- One event target per rule (not utilizing multi-target feature)
- EventBridge and CloudWatch Events API equivalency maintained by AWS

**Future Considerations:**
- Custom event bus provisioning may be added in roadmap item #9
- Advanced input transformations may require schema validation
- DLQ configuration could extend event target resources
- Event replay features may add archive configuration
- Cross-account permissions may require additional IAM resources

## Example Configurations

### Example 1: Simple Schedule Event (Rate Expression)

**Input (serverless.yml):**
```yaml
service: scheduled-service
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev

functions:
  processDaily:
    handler: handler.process
    events:
      - schedule: rate(1 day)
```

**Expected Terraform Resources:**
```hcl
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "scheduled-service-dev-processDaily-schedule-0"
  description         = null
  schedule_expression = "rate(1 day)"
  state              = "ENABLED"
}

resource "aws_cloudwatch_event_target" "schedule" {
  rule      = aws_cloudwatch_event_rule.schedule["processDaily-schedule-0"].name
  target_id = "processDaily-schedule-0"
  arn       = aws_lambda_function.functions["processDaily"].arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "scheduled-service-dev-processDaily-eventbridge-0"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions["processDaily"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule["processDaily-schedule-0"].arn
}
```

### Example 2: Cron Expression with Description

**Input (serverless.yml):**
```yaml
functions:
  backupDatabase:
    handler: backup.run
    events:
      - schedule:
          rate: cron(0 2 * * ? *)
          description: Daily database backup at 2 AM UTC
          enabled: true
```

**Expected Terraform Resources:**
```hcl
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "my-service-dev-backupDatabase-schedule-0"
  description         = "Daily database backup at 2 AM UTC"
  schedule_expression = "cron(0 2 * * ? *)"
  state              = "ENABLED"
}

# Event target and permission similar to Example 1
```

### Example 3: EventBridge with Custom Pattern

**Input (serverless.yml):**
```yaml
functions:
  handleEC2Events:
    handler: ec2.handler
    events:
      - eventBridge:
          pattern:
            source:
              - aws.ec2
            detail-type:
              - EC2 Instance State-change Notification
            detail:
              state:
                - running
```

**Expected Terraform Resources:**
```hcl
resource "aws_cloudwatch_event_rule" "eventbridge" {
  name         = "my-service-dev-handleEC2Events-eventbridge-0"
  event_bus_name = "default"
  event_pattern = jsonencode({
    source = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["running"]
    }
  })
  state = "ENABLED"
}

resource "aws_cloudwatch_event_target" "eventbridge" {
  rule      = aws_cloudwatch_event_rule.eventbridge["handleEC2Events-eventbridge-0"].name
  target_id = "handleEC2Events-eventbridge-0"
  arn       = aws_lambda_function.functions["handleEC2Events"].arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "my-service-dev-handleEC2Events-eventbridge-0"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions["handleEC2Events"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.eventbridge["handleEC2Events-eventbridge-0"].arn
}
```

### Example 4: Multiple Events per Function

**Input (serverless.yml):**
```yaml
functions:
  multiTrigger:
    handler: multi.handler
    events:
      - schedule: rate(5 minutes)
      - schedule: cron(0 * * * ? *)
      - eventBridge:
          eventBus: custom-bus
          pattern:
            source:
              - custom.app
```

**Expected Resources:**
- 3 CloudWatch Event Rules (multiTrigger-schedule-0, multiTrigger-schedule-1, multiTrigger-eventbridge-2)
- 3 Event Targets pointing to same Lambda function
- 3 Lambda Permissions with unique statement IDs

### Example 5: Input Transformation

**Input (serverless.yml):**
```yaml
functions:
  transform:
    handler: transform.handler
    events:
      - schedule:
          rate: rate(10 minutes)
          input:
            key: value
            timestamp: "scheduled-run"
```

**Expected Terraform Resources:**
```hcl
resource "aws_cloudwatch_event_target" "schedule" {
  rule      = aws_cloudwatch_event_rule.schedule["transform-schedule-0"].name
  target_id = "transform-schedule-0"
  arn       = aws_lambda_function.functions["transform"].arn

  input = jsonencode({
    key       = "value"
    timestamp = "scheduled-run"
  })
}
```

### Example 6: Disabled Rule

**Input (serverless.yml):**
```yaml
functions:
  maintenance:
    handler: maint.handler
    events:
      - schedule:
          rate: rate(1 hour)
          enabled: false
          description: Maintenance task (currently disabled)
```

**Expected Terraform Resources:**
```hcl
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "my-service-dev-maintenance-schedule-0"
  description         = "Maintenance task (currently disabled)"
  schedule_expression = "rate(1 hour)"
  state              = "DISABLED"
}

# Target and permission still created but rule won't trigger
```

## Implementation Notes

**Development Order:**
1. Add event parsing logic to locals.tf (flatten schedule and eventBridge events)
2. Create local value maps with unique keys for each event
3. Add aws_cloudwatch_event_rule resources for schedule events
4. Add aws_cloudwatch_event_rule resources for eventBridge events
5. Add aws_cloudwatch_event_target resources linking rules to Lambda functions
6. Add aws_lambda_permission resources for EventBridge invocation
7. Add outputs for rule ARNs and names
8. Test with single schedule event
9. Test with eventBridge pattern
10. Test with multiple events per function

**Key Implementation Challenges:**
- Flattening nested event structures while preserving function context and event index
- Creating unique resource keys for for_each iteration across multiple functions
- Supporting both schedule string syntax and object syntax from Serverless Framework
- Handling optional fields (description, input, enabled) with correct defaults
- Converting event pattern maps to JSON strings with jsonencode()
- Ensuring proper resource dependencies (rule before target, permission references rule)

**Event Flattening Pattern:**
```hcl
locals {
  # Flatten with comprehensive context
  all_schedule_events = flatten([
    for func_name, func in var.functions_with_defaults : [
      for event_idx, event in try(func.events, []) : {
        function_name    = func_name
        event_index      = event_idx
        event_key        = "${func_name}-schedule-${event_idx}"

        # Handle both string and object syntax
        schedule_expr    = try(event.schedule.rate, try(event.schedule.cron, event.schedule))
        enabled          = try(event.schedule.enabled, true)
        description      = try(event.schedule.description, null)
        input            = try(event.schedule.input, null)
      } if can(event.schedule) || can(event.schedule.rate) || can(event.schedule.cron)
    ]
  ])

  schedule_event_map = {
    for event in local.all_schedule_events :
    event.event_key => event
  }
}
```

**Resource Naming Best Practices:**
- Use consistent delimiter (hyphen) in all resource names
- Include service, stage, function name, event type, and index
- Ensure uniqueness across all functions and events
- Keep under AWS naming limits (64 characters for rules)
- Use same key format across rule, target, and permission

**Code Quality Guidelines:**
- Run terraform fmt on all modified files
- Add comments explaining event flattening logic
- Use descriptive local value names (schedule_events, not se)
- Keep resource blocks readable with consistent formatting
- Document schedule vs cron expression differences

**Testing Approach:**
- Create examples/eventbridge/ directory with comprehensive serverless.yml
- Include examples of rate, cron, eventBridge, multiple events
- Test terraform plan shows correct resource counts
- Test terraform apply creates AWS resources
- Manually verify scheduled Lambda invocation in CloudWatch Logs
- Test terraform destroy cleanup
- Verify event pattern matching with test events in EventBridge console

**Integration Points:**
- Consume lambda_function_arns from roadmap item #2 for event targets
- Consume lambda_function_names from roadmap item #2 for permissions
- Consume service_name and provider_config from roadmap item #1
- No dependencies on future roadmap items (terminal integration)

---

**This specification is ready for implementation.** Developers should reference the Lambda Function Translation module (roadmap item #2) for Lambda ARN outputs and the Core Module (roadmap item #1) for configuration parsing patterns.
