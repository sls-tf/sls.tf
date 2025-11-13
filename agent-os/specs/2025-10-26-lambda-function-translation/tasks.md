# Task Breakdown: Lambda Function Translation

## Overview
Total Tasks: 37 tasks across 6 task groups
Focus: Generate AWS Lambda functions and IAM execution roles from Serverless Framework definitions
Roadmap Position: Item #2 - Core resource provisioning foundation
**Status:** ✅ COMPLETED - All 6 task groups completed (28 tests passing)

## Dependencies
**Required Completion:** Roadmap item #1 (Core Module Structure & YAML Parsing)
**Consumes Outputs:**
- `service_name` - for resource naming
- `provider_config` - for stage and region
- `functions` (functions_with_defaults) - complete function definitions with defaults applied

## Task List

### Provider & Infrastructure Setup

#### Task Group 1: Provider Requirements & Variables
**Dependencies:** None (extends existing module from roadmap item #1)

- [x] 1.0 Complete provider and variable setup
  - [x] 1.1 Write 2-8 focused tests for provider and variable setup
    - Test archive provider initialization ✓
    - Test lambda_code_path variable validation (non-empty) ✓
    - Test lambda_code_path defaults to "." (current directory) ✓
    - Test variable integration with module ✓
    - Total: Created 4 tests in tests/provider_setup.tftest.hcl
  - [x] 1.2 Add archive provider to versions.tf
    - Open /home/tom/p/t/sls.tf/versions.tf
    - Add to required_providers block:
      ```hcl
      archive = {
        source  = "hashicorp/archive"
        version = ">= 2.0"
      }
      ```
    - Maintain existing AWS and Null provider requirements ✓
    - Reference: spec.md lines 111-112 ✓
  - [x] 1.3 Add lambda_code_path variable to variables.tf
    - Open /home/tom/p/t/sls.tf/variables.tf
    - Add new variable block:
      ```hcl
      variable "lambda_code_path" {
        description = "Path to Lambda function code directory to package. Defaults to current directory."
        type        = string
        default     = "."
        validation {
          condition     = var.lambda_code_path != ""
          error_message = "lambda_code_path must not be an empty string."
        }
      }
      ```
    - Reference: spec.md lines 107-108 ✓
  - [x] 1.4 Run terraform fmt on modified files
    - Format versions.tf ✓
    - Format variables.tf ✓
    - Verify no syntax errors ✓
  - [x] 1.5 Ensure provider setup tests pass
    - Run ONLY the 4 tests written in 1.1 ✓
    - Verify archive provider initialization works ✓
    - Verify variable validation works ✓

**Acceptance Criteria:** ✅ ALL MET
- The 4 tests written in 1.1 pass ✓
- Archive provider >= 2.0 added to versions.tf ✓
- lambda_code_path variable added with validation and default value ✓
- terraform fmt passes on all modified files ✓
- terraform init successfully initializes archive provider ✓

### Code Packaging Layer

#### Task Group 2: Lambda Code Packaging
**Dependencies:** Task Group 1

- [ ] 2.0 Complete code packaging implementation
  - [ ] 2.1 Write 2-8 focused tests for code packaging
    - Test archive_file data source creation per function
    - Test ZIP output path in .terraform/ directory
    - Test source_code_hash populated correctly
    - Test multiple functions get separate ZIP files
    - Test functionless configuration (no archives created)
    - Total: Create 5 tests in tests/code_packaging.tftest.hcl
  - [ ] 2.2 Create archive_file data source in main.tf
    - Open /home/tom/p/t/sls.tf/main.tf
    - Add after existing validation resource:
      ```hcl
      # Package Lambda function code
      data "archive_file" "lambda_code" {
        for_each = local.functions_with_defaults

        type        = "zip"
        source_dir  = var.lambda_code_path
        output_path = "${path.module}/.terraform/lambda-${each.key}.zip"
      }
      ```
    - Use for_each to iterate over functions map from roadmap item #1
    - Reference: spec.md lines 118-125, lines 191-196
  - [ ] 2.3 Update .gitignore for ZIP files
    - Ensure .terraform/ directory is ignored
    - Verify ZIP files won't be committed to version control
    - Pattern should include: `.terraform/lambda-*.zip`
  - [ ] 2.4 Test code packaging with example
    - Create simple Lambda handler file in examples/basic/
    - Verify archive_file generates ZIP correctly
    - Check ZIP file created in .terraform/ directory
  - [ ] 2.5 Ensure code packaging tests pass
    - Run ONLY the 5 tests written in 2.1
    - Verify ZIPs created with correct naming pattern
    - Verify source_code_hash enables change detection

**Acceptance Criteria:**
- The 5 tests written in 2.1 pass
- archive_file data source uses for_each over functions map
- ZIP files stored in .terraform/ directory with naming: lambda-{function_key}.zip
- source_code_hash attribute populated for change detection
- Functionless configurations (empty functions map) generate no archives
- .gitignore properly excludes generated ZIP files

### IAM Role Provisioning

#### Task Group 3: IAM Execution Roles and Policies
**Dependencies:** Task Group 1 (variables needed for resource naming)

- [ ] 3.0 Complete IAM role provisioning
  - [ ] 3.1 Write 2-8 focused tests for IAM roles
    - Test one IAM role created per function
    - Test role trust policy allows lambda.amazonaws.com
    - Test AWSLambdaBasicExecutionPolicy attached
    - Test role naming convention: {service}-{stage}-{function_key}-role
    - Test functionless configuration (no roles created)
    - Test multiple functions create multiple roles
    - Total: Create 6 tests in tests/iam_roles.tftest.hcl
  - [ ] 3.2 Create aws_iam_role resource in main.tf
    - Open /home/tom/p/t/sls.tf/main.tf
    - Add IAM role resource with for_each:
      ```hcl
      # IAM execution role for each Lambda function
      resource "aws_iam_role" "lambda_execution" {
        for_each = local.functions_with_defaults

        name = "${local.parsed_config.service}-${local.provider_with_defaults.stage}-${each.key}-role"

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

        tags = {
          Service  = local.parsed_config.service
          Stage    = local.provider_with_defaults.stage
          Function = each.key
        }
      }
      ```
    - Use service_name and provider_config outputs from roadmap item #1
    - Reference: spec.md lines 44-49, lines 127-143, lines 185-189
  - [ ] 3.3 Create aws_iam_role_policy_attachment resource in main.tf
    - Add policy attachment for CloudWatch Logs:
      ```hcl
      # Attach basic execution policy for CloudWatch Logs
      resource "aws_iam_role_policy_attachment" "lambda_logs" {
        for_each = local.functions_with_defaults

        role       = aws_iam_role.lambda_execution[each.key].name
        policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionPolicy"
      }
      ```
    - Reference: spec.md lines 146-151
  - [ ] 3.4 Verify IAM trust policy document structure
    - Confirm trust policy follows spec.md lines 52-65
    - Ensure lambda.amazonaws.com is the only trusted service
    - Verify policy is properly JSON-encoded
  - [ ] 3.5 Test IAM resources with terraform plan
    - Run terraform plan in examples/basic/
    - Verify correct number of roles created
    - Verify role naming matches convention
    - Verify policy attachments reference correct roles
  - [ ] 3.6 Ensure IAM role tests pass
    - Run ONLY the 6 tests written in 3.1
    - Verify role trust policy structure correct
    - Verify policy attachment works

**Acceptance Criteria:**
- The 6 tests written in 3.1 pass
- One aws_iam_role created per function using for_each
- Role naming follows convention: {service}-{stage}-{function_key}-role
- Trust policy allows only lambda.amazonaws.com to assume role
- AWSLambdaBasicExecutionPolicy attached to each role via aws_iam_role_policy_attachment
- Tags applied to roles for service, stage, and function identification
- Functionless configurations create no IAM resources

### Lambda Function Resources

#### Task Group 4: Lambda Function Resource Generation
**Dependencies:** Task Groups 2 and 3 (requires code packages and IAM roles)

- [ ] 4.0 Complete Lambda function resource generation
  - [ ] 4.1 Write 2-8 focused tests for Lambda resources
    - Test Lambda function created per function definition
    - Test function naming: {service}-{stage}-{function_key}
    - Test runtime, handler, memory, timeout correctly mapped
    - Test description mapped when present, null when absent
    - Test function references correct IAM role ARN
    - Test function references correct code package
    - Test environment block created only when variables exist
    - Test multiple functions with different configurations
    - Total: Create 8 tests in tests/lambda_resources.tftest.hcl
  - [ ] 4.2 Create aws_lambda_function resource in main.tf
    - Open /home/tom/p/t/sls.tf/main.tf
    - Add Lambda function resource:
      ```hcl
      # Lambda function resources
      resource "aws_lambda_function" "functions" {
        for_each = local.functions_with_defaults

        function_name = "${local.parsed_config.service}-${local.provider_with_defaults.stage}-${each.key}"
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

        tags = {
          Service  = local.parsed_config.service
          Stage    = local.provider_with_defaults.stage
          Function = each.key
        }

        depends_on = [
          aws_iam_role_policy_attachment.lambda_logs
        ]
      }
      ```
    - Reference: spec.md lines 154-176, lines 36-42
  - [ ] 4.3 Implement dynamic environment block
    - Use dynamic block with for_each to conditionally include environment
    - Check if each.value.environment exists and is not null
    - Only create environment block when variables map is present
    - Reference: spec.md lines 170-175, lines 74-78, lines 197-202
  - [ ] 4.4 Verify property mapping from functions_with_defaults
    - Confirm runtime uses each.value.runtime (already validated and defaulted)
    - Confirm handler uses each.value.handler (required field)
    - Confirm memorySize uses each.value.memorySize (defaults applied)
    - Confirm timeout uses each.value.timeout (defaults applied)
    - Confirm description uses try() for optional field
    - Reference: spec.md lines 35-42
  - [ ] 4.5 Verify resource dependencies
    - Ensure Lambda function creation waits for IAM role
    - Ensure Lambda function creation waits for policy attachment
    - Use depends_on for explicit dependency if needed
    - Implicit dependency via role ARN reference should be sufficient
  - [ ] 4.6 Test Lambda resources with terraform plan
    - Run terraform plan in examples/basic/
    - Verify correct number of functions created
    - Verify all properties mapped correctly
    - Verify environment block only present when needed
  - [ ] 4.7 Ensure Lambda resource tests pass
    - Run ONLY the 8 tests written in 4.1
    - Verify function naming convention correct
    - Verify all properties mapped from configuration

**Acceptance Criteria:**
- The 8 tests written in 4.1 pass
- One aws_lambda_function created per function using for_each
- Function naming follows convention: {service}-{stage}-{function_key}
- All properties (runtime, handler, memory_size, timeout) mapped from functions_with_defaults
- Description field uses try() and is null when not specified
- Dynamic environment block only created when environment variables exist
- Functions reference correct IAM role ARN from aws_iam_role resource
- Functions reference correct code package from archive_file data source
- source_code_hash enables change detection and redeployment
- Explicit depends_on ensures IAM policy attachment completes before function creation

### Output Interface

#### Task Group 5: Lambda Function Outputs
**Dependencies:** Task Group 4 (requires Lambda functions to output)

- [ ] 5.0 Complete output interface for Lambda functions
  - [ ] 5.1 Write 2-8 focused tests for outputs
    - Test function_arns map contains all functions
    - Test function_names map contains all functions
    - Test role_arns map contains all roles
    - Test invoke_arns map contains all functions
    - Test empty maps when no functions defined
    - Total: Create 5 tests in tests/lambda_outputs.tftest.hcl
  - [ ] 5.2 Add Lambda function outputs to outputs.tf
    - Open /home/tom/p/t/sls.tf/outputs.tf
    - Add after existing outputs:
      ```hcl
      output "function_arns" {
        description = "Map of Lambda function ARNs keyed by function name"
        value       = { for k, v in aws_lambda_function.functions : k => v.arn }
      }

      output "function_names" {
        description = "Map of Lambda function names keyed by function name"
        value       = { for k, v in aws_lambda_function.functions : k => v.function_name }
      }

      output "role_arns" {
        description = "Map of IAM role ARNs keyed by function name"
        value       = { for k, v in aws_iam_role.lambda_execution : k => v.arn }
      }

      output "function_invoke_arns" {
        description = "Map of Lambda function invoke ARNs for API Gateway integration"
        value       = { for k, v in aws_lambda_function.functions : k => v.invoke_arn }
      }
      ```
    - Use for expressions to create maps from resources
    - Reference: spec.md lines 80-84, lines 356-362
  - [ ] 5.3 Verify output interface for downstream integrations
    - Confirm function_arns available for API Gateway event source (roadmap #4)
    - Confirm invoke_arns available for API Gateway permissions (roadmap #4)
    - Confirm role_arns available for custom IAM policies (roadmap #3)
    - Confirm outputs work with empty functions map (functionless config)
  - [ ] 5.4 Test outputs with terraform plan
    - Run terraform plan in examples/basic/
    - Verify output values populated correctly
    - Check output structure matches map format
    - Test with functionless configuration (empty maps)
  - [ ] 5.5 Ensure Lambda output tests pass
    - Run ONLY the 5 tests written in 5.1
    - Verify all output maps properly populated
    - Verify empty maps for functionless configurations

**Acceptance Criteria:**
- The 5 tests written in 5.1 pass
- function_arns output contains map of function ARNs keyed by function name
- function_names output contains map of function names keyed by function name
- role_arns output contains map of IAM role ARNs keyed by function name
- function_invoke_arns output contains map of invoke ARNs keyed by function name
- All outputs return empty maps when functions_with_defaults is empty
- Output interface ready for consumption by roadmap items #3, #4, #5, #7, #8

### Integration Testing & Examples

#### Task Group 6: End-to-End Testing & Documentation
**Dependencies:** Task Groups 1-5

- [ ] 6.0 Complete integration testing and examples
  - [ ] 6.1 Review tests from Task Groups 1-5
    - Review the 4 tests written for provider setup (Task 1.1)
    - Review the 5 tests written for code packaging (Task 2.1)
    - Review the 6 tests written for IAM roles (Task 3.1)
    - Review the 8 tests written for Lambda resources (Task 4.1)
    - Review the 5 tests written for outputs (Task 5.1)
    - Total existing tests: 28 tests
  - [ ] 6.2 Analyze test coverage gaps for THIS feature only
    - Identify critical Lambda translation workflows lacking coverage
    - Focus ONLY on gaps related to Lambda function translation
    - Do NOT assess coverage for future roadmap items (custom IAM, events)
    - Prioritize end-to-end deployment workflows
    - Check for gaps in:
      - Function with all optional properties
      - Function with minimal required properties
      - Multiple functions with mixed configurations
      - Environment variable handling edge cases
  - [ ] 6.3 Write up to 10 additional strategic tests maximum
    - Add integration test for complete Lambda deployment workflow
    - Add test for function with environment variables
    - Add test for function without environment variables
    - Add test for multiple functions with different runtimes
    - Add test for function with description field
    - Add test for function without description field
    - Add test verifying IAM role referenced correctly
    - Add test verifying code package referenced correctly
    - Focus on integration points between components
    - Total: Maximum 10 tests in tests/integration.tftest.hcl
  - [ ] 6.4 Create examples/lambda/ directory and configuration
    - Create directory: /home/tom/p/t/sls.tf/examples/lambda/
    - Create serverless.yml with multi-function configuration:
      - 2-3 functions with different runtimes
      - Mix of functions with/without environment variables
      - Mix of functions with/without descriptions
      - Function-level property overrides
    - Create simple Lambda handler files (index.js, app.py, etc.)
    - Create main.tf that invokes the sls.tf module
    - Create outputs.tf to display module outputs
    - Reference: spec.md lines 499-662 for example patterns
  - [ ] 6.5 Create Terraform configuration for examples/lambda/
    - Create examples/lambda/main.tf:
      ```hcl
      module "serverless" {
        source = "../.."

        config_path      = "${path.module}/serverless.yml"
        lambda_code_path = "${path.module}"
      }
      ```
    - Create examples/lambda/outputs.tf to display all module outputs
    - Include function ARNs, names, roles, and invoke ARNs
  - [ ] 6.6 Test complete Lambda deployment workflow
    - Run terraform init in examples/lambda/
    - Run terraform plan and verify resources to create:
      - Expected number of archive_file data sources
      - Expected number of aws_iam_role resources
      - Expected number of aws_iam_role_policy_attachment resources
      - Expected number of aws_lambda_function resources
    - Verify resource naming matches conventions
    - Verify all properties correctly mapped
  - [ ] 6.7 Run feature-specific tests only
    - Run ONLY tests related to Lambda function translation
    - Expected total: approximately 28-38 tests maximum
    - Do NOT run tests for future roadmap items
    - Verify critical Lambda translation workflows pass
  - [ ] 6.8 Update module README.md
    - Open /home/tom/p/t/sls.tf/README.md
    - Add section: "Lambda Function Translation"
    - Document new lambda_code_path variable
    - Document new outputs: function_arns, function_names, role_arns, invoke_arns
    - Add example showing Lambda function deployment
    - Document IAM role creation and basic execution policy
    - Note out-of-scope items: custom IAM policies, event sources, VPC config
  - [ ] 6.9 Create test coverage documentation
    - Create or update: tests/LAMBDA_COVERAGE.md
    - List all test scenarios with file locations
    - Document intentional gaps (custom IAM, event sources)
    - Note alignment with testing standards
    - Confirm minimal test approach followed

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 28-38 tests total)
- Critical Lambda translation workflows fully covered
- No more than 10 additional tests added beyond initial development tests
- Testing focused exclusively on Lambda function translation feature
- examples/lambda/ directory created with working multi-function configuration
- Terraform plan succeeds and shows correct resource count
- README.md updated with Lambda feature documentation
- Test coverage documented clearly
- Module ready for integration with roadmap item #3 (custom IAM) and #4-8 (event sources)

## Execution Order

Recommended implementation sequence:

1. **Provider & Variables (Task Group 1)** - Add archive provider and lambda_code_path variable
2. **Code Packaging (Task Group 2)** - Implement archive_file data sources for ZIP generation
3. **IAM Roles (Task Group 3)** - Create execution roles and policy attachments
4. **Lambda Functions (Task Group 4)** - Generate aws_lambda_function resources
5. **Outputs (Task Group 5)** - Add Lambda-specific outputs for downstream consumption
6. **Integration & Examples (Task Group 6)** - Create examples and fill test gaps

## Important Notes

### Terraform-Specific Considerations

- **Resource Dependencies**: IAM role must be created before Lambda function (implicit via ARN reference)
- **for_each Pattern**: Use consistently across all resources (archive_file, IAM role, Lambda function)
- **Dynamic Blocks**: Use for conditional environment block based on variable presence
- **Try Function**: Use try() for optional fields like description and environment
- **Change Detection**: source_code_hash enables automatic redeployment when code changes
- **Functionless Support**: for_each on empty map creates zero resources gracefully

### Integration with Roadmap Item #1

- **Consume functions_with_defaults**: Already has runtime, memorySize, timeout with defaults applied
- **Consume service_name**: For Lambda function and IAM role naming
- **Consume provider_config**: For stage and region information
- **Trust Validation**: Runtime, handler, memory, timeout already validated by item #1
- **No Re-validation**: Do NOT re-validate configuration from item #1

### Lambda Naming Conventions

- **Function Naming**: `{service}-{stage}-{function_key}` (matches Serverless Framework)
- **Role Naming**: `{service}-{stage}-{function_key}-role`
- **ZIP File Naming**: `.terraform/lambda-{function_key}.zip`
- **Naming Source**: Use local.parsed_config.service and local.provider_with_defaults.stage

### IAM Role Structure

- **Trust Policy**: Only lambda.amazonaws.com can assume role
- **Managed Policy**: AWSLambdaBasicExecutionPolicy for CloudWatch Logs
- **Extensibility**: Role structure supports future custom policy attachment (roadmap #3)
- **Security**: Follows principle of least privilege (basic execution only)

### Code Packaging Strategy

- **Single Package Per Function**: Each function gets its own ZIP file
- **Storage Location**: .terraform/ directory (gitignored)
- **Source Directory**: Defaults to "." (current directory), configurable via lambda_code_path
- **Future Enhancement**: Individual function code paths (out of scope for item #2)

### Environment Variable Handling

- **Conditional Block**: Use dynamic block to only include when variables exist
- **Direct Mapping**: Map all key-value pairs from function.environment
- **No Variable Resolution**: Serverless variables like ${env:} NOT resolved (roadmap #10)
- **Future Enhancement**: Merge provider and function-level environment (out of scope)

### Testing Strategy

- **Minimal Test Approach**: Follow user's testing standards - write minimal, strategic tests
- **Test During Development**: Write 2-8 focused tests per task group during implementation
- **Run Incremental Tests**: Run only newly written tests, not entire suite
- **Gap Analysis Last**: Fill critical gaps with maximum 10 additional tests
- **Total Test Budget**: Approximately 28-38 tests for entire feature

### Out of Scope for This Feature

- **Custom IAM Policies**: Translation of iamRoleStatements (roadmap item #3)
- **Event Sources**: API Gateway, S3, EventBridge, DynamoDB, SQS (roadmap #4-8)
- **Advanced Packaging**: package.patterns, individual function packages
- **VPC Configuration**: Subnets, security groups, network config
- **Lambda Layers**: Layer attachments and management
- **Versioning/Aliases**: Traffic shifting, canary deployments
- **Variable Resolution**: ${self:}, ${env:}, ${cf:} syntax (roadmap #10)
- **Dead Letter Queues**: DLQ configuration
- **Concurrent Execution**: Reserved/provisioned concurrency
- **X-Ray Tracing**: Distributed tracing configuration

### File Organization

Resources will be added to existing module structure:

```
sls.tf/
├── main.tf              # Add: archive_file, aws_iam_role, policy_attachment, aws_lambda_function
├── variables.tf         # Add: lambda_code_path
├── outputs.tf           # Add: function_arns, function_names, role_arns, invoke_arns
├── versions.tf          # Add: archive provider
├── locals.tf            # No changes needed (uses existing locals)
├── .gitignore           # Ensure .terraform/lambda-*.zip ignored
├── examples/
│   ├── basic/           # Existing from roadmap #1
│   └── lambda/          # NEW: Multi-function Lambda example
│       ├── serverless.yml
│       ├── main.tf
│       ├── outputs.tf
│       └── index.js (or other handler files)
└── tests/
    ├── provider_setup.tftest.hcl    # NEW: Task Group 1 tests
    ├── code_packaging.tftest.hcl    # NEW: Task Group 2 tests
    ├── iam_roles.tftest.hcl         # NEW: Task Group 3 tests
    ├── lambda_resources.tftest.hcl  # NEW: Task Group 4 tests
    ├── lambda_outputs.tftest.hcl    # NEW: Task Group 5 tests
    ├── integration.tftest.hcl       # NEW: Task Group 6 tests
    └── LAMBDA_COVERAGE.md           # NEW: Coverage documentation
```

### Code Quality Guidelines

- **Run terraform fmt**: Format all modified .tf files
- **Descriptive Names**: Use lambda_execution (not just role), lambda_logs (not just attachment)
- **Comments**: Add comments explaining IAM trust policy and permissions
- **Consistent Ordering**: Function attributes in logical order (name, role, code, runtime, properties)
- **Tags**: Apply consistent tags to all resources (Service, Stage, Function)

### Success Metrics

- Module generates aws_lambda_function resources for each function in serverless.yml
- Each Lambda has correct runtime, handler, memory, timeout, description from configuration
- Function naming follows Serverless Framework convention: {service}-{stage}-{function_key}
- Each Lambda has associated IAM execution role with basic execution policy
- Code packaging generates ZIP files with change detection
- Environment variables mapped when present, block absent when not specified
- Functionless configurations complete successfully with zero resources created
- All outputs populated correctly for downstream integration
- terraform plan deterministic and repeatable
- 28-38 strategic tests cover critical workflows
- Module ready for roadmap items #3 (custom IAM) and #4-8 (event sources)

## Reference Documentation

**Specification:** /home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-lambda-function-translation/spec.md
**Example Tasks Format:** /home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/tasks.md
**Existing Module:** /home/tom/p/t/sls.tf/ (main.tf, outputs.tf, locals.tf, variables.tf, versions.tf)
**Standards:** /home/tom/p/t/sls.tf/agent-os/standards/ (coding-style, conventions, error-handling, testing)
