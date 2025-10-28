# Specification: LocalStack Integration for Testing

## Goal

Enable fast, cost-free local testing of the Serverless-to-Terraform translation module by integrating LocalStack Community Edition as a drop-in replacement for AWS during test execution, reducing test execution time by 80%+ and eliminating AWS costs during development.

## User Stories

- As a developer, I want to run tests locally without AWS credentials so that I can develop features without AWS account access or costs
- As a contributor, I want CI/CD to validate my PRs automatically using LocalStack so that I get fast feedback without waiting for AWS resources
- As a maintainer, I want dual-mode tests that work with both LocalStack and real AWS so that I can validate LocalStack accuracy against real AWS behavior
- As a tester, I want clear error messages when LocalStack limitations are encountered so that I understand which features require real AWS testing
- As a developer, I want simple Make targets to manage LocalStack lifecycle so that I can start/stop LocalStack without Docker knowledge

## Core Requirements

- LocalStack Community Edition running in Docker container for local AWS emulation
- Terraform provider endpoint override mechanism to switch between LocalStack and real AWS
- Test framework toggle to enable dual-mode testing (LocalStack or AWS)
- Make targets for LocalStack lifecycle management (start, stop, health check, logs, clean)
- CI/CD pipeline integration with mandatory LocalStack tests on all PRs
- Support for current services: Lambda, API Gateway, S3, IAM
- Pre-emptive support for roadmap services: EventBridge, DynamoDB, SQS, Route53
- Graceful handling of LocalStack limitations with skip logic for unsupported features
- Reuse all existing test fixtures (tests/fixtures/*.yml) for parity testing
- Zero AWS costs for standard development workflow
- Developer documentation for setup, usage, and troubleshooting

## Visual Design

No visual components - this is infrastructure and testing enhancement.

## Reusable Components

### Existing Code to Leverage

**Test Framework Structure:**
- `/home/tom/p/t/sls.tf/tests/*.tftest.hcl` - 20+ existing Terraform test files using `terraform test` command
- Test pattern: `run "test_name" { command = plan; variables {...}; assert {...} }`
- Existing test fixtures: `/home/tom/p/t/sls.tf/tests/fixtures/*.yml` - YAML configurations for various scenarios

**Provider Configuration:**
- `/home/tom/p/t/sls.tf/versions.tf` - Required providers block (AWS >= 6.0, null >= 3.0, archive >= 2.0)
- No existing provider configuration block (module doesn't declare provider, expects it from parent)

**Variables System:**
- `/home/tom/p/t/sls.tf/variables.tf` - Existing variables: `config_path`, `config_format`, `aws_region`, `lambda_code_path`
- Variable-based configuration pattern already established

**Resource Patterns:**
- `/home/tom/p/t/sls.tf/main.tf` - Lambda, API Gateway, IAM resources
- `/home/tom/p/t/sls.tf/s3.tf` - S3 bucket and notification resources
- `/home/tom/p/t/sls.tf/locals.tf` - Validation and parsing logic (620+ lines)

**Outputs:**
- `/home/tom/p/t/sls.tf/outputs.tf` - Comprehensive outputs for function ARNs, API endpoints, S3 buckets, event source mappings

### New Components Required

**LocalStack Configuration:**
- Docker Compose file for LocalStack container lifecycle
- Makefile with targets for LocalStack management
- Health check script for LocalStack readiness validation
- LocalStack configuration file for service enablement

**Provider Override System:**
- Test-level variables for endpoint configuration
- Provider configuration wrapper for tests
- Endpoint mapping for AWS services to LocalStack URLs

**Test Framework Enhancements:**
- Dual-mode test runner script/wrapper
- Environment detection logic
- Skip patterns for LocalStack-incompatible tests
- Test metadata for LocalStack compatibility

**CI/CD Integration:**
- GitHub Actions/GitLab CI workflow changes
- LocalStack container setup in pipeline
- Test execution strategy (LocalStack required, AWS optional)

**Documentation:**
- LocalStack setup guide
- Test writing guide for dual-mode tests
- Troubleshooting guide for common LocalStack issues
- Migration guide for converting existing tests

## Technical Approach

### Architecture Overview

Use Terraform's provider configuration flexibility with endpoint overrides to enable dual-mode testing. Tests will conditionally set AWS provider endpoints to LocalStack URLs when `use_localstack` variable is true. LocalStack runs in Docker with exposed ports for AWS service endpoints.

### Provider Configuration Strategy

**Approach: Test-level Provider Configuration with Endpoint Overrides**

Create a new `providers.tf` file in the module that declares the AWS provider configuration with optional endpoint overrides. Tests will pass variables to override endpoints when using LocalStack.

**Why this approach:**
- Clean separation between LocalStack and AWS modes
- No environment variable pollution
- Compatible with Terraform test framework
- Reuses existing variable pattern
- Easy to toggle per test or globally
- Works with module-based architecture

**Key decision:** Use conditional endpoint configuration blocks rather than provider aliases, as provider aliases would require duplicate resource definitions.

### LocalStack Service Support Matrix

| Service | LocalStack Community | Current Support | Roadmap | Notes |
|---------|---------------------|-----------------|---------|-------|
| Lambda | Full | Yes | - | Execution, layers, environment vars |
| API Gateway | Full | Yes | - | REST API, integrations, CORS |
| S3 | Full | Yes | - | Buckets, notifications, events |
| IAM | Full | Yes | - | Roles, policies (limited validation) |
| EventBridge | Partial | No | Yes | Basic rules, limited patterns |
| DynamoDB | Full | Yes (partial) | Yes | Streams fully supported |
| SQS | Full | No | Yes | Standard and FIFO queues |
| Route53 | Basic | No | Yes | Limited DNS features |

**Handling Partial Support:**
- EventBridge: Support basic schedule/cron rules, skip complex event patterns
- IAM: Accept reduced validation strictness vs real AWS
- Route53: Test basic DNS records, skip advanced routing policies

### Configuration Flow

```
Test Execution
    ↓
Test Variables (use_localstack = true/false)
    ↓
Provider Configuration (endpoint overrides)
    ↓
AWS Provider Initialization
    ↓
Resource Creation (LocalStack or AWS)
    ↓
Assertions & Validation
```

### File Structure

```
/home/tom/p/t/sls.tf/
├── docker-compose.localstack.yml    # LocalStack container definition
├── Makefile                         # LocalStack lifecycle targets
├── .localstack/                     # LocalStack configuration
│   ├── config.yml                   # LocalStack service config
│   └── init-scripts/                # Initialization scripts
├── providers.tf                     # NEW: Provider config with endpoints
├── variables.tf                     # UPDATED: Add LocalStack variables
├── tests/
│   ├── *.tftest.hcl                # UPDATED: Add provider config
│   ├── localstack_helpers.tftest.hcl # NEW: Shared test helpers
│   └── fixtures/                    # REUSE: Existing YAML fixtures
└── docs/
    └── localstack-testing.md        # NEW: Developer documentation
```

## Implementation Details

### 1. Docker Compose Configuration

Create `/home/tom/p/t/sls.tf/docker-compose.localstack.yml`:

```yaml
version: '3.8'

services:
  localstack:
    container_name: sls-tf-localstack
    image: localstack/localstack:latest
    ports:
      - "4566:4566"            # LocalStack gateway
      - "4510-4559:4510-4559"  # External service port range
    environment:
      - SERVICES=lambda,apigateway,s3,iam,dynamodb,sqs,events,route53
      - DEBUG=0
      - LAMBDA_EXECUTOR=docker-reuse
      - DOCKER_HOST=unix:///var/run/docker.sock
      - PERSISTENCE=0
      - EAGER_SERVICE_LOADING=1
    volumes:
      - "${PWD}/.localstack:/etc/localstack/init/ready.d"
      - "/var/run/docker.sock:/var/run/docker.sock"
    networks:
      - localstack-network

networks:
  localstack-network:
    driver: bridge
```

**Key Configuration Decisions:**
- `SERVICES`: Explicitly list required services for faster startup
- `LAMBDA_EXECUTOR=docker-reuse`: Reuse containers for faster Lambda execution
- `PERSISTENCE=0`: No state persistence (clean slate each run)
- `EAGER_SERVICE_LOADING=1`: Load all services at startup for predictable behavior
- Port 4566: Single gateway port for all services (LocalStack Community default)

### 2. Makefile Targets

Create `/home/tom/p/t/sls.tf/Makefile`:

```makefile
.PHONY: localstack-start localstack-stop localstack-restart localstack-status localstack-logs localstack-health localstack-clean test-local test-aws test-all

# LocalStack Management
localstack-start:
	@echo "Starting LocalStack..."
	@docker-compose -f docker-compose.localstack.yml up -d
	@echo "Waiting for LocalStack to be ready..."
	@$(MAKE) localstack-health

localstack-stop:
	@echo "Stopping LocalStack..."
	@docker-compose -f docker-compose.localstack.yml down

localstack-restart: localstack-stop localstack-start

localstack-status:
	@docker-compose -f docker-compose.localstack.yml ps

localstack-logs:
	@docker-compose -f docker-compose.localstack.yml logs -f

localstack-health:
	@echo "Checking LocalStack health..."
	@timeout 60 bash -c 'until curl -s http://localhost:4566/_localstack/health | grep -q "\"s3\": *\"available\""; do sleep 2; done' || (echo "LocalStack health check failed" && exit 1)
	@echo "LocalStack is healthy and ready"

localstack-clean: localstack-stop
	@echo "Cleaning LocalStack volumes and containers..."
	@docker-compose -f docker-compose.localstack.yml down -v
	@rm -rf .localstack/data

# Testing Targets
test-local:
	@echo "Running tests against LocalStack..."
	@$(MAKE) localstack-start
	@terraform init -upgrade
	@terraform test -var="use_localstack=true"

test-aws:
	@echo "Running tests against real AWS..."
	@terraform init -upgrade
	@terraform test -var="use_localstack=false"

test-all: test-local
	@echo "Running LocalStack tests only (AWS tests require manual trigger)"

# Default target
help:
	@echo "LocalStack Testing Targets:"
	@echo "  localstack-start    - Start LocalStack container"
	@echo "  localstack-stop     - Stop LocalStack container"
	@echo "  localstack-restart  - Restart LocalStack container"
	@echo "  localstack-status   - Check LocalStack container status"
	@echo "  localstack-logs     - Tail LocalStack logs"
	@echo "  localstack-health   - Check LocalStack health endpoints"
	@echo "  localstack-clean    - Stop and remove all LocalStack data"
	@echo "  test-local          - Run tests against LocalStack"
	@echo "  test-aws            - Run tests against real AWS"
	@echo "  test-all            - Run LocalStack tests (default)"
```

**Design Decisions:**
- Health check uses LocalStack's `/_localstack/health` endpoint
- 60-second timeout for health check (LocalStack startup can be slow)
- `localstack-clean` removes volumes to ensure clean state
- Separate test targets for explicit LocalStack/AWS choice
- `test-all` defaults to LocalStack (no AWS costs)

### 3. Provider Configuration with Endpoint Overrides

Create `/home/tom/p/t/sls.tf/providers.tf`:

```hcl
# This file configures the AWS provider with optional endpoint overrides for LocalStack
# When use_localstack is true, all AWS service endpoints point to LocalStack

# LocalStack endpoint configuration
locals {
  # LocalStack gateway endpoint (single endpoint for all services in Community Edition)
  localstack_endpoint = "http://localhost:4566"

  # Conditional endpoint configuration
  endpoints = var.use_localstack ? {
    apigateway     = local.localstack_endpoint
    cloudformation = local.localstack_endpoint
    cloudwatch     = local.localstack_endpoint
    dynamodb       = local.localstack_endpoint
    ec2            = local.localstack_endpoint
    es             = local.localstack_endpoint
    events         = local.localstack_endpoint
    firehose       = local.localstack_endpoint
    iam            = local.localstack_endpoint
    kinesis        = local.localstack_endpoint
    lambda         = local.localstack_endpoint
    route53        = local.localstack_endpoint
    s3             = local.localstack_endpoint
    secretsmanager = local.localstack_endpoint
    ses            = local.localstack_endpoint
    sns            = local.localstack_endpoint
    sqs            = local.localstack_endpoint
    ssm            = local.localstack_endpoint
    stepfunctions  = local.localstack_endpoint
    sts            = local.localstack_endpoint
  } : {}
}

# Note: This module does NOT declare the AWS provider directly
# The provider must be configured by the calling module/test
# This file only provides endpoint configuration helpers
```

Update `/home/tom/p/t/sls.tf/variables.tf`:

```hcl
variable "use_localstack" {
  description = "Enable LocalStack mode for testing. When true, all AWS provider endpoints will point to LocalStack."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL. Only used when use_localstack is true."
  type        = string
  default     = "http://localhost:4566"

  validation {
    condition     = can(regex("^https?://", var.localstack_endpoint))
    error_message = "localstack_endpoint must be a valid HTTP or HTTPS URL."
  }
}
```

### 4. Test File Structure - Dual-Mode Testing

**Pattern for Dual-Mode Tests:**

Tests must declare a provider configuration block that respects the `use_localstack` variable. Create shared test helper configuration.

Create `/home/tom/p/t/sls.tf/tests/test_config.tftest.hcl`:

```hcl
# Shared test configuration for provider setup
# Include this in all test files that need AWS provider

# Provider configuration with conditional LocalStack endpoints
provider "aws" {
  region = "us-east-1"

  # Skip credential validation when using LocalStack
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  # S3 path style required for LocalStack
  s3_use_path_style = var.use_localstack

  # Conditional endpoint overrides
  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      apigateway     = var.localstack_endpoint
      dynamodb       = var.localstack_endpoint
      iam            = var.localstack_endpoint
      lambda         = var.localstack_endpoint
      s3             = var.localstack_endpoint
      sqs            = var.localstack_endpoint
      events         = var.localstack_endpoint
      route53        = var.localstack_endpoint
      sts            = var.localstack_endpoint
    }
  }
}

# LocalStack-specific variables
variables {
  use_localstack      = true  # Override in CI/CD or local runs
  localstack_endpoint = "http://localhost:4566"
}
```

**Example: Converting Existing Test to Dual-Mode**

Before (existing test):
```hcl
run "short_form_http_event" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-short-form.yml"
  }

  assert {
    condition     = length(local.http_events) == 1
    error_message = "Should parse one HTTP event from short-form syntax"
  }
}
```

After (dual-mode test):
```hcl
# Provider configuration
provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      apigateway = var.localstack_endpoint
      lambda     = var.localstack_endpoint
      s3         = var.localstack_endpoint
      iam        = var.localstack_endpoint
    }
  }
}

run "short_form_http_event" {
  command = plan

  variables {
    config_path    = "tests/fixtures/http-short-form.yml"
    use_localstack = true  # Can be overridden via CLI
  }

  assert {
    condition     = length(local.http_events) == 1
    error_message = "Should parse one HTTP event from short-form syntax"
  }
}
```

### 5. Handling LocalStack Limitations

**Skip Pattern for Unsupported Features:**

```hcl
run "eventbridge_complex_pattern" {
  command = plan

  # Skip this test when using LocalStack (complex EventBridge patterns not supported)
  condition = !var.use_localstack

  variables {
    config_path = "tests/fixtures/eventbridge-complex.yml"
  }

  assert {
    condition     = length(local.eventbridge_rules) == 1
    error_message = "Should create EventBridge rule with complex pattern"
  }
}
```

**Graceful Degradation Pattern:**

```hcl
run "iam_role_validation" {
  command = plan

  variables {
    config_path = "tests/fixtures/iam-complex.yml"
  }

  assert {
    condition     = length(aws_iam_role.lambda_execution) > 0
    error_message = "Should create IAM roles"
  }

  # LocalStack has weaker IAM validation - skip strict checks
  assert {
    condition     = var.use_localstack || can(regex("arn:aws:iam::", aws_iam_role.lambda_execution["myFunc"].arn))
    error_message = "IAM role ARN should follow AWS format (skipped in LocalStack)"
  }
}
```

**LocalStack Compatibility Metadata:**

Add comments to test files indicating LocalStack compatibility:

```hcl
# LocalStack Compatibility: FULL
# All tests in this file work with LocalStack Community Edition

# LocalStack Compatibility: PARTIAL
# Tests marked with 'condition = !var.use_localstack' require real AWS

# LocalStack Compatibility: NONE
# This test file requires real AWS (Pro features, advanced IAM, etc.)
```

### 6. CI/CD Integration

**GitHub Actions Workflow Example:**

Create `.github/workflows/test.yml`:

```yaml
name: Terraform Tests

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]

jobs:
  test-localstack:
    name: Test with LocalStack
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Start LocalStack
        run: |
          docker-compose -f docker-compose.localstack.yml up -d

      - name: Wait for LocalStack
        run: |
          timeout 60 bash -c 'until curl -s http://localhost:4566/_localstack/health | grep -q "\"s3\": *\"available\""; do sleep 2; done'

      - name: Run Terraform Tests
        run: |
          terraform init
          terraform test -var="use_localstack=true"

      - name: LocalStack Logs on Failure
        if: failure()
        run: docker-compose -f docker-compose.localstack.yml logs

      - name: Cleanup
        if: always()
        run: docker-compose -f docker-compose.localstack.yml down -v

  test-aws:
    name: Test with Real AWS (Manual)
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch' || github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Run Terraform Tests Against AWS
        run: |
          terraform init
          terraform test -var="use_localstack=false"
```

**Key CI/CD Design Decisions:**
- LocalStack tests run on all PRs (mandatory)
- AWS tests run only on workflow_dispatch or main branch (optional/manual)
- LocalStack logs captured on failure for debugging
- Separate jobs for clear separation
- LocalStack container cleanup in always() block

## Service-Specific Implementation Notes

### Lambda

**LocalStack Support: FULL**

- Function creation, invocation, environment variables: Fully supported
- Layers: Supported in Community Edition
- VPC configuration: Limited (accepts config but no actual VPC)

**Test Considerations:**
- Lambda code packaging works identically
- Execution logs available via LocalStack logs
- Cold start times differ from AWS (faster in LocalStack)

**Configuration:**
```hcl
# No special handling needed - works out of the box
# Archive file packaging works identically
```

### API Gateway

**LocalStack Support: FULL**

- REST API creation, methods, integrations: Fully supported
- Deployments and stages: Supported
- CORS configuration: Supported
- Custom domains: Limited (basic support only)

**Test Considerations:**
- Invoke URLs use localhost:4566 instead of AWS domains
- CORS headers work but may have minor behavior differences
- Stage variables supported

**Configuration:**
```hcl
# Endpoint format: http://localhost:4566/restapis/{api-id}/{stage}/_user_request/{path}
# Tests should use output.api_gateway_invoke_url for compatibility
```

### S3

**LocalStack Support: FULL**

- Bucket creation, deletion: Fully supported
- Bucket notifications: Supported
- Event filtering (prefix/suffix): Supported
- Versioning: Supported

**Test Considerations:**
- Bucket names must be unique within LocalStack instance
- Path-style access required (s3_use_path_style = true)
- Notification delivery to Lambda works correctly

**Configuration:**
```hcl
# S3 path-style access required
provider "aws" {
  s3_use_path_style = var.use_localstack
}
```

### IAM

**LocalStack Support: PARTIAL**

- Role creation: Supported
- Policy attachment: Supported
- Permission validation: Limited (accepts invalid permissions)
- AssumeRole: Basic support

**Test Considerations:**
- IAM validation is less strict than AWS
- Tests should focus on structure rather than strict validation
- ARN formats may differ slightly

**Skip Patterns:**
```hcl
# Skip strict IAM validation tests in LocalStack
run "iam_permission_boundary_enforcement" {
  condition = !var.use_localstack
  # ... test implementation
}
```

### EventBridge (Roadmap)

**LocalStack Support: PARTIAL**

- Schedule expressions (cron/rate): Supported
- Basic event patterns: Supported
- Complex event filtering: Limited
- Cross-account events: Not supported

**Test Strategy:**
- Test basic schedule rules with LocalStack
- Skip complex pattern matching tests
- Document limitations clearly

**Skip Patterns:**
```hcl
run "eventbridge_complex_content_filtering" {
  condition = !var.use_localstack
  # Complex event patterns not supported in Community
}
```

### DynamoDB Streams (Roadmap)

**LocalStack Support: FULL**

- Stream creation: Supported
- Event source mappings: Supported
- Batch size, starting position: Supported
- Stream view type: Supported

**Test Considerations:**
- Streams work reliably in LocalStack
- No special handling needed
- Full feature parity expected

### SQS (Roadmap)

**LocalStack Support: FULL**

- Queue creation (standard and FIFO): Fully supported
- Event source mappings: Supported
- Batch size configuration: Supported
- Dead letter queues: Supported

**Test Considerations:**
- Message delivery timing may differ
- FIFO ordering guarantees maintained
- No special configuration needed

### Route53 (Roadmap)

**LocalStack Support: BASIC**

- Hosted zone creation: Supported
- Basic record sets: Supported
- Alias records: Limited
- Routing policies: Not supported

**Test Strategy:**
- Test basic DNS record creation
- Skip advanced routing policies
- Skip health checks (not supported)

**Skip Patterns:**
```hcl
run "route53_weighted_routing_policy" {
  condition = !var.use_localstack
  # Advanced routing not supported in Community
}
```

## Error Handling & Validation

### LocalStack Availability Detection

Create health check helper in tests:

```hcl
# tests/localstack_helpers.tftest.hcl
locals {
  localstack_available = var.use_localstack ? (
    can(
      jsondecode(
        data.http.localstack_health.body
      ).services.s3 == "available"
    )
  ) : false
}

data "http" "localstack_health" {
  count = var.use_localstack ? 1 : 0
  url   = "${var.localstack_endpoint}/_localstack/health"
}
```

### Graceful Degradation Messages

```hcl
resource "null_resource" "localstack_validation" {
  count = var.use_localstack ? 1 : 0

  lifecycle {
    precondition {
      condition     = can(jsondecode(data.http.localstack_health[0].body))
      error_message = "LocalStack is not available at ${var.localstack_endpoint}. Run 'make localstack-start' to start LocalStack."
    }
  }
}
```

### Clear Error Messages

```hcl
# Example: Unsupported feature detection
resource "null_resource" "feature_compatibility_check" {
  lifecycle {
    precondition {
      condition     = !var.use_localstack || !contains(local.features_used, "advanced_iam_boundary")
      error_message = "This configuration uses IAM permission boundaries which are not supported in LocalStack Community Edition. Run tests with use_localstack=false to test against real AWS."
    }
  }
}
```

## Examples

### Example 1: Dual-Mode Test File

```hcl
# tests/lambda_basic_creation.tftest.hcl
# LocalStack Compatibility: FULL

# Provider configuration
provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      lambda = var.localstack_endpoint
      iam    = var.localstack_endpoint
      s3     = var.localstack_endpoint
    }
  }
}

variables {
  use_localstack = true  # Default to LocalStack, override via CLI
}

run "create_basic_lambda_function" {
  command = plan

  variables {
    config_path      = "tests/fixtures/lambda-basic.yml"
    lambda_code_path = "tests/fixtures/lambda-code"
  }

  assert {
    condition     = length(aws_lambda_function.functions) == 1
    error_message = "Should create exactly one Lambda function"
  }

  assert {
    condition     = aws_lambda_function.functions["hello"].runtime == "nodejs18.x"
    error_message = "Should set correct runtime"
  }

  assert {
    condition     = aws_lambda_function.functions["hello"].memory_size == 1024
    error_message = "Should apply default memory size"
  }
}

run "lambda_with_environment_variables" {
  command = plan

  variables {
    config_path      = "tests/fixtures/lambda-env-vars.yml"
    lambda_code_path = "tests/fixtures/lambda-code"
  }

  assert {
    condition     = aws_lambda_function.functions["api"].environment[0].variables["NODE_ENV"] == "production"
    error_message = "Should set environment variables correctly"
  }
}
```

### Example 2: Make Target Usage

```bash
# Start LocalStack
make localstack-start

# Run tests against LocalStack (default)
make test-local

# Run specific test file
terraform test -var="use_localstack=true" -filter="lambda_basic_creation"

# Check LocalStack health
make localstack-health

# View LocalStack logs
make localstack-logs

# Stop LocalStack
make localstack-stop

# Clean everything
make localstack-clean
```

### Example 3: Provider Configuration in CI/CD

```yaml
# .github/workflows/test.yml snippet
- name: Run All Tests with LocalStack
  run: |
    terraform init
    terraform test -var="use_localstack=true"

# Run specific test with AWS (manual trigger)
- name: Run AWS-Specific Tests
  if: github.event_name == 'workflow_dispatch'
  run: |
    terraform init
    terraform test -filter="aws_only" -var="use_localstack=false"
```

### Example 4: Test with LocalStack Limitations

```hcl
# tests/iam_advanced_policies.tftest.hcl
# LocalStack Compatibility: PARTIAL

run "iam_policy_structure" {
  # This test works with both LocalStack and AWS
  command = plan

  variables {
    config_path = "tests/fixtures/iam-complex.yml"
  }

  assert {
    condition     = length(aws_iam_role_policy.lambda_custom_policy) > 0
    error_message = "Should create IAM policies"
  }
}

run "iam_permission_boundary_enforcement" {
  # This test requires real AWS - skip in LocalStack
  condition = !var.use_localstack
  command   = plan

  variables {
    config_path = "tests/fixtures/iam-permission-boundary.yml"
  }

  assert {
    condition     = aws_iam_role.lambda_execution["secured"].permissions_boundary != null
    error_message = "Should enforce permission boundaries"
  }
}
```

## Migration Strategy

### Phase 1: Infrastructure Setup (Week 1)

1. Create `docker-compose.localstack.yml`
2. Create `Makefile` with LocalStack targets
3. Add `use_localstack` and `localstack_endpoint` variables
4. Create provider configuration helpers
5. Test LocalStack startup and health checks manually

**Success Criteria:**
- `make localstack-start` successfully starts LocalStack
- Health check passes within 60 seconds
- All AWS service endpoints respond

### Phase 2: Test Framework Enhancement (Week 1-2)

1. Create shared test configuration helpers
2. Convert 3-5 simple tests to dual-mode (Lambda, S3 basic)
3. Document test conversion pattern
4. Test dual-mode tests against both LocalStack and AWS

**Success Criteria:**
- Converted tests pass in both LocalStack and AWS modes
- Clear pattern established for test conversion
- Documentation covers common scenarios

### Phase 3: Bulk Test Migration (Week 2-3)

1. Convert all existing tests to dual-mode where possible
2. Mark AWS-only tests with `condition = !var.use_localstack`
3. Add LocalStack compatibility metadata to all test files
4. Create troubleshooting guide for common issues

**Success Criteria:**
- 80%+ of tests work with LocalStack
- 100% of tests have compatibility metadata
- Clear skip patterns for LocalStack limitations

### Phase 4: CI/CD Integration (Week 3)

1. Create GitHub Actions workflow
2. Test LocalStack container in CI
3. Configure AWS credentials for optional AWS tests
4. Set up test reporting

**Success Criteria:**
- LocalStack tests run automatically on all PRs
- Test results clearly indicate LocalStack vs AWS
- Failed tests show LocalStack logs for debugging

### Phase 5: Documentation & Rollout (Week 4)

1. Write comprehensive LocalStack setup guide
2. Create test writing guide with examples
3. Document known limitations and workarounds
4. Train team on LocalStack usage

**Success Criteria:**
- New contributors can run tests without AWS account
- Clear documentation for all LocalStack features
- Team understands when to use LocalStack vs AWS

## Testing the Migration

### Validation Checklist

For each migrated test file:

- [ ] Test passes with `use_localstack=true`
- [ ] Test passes with `use_localstack=false` (if AWS accessible)
- [ ] LocalStack compatibility metadata added to file header
- [ ] AWS-only features properly marked with `condition = !var.use_localstack`
- [ ] Test uses fixtures from `tests/fixtures/` (no hardcoded values)
- [ ] Provider configuration block includes all required endpoints
- [ ] Assertions work in both modes (or conditionally skip)

### Test Execution Matrix

| Test Category | LocalStack | AWS | Notes |
|---------------|-----------|-----|-------|
| Lambda Basic | ✓ | ✓ | Full parity |
| Lambda Layers | ✓ | ✓ | Full parity |
| API Gateway REST | ✓ | ✓ | Minor URL format differences |
| S3 Notifications | ✓ | ✓ | Full parity |
| IAM Roles | ✓ | ✓ | Validation differs |
| IAM Boundaries | ✗ | ✓ | AWS-only test |
| DynamoDB Streams | ✓ | ✓ | Full parity (when implemented) |
| SQS Events | ✓ | ✓ | Full parity (when implemented) |
| EventBridge Simple | ✓ | ✓ | Basic schedules only |
| EventBridge Complex | ✗ | ✓ | AWS-only test |
| Route53 Basic | ✓ | ✓ | Basic records only |
| Route53 Routing | ✗ | ✓ | AWS-only test |

## Success Metrics

### Performance Targets

- **Test execution time reduction**: 80%+ faster with LocalStack vs AWS
  - Baseline (AWS): ~300 seconds for 20 tests
  - Target (LocalStack): ~60 seconds for 20 tests
- **LocalStack startup time**: < 30 seconds
- **Health check response time**: < 5 seconds after startup

### Coverage Goals

- **LocalStack test coverage**: 80%+ of all tests work with LocalStack
- **Dual-mode tests**: 100% of compatible tests support both modes
- **CI/CD integration**: 100% of PRs run LocalStack tests automatically

### Developer Experience Metrics

- **Setup time for new contributors**: < 5 minutes (vs ~30 minutes for AWS)
- **AWS costs eliminated**: $0/month for development testing (vs ~$50/month)
- **Feedback loop time**: < 2 minutes from push to test results (vs ~10 minutes)

### Quality Metrics

- **Test reliability**: 95%+ consistent pass rate in LocalStack
- **False positive rate**: < 5% (tests pass in LocalStack but fail in AWS)
- **False negative rate**: < 2% (tests fail in LocalStack but pass in AWS)

## Future Considerations

### Path to LocalStack Pro (If Needed)

If Community Edition limitations become blockers:

1. Evaluate specific Pro features needed (e.g., IAM policy enforcement, advanced EventBridge)
2. Cost-benefit analysis: Pro license cost vs AWS testing costs
3. Incremental adoption: Pro only for advanced tests
4. Configuration: Separate `docker-compose.localstack-pro.yml`

**Not recommended unless:**
- Community Edition blocks >20% of critical tests
- Team size grows significantly (Pro team licenses)
- Advanced features become core requirements

### Additional Service Support

As roadmap items are implemented:

**Short-term (Next 3 months):**
- EventBridge basic support (already in Community)
- DynamoDB streams (already in Community)
- SQS event sources (already in Community)

**Medium-term (3-6 months):**
- Route53 basic records (already in Community)
- CloudWatch Logs (for Lambda debugging)
- CloudWatch Events (alternative to EventBridge)

**Long-term (6+ months):**
- Step Functions (Community support)
- SNS (Community support)
- CloudFront (limited Community support)

### Enhanced LocalStack Features

**Potential improvements:**

1. **Persistence mode** for faster repeated test runs
   - Trade-off: State consistency vs speed
   - Use case: Local development only

2. **Lambda hot-reload** for faster iteration
   - Use LocalStack's code mounting features
   - Reduce package/deploy cycle time

3. **Snapshot testing** for complex configurations
   - Save LocalStack state after setup
   - Restore for faster test runs

4. **LocalStack configuration profiles**
   - Different service combinations for different test suites
   - Reduce startup time for focused testing

### Test Framework Evolution

**Potential enhancements:**

1. **Automatic LocalStack compatibility detection**
   - Analyze test code for used services
   - Auto-add compatibility metadata

2. **Diff reporting** between LocalStack and AWS results
   - Highlight behavioral differences
   - Track LocalStack accuracy over time

3. **Performance benchmarking**
   - Track test execution times
   - Identify slow tests for optimization

4. **Test isolation improvements**
   - Parallel test execution
   - Namespace isolation between tests

## Out of Scope

### Explicitly Excluded

1. **LocalStack Pro features**
   - Advanced IAM policy enforcement
   - Cloud Pods (state snapshots)
   - Chaos Engineering extensions
   - Analytics/Insights dashboards

2. **Full AWS behavior parity**
   - Accept minor differences in LocalStack behavior
   - Focus on functional correctness over exact matching
   - Document known differences rather than fixing

3. **Production-like performance testing**
   - LocalStack is for functional testing only
   - Load testing requires real AWS
   - Performance characteristics differ significantly

4. **Multi-region testing**
   - LocalStack Community uses single pseudo-region
   - Region-specific behavior not tested
   - Real AWS required for multi-region validation

5. **Custom LocalStack extensions**
   - No custom service implementations
   - No LocalStack plugin development
   - Stick to official Community Edition features

6. **100% test migration**
   - Some tests inherently require real AWS
   - Accept that 10-20% of tests may be AWS-only
   - Maintain separate test suites where needed

### Future Scope (Not Now)

1. **Integration with other testing frameworks**
   - Jest/Mocha for JavaScript validation
   - Pytest for Python Lambda functions
   - Focus on Terraform tests first

2. **LocalStack in production**
   - LocalStack is testing tool only
   - No deployment to LocalStack containers
   - Production always uses real AWS

3. **Automated AWS cost tracking**
   - Track savings from LocalStack adoption
   - Compare AWS costs before/after
   - Nice-to-have but not required

## Technical Constraints & Limitations

### LocalStack Community Limitations

1. **Service Coverage**
   - Not all AWS services supported
   - Some services have partial implementations
   - Pro features unavailable (accepted trade-off)

2. **Behavioral Differences**
   - IAM validation less strict
   - Error messages may differ
   - Timing/latency characteristics different

3. **Resource Limits**
   - No AWS account limits enforced
   - Quotas not simulated
   - May allow invalid configurations

### Terraform Compatibility

1. **Provider Configuration**
   - Endpoint override approach has limitations
   - Some resources may not support endpoint configuration
   - Requires testing each resource type

2. **State Management**
   - LocalStack resources create real Terraform state
   - State between LocalStack and AWS incompatible
   - Separate state files required

3. **Module Boundaries**
   - Module doesn't declare provider (expects from parent)
   - Tests must provide provider configuration
   - Consistent pattern required across all tests

### Developer Experience Constraints

1. **Docker Dependency**
   - Requires Docker installed and running
   - Platform-specific issues (Windows WSL, Mac permissions)
   - Network configuration challenges

2. **Learning Curve**
   - Developers must understand LocalStack limitations
   - Dual-mode testing adds complexity
   - Clear documentation essential

3. **Debugging Complexity**
   - LocalStack errors may not match AWS errors
   - Additional debugging layer
   - Logs must be easily accessible

## Dependencies & Prerequisites

### Required Software

- **Docker**: >= 20.10 (for LocalStack container)
- **Docker Compose**: >= 2.0 (for orchestration)
- **Terraform**: >= 1.6.0 (for test framework)
- **Make**: >= 4.0 (for automation targets)
- **curl**: For health checks
- **jq**: For JSON parsing in scripts (optional, recommended)

### Network Requirements

- **Port 4566**: LocalStack gateway (must be available)
- **Ports 4510-4559**: LocalStack external services (optional)
- **Internet access**: To pull LocalStack Docker image
- **No AWS credentials**: For LocalStack-only testing

### CI/CD Requirements

- **GitHub Actions**: runners with Docker support
- **AWS credentials**: For optional AWS testing (GitHub Secrets)
- **Sufficient runner resources**: 2 CPU, 4GB RAM minimum

## Risk Assessment & Mitigation

### Risk: LocalStack Behavioral Differences

**Impact**: High - Tests pass in LocalStack but fail in AWS

**Probability**: Medium

**Mitigation**:
- Maintain dual-mode testing capability
- Run AWS tests on main branch merges
- Document known differences
- Periodic AWS validation runs

### Risk: LocalStack Stability Issues

**Impact**: Medium - Flaky tests, false failures

**Probability**: Low-Medium

**Mitigation**:
- Pin LocalStack version in Docker Compose
- Implement retry logic for health checks
- Capture logs on failure
- Regular LocalStack version updates and testing

### Risk: Developer Confusion

**Impact**: Medium - Incorrect test writing, skipped validations

**Probability**: Medium

**Mitigation**:
- Comprehensive documentation
- Clear examples and templates
- Code review guidelines
- Training sessions

### Risk: CI/CD Pipeline Slowdown

**Impact**: Low - LocalStack startup adds time

**Probability**: Low

**Mitigation**:
- Cache LocalStack Docker image
- Optimize service loading (eager loading)
- Parallel test execution
- Benchmark and optimize

### Risk: Incomplete AWS Coverage

**Impact**: High - Production issues not caught in testing

**Probability**: Low

**Mitigation**:
- Maintain AWS test capability
- Regular AWS validation runs
- Document AWS-only scenarios
- Production monitoring and canary deployments

## Appendix A: LocalStack Service Endpoints

LocalStack Community Edition uses a single gateway endpoint for all services:

```
http://localhost:4566
```

**Service-specific endpoint examples:**

- Lambda: `http://localhost:4566` (API endpoint)
- API Gateway: `http://localhost:4566/restapis/` (Management API)
- S3: `http://localhost:4566` (with path-style access)
- IAM: `http://localhost:4566` (IAM API)
- DynamoDB: `http://localhost:4566` (DynamoDB API)
- SQS: `http://localhost:4566` (SQS API)
- EventBridge: `http://localhost:4566` (Events API)

**Note**: LocalStack routes all requests through port 4566 and uses request headers to determine the target service.

## Appendix B: Common LocalStack Issues & Solutions

### Issue: LocalStack Container Won't Start

**Symptoms**: `docker-compose up` fails or hangs

**Solutions**:
1. Check Docker daemon is running: `docker ps`
2. Check port 4566 is available: `lsof -i :4566`
3. Check Docker resources: Ensure 2+ GB RAM allocated
4. Clean up old containers: `make localstack-clean`

### Issue: Health Check Timeout

**Symptoms**: `make localstack-health` times out after 60s

**Solutions**:
1. Check LocalStack logs: `make localstack-logs`
2. Increase timeout in Makefile
3. Ensure internet connectivity (for image pull)
4. Restart Docker daemon

### Issue: S3 Path-Style Access Errors

**Symptoms**: S3 operations fail with 404

**Solutions**:
1. Ensure `s3_use_path_style = true` in provider config
2. Check bucket name format (no dots for virtual-hosted style)
3. Verify LocalStack S3 service is available: `curl http://localhost:4566/_localstack/health`

### Issue: Lambda Invocation Fails

**Symptoms**: Lambda functions created but invocation fails

**Solutions**:
1. Check Lambda executor mode: `LAMBDA_EXECUTOR=docker-reuse`
2. Ensure Docker socket mounted: `/var/run/docker.sock`
3. Check function code packaging (must be valid zip)
4. Review LocalStack logs for errors

### Issue: IAM Policy Validation Errors

**Symptoms**: IAM policies accepted in LocalStack but fail in AWS

**Solutions**:
1. Use conditional assertions: `var.use_localstack || <strict_check>`
2. Mark test as AWS-only: `condition = !var.use_localstack`
3. Document IAM validation differences
4. Test IAM policies in AWS before production

## Appendix C: Test Writing Checklist

Use this checklist when creating new dual-mode tests:

**Setup:**
- [ ] Provider block includes LocalStack endpoint configuration
- [ ] Provider block includes `skip_credentials_validation` flag
- [ ] Provider block includes `s3_use_path_style` flag
- [ ] Variables section includes `use_localstack` and `localstack_endpoint`

**Test Logic:**
- [ ] Test uses fixtures from `tests/fixtures/` directory
- [ ] Test assertions work with both LocalStack and AWS
- [ ] Conditional assertions for LocalStack limitations documented
- [ ] Test marked as AWS-only if LocalStack incompatible

**Documentation:**
- [ ] File header includes LocalStack compatibility level (FULL/PARTIAL/NONE)
- [ ] Comments explain any LocalStack-specific behavior
- [ ] Known limitations documented in test comments

**Validation:**
- [ ] Test passes with `use_localstack=true`
- [ ] Test passes with `use_localstack=false` (if AWS accessible)
- [ ] Test name clearly describes what is being tested
- [ ] Error messages are clear and actionable

## Appendix D: Variable Reference

**Module Variables:**

```hcl
variable "use_localstack" {
  description = "Enable LocalStack mode for testing"
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

variable "config_path" {
  description = "Path to Serverless configuration file"
  type        = string
}

variable "config_format" {
  description = "Configuration format (yaml or typescript)"
  type        = string
  default     = "yaml"
}

variable "aws_region" {
  description = "AWS region override"
  type        = string
  default     = null
}

variable "lambda_code_path" {
  description = "Path to Lambda function code"
  type        = string
  default     = "."
}
```

**Test Override Examples:**

```bash
# Run tests with LocalStack
terraform test -var="use_localstack=true"

# Run tests with AWS
terraform test -var="use_localstack=false"

# Use custom LocalStack endpoint
terraform test -var="use_localstack=true" -var="localstack_endpoint=http://192.168.1.100:4566"

# Run specific test with LocalStack
terraform test -filter="lambda_basic" -var="use_localstack=true"
```

## Appendix E: Make Target Reference

| Target | Description | Prerequisites |
|--------|-------------|---------------|
| `localstack-start` | Start LocalStack container | Docker running |
| `localstack-stop` | Stop LocalStack container | - |
| `localstack-restart` | Restart LocalStack | - |
| `localstack-status` | Show container status | - |
| `localstack-logs` | Tail container logs | LocalStack running |
| `localstack-health` | Check health endpoints | LocalStack running |
| `localstack-clean` | Remove all LocalStack data | - |
| `test-local` | Run tests with LocalStack | LocalStack started |
| `test-aws` | Run tests with AWS | AWS credentials |
| `test-all` | Run LocalStack tests (default) | Docker running |

**Example workflows:**

```bash
# Quick test run
make test-local

# Full development cycle
make localstack-start
# ... make code changes ...
terraform test -var="use_localstack=true"
make localstack-logs  # if issues
make localstack-stop

# Clean restart
make localstack-clean
make localstack-start
make test-local
```
