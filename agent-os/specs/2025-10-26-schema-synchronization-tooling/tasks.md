# Task Breakdown: Schema Synchronization Tooling

## Overview

**Feature:** Automated tooling to generate Terraform validation code from Serverless Framework JSON schemas
**Roadmap Item:** 13 (Medium)
**Estimated Duration:** 7-9 days
**Total Task Groups:** 7

## Task List

### Phase 1: Foundation and Schema Management

#### Task Group 1: Project Setup and Schema Vendoring
**Dependencies:** None
**Estimated Duration:** 0.5-1 day

- [ ] 1.0 Set up schema generator project foundation
  - [ ] 1.1 Create `tools/schema-generator/` directory structure
    - Create subdirectories: `src/`, `templates/`, `tests/`, `bin/`
    - Set up proper directory permissions
  - [ ] 1.2 Initialize package.json with project metadata
    - Name: `@sls-tf/schema-generator`
    - Version: `0.1.0`
    - Node.js version requirement: `>=14.0.0`
    - Add bin entry pointing to CLI entrypoint
  - [ ] 1.3 Install core dependencies
    - `handlebars` - template engine for HCL generation
    - `@json-schema-tools/dereferencer` - JSON Schema Draft normalization
    - `yargs` - CLI argument parsing
    - `chalk` - colored terminal output
    - `ajv` - JSON Schema validation
  - [ ] 1.4 Install development dependencies
    - `jest` - testing framework
    - `@types/node` - TypeScript definitions
    - `eslint` - linting
    - `prettier` - code formatting
  - [ ] 1.5 Create schemas directory structure
    - Create `schemas/serverless-framework/` at repository root
    - Add `.gitkeep` or initial README explaining purpose
  - [ ] 1.6 Vendor Serverless Framework JSON schemas
    - Download schema for v2.x from Serverless Framework repository
    - Download schema for v3.x from Serverless Framework repository
    - Download schema for v4.x from Serverless Framework repository
    - Save as: `v2.x.json`, `v3.x.json`, `v4.x.json`
    - Document source URLs and dates in `schemas/serverless-framework/README.md`
  - [ ] 1.7 Write 2-8 focused tests for schema loading
    - Test: Schema files exist and are valid JSON
    - Test: Schemas conform to JSON Schema Draft 7 spec
    - Test: Required schema properties are present (e.g., $schema, properties)
    - Skip: Exhaustive schema content validation
  - [ ] 1.8 Create basic CLI scaffolding
    - Create `bin/schema-generator.js` as entrypoint
    - Set up shebang and executable permissions
    - Add basic argument parsing structure with yargs
    - Implement `--help` and `--version` flags
  - [ ] 1.9 Ensure foundation tests pass
    - Run ONLY the 2-8 tests written in 1.7
    - Verify CLI can be invoked with `--help`
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.7 pass
- Directory structure follows Node.js project conventions
- All three schema files are vendored and valid JSON Schema Draft 7
- CLI can be invoked and displays help text
- Dependencies are properly installed and locked

---

### Phase 2: Core Schema Processing Engine

#### Task Group 2: Schema Parsing and Constraint Extraction
**Dependencies:** Task Group 1
**Estimated Duration:** 1.5-2 days

