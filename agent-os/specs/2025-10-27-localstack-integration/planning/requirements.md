# LocalStack Integration Requirements

## Overview
Implement LocalStack integration to enable local testing of Terraform infrastructure creation without requiring real AWS resources.

## Requirements Gathered

### 1. LocalStack Service Scope
**Decision**: Include support for current services AND pre-emptive support for roadmap services.

**Services to Support**:
- **Currently Implemented**: Lambda, API Gateway, IAM, S3
- **Roadmap Services**: EventBridge, DynamoDB streams, SQS event sources, Custom Resources, Route53/Custom Domains

**Note**: Where partial support exists (like EventBridge), we should simplify the approach to allow some value from LocalStack while accepting reduced accuracy compared to real AWS.

### 2. Integration Approach
**Decision**: Open to suggestions - to be determined during spec writing.

**Options to Consider**:
- Opt-in via test variable (e.g., `use_localstack = true`)
- Separate `.localstack.tftest.hcl` test files
- Environment variable-based provider overrides
- Hybrid approach combining multiple strategies

### 3. LocalStack Lifecycle Management
**Decision**: Include Make targets for LocalStack lifecycle management.

**Requirements**:
- Provide Make targets for starting/stopping LocalStack
- Support Docker-based LocalStack deployment
- Handle LocalStack health checks and readiness
- Provide clear documentation for developers

### 4. Test Fixture Strategy
**Decision**: Reuse existing test fixtures in `tests/fixtures/*.yml`.

**Benefits**:
- Ensures parity between real AWS and LocalStack behavior
- Reduces maintenance burden
- Validates that LocalStack accurately simulates AWS services
- Single source of truth for test scenarios

### 5. CI/CD Integration
**Decision**: LocalStack tests mandatory for all PRs; real AWS tests optional or on specific branches.

**Requirements**:
- LocalStack tests run automatically in CI/CD pipeline
- Fast feedback loop for developers
- Real AWS tests can run on release branches or manually
- No AWS costs for standard PR validation

### 6. Configuration Management
**Decision**: Manage LocalStack endpoint configuration via Terraform variables in test files.

**Approach**:
- Test files should accept variables for endpoint URLs
- Clean separation between LocalStack and real AWS configuration
- Easy toggle between environments
- No environment variable pollution

### 7. LocalStack Version & Features
**Decision**: Target LocalStack Community Edition.

**Community Edition Services**:
- Lambda ✓
- API Gateway ✓
- S3 ✓
- IAM ✓
- EventBridge ✓ (partial support - simplify approach)
- DynamoDB ✓
- SQS ✓
- Route53 ✓

**Handling Partial Support**:
- For services with partial support (e.g., EventBridge), simplify test scenarios
- Accept reduced accuracy compared to real AWS
- Document limitations clearly
- Focus on core functionality validation

### 8. Test Coverage Philosophy
**Decision**: Tests should work with both LocalStack and real AWS via a toggle where possible.

**Approach**:
- Dual-mode tests: same test runs against LocalStack OR real AWS
- Toggle mechanism to switch between environments
- Handle LocalStack limitations cleanly (skip unsupported scenarios)
- Graceful degradation for partial support services
- Clear documentation of LocalStack-incompatible tests

**Exception Handling**:
- Some tests will be LocalStack-only (fast iteration tests)
- Some tests will be AWS-only (features LocalStack can't support)
- Mark tests appropriately with metadata/comments

### 9. Scope Exclusions
**Decision**: Exclude LocalStack Pro-only features.

**Explicitly Excluded**:
- LocalStack Pro features
- Custom LocalStack extensions
- Advanced Pro-only service emulations
- Commercial/proprietary integrations

**Included in Scope**:
- All Community Edition services
- Open-source LocalStack features
- Standard AWS service emulation

## Technical Constraints

### LocalStack Community Limitations
- Some AWS services have partial or limited support
- Behavior may not match AWS 100% (acceptable trade-off)
- Advanced features may require Pro (will not implement)

### Terraform Compatibility
- Must work with existing Terraform test framework (`terraform test`)
- Must not break existing real AWS tests
- Should integrate cleanly with current test structure

### Developer Experience
- Easy to set up and run locally
- Fast feedback cycle
- Clear documentation
- Minimal friction for new contributors

## Success Criteria

1. ✅ LocalStack can be started/stopped via Make targets
2. ✅ All existing tests can run against LocalStack (where supported)
3. ✅ Tests can toggle between LocalStack and real AWS
4. ✅ CI/CD pipeline runs LocalStack tests automatically
5. ✅ LocalStack limitations documented clearly
6. ✅ Developer documentation for local setup
7. ✅ No AWS costs for standard development workflow
8. ✅ Test execution time significantly reduced with LocalStack

## Out of Scope

- LocalStack Pro features
- Custom LocalStack plugins/extensions
- 100% AWS behavior parity (best-effort with Community Edition)
- Migration of all existing tests (will handle incompatibilities gracefully)
- Support for non-AWS providers

## Next Steps

After spec writing:
1. Design provider configuration strategy (toggle mechanism)
2. Create Make targets for LocalStack lifecycle
3. Implement test framework enhancements
4. Update CI/CD pipeline
5. Document LocalStack setup and usage
6. Create example tests demonstrating dual-mode approach
