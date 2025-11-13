# Task Breakdown: Route 53 & Custom Domain Management

## Overview

**Feature:** Route 53 & Custom Domain Management for API Gateway
**Roadmap Item:** #12
**Dependencies:** Roadmap #4 (API Gateway REST API Integration)
**Total Task Groups:** 6
**Implementation Approach:** Terraform module development with validation-first design

This task breakdown organizes implementation into logical phases: module structure setup, configuration parsing, validation implementation, Route 53 resources, API Gateway resources, and testing. Each task group is designed for focused specialist work with clear dependencies and acceptance criteria.

---

## Task List

### Task Group 1: Module Structure & Foundation Setup
**Specialist:** Infrastructure Engineer
**Dependencies:** None
**Estimated Tasks:** 6

- [ ] 1.0 Set up custom domain module structure
  - [ ] 1.1 Create module directory structure
    - Create `/home/tom/p/t/sls.tf/modules/custom-domain/` directory
    - Create empty files: `main.tf`, `variables.tf`, `outputs.tf`, `data.tf`, `route53.tf`, `validation.tf`
    - Follow existing module organization pattern from core module
  - [ ] 1.2 Define module input variables in `variables.tf`
    - Create `domain_config` variable (object type with domainName, basePath, stage, createRoute53Record, certificateArn, hostedZoneId, endpointType)
    - Create `api_gateway_rest_api` variable (string, API ID from roadmap #4)
    - Create `api_gateway_stage` variable (string, stage name)
    - Create `create_hosted_zone` variable (bool, default false)
    - Create `acm_certificate_arn` variable (string, optional)
    - Create `aws_region` variable (string, for certificate validation)
    - Add validation blocks for required variables
    - Include descriptive comments matching spec requirements
  - [ ] 1.3 Set up module outputs in `outputs.tf`
    - Define `custom_domain_name` output (configured domain or null)
    - Define `custom_domain_target` output (CloudFront/regional endpoint DNS)
    - Define `custom_domain_hosted_zone_id` output (Route 53 zone ID)
    - Define `custom_domain_base_path` output (base path or null)
    - Define `route53_record_fqdn` output (DNS record FQDN or null)
    - Define `api_gateway_domain_name_id` output (resource ID)
    - All outputs should handle null cases when domain not configured
  - [ ] 1.4 Add module integration to root `main.tf`
    - Add `enable_custom_domain` variable to root `/home/tom/p/t/sls.tf/variables.tf` (bool, default false)
    - Add `create_hosted_zone` variable to root variables (bool, default false)
    - Add `acm_certificate_arn` variable to root variables (string, optional)
    - Create module block invoking `modules/custom-domain/` with conditional count
    - Count condition: `var.enable_custom_domain && try(local.provider_with_defaults.customDomain, null) != null ? 1 : 0`
    - Pass variables: domain_config, api_gateway_rest_api, api_gateway_stage, create_hosted_zone, acm_certificate_arn, aws_region
  - [ ] 1.5 Write 2-4 focused tests for module structure
    - Test module loads successfully with minimal valid configuration
    - Test module does not create resources when enable_custom_domain=false
    - Test module errors appropriately when customDomain block missing
    - Run ONLY these 2-4 structural tests to verify foundation
  - [ ] 1.6 Verify module structure setup
    - Run `terraform init` to validate module structure
    - Run `terraform fmt -recursive` on all module files
    - Run the 2-4 structural tests from step 1.5
    - Verify no syntax errors in module files

**Acceptance Criteria:**
- Module directory structure created under `modules/custom-domain/`
- All 6 required Terraform files created (main, variables, outputs, data, route53, validation)
- Module integrated into root `main.tf` with conditional creation pattern
- Variables defined with proper types and validation blocks
- Outputs defined with null-safe logic
- The 2-4 structural tests pass
- `terraform init` and `terraform fmt` succeed

---

### Task Group 2: Configuration Parsing & Default Application
**Specialist:** Configuration Engineer
**Dependencies:** Task Group 1
**Estimated Tasks:** 5

- [ ] 2.0 Implement configuration parsing and defaults
  - [ ] 2.1 Parse customDomain configuration in module locals
    - In `modules/custom-domain/main.tf`, create locals block
    - Extract customDomain fields: domainName, basePath, stage, createRoute53Record, certificateArn, hostedZoneId, endpointType
    - Use `try()` wrapper for safe field access (pattern from core module)
    - Handle missing customDomain block gracefully (return null)
  - [ ] 2.2 Apply Serverless Framework default values
    - Create `custom_domain_config` local value with defaults merged
    - Default `createRoute53Record = true` (Serverless Framework behavior)
    - Default `endpointType = "EDGE"` (Serverless Framework default)
    - Default `stage = var.api_gateway_stage` if not specified in config
    - Use `coalesce()` for default application (existing pattern)
  - [ ] 2.3 Implement certificate ARN resolution logic
    - Create `certificate_arn` local value
    - Priority 1: Use `var.domain_config.certificateArn` if provided
    - Priority 2: Fall back to `var.acm_certificate_arn` module variable
    - Use `coalesce()` to chain resolution: `coalesce(try(var.domain_config.certificateArn, null), var.acm_certificate_arn)`
  - [ ] 2.4 Implement hosted zone resolution logic
    - Create `hosted_zone_id` local value
    - Priority 1: Use `var.domain_config.hostedZoneId` if provided
    - Priority 2: Use created zone ID from `aws_route53_zone.custom_domain[0].zone_id`
    - Priority 3: Use looked-up zone ID from `data.aws_route53_zone.existing[0].zone_id`
    - Use `coalesce()` to chain resolution across all three sources
  - [ ] 2.5 Write 2-4 focused tests for configuration parsing
    - Test default values applied correctly (createRoute53Record=true, endpointType="EDGE")
    - Test certificate ARN resolution from config takes precedence over module variable
    - Test stage fallback from provider.stage when not in customDomain
    - Run ONLY these 2-4 parsing tests to verify logic
  - [ ] 2.6 Verify configuration parsing
    - Test with serverless.yml containing minimal customDomain block
    - Test with customDomain block containing all optional fields
    - Verify defaults applied as expected
    - Run the 2-4 parsing tests from step 2.5

**Acceptance Criteria:**
- Configuration parsing extracts all customDomain fields using safe `try()` access
- Serverless Framework defaults applied correctly (createRoute53Record, endpointType, stage)
- Certificate ARN resolution prioritizes config over module variable
- Hosted zone resolution handles lookup, creation, and config sources
- The 2-4 parsing tests pass
- No errors when customDomain block absent (graceful null handling)

---

### Task Group 3: Validation Implementation
**Specialist:** Validation Engineer
**Dependencies:** Task Group 2
**Estimated Tasks:** 8

- [ ] 3.0 Implement comprehensive validation logic
  - [ ] 3.1 Implement required field validation
    - In `modules/custom-domain/validation.tf`, create locals for validation errors
    - Validate `domainName` is present and non-empty when customDomain configured
    - Create `required_field_errors` list for missing required fields
  - [ ] 3.2 Implement domain name format validation
    - Validate `domainName` matches DNS hostname pattern (RFC 1123)
    - Use regex: `^[a-z0-9][a-z0-9-\\.]*[a-z0-9]$`
    - Create `format_validation_errors` list for invalid formats
    - Error message: "Field 'customDomain.domainName' must be a valid DNS hostname (RFC 1123 format)."
  - [ ] 3.3 Implement base path format validation
    - Validate `basePath` has no leading slash (if provided)
    - Validate `basePath` has no trailing slash (if provided)
    - Validate `basePath` contains only alphanumeric, hyphens, underscores
    - Use regex: `^[a-zA-Z0-9_-]+$`
    - Create `base_path_errors` list
    - Error message: "Field 'customDomain.basePath' must contain only alphanumeric characters, hyphens, and underscores with no leading or trailing slashes. Got: '{value}'"
  - [ ] 3.4 Implement endpoint type validation
    - Validate `endpointType` is one of: "EDGE", "REGIONAL", "PRIVATE"
    - Use `contains()` function with valid endpoint types list
    - Create `endpoint_type_errors` list
    - Error message: "Field 'customDomain.endpointType' must be one of: EDGE, REGIONAL, PRIVATE. Got: '{value}'"
  - [ ] 3.5 Implement certificate ARN validation
    - Validate certificate ARN provided from either config or module variable
    - If neither provided, add to `certificate_required_errors` list
    - Validate ARN format: `arn:aws:acm:region:account:certificate/id`
    - Error message if missing: "ACM certificate ARN required for custom domain. Provide via customDomain.certificateArn or acm_certificate_arn module variable."
  - [ ] 3.6 Implement certificate region validation
    - Extract region from certificate ARN using `split(":", var.certificate_arn)[3]`
    - For EDGE endpoints: validate certificate region is "us-east-1"
    - For REGIONAL endpoints: validate certificate region matches `var.aws_region`
    - For PRIVATE endpoints: validate certificate region matches `var.aws_region`
    - Create `certificate_region_errors` list
    - Error message: "Certificate region mismatch: {endpointType} endpoints require certificate in {required_region}, got certificate in {actual_region}"
  - [ ] 3.7 Implement hosted zone validation
    - Validate hosted zone ID available from config, creation, or lookup
    - If none available, add to `hosted_zone_errors` list
    - Validate `hostedZoneId` format if provided: pattern "Z[A-Z0-9]+"
    - Error message: "Route 53 hosted zone required. Provide customDomain.hostedZoneId or set create_hosted_zone=true."
  - [ ] 3.8 Implement validation error collection and enforcement
    - Concatenate all error lists: required_field_errors, format_validation_errors, certificate_validation_errors, certificate_region_errors, endpoint_type_errors, hosted_zone_errors, base_path_errors
    - Create `validation_errors` local as concatenation
    - Create `has_errors` local: `length(local.validation_errors) > 0`
    - Add `null_resource.custom_domain_validation` with precondition
    - Precondition checks `!local.has_errors`
    - Error message displays all errors: "Custom domain validation failed:\n- ${join("\n- ", local.validation_errors)}"
    - Follow pattern from `/home/tom/p/t/sls.tf/main.tf` null_resource validation
  - [ ] 3.9 Write 2-6 focused tests for validation
    - Test invalid domain name format triggers error
    - Test base path with leading slash triggers error
    - Test invalid endpoint type triggers error
    - Test EDGE endpoint with non-us-east-1 certificate triggers error
    - Test missing certificate ARN triggers error
    - Test missing hosted zone (without create flag) triggers error
    - Run ONLY these 2-6 validation tests
  - [ ] 3.10 Verify validation implementation
    - Test with invalid domain name, verify error caught
    - Test with wrong certificate region for EDGE, verify error
    - Test with missing certificate, verify error
    - Verify all errors collected and displayed together
    - Run the 2-6 validation tests from step 3.9

**Acceptance Criteria:**
- All validation rules implemented in `validation.tf`
- Domain name format validated using RFC 1123 regex
- Base path format validated (no slashes, valid characters)
- Endpoint type validated against allowed values
- Certificate ARN presence validated
- Certificate region validated against endpoint type requirements
- Hosted zone availability validated
- All errors collected and displayed together via null_resource precondition
- The 2-6 validation tests pass
- Error messages are clear and reference specific fields

---

### Task Group 4: Route 53 Resources Implementation
**Specialist:** DNS Engineer
**Dependencies:** Task Group 3
**Estimated Tasks:** 6

- [ ] 4.0 Implement Route 53 hosted zone and DNS record resources
  - [ ] 4.1 Implement existing hosted zone lookup in `data.tf`
    - Create `data.aws_route53_zone.existing` data source
    - Conditional count: `var.domain_config.hostedZoneId != null ? 1 : 0`
    - Set `zone_id = var.domain_config.hostedZoneId`
    - This data source looks up existing zone when hostedZoneId provided in config
  - [ ] 4.2 Implement Route 53 zone creation in `route53.tf`
    - Create `aws_route53_zone.custom_domain` resource
    - Conditional count: `var.create_hosted_zone && var.domain_config.hostedZoneId == null ? 1 : 0`
    - Set `name = var.domain_config.domainName`
    - Add comment explaining zone created only when create_hosted_zone=true and no hostedZoneId provided
  - [ ] 4.3 Implement endpoint-specific domain target selection
    - In `main.tf` locals, create `domain_name_target` value
    - For EDGE: use `aws_api_gateway_domain_name.custom_domain.cloudfront_domain_name`
    - For REGIONAL/PRIVATE: use `aws_api_gateway_domain_name.custom_domain.regional_domain_name`
    - Use ternary: `var.domain_config.endpointType == "EDGE" ? cloudfront_domain_name : regional_domain_name`
    - Create `domain_name_zone_id` value with same pattern (cloudfront_zone_id vs regional_zone_id)
  - [ ] 4.4 Implement Route 53 ALIAS record in `route53.tf`
    - Create `aws_route53_record.custom_domain` resource
    - Conditional count: `var.domain_config.createRoute53Record ? 1 : 0`
    - Set `zone_id = local.hosted_zone_id`
    - Set `name = var.domain_config.domainName`
    - Set `type = "A"`
    - Add `alias` block:
      - `name = local.domain_name_target`
      - `zone_id = local.domain_name_zone_id`
      - `evaluate_target_health = true`
    - Add comment explaining ALIAS record used instead of A record (AWS-native, no query limits)
  - [ ] 4.5 Write 2-4 focused tests for Route 53 resources
    - Test hosted zone created when create_hosted_zone=true and no hostedZoneId
    - Test existing hosted zone looked up when hostedZoneId provided
    - Test ALIAS record created when createRoute53Record=true
    - Test ALIAS record not created when createRoute53Record=false
    - Run ONLY these 2-4 Route 53 tests
  - [ ] 4.6 Verify Route 53 resources
    - Test zone creation with create_hosted_zone=true
    - Test zone lookup with hostedZoneId provided
    - Test ALIAS record points to correct target (EDGE vs REGIONAL)
    - Verify conditional creation logic works correctly
    - Run the 2-4 Route 53 tests from step 4.5

**Acceptance Criteria:**
- Existing hosted zone lookup implemented with conditional count
- New hosted zone creation implemented with conditional count
- Domain name target selection handles EDGE vs REGIONAL endpoints correctly
- ALIAS record created with correct target and zone ID
- ALIAS record uses `evaluate_target_health = true`
- Conditional creation based on createRoute53Record flag works
- The 2-4 Route 53 tests pass
- Resources only created when appropriate conditions met

---

### Task Group 5: API Gateway Custom Domain Resources
**Specialist:** API Gateway Engineer
**Dependencies:** Task Group 4
**Estimated Tasks:** 6

- [ ] 5.0 Implement API Gateway domain name and base path mapping
  - [ ] 5.1 Implement API Gateway domain name resource in `main.tf`
    - Create `aws_api_gateway_domain_name.custom_domain` resource
    - Set `domain_name = var.domain_config.domainName`
    - Set `certificate_arn = local.certificate_arn` (from resolution logic)
    - Add `endpoint_configuration` block:
      - `types = [var.domain_config.endpointType]`
    - No conditional count (module itself is conditionally created by root)
    - Add comment explaining EDGE uses CloudFront, REGIONAL uses regional endpoint
  - [ ] 5.2 Implement base path mapping resource in `main.tf`
    - Create `aws_api_gateway_base_path_mapping.custom_domain` resource
    - Set `domain_name = aws_api_gateway_domain_name.custom_domain.domain_name`
    - Set `api_id = var.api_gateway_rest_api` (from roadmap #4)
    - Set `stage_name = coalesce(var.domain_config.stage, var.api_gateway_stage)`
    - Set `base_path = try(var.domain_config.basePath, null)` (optional field)
    - Add depends_on for API Gateway domain name resource
  - [ ] 5.3 Wire up module outputs in `outputs.tf`
    - Implement `custom_domain_name` output: `aws_api_gateway_domain_name.custom_domain.domain_name`
    - Implement `custom_domain_target` output: `local.domain_name_target`
    - Implement `custom_domain_hosted_zone_id` output: `local.hosted_zone_id`
    - Implement `custom_domain_base_path` output: `try(var.domain_config.basePath, null)`
    - Implement `route53_record_fqdn` output: `try(aws_route53_record.custom_domain[0].fqdn, null)`
    - Implement `api_gateway_domain_name_id` output: `aws_api_gateway_domain_name.custom_domain.id`
    - All outputs should be null-safe
  - [ ] 5.4 Add root module outputs for custom domain
    - In root `/home/tom/p/t/sls.tf/outputs.tf`, add custom domain outputs
    - Output `custom_domain_name`: reference `module.custom_domain[0].custom_domain_name` with conditional
    - Output `custom_domain_target`: reference module output
    - Output `route53_record_fqdn`: reference module output
    - All outputs should handle module not being created (count = 0 case)
  - [ ] 5.5 Write 2-6 focused tests for API Gateway resources
    - Test domain name created with correct certificate ARN
    - Test domain name uses correct endpoint type (EDGE vs REGIONAL)
    - Test base path mapping links to correct API and stage
    - Test base path mapping includes basePath when provided
    - Test base path mapping works with null basePath (root path)
    - Test outputs populated correctly for each scenario
    - Run ONLY these 2-6 API Gateway tests
  - [ ] 5.6 Verify API Gateway resources and outputs
    - Test domain name resource with EDGE endpoint
    - Test domain name resource with REGIONAL endpoint
    - Test base path mapping with and without basePath
    - Verify outputs return expected values
    - Verify outputs are null when customDomain not configured
    - Run the 2-6 API Gateway tests from step 5.5

**Acceptance Criteria:**
- API Gateway domain name resource created with correct configuration
- Domain name uses certificate from resolution logic
- Endpoint configuration set from customDomain.endpointType
- Base path mapping connects domain to API stage correctly
- Base path mapping handles optional basePath field
- All 6 module outputs implemented and null-safe
- Root module outputs reference custom domain module outputs
- The 2-6 API Gateway tests pass
- Resources integrate correctly with API Gateway from roadmap #4

---

### Task Group 6: Integration Testing & Validation
**Specialist:** QA Engineer
**Dependencies:** Task Groups 1-5
**Estimated Tasks:** 5

- [ ] 6.0 Perform integration testing and gap analysis
  - [ ] 6.1 Review existing tests from previous task groups
    - Review 2-4 tests from Task 1.5 (module structure)
    - Review 2-4 tests from Task 2.5 (configuration parsing)
    - Review 2-6 tests from Task 3.9 (validation)
    - Review 2-4 tests from Task 4.5 (Route 53 resources)
    - Review 2-6 tests from Task 5.5 (API Gateway resources)
    - Total existing tests: approximately 10-24 tests
  - [ ] 6.2 Analyze test coverage gaps for this feature
    - Identify critical end-to-end workflows not covered
    - Focus on integration between Route 53, API Gateway, and ACM
    - Check coverage of EDGE vs REGIONAL endpoint scenarios
    - Check coverage of certificate region validation scenarios
    - Prioritize gaps in primary user workflows (domain setup, DNS resolution)
    - Skip edge cases unless business-critical
  - [ ] 6.3 Create test configurations in `tests/` directory
    - Create `tests/custom-domain-edge/` directory with serverless.yml for EDGE endpoint test
    - Create `tests/custom-domain-regional/` directory for REGIONAL endpoint test
    - Create `tests/custom-domain-existing-zone/` for hostedZoneId scenario
    - Create `tests/custom-domain-new-zone/` for create_hosted_zone scenario
    - Each test directory should have: serverless.yml, terraform.tfvars, expected outputs
    - Include test for basePath mapping scenario
    - Include test for createRoute53Record=false scenario
  - [ ] 6.4 Write up to 10 additional strategic tests maximum
    - Add integration test: EDGE endpoint with us-east-1 certificate (full workflow)
    - Add integration test: REGIONAL endpoint with matching region certificate
    - Add integration test: Hosted zone lookup when hostedZoneId provided
    - Add integration test: Hosted zone creation when create_hosted_zone=true
    - Add integration test: Base path mapping with basePath specified
    - Add validation test: Certificate region mismatch for EDGE endpoint
    - Add validation test: Certificate region mismatch for REGIONAL endpoint
    - Add validation test: Missing certificate ARN from both sources
    - Add integration test: Skip Route 53 record when createRoute53Record=false
    - Focus on end-to-end workflows and critical validation paths
    - Do NOT test all edge cases or exhaustive scenarios
  - [ ] 6.5 Run feature-specific test suite
    - Run all tests from task groups 1-5 (approximately 10-24 tests)
    - Run up to 10 additional tests from step 6.4
    - Total test count: approximately 20-34 tests maximum
    - Verify all critical workflows pass
    - Verify validation errors display correctly
    - Verify outputs match expected values
    - Do NOT run entire application test suite
    - Focus exclusively on custom domain feature tests

**Acceptance Criteria:**
- All existing tests from task groups 1-5 reviewed (approximately 10-24 tests)
- Test coverage gaps identified for critical workflows
- Test configurations created in `tests/` directory for key scenarios
- Maximum of 10 additional strategic tests added to fill gaps
- All feature-specific tests pass (approximately 20-34 tests total)
- EDGE endpoint with us-east-1 certificate tested end-to-end
- REGIONAL endpoint with regional certificate tested end-to-end
- Hosted zone creation and lookup scenarios tested
- Base path mapping scenarios tested
- Certificate region validation tested
- Route 53 record creation and skip scenarios tested
- No comprehensive edge case testing (focused on critical paths only)

---

## Implementation Order & Dependencies

**Sequential Implementation Flow:**
```
Task Group 1 (Foundation)
    ↓
Task Group 2 (Configuration Parsing)
    ↓
Task Group 3 (Validation)
    ↓
Task Group 4 (Route 53 Resources)
    ↓
Task Group 5 (API Gateway Resources)
    ↓
Task Group 6 (Integration Testing)
```

**Parallel Work Opportunities:**
- Task Groups 4 and 5 can be worked on in parallel after Task Group 3 completes
- Test writing within each group (x.5 steps) can be done by a separate tester in parallel with next group if needed

**Critical Path Items:**
1. Module structure must be complete before configuration parsing
2. Configuration parsing must be complete before validation
3. Validation must be complete before resource creation
4. Route 53 and API Gateway resources depend on validation logic
5. Integration testing depends on all resource implementations

---

## Technical Implementation Notes

### Certificate Region Validation Pattern
```hcl
locals {
  # Extract region from certificate ARN
  certificate_region = local.certificate_arn != null ? split(":", local.certificate_arn)[3] : null

  # Define required region based on endpoint type
  required_region = var.domain_config.endpointType == "EDGE" ? "us-east-1" : var.aws_region

  # Validation error for region mismatch
  certificate_region_errors = local.certificate_arn != null && local.certificate_region != local.required_region ? [
    "Certificate region mismatch: ${var.domain_config.endpointType} endpoints require certificate in ${local.required_region}, got certificate in ${local.certificate_region}"
  ] : []
}
```

### Conditional Resource Creation Pattern
```hcl
# Route 53 zone - create only if create_hosted_zone=true AND hostedZoneId not provided
resource "aws_route53_zone" "custom_domain" {
  count = var.create_hosted_zone && try(var.domain_config.hostedZoneId, null) == null ? 1 : 0
  name  = var.domain_config.domainName
}

# ALIAS record - create only if createRoute53Record=true
resource "aws_route53_record" "custom_domain" {
  count   = try(var.domain_config.createRoute53Record, true) ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.domain_config.domainName
  type    = "A"

  alias {
    name                   = local.domain_name_target
    zone_id                = local.domain_name_zone_id
    evaluate_target_health = true
  }
}
```

### Domain Name Target Selection Pattern
```hcl
locals {
  # Select appropriate target based on endpoint type
  domain_name_target = try(var.domain_config.endpointType, "EDGE") == "EDGE" ? (
    aws_api_gateway_domain_name.custom_domain.cloudfront_domain_name
  ) : (
    aws_api_gateway_domain_name.custom_domain.regional_domain_name
  )

  domain_name_zone_id = try(var.domain_config.endpointType, "EDGE") == "EDGE" ? (
    aws_api_gateway_domain_name.custom_domain.cloudfront_zone_id
  ) : (
    aws_api_gateway_domain_name.custom_domain.regional_zone_id
  )
}
```

### Root Module Integration Pattern
```hcl
# In /home/tom/p/t/sls.tf/main.tf
module "custom_domain" {
  source = "./modules/custom-domain"

  count = var.enable_custom_domain && try(local.provider_with_defaults.customDomain, null) != null ? 1 : 0

  domain_config        = local.provider_with_defaults.customDomain
  api_gateway_rest_api = module.api_gateway[0].rest_api_id
  api_gateway_stage    = module.api_gateway[0].stage_name
  create_hosted_zone   = var.create_hosted_zone
  acm_certificate_arn  = var.acm_certificate_arn
  aws_region          = local.provider_with_defaults.region
}
```

---

## Code Quality Checklist

**Before marking each task group complete:**
- [ ] Run `terraform fmt -recursive` on all modified files
- [ ] Run `terraform validate` to check syntax
- [ ] Verify no hardcoded values (use variables and locals)
- [ ] Add descriptive comments for complex logic (certificate region extraction, endpoint selection)
- [ ] Use snake_case for all Terraform identifiers
- [ ] Follow existing validation error collection pattern from core module
- [ ] Test with `terraform plan` to verify resources created correctly
- [ ] Verify null handling for optional fields
- [ ] Check that all resources have appropriate dependencies (depends_on or implicit)

---

## Testing Strategy Summary

**Test Distribution Across Task Groups:**
- Task Group 1: 2-4 tests (module structure and loading)
- Task Group 2: 2-4 tests (configuration parsing and defaults)
- Task Group 3: 2-6 tests (validation rules)
- Task Group 4: 2-4 tests (Route 53 resources)
- Task Group 5: 2-6 tests (API Gateway resources)
- Task Group 6: Up to 10 additional tests (integration and gap filling)

**Total Expected Tests:** 20-34 tests maximum

**Test Focus Areas:**
1. Module conditional creation based on enable_custom_domain flag
2. Configuration parsing with default value application
3. Validation error collection and display
4. Certificate region validation for EDGE vs REGIONAL
5. Hosted zone creation vs lookup scenarios
6. ALIAS record conditional creation
7. API Gateway domain name with correct endpoint type
8. Base path mapping with optional basePath
9. End-to-end workflow: EDGE with us-east-1 certificate
10. End-to-end workflow: REGIONAL with regional certificate

**Testing Principles:**
- Write minimal tests during development (2-6 per task group)
- Focus on critical behaviors, not exhaustive coverage
- Run only newly written tests at each stage (not entire suite)
- Integration testing phase adds maximum 10 strategic tests
- Skip edge cases and non-critical scenarios unless business-critical

---

## File Organization Reference

```
sls.tf/
├── main.tf                              # Root module with custom_domain module invocation
├── variables.tf                         # Root variables: enable_custom_domain, create_hosted_zone, acm_certificate_arn
├── outputs.tf                           # Root outputs referencing module.custom_domain outputs
├── locals.tf                            # Existing locals for config parsing
├── modules/
│   └── custom-domain/
│       ├── main.tf                      # API Gateway domain name, base path mapping, locals
│       ├── variables.tf                 # Module inputs: domain_config, api_gateway_rest_api, etc.
│       ├── outputs.tf                   # Module outputs: custom_domain_name, target, zone_id, etc.
│       ├── data.tf                      # Route 53 zone lookup data source
│       ├── route53.tf                   # Route 53 zone creation, ALIAS record resources
│       └── validation.tf                # Validation locals and null_resource enforcement
└── tests/
    ├── custom-domain-edge/              # Test: EDGE endpoint with us-east-1 certificate
    ├── custom-domain-regional/          # Test: REGIONAL endpoint with regional certificate
    ├── custom-domain-existing-zone/     # Test: hostedZoneId provided scenario
    ├── custom-domain-new-zone/          # Test: create_hosted_zone=true scenario
    ├── custom-domain-base-path/         # Test: base path mapping scenario
    └── custom-domain-no-record/         # Test: createRoute53Record=false scenario
```

---

## Key Dependencies & Prerequisites

**External Dependencies:**
- Roadmap #4 (API Gateway REST API Integration) must be implemented
  - Requires `api_gateway_rest_api` output (REST API ID)
  - Requires `api_gateway_stage` output (stage name)
- ACM certificate must be pre-provisioned in correct region
  - EDGE endpoints: certificate in us-east-1
  - REGIONAL endpoints: certificate in same region as API
- Route 53 hosted zone (either existing or permission to create)

**Terraform Requirements:**
- Terraform >= 1.13.4 (from existing `versions.tf`)
- AWS provider >= 6.0 (from existing `versions.tf`)
- Null provider >= 3.0 (for validation resources)

**Configuration Requirements:**
- serverless.yml with `provider.customDomain` block (optional)
- At minimum: `domainName` field required in customDomain
- Certificate ARN from either customDomain.certificateArn or acm_certificate_arn variable

---

## Success Metrics

**Implementation Complete When:**
- All 6 task groups completed with acceptance criteria met
- Module structure created under `modules/custom-domain/`
- All Terraform files formatted and validated
- Configuration parsing handles all customDomain fields with defaults
- All validation rules implemented and tested
- Route 53 resources created conditionally based on configuration
- API Gateway domain name and base path mapping created
- All module outputs implemented and tested
- Approximately 20-34 feature-specific tests pass
- Integration with API Gateway (roadmap #4) verified
- Domain resolution tested end-to-end for both EDGE and REGIONAL

**Feature Functionality Verified:**
- Custom domain attached to API Gateway endpoint
- DNS record resolves to correct target (CloudFront or regional)
- Certificate region matches endpoint type requirements
- Base path mapping routes requests to correct API stage
- Validation errors clear and actionable
- Conditional resource creation works as expected
- Outputs provide correct values for manual DNS setup scenarios

---

**This task breakdown is ready for implementation.** Follow the sequential order through task groups 1-6, completing all sub-tasks and acceptance criteria before moving to the next group. Reference the spec at `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-route53-custom-domain/spec.md` for detailed requirements and the requirements document for Q&A context.
