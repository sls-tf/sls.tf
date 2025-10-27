# Specification: Schema Synchronization Tooling

## Goal

Develop automated tooling to generate Terraform validation code from Serverless Framework JSON schemas, ensuring validation rules stay synchronized with schema evolution across Framework versions 2.x, 3.x, and 4.x, eliminating manual validation maintenance and preventing drift between schema definitions and Terraform validation logic.

## User Stories

- As a module maintainer, I need automated schema synchronization so that validation rules automatically stay aligned with Serverless Framework updates without manual code changes, reducing maintenance burden and preventing validation drift
- As a module maintainer, I need version-specific validation generation so that users on different Serverless Framework versions (2.x, 3.x, 4.x) receive appropriate validation errors based on their version's schema
- As a developer using sls.tf, when my serverless.yml has a validation error, I need clear error messages that explain what's wrong, reference the schema constraint, and suggest how to fix it
- As a module maintainer implementing roadmap features incrementally, I need to generate validation only for implemented features so that users don't receive validation errors for unimplemented functionality
- As a contributor, I need clear separation between generated and hand-written code so that I know which files are safe to edit and which should be regenerated
- As a module maintainer, I need comprehensive tests for the schema generator and generated validation code so that I can confidently update schemas without introducing regressions

## Core Requirements

### Schema Management
- Vendor Serverless Framework JSON schemas for versions 2.x, 3.x, and 4.x in `schemas/serverless-framework/` directory
- Support JSON Schema Draft 7 format with automatic normalization from older drafts (Draft 4, Draft 6)
- Implement CI/CD workflow for weekly schema update detection and PR creation
- Organize schemas by major version with clear naming (e.g., `v2.x.json`, `v3.38.0.json`)

### Code Generator CLI Tool
- Develop Node.js-based CLI tool in `tools/schema-generator/` directory
- Support command-line arguments: `--schema-version`, `--output-dir`, `--config`, `--full`
- Parse JSON Schema files and extract validation constraints (required fields, types, enums, patterns, ranges)
- Generate Terraform HCL validation code using Handlebars templates
- Support incremental generation based on configuration file allowlist/blocklist
- Output version-specific validation files: `generated/validation-v2.tf`, `generated/validation-v3.tf`, `generated/validation-v4.tf`, `generated/validation-common.tf`

### Terraform Validation Code Generation
- Generate validation expressions within `locals` blocks for post-parse schema validation
- Generate custom validation functions using `can()`, `try()`, and conditional expressions for complex rules
- Include detailed error messages with schema paths, expected values, and fix suggestions
- Include documentation comments explaining each validation rule and its source schema
- Add auto-generation header comments with tool version, schema version, and timestamp
- Ensure generated code is terraform fmt compatible

### Multi-Version Support
- Detect Serverless Framework version from parsed configuration (via frameworkVersion field)
- Conditionally load version-specific validation file based on detected version
- Support version override via explicit configuration variable
- Maintain backward compatibility for older schema versions within supported range
- Clearly separate version-specific validation from common validation rules

### Validation Coverage
- Validate top-level required fields: service, provider, functions
- Validate field types: string, number, boolean, object, array
- Validate enum constraints: runtime values, event types, AWS regions
- Validate pattern matching: naming conventions, ARN formats, version strings
- Validate range constraints: memory limits (128-10240 MB), timeout bounds (1-900 seconds)
- Validate conditional requirements: fields required based on other field values
- Allow unknown properties to support Serverless Framework plugins (permissive approach)

### Error Messaging Standards
- Include JSON schema path reference in each error message (e.g., `#/properties/provider/properties/runtime`)
- Provide expected vs. actual value comparison
- Suggest common fixes for frequent mistakes (e.g., runtime version typos)
- Link to relevant Serverless Framework documentation
- Format errors consistently with existing validation error patterns in locals.tf

### Build and CI/CD Integration
- Manual validation generation via `npm run generate:validation` when schemas are updated
- Generated files committed to version control
- CI/CD validates that generated files are up-to-date by re-running generator and checking for diffs
- Weekly cron job to check Serverless Framework releases and create PRs when schema changes detected
- No pre-commit hooks (too slow)
- No runtime generation (keeps terraform apply fast and deterministic)

## Visual Design

Not applicable - this is a code generation and validation tooling feature without visual components.

## Reusable Components

### Existing Code to Leverage

**Validation Patterns in locals.tf:**
- Validation error collection pattern using `concat()` for aggregating multiple validation errors
- Use of `try()` for safe property access with null defaults
- Conditional error inclusion pattern: `condition ? ["error message"] : []`
- Error message format: descriptive text with field references and suggestions
- Example: Runtime validation errors, provider field errors, function-level validation errors

