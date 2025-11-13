# Task Breakdown: IAM Role & Policy Management

## Overview
Total Tasks: Approximately 26 sub-tasks across 5 task groups

## Task List

### Parsing & Normalization Layer

#### Task Group 1: IAM Statement Parsing and Normalization
**Dependencies:** Roadmap #1 (Core Module) and Roadmap #2 (Lambda Translation) must be complete

- [ ] 1.0 Complete IAM statement parsing and normalization
  - [ ] 1.1 Write 2-5 focused tests for statement parsing
    - Test provider-level iamRoleStatements parsing
    - Test function-level iamRoleStatements parsing
    - Test Action/Resource normalization (string to array)
    - Test missing/empty iamRoleStatements handling
    - Skip exhaustive edge cases at this stage
  - [ ] 1.2 Add provider-level statement parsing logic to locals.tf
    - Parse `local.parsed_config.provider.iamRoleStatements` array
    - Use `try()` to handle missing field gracefully
    - Return empty array if iamRoleStatements not present
    - Reference existing pattern from roadmap #1
  - [ ] 1.3 Implement Action/Resource normalization for provider statements
    - Normalize Action field: convert string to single-element array
    - Normalize Resource field: convert string to single-element array
    - Use `try(tolist(stmt.Action), [stmt.Action])` pattern
    - Preserve arrays as-is when already in array format
  - [ ] 1.4 Add function-level statement parsing logic to locals.tf
    - Parse `func.iamRoleStatements` per function in functions_with_defaults
    - Create map keyed by function name
    - Use `try()` to handle missing field gracefully
    - Return empty array for functions without iamRoleStatements
  - [ ] 1.5 Implement Action/Resource normalization for function statements
    - Apply same normalization logic as provider statements
    - Normalize within function statement iteration
    - Ensure consistent array format across all statements
  - [ ] 1.6 Ensure parsing tests pass
    - Run ONLY the 2-5 tests written in 1.1
    - Verify normalization produces correct array formats
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-5 tests written in 1.1 pass
- Provider statements parsed correctly into normalized format
- Function statements parsed per function into normalized format
- String Action/Resource converted to arrays
- Array Action/Resource preserved as arrays
- Missing iamRoleStatements handled gracefully (empty arrays)

### Policy Merging Layer

#### Task Group 2: Statement Merging and Policy Map Generation
**Dependencies:** Task Group 1

- [ ] 2.0 Complete policy merging logic
  - [ ] 2.1 Write 2-5 focused tests for policy merging
    - Test provider statements only (applies to all functions)
    - Test function statements only (applies to specific function)
    - Test combined provider + function statements (merged)
    - Test no statements (empty merged result)
    - Skip exhaustive merging scenarios at this stage
  - [ ] 2.2 Implement merged_iam_statements local in locals.tf
    - Iterate over all functions in functions_with_defaults
    - Concatenate provider statements + function statements using `concat()`
    - Preserve statement order: provider statements first, then function statements
    - Create map keyed by function name
  - [ ] 2.3 Implement functions_with_policies local in locals.tf
    - Filter merged_iam_statements to only functions with non-empty statements
    - Use conditional: `if length(statements) > 0`
    - Create map suitable for resource `for_each` iteration
    - Exclude functions with zero statements
  - [ ] 2.4 Verify merging preserves statement order
    - Provider-level statements appear first in merged array
    - Function-level statements appear after provider statements
    - No automatic statement deduplication
  - [ ] 2.5 Ensure merging tests pass
    - Run ONLY the 2-5 tests written in 2.1
    - Verify correct statement merging for all scenarios
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-5 tests written in 2.1 pass
- Provider statements included in ALL function policies
- Function statements included ONLY in specific function's policy
- Statement order preserved: provider first, then function
- Functions without statements excluded from functions_with_policies map
- No statement deduplication (explicit configuration honored)

### Validation Layer

#### Task Group 3: IAM Statement Validation Rules
**Dependencies:** Task Group 1

