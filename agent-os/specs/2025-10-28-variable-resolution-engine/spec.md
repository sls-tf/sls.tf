# Specification: Variable Resolution Engine

## Goal
Enable Serverless Framework-style variable resolution in Terraform HCL, allowing users to reference config values, environment variables, CLI options, external data sources, and files using the familiar ${variable} syntax throughout their serverless.yml configurations.

## User Stories
- As a developer, I want to use ${self:provider.stage} to reference configuration values so that I can keep my configs DRY
- As a DevOps engineer, I want to use ${env:API_KEY} to inject environment-specific values so that I can manage secrets externally
- As a team lead, I want to use ${opt:stage} to override values at deployment time so that I can deploy the same config to multiple environments
- As a system architect, I want to use ${cf:my-stack.OutputKey} to reference CloudFormation outputs so that I can compose infrastructure
- As an SRE, I want to use ${ssm:/path/to/param} to retrieve SSM parameters so that I can centralize configuration management
- As a developer, I want to use ${file(./config.json):key} to load external configuration so that I can split large configs

## Core Requirements
- Parse and resolve ${self:path.to.property} internal configuration references
- Parse and resolve ${env:VARIABLE_NAME} environment variable references
- Parse and resolve ${opt:option} CLI option references (map to Terraform variables)
- Parse and resolve ${cf:stackName.outputKey} CloudFormation output references
- Parse and resolve ${ssm:/path/to/param} SSM parameter references
- Parse and resolve ${file(path):key} external file references
- Support recursive resolution with configurable max depth (default: 10 levels)
- Support default values: ${env:VAR, 'default'}
- Detect and error on circular references
- Fail fast with clear error messages for undefined variables
- Resolve variables at Terraform plan time where possible
- Create resolved_config local after variable resolution for use by resources

## Visual Design
Not applicable - infrastructure code only.

## Reusable Components

### Existing Code to Leverage
- **locals.tf**: Current parsing logic using try(), coalesce(), and regex patterns can be extended for variable resolution
- **locals.tf**: Existing validation error aggregation pattern (concat of conditional lists) can be reused for variable resolution errors
- **locals.tf**: Pattern of creating normalized/processed versions of config (e.g., functions_with_defaults) serves as model for resolved_config
- **main.tf**: Use of dynamic blocks and conditional resource creation patterns
- **variables.tf**: Input variable structure and validation patterns
- **tests/*.tftest.hcl**: Test file patterns with fixtures and assertions

### New Components Required
- **variable_resolution.tf**: New file for variable resolution logic (doesn't exist yet)
- Variable parsing functions to extract ${...} patterns from strings
- Recursive resolution algorithm with depth tracking
- Circular dependency detection mechanism
- Default value parsing and application logic

## Technical Approach

### Architecture Overview
The variable resolution engine will operate in multiple phases within Terraform's locals block:

1. **Raw Config**: YAML parsed into local.parsed_config (existing)
2. **Variable Extraction**: Scan all string values for ${...} patterns
3. **Dependency Graph**: Build resolution order based on references
4. **Variable Resolution**: Resolve variables recursively with proper data sources
5. **Resolved Config**: Create local.resolved_config for resource generation
6. **Resource Generation**: Use resolved_config instead of parsed_config

### Resolution Strategy

**Phase 1 (Priority)**: ${self:} and ${env:}
- Most common patterns, 80% of use cases
- ${self:} maps to local.parsed_config paths using split(":", var) and nested lookups
- ${env:} maps to Terraform input variables (var.env_*)

**Phase 2**: ${opt:}, ${cf:}, ${ssm:}
- ${opt:} maps to Terraform input variables (existing var.aws_region, new vars for stage overrides)
- ${cf:} uses data "aws_cloudformation_stack" for lookups
- ${ssm:} uses data "aws_ssm_parameter" for lookups

**Phase 3**: ${file()} and advanced patterns
- ${file()} uses jsondecode(file()) or yamldecode(file()) with optional key path
- Support for nested variable references within file contents

### Variable Resolution Algorithm

```
For each string value in parsed_config:
  1. Extract all ${...} patterns using regex
  2. For each pattern:
     a. Parse type (self, env, opt, cf, ssm, file)
     b. Parse path/key
     c. Parse default value if present
     d. Check depth (error if > max_depth)
     e. Check for circular reference (error if detected)
     f. Resolve based on type:
        - self: Navigate local.parsed_config
        - env: Reference var.env_<NAME>
        - opt: Reference var.opt_<NAME>
        - cf: Query data source
        - ssm: Query data source
        - file: Load and parse file
     g. If result contains ${...}, recursively resolve
     h. Apply default if resolution fails and default exists
     i. Error if no default and resolution fails
  3. Replace ${...} with resolved value
  4. Return fully resolved string
```

### Data Sources Required

```hcl
# CloudFormation stack outputs (Phase 2)
data "aws_cloudformation_stack" "referenced_stacks" {
  for_each = local.cloudformation_stack_references
  name     = each.value.stack_name
}

# SSM parameters (Phase 2)
data "aws_ssm_parameter" "referenced_params" {
  for_each = local.ssm_parameter_references
  name     = each.value.parameter_path
}
```

### Input Variables Required

```hcl
# Environment variable passthroughs (Phase 1)
variable "env_vars" {
  description = "Map of environment variables to pass through for ${env:} resolution"
  type        = map(string)
  default     = {}
}

# CLI option overrides (Phase 2)
variable "opt_stage" {
  description = "Stage override for ${opt:stage}"
  type        = string
  default     = null
}

variable "opt_region" {
  description = "Region override for ${opt:region}"
  type        = string
  default     = null
}

# Resolution behavior controls
variable "strict_variable_resolution" {
  description = "Fail on undefined variables (true) or use empty string (false)"
  type        = bool
  default     = true
}

variable "max_variable_depth" {
  description = "Maximum depth for recursive variable resolution"
  type        = number
  default     = 10
}
```

### Local Variables Structure

```hcl
locals {
  # Existing
  parsed_config = yamldecode(local.file_content)

  # New: Extract variable references (Phase 1)
  self_references = [/* extracted ${self:} patterns */]
  env_references  = [/* extracted ${env:} patterns */]

  # New: Resolution with error tracking (Phase 1)
  variable_resolution_errors = [/* validation errors */]

  # New: Resolved configuration (Phase 1)
  resolved_config = /* recursively resolved parsed_config */

  # Modified: Use resolved_config instead of parsed_config
  provider_with_defaults = local.resolved_config.provider
  functions_with_defaults = local.resolved_config.functions
  # ... etc
}
```

### Error Handling

Clear, actionable error messages following existing validation pattern:

```hcl
variable_resolution_errors = concat(
  # Circular reference detection
  local.has_circular_references ? [
    "Circular variable reference detected: ${join(" -> ", local.circular_reference_path)}"
  ] : [],

  # Undefined variable errors
  [
    for var in local.undefined_variables :
    "Undefined variable '${var.pattern}' in ${var.location}. ${
      var.strict_mode ? "Set strict_variable_resolution=false to use empty string as default." : ""
    }"
  ],

  # Max depth exceeded
  local.max_depth_exceeded ? [
    "Variable resolution exceeded maximum depth of ${var.max_variable_depth}. Check for recursive variable definitions."
  ] : [],

  # Data source errors
  [
    for err in local.data_source_errors :
    "Failed to resolve ${err.type} reference '${err.path}': ${err.message}"
  ]
)
```

### Resolution Examples

**Example 1: Self-reference**
```yaml
# Input (serverless.yml)
service: my-api
provider:
  stage: dev
