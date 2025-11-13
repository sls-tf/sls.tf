# Specification: Core Module Structure & YAML Parsing

## Overview

This specification defines the foundational Terraform module for sls.tf, which parses Serverless Framework configuration files (serverless.yml) and validates them against the Serverless Framework schema. This module establishes the core input/output interface that subsequent roadmap items will build upon to provision AWS resources.

**Roadmap Position:** Item #1 - Foundation for all subsequent features
**Dependencies:** None - this is the first feature
**Target Completion:** Establishes parsing and validation infrastructure

## Goal

Create a robust Terraform module that reads and validates Serverless Framework YAML configurations, applies framework-compliant defaults, and outputs structured data for downstream resource provisioning modules.

## User Stories

- As a platform engineer, I want to provide a serverless.yml file path to the Terraform module so that I can maintain existing Serverless Framework configuration syntax while using Terraform for deployment
- As a migration architect, I want the module to validate my serverless.yml against Serverless Framework schema rules so that I catch configuration errors early in the Terraform plan phase
- As a developer, I want clear, actionable error messages when my serverless.yml is invalid so that I can quickly fix configuration issues without trial-and-error
- As an infrastructure team member, I want the module to support functionless configurations so that I can deploy infrastructure-only serverless.yml files
- As a DevOps engineer, I want region override capability with warnings so that I can manage multi-region deployments while being alerted to mismatches

## Visual Design

This feature includes four Mermaid diagrams for technical reference:

- **Module Interface** (`planning/visuals/module-interface.md`): Shows input variables and output values
- **Data Flow** (`planning/visuals/data-flow.md`): Illustrates parsing, validation, and output generation flow
- **Validation Flow** (`planning/visuals/validation-flow.md`): Details comprehensive validation logic with error collection
- **Module Usage Example** (`planning/visuals/module-usage-example.md`): Demonstrates how users consume the module

## Core Requirements

### Functional Requirements

**Configuration Parsing:**
- Read YAML configuration file from user-specified path using Terraform's `file()` function
- Parse YAML using Terraform's native `yamldecode()` function
- Wrap parsing in `try()` block to provide user-friendly error messages for invalid YAML
- Halt execution with clear error message if YAML syntax is invalid

**Schema Validation:**
- Validate required top-level field: `service` (service name string)
- Validate required top-level field: `provider` (provider configuration object)
- Validate required provider field: `provider.name` (must equal "aws")
- Validate optional provider fields when specified:
  - `provider.runtime`: Must match valid AWS Lambda runtime pattern
  - `provider.region`: Must be valid AWS region code
  - `provider.stage`: Any string value accepted
  - `provider.memorySize`: Integer between 128-10240 MB
  - `provider.timeout`: Integer between 1-900 seconds
- Validate optional field: `frameworkVersion` (must be 2.x, 3.x, or 4.x if specified)
- Allow `functions` field to be empty or absent (functionless configurations are valid)

**Function-Level Validation:**
- For each function defined in `functions` map:
  - Validate required field: `handler` (handler path string)
  - Validate runtime specification using strict mode (see Runtime Validation below)
  - Validate optional `memorySize` field (128-10240 MB range)
  - Validate optional `timeout` field (1-900 seconds range)
  - Validate optional `runtime` field (valid runtime pattern)

**Runtime Validation (Strict Mode):**
- Runtime MUST be specified at provider level OR at individual function level
- If `provider.runtime` is set: applies to all functions that don't override it
- If `provider.runtime` is NOT set: every function MUST specify its own runtime
- Missing runtime at both levels is a validation ERROR
- Error message format: "Function 'functionName' missing required 'runtime' field. Either set provider.runtime or specify runtime for each function."

**Default Value Application:**
- Apply Serverless Framework defaults per official JSON schema:
  - `provider.stage`: "dev" (if not specified)
  - `provider.region`: "us-east-1" (if not specified)
  - `provider.memorySize`: 1024 MB (if not specified)
  - `provider.timeout`: 6 seconds (if not specified)
  - `provider.runtime`: NO DEFAULT - must be explicit (strict validation)
- Inherit provider-level defaults to function level when function doesn't override
- Use Terraform's `coalesce()` function for default application logic

**Error Collection and Reporting:**
- Collect ALL validation errors before halting execution
- Do not fail one error at a time (poor developer experience)
- Format errors as multi-line list with clear, actionable messages
- Distinguish between errors (halt execution) and warnings (continue execution)
- Use Terraform validation blocks with custom error messages

