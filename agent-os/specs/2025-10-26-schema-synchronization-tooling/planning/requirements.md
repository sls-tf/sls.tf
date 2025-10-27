# Spec Requirements: Schema Synchronization Tooling

## Initial Description

Develop automated tooling to generate Terraform validation code from the Serverless Framework JSON schema, ensuring validation rules stay synchronized with schema evolution across Framework versions 2.x, 3.x, and 4.x.

This is roadmap item 13, a Medium (M) sized feature that addresses the challenge of keeping Terraform validation logic aligned with the official Serverless Framework schema as it evolves across major versions.

## Requirements Discussion

### First Round Questions

**Q1: Schema Source and Versioning Strategy**

I assume we should fetch Serverless Framework JSON schemas directly from the official Serverless Framework GitHub repository (serverless/serverless) for each supported version (2.x, 3.x, 4.x), using tagged releases or version-specific schema files. Should the tool support dynamic schema fetching at runtime, or should schemas be vendored into the repository with periodic updates?

**Answer:** Schemas should be vendored into the repository under a structured directory (e.g., `schemas/serverless-framework/v2.x.json`, `schemas/serverless-framework/v3.x.json`, `schemas/serverless-framework/v4.x.json`) with a CI/CD workflow that automatically checks for schema updates weekly and creates pull requests when new versions are detected. This approach balances freshness with build reproducibility and avoids runtime dependencies on external services.

**Q2: Code Generation Scope and Target**

I'm thinking the tool should generate Terraform validation blocks (using the `validation` attribute in variable definitions and local values) for serverless.yml structure validation, including required fields, type constraints, enum values, and pattern matching. Should it also generate helper functions for custom validation logic that goes beyond basic JSON schema constraints?

**Answer:** Yes. The tool should generate:
1. Terraform `validation` blocks for variable inputs where applicable
2. Local value definitions with validation expressions for parsed configuration structures
3. A reusable `validation.tf` file with custom validation functions using Terraform's `can()`, `try()`, and conditional expressions for complex schema rules (e.g., conditional required fields, cross-field dependencies)
4. Documentation comments explaining each validation rule and its schema source

**Q3: Multi-Version Support Strategy**

I assume we need to support all three Serverless Framework versions simultaneously since users may be running different versions in different projects. Should the tool generate version-specific validation files (e.g., `validation-v2.tf`, `validation-v3.tf`, `validation-v4.tf`) or a single unified validation file with version detection logic?

**Answer:** Generate version-specific validation files organized as:
- `generated/validation-v2.tf` - Validation rules for Serverless Framework 2.x
- `generated/validation-v3.tf` - Validation rules for Serverless Framework 3.x
- `generated/validation-v4.tf` - Validation rules for Serverless Framework 4.x
- `generated/validation-common.tf` - Shared validation logic across all versions

The main module should detect the Serverless Framework version from the parsed configuration (checking for version-specific fields or reading an explicit version declaration) and conditionally load the appropriate validation file. This allows clear separation and makes it easy to deprecate older versions in the future.

**Q4: Code Generation Language and Tooling**

For implementing the schema-to-Terraform code generator, I'm proposing either:
- Python with Jinja2 templates (good JSON schema handling, mature templating)
- Node.js with Handlebars (aligns with TypeScript parsing dependencies already in tech stack)
- Go (type-safe, single binary distribution, good for CI/CD)

Which approach aligns best with the project's existing tooling and team expertise?

**Answer:** Node.js with Handlebars templates. This aligns with the existing tech stack (Node.js 14+ is already a dependency for TypeScript configuration parsing via ts-node), minimizes new runtime dependencies, allows reuse of existing npm infrastructure, and provides a familiar ecosystem for contributors. The generator should be implemented as a standalone CLI tool in a `tools/schema-generator/` directory with its own package.json.

**Q5: Validation Granularity and Error Messages**