resources:
  Resources:
    MyBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: ${self:service}-${self:provider.stage}-uploads

# Resolution
# ${self:service} -> "my-api"
# ${self:provider.stage} -> "dev"
# Result: "my-api-dev-uploads"
```

**Example 2: Environment variable with default**
```yaml
# Input
provider:
  environment:
    API_URL: ${env:API_ENDPOINT, 'https://api.example.com'}

# Resolution (if $API_ENDPOINT not set)
# ${env:API_ENDPOINT, 'https://api.example.com'} -> 'https://api.example.com'
```

**Example 3: Nested self-reference**
```yaml
# Input
custom:
  baseName: ${self:service}-${self:provider.stage}
resources:
  Resources:
    MyTable:
      Properties:
        TableName: ${self:custom.baseName}-users

# Resolution
# First: ${self:custom.baseName} -> "${self:service}-${self:provider.stage}"
# Second: Resolve nested variables -> "my-api-dev"
# Third: Concatenate -> "my-api-dev-users"
```

**Example 4: SSM parameter reference**
```yaml
# Input (Phase 2)
provider:
  environment:
    DB_PASSWORD: ${ssm:/myapp/prod/db-password}

# Resolution
# Creates data.aws_ssm_parameter reference
# Resolves to parameter value at plan time
```

## Implementation Phases

### Phase 1: Core ${self:} and ${env:} Support (Roadmap #11a)
**Scope:**
- Basic ${self:} path traversal
- ${env:} mapping to Terraform variables
- Default value support: ${var, 'default'}
- Circular reference detection
- Single-level resolution (no nested variables yet)
- Integration with existing locals and resources

**Deliverables:**
- variable_resolution.tf with core resolution logic
- Updated variables.tf with env_vars map
- Tests for self and env resolution
- Documentation with examples

**Success Criteria:**
- Can resolve ${self:service}, ${self:provider.stage}
- Can resolve ${env:VAR} from var.env_vars map
- Detects and errors on circular references
- Existing tests continue to pass

### Phase 2: ${opt:}, ${cf:}, ${ssm:} Support (Roadmap #11b)
**Scope:**
- CLI option overrides (opt_stage, opt_region)
- CloudFormation stack output data sources
- SSM parameter data sources
- Recursive resolution (nested variables)
- Advanced default value handling

**Deliverables:**
- CloudFormation data source integration
- SSM data source integration
- Recursive resolution algorithm with depth tracking
- Tests for all new variable types
- Updated documentation

**Success Criteria:**
- Can resolve ${opt:stage} from Terraform variables
- Can resolve ${cf:stack.output} from CloudFormation
- Can resolve ${ssm:/path} from SSM
- Handles nested variables up to max depth
- Clear errors when max depth exceeded

### Phase 3: ${file()} and Advanced Features (Roadmap #11c)
**Scope:**
- File loading with jsondecode/yamldecode
- JSONPath-style key extraction from files
- Variable resolution within loaded files
- Performance optimization for large configs
- Optional caching mechanisms

**Deliverables:**
- File loading and parsing logic
- Key path extraction from JSON/YAML
- Complete recursive resolution across files
- Performance benchmarking
- Migration guide for complex configs

**Success Criteria:**
- Can load and parse JSON/YAML files
- Can extract nested keys from files
- Resolves variables within file contents
- No performance regression on existing configs
- Full documentation with migration examples

## Out of Scope

### Current Release
- CloudFormation intrinsic functions (!Ref, !GetAtt) - Phase 4
- AWS Secrets Manager integration (${secrets:}) - Phase 4
- Custom variable resolvers/plugins - Future
- Variable resolution in Terraform resources (only serverless.yml) - Not needed
- Git-based variable sources (${git:}) - Future
- HTTP-based variable sources (${http:}) - Future

### Explicitly Excluded
- Modifying existing Terraform variable syntax (${var.x} vs ${env:x})
- Changing how Terraform resolves its own variables
- Client-side pre-processing (all resolution at Terraform plan time)

## Testing Strategy

### Unit Tests (via terraform test)
Each test file focuses on specific variable type:

**test_self_references.tftest.hcl**
- Simple self-references (${self:service})
- Nested self-references (${self:custom.baseName})
- Array/list access (${self:custom.domains[0]})
- Missing path errors
- Circular reference detection

**test_env_variables.tftest.hcl**
- Basic env resolution (${env:NODE_ENV})
- Default values (${env:MISSING, 'default'})
- Empty env variable handling
- Missing env without default (error case)

**test_opt_variables.tftest.hcl**
- Stage override (${opt:stage})
- Region override (${opt:region})
- Missing opt variable with default

**test_cf_references.tftest.hcl**
- Stack output resolution
- Missing stack errors
- Missing output errors

**test_ssm_parameters.tftest.hcl**
- Parameter path resolution
- Non-existent parameter errors
- SecureString handling

**test_file_loading.tftest.hcl**
- JSON file loading
- YAML file loading
- Key path extraction
- Missing file errors
- Invalid file format errors

**test_recursive_resolution.tftest.hcl**
- Two-level nesting
- Three-level nesting
- Max depth exceeded
- Circular dependencies

**test_error_messages.tftest.hcl**
- Undefined variable error format
- Circular reference error format
- Max depth error format
- Data source error format

### Integration Tests
**test_full_config_resolution.tftest.hcl**
- Complete serverless.yml with mixed variable types
- Verify all resources created with resolved values
- Verify outputs contain resolved values

### Test Fixtures Required
- fixtures/variables-self-basic.yml
- fixtures/variables-self-nested.yml
- fixtures/variables-env-defaults.yml
- fixtures/variables-circular.yml (should fail)
- fixtures/variables-mixed.yml (all types)
- fixtures/external-config.json
- fixtures/external-config.yml

### Validation Tests
Test that existing functionality still works:
- Run all existing tests with resolved_config
- Verify no performance regression
- Verify error messages remain clear

## Success Criteria

### Phase 1 Completion
- [ ] 95%+ of ${self:} patterns resolve correctly
- [ ] ${env:} variables work with var.env_vars map
- [ ] Default values work: ${var, 'default'}
- [ ] Circular references detected and error clearly
- [ ] All existing tests pass with resolved_config
- [ ] Test coverage >80% for resolution logic
- [ ] Documentation includes 5+ real-world examples
- [ ] Migration guide for converting hardcoded values to variables

### Phase 2 Completion
- [ ] ${opt:stage} and ${opt:region} work
- [ ] ${cf:stack.output} resolves from CloudFormation
- [ ] ${ssm:/path} resolves from SSM
- [ ] Recursive resolution works up to 10 levels deep
- [ ] Clear error when max depth exceeded
- [ ] Test coverage includes all new variable types
- [ ] Performance: <100ms overhead for typical configs

### Phase 3 Completion
- [ ] ${file(./config.json):key} loads and parses files
- [ ] Supports both JSON and YAML files
- [ ] Variables within files are resolved
- [ ] Performance: <200ms for configs with file references
- [ ] Complete documentation with advanced examples
- [ ] Migration guide for complex multi-environment setups

### Overall Success Metrics
- [ ] Reduces config duplication by >50% in real projects
- [ ] Error messages are actionable (user can fix without reading source)
- [ ] No breaking changes to existing working configs
- [ ] Compatible with Terraform 1.5+ and OpenTofu
- [ ] LocalStack tests pass for all variable types