- [ ] 2.0 Implement schema parsing and constraint extraction
  - [ ] 2.1 Write 2-8 focused tests for schema processing
    - Test: Schema normalization from Draft 4/6 to Draft 7
    - Test: Extraction of required fields from schema
    - Test: Extraction of enum constraints
    - Test: Extraction of type constraints
    - Skip: Exhaustive testing of all schema features
  - [ ] 2.2 Create schema normalization module
    - File: `src/schema-normalizer.js`
    - Implement Draft 4 to Draft 7 conversion
    - Implement Draft 6 to Draft 7 conversion
    - Use `@json-schema-tools/dereferencer` for $ref resolution
    - Handle missing $schema field gracefully (default to Draft 7)
  - [ ] 2.3 Create schema loader module
    - File: `src/schema-loader.js`
    - Load schema file from path
    - Validate JSON syntax with clear error messages
    - Apply normalization pipeline
    - Cache normalized schemas for performance
  - [ ] 2.4 Create constraint extraction module
    - File: `src/constraint-extractor.js`
    - Extract `required` fields from schema properties
    - Extract `type` constraints (string, number, boolean, object, array)
    - Extract `enum` values for enumerated fields
    - Extract `pattern` regex for string validation
    - Extract `minimum`/`maximum` for number ranges
    - Extract conditional requirements (if/then/else, dependencies)
  - [ ] 2.5 Create configuration file loader
    - File: `src/config-loader.js`
    - Load `tools/schema-generator/config.yml`
    - Parse `included_paths` and `excluded_paths` arrays
    - Validate configuration structure
    - Provide defaults if config file missing
  - [ ] 2.6 Implement schema path filtering
    - File: `src/path-filter.js`
    - Filter schema based on included_paths allowlist
    - Remove schema sections matching excluded_paths
    - Support glob patterns in paths (e.g., `/properties/functions/*`)
    - Preserve schema structure after filtering
  - [ ] 2.7 Ensure schema processing tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify constraint extraction works for sample schemas
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- Schema normalization handles Draft 4, 6, and 7 formats
- Constraint extractor identifies all major constraint types
- Configuration-based path filtering works correctly
- Error messages are clear and actionable

---

### Phase 3: Template Engine and HCL Generation

#### Task Group 3: Handlebars Templates and Code Generation
**Dependencies:** Task Group 2
**Estimated Duration:** 1.5-2 days

- [ ] 3.0 Build template system and HCL code generation
  - [ ] 3.1 Write 2-8 focused tests for template rendering
    - Test: Required field validation generates correct HCL
    - Test: Enum constraint generates correct validation expression
    - Test: Type constraint generates correct can() check
    - Test: Error messages include schema paths
    - Skip: Testing all possible schema constraint combinations
  - [ ] 3.2 Create Handlebars template for validation blocks
    - File: `templates/validation-block.hbs`
    - Template structure: Terraform locals block with validation_errors list
    - Use `concat()` for aggregating validation errors
    - Use conditional expression: `condition ? ["error"] : []`
    - Include schema path in error messages
  - [ ] 3.3 Create Handlebars template for required field validation
    - File: `templates/required-field.hbs`
    - Generate: `try(local.parsed_config.{{path}}, null) != null`
    - Error message: "Required field '{{field}}' is missing"
    - Include schema path reference
  - [ ] 3.4 Create Handlebars template for type validation
    - File: `templates/type-validation.hbs`
    - Generate `can(tobool(...))`, `can(tonumber(...))` checks
    - Handle complex types: object (can(keys(...))), array (can(length(...)))
    - Error message: "Field '{{field}}' must be {{type}}, got: ${type(...)}"
  - [ ] 3.5 Create Handlebars template for enum validation
    - File: `templates/enum-validation.hbs`
    - Generate: `contains([{{enumValues}}], local.parsed_config.{{path}})`
    - Error message: "Invalid {{field}}. Must be one of: {{enumValues}}"
    - Include common fix suggestions for known typos
  - [ ] 3.6 Create Handlebars template for pattern validation
    - File: `templates/pattern-validation.hbs`
    - Generate: `can(regex("{{pattern}}", local.parsed_config.{{path}}))`
    - Error message: "Field '{{field}}' does not match required pattern: {{pattern}}"
  - [ ] 3.7 Create Handlebars template for range validation
    - File: `templates/range-validation.hbs`
    - Generate minimum/maximum checks for numbers
    - Error message: "{{field}} must be between {{min}} and {{max}}"
  - [ ] 3.8 Create file header template with metadata
    - File: `templates/file-header.hbs`
    - Include: "AUTO-GENERATED FILE - DO NOT EDIT" warning
    - Include: Generator version, schema version, timestamp
    - Include: Regeneration command
  - [ ] 3.9 Create code generation orchestrator
    - File: `src/code-generator.js`
    - Map extracted constraints to appropriate templates
    - Render templates with constraint data
    - Combine rendered blocks into complete HCL file
    - Apply terraform fmt formatting to output
  - [ ] 3.10 Implement version-specific file generation
    - Generate `generated/validation-v2.tf` for v2.x constraints
    - Generate `generated/validation-v3.tf` for v3.x constraints
    - Generate `generated/validation-v4.tf` for v4.x constraints
    - Generate `generated/validation-common.tf` for shared constraints
  - [ ] 3.11 Ensure template rendering tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify generated HCL is syntactically valid
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- Templates generate valid Terraform HCL syntax
- Generated code follows terraform fmt conventions
- Error messages include schema paths and suggestions
- Auto-generation headers are present and informative

