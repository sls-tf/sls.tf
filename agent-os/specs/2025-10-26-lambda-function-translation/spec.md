# Specification: Lambda Function Translation

## Overview

This specification defines the Lambda function translation module for sls.tf, which consumes the parsed Serverless Framework configuration (from roadmap item #1) and generates AWS Lambda function resources with associated IAM roles. This module translates Serverless Framework function definitions into native Terraform aws_lambda_function resources with proper runtime configuration, memory allocation, timeout settings, environment variables, and automatic IAM role provisioning.

**Roadmap Position:** Item #2 - Core resource provisioning foundation
**Dependencies:** Roadmap item #1 (Core Module Structure & YAML Parsing) - outputs consumed
**Target Completion:** Enable Lambda function deployment via Terraform from serverless.yml

## Goal

Transform Serverless Framework function definitions into fully-configured AWS Lambda functions with automatically provisioned IAM execution roles, supporting all standard Lambda properties and gracefully handling functionless configurations.

## User Stories

- As a developer, I want my Serverless Framework function definitions to automatically create Lambda functions in AWS via Terraform so that I maintain my familiar serverless.yml syntax while gaining Terraform's state management benefits
- As a platform engineer, I want Lambda functions to have proper IAM execution roles without manual configuration so that functions can execute and write logs to CloudWatch automatically
- As a migration architect, I want consistent function naming that follows Serverless Framework conventions (service-stage-function) so that existing monitoring and tooling continue to work during migration
- As a DevOps engineer, I want environment variables and function properties to be correctly mapped from serverless.yml to Lambda configuration so that application behavior remains consistent
- As an infrastructure team member, I want functionless configurations to be gracefully handled so that infrastructure-only deployments don't fail during Terraform plan/apply

## Core Requirements

### Functional Requirements

**Function Resource Generation:**
- Consume `functions` output from core module (roadmap item #1)
- Generate one `aws_lambda_function` resource per function definition
- Use Terraform `for_each` to iterate over `functions_with_defaults` map
- Support empty function maps (functionless configurations) without errors
- Derive function names following Serverless Framework convention: `{service}-{stage}-{function_key}`

**Lambda Function Properties Mapping:**
- **Runtime**: Use value from `functions_with_defaults[func_name].runtime` (already validated and inherited in module #1)
- **Handler**: Map from `functions_with_defaults[func_name].handler` (required field, validated in module #1)
- **Function name**: Construct as `{service_name}-{provider_config.stage}-{function_key}`
- **Memory size**: Use `functions_with_defaults[func_name].memorySize` (defaults applied in module #1)
- **Timeout**: Use `functions_with_defaults[func_name].timeout` (defaults applied in module #1)
- **Description**: Optional, map from `functions_with_defaults[func_name].description` if present
- **Environment variables**: Parse from `functions_with_defaults[func_name].environment` map (if present)
- **Role ARN**: Reference the auto-created IAM role for each function

**IAM Role Creation:**
- Generate one `aws_iam_role` per Lambda function
- Role name convention: `{service}-{stage}-{function_key}-role`
- Trust policy: Allow `lambda.amazonaws.com` service to assume the role
- Attach AWS managed policy: `arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionPolicy`
- Use `aws_iam_role_policy_attachment` to attach the managed policy

**IAM Trust Policy Document:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Code Deployment Strategy:**
- Use `archive_file` data source to package Lambda code
- Default packaging path: current directory (or configurable via variable)
- Generate ZIP archive with source code for deployment
- Support `source_code_hash` for change detection and redeployment
- Reference archive output in `aws_lambda_function.filename` attribute

**Environment Variables Handling:**
- Parse `environment` map from function definition (optional field)
- Map to `aws_lambda_function.environment.variables` block
- Only include environment block if variables exist (conditional block)
- Support both provider-level and function-level environment variables (future enhancement)

**Output Interface:**
- Output map of Lambda function ARNs: `{ function_key = arn }`
- Output map of Lambda function names: `{ function_key = name }`
- Output map of IAM role ARNs: `{ function_key = role_arn }`
- Output map of function invoke ARNs: `{ function_key = invoke_arn }` (for API Gateway integration)

### Module Integration

**Input from Core Module (Roadmap Item #1):**
- `service_name`: Used for function and role naming
- `provider_config`: Access `stage` for naming and `region` for deployment
- `functions_with_defaults`: Complete function definitions with all defaults applied

**Module Structure Enhancement:**
The Lambda translation logic will be added to the existing module structure:

```
sls.tf/
├── main.tf           # Add Lambda resources and IAM roles
├── variables.tf      # Add lambda_code_path variable
├── outputs.tf        # Add Lambda function outputs
├── versions.tf       # Add archive provider requirement
├── locals.tf         # Add Lambda-specific transformations
└── examples/
    └── lambda/       # New example with function deployment
```

**New Variables Required:**
- `lambda_code_path` (string, optional, default "."): Path to Lambda function code directory to package

**New Provider Requirement:**
- Archive provider: `hashicorp/archive >= 2.0` for ZIP generation

### Technical Approach

**Resource Generation Pattern:**

```hcl
# Archive each function's code
data "archive_file" "lambda_code" {
  for_each = module.serverless_parser.functions

  type        = "zip"
  source_dir  = var.lambda_code_path
  output_path = "${path.module}/.terraform/lambda-${each.key}.zip"
}

# Create IAM role for each function
resource "aws_iam_role" "lambda_execution" {
  for_each = module.serverless_parser.functions

  name = "${module.serverless_parser.service_name}-${module.serverless_parser.provider_config.stage}-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  for_each = module.serverless_parser.functions

  role       = aws_iam_role.lambda_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionPolicy"
}

# Create Lambda functions
resource "aws_lambda_function" "functions" {
  for_each = module.serverless_parser.functions

  function_name = "${module.serverless_parser.service_name}-${module.serverless_parser.provider_config.stage}-${each.key}"
  role          = aws_iam_role.lambda_execution[each.key].arn

  filename         = data.archive_file.lambda_code[each.key].output_path
  source_code_hash = data.archive_file.lambda_code[each.key].output_base64sha256

  runtime     = each.value.runtime
  handler     = each.value.handler
  memory_size = each.value.memorySize
  timeout     = each.value.timeout

  description = try(each.value.description, null)

  dynamic "environment" {
    for_each = try(each.value.environment, null) != null ? [1] : []
    content {
      variables = each.value.environment
    }
  }
}
```

**Function Naming Convention:**
- Pattern: `{service_name}-{stage}-{function_key}`
- Example: `example-service-dev-hello` for function key "hello"
- Matches Serverless Framework default naming
- Ensures uniqueness across stages and services

**IAM Role Naming Convention:**
- Pattern: `{service_name}-{stage}-{function_key}-role`
- Example: `example-service-dev-hello-role`
- Clear association between function and role
- Supports future custom role configurations (roadmap item #3)

**Code Packaging Strategy:**
- Use `archive_file` data source for dynamic ZIP generation
- Store ZIP files in `.terraform/` directory (ignored by git)
- Include `source_code_hash` for change detection
- Support multiple functions with separate archives
- Future enhancement: Honor `package.patterns` for include/exclude (out of scope)

**Environment Variable Handling:**
- Use dynamic block to conditionally include environment configuration
- Only create block if `environment` field exists in function definition
- Map all key-value pairs directly from serverless.yml to Lambda
- Future enhancement: Merge provider-level and function-level environment variables (out of scope)

**Functionless Configuration Handling:**
- `for_each` iterates over empty map when no functions defined
- No resources created when `functions_with_defaults` is empty
- Terraform plan shows zero resources to create
- Maintains compatibility with infrastructure-only deployments

## Reusable Components

### Existing Code to Leverage

**From Core Module (Roadmap Item #1):**
- `functions_with_defaults` output: Complete function definitions with all defaults applied and validation completed
- `service_name` output: For resource naming
- `provider_config` output: For stage and region information
- Validation framework: Runtime, handler, memory, timeout already validated

**Terraform Built-in Functions:**
- `jsonencode()`: Create IAM trust policy documents
- `try()`: Safely access optional fields (description, environment)
- `for_each`: Iterate over function map to create resources
- Dynamic blocks: Conditionally include environment configuration

### New Components Required

**Lambda Resource Generation:**
- aws_lambda_function resource declarations with for_each iteration
- Required because: Core Lambda provisioning capability

**IAM Role Provisioning:**
- aws_iam_role resource for Lambda execution
- aws_iam_role_policy_attachment for basic execution policy
- Required because: Lambda functions require execution roles for logging and invocation

**Code Packaging:**
- archive_file data source for ZIP generation
- Required because: Lambda requires packaged deployment artifacts

**Output Mapping:**
- Lambda ARN, name, invoke ARN, and role ARN outputs
- Required because: Downstream integrations (API Gateway, EventBridge) need function references

## Technical Constraints

**Terraform Compatibility:**
- Must work with Terraform 1.13.4+ (inherited from module #1)
- Must work with AWS provider 6.0+ (inherited from module #1)
- Must use archive provider 2.0+ for ZIP generation

**AWS Provider Constraints:**
- Lambda function names limited to 64 characters
- Function naming must be DNS-compliant (lowercase, hyphens)
- IAM role names limited to 64 characters
- Memory size range: 128-10240 MB (validated in module #1)
- Timeout range: 1-900 seconds (validated in module #1)

**Implementation Constraints:**
- Must maintain pure HCL implementation (no external scripts)
- Must support functionless configurations gracefully
- Must not modify or re-validate configuration (trust module #1 outputs)
- Must follow Terraform best practices for resource dependencies

**Serverless Framework Compatibility:**
- Function naming must match Serverless Framework conventions
- Property mapping must preserve Serverless Framework behavior
- Environment variable handling must match framework semantics

## Out of Scope

### Excluded from This Feature

**Custom IAM Policies:**
- Translation of `iamRoleStatements` from serverless.yml
- Custom IAM policy document generation
- Role ARN references and cross-account permissions
- Deferred to roadmap item #3 (IAM Role & Policy Management)

**Event Source Integrations:**
- API Gateway HTTP event configuration
- S3 bucket notification triggers
- EventBridge/CloudWatch event rules
- DynamoDB/SQS event source mappings
- All event sources deferred to roadmap items #4, #5, #7, #8

**Advanced Packaging:**
- Package patterns (include/exclude) from `package.patterns`
- Individual function packaging configuration
- External package artifacts (pre-built ZIPs)
- Lambda layers support
- Future enhancement (not on current roadmap)

**Lambda Configuration Advanced Features:**
- VPC configuration (subnets, security groups)
- Dead letter queue configuration
- Reserved concurrent executions
- Provisioned concurrency
- File system configurations (EFS)
- X-Ray tracing configuration
- Future enhancement (consider for roadmap expansion)

**Provider-Level Environment Variables:**
- Merging provider.environment with function.environment
- Global environment variable inheritance
- Future enhancement (not explicitly in roadmap item description)

**Variable Resolution:**
- Serverless variable syntax (`${self:}`, `${env:}`, etc.)
- Deferred to roadmap item #10

**Deployment Configuration:**
- Versioning and aliases
- Traffic shifting and canary deployments
- Deployment preferences
- Future enhancement (not on current roadmap)

**Multi-Region Deployment:**
- Deploying same functions to multiple regions
- Cross-region replication
- Future enhancement (consider for roadmap expansion)

## Success Criteria

**Resource Generation Success:**
- Module generates aws_lambda_function resources for each function in serverless.yml
- Generated functions have correct runtime, handler, memory, timeout, description
- Function naming follows Serverless Framework convention: `{service}-{stage}-{function_key}`
- Functionless configurations complete successfully with zero resources created

**IAM Role Success:**
- Each Lambda function has an associated aws_iam_role created
- IAM roles have correct trust policy for lambda.amazonaws.com
- Basic execution policy (AWSLambdaBasicExecutionPolicy) attached to each role
- Role naming follows convention: `{service}-{stage}-{function_key}-role`
- Lambda functions reference the correct IAM role ARN

**Code Packaging Success:**
- archive_file data source generates ZIP packages for each function
- ZIP files stored in `.terraform/` directory
- source_code_hash enables change detection
- Lambda functions reference correct package files

**Environment Variable Success:**
- Functions with environment variables have environment block configured
- Environment variables correctly mapped from serverless.yml
- Functions without environment variables have no environment block
- All key-value pairs preserved from configuration

**Property Mapping Success:**
- Runtime inherited from provider or function level (validated by module #1)
- Memory size uses function override or provider default
- Timeout uses function override or provider default
- Optional description field mapped when present
- All properties match Serverless Framework behavior

**Output Interface Success:**
- Function ARNs output as map keyed by function name
- Function names output as map keyed by function name
- IAM role ARNs output as map keyed by function name
- Invoke ARNs output for downstream API Gateway integration
- Outputs accessible to subsequent roadmap item implementations

**Terraform Best Practices Success:**
- Resources created with proper dependencies (role before function)
- for_each iteration maintains idempotency
- Resource naming avoids collisions
- No hardcoded values (all derived from configuration)
- Terraform plan deterministic and repeatable

**Integration Success:**
- Module consumes outputs from roadmap item #1 without modification
- Generated resources compatible with future event source integrations
- Function ARNs ready for API Gateway, EventBridge, S3 event consumption
- IAM role structure supports future policy attachment (roadmap item #3)

## Testing Requirements

While test implementation is out of scope for this specification, the following test scenarios must be covered:

**Valid Configuration Tests:**
- Generate Lambda resources for single-function configuration
- Generate Lambda resources for multi-function configuration
- Handle functionless configuration (zero resources created)
- Process function with all optional properties (description, environment)
- Process function with minimal required properties (handler, runtime)

**Property Mapping Tests:**
- Verify runtime mapped correctly from function definition
- Verify memory size uses function override or provider default
- Verify timeout uses function override or provider default
- Verify handler mapped correctly
- Verify description included when present, null when absent

**IAM Role Tests:**
- Verify one IAM role created per function
- Verify role trust policy allows lambda.amazonaws.com
- Verify AWSLambdaBasicExecutionPolicy attached
- Verify role ARN referenced by Lambda function
- Verify role naming convention followed

**Code Packaging Tests:**
- Verify archive_file data source created per function
- Verify ZIP output path in .terraform/ directory
- Verify source_code_hash populated
- Verify Lambda function references correct package

**Environment Variable Tests:**
- Verify environment block created when variables present
- Verify all environment key-value pairs mapped correctly
- Verify no environment block when variables absent
- Verify empty environment map handled gracefully

**Naming Convention Tests:**
- Verify function name format: `{service}-{stage}-{function_key}`
- Verify role name format: `{service}-{stage}-{function_key}-role`
- Verify naming handles special characters in function keys
- Verify naming consistent across all resources

**Output Tests:**
- Verify function_arns map contains all functions
- Verify function_names map contains all functions
- Verify role_arns map contains all roles
- Verify invoke_arns map contains all functions
- Verify empty maps when no functions defined

**Integration Tests:**
- Verify module consumes roadmap item #1 outputs correctly
- Verify generated resources valid for terraform plan
- Verify terraform apply creates actual AWS resources
- Verify resources match serverless.yml configuration
- Verify resources deletable via terraform destroy

## Non-Functional Requirements

**Maintainability:**
- Clear resource naming patterns for debugging
- Descriptive comments for IAM policy documents
- Logical grouping of related resources (role, policy attachment, function)
- Consistent use of for_each across all resources

**Extensibility:**
- IAM role structure supports future custom policy attachment (roadmap #3)
- Function resource supports future event source additions (roadmap #4-8)
- Code packaging supports future layer and artifact enhancements
- Output interface extensible for additional function metadata

**Performance:**
- Resource generation completes during Terraform plan phase
- for_each iteration efficient for large function counts
- ZIP generation only occurs when source code changes
- No unnecessary resource recreation on plan/apply

**Security:**
- IAM roles follow principle of least privilege (basic execution only)
- No secrets or sensitive data in function configuration (use environment variables)
- Trust policy scoped to lambda.amazonaws.com service only
- Future: Support for custom policies (roadmap item #3)

**Compatibility:**
- Works with existing module structure from roadmap item #1
- Compatible with future event source integrations (roadmap items #4-8)
- Follows Terraform AWS provider best practices
- Maintains Serverless Framework naming conventions

**Documentation:**
- Clear variable descriptions for lambda_code_path
- Clear output descriptions for ARN maps
- Comments explaining IAM trust policy structure
- Example configuration demonstrating Lambda deployment

## Dependencies and Assumptions

**Dependencies:**
- Roadmap item #1 (Core Module Structure & YAML Parsing) must be complete
- Outputs required: `service_name`, `provider_config`, `functions_with_defaults`
- Terraform 1.13.4+ installed
- AWS provider 6.0+ configured
- Archive provider 2.0+ available
- AWS credentials configured for Lambda and IAM resource creation

**Assumptions:**
- Lambda function code exists at `lambda_code_path` location
- All functions in serverless.yml can use the same code package (single-repo deployment)
- Runtime, handler, memory, timeout already validated by module #1
- No custom IAM policies needed initially (roadmap item #3 will add this)
- Basic execution permissions sufficient for initial Lambda invocation and logging
- Function keys in serverless.yml are valid Terraform resource identifiers
- Service name and stage combination produces unique function names within AWS account/region

**Future Considerations:**
- Individual function code paths will require enhanced packaging logic
- Lambda layers will require additional data sources and resource attributes
- VPC configuration will require network infrastructure dependencies
- Event source integrations will add aws_lambda_permission resources (roadmap #4-8)
- Custom IAM policies will extend the IAM role configuration (roadmap #3)
- Multi-region deployment will require provider aliasing and resource duplication

## Example Configurations

### Example 1: Simple Lambda Function

**Input (serverless.yml):**
```yaml
service: my-service
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev
  region: us-east-1

functions:
  hello:
    handler: index.handler
    description: Simple hello function
```

**Expected Terraform Resources:**
```hcl
# Generated IAM Role
resource "aws_iam_role" "lambda_execution" {
  name = "my-service-dev-hello-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Policy Attachment
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "my-service-dev-hello-role"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionPolicy"
}

# Lambda Function
resource "aws_lambda_function" "functions" {
  function_name = "my-service-dev-hello"
  role          = aws_iam_role.lambda_execution["hello"].arn

  filename         = ".terraform/lambda-hello.zip"
  source_code_hash = "<computed>"

  runtime     = "nodejs18.x"
  handler     = "index.handler"
  memory_size = 1024
  timeout     = 6

  description = "Simple hello function"
}
```

### Example 2: Function with Environment Variables

**Input (serverless.yml):**
```yaml
service: api-service
provider:
  name: aws
  runtime: python3.11
  stage: prod
  region: us-west-2
  memorySize: 512
  timeout: 30

functions:
  process:
    handler: app.process_handler
    environment:
      TABLE_NAME: users-table
      API_KEY: ${env:API_KEY}
```

**Expected Terraform Resources:**
```hcl
resource "aws_lambda_function" "functions" {
  function_name = "api-service-prod-process"
  role          = aws_iam_role.lambda_execution["process"].arn

  filename         = ".terraform/lambda-process.zip"
  source_code_hash = "<computed>"

  runtime     = "python3.11"
  handler     = "app.process_handler"
  memory_size = 512
  timeout     = 30

  environment {
    variables = {
      TABLE_NAME = "users-table"
      API_KEY    = "${env:API_KEY}"  # Variable resolution not yet implemented
    }
  }
}
```

### Example 3: Multiple Functions with Overrides

**Input (serverless.yml):**
```yaml
service: multi-func
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev
  memorySize: 1024

functions:
  fast:
    handler: fast.handler
    memorySize: 2048
    timeout: 10

  slow:
    handler: slow.handler
    runtime: python3.11
    timeout: 60
```

**Expected Resources:**
```hcl
# Two IAM roles created
resource "aws_iam_role" "lambda_execution" {
  for_each = {
    fast = { ... }
    slow = { ... }
  }
  name = "multi-func-dev-${each.key}-role"
  # ... trust policy
}

# Two Lambda functions created
resource "aws_lambda_function" "functions" {
  for_each = {
    fast = {
      runtime    = "nodejs18.x"  # inherited
      handler    = "fast.handler"
      memorySize = 2048           # override
      timeout    = 10             # override
    }
    slow = {
      runtime    = "python3.11"   # override
      handler    = "slow.handler"
      memorySize = 1024           # inherited
      timeout    = 60             # override
    }
  }

  function_name = "multi-func-dev-${each.key}"
  runtime       = each.value.runtime
  handler       = each.value.handler
  memory_size   = each.value.memorySize
  timeout       = each.value.timeout
  # ... other attributes
}
```

### Example 4: Functionless Configuration

**Input (serverless.yml):**
```yaml
service: infrastructure-only
provider:
  name: aws
  runtime: nodejs18.x
  stage: dev

resources:
  Resources:
    MyBucket:
      Type: AWS::S3::Bucket
```

**Expected Behavior:**
- No Lambda functions created
- No IAM roles created
- Terraform plan shows zero resources for Lambda module
- No errors or failures
- Future roadmap item #9 will handle resources section

## Implementation Notes

**Development Order:**
1. Add archive provider to versions.tf
2. Add lambda_code_path variable to variables.tf
3. Add archive_file data source for code packaging
4. Add aws_iam_role resources with for_each
5. Add aws_iam_role_policy_attachment resources
6. Add aws_lambda_function resources with for_each
7. Add outputs for function ARNs, names, roles, invoke ARNs
8. Test with examples/basic/serverless.yml
9. Create examples/lambda/ with multi-function configuration
10. Verify functionless configuration handling

**Key Implementation Challenges:**
- Ensuring IAM roles created before Lambda functions (implicit dependency via role ARN reference)
- Conditionally including environment block (use dynamic block with for_each)
- Handling empty function maps gracefully (for_each on empty map creates no resources)
- Managing ZIP file paths and cleanup (store in .terraform/ directory, add to .gitignore)
- Preserving function key as resource identifier (use each.key throughout)

**Code Quality Guidelines:**
- Run `terraform fmt` on all modified .tf files
- Use descriptive resource names (lambda_execution, not just role)
- Add comments for IAM policy documents explaining permissions
- Keep resource blocks readable with consistent attribute ordering
- Follow Terraform naming conventions (snake_case)

**Testing Approach:**
- Test with examples/basic/serverless.yml (single function)
- Create examples/lambda/serverless.yml (multiple functions, overrides, environment vars)
- Test functionless configuration (no functions defined)
- Verify terraform plan output shows correct resource count
- Verify terraform apply creates actual AWS resources
- Verify function invocation works with basic execution role
- Test terraform destroy removes all resources cleanly

**Integration Points:**
- Consume `module.serverless_parser.functions` (from roadmap item #1)
- Consume `module.serverless_parser.service_name` for naming
- Consume `module.serverless_parser.provider_config` for stage
- Output function ARNs for roadmap items #4, #5, #7, #8 (event sources)
- Output role ARNs for roadmap item #3 (custom IAM policies)

---

**This specification is ready for implementation.** Developers should reference the core module implementation in `/home/tom/p/t/sls.tf/` for integration patterns and consult roadmap item #1 specification for output interface details.