**Region Override Handling:**
- Accept optional `aws_region` input variable
- If `aws_region` is set and differs from `provider.region`, output a WARNING
- Continue execution with override value (do not treat as error)
- Warning format: "WARNING: aws_region override 'X' differs from serverless.yml region 'Y'. Using override value."

**Output Generation:**
- Output `parsed_config`: Complete parsed configuration object
- Output `service_name`: Extracted service name (string)
- Output `provider_config`: Provider configuration object with defaults applied
- Output `functions`: Map of function definitions (empty map if no functions)
- Output `custom`: Custom configuration section (null if not present)
- Output `resources`: Resources section for custom AWS resources (null if not present)
- Output `package`: Packaging configuration (null if not present)

### Module Structure

**File Organization:**
```
sls.tf/
├── main.tf           # Core parsing and validation logic
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── versions.tf       # Terraform and provider version constraints
├── locals.tf         # Local values for transformations and defaults
├── README.md         # Module documentation (future)
└── examples/         # Usage examples (future)
    └── basic/
        ├── main.tf
        └── serverless.yml
```

**main.tf Responsibilities:**
- Load configuration file using `file()` function
- Parse YAML using `yamldecode()` wrapped in `try()` for error handling
- Primary orchestration of parsing and validation flow

**variables.tf Contents:**
- `config_path` (string, required): Absolute or relative path to serverless.yml
- `config_format` (string, optional, default "yaml"): Configuration format (only "yaml" supported in this phase)
- `aws_region` (string, optional, default null): Override for AWS region with warning

**outputs.tf Contents:**
- All seven output values listed in Output Generation section above
- Clear descriptions for each output
- Proper type constraints where applicable

**versions.tf Requirements:**
- Terraform version constraint: `>= 1.13.4`
- AWS provider version constraint: `>= 6.0`
- Required provider configuration block

**locals.tf Responsibilities:**
- Parse YAML configuration into local value
- Apply default values using `coalesce()`
- Build transformed configuration objects
- Compute validation error lists
- Perform default inheritance from provider to function level

## Reusable Components

### Existing Code to Leverage

The project repository already has foundational Terraform files that establish the basic structure:

**Existing files:**
- `/home/tom/p/t/sls.tf/main.tf` - Contains validation logic using null_resource with lifecycle preconditions
- `/home/tom/p/t/sls.tf/variables.tf` - Defines `config_path`, `config_format`, and `aws_region` variables with validation
- `/home/tom/p/t/sls.tf/versions.tf` - Sets Terraform and provider version constraints
- `/home/tom/p/t/sls.tf/locals.tf` - Implements parsing, validation, default application logic
- `/home/tom/p/t/sls.tf/outputs.tf` - Defines all module outputs

**Patterns to follow:**
- Use `try()` wrapper for file reading and YAML parsing
- Use `null_resource` with lifecycle preconditions for validation enforcement
- Collect validation errors in local values before enforcing
- Use `coalesce()` for default value application
- Use `for_each` for function iteration during validation

**Key implementation patterns from existing code:**
- Error collection using `concat()` to aggregate validation issues
- Strict runtime validation with function-level iteration
- Provider-level defaults application using `merge()` and `coalesce()`
- Function-level inheritance from provider defaults
- Region override warning mechanism using separate warning list

### New Components Required

None identified. The existing codebase provides the complete implementation structure needed for this specification.

## Technical Approach

### Technology Stack Compliance

This module uses Terraform (HCL) as the primary language with the following built-in functions:
- `file()`: Read configuration file from filesystem
- `yamldecode()`: Parse YAML content to Terraform data structures
- `try()`: Graceful error handling for YAML parsing
- `coalesce()`: Default value application
- `concat()`: Error message list aggregation
- `length()`: Error collection size checking
- `join()`: Multi-line error message formatting
- `lookup()`: Safe map access with defaults
- `merge()`: Object combination for defaults

### Terraform Module Patterns

**Input Validation Pattern:**
```hcl
variable "config_path" {
  type        = string
  description = "Path to serverless.yml configuration file"

  validation {
    condition     = length(var.config_path) > 0
    error_message = "config_path must be a non-empty string"
  }
}
```

**Error Collection Pattern:**
```hcl
locals {
  validation_errors = concat(
    try(local.parsed_config.service, null) == null ?
      ["Required field 'service' is missing. Specify service name in serverless.yml."] : [],
    try(local.parsed_config.provider.name, null) != "aws" ?
      ["Required field 'provider.name' must be 'aws', got: '${try(local.parsed_config.provider.name, "none")}'."] : [],
    # Additional validation rules...
  )

  has_errors = length(local.validation_errors) > 0
}
```

