# Task Breakdown: Variable Resolution Engine (Phase 1)

## Overview
**Total Tasks:** 6 task groups
**Scope:** Phase 1 - ${self:} and ${env:} variable resolution
**Target:** Resolve 80% of Serverless Framework variable use cases

## Task List

### Task Group 1: Variable Input Infrastructure

#### Dependencies: None

- [ ] 1.0 Complete variable input infrastructure
  - [ ] 1.1 Write 3-5 focused tests for environment variable inputs
    - Test env_vars map passes through to resolution
    - Test empty env_vars map defaults correctly
    - Test strict_variable_resolution flag behavior
  - [ ] 1.2 Add environment variable input to variables.tf
    - Add `env_vars` map(string) variable with default = {}
    - Add `strict_variable_resolution` bool variable with default = true
    - Add `max_variable_depth` number variable with default = 10
    - Follow existing variable validation patterns from variables.tf
  - [ ] 1.3 Ensure variable input tests pass
    - Run ONLY the 3-5 tests written in 1.1
    - Verify variable defaults work correctly
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 3-5 tests written in 1.1 pass
- New variables are properly typed and have sensible defaults
- Variable definitions follow existing patterns in variables.tf
- Documentation comments explain purpose of each variable

**Files to Create/Modify:**
- `/home/tom/p/t/sls.tf/variables.tf` (extend existing)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-env-basic.yml` (new fixture)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-self-basic.yml` (new fixture)
- `/home/tom/p/t/sls.tf/tests/variable_inputs.tftest.hcl` (new test file)

---

### Task Group 2: Variable Pattern Detection

#### Dependencies: Task Group 1

- [ ] 2.0 Complete variable pattern detection
  - [ ] 2.1 Write 4-6 focused tests for pattern extraction
    - Test extraction of ${self:service} pattern
    - Test extraction of ${env:VAR} pattern
    - Test extraction of multiple variables in one string
    - Test strings with no variables (pass-through)
    - Test default value parsing: ${env:VAR, 'default'}
  - [ ] 2.2 Create variable_resolution.tf file
    - Add regex patterns for ${self:...} detection
    - Add regex patterns for ${env:...} detection
    - Add logic to extract default values from ${var, 'default'} syntax
    - Use existing try/can patterns from locals.tf
  - [ ] 2.3 Create variable extraction locals in variable_resolution.tf
    - Extract all_self_references from parsed_config
    - Extract all_env_references from parsed_config
    - Build map of variable_locations (which fields contain variables)
    - Use flatten and for comprehensions like locals.tf patterns
  - [ ] 2.4 Ensure pattern detection tests pass
    - Run ONLY the 4-6 tests written in 2.1
    - Verify regex patterns detect variables correctly
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 4-6 tests written in 2.1 pass
- Regex patterns reliably extract ${self:} and ${env:} references
- Default value syntax is correctly parsed
- Pattern detection works for nested config structures
- Extraction logic follows locals.tf patterns (try/coalesce/flatten)