I assume validation should cover:
- Top-level required fields (service name, provider, functions)
- Type validation (string, number, boolean, object, array)
- Enum constraints (allowed runtime values, event types)
- Pattern matching (regex for naming conventions, ARN formats)
- Range validation (memory limits, timeout bounds)

Should error messages reference specific JSON schema constraint paths and include suggestions for fixing common mistakes?

**Answer:** Yes. Each generated validation rule should include:
1. The JSON schema path that defines the constraint (e.g., `#/properties/provider/properties/runtime`)
2. Clear error messages that state what was expected vs. what was provided
3. Common fix suggestions when applicable (e.g., "Did you mean 'nodejs18.x' instead of 'nodejs18'?")
4. Links to Serverless Framework documentation for complex constraints

Example:
```hcl
validation {
  condition     = contains(["nodejs14.x", "nodejs16.x", "nodejs18.x", "nodejs20.x"], local.config.provider.runtime)
  error_message = "Invalid runtime '${local.config.provider.runtime}'. Must be one of: nodejs14.x, nodejs16.x, nodejs18.x, nodejs20.x. See: https://www.serverless.com/framework/docs/providers/aws/guide/functions#runtime (Schema: #/properties/provider/properties/runtime/enum)"
}
```

**Q6: Schema Drift Detection and Testing**

How should the tool detect when generated validation code becomes out of sync with schema updates? Should there be automated tests that validate the generator output against the source schemas?

**Answer:** Implement a comprehensive testing strategy:
1. **Schema Integrity Tests:** Automated tests that parse each vendored schema file and verify it's valid JSON Schema Draft 7 format
2. **Generation Consistency Tests:** Tests that run the generator against known schema versions and compare output against committed baseline files (golden file testing)
3. **Validation Coverage Tests:** Tests that ensure every required field, enum, and type constraint in the schema has corresponding Terraform validation code
4. **Drift Detection:** CI workflow that runs the generator and checks if generated files differ from committed versions, failing the build if manual edits were made to generated files
5. **Schema Update Detection:** Weekly cron job that fetches latest Serverless Framework releases, compares schema hashes, and creates PRs if changes detected

**Q7: Handling Schema Extensions and Custom Properties**

Serverless Framework allows plugins to extend the schema with custom properties. Should the generator support plugin schema extensions, or focus only on core framework schema?

**Answer:** Focus on core Serverless Framework schema only for the initial implementation. Plugin schemas are:
1. Highly variable and plugin-specific
2. Not centrally documented in a machine-readable format
3. Would require dynamic runtime schema fetching rather than static generation

However, the generated validation should NOT reject unknown properties (be permissive) to allow plugin-extended configurations to work. This can be noted in documentation with guidance for users who need plugin-specific validation to add custom validation blocks in their Terraform configurations.

**Q8: Integration with Existing Validation Code**

Looking at the current `variables.tf`, there are manual validation blocks for `config_path` and `config_format`. Should generated validation code:
- Replace existing manual validations where overlap exists?
- Complement existing validations by focusing only on serverless.yml content validation?
- Be clearly marked as auto-generated with warnings not to manually edit?

**Answer:** Generated validation should complement, not replace, existing manual validations:
1. Manual validations in `variables.tf` validate Terraform module inputs (config_path, config_format, aws_region)
2. Generated validations validate the parsed Serverless Framework configuration content
3. All generated files should have prominent header comments:
   ```hcl
   # AUTO-GENERATED FILE - DO NOT EDIT
   # Generated by: tools/schema-generator
   # Schema version: serverless-framework-v3.38.0
   # Generated at: 2025-10-26T10:30:00Z
   # To regenerate: npm run generate:validation --schema-version=3.x
   ```
4. Generated files should live in a `generated/` directory separate from hand-written code

**Q9: Performance and Build Integration**

Should schema-to-validation code generation happen:
- As a pre-commit hook (ensures validation is always fresh)?
- As part of CI/CD pipeline (validates before merge)?
- Manually via npm script when schemas are updated (generated code is committed)?
- At Terraform runtime (dynamic validation)?

