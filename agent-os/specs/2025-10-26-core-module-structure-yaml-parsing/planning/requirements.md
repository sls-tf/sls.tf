# Spec Requirements: Core Module Structure & YAML Parsing

## Initial Description

Create the foundational Terraform module with variables for configuration file path and format, implement YAML parsing using yamldecode(), and establish the module's input/output interface including validation for required Serverless Framework fields.

This is the first feature in the roadmap for sls.tf, a Terraform module that bridges Serverless Framework configuration syntax with Terraform-managed AWS infrastructure.

## Requirements Discussion

### First Round Questions

**Q1: Module Interface - What should we name the input variables?**
**Answer:** Use `config_path` or `config_file` (prefer `config_path`), `config_format` with default "yaml". For now, always read `service_name` from the config file (no override variable).

**Q2: Module Structure - Should we follow standard Terraform module structure?**
**Answer:** Confirmed - root module with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and `locals.tf`.

**Q3: Terraform Version - What minimum Terraform version should we require?**
**Answer:** Require current version (1.13 - user thinks, need to verify latest stable version and use that).
**Research Result:** Latest stable Terraform version is 1.13.4.

**Q4: Functionless Configuration - Can a serverless.yml be valid without functions?**
**Answer:** Check if Serverless Framework allows functionless configs. If yes, allow it.
**Research Result:** Yes, functionless configurations are valid. The `functions` field is optional at the service level. This enables infrastructure-only deployments with just the `resources` section.

**Q5: Region Handling - How should we handle region specification?**
**Answer:** Match the JSON schema completely. Allow `aws_region` override variable, but output a WARNING if it doesn't match the serverless.yml value.

**Q6: Provider Fields - Which provider fields are required vs optional?**
**Answer:** Match the JSON schema - if fields can be optional, provide defaults according to the schema.
**Research Result:**
- Required: `provider.name` (must be "aws")
- Optional with defaults:
  - `provider.stage` (default: "dev")
  - `provider.region` (default: "us-east-1")
  - `provider.memorySize` (default: 1024 MB)
  - `provider.timeout` (default: 6 seconds)
  - `provider.runtime` (no default - can be set at function level)

**Q7: Validation Approach - How should validation errors be handled?**
**Answer:** Fail with clear messages using Terraform validation. Collect ALL validation errors and report them together (not one at a time).

**Q8: YAML Parsing Errors - How should we handle invalid YAML?**
**Answer:** Halt execution for invalid YAML, but wrap with try() for friendlier error messages.

**Q9: Output Structure - Should we output the entire parsed config or break it into components?**
**Answer:** Output the entire parsed configuration as a single object for now.

**Q10: Additional Outputs - Should we provide granular outputs for specific sections?**
**Answer:** Yes, include outputs for `service_name`, `provider_config`, `functions`, `custom`, `resources`, and `package` even if not used until later.

**Q11: TypeScript Support - Should we support serverless.ts in this phase?**
**Answer:** Start with YAML only. Add TypeScript parsing in roadmap item #6.

**Q12: Framework Version - Should we validate frameworkVersion field?**
**Answer:** Add validation check for `frameworkVersion`. Also research if Framework 4.x exists now.
**Research Result:** Serverless Framework 4.x exists and is the current version. The module should validate and support Framework versions 2.x, 3.x, and 4.x.

**Q13: Exclusions - What should we NOT handle in this phase?**
**Answer:**
- Variable substitution syntax (`${self:service}`, `${env:STAGE}`) - future roadmap item #10
- CloudFormation intrinsic functions (`!Ref`, `!GetAtt`) - could be supported but move to future roadmap item
- Plugins configuration - not mentioned, assume future work

### Existing Code to Reference

**Similar Features Identified:**
None available. This is a side project to be open sourced, cannot use employer code.

### Follow-up Questions - Round 2

**Q14: AWS Provider Version - Should we use version 5 or 6?**
**Answer:** Research when AWS provider version 6 was released. If very recent, use version 5 (`>= 5.0`). If it's been out a while, use version 6 (`>= 6.0`).
**Research Result:** AWS provider v6.0.0 was released on June 18, 2025. As of October 26, 2025, it has been stable for over 4 months. Decision: Use version 6 constraint (`>= 6.0`).

**Q15: Runtime Validation - How strict should runtime validation be?**
**Answer:** Require each function to specify its own runtime if not specified at provider level. This is strict validation - no defaults, no permissiveness.
**Validation Rule:** Either `provider.runtime` must be set (applies to all functions) OR each individual function must specify its own `runtime`. Missing runtime at both levels is a validation error.

**Q16: Schema Synchronization - Scope Decision**
**Answer:** User wants scripts that keep Terraform validation current with the latest Serverless Framework JSON schema automatically. This avoids manual adjustments as the schema evolves.