---

### Phase 4: CLI Integration and Configuration

#### Task Group 4: CLI Implementation and User Interface
**Dependencies:** Task Group 3
**Estimated Duration:** 1 day

- [ ] 4.0 Complete CLI tool implementation
  - [ ] 4.1 Write 2-8 focused tests for CLI functionality
    - Test: CLI accepts --schema-version argument
    - Test: CLI accepts --output-dir argument
    - Test: CLI generates files in correct output directory
    - Test: CLI exits with error code on failure
    - Skip: Testing all CLI argument combinations
  - [ ] 4.2 Implement command-line argument handling
    - File: `src/cli.js`
    - Argument: `--schema-version <version>` (required, choices: 2, 3, 4, all)
    - Argument: `--output-dir <path>` (optional, default: `generated/`)
    - Argument: `--config <path>` (optional, default: `tools/schema-generator/config.yml`)
    - Argument: `--full` (flag, generate all schema paths ignoring config)
    - Validate argument combinations
  - [ ] 4.3 Create default configuration file
    - File: `tools/schema-generator/config.yml`
    - Include paths: `/properties/service`, `/properties/provider`, `/properties/functions`
    - Exclude paths: `/properties/plugins`, `/properties/package`
    - Document configuration format with comments
  - [ ] 4.4 Implement CLI execution flow
    - Load configuration from file or use defaults
    - Load schema(s) based on --schema-version
    - Apply path filtering from configuration (unless --full flag)
    - Extract constraints from filtered schema
    - Generate HCL files for each version
    - Write output files to --output-dir
    - Display summary of generated files
  - [ ] 4.5 Add colored output and progress indicators
    - Use chalk for colored success/error messages
    - Display: "Loading schema v3.x..." with spinner
    - Display: "Generated validation-v3.tf (42 validation rules)"
    - Display: "Completed in 1.2s"
  - [ ] 4.6 Implement error handling and reporting
    - Catch schema loading errors with helpful messages
    - Catch template rendering errors with context
    - Catch file writing errors with permissions guidance
    - Exit with appropriate exit codes (0 = success, 1 = error)
  - [ ] 4.7 Create npm script shortcuts
    - Add to root `package.json`: `"generate:validation": "node tools/schema-generator/bin/schema-generator.js"`
    - Add script: `"generate:validation:v2": "npm run generate:validation -- --schema-version=2"`
    - Add script: `"generate:validation:v3": "npm run generate:validation -- --schema-version=3"`
    - Add script: `"generate:validation:v4": "npm run generate:validation -- --schema-version=4"`
    - Add script: `"generate:validation:all": "npm run generate:validation -- --schema-version=all"`
  - [ ] 4.8 Ensure CLI functionality tests pass
    - Run ONLY the 2-8 tests written in 4.1
    - Verify CLI generates expected output files
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.1 pass
- CLI accepts and validates all required arguments
- Configuration file format is documented and works
- Generated files are written to correct output directory
- Error messages are clear and actionable
- npm scripts provide convenient shortcuts

---

### Phase 5: Initial Validation Generation

#### Task Group 5: Generate and Integrate Validation Code
**Dependencies:** Task Group 4
**Estimated Duration:** 1 day