**Files to Create/Modify:**
- `/home/tom/p/t/sls.tf/variable_resolution.tf` (new file)
- `/home/tom/p/t/sls.tf/tests/variable_pattern_detection.tftest.hcl` (new test file)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-mixed-patterns.yml` (new fixture)

---

### Task Group 3: ${self:} Resolution Algorithm

#### Dependencies: Task Group 2

- [ ] 3.0 Complete ${self:} resolution algorithm
  - [ ] 3.1 Write 5-7 focused tests for ${self:} resolution
    - Test simple reference: ${self:service}
    - Test nested reference: ${self:provider.stage}
    - Test deep nested reference: ${self:custom.baseName}
    - Test array/list access if needed: ${self:custom.domains[0]}
    - Test undefined reference error (strict mode)
    - Test recursive self-reference (should resolve nested variables)
  - [ ] 3.2 Implement path traversal logic in variable_resolution.tf
    - Parse "provider.stage" path into ["provider", "stage"] segments
    - Navigate local.parsed_config using path segments
    - Use try() for safe navigation (follows locals.tf patterns)
    - Return resolved value or null if path not found
  - [ ] 3.3 Add recursive resolution with depth tracking
    - After resolving ${self:path}, check if result contains more ${...}
    - Recursively resolve up to var.max_variable_depth times
    - Track current_depth to prevent infinite recursion
    - Build resolution_path for circular reference detection
  - [ ] 3.4 Implement circular reference detection
    - Track visited paths during resolution
    - Detect when same path is visited twice
    - Generate clear error with circular_reference_path
  - [ ] 3.5 Create resolved_self_config local
    - Walk through entire parsed_config structure
    - Replace all ${self:} patterns with resolved values
    - Preserve non-variable strings unchanged
    - Use for comprehensions like locals.tf patterns
  - [ ] 3.6 Ensure ${self:} resolution tests pass
    - Run ONLY the 5-7 tests written in 3.1
    - Verify self-references resolve correctly
    - Verify circular reference detection works
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 5-7 tests written in 3.1 pass
- ${self:service} resolves to service name
- ${self:provider.stage} resolves to stage value
- Nested self-references resolve correctly
- Circular references are detected with clear error message
- Max depth exceeded produces clear error
- Resolution follows existing locals.tf coding patterns

**Files to Create/Modify:**
- `/home/tom/p/t/sls.tf/variable_resolution.tf` (extend)
- `/home/tom/p/t/sls.tf/tests/self_variable_resolution.tftest.hcl` (new test file)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-self-nested.yml` (new fixture)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-circular.yml` (new fixture for error case)

---

### Task Group 4: ${env:} Resolution Algorithm

#### Dependencies: Task Group 3

- [ ] 4.0 Complete ${env:} resolution algorithm
  - [ ] 4.1 Write 4-6 focused tests for ${env:} resolution
    - Test basic env resolution: ${env:NODE_ENV}
    - Test env with default value: ${env:MISSING, 'dev'}
    - Test undefined env without default (strict mode error)
    - Test undefined env without default (non-strict mode empty string)
    - Test env variable in combination with self-reference
  - [ ] 4.2 Implement env variable resolution in variable_resolution.tf
    - Map ${env:VAR_NAME} to var.env_vars["VAR_NAME"]
    - Use try(var.env_vars["VAR_NAME"], null) for safe lookup
    - Apply default value if provided and lookup fails
    - Error in strict mode if undefined and no default
  - [ ] 4.3 Integrate env resolution with self resolution
    - Resolve ${env:} and ${self:} in same pass
    - Handle strings with multiple variable types
    - Maintain recursive resolution for nested variables
  - [ ] 4.4 Create resolved_config local (final output)
    - Combine resolved_self_config with env resolution
    - This becomes the replacement for parsed_config
    - Follow same structure as parsed_config
  - [ ] 4.5 Ensure ${env:} resolution tests pass
    - Run ONLY the 4-6 tests written in 4.1
    - Verify env variables resolve from var.env_vars
    - Verify default values work correctly
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 4-6 tests written in 4.1 pass
- ${env:VAR} resolves from var.env_vars["VAR"]
- Default values work: ${env:MISSING, 'default'}
- Strict mode enforces defined variables
- Non-strict mode allows undefined variables (returns empty string)
- Combined ${self:} and ${env:} resolution works
- local.resolved_config is ready to replace local.parsed_config

**Files to Create/Modify:**
- `/home/tom/p/t/sls.tf/variable_resolution.tf` (extend)
- `/home/tom/p/t/sls.tf/tests/env_variable_resolution.tftest.hcl` (new test file)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-env-defaults.yml` (new fixture)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-env-strict.yml` (new fixture)

---

### Task Group 5: Integration with Existing Resources

#### Dependencies: Task Group 4

- [ ] 5.0 Complete integration with existing resources
  - [ ] 5.1 Write 3-5 focused integration tests
    - Test Lambda function uses resolved variable in name
    - Test IAM role uses resolved service/stage names
    - Test API Gateway path uses resolved variable
    - Test existing tests continue to pass with resolved_config
  - [ ] 5.2 Update locals.tf to use resolved_config
    - Change provider_with_defaults to read from resolved_config
    - Change functions_with_defaults_prevalidation to use resolved_config
    - Update all references from parsed_config to resolved_config
    - Maintain backward compatibility for non-variable configs
  - [ ] 5.3 Add variable_resolution_errors to validation_errors
    - Extend validation_errors concat in locals.tf
    - Add variable_resolution_errors from variable_resolution.tf
    - Follow existing error aggregation pattern
    - Include circular reference errors, undefined variable errors, max depth errors
  - [ ] 5.4 Add resolved_config to null_resource validation
    - Ensure config_validation resource checks variable_resolution_errors
    - Maintain all existing validation checks
  - [ ] 5.5 Ensure integration tests pass
    - Run ONLY the 3-5 tests written in 5.1
    - Verify resources use resolved values
    - Verify existing functionality unchanged
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 3-5 tests written in 5.1 pass
- All existing resources now use local.resolved_config
- Variable resolution errors appear in validation output
- Configs without variables continue to work unchanged
- No breaking changes to existing functionality
- Error messages maintain clarity and actionability

**Files to Create/Modify:**
- `/home/tom/p/t/sls.tf/locals.tf` (modify)
- `/home/tom/p/t/sls.tf/tests/variable_integration.tftest.hcl` (new test file)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-integration.yml` (new fixture)

