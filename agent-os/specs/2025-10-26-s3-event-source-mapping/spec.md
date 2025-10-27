# Specification: S3 Event Source Mapping

## Overview

This specification defines the S3 Event Source Mapping capability for sls.tf, which extends the Lambda function translation module (roadmap item #2) by implementing S3 bucket notification configurations from Serverless Framework S3 event definitions. This module translates both shorthand and full object syntax S3 events into Terraform aws_s3_bucket, aws_s3_bucket_notification, and aws_lambda_permission resources with proper event type filtering, prefix/suffix pattern matching, notification aggregation per bucket, and support for both new and existing S3 buckets.

**Roadmap Position:** Item #5 - Event source integration for S3 triggers
**Dependencies:**
- Roadmap item #1 (Core Module Structure & YAML Parsing) - provides parsed configuration
- Roadmap item #2 (Lambda Function Translation) - provides Lambda function resources
**Target Completion:** Enable S3-triggered Lambda functions via Terraform from serverless.yml

## Goal

Transform Serverless Framework S3 event definitions into fully-configured S3 bucket notifications with Lambda permissions, supporting both shorthand and full object syntax, event type filtering, prefix/suffix rules, notification aggregation per bucket, and seamless integration with both new and existing S3 buckets.

## User Stories

- As a developer, I want my Serverless Framework S3 event definitions to automatically create S3 bucket notifications in AWS via Terraform so that my Lambda functions trigger on S3 object events without manual AWS console configuration
- As a platform engineer, I want S3 buckets to be automatically created when referenced in function events so that infrastructure deployment is fully automated without pre-existing bucket requirements
- As a migration architect, I want to attach Lambda functions to existing S3 buckets using the `existing: true` flag so that I can integrate with pre-existing infrastructure without recreating buckets
- As a developer, I want to filter S3 events by type (ObjectCreated, ObjectRemoved) and object key patterns (prefix/suffix) so that my functions only execute for relevant S3 operations
- As a DevOps engineer, I want multiple Lambda functions to subscribe to the same S3 bucket with different event configurations so that I can implement event-driven architectures with specialized handlers
- As an infrastructure team member, I want S3 event configurations to be aggregated into a single notification resource per bucket so that AWS constraints are automatically satisfied and conflicts are avoided

## Visual Design

Technical reference diagrams provided in `planning/visuals/`:

- **Configuration Flow** (`configuration-flow.md`): Illustrates parsing, normalization, validation, and resource generation for S3 events
- **Module Integration** (`module-integration.md`): Shows how S3 event logic integrates with existing core and Lambda modules
- **Notification Aggregation** (`notification-aggregation.md`): Demonstrates multiple function subscriptions merging into single notification resource
- **Resource Dependencies** (`resource-dependencies.md`): Details dependency relationships between S3, Lambda, and permission resources

## Core Requirements

### Functional Requirements

**S3 Event Parsing:**
- Parse S3 event configurations from `functions[name].events` array where event is `s3` type
- Support shorthand string syntax: `- s3: bucketname`
- Support full object syntax: `- s3: { bucket, event, rules, existing, forceDeploy }`
- Extract bucket name, event type, filter rules, existing flag, forceDeploy flag
- Gracefully handle functions with no S3 events (skip S3 processing for those functions)

**Shorthand Syntax Support:**
```yaml
functions:
  resize:
    handler: resize.handler
    events:
      - s3: photos
```
- Bucket name: `photos` (from string value)
- Event type: `s3:ObjectCreated:*` (default)
- Rules: none (no filters)
- Existing: `false` (create new bucket)
- ForceDeploy: `false`

**Full Object Syntax Support:**
```yaml
functions:
  users:
    handler: users.handler
    events:
      - s3:
          bucket: photos
          event: s3:ObjectRemoved:*
          rules:
            - prefix: uploads/
            - suffix: .jpg
          existing: true
          forceDeploy: true
```
- Bucket name: `photos` (required field)
- Event type: `s3:ObjectRemoved:*` (optional, defaults to `s3:ObjectCreated:*`)
- Rules: array of `{ prefix, suffix }` objects (optional)
- Existing: `true` (use existing bucket, don't create)
- ForceDeploy: `true` (force notification update, requires `existing: true`)

**Event Type Support:**
All AWS S3 notification event types must be supported:
- `s3:ObjectCreated:*` (default if not specified)
- `s3:ObjectCreated:Put`
- `s3:ObjectCreated:Post`
- `s3:ObjectCreated:Copy`
- `s3:ObjectCreated:CompleteMultipartUpload`
- `s3:ObjectRemoved:*`
- `s3:ObjectRemoved:Delete`
- `s3:ObjectRemoved:DeleteMarkerCreated`
- `s3:ObjectRestore:*`
- `s3:ObjectRestore:Post`
- `s3:ObjectRestore:Completed`
- `s3:ReducedRedundancyLostObject`
- `s3:Replication:*`

**Filter Rule Support:**
- Parse `rules` array from S3 event configuration
- Each rule can have `prefix` (string) and/or `suffix` (string)
- Multiple rules create AND conditions (prefix AND suffix must both match)
- Empty rules array or missing rules field means no filtering (all objects trigger)
- Convert rules to aws_s3_bucket_notification filter_prefix and filter_suffix attributes

**Bucket Management:**
- Create new S3 buckets for non-existing bucket references (`existing: false` or not specified)
- Reference existing buckets when `existing: true` flag is set (do not create bucket resource)
- Support custom bucket properties from `provider.s3.<bucket_key>` section
- Bucket name from either explicit `name` property or bucket key
- Apply S3 naming convention validations

**Custom Bucket Properties Support:**
```yaml
functions:
  resize:
    handler: resize.handler
    events:
      - s3: bucketOne

provider:
  s3:
    bucketOne:
      name: my-custom-bucket-name
      versioningConfiguration:
        Status: Enabled
```
- Parse `provider.s3.<bucket_key>` section for bucket configuration
- Support CloudFormation S3 bucket properties in camelCase format
- Apply custom properties to created buckets (translate to Terraform HCL format)
- Use bucket key as default bucket name if `name` not specified

**Lambda Permission Creation:**
- Generate `aws_lambda_permission` resources for each S3 event subscription
- Set principal to `s3.amazonaws.com`
- Include source ARN of the S3 bucket
- Action: `lambda:InvokeFunction`
- Unique permission resource naming per function-bucket combination
- Permission name convention: `{service}-{stage}-{function}-s3-{bucket}`

**Notification Configuration:**
- Aggregate all S3 event subscriptions per bucket into single `aws_s3_bucket_notification` resource
- Create `lambda_function` blocks within notification for each function subscription
- Include event types, filter rules (prefix/suffix), and Lambda function ARN in each block
- Ensure one notification resource per bucket (AWS constraint)
- Notification resource depends on all Lambda permissions for that bucket

**Notification Aggregation Strategy:**
- Group all S3 events by bucket name
- Create single `aws_s3_bucket_notification` resource per unique bucket
- Generate multiple `lambda_function` blocks within notification
- Each block represents one function subscription to the bucket
- Aggregation handles both new and existing buckets identically

**Filter Rule Transformation:**
- No rules: Function triggers on all S3 object events in bucket
- Prefix only: Set `filter_prefix` in lambda_function block
- Suffix only: Set `filter_suffix` in lambda_function block
- Both prefix and suffix: Set both `filter_prefix` and `filter_suffix` (AND condition)
- Empty string values treated as no filter

### Validation Requirements

**Configuration Validation:**
- Bucket name must be specified (required in both shorthand and object syntax)
- Event type must be valid S3 notification event type (if specified)
- `forceDeploy` can only be used with `existing: true`
- Bucket names must follow S3 naming conventions:
  - 3-63 characters long
  - Lowercase letters, numbers, hyphens, periods
  - Must start and end with letter or number
  - No consecutive periods, no IP address format
- Duplicate event configurations on same bucket validated (must be distinct)

**Duplicate Configuration Detection:**
Multiple functions can subscribe to same bucket, but each must have unique event configuration:
- Different event types allowed (e.g., `s3:ObjectCreated:*` vs `s3:ObjectRemoved:*`)
- Same event type with different filter rules allowed (e.g., different prefixes)
- Identical event type + filter rules combination not allowed (Serverless Framework constraint)

**Validation Error Messages:**
- Clear error when bucket name missing
- Clear error when invalid event type specified
- Clear error when `forceDeploy` used without `existing: true`
- Clear error when bucket name violates S3 naming rules
- Clear error when duplicate event configurations detected
- Error messages indicate function name and event index

**Edge Case Validation:**
- Warn if bucket name is hardcoded (recommend using variables for uniqueness)
- Validate that existing buckets are not being created (conflicting configuration)
- Validate that non-existing buckets are not referenced with `existing: true` (will fail at apply time)

### Module Integration

**Input from Roadmap Item #1 (Core Module):**
- `parsed_config`: Access `functions` and `provider.s3` for S3 event configurations
- `service_name`: Used for resource naming
- `provider_with_defaults`: Access `stage` for naming
- `functions_with_defaults`: Access function events for S3 event extraction

**Input from Roadmap Item #2 (Lambda Translation):**
- `aws_lambda_function.functions`: Lambda functions to trigger from S3 events
- Lambda function ARNs for notification configuration
- Lambda function naming convention for permission resources

**Module Structure Enhancement:**
The S3 event source mapping logic will be added to the existing module structure:

```
sls.tf/
├── main.tf           # Add S3 bucket resources
├── s3.tf             # New file: S3 notification and permission resources
├── locals.tf         # Add S3 event parsing and aggregation logic
├── outputs.tf        # Add S3 bucket and notification outputs
└── examples/
    └── s3-events/    # New example with S3 event configurations
```

**New Locals Required:**
- `s3_events_raw`: Initial extraction of S3 events from function definitions
- `s3_events_normalized`: Converted to consistent format (both shorthand and object syntax)
- `s3_buckets_to_create`: List of buckets that need to be created (not existing)
- `s3_buckets_custom_properties`: Custom bucket properties from `provider.s3` section
- `s3_notifications_aggregated`: Events grouped by bucket for aggregation
- `s3_permissions_needed`: Lambda permissions required for S3 invocation
- `s3_event_validations`: Validation errors for S3 configurations

**New Outputs Added:**
- `s3_bucket_arns`: Map of S3 bucket ARNs by bucket name `{ bucket_name = arn }`
- `s3_bucket_names`: Map of S3 bucket names by bucket key `{ bucket_key = name }`
- `s3_notification_ids`: Map of notification IDs by bucket name `{ bucket_name = id }`

### Technical Approach

**S3 Event Extraction Pattern:**

```hcl
locals {
  # Extract all S3 events from all functions
  s3_events_raw = flatten([
    for func_name, func in local.functions_with_defaults : [
      for idx, event in try(func.events, []) :
      try(event.s3, null) != null ? {
        function_name = func_name
        event_index   = idx
        s3_config     = event.s3
      } : null
    ]
  ])

  # Filter out null values (non-S3 events)
  s3_events_filtered = [for evt in local.s3_events_raw : evt if evt != null]
}
```

**S3 Event Normalization Pattern:**

```hcl
locals {
  # Normalize both shorthand and object syntax to consistent format
  s3_events_normalized = [
    for evt in local.s3_events_filtered : {
      function_name = evt.function_name
      event_index   = evt.event_index
      bucket_key    = try(evt.s3_config.bucket, evt.s3_config)  # Object or string
      bucket_name   = try(
        local.s3_buckets_custom_properties[try(evt.s3_config.bucket, evt.s3_config)].name,
        try(evt.s3_config.bucket, evt.s3_config)
      )
      event_type    = try(evt.s3_config.event, "s3:ObjectCreated:*")
      rules         = try(evt.s3_config.rules, [])
      existing      = try(evt.s3_config.existing, false)
      force_deploy  = try(evt.s3_config.forceDeploy, false)
    }
  ]
}
```

**Bucket Creation Identification:**

```hcl
locals {
  # Identify unique buckets that need to be created (not existing)
  s3_buckets_to_create = {
    for bucket_name in distinct([
      for evt in local.s3_events_normalized :
      evt.bucket_key if !evt.existing
    ]) :
    bucket_name => {
      name       = try(local.s3_buckets_custom_properties[bucket_name].name, bucket_name)
      properties = try(local.s3_buckets_custom_properties[bucket_name], {})
    }
  }

  # Parse custom bucket properties from provider.s3 section
  s3_buckets_custom_properties = try(local.parsed_config.provider.s3, {})
}
```

**Notification Aggregation Pattern:**

```hcl
locals {
  # Group S3 events by bucket name for aggregation
  s3_notifications_aggregated = {
    for bucket_name in distinct([for evt in local.s3_events_normalized : evt.bucket_name]) :
    bucket_name => [
      for evt in local.s3_events_normalized :
      {
        function_name = evt.function_name
        function_arn  = aws_lambda_function.functions[evt.function_name].arn
        events        = [evt.event_type]
        filter_prefix = try([for rule in evt.rules : rule.prefix if try(rule.prefix, null) != null][0], null)
        filter_suffix = try([for rule in evt.rules : rule.suffix if try(rule.suffix, null) != null][0], null)
      }
      if evt.bucket_name == bucket_name
    ]
  }
}
```

**S3 Bucket Resource Generation:**

```hcl
# Create new S3 buckets (only for non-existing bucket references)
resource "aws_s3_bucket" "event_buckets" {
  for_each = local.s3_buckets_to_create

  bucket = each.value.name

  # Additional properties from provider.s3 section applied via lifecycle configuration
  # versioningConfiguration, etc. handled by separate aws_s3_bucket_versioning resources
}
```

**Lambda Permission Resource Generation:**

```hcl
# Create Lambda permissions for S3 invocation
resource "aws_lambda_permission" "s3_triggers" {
  for_each = {
    for evt in local.s3_events_normalized :
    "${evt.function_name}-${evt.bucket_name}" => evt
  }

  statement_id  = "AllowExecutionFromS3-${each.value.bucket_name}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.value.function_name].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = each.value.existing ? "arn:aws:s3:::${each.value.bucket_name}" : aws_s3_bucket.event_buckets[each.value.bucket_key].arn
}
```

**S3 Bucket Notification Resource Generation:**

```hcl
# Create S3 bucket notifications (one per bucket, aggregated)
resource "aws_s3_bucket_notification" "lambda_triggers" {
  for_each = local.s3_notifications_aggregated

  bucket = each.key

  dynamic "lambda_function" {
    for_each = each.value
    content {
      lambda_function_arn = lambda_function.value.function_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }

  depends_on = [aws_lambda_permission.s3_triggers]
}
```

**Validation Pattern:**

```hcl
locals {
  # S3 event configuration validation errors
  s3_event_validations = flatten([
    for evt in local.s3_events_normalized : concat(
      # Validate bucket name not empty
      evt.bucket_name == "" ?
      ["Function '${evt.function_name}' S3 event[${evt.event_index}]: Bucket name is required."] : [],

      # Validate event type is valid S3 event
      !contains([
        "s3:ObjectCreated:*", "s3:ObjectCreated:Put", "s3:ObjectCreated:Post",
        "s3:ObjectCreated:Copy", "s3:ObjectCreated:CompleteMultipartUpload",
        "s3:ObjectRemoved:*", "s3:ObjectRemoved:Delete", "s3:ObjectRemoved:DeleteMarkerCreated",
        "s3:ObjectRestore:*", "s3:ObjectRestore:Post", "s3:ObjectRestore:Completed",
        "s3:ReducedRedundancyLostObject", "s3:Replication:*"
      ], evt.event_type) ?
      ["Function '${evt.function_name}' S3 event[${evt.event_index}]: Invalid event type '${evt.event_type}'."] : [],

      # Validate forceDeploy only with existing
      evt.force_deploy && !evt.existing ?
      ["Function '${evt.function_name}' S3 event[${evt.event_index}]: forceDeploy can only be used with existing: true."] : [],

      # Validate S3 bucket naming conventions
      !can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", evt.bucket_name)) ?
      ["Function '${evt.function_name}' S3 event[${evt.event_index}]: Bucket name '${evt.bucket_name}' violates S3 naming conventions."] : []
    )
  ])

  # Detect duplicate event configurations (same bucket + event type + filter rules)
  s3_duplicate_validations = [
    for bucket_name, events in local.s3_notifications_aggregated :
    length(events) != length(distinct([
      for evt in events :
      "${evt.events[0]}-${coalesce(evt.filter_prefix, "")}-${coalesce(evt.filter_suffix, "")}"
    ])) ?
    "Bucket '${bucket_name}' has duplicate event configurations. Each function must have unique event type or filter rules." : null
  ]

  # Combine all S3 validations
  all_s3_validations = concat(
    local.s3_event_validations,
    [for err in local.s3_duplicate_validations : err if err != null]
  )
}
```

**Integration with Existing Validation:**
Add S3 validations to existing `validation_errors` local:

```hcl
locals {
  validation_errors = local.parsed_config == null ? [] : concat(
    # Existing validations from roadmap #1
    # ...

    # S3 event validations (new)
    local.parsed_config != null ? local.all_s3_validations : []
  )
}
```

## Reusable Components

### Existing Code to Leverage

**From Roadmap Item #1 (Core Module):**
- `parsed_config` output: Access functions and provider.s3 section
- `service_name` output: For resource naming
- `provider_with_defaults`: For stage information
- `functions_with_defaults`: For S3 event extraction
- Validation framework: Error collection pattern using `concat()` and `flatten()`
- Default application pattern: `coalesce()`, `merge()`, `try()`

**From Roadmap Item #2 (Lambda Translation):**
- `aws_lambda_function.functions`: Lambda functions to trigger
- Lambda function ARN references for notifications
- Function naming convention: `{service}-{stage}-{function}`
- `for_each` iteration pattern over functions

**Terraform Built-in Functions:**
- `flatten()`: Aggregate S3 events across all functions
- `distinct()`: Identify unique buckets for creation
- `try()`: Safely access optional S3 event fields
- `coalesce()`: Default value handling for event types
- `jsonencode()`: Not directly used but pattern familiar from IAM module
- `can()` and `regex()`: Validate bucket naming conventions
- `contains()`: Validate event type values

**Validation Patterns:**
- Error collection strategy from roadmap #1
- Multi-level iteration (functions → events → fields)
- Clear, actionable error messages with context

### New Components Required

**S3 Event Parsing:**
- Event extraction from function event arrays
- Required because: S3 events mixed with other event types in events array

**Syntax Normalization:**
- Shorthand string to object conversion
- Required because: Serverless supports both formats, need consistent internal representation

**Notification Aggregation:**
- Grouping events by bucket name
- Required because: AWS allows only one notification resource per bucket

**Bucket Creation Logic:**
- Identifying new vs. existing buckets
- Required because: Different resources needed (aws_s3_bucket vs. data reference)

**Lambda Permission Generation:**
- S3-specific permission resources
- Required because: S3 service needs explicit permission to invoke Lambda

**Filter Rule Transformation:**
- Rules array to filter_prefix/filter_suffix conversion
- Required because: Serverless rules format differs from Terraform notification format

## Technical Constraints

**Terraform Compatibility:**
- Must work with Terraform 1.13.4+ (inherited from module #1)
- Must work with AWS provider 6.0+ (inherited from module #1)
- Must use native HCL functions (no external scripts)

**AWS S3 Constraints:**
- Only one `aws_s3_bucket_notification` resource per bucket (must aggregate)
- S3 bucket names must be globally unique across all AWS accounts
- Bucket naming conventions enforced (lowercase, hyphens, dots, 3-63 chars)
- Each notification can have multiple lambda_function blocks
- Lambda permissions required before notification configuration

**Serverless Framework Compatibility:**
- Must match Serverless Framework S3 event behavior exactly
- Must support both shorthand and full object syntax
- Must default to `s3:ObjectCreated:*` when event type not specified
- Must support all S3 notification event types
- Must preserve filter rule semantics (AND condition for multiple rules)

**Implementation Constraints:**
- Must maintain pure HCL implementation (no external scripts)
- Must integrate with existing Lambda functions from roadmap #2
- Must support functionless configurations gracefully
- Must follow Terraform best practices for resource dependencies

**AWS Resource Constraints:**
- Lambda permission statement_id must be unique per function-bucket combination
- S3 bucket notification depends on Lambda permissions being created first
- Bucket creation depends on no pre-existing bucket with same name
- Existing bucket references require bucket to actually exist

## Out of Scope

### Excluded from This Feature

**Custom Resource for Existing Buckets:**
- CloudFormation-style custom resource Lambda for managing existing bucket notifications
- Additional Lambda function and IAM role for custom resource management
- Deferred to roadmap item #9 (Custom Resource Provisioning)
- Note: `existing: true` flag parsed and validated, but may require custom resource handling in future

**Advanced Bucket Features:**
- S3 bucket lifecycle policies
- S3 bucket replication configurations
- S3 bucket CORS policies
- S3 bucket encryption settings (beyond custom properties)
- S3 bucket access policies (separate IAM concern)
- Future enhancement consideration

**Variable Resolution in Bucket Names:**
- `${self:service}` references in bucket names
- `${env:}` environment variable substitution
- `${cf:}` CloudFormation output references
- Deferred to roadmap item #10 (Variable Resolution Engine)

**S3 Event Source Mapping Advanced Features:**
- SQS queue notifications (separate notification type)
- SNS topic notifications (separate notification type)
- EventBridge (CloudWatch Events) notifications (separate feature)
- Multiple event types per lambda_function block (array format)
- Future enhancement consideration

**Bucket Deletion on Stack Destroy:**
- Force deletion of non-empty buckets
- Automatic bucket content cleanup
- Follow Terraform's default S3 bucket retention behavior (fails on non-empty buckets)
- Users must manually empty buckets before destroy

**Package Patterns for S3 Code:**
- Deploying Lambda code from S3 bucket (S3 as deployment source)
- Lambda code artifact management via S3
- Separate concern from S3 event triggers

**Multi-Region S3 Events:**
- Cross-region S3 bucket notifications
- Replication event handling across regions
- Future enhancement consideration

## Success Criteria

**Parsing Success:**
- Module correctly parses shorthand string syntax S3 events
- Module correctly parses full object syntax S3 events
- Both syntax formats normalized to consistent internal representation
- Functions without S3 events handled gracefully (no S3 resources created)
- Empty events array handled without errors

**Event Type Success:**
- Default event type `s3:ObjectCreated:*` applied when not specified
- All valid S3 event types supported and preserved
- Invalid event types rejected with clear error messages
- Event types correctly mapped to notification configuration

**Filter Rule Success:**
- Prefix-only rules correctly mapped to filter_prefix
- Suffix-only rules correctly mapped to filter_suffix
- Combined prefix and suffix rules create AND condition
- Empty rules array creates no filters (all objects trigger)
- Multiple rules within single event handled correctly

**Bucket Management Success:**
- New buckets created for non-existing references (existing: false)
- Existing buckets referenced without creation (existing: true)
- Custom bucket properties from provider.s3 section applied
- Bucket naming convention validations prevent invalid names
- Bucket name resolution from explicit name or bucket key

**Lambda Permission Success:**
- One aws_lambda_permission created per function-bucket combination
- Permission principal set to s3.amazonaws.com
- Source ARN correctly references S3 bucket ARN
- Permission names unique and follow naming convention
- Permissions created before bucket notifications

**Notification Aggregation Success:**
- Single aws_s3_bucket_notification resource per bucket
- Multiple lambda_function blocks for multiple function subscriptions
- All functions subscribing to same bucket aggregated correctly
- Notification depends on all Lambda permissions for that bucket
- Terraform resource graph respects dependencies

**Validation Success:**
- Required bucket name validated (not empty)
- Valid event types enforced
- forceDeploy without existing rejected with error
- S3 bucket naming conventions validated
- Duplicate event configurations detected and rejected
- Error messages indicate function name and event index

**Integration Success:**
- S3 resources integrate with Lambda functions from roadmap #2
- Module consumes outputs from roadmap #1 without modification
- S3 validations added to existing validation_errors collection
- Terraform plan shows correct number of S3 resources
- Terraform apply creates S3 resources without errors

**Serverless Framework Compatibility Success:**
- Generated S3 notifications match Serverless Framework behavior
- Same event triggers as Serverless Framework deployment
- Filter rules work identically to Serverless Framework
- Notification aggregation produces same effective configuration
- Both syntax formats produce identical results for same configuration

**Output Interface Success:**
- S3 bucket ARNs output as map keyed by bucket name
- S3 bucket names output as map keyed by bucket key
- Notification IDs output as map keyed by bucket name
- Outputs accessible for monitoring and debugging
- Empty maps when no S3 events defined

## Testing Requirements

While test implementation is out of scope for this specification, the following test scenarios must be covered:

**Valid Configuration Tests:**
- Generate S3 resources for shorthand syntax (single bucket)
- Generate S3 resources for full object syntax (with all properties)
- Handle function with multiple S3 events (different buckets)
- Handle multiple functions with same bucket (notification aggregation)
- Process function without S3 events (no resources created)

**Syntax Format Tests:**
- Verify shorthand string syntax parsed correctly
- Verify full object syntax parsed correctly
- Verify both formats produce same result for equivalent configurations
- Verify mixed syntax within same serverless.yml

**Event Type Tests:**
- Verify default event type applied (s3:ObjectCreated:*)
- Verify custom event type preserved (s3:ObjectRemoved:*)
- Verify multiple event types handled (different functions)
- Verify wildcard event types (s3:ObjectCreated:*, s3:Replication:*)

**Filter Rule Tests:**
- Verify prefix-only rule creates filter_prefix
- Verify suffix-only rule creates filter_suffix
- Verify combined prefix+suffix rules create both filters
- Verify empty rules array creates no filters
- Verify filter rules correctly mapped to notification

**Bucket Management Tests:**
- Verify new bucket created when existing: false
- Verify existing bucket referenced when existing: true
- Verify custom bucket properties applied from provider.s3
- Verify bucket name resolved from explicit name property
- Verify bucket name defaults to bucket key

**Notification Aggregation Tests:**
- Verify single notification resource per bucket
- Verify multiple lambda_function blocks for same bucket
- Verify each function subscription has correct properties
- Verify notification depends on all Lambda permissions
- Verify terraform plan shows single notification per bucket

**Lambda Permission Tests:**
- Verify one permission created per function-bucket
- Verify permission principal is s3.amazonaws.com
- Verify source ARN references correct bucket
- Verify permission names unique and follow convention
- Verify permissions created before notifications

**Validation Tests:**
- Reject empty bucket name
- Reject invalid event type
- Reject forceDeploy without existing
- Reject bucket name violating S3 naming rules
- Reject duplicate event configurations on same bucket
- Verify error messages include function name and event index

**Integration Tests:**
- Verify S3 resources reference Lambda functions from roadmap #2
- Verify terraform plan succeeds with S3 events
- Verify terraform apply creates all S3 resources
- Verify S3 events trigger Lambda invocations
- Verify terraform destroy removes all S3 resources cleanly

**Edge Cases:**
- Empty events array (no S3 resources)
- Function with only non-S3 events (no S3 resources)
- Functionless configuration (no S3 resources)
- Large number of functions on same bucket
- Complex filter rules with special characters

## Non-Functional Requirements

**Maintainability:**
- Clear separation of parsing, normalization, aggregation, and resource generation
- Descriptive local value names (s3_events_normalized, s3_notifications_aggregated)
- Comments explaining notification aggregation strategy
- Consistent validation error message format
- Logical grouping of S3 resources in s3.tf file

**Extensibility:**
- Parsing logic supports future S3 event properties
- Notification structure supports future notification types (SQS, SNS)
- Validation framework extensible for new S3 event validations
- Output interface supports additional S3 metadata
- Custom properties support extensible to all bucket configurations

**Performance:**
- S3 event parsing completes during Terraform plan phase
- Notification aggregation efficient for large event counts
- Validation runs once during plan (no runtime overhead)
- No external AWS API calls during plan (pure HCL)
- for_each iteration efficient for multiple buckets

**Security:**
- Lambda permissions scoped to specific S3 buckets (source ARN)
- No overly permissive wildcard permissions
- Bucket naming validated to prevent injection
- Filter rules preserved exactly as specified
- Follow AWS IAM best practices for Lambda permissions

**Compatibility:**
- Works with existing module structure from roadmap items #1 and #2
- Compatible with future event source integrations (roadmap items #7, #8)
- Follows Terraform AWS provider best practices
- Maintains Serverless Framework S3 event semantics
- Future-compatible with variable resolution (roadmap #10)

**Documentation:**
- Clear examples demonstrating shorthand and object syntax
- Comments explaining notification aggregation constraint
- Variable descriptions for S3-related locals
- Output descriptions for bucket ARNs and notification IDs
- Visual diagrams in planning/visuals/ directory

## Dependencies and Assumptions

**Dependencies:**
- Roadmap item #1 (Core Module Structure & YAML Parsing) must be complete
- Roadmap item #2 (Lambda Function Translation) must be complete
- Outputs required: `parsed_config`, `service_name`, `provider_with_defaults`, `functions_with_defaults`
- Resources required: `aws_lambda_function.functions` Lambda functions
- Terraform 1.13.4+ installed
- AWS provider 6.0+ configured
- AWS credentials with S3, Lambda, and IAM permissions

**Assumptions:**
- Lambda functions created in roadmap #2 are named consistently: `{service}-{stage}-{function}`
- S3 bucket names in serverless.yml are valid and unique (global uniqueness)
- Users understand S3 event types and filter rule semantics
- Existing bucket references actually exist in AWS (validated at apply time)
- No variable substitution needed yet (literal bucket names only)
- Notification aggregation constraint understood (one notification per bucket)
- Function keys in serverless.yml are valid Terraform resource identifiers

**Future Considerations:**
- Variable resolution (roadmap #10) will enable `${self:}`, `${env:}` in bucket names
- Custom resource provisioning (roadmap #9) may enable better existing bucket handling
- Additional notification types (SQS, SNS) may extend aggregation logic
- EventBridge notifications may replace CloudWatch Events integration
- Advanced bucket features may require separate bucket configuration modules

## Example Configurations

### Example 1: Shorthand Syntax (New Bucket)

**Input (serverless.yml):**
```yaml
service: photo-service
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev

functions:
  resize:
    handler: resize.handler
    events:
      - s3: photos
```

**Expected Terraform Resources:**
```hcl
# New S3 bucket created
resource "aws_s3_bucket" "event_buckets" {
  bucket = "photos"
}

# Lambda permission for S3 invocation
resource "aws_lambda_permission" "s3_triggers" {
  statement_id  = "AllowExecutionFromS3-photos"
  action        = "lambda:InvokeFunction"
  function_name = "photo-service-dev-resize"
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.event_buckets["photos"].arn
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "lambda_triggers" {
  bucket = "photos"

  lambda_function {
    lambda_function_arn = aws_lambda_function.functions["resize"].arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_triggers]
}
```

**Behavior:**
- New bucket "photos" created
- Default event type `s3:ObjectCreated:*` applied
- No filter rules (all objects trigger)
- Single lambda_function block in notification

### Example 2: Full Object Syntax with Filters

**Input (serverless.yml):**
```yaml
service: image-processor
provider:
  name: aws
  runtime: python3.11
  stage: prod

functions:
  processImage:
    handler: app.process_handler
    events:
      - s3:
          bucket: user-uploads
          event: s3:ObjectCreated:Put
          rules:
            - prefix: images/
            - suffix: .jpg
```

**Expected Terraform Resources:**
```hcl
# New S3 bucket
resource "aws_s3_bucket" "event_buckets" {
  bucket = "user-uploads"
}

# Lambda permission
resource "aws_lambda_permission" "s3_triggers" {
  statement_id  = "AllowExecutionFromS3-user-uploads"
  action        = "lambda:InvokeFunction"
  function_name = "image-processor-prod-processImage"
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.event_buckets["user-uploads"].arn
}

# S3 bucket notification with filters
resource "aws_s3_bucket_notification" "lambda_triggers" {
  bucket = "user-uploads"

  lambda_function {
    lambda_function_arn = aws_lambda_function.functions["processImage"].arn
    events              = ["s3:ObjectCreated:Put"]
    filter_prefix       = "images/"
    filter_suffix       = ".jpg"
  }

  depends_on = [aws_lambda_permission.s3_triggers]
}
```

**Behavior:**
- Triggers only on PUT operations (not POST, COPY, etc.)
- Only triggers for objects in `images/` prefix
- Only triggers for `.jpg` files
- AND condition: prefix AND suffix must both match

### Example 3: Multiple Functions on Same Bucket (Notification Aggregation)

**Input (serverless.yml):**
```yaml
service: data-pipeline
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev

functions:
  onCreate:
    handler: onCreate.handler
    events:
      - s3:
          bucket: data-lake
          event: s3:ObjectCreated:*

  onDelete:
    handler: onDelete.handler
    events:
      - s3:
          bucket: data-lake
          event: s3:ObjectRemoved:*
```

**Expected Terraform Resources:**
```hcl
# Single S3 bucket
resource "aws_s3_bucket" "event_buckets" {
  bucket = "data-lake"
}

# Two Lambda permissions (one per function)
resource "aws_lambda_permission" "s3_triggers" {
  for_each = {
    "onCreate-data-lake"  = { function = "onCreate", bucket = "data-lake" }
    "onDelete-data-lake"  = { function = "onDelete", bucket = "data-lake" }
  }

  statement_id  = "AllowExecutionFromS3-${each.value.bucket}"
  action        = "lambda:InvokeFunction"
  function_name = "data-pipeline-dev-${each.value.function}"
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.event_buckets["data-lake"].arn
}

# Single notification with two lambda_function blocks (AGGREGATED)
resource "aws_s3_bucket_notification" "lambda_triggers" {
  bucket = "data-lake"

  lambda_function {
    lambda_function_arn = aws_lambda_function.functions["onCreate"].arn
    events              = ["s3:ObjectCreated:*"]
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.functions["onDelete"].arn
    events              = ["s3:ObjectRemoved:*"]
  }

  depends_on = [aws_lambda_permission.s3_triggers]
}
```

**Behavior:**
- Single bucket, single notification resource
- Two lambda_function blocks (aggregated)
- onCreate function triggers on object creation
- onDelete function triggers on object deletion
- Different event types allowed on same bucket

### Example 4: Existing Bucket Reference

**Input (serverless.yml):**
```yaml
service: legacy-integration
provider:
  name: aws
  runtime: nodejs18.x
  stage: prod

functions:
  processUploads:
    handler: process.handler
    events:
      - s3:
          bucket: existing-uploads-bucket
          event: s3:ObjectCreated:*
          existing: true
          forceDeploy: true
```

**Expected Terraform Resources:**
```hcl
# NO aws_s3_bucket resource created (existing bucket)

# Lambda permission referencing existing bucket ARN
resource "aws_lambda_permission" "s3_triggers" {
  statement_id  = "AllowExecutionFromS3-existing-uploads-bucket"
  action        = "lambda:InvokeFunction"
  function_name = "legacy-integration-prod-processUploads"
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::existing-uploads-bucket"  # Constructed ARN
}

# S3 bucket notification (references existing bucket by name)
resource "aws_s3_bucket_notification" "lambda_triggers" {
  bucket = "existing-uploads-bucket"

  lambda_function {
    lambda_function_arn = aws_lambda_function.functions["processUploads"].arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_triggers]
}
```

**Behavior:**
- No bucket created (existing: true)
- Notification attached to pre-existing bucket
- forceDeploy flag forces notification update (Terraform behavior)
- Bucket must exist or apply will fail

### Example 5: Custom Bucket Properties

**Input (serverless.yml):**
```yaml
service: versioned-storage
provider:
  name: aws
  runtime: nodejs18.x
  stage: prod
  s3:
    archiveBucket:
      name: my-archive-bucket-prod-unique
      versioningConfiguration:
        Status: Enabled

functions:
  archiver:
    handler: archive.handler
    events:
      - s3: archiveBucket
```

**Expected Terraform Resources:**
```hcl
# S3 bucket with custom name from provider.s3 section
resource "aws_s3_bucket" "event_buckets" {
  bucket = "my-archive-bucket-prod-unique"  # Custom name, not "archiveBucket"
}

# S3 bucket versioning (from custom properties)
resource "aws_s3_bucket_versioning" "event_buckets_versioning" {
  bucket = aws_s3_bucket.event_buckets["archiveBucket"].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lambda permission
resource "aws_lambda_permission" "s3_triggers" {
  statement_id  = "AllowExecutionFromS3-my-archive-bucket-prod-unique"
  action        = "lambda:InvokeFunction"
  function_name = "versioned-storage-prod-archiver"
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.event_buckets["archiveBucket"].arn
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "lambda_triggers" {
  bucket = "my-archive-bucket-prod-unique"

  lambda_function {
    lambda_function_arn = aws_lambda_function.functions["archiver"].arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_triggers]
}
```

**Behavior:**
- Bucket created with custom name from provider.s3 section
- Bucket key "archiveBucket" used for resource references
- Custom properties (versioningConfiguration) applied via separate resources
- CloudFormation camelCase properties translated to Terraform snake_case

## Implementation Notes

**Development Order:**
1. Add S3 event extraction logic to locals.tf (s3_events_raw)
2. Add syntax normalization logic (s3_events_normalized)
3. Add bucket creation identification (s3_buckets_to_create)
4. Add custom bucket properties parsing (provider.s3 section)
5. Add notification aggregation logic (s3_notifications_aggregated)
6. Add S3 event validations (event type, bucket name, forceDeploy, duplicates)
7. Create s3.tf file with aws_s3_bucket resources
8. Add aws_lambda_permission resources to s3.tf
9. Add aws_s3_bucket_notification resources to s3.tf
10. Add S3 outputs to outputs.tf (bucket ARNs, notification IDs)
11. Test with examples covering all syntax formats and scenarios
12. Verify notification aggregation with multiple functions on same bucket

**Key Implementation Challenges:**
- Normalizing shorthand string and full object syntax to consistent format (use type checking and try())
- Aggregating multiple function subscriptions into single notification per bucket (group by bucket name)
- Handling both new and existing buckets in permission source ARN (conditional ARN construction)
- Detecting duplicate event configurations (hash event type + filter rules)
- Extracting S3 events from mixed event arrays (filter by event.s3 presence)
- Applying custom bucket properties from provider.s3 section (translate CloudFormation to Terraform)

**Code Quality Guidelines:**
- Run `terraform fmt` on all modified .tf files
- Use descriptive local value names (s3_events_normalized, not s3_data)
- Add comments explaining notification aggregation constraint
- Keep validation rules readable (one condition per concat element)
- Follow Terraform naming conventions (snake_case)
- Group related resources in s3.tf file

**Testing Approach:**
- Create example with shorthand syntax (single bucket)
- Create example with full object syntax (all properties)
- Create example with multiple functions on same bucket (aggregation)
- Create example with existing bucket reference
- Create example with custom bucket properties
- Create example with filter rules (prefix, suffix, both)
- Verify terraform plan shows correct resource count
- Verify terraform apply creates S3 resources successfully
- Test S3 event triggering Lambda invocations
- Verify terraform destroy removes S3 resources cleanly

**Integration Points:**
- Consume `local.parsed_config.functions` for S3 event extraction
- Consume `local.functions_with_defaults` for event arrays
- Consume `local.parsed_config.provider.s3` for custom bucket properties
- Consume `local.service_name` for resource naming
- Consume `local.provider_with_defaults.stage` for naming
- Reference `aws_lambda_function.functions[func_name]` from roadmap #2
- Extend `validation_errors` collection with S3 validations

**File Organization:**

**locals.tf additions:**
```hcl
# S3 Event Parsing
locals {
  s3_events_raw              = ...
  s3_events_normalized       = ...
  s3_buckets_custom_properties = ...
  s3_buckets_to_create       = ...
  s3_notifications_aggregated = ...
  s3_event_validations       = ...
  all_s3_validations         = ...
}
```

**s3.tf (new file):**
```hcl
# S3 Buckets (new buckets only)
resource "aws_s3_bucket" "event_buckets" { ... }

# Lambda Permissions for S3 invocation
resource "aws_lambda_permission" "s3_triggers" { ... }

# S3 Bucket Notifications (aggregated)
resource "aws_s3_bucket_notification" "lambda_triggers" { ... }
```

**outputs.tf additions:**
```hcl
output "s3_bucket_arns" { ... }
output "s3_bucket_names" { ... }
output "s3_notification_ids" { ... }
```

**Validation Integration:**
Ensure S3 validations are integrated into existing validation framework:
- Add `local.all_s3_validations` to `validation_errors` concat
- Follow existing validation error message format
- Include function name and event index in error messages
- Validate during plan phase (fail fast)

**Dependency Management:**
Ensure correct resource dependency order:
1. Lambda functions (from roadmap #2)
2. S3 buckets (new buckets only)
3. Lambda permissions (depends on functions and buckets)
4. S3 bucket notifications (depends on permissions)

**Terraform Resource Graph:**
```
aws_lambda_function.functions
  ↓
aws_s3_bucket.event_buckets (for new buckets)
  ↓
aws_lambda_permission.s3_triggers
  ↓
aws_s3_bucket_notification.lambda_triggers
```

---

**This specification is ready for implementation.** Developers should reference the Lambda function resources in roadmap item #2, the validation patterns from roadmap item #1, and the visual diagrams in `planning/visuals/` for notification aggregation strategy and module integration details.