**Answer:** Manual generation with committed output:
1. Developers run `npm run generate:validation` when updating vendored schemas
2. Generated files are committed to version control
3. CI/CD validates that generated files are up-to-date (by re-running generator and checking for diffs)
4. Pre-commit hooks are NOT used (too slow, blocks commits unnecessarily)
5. Terraform runtime does NOT generate code (keeps terraform apply fast and deterministic)

This approach ensures reproducible builds, fast Terraform execution, and clear change tracking in git history.

**Q10: Scope Boundaries and Exclusions**

What should explicitly NOT be included in this feature? For example:
- CloudFormation resource validation (handled separately)
- Plugin-specific schema validation
- Runtime value validation (e.g., checking if an S3 bucket actually exists)
- Serverless Framework version 1.x (legacy, out of support)
- TypeScript type generation (different concern)

**Answer:** Out of scope for this feature:
1. Serverless Framework 1.x - no longer supported by Serverless Inc.
2. Runtime resource existence validation - that's Terraform's job during apply
3. CloudFormation resource schema validation - already handled by AWS provider
4. Plugin schema extensions - too variable, addressed in Q7
5. TypeScript type generation for serverless.ts - potential future enhancement but separate from Terraform validation
6. Semantic validation requiring external context (e.g., "does this IAM role exist?")
7. Custom validation rule authoring UI - generator is CLI-only
8. Real-time schema watching/hot-reload - manual update workflow is sufficient

**Existing Code Reuse:**

Are there existing features in your codebase with similar patterns we should reference?

**Answer:** The project is in early stages (roadmap item 13 of 13, with only item 1 completed based on git status). However, reference these patterns:
- `variables.tf` - existing validation block structure to maintain consistency
- `locals.tf` - likely contains YAML parsing logic to understand what's being validated
- `examples/basic/` - test configuration structure that validation should handle
- The tech stack already uses Node.js/ts-node for TypeScript parsing (roadmap item 6), so the schema generator can reuse that dependency chain

No similar code generation tooling exists yet in the project, so this establishes patterns for future generators.

**Visual Assets Request:**

Do you have any design mockups, wireframes, or screenshots that could help guide the development?

**Answer:** No visual assets are applicable for this feature. This is a code generation and validation tooling feature without UI components. The primary artifacts are:
1. CLI tool output (terminal text)
2. Generated Terraform HCL code files
3. JSON schema files
4. Validation error messages in Terraform output

Documentation diagrams showing the schema-to-validation flow would be useful but are not required for initial implementation.

### Follow-up Questions

Based on the answers above, I have a few follow-up questions:

**Follow-up 1: JSON Schema Dialect Compatibility**

Serverless Framework schemas may use different JSON Schema dialects (Draft 4, Draft 7, etc.) across versions. Should the generator support multiple JSON Schema dialects, or require schemas to be normalized to a single dialect?

**Answer:** The generator should support JSON Schema Draft 7 as the primary dialect (most common in modern schemas) but include a schema normalization step that converts older dialects (Draft 4, Draft 6) to Draft 7 before code generation. This can use the `@json-schema-tools/dereferencer` npm package. If a schema uses an unsupported dialect, the generator should fail with a clear error message indicating which dialect version is required.

**Follow-up 2: Incremental Validation Strategy**

Should validation be applied at multiple layers:
- Parse-time (when yamldecode() executes)?
- Post-parse (after YAML is converted to structured data)?
- Pre-resource-creation (before aws_lambda_function generation)?

Or should all validation be consolidated at a single point?

**Answer:** Multi-layer validation strategy:
1. **Parse-time:** Basic structure validation (valid YAML syntax, no duplicate keys) - handled by Terraform's yamldecode()
2. **Post-parse:** Schema-driven validation (required fields, types, enums) - generated validation from this feature, executed in locals.tf after parsing
3. **Pre-resource-creation:** Semantic validation (resource naming conflicts, dependency checks) - custom hand-written validation in main.tf