---

### Task Group 6: End-to-End Testing & Documentation

#### Dependencies: Task Group 5

- [ ] 6.0 Complete end-to-end testing and documentation
  - [ ] 6.1 Review existing tests and fill critical gaps only
    - Review the 3-5 tests from Task 1.1 (variable inputs)
    - Review the 4-6 tests from Task 2.1 (pattern detection)
    - Review the 5-7 tests from Task 3.1 (${self:} resolution)
    - Review the 4-6 tests from Task 4.1 (${env:} resolution)
    - Review the 3-5 tests from Task 5.1 (integration)
    - Total existing tests: approximately 19-29 tests
  - [ ] 6.2 Analyze test coverage gaps for Phase 1 only
    - Identify critical user workflows lacking coverage
    - Focus ONLY on Phase 1 features (${self:} and ${env:})
    - Do NOT assess entire application test coverage
    - Prioritize end-to-end workflows over unit test gaps
  - [ ] 6.3 Write up to 8 additional strategic tests maximum
    - Add maximum of 8 new tests to fill identified gaps
    - Focus on realistic Serverless Framework configs
    - Test error message clarity and actionability
    - Test combination of self and env variables
    - Test edge cases like empty strings, special characters
    - Skip performance tests unless business-critical
  - [ ] 6.4 Run all Phase 1 variable resolution tests
    - Run ALL variable resolution tests (19-37 tests total)
    - Verify critical workflows pass
    - Document any known limitations
  - [ ] 6.5 Run complete test suite to ensure no regressions
    - Run the FULL existing test suite (all 32+ test files)
    - Verify NO existing tests are broken by changes
    - This is the ONLY task that runs the complete test suite
    - Fix any regressions before completing task group
  - [ ] 6.6 Create example fixtures for documentation
    - Create realistic serverless.yml examples
    - Show before/after with variable resolution
    - Include common patterns (${self:service}-${self:provider.stage})
    - Document error cases and how to fix them

**Acceptance Criteria:**
- All Phase 1 tests pass (approximately 19-37 tests)
- Complete test suite passes with NO regressions
- No more than 8 additional tests added for gap coverage
- Example fixtures demonstrate common use cases
- Error messages guide users to solutions
- Variable resolution covers 80% of common use cases
- Documentation explains ${self:} and ${env:} patterns clearly

**Files to Create/Modify:**
- `/home/tom/p/t/sls.tf/tests/variable_resolution_gaps.tftest.hcl` (new test file for gap coverage)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-complete-example.yml` (comprehensive example)
- `/home/tom/p/t/sls.tf/tests/fixtures/variables-real-world.yml` (realistic config)
- `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-28-variable-resolution-engine/examples/` (documentation examples)

---

## Execution Order

**Recommended implementation sequence:**
1. **Variable Input Infrastructure** (Task Group 1) - Foundation for variable passing
2. **Variable Pattern Detection** (Task Group 2) - Identify variables to resolve
3. **${self:} Resolution Algorithm** (Task Group 3) - Core resolution logic
4. **${env:} Resolution Algorithm** (Task Group 4) - Environment variable support
5. **Integration with Existing Resources** (Task Group 5) - Connect to resource generation
6. **End-to-End Testing & Documentation** (Task Group 6) - Validate and document

---

## Key Technical Decisions

### Architecture
- **File Organization:** All resolution logic in new variable_resolution.tf file
- **Integration Point:** Create local.resolved_config, swap in locals.tf
- **Error Handling:** Follow existing validation_errors concat pattern in locals.tf
- **Coding Style:** Match existing locals.tf patterns (try/coalesce/for/flatten)

### Resolution Strategy
- **Single Pass Approach:** Resolve ${self:} and ${env:} in one traversal
- **Recursive Resolution:** Support nested variables up to max_variable_depth
- **Depth Tracking:** Prevent infinite recursion with depth counter
- **Circular Detection:** Track resolution path, error on revisit

### Testing Approach
- **Focused Tests Per Group:** 3-7 tests per development task group
- **Incremental Validation:** Run only new tests during development
- **Final Integration:** Run full suite only in Task Group 6
- **Fixture Reuse:** Create reusable YAML fixtures for common patterns

### Backward Compatibility
- **No Breaking Changes:** Configs without variables work unchanged
- **Opt-In Variables:** Only resolve when ${...} patterns detected
- **Default Behavior:** strict_variable_resolution=true for safety

---

## Phase 1 Success Metrics

- [ ] ${self:service} resolves correctly in 100% of test cases
- [ ] ${self:provider.stage} resolves correctly in 100% of test cases
- [ ] ${env:VAR} resolves from var.env_vars map in 100% of test cases
- [ ] Default values work: ${env:MISSING, 'default'}
- [ ] Circular references detected with clear error message
- [ ] Max depth exceeded produces clear error
- [ ] All existing tests continue to pass (no regressions)
- [ ] Test coverage >80% for variable resolution logic
- [ ] Error messages are actionable (tell user how to fix)
- [ ] Reduces config duplication by >50% in example configs

---

## Out of Scope (Phase 1)

**Deferred to Phase 2:**
- ${opt:} CLI option overrides
- ${cf:} CloudFormation stack outputs
- ${ssm:} SSM parameter references
- Data source integration (aws_cloudformation_stack, aws_ssm_parameter)

**Deferred to Phase 3:**
- ${file()} external file loading
- JSONPath-style key extraction
- Performance optimization and caching

**Explicitly Excluded:**
- CloudFormation intrinsic functions (!Ref, !GetAtt)
- AWS Secrets Manager integration
- Custom variable resolvers/plugins
- Git/HTTP-based variable sources

---

## Implementation Notes

### Pattern Matching Approach
Use Terraform's `regexall()` to extract variable patterns:
```hcl
# Extract all ${...} patterns from a string
variable_patterns = regexall("\\$\\{([^}]+)\\}", string_value)

