# Task Breakdown: LocalStack Integration for Testing

## Overview

**Goal**: Enable fast, cost-free local testing using LocalStack Community Edition as a drop-in replacement for AWS during test execution.

**Total Task Groups**: 8
**Estimated Timeline**: 3-4 weeks
**Success Criteria**: 80%+ tests work with LocalStack, <2 minute feedback loop, $0 dev costs

## Key Metrics
- **Test execution time reduction**: 80%+ (from ~300s to ~60s)
- **LocalStack startup time**: <30 seconds
- **Test coverage**: 80%+ of tests LocalStack-compatible
- **CI/CD**: 100% of PRs run LocalStack tests automatically

---

## Task List

### Task Group 1: Infrastructure & Lifecycle Management

**Dependencies**: None
**Estimated Effort**: 4-6 hours
**Assignee**: DevOps/Infrastructure Engineer

**Objective**: Set up LocalStack container infrastructure with Make-based lifecycle management for easy local development.

- [ ] 1.0 Complete LocalStack infrastructure setup
  - [ ] 1.1 Create Docker Compose configuration
    - File: `/home/tom/p/t/sls.tf/docker-compose.localstack.yml`
    - Container name: `sls-tf-localstack`
    - Image: `localstack/localstack:latest`
    - Expose port 4566 for LocalStack gateway
    - Configure services: `lambda,apigateway,s3,iam,dynamodb,sqs,events,route53`
    - Set environment variables:
      - `LAMBDA_EXECUTOR=docker-reuse` (faster Lambda execution)
      - `PERSISTENCE=0` (clean state each run)
      - `EAGER_SERVICE_LOADING=1` (predictable startup)
      - `DEBUG=0` (reduce noise)
    - Mount Docker socket: `/var/run/docker.sock:/var/run/docker.sock`
    - Mount init scripts: `.localstack:/etc/localstack/init/ready.d`
    - Use bridge network: `localstack-network`
  - [ ] 1.2 Create Makefile with LocalStack lifecycle targets
    - File: `/home/tom/p/t/sls.tf/Makefile`
    - Implement targets:
      - `localstack-start`: Start container with health check
      - `localstack-stop`: Stop container gracefully
      - `localstack-restart`: Restart container
      - `localstack-status`: Show container status via `docker-compose ps`
      - `localstack-logs`: Tail container logs with `-f` flag
      - `localstack-health`: Check `/_localstack/health` endpoint
      - `localstack-clean`: Stop container and remove volumes
      - `test-local`: Run tests with LocalStack
      - `test-aws`: Run tests against real AWS
      - `test-all`: Default to LocalStack tests
      - `help`: Display usage information
    - Health check implementation:
      - Use `curl http://localhost:4566/_localstack/health`
      - Check for `"s3": "available"` in response
      - 60-second timeout with 2-second retry interval
      - Exit with error message if health check fails
  - [ ] 1.3 Create LocalStack configuration directory
    - Directory: `/home/tom/p/t/sls.tf/.localstack/`
    - Create `.localstack/config.yml` (optional, for future customization)
    - Create `.localstack/init-scripts/` directory (for future init scripts)
    - Add `.localstack/data/` to `.gitignore` (runtime state)
  - [ ] 1.4 Update .gitignore
    - Add `.localstack/data/` to ignore runtime state
    - Verify `.terraform/` already ignored (for Lambda zip files)
  - [ ] 1.5 Verify LocalStack infrastructure
    - Run `make localstack-start`
    - Verify container starts successfully
    - Verify health check passes within 60 seconds
    - Check all services available via `curl http://localhost:4566/_localstack/health`
    - Run `make localstack-logs` to verify clean startup
    - Run `make localstack-stop` to verify clean shutdown
    - Run `make localstack-clean` to verify volume cleanup

**Acceptance Criteria**:
- `make localstack-start` successfully starts LocalStack within 30 seconds
- Health check endpoint returns all services as "available"
- `make localstack-logs` displays container logs without errors
- `make localstack-clean` removes all LocalStack data
- Docker Compose configuration follows best practices (networks, health checks)

**Implementation Notes**:
- LocalStack Community Edition uses single endpoint (port 4566) for all services
- Health check is critical for CI/CD reliability
- Volume cleanup prevents state leakage between test runs
- Follow spec's Docker Compose configuration exactly (section "1. Docker Compose Configuration")

---

### Task Group 2: Provider Configuration Framework

**Dependencies**: Task Group 1
**Estimated Effort**: 6-8 hours
**Assignee**: Terraform/Infrastructure Engineer

**Objective**: Implement dynamic provider configuration that switches between LocalStack and AWS based on variables.