- [ ] 3.0 Complete IAM validation logic
  - [ ] 3.1 Write 2-5 focused tests for validation
    - Test invalid Effect value rejection
    - Test missing Action field rejection
    - Test missing Resource field rejection
    - Test invalid action format rejection (no service:action pattern)
    - Skip exhaustive validation scenarios at this stage
  - [ ] 3.2 Add provider-level IAM validation to locals.tf
    - Validate Effect is "Allow" or "Deny"
    - Validate Action field exists
    - Validate Resource field exists
    - Collect errors in provider_iam_validation_errors local
    - Include statement index in error messages
  - [ ] 3.3 Add function-level IAM validation to locals.tf
    - Validate Effect values for each function's statements
    - Validate Action field exists for each statement
    - Validate Resource field exists for each statement
    - Collect errors in iam_validation_errors local
    - Include function name and statement index in error messages
  - [ ] 3.4 Implement action format validation
    - Create validate_action_format helper function
    - Check each action matches `service:action` pattern
    - Use `can(regex("^[a-z0-9]+:[*a-zA-Z0-9]+$", act))` pattern
    - Support wildcards in action (e.g., s3:*, dynamodb:GetItem)
    - Return validation errors for invalid formats
  - [ ] 3.5 Integrate IAM validations into existing validation_errors
    - Add provider_iam_validation_errors to validation_errors concat
    - Add iam_validation_errors to validation_errors concat
    - Follow existing validation pattern from roadmap #1
    - Ensure all errors collected before halting
  - [ ] 3.6 Ensure validation tests pass
    - Run ONLY the 2-5 tests written in 3.1
    - Verify all validation rules enforce correctly
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-5 tests written in 3.1 pass
- Invalid Effect values rejected with clear error message
- Missing Action field rejected with clear error message
- Missing Resource field rejected with clear error message
- Invalid action format rejected (must match service:action)
- Error messages include function name and statement index
- All validation errors collected before halting execution

### IAM Policy Resource Layer

#### Task Group 4: Policy Document Generation and Resource Creation
**Dependencies:** Task Groups 2 and 3

- [ ] 4.0 Complete IAM policy resource creation
  - [ ] 4.1 Write 2-5 focused tests for policy resources
    - Test policy resource created for function with statements
    - Test no policy resource for function without statements
    - Test policy document JSON structure (Version, Statement array)
    - Test policy attachment to correct IAM role
    - Skip exhaustive resource scenarios at this stage
  - [ ] 4.2 Add aws_iam_role_policy resource to main.tf
    - Use `for_each = local.functions_with_policies`
    - Generate policy name: `{service}-{stage}-{function}-policy`
    - Reference IAM role: `aws_iam_role.lambda_execution[each.key].name`
    - Generate policy JSON using jsonencode()
  - [ ] 4.3 Implement policy document generation
    - Include Version: "2012-10-17" in policy document
    - Create Statement array from each.value (merged statements)
    - Map each statement to include Effect, Action, Resource
    - Preserve Action and Resource as arrays (already normalized)
  - [ ] 4.4 Verify policy naming convention
    - Policy name pattern: `{service_name}-{stage}-{function_key}-policy`
    - Example: `my-service-dev-worker-policy`
    - Matches Lambda function and role naming from roadmap #2
    - Ensures uniqueness across stages and services
  - [ ] 4.5 Verify policy attachment strategy
    - Policies attached as inline policies (not managed policies)
    - One policy resource per function with statements
    - Attached to correct IAM role created in roadmap #2
    - Does not conflict with AWSLambdaBasicExecutionPolicy attachment
  - [ ] 4.6 Ensure policy resource tests pass
    - Run ONLY the 2-5 tests written in 4.1
    - Verify correct policy resources created
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-5 tests written in 4.1 pass
- aws_iam_role_policy resources created for functions with statements
- No policy resources created for functions without statements
- Policy documents have correct JSON structure (Version + Statement array)
- Policies attached to correct IAM roles from roadmap #2
- Policy naming follows convention: {service}-{stage}-{function}-policy
- Inline policies created (not managed policies)

### Outputs & Integration Layer

