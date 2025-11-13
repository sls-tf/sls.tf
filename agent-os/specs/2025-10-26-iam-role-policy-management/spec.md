# Specification: IAM Role & Policy Management

## Overview

This specification defines the IAM Role & Policy Management capability for sls.tf, which extends the Lambda function translation module (roadmap item #2) by implementing custom IAM policy generation from Serverless Framework iamRoleStatements. This module translates both provider-level and function-level IAM policy statements into Terraform aws_iam_role_policy resources with proper policy document generation, action wildcard support, resource ARN pattern handling, and intelligent policy merging across configuration levels.

**Roadmap Position:** Item #3 - Core security and permissions infrastructure
**Dependencies:**
- Roadmap item #1 (Core Module Structure & YAML Parsing) - provides parsed configuration
- Roadmap item #2 (Lambda Function Translation) - provides IAM roles to extend
**Target Completion:** Enable custom AWS service permissions for Lambda functions via serverless.yml

## Goal

Transform Serverless Framework iamRoleStatements (both provider-level and function-level) into AWS IAM inline policies attached to Lambda execution roles, supporting action wildcards, resource ARN patterns, and policy statement merging while maintaining Serverless Framework compatibility and security best practices.

## User Stories

- As a developer, I want to specify DynamoDB permissions in serverless.yml iamRoleStatements so that my Lambda functions can access DynamoDB tables without manually creating IAM policies in the AWS console
- As a platform engineer, I want provider-level iamRoleStatements to automatically apply to all Lambda functions so that I can define common permissions once and avoid repetition across function definitions
- As a security architect, I want function-level iamRoleStatements to enable least-privilege access patterns so that functions only receive the specific permissions they need beyond common provider-level grants
- As a migration specialist, I want IAM policy translation to match Serverless Framework behavior exactly so that migrated applications maintain the same security posture without permission changes
- As a DevOps engineer, I want action wildcards (s3:*, dynamodb:GetItem) and resource ARN patterns to work correctly so that my existing serverless.yml configurations deploy without modification
- As an infrastructure team member, I want clear validation errors for malformed iamRoleStatements so that I can fix IAM policy issues during Terraform plan rather than discovering them at runtime

## Visual Design

This feature has no visual user interface components. Technical reference diagrams are provided:

- **IAM Policy Flow** (`planning/visuals/iam-policy-flow.md`): Illustrates parsing, merging, and policy document generation
- **Policy Merging Strategy** (`planning/visuals/policy-merging.md`): Shows how provider and function-level statements combine
- **Resource Association** (`planning/visuals/resource-association.md`): Demonstrates role-policy-function relationships

## Core Requirements

### Functional Requirements

**iamRoleStatements Parsing:**
- Parse `provider.iamRoleStatements` array from parsed configuration (via roadmap item #1)
- Parse function-level `functions[name].iamRoleStatements` arrays from function definitions
- Support statement objects with required fields: `Effect`, `Action`, `Resource`
- Handle both string and array formats for `Action` and `Resource` fields
- Gracefully handle missing iamRoleStatements (no policies created if not specified)

**IAM Statement Schema:**
```yaml
# Provider-level (applies to ALL functions)
provider:
  iamRoleStatements:
    - Effect: Allow | Deny
      Action: string | string[]
      Resource: string | string[]

# Function-level (applies to specific function)
functions:
  myFunction:
    iamRoleStatements:
      - Effect: Allow | Deny
        Action: string | string[]
        Resource: string | string[]
```

**Policy Document Generation:**
- Generate IAM policy JSON documents from iamRoleStatements using `jsonencode()`
- Include required `Version: "2012-10-17"` in all policy documents
- Translate Serverless statement format to AWS IAM policy Statement array
- Normalize Action and Resource to arrays (convert strings to single-element arrays)
- Preserve Effect values exactly as specified (Allow or Deny)

**Action Wildcard Support:**
- Support full service wildcards: `s3:*`, `dynamodb:*`, `logs:*`
- Support specific actions: `dynamodb:GetItem`, `s3:PutObject`
- Support action arrays: `["dynamodb:GetItem", "dynamodb:PutItem"]`
- Preserve wildcards in generated policy documents (no expansion)
- Validate action format matches `service:action` pattern

**Resource ARN Pattern Support:**
- Support literal ARNs: `arn:aws:dynamodb:us-east-1:123456789012:table/MyTable`
- Support wildcard patterns: `arn:aws:s3:::mybucket/*`
- Support region/account wildcards: `arn:aws:dynamodb:*:*:table/MyTable`
- Support special CloudWatch Logs ARN: `arn:aws:logs:*:*:*`
- Support resource arrays: `["arn:aws:s3:::bucket1/*", "arn:aws:s3:::bucket2/*"]`
- Preserve ARN patterns exactly as specified (no substitution yet - deferred to roadmap #10)

**Policy Attachment Strategy:**
- Create `aws_iam_role_policy` inline policy resources (not managed policies)
- One policy resource per function (combines provider + function statements)
- Policy name convention: `{service}-{stage}-{function}-policy`
- Attach to existing IAM roles created in roadmap item #2
- Use `for_each` to create policies only for functions with statements

**Policy Merging Logic:**
- Provider-level iamRoleStatements apply to ALL functions
- Function-level iamRoleStatements apply to specific function only
- Merge provider and function statements into single policy document per function
- Preserve statement order: provider statements first, then function statements
- Do not deduplicate identical statements (preserve explicit configuration)
- Functions without any statements (provider or function-level) get no custom policy

**Validation Rules:**
- Validate Effect field values: must be "Allow" or "Deny"
- Validate Action field: required, must be string or array of strings
- Validate Resource field: required, must be string or array of strings
- Validate Action format: each action must match `service:action` pattern (e.g., `s3:GetObject`)
- Collect all validation errors before halting execution (consistent with roadmap #1 pattern)
- Provide clear error messages indicating which function and statement has issues

**Integration with Existing IAM Roles:**
- Extend IAM roles created in roadmap item #2 (do not replace them)
- Maintain existing `AWSLambdaBasicExecutionPolicy` attachment
- Add custom policy alongside basic execution policy
- Reference role using `aws_iam_role.lambda_execution[each.key].name`

**Functionless Configuration Handling:**
- No policies created when no functions defined
- No policies created when functions exist but no iamRoleStatements specified
- Gracefully handle empty provider.iamRoleStatements array
- Gracefully handle empty function.iamRoleStatements arrays

### Module Integration

**Input from Roadmap Item #1 (Core Module):**
- `parsed_config`: Access `provider.iamRoleStatements` for global statements
- `service_name`: Used for policy naming convention
- `provider_config`: Access `stage` for policy naming
- `functions_with_defaults`: Access function-level iamRoleStatements

**Input from Roadmap Item #2 (Lambda Translation):**
- `aws_iam_role.lambda_execution`: Existing IAM roles to attach policies to
- Role naming convention: `{service}-{stage}-{function}-role`

**Module Structure Enhancement:**
The IAM policy logic will be added to the existing module structure:

```
sls.tf/
├── main.tf           # Add aws_iam_role_policy resources
├── locals.tf         # Add IAM policy transformation logic
├── outputs.tf        # Add policy ARN outputs
└── examples/
    └── iam-policies/ # New example with iamRoleStatements
```

**New Locals Required:**
- `provider_iam_statements`: Parsed provider-level statements (normalized)
- `function_iam_statements`: Parsed function-level statements per function (normalized)
- `merged_iam_statements`: Combined statements per function (provider + function)
- `functions_with_policies`: Map of functions requiring custom policies

**New Outputs Added:**
- `policy_arns`: Map of policy ARNs by function name `{ function_key = policy_arn }`
- `policy_names`: Map of policy names by function name `{ function_key = policy_name }`

### Technical Approach

**Statement Normalization Pattern:**

```hcl
locals {
  # Normalize provider-level iamRoleStatements
  provider_iam_statements = try(local.parsed_config.provider.iamRoleStatements, null) != null ? [
    for stmt in local.parsed_config.provider.iamRoleStatements : {
      Effect   = stmt.Effect
      Action   = try(tolist(stmt.Action), [stmt.Action])  # Normalize to array
      Resource = try(tolist(stmt.Resource), [stmt.Resource])  # Normalize to array
    }
  ] : []

  # Normalize function-level iamRoleStatements per function
  function_iam_statements = {
    for func_name, func in local.functions_with_defaults :
    func_name => try(func.iamRoleStatements, null) != null ? [
      for stmt in func.iamRoleStatements : {
        Effect   = stmt.Effect
        Action   = try(tolist(stmt.Action), [stmt.Action])
        Resource = try(tolist(stmt.Resource), [stmt.Resource])
      }
    ] : []
  }

  # Merge provider and function statements per function
  merged_iam_statements = {
    for func_name, func in local.functions_with_defaults :
    func_name => concat(
      local.provider_iam_statements,
      local.function_iam_statements[func_name]
    )
  }

  # Identify functions requiring custom policies (non-empty statements)
  functions_with_policies = {
    for func_name, statements in local.merged_iam_statements :
    func_name => statements
    if length(statements) > 0
  }
}
```

**Policy Resource Generation Pattern:**

```hcl
# Create inline IAM policies for functions with iamRoleStatements
resource "aws_iam_role_policy" "lambda_custom_policy" {
  for_each = local.functions_with_policies

  name = "${local.service_name}-${local.provider_with_defaults.stage}-${each.key}-policy"
  role = aws_iam_role.lambda_execution[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in each.value : {
        Effect   = stmt.Effect
        Action   = stmt.Action
        Resource = stmt.Resource
      }
    ]
  })
}
```

**Validation Pattern:**

```hcl
locals {
  # IAM statement validation errors
  iam_validation_errors = flatten([
    for func_name, func in try(local.parsed_config.functions, {}) :
    try(func.iamRoleStatements, null) != null ? [
      for idx, stmt in func.iamRoleStatements : concat(
        # Validate Effect field
        !contains(["Allow", "Deny"], try(stmt.Effect, "")) ?
        ["Function '${func_name}' iamRoleStatement[${idx}]: Effect must be 'Allow' or 'Deny', got '${try(stmt.Effect, "none")}'."] : [],

        # Validate Action field exists
        try(stmt.Action, null) == null ?
        ["Function '${func_name}' iamRoleStatement[${idx}]: Required field 'Action' is missing."] : [],

        # Validate Resource field exists
        try(stmt.Resource, null) == null ?
        ["Function '${func_name}' iamRoleStatement[${idx}]: Required field 'Resource' is missing."] : [],

        # Validate Action format (service:action pattern)
        try(stmt.Action, null) != null ? local.validate_action_format(stmt.Action, func_name, idx) : []
      )
    ] : []
  ])

  # Also validate provider-level statements
  provider_iam_validation_errors = try(local.parsed_config.provider.iamRoleStatements, null) != null ? flatten([
    for idx, stmt in local.parsed_config.provider.iamRoleStatements : concat(
      !contains(["Allow", "Deny"], try(stmt.Effect, "")) ?
      ["Provider iamRoleStatement[${idx}]: Effect must be 'Allow' or 'Deny', got '${try(stmt.Effect, "none")}'."] : [],

      try(stmt.Action, null) == null ?
      ["Provider iamRoleStatement[${idx}]: Required field 'Action' is missing."] : [],

      try(stmt.Resource, null) == null ?
      ["Provider iamRoleStatement[${idx}]: Required field 'Resource' is missing."] : []
    )
  ]) : []

  # Helper function to validate action format
  validate_action_format = function(action, func_name, idx) {
    actions = try(tolist(action), [action])
    invalid_actions = [
      for act in actions :
      act if !can(regex("^[a-z0-9]+:[*a-zA-Z0-9]+$", act))
    ]
    return length(invalid_actions) > 0 ? [
      "Function '${func_name}' iamRoleStatement[${idx}]: Invalid action format '${join(", ", invalid_actions)}'. Must match 'service:action' pattern."
    ] : []
  }
}
```

**Policy Naming Convention:**
- Pattern: `{service_name}-{stage}-{function_key}-policy`
- Example: `my-service-dev-worker-policy`
- Matches Lambda function and role naming conventions
- Ensures uniqueness across stages and services

**Dependency Management:**
- IAM policies depend on IAM roles (implicit via role name reference)
- Lambda functions created in roadmap #2 already depend on roles
- Policy attachment completes before Lambda function invocation
- Terraform dependency graph: Role → Policy → Function

## Reusable Components

### Existing Code to Leverage

**From Roadmap Item #1 (Core Module):**
- `parsed_config` output: Access provider and function iamRoleStatements
- `service_name` output: For policy naming
- `provider_with_defaults`: For stage information
- `functions_with_defaults`: For function-level statements
- Validation framework: Error collection pattern using `concat()` and `flatten()`

**From Roadmap Item #2 (Lambda Translation):**
- `aws_iam_role.lambda_execution`: Existing IAM roles to attach policies to
- Role naming convention: Consistent with function naming
- `for_each` iteration pattern over functions
- Policy attachment strategy using `aws_iam_role_policy_attachment`

**Terraform Built-in Functions:**
- `jsonencode()`: Generate IAM policy JSON from HCL structures
- `try()`: Safely access optional iamRoleStatements fields
- `coalesce()`: Default value handling
- `concat()`: Merge provider and function statement arrays
- `tolist()`: Normalize string to array for Action/Resource
- `flatten()`: Aggregate validation errors across statements
- `contains()`: Validate Effect values
- `can()` and `regex()`: Validate action format patterns

**Validation Patterns:**
- Error collection strategy from roadmap #1
- Multi-level iteration (functions → statements → fields)
- Clear, actionable error messages with context (function name, statement index)

### New Components Required

**IAM Policy Statement Parsing:**
- Statement normalization logic (string to array conversion)
- Required because: Serverless supports both string and array formats for Action/Resource

**Policy Merging Logic:**
- Provider + function statement concatenation per function
- Required because: Serverless Framework merges statements at both levels

**Policy Document Generation:**
- IAM policy JSON structure with Version and Statement array
- Required because: AWS IAM requires specific JSON schema

**Custom Policy Attachment:**
- `aws_iam_role_policy` resource declarations with `for_each`
- Required because: Inline policies needed for custom permissions

**IAM-Specific Validation:**
- Effect value validation (Allow/Deny)
- Action format validation (service:action pattern)
- Action/Resource required field checks
- Required because: Invalid IAM policies fail at runtime, not plan time

## Technical Constraints

**Terraform Compatibility:**
- Must work with Terraform 1.13.4+ (inherited from module #1)
- Must work with AWS provider 6.0+ (inherited from module #1)
- Must use native HCL functions (no external IAM policy generators)

**AWS IAM Constraints:**
- Policy document size limit: 10,240 characters per inline policy
- Maximum 10 managed policies per role (not applicable - using inline policies)
- IAM policy name limits: 128 characters maximum
- Effect must be "Allow" or "Deny" (case-sensitive)
- Action format must follow AWS service:action pattern

**Serverless Framework Compatibility:**
- Must match Serverless Framework IAM statement merging behavior
- Must preserve action wildcards exactly as specified
- Must preserve resource ARN patterns exactly as specified
- Must support both provider and function-level statements
- Must maintain statement order (provider first, then function)

**Implementation Constraints:**
- Must maintain pure HCL implementation (no external scripts)
- Must integrate with existing IAM roles from roadmap #2
- Must not break existing basic execution policy attachment
- Must follow Terraform best practices for resource dependencies

**Security Constraints:**
- No automatic ARN substitution (deferred to roadmap #10 variable resolution)
- No permission boundary enforcement (future enhancement)
- No managed policy attachment (only inline policies in this phase)
- Preserve user-specified permissions exactly (no automatic least-privilege reduction)

## Out of Scope

### Excluded from This Feature

**Advanced IAM Policy Features:**
- Condition blocks in IAM statements (future enhancement)
- NotAction and NotPrincipal fields (future enhancement)
- Statement Sid (statement ID) generation (not commonly used in Serverless)
- Policy versioning and rollback (Terraform state handles this)
- Future consideration for roadmap expansion

**Managed Policy Support:**
- Attachment of AWS managed policies (beyond basic execution policy)
- Custom managed policy creation (aws_iam_policy resource)
- Policy ARN references from serverless.yml
- Deferred to future enhancement (not in current roadmap)

**Role Management Advanced Features:**
- Custom IAM role ARN specification (role property in serverless.yml)
- Shared IAM roles across multiple functions
- Cross-account role assumption
- Assume role policy customization beyond Lambda service
- Future consideration for roadmap expansion

**Variable Resolution in Policies:**
- `${self:}` references in Action/Resource fields
- `${env:}` environment variable substitution
- `${cf:}` CloudFormation output references
- Deferred to roadmap item #10 (Variable Resolution Engine)

**Permission Boundaries:**
- IAM permission boundaries for functions
- Organization-level service control policies
- Session policies for assumed roles
- Future enhancement (not on current roadmap)

**Policy Optimization:**
- Automatic deduplication of identical statements
- Wildcard consolidation (e.g., combining s3:GetObject and s3:PutObject to s3:*)
- Policy size reduction techniques
- Statement reordering for efficiency
- Future enhancement consideration

**IAM Role Passthrough:**
- Using existing IAM roles instead of auto-generated ones
- Role ARN references from external Terraform modules
- Future enhancement (not in current roadmap)

**Advanced Resource ARN Handling:**
- Automatic account ID substitution in ARNs
- Region substitution in ARNs
- Dynamic resource ARN generation from Terraform resources
- Deferred to roadmap #10 (variable resolution handles this)

## Success Criteria

**Policy Parsing Success:**
- Module correctly parses provider.iamRoleStatements from configuration
- Module correctly parses function-level iamRoleStatements per function
- Empty or missing iamRoleStatements handled gracefully (no policies created)
- Both string and array formats for Action/Resource parsed correctly

**Policy Generation Success:**
- Generated IAM policy documents have correct JSON structure
- Policy documents include Version "2012-10-17"
- Statement array contains all provider + function statements
- Effect values preserved exactly (Allow/Deny)
- Action wildcards preserved (s3:*, dynamodb:GetItem)
- Resource ARN patterns preserved (including wildcards)

**Policy Attachment Success:**
- One aws_iam_role_policy created per function with statements
- Policies attached to correct IAM roles (from roadmap #2)
- Policy naming follows convention: {service}-{stage}-{function}-policy
- No policies created for functions without statements
- Policies created alongside existing AWSLambdaBasicExecutionPolicy attachment

**Policy Merging Success:**
- Provider-level statements included in ALL function policies
- Function-level statements included only in specific function's policy
- Statement order preserved: provider statements first, then function statements
- No statement deduplication (explicit configuration honored)
- Functions with only provider statements receive those statements
- Functions with only function statements receive those statements
- Functions with both levels receive merged statements

**Validation Success:**
- Invalid Effect values rejected (not Allow or Deny)
- Missing Action field rejected with clear error message
- Missing Resource field rejected with clear error message
- Invalid action format rejected (must match service:action)
- Validation errors collected for ALL statements before halting
- Error messages indicate function name and statement index

**Integration Success:**
- Policies integrate with IAM roles from roadmap #2 without modification
- Basic execution policy remains attached (CloudWatch Logs access)
- Lambda functions can invoke AWS services based on granted permissions
- Terraform plan shows correct number of policy resources
- Terraform apply creates policies without errors

**Serverless Framework Compatibility Success:**
- Generated policies match Serverless Framework behavior exactly
- Same permissions granted as Serverless Framework deployment
- Action wildcards work identically to Serverless Framework
- Resource ARN patterns work identically to Serverless Framework
- Policy merging produces same effective permissions

**Output Interface Success:**
- Policy ARNs output as map keyed by function name
- Policy names output as map keyed by function name
- Outputs accessible for monitoring and auditing tools
- Empty maps when no policies created

## Testing Requirements

While test implementation is out of scope for this specification, the following test scenarios must be covered:

**Valid Configuration Tests:**
- Generate policy for function with provider-level statements only
- Generate policy for function with function-level statements only
- Generate policy for function with both provider and function statements
- Handle function without any statements (no policy created)
- Process multiple functions with mixed statement configurations

**Statement Format Tests:**
- Parse Action as string (single action)
- Parse Action as array (multiple actions)
- Parse Resource as string (single resource)
- Parse Resource as array (multiple resources)
- Handle mixed string/array formats across statements

**Action Wildcard Tests:**
- Preserve full service wildcard (s3:*)
- Preserve specific action (dynamodb:GetItem)
- Preserve action array with mixed wildcards and specific actions
- Verify wildcards not expanded in generated policy

**Resource ARN Pattern Tests:**
- Preserve literal ARN without wildcards
- Preserve ARN with path wildcard (arn:aws:s3:::bucket/*)
- Preserve ARN with region/account wildcards (arn:aws:dynamodb:*:*:table/Name)
- Preserve special CloudWatch Logs ARN (arn:aws:logs:*:*:*)
- Verify ARN patterns not modified in generated policy

**Policy Merging Tests:**
- Verify provider statements included in all function policies
- Verify function statements only in specific function's policy
- Verify statement order: provider first, then function
- Verify no deduplication of identical statements
- Verify empty provider statements handled correctly
- Verify empty function statements handled correctly

**Validation Tests:**
- Reject Effect value not "Allow" or "Deny"
- Reject missing Action field
- Reject missing Resource field
- Reject invalid action format (no colon, invalid characters)
- Verify validation errors collected for all statements
- Verify error messages include function name and statement index

**Policy Naming Tests:**
- Verify policy name format: {service}-{stage}-{function}-policy
- Verify naming consistent with role naming convention
- Verify naming handles special characters in function keys
- Verify uniqueness across functions

**Integration Tests:**
- Verify policies attach to roles created in roadmap #2
- Verify basic execution policy remains attached
- Verify terraform plan shows correct resource count
- Verify terraform apply creates policies successfully
- Verify Lambda functions can use granted permissions
- Verify terraform destroy removes policies cleanly

**Edge Cases:**
- Empty iamRoleStatements array (no policies created)
- iamRoleStatements field absent (no policies created)
- Functionless configuration (no policies created)
- Large number of statements (policy size validation)
- Complex ARN patterns with multiple wildcards

## Non-Functional Requirements

**Maintainability:**
- Clear separation of statement parsing, merging, and policy generation
- Descriptive local value names (provider_iam_statements, merged_iam_statements)
- Comments explaining IAM policy structure and merging logic
- Consistent validation error message format

**Extensibility:**
- Policy structure supports future Condition block addition
- Statement normalization supports future NotAction/NotResource fields
- Validation framework extensible for new IAM policy rules
- Output interface supports additional policy metadata

**Performance:**
- Policy generation completes during Terraform plan phase
- Statement merging efficient for large statement counts
- Validation runs once during plan (no runtime overhead)
- No external IAM policy validation calls (pure HCL)

**Security:**
- Preserve user-specified permissions exactly (no automatic changes)
- Clear validation prevents invalid IAM policies
- No secrets in policy documents (ARNs and actions only)
- Policy attachment follows AWS IAM best practices

**Compatibility:**
- Works with existing module structure from roadmap items #1 and #2
- Compatible with future variable resolution (roadmap #10)
- Follows Terraform AWS provider best practices
- Maintains Serverless Framework IAM statement semantics

**Documentation:**
- Clear examples demonstrating provider and function-level statements
- Comments explaining policy merging strategy
- Variable descriptions for IAM-related locals
- Output descriptions for policy ARNs and names

## Dependencies and Assumptions

**Dependencies:**
- Roadmap item #1 (Core Module Structure & YAML Parsing) must be complete
- Roadmap item #2 (Lambda Function Translation) must be complete
- Outputs required: `parsed_config`, `service_name`, `provider_config`, `functions_with_defaults`
- Resources required: `aws_iam_role.lambda_execution` roles
- Terraform 1.13.4+ installed
- AWS provider 6.0+ configured
- AWS credentials with IAM policy creation permissions

**Assumptions:**
- IAM roles created in roadmap #2 are named consistently: `{service}-{stage}-{function}-role`
- Lambda basic execution policy attachment remains separate (not affected by custom policies)
- Users understand IAM policy syntax for Action and Resource fields
- ARN patterns in serverless.yml are valid AWS ARNs (validation in roadmap #10)
- No variable substitution needed yet (literal ARNs only)
- Inline policies sufficient for initial implementation (managed policies future enhancement)
- Policy size limits (10,240 characters) not exceeded in normal usage
- Function keys in serverless.yml are valid Terraform resource identifiers

**Future Considerations:**
- Variable resolution (roadmap #10) will enable `${self:}`, `${env:}`, `${cf:}` in ARNs
- Condition blocks may be added in future enhancement
- Managed policy support may be added as separate feature
- Permission boundaries may be added for advanced security requirements
- Policy optimization (deduplication, consolidation) may be added as enhancement

## Example Configurations

### Example 1: Provider-Level Statements (Apply to All Functions)

**Input (serverless.yml):**
```yaml
service: my-service
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev
  region: us-east-1
  iamRoleStatements:
    - Effect: Allow
      Action:
        - dynamodb:GetItem
        - dynamodb:PutItem
      Resource: "arn:aws:dynamodb:us-east-1:*:table/MyTable"
    - Effect: Allow
      Action: s3:*
      Resource: "arn:aws:s3:::my-bucket/*"

functions:
  worker:
    handler: worker.handler
  processor:
    handler: processor.handler
```

**Expected Terraform Resources:**
```hcl
# Policy for worker function (gets provider statements)
resource "aws_iam_role_policy" "lambda_custom_policy" {
  for_each = {
    worker    = local.merged_iam_statements["worker"]
    processor = local.merged_iam_statements["processor"]
  }

  name = "my-service-dev-${each.key}-policy"
  role = aws_iam_role.lambda_execution[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = ["arn:aws:dynamodb:us-east-1:*:table/MyTable"]
      },
      {
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = ["arn:aws:s3:::my-bucket/*"]
      }
    ]
  })
}
```

**Behavior:**
- Both worker and processor functions receive identical custom policies
- Both policies contain 2 statements (provider-level statements)
- DynamoDB and S3 permissions granted to both functions
- Basic execution policy still attached separately

### Example 2: Function-Level Statements (Least Privilege Pattern)

**Input (serverless.yml):**
```yaml
service: api-service
provider:
  name: aws
  runtime: python3.11
  stage: prod

functions:
  reader:
    handler: app.read_handler
    iamRoleStatements:
      - Effect: Allow
        Action: dynamodb:GetItem
        Resource: "arn:aws:dynamodb:us-west-2:*:table/Users"

  writer:
    handler: app.write_handler
    iamRoleStatements:
      - Effect: Allow
        Action:
          - dynamodb:GetItem
          - dynamodb:PutItem
          - dynamodb:UpdateItem
        Resource: "arn:aws:dynamodb:us-west-2:*:table/Users"
```

**Expected Terraform Resources:**
```hcl
# Policy for reader function (read-only access)
resource "aws_iam_role_policy" "lambda_custom_policy" {
  for_each = {
    reader = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem"]
      Resource = ["arn:aws:dynamodb:us-west-2:*:table/Users"]
    }]
    writer = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
      Resource = ["arn:aws:dynamodb:us-west-2:*:table/Users"]
    }]
  }

  name = "api-service-prod-${each.key}-policy"
  role = aws_iam_role.lambda_execution[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = each.value
  })
}
```

**Behavior:**
- Reader function gets read-only DynamoDB permission
- Writer function gets read/write DynamoDB permissions
- No provider-level statements (each function has specific permissions)
- Demonstrates least-privilege pattern

### Example 3: Combined Provider and Function-Level Statements

**Input (serverless.yml):**
```yaml
service: combined-service
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev
  iamRoleStatements:
    - Effect: Allow
      Action: logs:CreateLogGroup
      Resource: "arn:aws:logs:*:*:*"

functions:
  uploader:
    handler: upload.handler
    iamRoleStatements:
      - Effect: Allow
        Action:
          - s3:PutObject
          - s3:PutObjectAcl
        Resource: "arn:aws:s3:::uploads-bucket/*"

  downloader:
    handler: download.handler
    iamRoleStatements:
      - Effect: Allow
        Action: s3:GetObject
        Resource: "arn:aws:s3:::uploads-bucket/*"
```

**Expected Behavior:**
```hcl
# Uploader policy: provider statement + function statement
resource "aws_iam_role_policy" "lambda_custom_policy" {
  name = "combined-service-dev-uploader-policy"
  role = aws_iam_role.lambda_execution["uploader"].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Provider statement (first)
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup"]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      # Function statement (second)
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
        Resource = ["arn:aws:s3:::uploads-bucket/*"]
      }
    ]
  })
}

# Downloader policy: provider statement + function statement
resource "aws_iam_role_policy" "lambda_custom_policy" {
  name = "combined-service-dev-downloader-policy"
  role = aws_iam_role.lambda_execution["downloader"].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Provider statement (first)
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup"]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      # Function statement (second)
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::uploads-bucket/*"]
      }
    ]
  })
}
```

**Behavior:**
- Both functions receive provider-level CloudWatch Logs permission
- Uploader adds S3 write permissions (PutObject, PutObjectAcl)
- Downloader adds S3 read permission (GetObject)
- Statement order: provider first, then function-specific
- Demonstrates policy merging strategy

### Example 4: No IAM Statements (Default Behavior)

**Input (serverless.yml):**
```yaml
service: simple-service
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev

functions:
  hello:
    handler: index.handler
```

**Expected Behavior:**
- No `aws_iam_role_policy` resources created
- Only basic execution policy attached (from roadmap #2)
- Function has CloudWatch Logs access only
- Terraform plan shows zero custom policy resources
- No policy-related validation errors

## Implementation Notes

**Development Order:**
1. Add IAM statement normalization logic to locals.tf
2. Add provider-level statement parsing
3. Add function-level statement parsing per function
4. Add policy merging logic (concat provider + function statements)
5. Add validation logic for Effect, Action, Resource fields
6. Add action format validation (service:action pattern)
7. Add aws_iam_role_policy resources with for_each
8. Add policy ARN and name outputs
9. Test with examples covering all statement combinations
10. Verify integration with roadmap #2 IAM roles

**Key Implementation Challenges:**
- Normalizing Action/Resource from string or array to consistent array format (use tolist())
- Merging provider and function statements while preserving order (use concat())
- Validating action format across nested structures (use flatten() for error collection)
- Creating policies only for functions with statements (use length check in for_each)
- Ensuring policy attachment doesn't conflict with basic execution policy (separate resources)

**Code Quality Guidelines:**
- Run `terraform fmt` on all modified .tf files
- Use descriptive local value names (provider_iam_statements, merged_iam_statements)
- Add comments explaining policy merging logic and statement order
- Keep validation rules readable (one condition per concat element)
- Follow Terraform naming conventions (snake_case)

**Testing Approach:**
- Create example with provider-level statements only
- Create example with function-level statements only
- Create example with combined provider + function statements
- Create example with no statements (verify no policies created)
- Test with string and array Action/Resource formats
- Verify terraform plan shows correct policy count
- Verify terraform apply creates policies successfully
- Test Lambda invocation with granted permissions (e.g., DynamoDB access)
- Verify terraform destroy removes policies cleanly

**Integration Points:**
- Consume `local.parsed_config.provider.iamRoleStatements` from roadmap #1
- Consume `local.functions_with_defaults[func].iamRoleStatements` from roadmap #1
- Consume `local.service_name` for policy naming
- Consume `local.provider_with_defaults.stage` for policy naming
- Reference `aws_iam_role.lambda_execution[each.key]` from roadmap #2
- Extend validation_errors collection from roadmap #1 with IAM-specific errors

**Validation Integration:**
Add IAM validation errors to existing validation_errors local in locals.tf:

```hcl
locals {
  validation_errors = local.parsed_config == null ? [] : concat(
    # Existing validations from roadmap #1
    # ...

    # IAM statement validations (new)
    local.provider_iam_validation_errors,
    local.iam_validation_errors
  )
}
```

**Policy Document Structure:**
All generated policy documents must follow this exact structure:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["service:action"],
      "Resource": ["arn:aws:service:region:account:resource"]
    }
  ]
}
```

---

**This specification is ready for implementation.** Developers should reference the IAM role resources in roadmap item #2 implementation and the validation patterns from roadmap item #1 for consistent error handling and resource naming conventions.