- [ ] 2.0 Complete provider configuration framework
  - [ ] 2.1 Add LocalStack variables to module
    - File: `/home/tom/p/t/sls.tf/variables.tf`
    - Add `use_localstack` variable:
      - Type: `bool`
      - Default: `false`
      - Description: "Enable LocalStack mode for testing. When true, all AWS provider endpoints will point to LocalStack."
    - Add `localstack_endpoint` variable:
      - Type: `string`
      - Default: `"http://localhost:4566"`
      - Description: "LocalStack endpoint URL. Only used when use_localstack is true."
      - Validation: Must match regex `^https?://` (valid HTTP/HTTPS URL)
    - Follow existing variable patterns in `/home/tom/p/t/sls.tf/variables.tf`
  - [ ] 2.2 Document provider configuration pattern
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-provider-config.md`
    - Document that this module does NOT declare the AWS provider
    - Explain that tests must configure provider with endpoint overrides
    - Provide example provider configuration block for tests
    - Document required provider settings:
      - `skip_credentials_validation = var.use_localstack`
      - `skip_metadata_api_check = var.use_localstack`
      - `skip_requesting_account_id = var.use_localstack`
      - `s3_use_path_style = var.use_localstack` (required for S3)
    - Document dynamic endpoints block pattern using `for_each`
    - List all service endpoints that should be overridden
  - [ ] 2.3 Create test provider configuration template
    - File: Create `/home/tom/p/t/sls.tf/tests/test_provider_template.txt`
    - Provide reusable provider configuration block
    - Include all AWS services used by module:
      - `apigateway`, `dynamodb`, `events`, `iam`, `lambda`, `route53`, `s3`, `sqs`, `sts`
    - Use dynamic block pattern: `dynamic "endpoints" { for_each = var.use_localstack ? [1] : [] }`
    - Include example usage in file header comments
    - Reference spec section "3. Provider Configuration with Endpoint Overrides"
  - [ ] 2.4 Create endpoint configuration helper locals (optional)
    - File: Consider adding to `/home/tom/p/t/sls.tf/locals.tf`
    - Create local value for LocalStack endpoint validation
    - Create helper for endpoint availability checking
    - Skip if keeping implementation simple (tests configure provider directly)
  - [ ] 2.5 Verify provider configuration switching
    - Create temporary test file with provider configuration
    - Test with `use_localstack = true`:
      - Verify endpoints point to LocalStack
      - Verify AWS credential validation skipped
      - Verify S3 path-style access enabled
    - Test with `use_localstack = false`:
      - Verify endpoints use default AWS
      - Verify AWS credentials required
    - Run `terraform init` and `terraform plan` with both modes
    - Verify no provider configuration errors
    - Delete temporary test file after verification

**Acceptance Criteria**:
- Variables added to `/home/tom/p/t/sls.tf/variables.tf` with proper validation
- Provider configuration documentation clearly explains test setup pattern
- Template provider configuration works with both LocalStack and AWS
- Provider switching verified via manual testing
- No breaking changes to existing module functionality

**Implementation Notes**:
- Module follows pattern where provider is NOT declared in module itself
- Tests must provide provider configuration (Terraform module best practice)
- Dynamic endpoints block only populated when `use_localstack = true`
- S3 path-style access critical for LocalStack compatibility
- Reference existing variables in `/home/tom/p/t/sls.tf/variables.tf` for style

---

### Task Group 3: Test Framework Enhancement

**Dependencies**: Task Group 2
**Estimated Effort**: 6-8 hours
**Assignee**: Test Engineer

**Objective**: Create shared test utilities and establish dual-mode testing patterns.

- [ ] 3.0 Complete test framework enhancements
  - [ ] 3.1 Create shared test configuration helper
    - File: Create `/home/tom/p/t/sls.tf/tests/shared_test_config.tftest.hcl`
    - Provide reusable provider configuration block
    - Include all required AWS services (lambda, apigateway, s3, iam, dynamodb, sqs, events, route53, sts)
    - Set LocalStack-friendly provider flags
    - Document usage in file header comments
    - Mark as "LocalStack Compatibility: TEMPLATE"
  - [ ] 3.2 Create LocalStack compatibility metadata standard
    - Document in `/home/tom/p/t/sls.tf/docs/localstack-testing.md`
    - Define three compatibility levels:
      - `FULL`: All tests work with LocalStack Community Edition
      - `PARTIAL`: Some tests require real AWS (marked with skip conditions)
      - `NONE`: Test file requires real AWS (Pro features, advanced IAM, etc.)
    - Standardize file header format:
      ```hcl
      # <Test File Name>
      # LocalStack Compatibility: <FULL|PARTIAL|NONE>
      # <Description>
      ```
    - Provide examples for each compatibility level
  - [ ] 3.3 Create test skip pattern for LocalStack limitations
    - Document skip pattern using `condition` attribute
    - Example: `condition = !var.use_localstack` for AWS-only tests
    - Document in `/home/tom/p/t/sls.tf/docs/localstack-testing.md`
    - Provide examples for common scenarios:
      - IAM permission boundary tests (AWS-only)
      - Complex EventBridge patterns (AWS-only)
      - Route53 advanced routing (AWS-only)
  - [ ] 3.4 Create graceful degradation pattern
    - Document conditional assertions for LocalStack behavior differences
    - Example: `var.use_localstack || <strict_aws_check>`
    - Provide examples for:
      - IAM validation differences
      - API Gateway invoke URL format differences
      - ARN format variations
    - Document in `/home/tom/p/t/sls.tf/docs/localstack-testing.md`
  - [ ] 3.5 Create test writing checklist
    - File: Append to `/home/tom/p/t/sls.tf/docs/localstack-testing.md`
    - Include checklist from spec Appendix C
    - Customize for this project's specific patterns
    - Reference existing test files as examples
  - [ ] 3.6 Verify test framework utilities
    - Use shared test config in a sample test
    - Test skip pattern with LocalStack running
    - Test skip pattern with LocalStack stopped
    - Verify compatibility metadata is clear
    - Verify documentation is comprehensive

**Acceptance Criteria**:
- Shared test configuration template is reusable and well-documented
- Compatibility metadata standard is clear and actionable
- Skip patterns work correctly in both LocalStack and AWS modes
- Graceful degradation patterns documented with examples
- Test writing checklist is comprehensive
- Documentation enables developers to write dual-mode tests independently

**Implementation Notes**:
- Follow existing test patterns in `/home/tom/p/t/sls.tf/tests/*.tftest.hcl`
- Tests use simple `run` blocks with `command = plan` (no complex setup needed)
- Existing tests use `variables { config_path = "..." }` pattern
- Reference spec sections "4. Test File Structure" and "5. Handling LocalStack Limitations"

---

### Task Group 4: Test Migration - Phase 1 (Core Parsing Tests)

**Dependencies**: Task Group 3
**Estimated Effort**: 8-10 hours
**Assignee**: Test Engineer

**Objective**: Convert core parsing and validation tests to dual-mode (LocalStack/AWS compatible).

- [ ] 4.0 Convert core parsing tests to dual-mode
  - [ ] 4.1 Convert HTTP event parsing tests
    - File: `/home/tom/p/t/sls.tf/tests/http_event_parsing.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block at top of file (use template from 3.1)
    - Add variables section with `use_localstack = true` default
    - Verify all 6 test runs work with LocalStack:
      - `short_form_http_event`
      - `long_form_http_event`
      - `invalid_http_method`
      - `invalid_http_path`
      - `functions_with_http_events_deduplication`
    - These are parsing tests (no resources created), should work identically
    - Run tests with `terraform test -var="use_localstack=true"`
    - Run tests with `terraform test -var="use_localstack=false"` (if AWS available)
  - [ ] 4.2 Convert S3 event parsing tests
    - File: `/home/tom/p/t/sls.tf/tests/s3_event_parsing.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Verify all 6 test runs work with LocalStack:
      - `test_s3_shorthand_syntax_parsing`
      - `test_s3_object_syntax_parsing`
      - `test_s3_mixed_syntax_in_same_file`
      - `test_s3_default_event_type_applied`
      - `test_s3_custom_event_type_preserved`
      - `test_functions_without_s3_events_graceful_skip`
    - These are parsing tests (no resources created), should work identically
    - Test both LocalStack and AWS modes
  - [ ] 4.3 Convert path parsing tests
    - File: `/home/tom/p/t/sls.tf/tests/path_parsing.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Verify all test runs work with LocalStack
    - These parse API Gateway paths, no resource creation
  - [ ] 4.4 Convert event source parsing tests
    - File: `/home/tom/p/t/sls.tf/tests/event_source_parsing.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - These parse event sources, minimal resource interaction
  - [ ] 4.5 Convert validation tests
    - File: `/home/tom/p/t/sls.tf/tests/s3_validation.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: PARTIAL`
    - Add provider configuration block
    - Add variables section
    - Review assertions for LocalStack compatibility
    - Add skip conditions for AWS-specific validation if needed
    - Document any LocalStack validation differences
  - [ ] 4.6 Run and verify Phase 1 tests
    - Start LocalStack: `make localstack-start`
    - Run all Phase 1 tests: `terraform test -filter="http_event_parsing|s3_event_parsing|path_parsing|event_source_parsing|s3_validation" -var="use_localstack=true"`
    - Verify all tests pass with LocalStack
    - Document any failures or compatibility issues
    - Create GitHub issue for any LocalStack bugs discovered

**Acceptance Criteria**:
- All 5 test files converted to dual-mode format
- All tests pass with LocalStack (`use_localstack=true`)
- Tests maintain compatibility with AWS (`use_localstack=false`)
- Compatibility headers accurately reflect LocalStack support level
- No test failures due to provider configuration issues

**Implementation Notes**:
- Parsing tests should work identically in LocalStack (no resources created)
- Tests use `command = plan` (no actual resource creation)
- These tests validate locals and parsing logic, not AWS API behavior
- Minimal risk of LocalStack compatibility issues
- Focus on provider configuration correctness

---

### Task Group 5: Test Migration - Phase 2 (Resource Creation Tests)

**Dependencies**: Task Group 4
**Estimated Effort**: 10-12 hours
**Assignee**: Test Engineer

**Objective**: Convert tests that create AWS resources to dual-mode, handling LocalStack-specific behaviors.

- [ ] 5.0 Convert resource creation tests to dual-mode
  - [ ] 5.1 Convert API Gateway resource tests
    - File: `/home/tom/p/t/sls.tf/tests/api_gateway_resources.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Review assertions for LocalStack compatibility:
      - API Gateway REST API creation
      - Resource and method creation
      - Path parameter handling
    - Handle invoke URL format differences:
      - LocalStack: `http://localhost:4566/restapis/{id}/{stage}/_user_request/{path}`
      - AWS: `https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/{path}`
    - Use conditional assertions if URL format validation present
    - Test with LocalStack to verify resource creation
  - [ ] 5.2 Convert API Gateway integration tests
    - File: `/home/tom/p/t/sls.tf/tests/api_gateway_integration.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Verify Lambda integration setup works in LocalStack
    - Test integration type, credentials, and request templates
  - [ ] 5.3 Convert API Gateway deployment tests
    - File: `/home/tom/p/t/sls.tf/tests/api_gateway_deployment.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Test stage creation and deployment
  - [ ] 5.4 Convert CORS configuration tests
    - File: `/home/tom/p/t/sls.tf/tests/cors_configuration.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Verify CORS headers in method responses
    - LocalStack should support CORS configuration fully
  - [ ] 5.5 Convert S3 bucket management tests
    - File: `/home/tom/p/t/sls.tf/tests/s3_bucket_management.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Verify S3 bucket creation, notification configuration
    - Ensure S3 path-style access working (`s3_use_path_style = true`)
    - Test bucket naming (LocalStack may have different constraints)
  - [ ] 5.6 Handle LocalStack-specific behaviors
    - Document invoke URL format differences in test comments
    - Add conditional assertions for URL validation if needed:
      ```hcl
      assert {
        condition = var.use_localstack || can(regex("execute-api", output.invoke_url))
        error_message = "AWS invoke URL should contain execute-api (skipped in LocalStack)"
      }
      ```
    - Document IAM role ARN format differences if encountered
  - [ ] 5.7 Run and verify Phase 2 tests
    - Start LocalStack: `make localstack-start`
    - Run all Phase 2 tests: `terraform test -filter="api_gateway|cors|s3_bucket" -var="use_localstack=true"`
    - Verify all tests pass with LocalStack
    - Check LocalStack logs for any errors: `make localstack-logs`
    - Document any compatibility issues or workarounds

**Acceptance Criteria**:
- All 5 test files converted to dual-mode format
- API Gateway tests successfully create resources in LocalStack
- S3 tests successfully create buckets and notifications in LocalStack
- CORS configuration works in LocalStack
- LocalStack-specific behaviors documented in test comments
- All tests pass with LocalStack mode
- Tests maintain AWS compatibility

**Implementation Notes**:
- API Gateway invoke URLs have different format in LocalStack
- S3 requires path-style access in LocalStack (configured in provider)
- IAM validation is less strict in LocalStack (acceptable)
- LocalStack should support all resources used in these tests
- Reference spec "Service-Specific Implementation Notes" for each service

---

### Task Group 6: Test Migration - Phase 3 (Remaining Tests)

**Dependencies**: Task Group 5
**Estimated Effort**: 6-8 hours
**Assignee**: Test Engineer

**Objective**: Complete migration of remaining test files to dual-mode.

- [ ] 6.0 Convert remaining tests to dual-mode
  - [ ] 6.1 Convert defaults tests
    - File: `/home/tom/p/t/sls.tf/tests/defaults.tftest.hcl`
    - Add LocalStack compatibility header (assess FULL or PARTIAL)
    - Add provider configuration block
    - Add variables section
    - Test default value application (should work identically)
  - [ ] 6.2 Convert code packaging tests
    - File: `/home/tom/p/t/sls.tf/tests/code_packaging.tftest.hcl`
    - Add LocalStack compatibility header: `# LocalStack Compatibility: FULL`
    - Add provider configuration block
    - Add variables section
    - Verify archive_file resource works with LocalStack
  - [ ] 6.3 Convert gap coverage tests
    - File: `/home/tom/p/t/sls.tf/tests/gap_coverage.tftest.hcl`
    - Add LocalStack compatibility header (assess compatibility)
    - Add provider configuration block
    - Add variables section
    - Review test scenarios for LocalStack compatibility
    - Add skip conditions for AWS-only scenarios if needed
  - [ ] 6.4 Convert event source validation tests
    - File: `/home/tom/p/t/sls.tf/tests/event_source_validation.tftest.hcl`
    - Add LocalStack compatibility header (assess compatibility)
    - Add provider configuration block
    - Add variables section
    - Review validation logic for LocalStack differences
  - [ ] 6.5 Create compatibility matrix documentation
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-test-matrix.md`
    - List all test files with compatibility level
    - Document LocalStack vs AWS behavior differences
    - List AWS-only tests and reasons
    - Provide troubleshooting tips per test file
    - Reference spec "Test Execution Matrix" section
  - [ ] 6.6 Run full test suite with LocalStack
    - Start LocalStack: `make localstack-start`
    - Run all tests: `make test-local`
    - Document pass/fail rate
    - Target: 80%+ tests passing with LocalStack
    - Create GitHub issues for any blocking failures
    - Document expected failures (AWS-only features)

**Acceptance Criteria**:
- All remaining test files converted to dual-mode
- Compatibility matrix documentation complete and accurate
- Full test suite runs with LocalStack via `make test-local`
- 80%+ of tests pass with LocalStack
- Known failures documented with explanations
- Test suite passes with AWS mode for validation

**Implementation Notes**:
- Prioritize high-value tests (core functionality)
- Accept that some tests may be AWS-only
- Document rather than fix LocalStack limitations
- Focus on making test suite useful for development
- Maintain test reliability in both modes

---

### Task Group 7: CI/CD Integration

**Dependencies**: Task Groups 4, 5, 6
**Estimated Effort**: 6-8 hours
**Assignee**: DevOps Engineer

**Objective**: Integrate LocalStack testing into CI/CD pipeline with fast feedback.

- [ ] 7.0 Complete CI/CD integration
  - [ ] 7.1 Create GitHub Actions workflow
    - File: Create `/home/tom/p/t/sls.tf/.github/workflows/test.yml`
    - Define workflow triggers:
      - `pull_request` on `[main, develop]` branches
      - `push` on `[main, develop]` branches
      - `workflow_dispatch` for manual runs
    - Create `test-localstack` job:
      - Runner: `ubuntu-latest`
      - Steps:
        1. Checkout code (`actions/checkout@v4`)
        2. Setup Terraform (`hashicorp/setup-terraform@v3`, version `1.6.0`)
        3. Start LocalStack (`docker-compose -f docker-compose.localstack.yml up -d`)
        4. Wait for LocalStack health check (60s timeout)
        5. Run Terraform init (`terraform init`)
        6. Run Terraform tests (`terraform test -var="use_localstack=true"`)
        7. Upload test results (if available)
        8. Show LocalStack logs on failure (`docker-compose logs`)
        9. Cleanup LocalStack (`docker-compose down -v`, always run)
    - Reference spec section "6. CI/CD Integration"
  - [ ] 7.2 Create optional AWS testing job
    - Add `test-aws` job to workflow
    - Conditions: Run only on `workflow_dispatch` or `main` branch pushes
    - Steps:
      1. Checkout code
      2. Setup Terraform
      3. Configure AWS credentials (from GitHub Secrets)
      4. Run Terraform init
      5. Run Terraform tests (`terraform test -var="use_localstack=false"`)
    - Secrets required:
      - `AWS_ACCESS_KEY_ID`
      - `AWS_SECRET_ACCESS_KEY`
    - Document that AWS tests are optional/manual
  - [ ] 7.3 Add workflow status badge to README
    - Update `/home/tom/p/t/sls.tf/README.md` (if exists)
    - Add GitHub Actions badge
    - Link to workflow runs
  - [ ] 7.4 Configure test result reporting
    - Add step to upload test results as artifacts
    - Configure GitHub Actions to show test summary
    - Add step to comment on PR with test results (optional)
  - [ ] 7.5 Optimize CI/CD performance
    - Cache Terraform providers between runs
    - Cache LocalStack Docker image
    - Use `EAGER_SERVICE_LOADING=1` for faster startup
    - Consider parallel test execution if supported
  - [ ] 7.6 Test CI/CD pipeline
    - Create test PR with small change
    - Verify LocalStack tests run automatically
    - Verify tests complete in <5 minutes
    - Verify logs accessible on failure
    - Verify cleanup happens (no resource leaks)
    - Test AWS job with `workflow_dispatch` (if credentials available)

**Acceptance Criteria**:
- GitHub Actions workflow configured and working
- LocalStack tests run on all PRs automatically
- Test execution completes in <5 minutes
- Test failures show clear error messages and logs
- AWS tests available via manual trigger
- Cleanup prevents resource leaks
- Workflow status visible in README

**Implementation Notes**:
- LocalStack container startup adds ~20-30 seconds to CI time
- Health check critical for test reliability
- Cleanup in `always()` block prevents leftover containers
- AWS tests optional to avoid credentials requirement
- Reference spec GitHub Actions example configuration

---

### Task Group 8: Documentation & Developer Experience

**Dependencies**: All previous task groups
**Estimated Effort**: 8-10 hours
**Assignee**: Technical Writer / Developer

**Objective**: Create comprehensive documentation for LocalStack setup, testing, and troubleshooting.

- [ ] 8.0 Complete documentation suite
  - [ ] 8.1 Create LocalStack setup guide
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-setup.md`
    - Sections:
      - Prerequisites (Docker, Make, Terraform versions)
      - Quick start (5-minute setup)
      - Make target reference (`localstack-start`, `localstack-stop`, etc.)
      - Health check explanation
      - Common setup issues and solutions
      - Port conflict resolution
      - Network troubleshooting
    - Include examples for each Make target
    - Reference spec Appendix E for Make target reference
  - [ ] 8.2 Create test writing guide
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-test-writing.md`
    - Sections:
      - Dual-mode test pattern
      - Provider configuration setup
      - Using test templates
      - Compatibility metadata guidelines
      - Skip patterns for AWS-only features
      - Graceful degradation examples
      - Common assertions and patterns
      - Debugging failed tests
    - Include before/after examples of test conversion
    - Reference spec section "4. Test File Structure - Dual-Mode Testing"
    - Include test writing checklist from spec Appendix C
  - [ ] 8.3 Create troubleshooting guide
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-troubleshooting.md`
    - Sections from spec Appendix B:
      - LocalStack container won't start
      - Health check timeout
      - S3 path-style access errors
      - Lambda invocation fails
      - IAM policy validation errors
      - API Gateway invoke URL issues
      - Docker socket permission errors
      - Port already in use errors
    - Include diagnostic commands for each issue
    - Provide step-by-step resolution guides
    - Link to LocalStack documentation where relevant
  - [ ] 8.4 Create migration guide for existing tests
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-migration-guide.md`
    - Sections:
      - When to use LocalStack vs AWS
      - Step-by-step test conversion process
      - Provider configuration template
      - Variable setup
      - Testing the conversion
      - Common migration issues
    - Include migration checklist
    - Provide examples from actual migrated tests
  - [ ] 8.5 Update main README
    - File: Update `/home/tom/p/t/sls.tf/README.md`
    - Add LocalStack section with:
      - Quick start (one-liner: `make test-local`)
      - Link to detailed documentation
      - Benefits (speed, cost, no AWS account needed)
      - Make target quick reference
    - Add LocalStack badge/logo if appropriate
    - Update testing section to mention LocalStack
  - [ ] 8.6 Create variable reference documentation
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-variables.md`
    - Document all LocalStack-related variables:
      - `use_localstack` (bool)
      - `localstack_endpoint` (string)
    - Document usage in tests vs module
    - Provide CLI override examples
    - Reference spec Appendix D
  - [ ] 8.7 Create developer onboarding checklist
    - File: Create `/home/tom/p/t/sls.tf/docs/localstack-onboarding.md`
    - Checklist for new developers:
      - [ ] Install Docker
      - [ ] Install Make
      - [ ] Clone repository
      - [ ] Run `make localstack-start`
      - [ ] Run `make test-local`
      - [ ] Review test writing guide
      - [ ] Write first dual-mode test
    - Estimate: <10 minutes for setup
    - Include verification steps
  - [ ] 8.8 Test documentation with new developer
    - Ask colleague to follow setup guide
    - Time the onboarding process (target: <10 minutes)
    - Collect feedback on clarity
    - Identify gaps in documentation
    - Update documentation based on feedback
    - Verify all links work

**Acceptance Criteria**:
- Setup guide enables new developer to start testing in <10 minutes
- Test writing guide provides clear examples and patterns
- Troubleshooting guide covers all common issues from spec Appendix B
- Migration guide helps convert existing tests
- README updated with LocalStack information
- Documentation reviewed by at least one other developer
- All internal documentation links working

**Implementation Notes**:
- Use clear, beginner-friendly language
- Include plenty of code examples
- Use diagrams for complex concepts (optional)
- Link to official LocalStack docs where appropriate
- Keep documentation in sync with code changes
- Follow project documentation style (if exists)

---

## Execution Order & Dependencies

```
Task Group 1: Infrastructure Setup (No dependencies)
    ↓
Task Group 2: Provider Configuration (Depends on 1)
    ↓
Task Group 3: Test Framework Enhancement (Depends on 2)
    ↓
Task Group 4: Test Migration Phase 1 (Depends on 3)
    ↓
Task Group 5: Test Migration Phase 2 (Depends on 4)
    ↓
Task Group 6: Test Migration Phase 3 (Depends on 5)
    ↓
Task Group 7: CI/CD Integration (Depends on 4, 5, 6)
Task Group 8: Documentation (Can run parallel with 7, depends on all)
```

**Recommended Implementation Sequence**:

1. **Week 1**: Task Groups 1-3 (Infrastructure, provider config, test framework)
2. **Week 2**: Task Groups 4-5 (Parsing tests, resource creation tests)
3. **Week 3**: Task Group 6 (Remaining tests)
4. **Week 4**: Task Groups 7-8 (CI/CD, documentation)

**Parallel Work Opportunities**:
- Task Groups 4, 5, 6 can be partially parallelized (different test files)
- Task Group 8 (documentation) can run parallel with Task Group 7

---

## Testing Strategy

### Test-First Approach
Each task group follows this pattern:
1. **Setup**: Create infrastructure/configuration
2. **Verify**: Manual testing of setup
3. **Validate**: Automated tests pass
4. **Document**: Update documentation

### Test Verification Points

**After Task Group 1**:
- Run: `make localstack-start && make localstack-health && make localstack-stop`
- Expected: Clean startup, healthy services, clean shutdown

**After Task Group 2**:
- Create temporary test with provider config
- Run: `terraform init && terraform plan -var="use_localstack=true"`
- Expected: No provider errors, endpoints point to LocalStack

**After Task Group 3**:
- Use shared test config in sample test
- Verify compatibility metadata is clear
- Verify skip patterns work

**After Task Group 4**:
- Run: `make test-local` with parsing tests
- Expected: All parsing tests pass

**After Task Group 5**:
- Run: `make test-local` with resource creation tests
- Expected: API Gateway and S3 resources created in LocalStack

**After Task Group 6**:
- Run: `make test-local` (full suite)
- Expected: 80%+ tests pass

**After Task Group 7**:
- Create test PR
- Expected: CI/CD runs LocalStack tests automatically

**After Task Group 8**:
- Follow setup guide as new developer
- Expected: Testing works in <10 minutes

---

## Success Metrics & Validation

### Performance Metrics
- [ ] Test execution time: <60 seconds for full suite (vs ~300s with AWS)
- [ ] LocalStack startup: <30 seconds
- [ ] CI/CD total time: <5 minutes including setup and cleanup

### Coverage Metrics
- [ ] 80%+ of tests pass with LocalStack
- [ ] 100% of parsing tests work with LocalStack (Task Group 4)
- [ ] 90%+ of resource creation tests work with LocalStack (Task Groups 5-6)

### Developer Experience Metrics
- [ ] New developer setup: <10 minutes
- [ ] Documentation completeness: All common scenarios covered
- [ ] Zero AWS costs for development workflow

### Quality Metrics
- [ ] Test reliability: 95%+ consistent pass rate
- [ ] False positive rate: <5% (tests pass in LocalStack but fail in AWS)
- [ ] CI/CD success rate: 90%+ successful runs

---

## Risk Mitigation

### Risk: LocalStack Behavioral Differences
**Mitigation**:
- Maintain dual-mode testing capability (Task Group 3)
- Run AWS tests on main branch (Task Group 7)
- Document known differences (Task Group 8)

### Risk: Flaky LocalStack Tests
**Mitigation**:
- Implement robust health checks (Task Group 1)
- Add retry logic for health checks (Task Group 1)
- Capture logs on failure (Task Group 7)

### Risk: Developer Confusion
**Mitigation**:
- Comprehensive documentation (Task Group 8)
- Clear examples and templates (Task Groups 3, 8)
- Test writing checklist (Task Group 8)

### Risk: CI/CD Pipeline Slowdown
**Mitigation**:
- Cache Docker images (Task Group 7)
- Optimize service loading (Task Group 1)
- Monitor and benchmark performance

---

## Post-Implementation

### Maintenance Tasks
- [ ] Update LocalStack version quarterly
- [ ] Review test compatibility matrix monthly
- [ ] Update documentation as features added
- [ ] Monitor CI/CD performance metrics

### Future Enhancements
- [ ] Evaluate LocalStack Pro (if Community Edition limitations block >20% tests)
- [ ] Add support for roadmap services (EventBridge, DynamoDB, SQS, Route53)
- [ ] Implement test parallelization
- [ ] Add performance benchmarking

---

## File Reference

### Files to Create
- `/home/tom/p/t/sls.tf/docker-compose.localstack.yml`
- `/home/tom/p/t/sls.tf/Makefile`
- `/home/tom/p/t/sls.tf/.localstack/config.yml`
- `/home/tom/p/t/sls.tf/docs/localstack-provider-config.md`
- `/home/tom/p/t/sls.tf/docs/localstack-testing.md`
- `/home/tom/p/t/sls.tf/docs/localstack-test-matrix.md`
- `/home/tom/p/t/sls.tf/docs/localstack-setup.md`
- `/home/tom/p/t/sls.tf/docs/localstack-test-writing.md`
- `/home/tom/p/t/sls.tf/docs/localstack-troubleshooting.md`
- `/home/tom/p/t/sls.tf/docs/localstack-migration-guide.md`
- `/home/tom/p/t/sls.tf/docs/localstack-variables.md`
- `/home/tom/p/t/sls.tf/docs/localstack-onboarding.md`
- `/home/tom/p/t/sls.tf/tests/shared_test_config.tftest.hcl`
- `/home/tom/p/t/sls.tf/tests/test_provider_template.txt`
- `/home/tom/p/t/sls.tf/.github/workflows/test.yml`

### Files to Modify
- `/home/tom/p/t/sls.tf/variables.tf` (add LocalStack variables)
- `/home/tom/p/t/sls.tf/.gitignore` (add `.localstack/data/`)
- `/home/tom/p/t/sls.tf/README.md` (add LocalStack section)
- `/home/tom/p/t/sls.tf/tests/http_event_parsing.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/s3_event_parsing.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/path_parsing.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/event_source_parsing.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/s3_validation.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/api_gateway_resources.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/api_gateway_integration.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/api_gateway_deployment.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/cors_configuration.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/s3_bucket_management.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/defaults.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/code_packaging.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/gap_coverage.tftest.hcl` (add dual-mode config)
- `/home/tom/p/t/sls.tf/tests/event_source_validation.tftest.hcl` (add dual-mode config)

---

## Integration Points with Existing Codebase

### Existing Test Pattern
Current tests follow this pattern:
```hcl
run "test_name" {
  command = plan

  variables {
    config_path = "tests/fixtures/example.yml"
  }

  assert {
    condition = <assertion>
    error_message = "<message>"
  }
}
```

### Dual-Mode Test Pattern
Converted tests will add:
```hcl
# LocalStack Compatibility: FULL
# <Description>

provider "aws" {
  region = "us-east-1"
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check = var.use_localstack
  skip_requesting_account_id = var.use_localstack
  s3_use_path_style = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      # Service endpoints
    }
  }
}

run "test_name" {
  # ... existing test code
}
```

### Variable Integration
Module variables in `/home/tom/p/t/sls.tf/variables.tf`:
- Existing: `config_path`, `config_format`, `aws_region`, `lambda_code_path`
- Adding: `use_localstack`, `localstack_endpoint`
- Pattern: Simple types with validation blocks

### Fixture Reuse
All existing YAML fixtures in `/home/tom/p/t/sls.tf/tests/fixtures/` will be reused without modification. This ensures:
- Test parity between LocalStack and AWS
- Single source of truth for test scenarios
- No duplication of test data

---

## Notes

- **Tech Stack Compliance**: This is a Terraform module project with custom testing approach
- **No Framework**: Pure Terraform with `terraform test` framework
- **Minimal Dependencies**: Docker, Make, Terraform only
- **Test Philosophy**: Focused strategic tests, not exhaustive coverage (per project standards)
- **Documentation Priority**: Clear setup and troubleshooting critical for adoption