**Validation Enforcement Pattern:**
```hcl
resource "null_resource" "validation" {
  lifecycle {
    precondition {
      condition     = !local.has_errors
      error_message = "Configuration validation failed:\n${join("\n- ", local.validation_errors)}"
    }
  }
}
```

**Default Application Pattern:**
```hcl
locals {
  provider_with_defaults = merge(
    local.parsed_config.provider,
    {
      stage      = coalesce(try(local.parsed_config.provider.stage, null), "dev")
      region     = coalesce(try(local.parsed_config.provider.region, null), var.aws_region, "us-east-1")
      memorySize = coalesce(try(local.parsed_config.provider.memorySize, null), 1024)
      timeout    = coalesce(try(local.parsed_config.provider.timeout, null), 6)
    }
  )
}
```

**Function Default Inheritance Pattern:**
```hcl
locals {
  functions_with_defaults = {
    for name, func in try(local.parsed_config.functions, {}) :
    name => merge(func, {
      runtime    = coalesce(try(func.runtime, null), try(local.provider_with_defaults.runtime, null))
      memorySize = coalesce(try(func.memorySize, null), local.provider_with_defaults.memorySize)
      timeout    = coalesce(try(func.timeout, null), local.provider_with_defaults.timeout)
    })
  }
}
```

### Validation Strategy

**Validation Phases:**
1. **YAML Syntax Validation**: Immediate failure if YAML is malformed
2. **Schema Validation**: Check required fields and types
3. **Value Range Validation**: Check numeric ranges and string patterns
4. **Runtime Validation**: Strict check for runtime at provider OR function level
5. **Framework Version Validation**: Check compatibility if specified
6. **Region Override Validation**: Warn if mismatch detected

**Error vs Warning Classification:**
- **Errors (halt execution):**
  - Invalid YAML syntax
  - Missing required fields (service, provider, provider.name)
  - Invalid provider.name (must be "aws")
  - Invalid value ranges (memory, timeout)
  - Invalid runtime pattern format
  - Missing runtime at both provider and function levels
  - Incompatible frameworkVersion

- **Warnings (continue execution):**
  - Region override differs from config region
  - Missing optional fields with defaults available

**Validation Error Message Format:**
```
Configuration validation failed:
- Required field 'service' is missing. Specify service name in serverless.yml.
- Required field 'provider.name' must be 'aws', got: 'azure'.
- Function 'myFunc' missing required field 'handler'.
- Function 'myFunc' missing required 'runtime' field. Either set provider.runtime or specify runtime for each function.
```

### Data Flow Architecture

Reference the `planning/visuals/data-flow.md` diagram for complete flow visualization.

**High-Level Flow:**
1. User invokes module with `config_path`
2. Module reads file using `file(var.config_path)`
3. Module parses YAML using `yamldecode()` wrapped in `try()`
4. If YAML invalid: halt with friendly error
5. If YAML valid: proceed to validation
6. Collect all validation errors into list
7. If errors exist: halt and display all errors together
8. If no errors: apply defaults and build outputs
9. Check for region override and warn if mismatch
10. Generate all output values
11. Module ready for consumption by downstream resources

### Terraform Version Requirements

**Terraform Constraint:** `>= 1.13.4`
- Rationale: Latest stable version as of requirements gathering
- Required features: `yamldecode()`, `try()`, advanced validation blocks

**AWS Provider Constraint:** `>= 6.0`
- Rationale: Version 6.0.0 released June 18, 2025; stable for 4+ months
- Required features: Modern AWS resource support for future roadmap items

**Null Provider Constraint:** `>= 3.0`
- Rationale: Required for validation resource with lifecycle preconditions
- Used for: Enforcing validation checks before resource creation

**versions.tf Implementation:**
```hcl
terraform {
  required_version = ">= 1.13.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}
```

### Serverless Framework Compatibility

**Supported Framework Versions:** 2.x, 3.x, 4.x

**Schema Compliance:**
- Match official Serverless Framework JSON schema for field defaults
- Honor framework conventions for optional vs required fields
- Support functionless configurations (functions field optional)
- Validate runtime according to strict framework semantics

**Framework-Specific Defaults:**
```yaml
# Applied if not specified in serverless.yml
provider:
  stage: "dev"
  region: "us-east-1"
  memorySize: 1024
  timeout: 6
  # runtime: NO DEFAULT - must be explicit
```

**Field Inheritance:**
- Function-level settings override provider-level settings
- If function doesn't specify memorySize/timeout: inherit from provider
- If function doesn't specify runtime: inherit from provider (if provider.runtime exists)
- If neither provider nor function specifies runtime: validation ERROR

## Out of Scope

### Excluded from This Feature