# Parse each pattern to determine type (self, env)
variable_type = split(":", pattern)[0]
variable_path = join(":", slice(split(":", pattern), 1, length(split(":", pattern))))
```

### Path Traversal Logic
Navigate nested config using recursive lookup:
```hcl
# Split path "provider.stage" -> ["provider", "stage"]
path_segments = split(".", variable_path)

# Navigate parsed_config: parsed_config["provider"]["stage"]
# Use try() for safe navigation
resolved_value = try(
  local.parsed_config[path_segments[0]][path_segments[1]],
  null
)
```

### Error Aggregation
Follow existing locals.tf pattern:
```hcl
variable_resolution_errors = concat(
  # Circular reference errors
  local.has_circular_reference ? [
    "Circular variable reference detected: ${join(" -> ", local.circular_path)}"
  ] : [],

  # Undefined variable errors
  [
    for ref in local.undefined_references :
    "Undefined variable '${ref.pattern}' in ${ref.location}..."
  ],

  # Max depth errors
  local.depth_exceeded ? ["Variable resolution exceeded max depth..."] : []
)
```

### Integration Pattern
Minimal changes to existing files:
```hcl
# locals.tf - BEFORE
provider_with_defaults = merge(
  try(local.parsed_config.provider, {}),
  { ... }
)

# locals.tf - AFTER
provider_with_defaults = merge(
  try(local.resolved_config.provider, {}),
  { ... }
)
```

---

## Testing Strategy

### Test File Organization
- **variable_inputs.tftest.hcl** - Variable input validation
- **variable_pattern_detection.tftest.hcl** - Regex pattern extraction
- **self_variable_resolution.tftest.hcl** - ${self:} resolution logic
- **env_variable_resolution.tftest.hcl** - ${env:} resolution logic
- **variable_integration.tftest.hcl** - Integration with resources
- **variable_resolution_gaps.tftest.hcl** - Gap coverage tests

### Fixture Organization
- **variables-self-basic.yml** - Simple ${self:service}
- **variables-self-nested.yml** - ${self:provider.stage}
- **variables-env-basic.yml** - Simple ${env:NODE_ENV}
- **variables-env-defaults.yml** - ${env:VAR, 'default'}
- **variables-circular.yml** - Circular reference error case
- **variables-mixed-patterns.yml** - Multiple variable types
- **variables-integration.yml** - Full config with variables
- **variables-complete-example.yml** - Comprehensive example

### Test Execution Strategy
1. **During Development:** Run only new tests for current task group
2. **Before PR:** Run all variable resolution tests (19-37 tests)
3. **Final Validation:** Run complete test suite (all 32+ files)
4. **LocalStack:** Verify resolution works in LocalStack environment

---

## Standards Compliance

This task breakdown aligns with user standards:

**Testing Standards (/home/tom/p/t/sls.tf/agent-os/standards/testing/test-writing.md):**
- Write 2-8 focused tests per task group (we use 3-7 range)
- Test only core user flows during development
- Defer edge case testing to gap coverage phase
- Run full suite only in final task group

**Coding Style (/home/tom/p/t/sls.tf/agent-os/standards/global/coding-style.md):**
- Follow existing locals.tf patterns (try/coalesce/for/flatten)
- Use meaningful names (resolved_config, variable_resolution_errors)
- DRY principle - reuse pattern detection logic
- Remove dead code - no commented examples

**Conventions:**
- Match existing Terraform file structure
- Follow HCL formatting from existing files
- Maintain alphabetical ordering where used
- Use consistent indentation (2 spaces)