This approach provides early failure with clear error messages at each stage. Generated validation code from this feature focuses exclusively on layer 2 (post-parse schema validation).

**Follow-up 3: Schema Subset Generation**

Given that the Serverless Framework schema is large and covers many features (many beyond the initial roadmap), should the generator:
- Generate validation for the entire schema comprehensively?
- Generate validation only for features implemented in the roadmap (functions, events, resources)?
- Use an allowlist configuration file to specify which schema sections to validate?

**Answer:** Use a configuration-driven approach with roadmap alignment:
1. Create a `tools/schema-generator/config.yml` file specifying which schema paths to include:
   ```yaml
   included_paths:
     - /properties/service
     - /properties/provider
     - /properties/functions
     - /properties/resources  # for roadmap item 9
     - /properties/custom      # common configuration
   excluded_paths:
     - /properties/plugins     # not implementing plugin system
     - /properties/package     # future enhancement
   ```
2. As roadmap items are completed, update the config to include new schema paths
3. Generate validation incrementally, ensuring it covers implemented features
4. Include a `--full` flag for generating complete schema validation for future use

This avoids validation noise for unimplemented features while maintaining forward compatibility.

## Visual Assets

### Files Provided:

No visual assets provided.

### Visual Insights:

Not applicable - this is a code generation and validation tooling feature without visual components.

## Requirements Summary

### Functional Requirements

**FR1: Schema Management**
- Vendor Serverless Framework JSON schemas for versions 2.x, 3.x, and 4.x in `schemas/serverless-framework/` directory
- Organize schemas by major version with clear naming convention (e.g., `v2.x.json`, `v3.38.0.json`)
- Support JSON Schema Draft 7 format with automatic normalization from older drafts
- Implement CI/CD workflow for weekly schema update detection and PR creation

**FR2: Code Generator CLI Tool**
- Develop Node.js-based CLI tool in `tools/schema-generator/` directory
- Support command-line arguments: `--schema-version`, `--output-dir`, `--config`, `--full`
- Parse JSON Schema files and extract validation constraints (required fields, types, enums, patterns, ranges)
- Generate Terraform HCL validation code using Handlebars templates
- Support incremental generation based on configuration file allowlist/blocklist
- Output version-specific validation files: `generated/validation-v2.tf`, `generated/validation-v3.tf`, `generated/validation-v4.tf`, `generated/validation-common.tf`

**FR3: Terraform Validation Code Generation**
- Generate `validation` blocks for local values with JSON schema-derived constraints
- Generate custom validation functions using `can()`, `try()`, and conditional expressions for complex rules
- Include detailed error messages with schema paths, expected values, and fix suggestions
- Include documentation comments explaining each validation rule and its source schema
- Add auto-generation header comments with tool version, schema version, and timestamp
- Ensure generated code follows Terraform formatting standards (terraform fmt compatible)

**FR4: Multi-Version Support**
- Detect Serverless Framework version from parsed configuration
- Conditionally load version-specific validation file based on detected version
- Support version override via explicit configuration variable
- Maintain backward compatibility for older schema versions within supported range
- Clearly separate version-specific validation from common validation rules

**FR5: Validation Coverage**
- Validate top-level required fields: service, provider, functions
- Validate field types: string, number, boolean, object, array
- Validate enum constraints: runtime values, event types, AWS regions
- Validate pattern matching: naming conventions, ARN formats, version strings
- Validate range constraints: memory limits (128-10240 MB), timeout bounds (1-900 seconds)
- Validate conditional requirements: fields required based on other field values
- Allow unknown properties to support Serverless Framework plugins

**FR6: Error Messaging**
- Include JSON schema path reference in each error message
- Provide expected vs. actual value comparison
- Suggest common fixes for frequent mistakes (e.g., runtime version typos)
- Link to relevant Serverless Framework documentation
- Format errors consistently with Terraform error message conventions

**FR7: Schema Update Workflow**
- Weekly CI/CD cron job to check Serverless Framework releases
- Compare schema file hashes against vendored versions
- Create automated PR when schema changes detected
- Include schema diff summary in PR description
- Require manual review before merging schema updates
- Regenerate validation code after schema updates