**Schema Synchronization Tooling:**
- Automated generation of validation code from Serverless Framework JSON schema
- Schema evolution tracking across Framework versions
- Moved to separate roadmap item (to be added)
- Initial validation will be manually coded

**TypeScript Configuration Parsing:**
- Support for serverless.ts files
- TypeScript execution via ts-node and external data source
- Deferred to roadmap item #6

**Variable Resolution:**
- Serverless Framework variable syntax (`${self:}`, `${env:}`, `${opt:}`, `${cf:}`)
- Variable substitution and interpolation
- Deferred to roadmap item #10

**CloudFormation Intrinsic Functions:**
- Support for `!Ref`, `!GetAtt`, `!Sub`, `!Join`, etc.
- CloudFormation template processing
- Future enhancement (not on current roadmap)

**Resource Provisioning:**
- Actual AWS resource creation (Lambda, API Gateway, etc.)
- Covered by roadmap items #2-12
- This module only parses and validates configuration

**Plugin System:**
- Serverless Framework plugins configuration
- Plugin-provided syntax and extensions
- Future enhancement (not on current roadmap)

**Multiple Configuration Formats:**
- Only YAML supported in this phase
- JSON support: not planned (Serverless Framework uses YAML/TypeScript)
- TypeScript support: roadmap item #6

## Success Criteria

**Parsing Success:**
- Module successfully parses valid serverless.yml files
- Module loads file from absolute and relative paths
- Parsed configuration accessible via outputs

**Validation Success:**
- Module rejects serverless.yml missing required fields
- Module collects and displays ALL validation errors together
- Module provides clear, actionable error messages
- Module accepts valid functionless configurations
- Module enforces strict runtime validation rules

**Default Application Success:**
- Module applies correct Serverless Framework defaults
- Provider-level defaults inherited by functions
- Function-level overrides take precedence
- No default applied for runtime (strict validation)

**Error Handling Success:**
- Invalid YAML syntax results in friendly error message
- Validation errors formatted as multi-line list
- All errors collected before halting execution
- Terraform plan fails fast with clear feedback

**Region Override Success:**
- Module accepts aws_region override variable
- Module warns when override differs from config
- Module continues execution with override value
- Warning message clearly indicates mismatch

**Output Interface Success:**
- All seven outputs populated correctly
- parsed_config contains complete configuration
- Granular outputs (service_name, functions, etc.) accessible
- Outputs usable by downstream Terraform resources

**Framework Compatibility Success:**
- Module validates frameworkVersion 2.x, 3.x, 4.x
- Module matches Serverless Framework JSON schema defaults
- Module behavior consistent with framework conventions

**Performance Success:**
- Module parsing completes during Terraform plan phase
- No external dependencies required (pure HCL)
- Validation errors appear immediately (no waiting)

## Testing Requirements

While test implementation is out of scope for this specification, the following test scenarios must be covered:

**Valid Configuration Tests:**
- Parse valid serverless.yml with all required fields
- Parse valid serverless.yml with functions
- Parse valid functionless serverless.yml
- Parse serverless.yml with provider runtime only
- Parse serverless.yml with function-level runtime overrides
- Parse serverless.yml with custom, resources, package sections

**Invalid Configuration Tests:**
- Reject invalid YAML syntax
- Reject missing service field
- Reject missing provider field
- Reject invalid provider.name (not "aws")
- Reject missing handler in function definition
- Reject missing runtime at both provider and function levels
- Reject invalid memorySize range
- Reject invalid timeout range
- Reject incompatible frameworkVersion

**Default Application Tests:**
- Verify stage defaults to "dev"
- Verify region defaults to "us-east-1"
- Verify memorySize defaults to 1024
- Verify timeout defaults to 6
- Verify runtime has no default (strict validation)
- Verify function inherits provider defaults
- Verify function overrides take precedence

**Error Collection Tests:**
- Verify multiple errors collected together
- Verify error messages are clear and actionable
- Verify errors formatted as multi-line list

**Region Override Tests:**
- Verify warning when aws_region differs from config
- Verify no warning when aws_region matches config
- Verify no warning when aws_region not specified
- Verify override value used when specified

**Edge Cases:**
- Empty functions map (functionless config)
- Functions field absent entirely
- Optional fields missing (use defaults)
- Optional fields present (use specified values)
- Nested YAML structures in custom/resources sections

## Non-Functional Requirements

**Maintainability:**
- Clear separation of concerns across module files
- Descriptive variable and local value names
- Comprehensive comments for complex validation logic
- Follow Terraform HCL style guide (terraform fmt)