- [ ] 5.0 Generate initial validation files and integrate with module
  - [ ] 5.1 Create `generated/` directory at repository root
    - Add `.gitkeep` or README explaining auto-generated content
    - Add note: "Files in this directory are auto-generated. Do not edit manually."
  - [ ] 5.2 Run generator for all supported versions
    - Execute: `npm run generate:validation:all`
    - Verify files created: `validation-v2.tf`, `validation-v3.tf`, `validation-v4.tf`, `validation-common.tf`
    - Review generated HCL for correctness
  - [ ] 5.3 Verify generated code syntax
    - Run `terraform fmt -check generated/validation-*.tf`
    - Fix any formatting issues in templates
    - Regenerate if needed
  - [ ] 5.4 Review generated validation rules
    - Manually inspect validation for service, provider, functions
    - Verify error messages are clear and helpful
    - Verify schema paths are correctly referenced
    - Check for any obvious issues or missing validations
  - [ ] 5.5 Create version detection logic guidance
    - Document in `generated/README.md`: How to detect Serverless Framework version
    - Example: `try(local.parsed_config.frameworkVersion, "3")`
    - Document conditional loading pattern for version-specific files
  - [ ] 5.6 Test generated validation against existing fixtures
    - Create test fixture: `tests/fixtures/valid-serverless.yml`
    - Create test fixture: `tests/fixtures/invalid-runtime.yml` (invalid enum)
    - Create test fixture: `tests/fixtures/missing-service.yml` (required field)
    - Run validation logic manually to verify behavior
  - [ ] 5.7 Commit generated files to version control
    - Add all generated files to git
    - Commit with message: "Generate initial schema validation for v2.x, v3.x, v4.x"
    - Include generator version and schema versions in commit message

**Acceptance Criteria:**
- All four validation files are generated successfully
- Generated HCL passes `terraform fmt -check`
- Validation rules correctly identify invalid configurations
- Test fixtures demonstrate validation behavior
- Generated files are committed to version control

---

### Phase 6: CI/CD Integration and Automation

#### Task Group 6: Automated Schema Updates and Drift Detection
**Dependencies:** Task Group 5
**Estimated Duration:** 1 day

- [ ] 6.0 Set up CI/CD workflows for schema management
  - [ ] 6.1 Write 2-8 focused tests for CI/CD scripts
    - Test: Drift detection identifies manual edits to generated files
    - Test: Schema update detection compares file hashes
    - Skip: Full integration testing of GitHub Actions workflows
  - [ ] 6.2 Create drift detection workflow
    - File: `.github/workflows/validate-generated-code.yml`
    - Trigger: On pull_request and push to main
    - Steps:
      1. Checkout code
      2. Set up Node.js environment
      3. Install dependencies in tools/schema-generator
      4. Run `npm run generate:validation:all`
      5. Check for git diff in generated/ directory
      6. Fail if differences detected with message: "Generated files are out of sync. Run 'npm run generate:validation:all' and commit changes."
  - [ ] 6.3 Create schema update detection workflow
    - File: `.github/workflows/schema-update.yml`
    - Trigger: Weekly cron (every Monday at 9 AM UTC)
    - Trigger: Manual workflow_dispatch
    - Steps:
      1. Checkout code
      2. Fetch latest Serverless Framework releases from GitHub API
      3. Download schemas for latest v2.x, v3.x, v4.x releases
      4. Compare SHA-256 hashes with vendored schemas
      5. If changes detected:
         - Update vendored schemas
         - Regenerate validation files
         - Create pull request with changes
         - Include schema diff in PR description
  - [ ] 6.4 Create schema update PR template
    - File: `.github/pull_request_template_schema_update.md`
    - Include: Schema version updates (old → new)
    - Include: List of changed validation rules
    - Include: Checklist for reviewer (verify tests pass, review breaking changes)
  - [ ] 6.5 Add CI validation performance check
    - Add step to drift detection workflow
    - Time generator execution
    - Fail if generation takes > 10 seconds (performance regression)
  - [ ] 6.6 Create maintenance documentation
    - File: `tools/schema-generator/MAINTENANCE.md`
    - Document: How to manually update schemas
    - Document: How to regenerate validation files
    - Document: How to review schema update PRs
    - Document: How to add new schema paths to config
  - [ ] 6.7 Ensure CI/CD tests pass
    - Run ONLY the 2-8 tests written in 6.1
    - Verify drift detection logic works locally
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 6.1 pass
- Drift detection workflow fails when generated files are manually edited
- Schema update workflow can be triggered manually
- Weekly cron job is configured correctly
- Maintenance documentation is complete and clear