#### Task Group 5: Output Interface and Integration Verification
**Dependencies:** Task Group 4

- [ ] 5.0 Complete outputs and integration
  - [ ] 5.1 Write 2-4 focused tests for outputs
    - Test policy_arns output map structure
    - Test policy_names output map structure
    - Test outputs empty when no policies created
    - Skip exhaustive output scenarios at this stage
  - [ ] 5.2 Add policy outputs to outputs.tf
    - Add policy_arns output: map of policy ARNs by function name
    - Add policy_names output: map of policy names by function name
    - Include descriptions for each output
    - Handle empty map when no policies created
  - [ ] 5.3 Create IAM policy example in examples/iam-policies/
    - Create serverless.yml with provider-level iamRoleStatements
    - Create serverless.yml with function-level iamRoleStatements
    - Create serverless.yml with combined statements
    - Include example with no statements (default behavior)
  - [ ] 5.4 Add example Terraform configuration
    - Create main.tf that uses module with IAM policies
    - Create outputs.tf to display policy ARNs and names
    - Document expected behavior in README
  - [ ] 5.5 Verify integration with roadmap #2
    - Ensure policies attach to IAM roles created in roadmap #2
    - Verify basic execution policy remains attached
    - Verify no conflicts between inline and managed policies
    - Test terraform plan shows correct policy count
  - [ ] 5.6 Ensure output and integration tests pass
    - Run ONLY the 2-4 tests written in 5.1
    - Verify outputs structure correct
    - Verify integration with roadmap #2 works
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-4 tests written in 5.1 pass
- Policy ARNs output as map keyed by function name
- Policy names output as map keyed by function name
- Outputs return empty maps when no policies created
- Example configurations demonstrate all IAM policy scenarios
- Integration with roadmap #2 IAM roles verified
- Basic execution policy remains attached (no conflicts)

### Testing & Verification

#### Task Group 6: Comprehensive Test Coverage Review
**Dependencies:** Task Groups 1-5

- [ ] 6.0 Review existing tests and fill critical gaps only
  - [ ] 6.1 Review tests from Task Groups 1-5
    - Review 2-5 tests from parsing (Task 1.1)
    - Review 2-5 tests from merging (Task 2.1)
    - Review 2-5 tests from validation (Task 3.1)
    - Review 2-5 tests from policy resources (Task 4.1)
    - Review 2-4 tests from outputs (Task 5.1)
    - Total existing tests: approximately 10-24 tests
  - [ ] 6.2 Analyze test coverage gaps for IAM policy feature only
    - Identify critical IAM workflows lacking test coverage
    - Focus ONLY on gaps related to this spec's IAM requirements
    - Do NOT assess entire application test coverage
    - Prioritize end-to-end policy generation workflows
  - [ ] 6.3 Write up to 10 additional strategic tests maximum
    - Test action wildcard preservation (s3:*, dynamodb:GetItem)
    - Test resource ARN pattern preservation (wildcards in ARNs)
    - Test policy size validation (10,240 character limit)
    - Test terraform plan/apply/destroy workflow
    - Test Lambda invocation with granted IAM permissions
    - Do NOT write comprehensive coverage for all scenarios
    - Skip performance tests and exhaustive edge cases
  - [ ] 6.4 Run feature-specific tests only
    - Run ONLY tests related to IAM policy feature
    - Expected total: approximately 20-34 tests maximum
    - Do NOT run entire application test suite
    - Verify critical IAM policy workflows pass
  - [ ] 6.5 Verify Terraform integration end-to-end
    - Run terraform fmt on all modified .tf files
    - Run terraform init to verify provider requirements
    - Run terraform plan with IAM policy examples
    - Run terraform apply to create policies in test account
    - Run terraform destroy to clean up resources
  - [ ] 6.6 Verify Serverless Framework compatibility
    - Compare generated policies to Serverless Framework output
    - Verify action wildcards work identically
    - Verify resource ARN patterns work identically
    - Verify policy merging produces same effective permissions

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 20-34 tests total)
- Critical IAM policy workflows covered by tests
- No more than 10 additional tests added when filling gaps
- Testing focused exclusively on this spec's IAM requirements
- Terraform plan/apply/destroy workflow verified
- Generated policies match Serverless Framework behavior
- Action wildcards and ARN patterns preserved exactly