**Final Scope Decision:** Schema synchronization tooling will be added as a SEPARATE roadmap item (not part of this feature). Initial validation for this feature will be manually coded based on the current Serverless Framework JSON schema.

### Follow-up Questions - Round 3

None required. All technical questions answered and scope clarified.

## Visual Assets

### Files Provided:
No image/screenshot visual assets provided by user.

### Generated Visual Documentation:
Created Mermaid diagram documentation files:
- `module-interface.md`: Input/output interface diagram showing module variables and outputs
- `data-flow.md`: Complete data flow from file loading through validation to outputs
- `module-usage-example.md`: Example of how users will consume the module with sample configs
- `validation-flow.md`: Comprehensive validation logic with error collection strategy

### Visual Insights:
The generated diagrams illustrate:
- Module boundary and interface contract
- YAML parsing with try/catch error handling
- Multi-stage validation with error collection
- Default value application logic
- Region override warning mechanism
- Support for functionless configurations
- Module composition patterns for users

**Fidelity Level:** Technical documentation diagrams (Mermaid format for maintainability)

## Requirements Summary

### Functional Requirements

**Core Parsing Functionality:**
- Read serverless.yml file from user-specified `config_path`
- Parse YAML using Terraform's native `yamldecode()` function
- Wrap parsing in `try()` block to provide friendly error messages for invalid YAML
- Halt execution with clear error message if YAML is invalid

**Configuration Validation:**
- Validate required field: `service` (service name)
- Validate required field: `provider` (provider configuration object)
- Validate required field: `provider.name` (must equal "aws")
- Validate optional field: `provider.runtime` (if specified, must match valid runtime pattern)
- Validate optional field: `provider.region` (if specified, must be valid AWS region)
- Validate optional field: `provider.memorySize` (if specified, must be 128-10240 MB)
- Validate optional field: `provider.timeout` (if specified, must be 1-900 seconds)
- Validate optional field: `frameworkVersion` (if specified, must be compatible: 2.x, 3.x, or 4.x)
- Allow `functions` field to be empty or absent (functionless configs are valid)
- For each function defined, validate:
  - Required: `handler` field
  - Required: `runtime` MUST be specified either at provider level OR at function level (strict validation)
  - Optional: `memorySize` (inherits from provider if not specified, validate range)
  - Optional: `timeout` (inherits from provider if not specified, validate range)

**Runtime Validation (Strict Mode):**
- Runtime must be specified at provider level (applies to all functions) OR at each individual function level
- If provider.runtime is not set, every function MUST have its own runtime specified
- If provider.runtime is set, functions can omit runtime (will inherit) or override it
- Missing runtime at both levels is a validation ERROR (no permissive defaults)
- Example error: "Function 'myFunc' missing required 'runtime' field. Either set provider.runtime or specify runtime for each function."

**Error Handling:**
- Collect ALL validation errors before halting execution
- Display all errors together in a clear, formatted message
- Do not fail one error at a time (improve developer experience)
- Distinguish between errors (halt execution) and warnings (continue)

**Default Value Application:**
- Apply `provider.stage = "dev"` if not specified
- Apply `provider.region = "us-east-1"` if not specified
- Apply `provider.memorySize = 1024` if not specified
- Apply `provider.timeout = 6` if not specified
- Inherit provider-level defaults to function-level if function doesn't specify
- DO NOT apply default for `provider.runtime` - this must be explicit (see Runtime Validation above)

**Region Override Handling:**
- Accept optional `aws_region` input variable
- If `aws_region` is set and differs from `provider.region`, output a WARNING
- Continue execution with the override value
- Do not treat region mismatch as an error

**Output Generation:**
- Output `parsed_config`: entire parsed configuration as single object
- Output `service_name`: extracted service name (string)
- Output `provider_config`: provider configuration object
- Output `functions`: map of function definitions (can be empty)
- Output `custom`: custom configuration section (if present)
- Output `resources`: resources section for custom AWS resources (if present)
- Output `package`: packaging configuration (if present)

**Module Structure:**
- Create standard Terraform module file structure:
  - `main.tf`: Primary parsing and validation logic
  - `variables.tf`: Input variable declarations (`config_path`, `config_format`, `aws_region`)
  - `outputs.tf`: All output value declarations
  - `versions.tf`: Terraform version constraint and provider requirements
  - `locals.tf`: Local values for transformations and default application
- Set Terraform version constraint: `>= 1.13.4`
- Set AWS provider version constraint: `>= 6.0` (version 6.0.0 released June 18, 2025, stable for 4+ months)

**Input Variables:**
- `config_path` (string, required): Path to serverless.yml file
- `config_format` (string, optional, default "yaml"): Configuration format (only "yaml" supported in this phase)
- `aws_region` (string, optional, default null): Override for AWS region with warning if different from config