---

### Phase 7: Testing, Documentation, and Quality Assurance

#### Task Group 7: Comprehensive Testing and Documentation
**Dependencies:** Task Groups 1-6
**Estimated Duration:** 1.5-2 days

- [ ] 7.0 Complete testing suite and documentation
  - [ ] 7.1 Review existing tests and identify critical gaps
    - Review the 2-8 tests from Task 1.7 (schema loading)
    - Review the 2-8 tests from Task 2.1 (schema processing)
    - Review the 2-8 tests from Task 3.1 (template rendering)
    - Review the 2-8 tests from Task 4.1 (CLI functionality)
    - Review the 2-8 tests from Task 6.1 (CI/CD scripts)
    - Total existing tests: approximately 10-40 tests
    - Identify gaps in critical workflows:
      - End-to-end generation from schema to HCL file
      - Integration with actual Serverless Framework schemas
      - Error handling for malformed schemas
  - [ ] 7.2 Write up to 10 additional strategic tests maximum
    - Test: Full pipeline from schema load to file output (integration test)
    - Test: Generated validation correctly rejects invalid serverless.yml
    - Test: Generated validation correctly accepts valid serverless.yml
    - Test: Error handling for corrupted schema file
    - Test: Configuration file with complex path patterns
    - Test: Version-specific constraint differences (v2 vs v3 vs v4)
    - Focus on integration workflows, not unit test coverage
  - [ ] 7.3 Implement golden file testing
    - Create `tests/golden/` directory
    - Generate baseline outputs for each schema version
    - Add test: Compare generator output against golden files
    - Update golden files only when schema or templates change intentionally
  - [ ] 7.4 Create schema coverage report
    - Script: `tools/schema-generator/scripts/coverage-report.js`
    - Analyze: Which schema paths have generated validation
    - Analyze: Which schema paths are excluded by config
    - Output: Markdown report showing coverage status
  - [ ] 7.5 Write generator usage documentation
    - File: `tools/schema-generator/README.md`
    - Section: Installation and setup
    - Section: CLI usage examples
    - Section: Configuration file format
    - Section: Adding new schema paths
    - Section: Template customization
    - Section: Troubleshooting common issues
  - [ ] 7.6 Write contribution guide for generated code
    - File: `docs/CONTRIBUTING-GENERATED-CODE.md`
    - Explain: Which files are generated vs. hand-written
    - Explain: When to edit templates vs. add manual validation
    - Explain: How to update schema generator config
    - Explain: How to test changes to generator
  - [ ] 7.7 Create integration guide for module users
    - File: `docs/VALIDATION.md`
    - Explain: How validation works in the module
    - Explain: How to interpret validation errors
    - Explain: Common validation failures and fixes
    - Include: Examples of error messages with explanations
  - [ ] 7.8 Add inline code documentation
    - Add JSDoc comments to all public functions
    - Document parameters, return values, exceptions
    - Add usage examples in JSDoc
  - [ ] 7.9 Run full test suite for schema generator
    - Execute: `npm test` in tools/schema-generator/
    - Expected: Approximately 20-50 total tests pass
    - Verify all critical workflows are covered
    - Do NOT expand test coverage beyond critical paths
  - [ ] 7.10 Verify performance targets
    - Test: Generator completes full schema processing in < 5 seconds
    - Test: Generated validation overhead < 100ms for typical serverless.yml
    - Test: CI validation check completes in < 30 seconds
    - Document performance benchmarks

**Acceptance Criteria:**
- Total test count is approximately 20-50 tests (not thousands)
- All critical workflows have test coverage
- Golden file tests ensure reproducible output
- Documentation is complete, clear, and accurate
- Performance targets are met and verified
- Contribution guide explains generated vs. hand-written code

---

## Execution Order

**Recommended implementation sequence:**

1. **Phase 1: Foundation** (Task Group 1) - 0.5-1 day
   - Set up project structure, vendor schemas, create basic CLI

2. **Phase 2: Core Engine** (Task Group 2) - 1.5-2 days
   - Build schema parsing, normalization, and constraint extraction

