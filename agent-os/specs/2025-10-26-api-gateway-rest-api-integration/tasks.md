# Task Breakdown: API Gateway REST API Integration

## Overview

**Spec:** API Gateway REST API Integration (Spec #4)
**Total Tasks:** 22 tasks organized into 5 major phases
**Estimated Complexity:** High - Involves complex path parsing, nested resource hierarchies, CORS handling, and deployment triggers

## Task List

### Phase 1: HTTP Event Parsing and Validation

**Dependencies:** Core Module Structure (Spec 1), Lambda Functions (Spec 2)

- [ ] 1.0 Complete HTTP event extraction and parsing logic
  - [ ] 1.1 Write 2-8 focused tests for HTTP event parsing
    - Test short-form syntax parsing: `http: GET /users/{id}`
    - Test long-form syntax parsing: `http: { path: /users, method: POST }`
    - Test CORS detection (boolean and object)
    - Test parameter extraction from both formats
    - Skip exhaustive edge case testing
    - File: `/home/tom/p/t/sls.tf/tests/http_event_parsing.tftest.hcl`
  - [ ] 1.2 Create `local.http_events` in locals.tf
    - Extract HTTP events from `local.functions_with_defaults`
    - Parse short-form syntax: extract method and path from string
    - Parse long-form syntax: extract path, method, cors properties
    - Build event objects with: function_name, function_arn, http_method, http_path, cors_enabled, cors_config
    - Use `flatten()` to create flat list from nested function events
    - Reference: Spec section 4.1
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 1.3 Create `local.functions_with_http_events` in locals.tf
    - Deduplicate function names from http_events
    - Use `toset()` for unique function list
    - Required for Lambda permission generation
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 1.4 Create `local.http_event_validation_errors` in locals.tf
    - Validate HTTP method against allowed list: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
    - Validate path starts with `/`
    - Validate no empty segments (consecutive slashes)
    - Validate path parameter syntax: `{paramName}` with alphanumeric/underscore only
    - Validate CORS config structure if object
    - Use `flatten()` and `concat()` for error collection
    - Reference: Spec section 4.1 validation
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 1.5 Add HTTP validation to main validation_errors collection
    - Update `local.validation_errors` to concat `local.http_event_validation_errors`
    - Follow existing error collection pattern from Spec 1
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 1.6 Run HTTP event parsing tests
    - Execute ONLY the 2-8 tests from task 1.1
    - Verify parsing logic works for both syntax forms
    - Verify validation catches invalid configurations
    - Do NOT run entire test suite

**Acceptance Criteria:**
- The 2-8 tests from task 1.1 pass
- Short-form syntax correctly parsed
- Long-form syntax correctly parsed
- Invalid HTTP methods rejected with clear errors
- Invalid path syntax rejected with clear errors
- CORS configuration correctly extracted

---

### Phase 2: Path Parsing and Resource Tree Building

**Dependencies:** Phase 1 (HTTP event parsing)

- [ ] 2.0 Complete path parsing and resource hierarchy generation
  - [ ] 2.1 Write 2-8 focused tests for path parsing
    - Test simple path parsing: `/users`
    - Test nested path parsing: `/users/{id}/posts/{postId}`
    - Test resource tree structure with parent relationships
    - Test path segment extraction
    - Test resource deduplication for shared paths
    - Skip exhaustive edge case testing
    - File: `/home/tom/p/t/sls.tf/tests/path_parsing.tftest.hcl`
  - [ ] 2.2 Create `local.all_paths` in locals.tf
    - Extract unique paths from `local.http_events`
    - Use `toset()` to deduplicate paths
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 2.3 Create `local.path_segments` in locals.tf
    - Parse each path into array of segments
    - Use `split("/", trimprefix(path, "/"))` to segment paths
    - Filter out empty segments
    - Store as map: `path => [segments]`
    - Example: `/users/{id}/posts` => `["users", "{id}", "posts"]`
    - Reference: Spec section 4.2
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 2.4 Create `local.all_resource_paths` in locals.tf
    - Build complete set of intermediate paths
    - Use `flatten()` and `range()` to generate all prefix paths
    - Example: `/users/{id}/posts` generates `/users`, `/users/{id}`, `/users/{id}/posts`
    - Use `toset()` to deduplicate shared intermediate paths
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 2.5 Create `local.resource_tree` in locals.tf
    - Map each resource path to metadata object
    - Include: segments, depth, path_part, parent_path, resource_name
    - Calculate parent_path for nested resources
    - Sanitize resource_name for Terraform identifiers (replace `/`, `{`, `}`)
    - Reference: Spec section 4.2
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 2.6 Run path parsing tests
    - Execute ONLY the 2-8 tests from task 2.1
    - Verify path segmentation works correctly
    - Verify resource tree structure is correct
    - Verify parent-child relationships are accurate

**Acceptance Criteria:**
- The 2-8 tests from task 2.1 pass
- Paths correctly split into segments
- Resource tree includes all intermediate paths
- Parent relationships correctly established
- Shared paths properly deduplicated

---

### Phase 3: CORS Configuration Builder

**Dependencies:** Phase 2 (Path parsing)

- [ ] 3.0 Complete CORS configuration logic
  - [ ] 3.1 Write 2-8 focused tests for CORS handling
    - Test CORS defaults when `cors: true`
    - Test custom CORS configuration (origin, headers)
    - Test CORS disabled when `cors: false` or absent
    - Test CORS on multiple methods on same resource
    - Skip edge cases and conflicting configurations
    - File: `/home/tom/p/t/sls.tf/tests/cors_configuration.tftest.hcl`
  - [ ] 3.2 Create `local.cors_defaults` in locals.tf
    - Define Serverless Framework default CORS values
    - origin: `'*'`
    - headers: `["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token", "X-Amz-User-Agent"]`
    - allowCredentials: `false`
    - Reference: Spec section 4.3
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 3.3 Create `local.resource_cors_config` in locals.tf
    - Build CORS configuration per resource path
    - Detect if any event on resource has CORS enabled
    - Merge custom CORS configs with defaults
    - Collect methods for Access-Control-Allow-Methods header
    - Store as map: `path => { enabled, custom_config, methods }`
    - Reference: Spec section 4.3
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 3.4 Create `local.cors_headers` in locals.tf
    - Format CORS headers for integration response
    - Quote values appropriately: `"'*'"` for origin
    - Join header arrays with commas
    - Include OPTIONS in methods list
    - Filter to only CORS-enabled resources
    - File: `/home/tom/p/t/sls.tf/locals.tf`
  - [ ] 3.5 Run CORS configuration tests
    - Execute ONLY the 2-8 tests from task 3.1
    - Verify default CORS values applied correctly
    - Verify custom CORS configuration works
    - Verify multiple methods aggregated correctly

**Acceptance Criteria:**
- The 2-8 tests from task 3.1 pass
- Default CORS values match Serverless Framework
- Custom CORS configurations properly merged
- CORS headers correctly formatted for API Gateway
- Methods list includes all methods on resource

---

### Phase 4: API Gateway Resource Generation

**Dependencies:** Phases 1-3 (Parsing, Path Tree, CORS)

- [ ] 4.0 Complete API Gateway resource creation
  - [ ] 4.1 Write 2-8 focused tests for API Gateway resources
    - Test REST API creation with correct name
    - Test resource hierarchy creation
    - Test method and integration creation
    - Test OPTIONS method for CORS
    - Test Lambda permission creation
    - Skip deployment and stage testing (covered in Phase 5)
    - File: `/home/tom/p/t/sls.tf/tests/api_gateway_resources.tftest.hcl`
  - [ ] 4.2 Create `aws_api_gateway_rest_api` resource in main.tf
    - Create singleton resource with `count` conditional
    - Only create if `length(local.http_events) > 0`
    - Name: `${service}-${stage}`
    - Description: `"API Gateway for ${service}"`
    - Endpoint type: EDGE
    - Reference: Spec section 4.4
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 4.3 Create `aws_api_gateway_resource.paths` in main.tf
    - Use `for_each` over `local.resource_tree`
    - Conditional creation when http_events exist
    - Set parent_id from root or parent resource
    - Use `path_part` from resource_tree
    - Reference: Spec section 4.4
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 4.4 Create `aws_api_gateway_method.endpoints` in main.tf
    - Use `for_each` over http_events
    - Map key: `${function_name}_${lower(http_method)}`
    - Set http_method from event
    - Authorization: "NONE"
    - Resource ID from aws_api_gateway_resource.paths
    - Reference: Spec section 4.4
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 4.5 Create `aws_api_gateway_integration.lambda` in main.tf
    - Use `for_each` over http_events (same as methods)
    - Type: "AWS_PROXY"
    - integration_http_method: "POST"
    - URI: Lambda invoke ARN pattern
    - Construct URI: `arn:aws:apigateway:${region}:lambda:path/2015-03-31/functions/${function_arn}/invocations`
    - Reference: Spec section 4.4
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 4.6 Create CORS OPTIONS method resources in main.tf
    - Create `aws_api_gateway_method.cors_options`
    - Create `aws_api_gateway_integration.cors_options` with MOCK type
    - Create `aws_api_gateway_method_response.cors_options_200`
    - Create `aws_api_gateway_integration_response.cors_options_200`
    - Filter to only CORS-enabled resources from `local.resource_cors_config`
    - Set response headers: Access-Control-Allow-Headers, -Methods, -Origin
    - Use values from `local.cors_headers`
    - Reference: Spec section 4.4
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 4.7 Create `aws_lambda_permission.api_gateway` in main.tf
    - Use `for_each` over `local.functions_with_http_events`
    - Statement ID: `AllowAPIGatewayInvoke-${function_name}`
    - Action: `lambda:InvokeFunction`
    - Principal: `apigateway.amazonaws.com`
    - Source ARN: `${api_execution_arn}/*/*` (wildcard for stage/method)
    - Reference: Spec section 4.4
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 4.8 Run API Gateway resource tests
    - Execute ONLY the 2-8 tests from task 4.1
    - Verify REST API created with correct name
    - Verify resource hierarchy matches paths
    - Verify methods and integrations created
    - Verify CORS OPTIONS methods created when enabled
    - Verify Lambda permissions created

**Acceptance Criteria:**
- The 2-8 tests from task 4.1 pass
- REST API created only when HTTP events exist
- Resource hierarchy correctly nested
- Methods reference correct resources
- Lambda proxy integrations configured correctly
- CORS OPTIONS methods created for CORS-enabled paths
- Lambda permissions grant API Gateway invoke access

---

### Phase 5: Deployment, Stage, and Outputs

**Dependencies:** Phase 4 (API Gateway resources)

- [ ] 5.0 Complete deployment, stage, and output configuration
  - [ ] 5.1 Write 2-8 focused tests for deployment and outputs
    - Test deployment creation with triggers
    - Test stage creation with correct stage name
    - Test deployment redeployment on configuration change
    - Test output values (invoke URL, REST API ID)
    - Skip complex trigger scenarios
    - File: `/home/tom/p/t/sls.tf/tests/api_gateway_deployment.tftest.hcl`
  - [ ] 5.2 Create `aws_api_gateway_deployment.this` in main.tf
    - Create singleton with `count` conditional
    - Use triggers with sha1 hash of method/integration IDs
    - Include all endpoints methods and lambda integrations
    - Include all CORS methods and integrations
    - Use `lifecycle { create_before_destroy = true }`
    - Add explicit `depends_on` for all methods/integrations
    - Reference: Spec section 4.4
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 5.3 Create `aws_api_gateway_stage.this` in main.tf
    - Create singleton with `count` conditional
    - Set stage_name from `local.provider_with_defaults.stage`
    - Reference deployment_id from aws_api_gateway_deployment
    - File: `/home/tom/p/t/sls.tf/main.tf`
  - [ ] 5.4 Add API Gateway outputs in outputs.tf
    - `api_gateway_rest_api_id`: REST API ID or null
    - `api_gateway_invoke_url`: Stage invoke URL or null
    - `api_gateway_stage_name`: Stage name or null
    - `api_gateway_resources`: Map of path to resource ID
    - Use conditional expressions based on http_events existence
    - Reference: Spec section 4.5
    - File: `/home/tom/p/t/sls.tf/outputs.tf`
  - [ ] 5.5 Run deployment and output tests
    - Execute ONLY the 2-8 tests from task 5.1
    - Verify deployment created
    - Verify stage created with correct name
    - Verify invoke URL output is valid
    - Verify redeployment triggered on changes

**Acceptance Criteria:**
- The 2-8 tests from task 5.1 pass
- Deployment includes all methods and integrations in triggers
- Stage name matches provider.stage configuration
- Invoke URL output is correctly formatted
- Deployment recreates when API configuration changes
- Outputs return null when no HTTP events exist

---

### Phase 6: Integration Testing and Gap Analysis

**Dependencies:** Phases 1-5 (All implementation complete)

- [ ] 6.0 Review tests and fill critical gaps
  - [ ] 6.1 Review all tests from Phases 1-5
    - Review HTTP event parsing tests (2-8 tests from Phase 1)
    - Review path parsing tests (2-8 tests from Phase 2)
    - Review CORS configuration tests (2-8 tests from Phase 3)
    - Review API Gateway resource tests (2-8 tests from Phase 4)
    - Review deployment/output tests (2-8 tests from Phase 5)
    - Total existing: approximately 10-40 tests
  - [ ] 6.2 Analyze test coverage gaps for API Gateway feature
    - Identify critical end-to-end workflows lacking coverage
    - Focus on integration between parsing, resources, and deployment
    - Look for gaps in multi-function scenarios
    - Prioritize real-world usage patterns
    - Do NOT assess application-wide test coverage
  - [ ] 6.3 Write up to 10 additional integration tests maximum
    - Test complete flow: YAML config -> deployed API Gateway
    - Test multiple functions sharing one API
    - Test resource reuse across different methods
    - Test no HTTP events (resources not created)
    - Test mixed CORS configurations
    - Test path parameter propagation to Lambda
    - Focus on integration points between components
    - Skip redundant coverage of already-tested units
    - File: `/home/tom/p/t/sls.tf/tests/api_gateway_integration.tftest.hcl`
  - [ ] 6.4 Run all API Gateway feature tests
    - Run all tests from Phases 1-6
    - Expected total: approximately 20-50 tests maximum
    - Verify end-to-end workflows function correctly
    - Do NOT run unrelated tests from other specs

**Acceptance Criteria:**
- All API Gateway feature tests pass (20-50 tests total)
- Critical end-to-end workflows have test coverage
- Multi-function API scenarios validated
- Edge cases for this feature addressed (root path, no events, etc.)
- No more than 10 additional tests added in gap analysis

---

### Phase 7: Test Fixtures and Documentation

**Dependencies:** Phase 6 (Testing complete)

- [ ] 7.0 Create test fixtures and update documentation
  - [ ] 7.1 Create test fixture files in tests/fixtures/
    - `http-short-form.yml`: Short-form HTTP event syntax
    - `http-long-form.yml`: Long-form HTTP event syntax
    - `http-path-params.yml`: Path with parameters
    - `http-cors-default.yml`: CORS with default configuration
    - `http-cors-custom.yml`: CORS with custom configuration
    - `http-invalid-method.yml`: Invalid HTTP method (validation test)
    - `http-invalid-path.yml`: Invalid path syntax (validation test)
    - `http-shared-paths.yml`: Multiple methods on shared paths
    - `http-multiple-functions.yml`: Multiple functions with HTTP events
    - `http-full-example.yml`: Comprehensive example for integration tests
    - Reference: Spec section 7.3 for fixture examples
    - Directory: `/home/tom/p/t/sls.tf/tests/fixtures/`
  - [ ] 7.2 Update README.md with API Gateway examples
    - Add HTTP event configuration examples
    - Document short-form and long-form syntax
    - Show CORS configuration options
    - Document output variables (invoke URL, API ID)
    - Include complete working example
    - File: `/home/tom/p/t/sls.tf/README.md`
  - [ ] 7.3 Update CHANGELOG or create release notes
    - Document new API Gateway REST API support
    - List supported features (HTTP events, CORS, path parameters)
    - Note out-of-scope items (authorizers, API keys, etc.)
    - Include migration notes if applicable
    - File: `/home/tom/p/t/sls.tf/CHANGELOG.md` or similar

**Acceptance Criteria:**
- All test fixtures created and valid YAML
- README includes clear API Gateway usage examples
- Documentation covers both syntax forms
- CORS configuration options documented
- Release notes capture feature scope

---

## Execution Order

Recommended implementation sequence:

1. **Phase 1: HTTP Event Parsing and Validation** (Tasks 1.1-1.6)
   - Foundation for all subsequent work
   - Enables validation early in pipeline

2. **Phase 2: Path Parsing and Resource Tree Building** (Tasks 2.1-2.6)
   - Depends on HTTP events from Phase 1
   - Required for resource generation

3. **Phase 3: CORS Configuration Builder** (Tasks 3.1-3.5)
   - Depends on path parsing from Phase 2
   - Required for OPTIONS methods

4. **Phase 4: API Gateway Resource Generation** (Tasks 4.1-4.8)
   - Depends on all parsing and configuration logic
   - Creates actual AWS resources

5. **Phase 5: Deployment, Stage, and Outputs** (Tasks 5.1-5.5)
   - Depends on API Gateway resources
   - Completes the API Gateway setup

6. **Phase 6: Integration Testing and Gap Analysis** (Tasks 6.1-6.4)
   - Verifies all phases work together
   - Fills critical test gaps only

7. **Phase 7: Test Fixtures and Documentation** (Tasks 7.1-7.3)
   - Can be done in parallel with testing
   - Required for usability

---

## Important Notes

### Test-Driven Development Approach

Each phase (1-5) follows this pattern:
1. **Write 2-8 focused tests** covering critical behaviors only
2. **Implement the functionality** to make those tests pass
3. **Run ONLY the phase-specific tests**, not the entire suite
4. **Move to next phase** once phase tests pass

Phase 6 (Integration Testing) is the ONLY phase that writes additional tests, and only up to 10 tests maximum to fill critical gaps.

### File Organization

- **Locals**: All parsing logic in `/home/tom/p/t/sls.tf/locals.tf`
- **Resources**: All API Gateway resources in `/home/tom/p/t/sls.tf/main.tf`
- **Outputs**: All outputs in `/home/tom/p/t/sls.tf/outputs.tf`
- **Tests**: All test files in `/home/tom/p/t/sls.tf/tests/`
- **Fixtures**: All test fixtures in `/home/tom/p/t/sls.tf/tests/fixtures/`

### Integration with Existing Code

- Builds on `local.parsed_config` from Spec 1
- Builds on `local.functions_with_defaults` from Spec 1
- Builds on `local.provider_with_defaults` from Spec 1
- Uses `local.validation_errors` pattern from Spec 1
- References Lambda functions from Spec 2 (if implemented)
- Follows validation pattern from existing codebase

### Validation Strategy

- Add `local.http_event_validation_errors` to existing `local.validation_errors`
- Follow error message format: `"Function 'X' has invalid Y. Details."`
- Collect all errors before failing (fail fast but report all issues)
- Use preconditions in `null_resource.config_validation`

### Terraform Best Practices

- Use `count` for singleton resources (REST API, deployment, stage)
- Use `for_each` for multiple resources (resources, methods, integrations)
- Use `depends_on` explicitly for deployment
- Use `create_before_destroy` lifecycle for deployment
- Use stable resource keys for Terraform state consistency

### Success Metrics

The implementation is successful when:
- All ~20-50 feature-specific tests pass
- Short-form and long-form HTTP events both work
- Path parameters create correct nested resources
- CORS generates OPTIONS methods with correct headers
- Deployment triggers work on configuration changes
- Lambda permissions grant API Gateway access
- Invoke URL output is functional
- Validation catches invalid configurations with clear errors