**Testing Patterns in tests/:**
- Terraform test framework using `.tftest.hcl` files
- Test fixtures in `tests/fixtures/` directory for various validation scenarios
- Pattern: `expect_failures = [null_resource.config_validation]` for validation tests
- Pattern: `assert { condition = ..., error_message = ... }` for positive assertions
- Golden file testing approach for consistent outputs

**YAML Parsing in locals.tf:**
- File reading with error handling: `try(file(var.config_path), null)`
- YAML parsing with friendly error messages: `yamldecode(local.file_content)`
- Structure of parsed configuration that validation operates on

**Validation Resource in main.tf:**
- null_resource with lifecycle preconditions for enforcing validation
- Multi-stage validation: file reading, parsing, schema validation
- Error message formatting with bullet points: `join("\n- ", local.validation_errors)`

### New Components Required

**Schema Vendor Directory:**
- Cannot reuse existing code - new directory structure needed at `schemas/serverless-framework/`
- Purpose: Store vendored JSON schema files for each Serverless Framework version

**Node.js CLI Generator:**
- Cannot reuse existing code - no code generation tooling exists in project yet
- Purpose: Parse JSON schemas and generate Terraform HCL validation code
- Location: `tools/schema-generator/`
- Dependencies: Node.js 14+, Handlebars, @json-schema-tools/dereferencer, yargs, chalk

**Handlebars Templates:**
- Cannot reuse existing code - new template system needed
- Purpose: Template system for generating consistent Terraform HCL validation blocks
- Location: `tools/schema-generator/templates/`

**Configuration-Driven Schema Subset Selection:**
- Cannot reuse existing code - new config file needed
- Purpose: Define which schema paths to include/exclude from validation generation
- Location: `tools/schema-generator/config.yml`

**CI/CD Schema Update Workflow:**
- Cannot reuse existing GitHub Actions patterns if they exist
- Purpose: Weekly cron job to detect schema updates and create PRs
- Location: `.github/workflows/schema-update.yml`

**Generated Validation Directory:**
- Cannot reuse existing code - new directory for generated files
- Purpose: Store auto-generated version-specific validation files separate from hand-written code
- Location: `generated/` at module root

## Technical Approach

### Schema Management Architecture
- Vendor schemas as JSON files in `schemas/serverless-framework/v{2,3,4}.x.json`
- Schema normalization step converts Draft 4/6 to Draft 7 using @json-schema-tools/dereferencer
- Weekly GitHub Actions cron job fetches latest Serverless Framework releases, compares hashes, creates PRs for changes

### Code Generation Pipeline
1. CLI reads JSON schema file for specified version
2. Loads configuration file to determine included/excluded schema paths
3. Parses schema and extracts constraints: required fields, types, enums, patterns, ranges, conditionals
4. Maps JSON Schema constraints to Terraform validation expressions
5. Renders Handlebars templates with extracted constraint data
6. Outputs formatted HCL files (terraform fmt applied automatically)
7. Generates version-specific files (v2.tf, v3.tf, v4.tf) and common validation file

### Terraform Integration Pattern
- Generated validation code extends existing `local.validation_errors` pattern in locals.tf
- Generated files define additional `local.*_validation_errors` variables for new schema constraints
- Version detection logic: `try(local.parsed_config.frameworkVersion, "3")` defaults to v3
- Conditional loading: version-specific validation concatenated to main validation_errors based on detected version

### Incremental Validation Strategy (Multi-Layer)
1. Parse-time: Basic structure validation (valid YAML syntax) - handled by yamldecode()
2. Post-parse: Schema-driven validation (required fields, types, enums) - generated validation from this feature
3. Pre-resource-creation: Semantic validation (resource naming conflicts) - custom hand-written validation

Generated validation code focuses exclusively on layer 2 (post-parse schema validation).

### Error Message Template Pattern
```hcl
validation {
  condition     = <terraform expression>
  error_message = "<description>. Must be <expected>, got: '${actual}'. <suggestion> See: <docs-link> (Schema: <schema-path>)"
}
```

### Testing Strategy
1. Schema Integrity Tests: Validate vendored schemas are valid JSON Schema Draft 7
2. Generation Consistency Tests: Golden file testing comparing generator output against baseline
3. Validation Coverage Tests: Ensure all schema constraints have corresponding Terraform validation
4. Drift Detection: CI fails if generated files manually edited
5. Integration Tests: Validate generated code against test fixtures in tests/fixtures/
6. Performance Tests: Ensure validation overhead < 100ms for typical configurations