### Reusability Opportunities

None identified. This is a new open-source project with no existing codebase to reference.

### Scope Boundaries

**In Scope:**
- YAML parsing using `yamldecode()`
- Schema validation for required and optional fields (manually coded)
- Strict runtime validation (must be at provider OR function level, no permissive defaults)
- Default value application per Serverless Framework specification (excluding runtime)
- Error collection and display (all errors at once)
- Warning system for region override mismatches
- Support for functionless configurations
- Validation of Serverless Framework version 2.x, 3.x, and 4.x compatibility
- Module output interface for downstream consumption
- Standard Terraform module file structure
- Terraform 1.13.4+ compatibility
- AWS provider 6.x compatibility

**Out of Scope (Future Roadmap):**
- **Schema Synchronization Tooling** - Will be added as a SEPARATE roadmap item. Initial validation rules will be manually coded based on the current Serverless Framework JSON schema. Future tooling will automate synchronization with schema evolution.
- TypeScript configuration parsing (`serverless.ts`) - Roadmap item #6
- Variable substitution syntax (`${self:}`, `${env:}`, `${opt:}`, `${cf:}`) - Roadmap item #10
- CloudFormation intrinsic functions (`!Ref`, `!GetAtt`, `!Sub`, etc.) - Future enhancement
- Plugins configuration and plugin-provided syntax - Future enhancement
- Actual AWS resource provisioning (Lambda, API Gateway, etc.) - Subsequent roadmap items #2-12
- IAM role generation - Roadmap item #3
- Event source mapping - Roadmap items #4, #5, #7, #8
- Custom resource translation - Roadmap item #9

### Technical Considerations

**Terraform Features Used:**
- `yamldecode()` function for parsing serverless.yml
- `try()` function for graceful error handling
- `coalesce()` function for default value application
- Variable validation blocks for schema enforcement
- `for_each` patterns (for iterating over functions in validation)
- Local values for intermediate transformations
- Dynamic blocks (potential future use)

**Serverless Framework Compatibility:**
- Support Framework versions 2.x, 3.x, and 4.x
- Match official JSON schema for provider field defaults
- Honor Serverless Framework conventions:
  - `stage` defaults to "dev"
  - `region` defaults to "us-east-1"
  - `memorySize` defaults to 1024 MB
  - `timeout` defaults to 6 seconds
  - Function-level settings override provider-level settings
  - Runtime must be explicitly specified (no default)

**Validation Strategy:**
- Use Terraform's native validation blocks on variables and locals
- Implement custom validation logic in locals for complex rules
- Format error messages for clarity and actionability
- Example error format: "Required field 'service' is missing. Specify service name in serverless.yml"
- Strict runtime validation: Error if runtime missing at both provider and function levels
- Manually code validation rules based on Serverless Framework JSON schema (schema sync tooling is out of scope)

**Warning vs Error Distinction:**
- Errors: Missing required fields, invalid values, schema violations, missing runtime → HALT
- Warnings: Region override mismatch, missing optional fields with defaults → CONTINUE

**Module Design Patterns:**
- Single responsibility: Only parse and validate, don't provision resources
- Clear input/output contract for composition
- Fail-fast validation with comprehensive error reporting
- Defensive defaults matching framework behavior (except runtime - strict validation)
- Extensible structure for future format support (TypeScript)

**File Organization:**
```
sls.tf/
├── main.tf           # Core parsing and validation logic
├── variables.tf      # config_path, config_format, aws_region
├── outputs.tf        # parsed_config, service_name, provider_config, functions, etc.
├── versions.tf       # Terraform >= 1.13.4, AWS provider >= 6.0
├── locals.tf         # Default application, transformations
├── README.md         # Module documentation (future)
└── examples/         # Usage examples (future)
    └── basic/
        ├── main.tf
        └── serverless.yml
```

**Error Message Examples:**
- "Configuration validation failed:\n- Required field 'service' is missing\n- Required field 'provider.name' must be 'aws', got: 'azure'\n- Function 'myFunc' missing required field 'handler'\n- Function 'myFunc' missing required 'runtime' field. Either set provider.runtime or specify runtime for each function."
- "WARNING: aws_region override 'us-west-2' differs from serverless.yml region 'us-east-1'. Using override value."

**Testing Considerations (Not in Scope for Implementation):**
- Test valid serverless.yml parsing
- Test invalid YAML syntax error handling
- Test missing required fields error collection
- Test functionless configuration acceptance
- Test default value application
- Test region override warning
- Test frameworkVersion validation for 2.x, 3.x, 4.x
- Test function-level overrides of provider settings
- Test strict runtime validation (missing at both levels should error)
- Test runtime inheritance from provider level
- Test runtime override at function level