3. **Phase 3: Code Generation** (Task Group 3) - 1.5-2 days
   - Create Handlebars templates and HCL generation logic

4. **Phase 4: CLI** (Task Group 4) - 1 day
   - Implement complete CLI with arguments and configuration

5. **Phase 5: Initial Generation** (Task Group 5) - 1 day
   - Generate validation files and verify integration

6. **Phase 6: CI/CD** (Task Group 6) - 1 day
   - Set up automation for drift detection and schema updates

7. **Phase 7: Testing & Docs** (Task Group 7) - 1.5-2 days
   - Add strategic tests, create documentation, verify quality

**Total Estimated Duration:** 7-9 days

---

## Implementation Notes

### Testing Philosophy
This feature follows a focused testing approach:
- Each development phase writes 2-8 targeted tests for critical functionality
- Tests focus on workflows, not exhaustive coverage
- Final testing phase adds maximum 10 strategic integration tests
- Total expected test count: 20-50 tests (not hundreds)
- Golden file testing ensures reproducible output

### Technology Stack Alignment
- **Node.js 14+** - Aligns with existing TypeScript parsing dependencies
- **Handlebars** - Template engine for HCL generation
- **JSON Schema Draft 7** - Standard for schema validation
- **Terraform 1.0+** - Target validation syntax

### Code Organization
- **Generated code:** Lives in `generated/` directory, marked with "DO NOT EDIT" headers
- **Hand-written code:** Lives in standard module structure (variables.tf, locals.tf, main.tf)
- **Clear separation:** CI/CD enforces through drift detection

### Version Support Strategy
- Support Serverless Framework versions: 2.x, 3.x, 4.x
- Version-specific files: `validation-v2.tf`, `validation-v3.tf`, `validation-v4.tf`
- Common validation: `validation-common.tf` for shared rules
- Version detection: Based on `frameworkVersion` field in parsed config

### Incremental Coverage Approach
- Start with core properties: service, provider, functions
- Expand coverage as roadmap features are implemented
- Configuration file controls which schema paths are validated
- Avoids validation noise for unimplemented features

### Performance Targets
- Generator execution: < 5 seconds for full schema processing
- Validation overhead: < 100ms for typical serverless.yml (< 50 functions)
- CI validation check: < 30 seconds total

### Error Message Quality
Every generated validation error must include:
1. Clear description of what's wrong
2. Expected vs. actual value comparison
3. JSON schema path reference (e.g., `#/properties/provider/properties/runtime`)
4. Common fix suggestion when applicable
5. Link to relevant Serverless Framework documentation

### Integration with Existing Module
- Generated validation extends existing `local.validation_errors` pattern
- Complements existing manual validations, doesn't replace them
- Follows same error aggregation approach using `concat()`
- Maintains consistent error message formatting

---

## Success Metrics

### Functional Completeness
- [ ] Generator processes all three schema versions (2.x, 3.x, 4.x)
- [ ] Generated HCL files pass `terraform fmt -check`
- [ ] Version-specific validations correctly distinguish between versions
- [ ] Configuration-based path filtering works as expected
- [ ] Weekly schema update detection workflow runs successfully

### Quality Assurance
- [ ] All strategic tests pass (approximately 20-50 tests)
- [ ] Golden file tests ensure reproducible output
- [ ] Generated validation correctly identifies invalid configurations
- [ ] Error messages include schema paths and helpful suggestions
- [ ] CI drift detection prevents manual edits to generated files

### Performance
- [ ] Generator completes in < 5 seconds
- [ ] Validation overhead < 100ms for typical configurations
- [ ] CI validation check completes in < 30 seconds

### Documentation
- [ ] Generator usage documented with examples
- [ ] Contribution guide explains generated vs. hand-written code distinction
- [ ] Schema update workflow documented for maintainers
- [ ] Error message documentation helps users resolve issues
- [ ] All public functions have JSDoc comments

### Integration Success
- [ ] Generated validation integrates seamlessly with existing locals.tf validation pattern
- [ ] Test fixtures demonstrate both passing and failing validation
- [ ] npm scripts provide convenient regeneration workflow
- [ ] CI/CD prevents validation drift and detects schema updates