**Extensibility:**
- Module structure supports future TypeScript parsing (roadmap #6)
- Validation framework extensible for new schema rules
- Output interface supports additional fields without breaking changes

**Documentation:**
- Clear variable descriptions in variables.tf
- Clear output descriptions in outputs.tf
- README.md with usage examples (future work)
- Reference to Mermaid diagrams for architecture understanding

**Performance:**
- Parsing completes in milliseconds (native yamldecode)
- Validation runs during plan phase (no runtime overhead)
- No external process calls (pure Terraform functions)

**Security:**
- No sensitive data in error messages
- Configuration file read with appropriate permissions
- No code execution (YAML parsing only, no evaluation)

**Compatibility:**
- Works with Terraform 1.13.4+
- Compatible with AWS provider 6.0+
- No platform-specific dependencies (cross-platform)

**Usability:**
- Error messages guide users to fix issues
- Warnings clearly distinguished from errors
- Default values match framework conventions
- Module interface intuitive for Terraform users

## Dependencies and Assumptions

**Dependencies:**
- Terraform 1.13.4 or higher installed
- AWS provider 6.0 or higher configured
- Null provider 3.0 or higher for validation resources
- Valid serverless.yml file accessible from module path
- No external tools or scripts required

**Assumptions:**
- Users have basic Terraform knowledge
- Users familiar with Serverless Framework configuration syntax
- serverless.yml file uses valid YAML syntax
- File paths provided are accessible from Terraform working directory
- No TypeScript configuration support needed yet (roadmap #6)
- No variable resolution needed yet (roadmap #10)
- Manual validation coding acceptable (schema sync is future work)

**Future Considerations:**
- TypeScript parsing will require external data source (roadmap #6)
- Variable resolution will require additional parsing logic (roadmap #10)
- Schema sync tooling will reduce maintenance burden (future roadmap item)
- Resource provisioning modules will consume these outputs (roadmap #2-12)

## References

**Planning Documents:**
- Requirements: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/planning/requirements.md`
- Summary: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/planning/summary.md`

**Visual Assets:**
- Module Interface Diagram: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/planning/visuals/module-interface.md`
- Data Flow Diagram: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/planning/visuals/data-flow.md`
- Validation Flow Diagram: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/planning/visuals/validation-flow.md`
- Module Usage Example: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/planning/visuals/module-usage-example.md`

**Product Documentation:**
- Mission: `/home/tom/p/t/sls.tf/agent-os/product/mission.md`
- Roadmap: `/home/tom/p/t/sls.tf/agent-os/product/roadmap.md`
- Tech Stack: `/home/tom/p/t/sls.tf/agent-os/product/tech-stack.md`

**External References:**
- Serverless Framework Documentation: https://www.serverless.com/framework/docs
- Serverless Framework JSON Schema: https://github.com/serverless/serverless/blob/master/lib/configSchema.js
- Terraform Functions: https://www.terraform.io/language/functions
- AWS Lambda Runtimes: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html

## Implementation Notes

**Development Order:**
1. Verify versions.tf has Terraform >= 1.13.4 and AWS provider >= 6.0 constraints
2. Verify variables.tf defines config_path, config_format, and aws_region
3. Verify locals.tf implements YAML parsing with try() wrapper
4. Verify validation error collection logic in locals.tf
5. Verify default application logic in locals.tf
6. Verify main.tf has null_resource with lifecycle preconditions
7. Verify outputs.tf declares all seven outputs
8. Test with valid and invalid serverless.yml files
9. Verify error collection displays all errors together
10. Verify defaults match Serverless Framework behavior

**Key Implementation Challenges:**
- Collecting all validation errors before halting (use concat and lists)
- Applying defaults while preserving user-specified values (use coalesce)
- Inheriting provider defaults to function level (use for loop with merge)
- Strict runtime validation across provider and function levels (conditional logic)
- Friendly YAML parsing errors (wrap yamldecode in try with custom message)

**Code Quality Guidelines:**
- Run `terraform fmt` on all .tf files
- Use descriptive local value names (parsed_config, validation_errors, etc.)
- Add comments explaining complex validation logic
- Keep validation rules readable (one condition per concat element)
- Follow Terraform naming conventions (snake_case for variables/locals/outputs)

**Testing Approach:**
- Create examples/basic/ directory with sample serverless.yml
- Test terraform plan with valid configurations
- Test terraform plan with invalid configurations
- Verify error messages are clear and actionable
- Verify all outputs populated correctly
- Test region override warning mechanism

---

**This specification is ready for implementation.** Developers should reference the visual diagrams in the planning/visuals/ directory for architecture understanding and consult the requirements.md document for detailed Q&A context.