**FR8: Testing and Validation**
- Schema integrity tests: validate vendored schemas against JSON Schema Draft 7 spec
- Generation consistency tests: golden file testing for reproducible output
- Validation coverage tests: ensure all schema constraints have corresponding Terraform validation
- Drift detection tests: fail CI if generated files manually edited
- Integration tests: validate generated code against example serverless.yml configurations
- Performance tests: ensure validation doesn't significantly impact terraform plan time

### Reusability Opportunities

**Existing Patterns to Reference:**
- `variables.tf` validation blocks - maintain consistent validation block structure and error message format
- `locals.tf` YAML parsing - understand the structure of parsed configuration that needs validation
- `examples/basic/main.tf` - test validation against real-world configuration examples
- Node.js/ts-node dependency chain - reuse for schema generator runtime

**Code Generation Patterns:**
This feature establishes reusable patterns for future code generation needs:
- Template-based HCL generation approach
- JSON schema parsing and constraint extraction
- Multi-version support strategy
- CI/CD integration for automated updates
- Golden file testing for generated code

**Potential Future Reuse:**
- Generate TypeScript types from JSON schema for serverless.ts validation
- Generate documentation from schema (automated reference docs)
- Generate example configurations from schema
- Generate test fixtures from schema examples

### Scope Boundaries

**In Scope:**
- Vendoring Serverless Framework JSON schemas for versions 2.x, 3.x, 4.x
- Node.js CLI tool for schema-to-Terraform validation code generation
- Handlebars templates for Terraform HCL output
- Generated validation for core Serverless Framework features (aligned with roadmap)
- Version-specific and common validation file generation
- Comprehensive error messages with schema references and suggestions
- CI/CD workflow for schema update detection and validation
- Test suite for generator and generated validation code
- Documentation for using and maintaining the schema generator