### Configuration File Format
```yaml
# tools/schema-generator/config.yml
included_paths:
  - /properties/service
  - /properties/provider
  - /properties/functions
  - /properties/resources
  - /properties/custom
excluded_paths:
  - /properties/plugins
  - /properties/package
```

Update configuration as roadmap items are completed to expand validation coverage incrementally.

## Implementation Phases

### Phase 1: Foundation (2-3 days)
- Set up `tools/schema-generator/` directory with package.json
- Install dependencies: Handlebars, @json-schema-tools/dereferencer, yargs, chalk
- Create basic CLI scaffolding with argument parsing
- Implement JSON Schema loader and Draft 4/6 to Draft 7 normalization
- Create initial Handlebars template structure

### Phase 2: Core Generation Logic (1-2 days)
- Implement schema constraint extraction (required, type, enum, pattern, range)
- Build constraint-to-Terraform expression mapping logic
- Develop Handlebars templates for validation block generation
- Add error message template with schema paths and suggestions
- Implement auto-generation header comment generation

### Phase 3: Multi-Version Support (1 day)
- Create configuration file schema (config.yml)
- Implement included_paths/excluded_paths filtering
- Generate version-specific output files (v2.tf, v3.tf, v4.tf, common.tf)
- Add version detection logic guidance for integration

### Phase 4: Schema Vendoring (0.5 day)
- Create `schemas/serverless-framework/` directory
- Fetch and vendor schemas for Serverless Framework v2.x, v3.x, v4.x
- Validate schemas against JSON Schema Draft 7 spec
- Document schema versions and sources

### Phase 5: Initial Validation Generation (1 day)
- Run generator against vendored schemas with initial config
- Generate validation for service, provider, functions properties
- Review and validate generated HCL code
- Test generated validation against existing test fixtures
- Commit generated files to `generated/` directory

### Phase 6: CI/CD Integration (1 day)
- Create `.github/workflows/schema-update.yml` for weekly schema checks
- Implement drift detection workflow to validate generated files are up-to-date
- Add npm script: `npm run generate:validation`
- Document regeneration workflow for maintainers

### Phase 7: Testing and Documentation (1-2 days)
- Implement golden file tests for generator output
- Add schema integrity tests
- Create validation coverage tests
- Add integration tests with existing test fixtures
- Write generator usage documentation
- Document contribution workflow for generated code

## Out of Scope

- Serverless Framework version 1.x support (legacy, no longer supported by Serverless Inc.)
- Runtime resource existence validation (that's Terraform's job during apply)
- CloudFormation resource schema validation (already handled by AWS provider)
- Plugin-specific schema validation (too variable, plugin configurations will be allowed but not validated)
- TypeScript type generation for serverless.ts (future enhancement, separate concern)
- Semantic validation requiring external context (e.g., "does this IAM role exist?")
- Custom validation rule authoring UI (CLI-only tool)
- Real-time schema watching or hot-reload (manual update workflow sufficient)
- Validation for unimplemented roadmap features (incremental generation aligned with roadmap)
- Automatic schema updates without review (security and stability concern - manual PR review required)

## Success Criteria

### Functional Success
- Schema generator CLI can parse Serverless Framework schemas and produce valid Terraform HCL
- Generated validation code successfully validates test fixtures with expected pass/fail outcomes
- Version-specific validation files correctly distinguish between v2.x, v3.x, and v4.x schema constraints
- CI/CD workflow successfully detects schema updates and creates PRs
- Drift detection prevents manual edits to generated files

### Quality Metrics
- All generated HCL code passes `terraform fmt` validation
- Generated validation error messages follow consistent format with schema references and suggestions
- Golden file tests ensure reproducible output across generator runs
- Validation coverage tests confirm all configured schema paths have corresponding validation

### Performance Targets
- Generator completes full schema processing in < 5 seconds
- Generated validation overhead < 100ms for typical serverless.yml (< 50 functions)
- CI validation check completes in < 30 seconds

### Documentation Completeness
- Generator usage documented with examples for common scenarios
- Generated file headers clearly indicate auto-generation and include metadata
- Contribution guide explains when to update schema generator config vs. adding manual validation
- Schema update and regeneration workflow documented for maintainers

### Integration Success
- Generated validation integrates seamlessly with existing validation error collection in locals.tf
- Generated validation does not break existing test fixtures
- Validation complements existing manual validations without conflicts
- npm script workflow enables easy regeneration for developers