## Execution Order

Recommended implementation sequence:
1. Parsing & Normalization Layer (Task Group 1)
2. Policy Merging Layer (Task Group 2)
3. Validation Layer (Task Group 3) - can run in parallel with Task Group 2
4. IAM Policy Resource Layer (Task Group 4)
5. Outputs & Integration Layer (Task Group 5)
6. Testing & Verification (Task Group 6)

## Implementation Notes

### Key Technical Decisions

**Statement Normalization Strategy:**
- Use `try(tolist(stmt.Action), [stmt.Action])` to normalize strings to arrays
- Apply normalization during parsing, not during policy generation
- Ensures consistent data structure throughout the module

**Policy Merging Strategy:**
- Use `concat()` to merge provider and function statements
- Provider statements always first, function statements second
- No deduplication - preserve explicit configuration

**Validation Approach:**
- Validate early during parsing, not during resource creation
- Collect all validation errors before halting (user-friendly)
- Include context in error messages (function name, statement index)

**Resource Generation Pattern:**
- Use `for_each` over `functions_with_policies` (not all functions)
- Inline policies (aws_iam_role_policy), not managed policies
- One policy per function containing all merged statements

### Integration Points with Existing Code

**From Roadmap #1 (Core Module):**
- Consume `local.parsed_config.provider.iamRoleStatements`
- Consume `local.functions_with_defaults[func].iamRoleStatements`
- Consume `local.service_name` for policy naming
- Consume `local.provider_with_defaults.stage` for policy naming
- Extend `local.validation_errors` with IAM validation errors

**From Roadmap #2 (Lambda Translation):**
- Reference `aws_iam_role.lambda_execution[each.key]` for policy attachment
- Follow same naming convention for consistency
- Do not modify basic execution policy attachment

### Code Quality Checklist

- [ ] Run `terraform fmt` on all .tf files
- [ ] Use descriptive local names (provider_iam_statements, merged_iam_statements)
- [ ] Add comments explaining policy merging and statement order
- [ ] Keep validation rules readable (one condition per line)
- [ ] Follow snake_case naming convention
- [ ] Include descriptions for all outputs
- [ ] Document examples with clear README

### Testing Checklist

- [ ] Create example with provider-level statements only
- [ ] Create example with function-level statements only
- [ ] Create example with combined provider + function statements
- [ ] Create example with no statements (verify no policies created)
- [ ] Test string and array formats for Action/Resource
- [ ] Test action wildcards (s3:*, dynamodb:GetItem)
- [ ] Test resource ARN patterns with wildcards
- [ ] Verify terraform plan shows correct policy count
- [ ] Verify terraform apply creates policies successfully
- [ ] Verify terraform destroy removes policies cleanly
- [ ] Test Lambda invocation with granted permissions (e.g., DynamoDB access)

### Security Considerations

- Preserve user-specified permissions exactly (no automatic changes)
- Validate IAM policy syntax to prevent runtime errors
- Do not include secrets in policy documents
- Follow AWS IAM best practices for policy attachment
- No automatic ARN substitution (deferred to roadmap #10)

### Performance Considerations

- Policy generation occurs during Terraform plan phase
- Statement merging efficient for typical statement counts
- Validation runs once during plan (no runtime overhead)
- No external IAM policy validation calls (pure HCL)

### Future Enhancements (Out of Scope)

- Condition blocks in IAM statements
- NotAction and NotPrincipal fields
- Variable resolution in Action/Resource ARNs (roadmap #10)
- Permission boundaries
- Managed policy attachment
- Policy optimization (deduplication, consolidation)

---

**This task breakdown is ready for implementation.** Each task group builds on the previous one, with clear dependencies and acceptance criteria. The focus is on achieving Serverless Framework compatibility while maintaining Terraform best practices.