**Out of Scope:**
- Serverless Framework version 1.x support (legacy)
- Plugin-specific schema validation (too variable)
- Runtime resource existence validation (Terraform's responsibility)
- CloudFormation resource schema validation (AWS provider's responsibility)
- TypeScript type generation for serverless.ts (future enhancement)
- Semantic validation requiring external context (e.g., IAM role existence checks)
- Custom validation rule authoring UI (CLI-only tool)
- Real-time schema watching or hot-reload (manual workflow sufficient)
- Validation for unimplemented roadmap features (incremental approach)
- Automatic schema updates without review (security and stability concern)

### Technical Considerations

**Technology Stack:**
- Node.js 14+ (aligns with existing ts-node dependency)
- npm for package management
- Handlebars for HCL template generation
- JSON Schema Draft 7 specification
- Terraform 1.0+ validation features

**Integration Points:**
- CI/CD pipeline: GitHub Actions workflow for schema updates and validation
- Terraform module: generated validation files loaded conditionally based on version detection
- Build process: npm scripts for manual validation generation
- Testing framework: Integration with existing Terraform test framework

**Performance Constraints:**
- Validation code must not significantly impact terraform plan execution time
- Target: validation overhead < 100ms for typical serverless.yml (< 50 functions)
- Generator should complete in < 5 seconds for full schema processing
- CI validation check should complete in < 30 seconds

**Dependencies:**
- Serverless Framework official JSON schemas (external, vendored)
- Node.js packages: handlebars, @json-schema-tools/dereferencer, yargs, chalk
- Terraform 1.0+ for validation block syntax
- GitHub API for automated schema update detection

**Constraints:**
- Must support offline builds (schemas are vendored, not fetched at build time)
- Generated code must be terraform fmt compliant
- No runtime dependencies beyond Terraform and Node.js (for TypeScript parsing)
- Generated validation must be backward compatible within major version
- Schema normalization must handle Draft 4, 6, and 7 dialects

**Security Considerations:**
- Validate JSON schema files before processing (prevent injection attacks)
- Pin npm dependencies in schema generator package.json
- Review schema updates manually before merging (prevent supply chain attacks)
- Do not execute user-provided code in schema generator
- Sanitize error messages to prevent information disclosure

**Roadmap Dependencies:**
- Depends on: Roadmap Item 1 (Core Module Structure & YAML Parsing) - provides the locals.tf structure where generated validation will be applied
- Enables: All future roadmap items (2-12) by ensuring configuration validation keeps pace with feature implementation
- Complements: Roadmap Item 6 (TypeScript Configuration Parsing) - validation applies to both YAML and TypeScript configs
- Foundation for: Future schema-driven features (documentation generation, example generation, migration tooling)

**Error Handling Strategy:**
- Schema parsing errors: Fail fast with clear error indicating which schema file is invalid
- Template rendering errors: Include line number and template context
- Validation generation errors: Log warnings for unsupported schema constructs, continue generation
- CI validation failures: Fail build if generated files are out of sync, provide re-generation instructions
- Runtime validation errors: Provide actionable error messages referencing schema and documentation

**Versioning and Compatibility:**
- Schema generator version: Semantic versioning (e.g., 1.0.0)
- Generated code version metadata: Include schema version and generator version in file headers
- Backward compatibility: Generated validation for v2.x should not break when v3.x is added
- Deprecation strategy: Keep validation for deprecated features but mark with comments
- Migration path: Document how to upgrade validation when moving between Serverless Framework versions

### User Stories

**US1: Module Maintainer - Ensure Validation Stays Current**
As a sls.tf module maintainer, I need automated schema synchronization so that validation rules automatically stay aligned with Serverless Framework updates without manual code changes, reducing maintenance burden and preventing validation drift.

**Acceptance Criteria:**
- CI/CD workflow checks for Serverless Framework schema updates weekly
- Automated PR is created when schema changes are detected
- PR includes schema diff and list of affected validation rules
- Regenerating validation code is a single npm command
- Generated validation files include metadata showing schema version and generation timestamp

**US2: Module Maintainer - Support Multiple Framework Versions**
As a sls.tf module maintainer, I need version-specific validation generation so that users on different Serverless Framework versions (2.x, 3.x, 4.x) receive appropriate validation errors based on their version's schema, preventing confusion from version-specific constraints.

**Acceptance Criteria:**
- Separate validation files generated for each major version (v2, v3, v4)
- Version detection logic correctly identifies Serverless Framework version from config
- Validation applies version-specific constraints (e.g., runtime options differ by version)
- Common validation rules are shared across versions in validation-common.tf
- Users can override version detection with explicit configuration variable

**US3: Module User - Clear Validation Error Messages**
As a developer using sls.tf, when my serverless.yml has a validation error, I need clear error messages that explain what's wrong, reference the schema constraint, and suggest how to fix it, so I can quickly resolve configuration issues without consulting documentation.

**Acceptance Criteria:**
- Error messages include the invalid value and expected value/pattern
- Error messages reference the JSON schema path (e.g., #/properties/provider/properties/runtime)
- Error messages suggest common fixes for frequent mistakes
- Error messages link to relevant Serverless Framework documentation
- Error messages are formatted consistently with Terraform conventions

**US4: Module Maintainer - Incremental Schema Coverage**
As a sls.tf module maintainer implementing roadmap features incrementally, I need to generate validation only for implemented features so that users don't receive validation errors for unimplemented functionality, while still maintaining comprehensive validation for supported features.

**Acceptance Criteria:**
- Configuration file allows specifying which schema paths to include/exclude
- Generator only creates validation for configured schema sections
- Configuration can be updated as roadmap items are completed
- `--full` flag available for generating complete schema validation
- Generated validation clearly documents which schema sections are covered

**US5: Contributor - Easy Schema Generator Development**
As a contributor to sls.tf, I need clear separation between generated and hand-written code so that I know which files are safe to edit and which should be regenerated, preventing accidental manual edits to generated files.

**Acceptance Criteria:**
- All generated files have prominent "AUTO-GENERATED - DO NOT EDIT" headers
- Generated files live in `generated/` directory separate from hand-written code
- CI fails if generated files have been manually edited (drift detection)
- Clear documentation on how to run the generator
- Template files for customizing generation are well-documented

**US6: Module Maintainer - Validation Performance**
As a sls.tf module maintainer, I need generated validation to execute efficiently so that terraform plan and apply operations remain fast even with comprehensive validation, ensuring good user experience.

**Acceptance Criteria:**
- Validation overhead is < 100ms for typical configurations (< 50 functions)
- Generated validation uses efficient Terraform expressions (avoids redundant checks)
- Validation is applied early in the evaluation phase (fail fast)
- Performance tests validate validation overhead stays within acceptable bounds
- Generated code follows Terraform best practices for performance

**US7: Module User - Plugin Compatibility**
As a developer using Serverless Framework plugins with sls.tf, I need validation to allow plugin-specific configuration properties so that my extended serverless.yml configurations don't fail validation due to unrecognized fields, while still validating core framework properties.

**Acceptance Criteria:**
- Generated validation does not reject unknown properties
- Validation focuses on known Serverless Framework core schema properties
- Documentation explains that plugin-specific validation is out of scope
- Guidance provided for adding custom validation for plugin properties if needed
- Plugin properties are ignored by validation (permissive approach)

**US8: Module Maintainer - Test Coverage for Validation**
As a sls.tf module maintainer, I need comprehensive tests for the schema generator and generated validation code so that I can confidently update schemas and regenerate validation without introducing regressions.

**Acceptance Criteria:**
- Golden file tests ensure consistent generator output
- Schema integrity tests validate vendored schemas are well-formed
- Coverage tests ensure all schema constraints have corresponding validation
- Integration tests validate generated code against example configurations
- CI fails if generated files differ from committed versions (drift detection)

## Dependencies on Other Roadmap Items

**Depends On:**
- **Roadmap Item 1 (Core Module Structure & YAML Parsing)** - REQUIRED
  - Provides the foundational module structure and yamldecode() logic
  - Generated validation will be applied to parsed configuration in locals.tf
  - Establishes the data structure that validation operates on
  - Status: Completed (based on git history showing initial commit)

**Enables:**
- **Roadmap Items 2-12 (All remaining features)** - BENEFICIAL
  - As each feature is implemented (Lambda, IAM, API Gateway, etc.), validation can be incrementally expanded
  - Ensures configuration validation keeps pace with feature development
  - Reduces manual validation code maintenance burden for new features
  - Provides consistent validation patterns across all features

**Complements:**
- **Roadmap Item 6 (TypeScript Configuration Parsing)** - RELATED
  - Generated validation applies to both YAML and TypeScript configurations
  - TypeScript parsing may provide additional type safety, validation provides runtime checks
  - Both features contribute to configuration correctness
  - Validation ensures TypeScript-generated JSON matches schema constraints

**Provides Foundation For:**
- Future schema-driven tooling:
  - Automated documentation generation from schema
  - Example configuration generation
  - Migration tooling between Serverless Framework versions
  - TypeScript type definition generation for serverless.ts

**No Blockers:**
- This feature can be implemented immediately after Item 1 completion
- Does not block any other roadmap items
- Other features can proceed without schema synchronization (using manual validation)
- Provides increasing value as more features are implemented

**Recommended Implementation Sequence:**
1. Implement schema generator tooling (2-3 days)
2. Vendor initial schemas for v2.x, v3.x, v4.x (0.5 day)
3. Generate initial validation for service, provider, functions (1 day)
4. Integrate with CI/CD for schema update detection (1 day)
5. Add validation coverage incrementally as roadmap items 2-12 are completed

**Cross-Feature Integration:**
- Validation generated by this feature will be consumed by all other roadmap items
- Each roadmap item implementation should update schema generator config to include relevant schema paths
- Validation provides safety net for feature development and regression prevention
