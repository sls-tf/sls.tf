# Specification: Route 53 & Custom Domain Management

## Overview

This specification defines the Route 53 and custom domain management feature for sls.tf, which provisions AWS Route 53 hosted zones, DNS records, API Gateway custom domain names, and base path mappings from Serverless Framework `provider.customDomain` configuration. This enables users to attach custom domains to their API Gateway endpoints using familiar Serverless Framework syntax while Terraform manages the underlying AWS resources.

**Roadmap Position:** Item #12 - Custom domain and DNS management for API Gateway
**Dependencies:** Roadmap item #4 (API Gateway REST API Integration)
**Target Completion:** Full custom domain provisioning with Route 53 integration

## Goal

Enable automatic provisioning of custom domains for API Gateway endpoints by parsing Serverless Framework `provider.customDomain` configuration and generating Route 53 hosted zones, DNS records, API Gateway domain names, and base path mappings through Terraform, supporting both edge-optimized and regional endpoints with flexible certificate management.

## User Stories

- As a platform engineer, I want to define custom domains in my serverless.yml `provider.customDomain` block so that my API Gateway endpoints use branded domain names instead of AWS-generated URLs
- As a migration architect, I want to leverage existing Route 53 hosted zones by specifying `hostedZoneId` so that I don't create duplicate DNS zones during migration
- As a developer, I want the module to create Route 53 DNS records automatically so that my custom domain resolves to the API Gateway endpoint without manual DNS configuration
- As a DevOps engineer, I want to use existing ACM certificates via `certificateArn` so that I can manage SSL certificates independently of domain provisioning
- As an infrastructure team member, I want clear validation errors for certificate region mismatches so that I catch edge vs regional endpoint certificate requirements early
- As an API developer, I want to configure base path mappings so that multiple API stages can share a single domain with different URL paths

## Visual Design

This feature includes four Mermaid diagrams for technical reference:

- **Custom Domain Architecture** (`planning/visuals/custom-domain-architecture.md`): Shows relationship between Route 53, ACM, API Gateway domain name, and base path mapping resources
- **Domain Creation Flow** (`planning/visuals/domain-creation-flow.md`): Decision tree for creating vs using existing hosted zones and certificates
- **Configuration Mapping** (`planning/visuals/configuration-mapping.md`): Maps Serverless Framework customDomain fields to Terraform resources and attributes
- **DNS Record Types** (`planning/visuals/dns-record-types.md`): Illustrates Route 53 ALIAS record structure pointing to API Gateway CloudFront or regional endpoints

## Core Requirements

### Functional Requirements

**Custom Domain Configuration Parsing:**
- Parse `provider.customDomain` configuration block from serverless.yml
- Extract required field: `domainName` (custom domain string, e.g., "api.example.com")
- Extract optional fields: `basePath`, `stage`, `createRoute53Record`, `certificateArn`, `hostedZoneId`, `endpointType`
- Apply Serverless Framework defaults: `createRoute53Record = true`, `endpointType = "EDGE"`, `stage = provider.stage`
- Support absence of customDomain block (feature disabled if not configured)

**Route 53 Hosted Zone Management:**
- If `hostedZoneId` provided in config: lookup existing hosted zone using `data.aws_route53_zone`
- If `hostedZoneId` not provided and `create_hosted_zone = true`: create `aws_route53_zone` for the domainName
- If `hostedZoneId` not provided and `create_hosted_zone = false`: error with message requiring hostedZoneId
- Accept module variable `create_hosted_zone` (bool, default false) to control zone creation
- Validate `hostedZoneId` format if provided: must start with "Z" followed by alphanumeric characters

**ACM Certificate Resolution:**
- If `certificateArn` provided in customDomain config: use that certificate ARN
- If `certificateArn` not provided in config: check module variable `acm_certificate_arn`
- If neither source provides certificate: error with clear message requiring certificate ARN
- Support ARN format validation: arn:aws:acm:region:account:certificate/certificate-id
- No automatic certificate creation (out of scope - requires DNS validation workflow)

**Certificate Region Validation:**
- EDGE endpoint type: certificate MUST be in us-east-1 region (CloudFront requirement)
- REGIONAL endpoint type: certificate MUST be in same region as API Gateway
- PRIVATE endpoint type: certificate MUST be in same region as API Gateway
- Extract region from certificate ARN and validate against endpoint type requirements
- Error message format: "Certificate region mismatch: EDGE endpoints require us-east-1 certificate, got us-west-2"

**API Gateway Domain Name Creation:**
- Create `aws_api_gateway_domain_name` resource with customDomain configuration
- Set `domain_name` attribute to customDomain.domainName value
- Set `certificate_arn` attribute from certificate resolution logic
- Set `endpoint_configuration.types` to [customDomain.endpointType]
- For EDGE endpoints: output `cloudfront_domain_name` and `cloudfront_zone_id`
- For REGIONAL endpoints: output `regional_domain_name` and `regional_zone_id`
- Conditional resource creation based on customDomain block presence

**Base Path Mapping Creation:**
- Create `aws_api_gateway_base_path_mapping` resource linking domain to API stage
- Set `domain_name` to reference aws_api_gateway_domain_name resource
- Set `api_id` to REST API ID from roadmap #4 API Gateway module output
- Set `stage_name` from customDomain.stage or fallback to provider.stage
- Set `base_path` from customDomain.basePath if provided (optional field)
- Validate basePath format: no leading/trailing slashes, alphanumeric with hyphens/underscores only

**Route 53 DNS Record Creation:**
- If `customDomain.createRoute53Record = true`: create `aws_route53_record` with ALIAS type
- Set record name to customDomain.domainName
- Point ALIAS to API Gateway domain name target (CloudFront or regional)
- For EDGE: use cloudfront_domain_name and cloudfront_zone_id from domain name resource
- For REGIONAL: use regional_domain_name and regional_zone_id from domain name resource
- Set `evaluate_target_health = true` for automatic health-based routing
- If `customDomain.createRoute53Record = false`: skip record creation, output target for manual setup

**Configuration Validation:**
- Validate `domainName` format: valid DNS hostname pattern (RFC 1123)
- Validate `basePath` format: alphanumeric, hyphens, underscores; no slashes at start/end
- Validate `endpointType`: must be one of "EDGE", "REGIONAL", or "PRIVATE"
- Validate `hostedZoneId` format if provided: pattern "Z[A-Z0-9]+"
- Validate `certificateArn` format: valid AWS ARN with acm service namespace
- Collect all validation errors before halting execution (consistent with core module pattern)

**Conditional Resource Creation:**
- Enable custom domain resources only if `provider.customDomain` block exists in serverless.yml
- Custom domain requires API Gateway REST API from roadmap #4 to be enabled
- Add module variable `enable_custom_domain` (bool, default false) for explicit control
- Skip all custom domain resources if customDomain configuration not present

**Output Generation:**
- Output `custom_domain_name`: The configured custom domain (string or null)
- Output `custom_domain_target`: CloudFront or regional endpoint DNS name for manual setup
- Output `custom_domain_hosted_zone_id`: Route 53 hosted zone ID used for DNS
- Output `custom_domain_base_path`: Configured base path mapping (string or null)
- Output `route53_record_fqdn`: Fully qualified domain name of created DNS record (or null)
- Output `api_gateway_domain_name_id`: Resource ID for external references

## Reusable Components

### Existing Code to Leverage

**Core Module Validation Patterns:**
- Use `concat()` for validation error collection from `/home/tom/p/t/sls.tf/locals.tf`
- Use `try()` wrapper for safe field access from existing parsing logic
- Use `null_resource` with lifecycle preconditions for validation enforcement from `/home/tom/p/t/sls.tf/main.tf`
- Use `coalesce()` for default value application pattern
- Follow error message format: "Field 'X' validation failed. Expected Y, got Z."

**Configuration Parsing Patterns:**
- Leverage existing `local.parsed_config` structure from core module
- Access provider configuration via `local.provider_with_defaults`
- Use optional field extraction: `try(local.parsed_config.provider.customDomain, null)`
- Follow conditional resource pattern: `count = var.enable_custom_domain && local.has_custom_domain ? 1 : 0`

**Module Interface Patterns:**
- Define input variables with validation blocks in `variables.tf`
- Structure outputs with clear descriptions in `outputs.tf`
- Use local values for complex transformations in `locals.tf`
- Separate data sources into `data.tf` file for organization

**Existing Terraform Resources:**
- Reference API Gateway REST API outputs from roadmap #4 module
- Reference API Gateway deployment stage from roadmap #4 module
- Follow AWS provider version constraint: `>= 6.0` from `versions.tf`
- Use Terraform version constraint: `>= 1.13.4` from existing setup

### New Components Required

**Custom Domain Module Structure:**
- New module directory: `modules/custom-domain/` for domain-specific resources
- New validation logic for certificate region matching endpoint type
- New data source lookups for Route 53 hosted zones
- New output interface specifically for custom domain resources
- Reason: Domain management is distinct feature with unique validation requirements not present in core module

**Certificate Region Extraction Logic:**
- Extract region from certificate ARN string (arn:aws:acm:**region**:account:certificate/id)
- Compare extracted region against endpoint type requirements
- Cannot reuse existing logic (new functionality specific to ACM certificate validation)

**Base Path Format Validation:**
- Regex validation for base path character restrictions
- Slash detection at boundaries (no leading/trailing slashes)
- New validation rule not present in core module schema validation

## Technical Approach

### Module Structure and File Organization

**File Organization:**
```
sls.tf/
├── modules/
│   └── custom-domain/
│       ├── main.tf              # Domain name and base path mapping resources
│       ├── variables.tf         # Module input variables (domain config, certificates)
│       ├── outputs.tf           # Domain and DNS outputs
│       ├── data.tf              # Route 53 zone lookups
│       ├── route53.tf           # Route 53 zone and record resources
│       └── validation.tf        # Certificate and configuration validation
└── main.tf                      # Root module invoking custom-domain module
```

**Root Module Integration:**
```hcl
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

### Terraform Resources and Data Sources

**Data Sources:**
```hcl
# Lookup existing hosted zone if hostedZoneId provided
data "aws_route53_zone" "existing" {
  count   = var.domain_config.hostedZoneId != null ? 1 : 0
  zone_id = var.domain_config.hostedZoneId
}
```

**Route 53 Resources:**
```hcl
# Create new hosted zone if needed
resource "aws_route53_zone" "custom_domain" {
  count = var.create_hosted_zone && var.domain_config.hostedZoneId == null ? 1 : 0
  name  = var.domain_config.domainName
}

# Create ALIAS record pointing to API Gateway
resource "aws_route53_record" "custom_domain" {
  count   = var.domain_config.createRoute53Record ? 1 : 0
  zone_id = local.hosted_zone_id
  name    = var.domain_config.domainName
  type    = "A"

  alias {
    name                   = local.domain_name_target
    zone_id               = local.domain_name_zone_id
    evaluate_target_health = true
  }
}
```

**API Gateway Resources:**
```hcl
# API Gateway custom domain name
resource "aws_api_gateway_domain_name" "custom_domain" {
  domain_name     = var.domain_config.domainName
  certificate_arn = local.certificate_arn

  endpoint_configuration {
    types = [var.domain_config.endpointType]
  }
}

# Base path mapping to API stage
resource "aws_api_gateway_base_path_mapping" "custom_domain" {
  domain_name = aws_api_gateway_domain_name.custom_domain.domain_name
  api_id      = var.api_gateway_rest_api
  stage_name  = coalesce(var.domain_config.stage, var.api_gateway_stage)
  base_path   = try(var.domain_config.basePath, null)
}
```

### Validation Strategy

**Validation Phases:**
1. **Configuration Presence Validation**: Check if customDomain block exists
2. **Required Field Validation**: Validate domainName is present and non-empty
3. **Format Validation**: Validate domain name, base path, hostedZoneId formats
4. **Certificate Validation**: Ensure certificate ARN is provided and properly formatted
5. **Certificate Region Validation**: Match certificate region to endpoint type requirements
6. **Endpoint Type Validation**: Ensure endpointType is valid value (EDGE/REGIONAL/PRIVATE)
7. **Hosted Zone Validation**: Ensure hosted zone available (provided or created)

**Certificate Region Validation Logic:**
```hcl
locals {
  # Extract region from certificate ARN
  certificate_region = var.certificate_arn != null ? split(":", var.certificate_arn)[3] : null

  # Define region requirements by endpoint type
  required_region = var.domain_config.endpointType == "EDGE" ? "us-east-1" : var.aws_region

  # Validation error for region mismatch
  certificate_region_errors = var.certificate_arn != null && local.certificate_region != local.required_region ? [
    "Certificate region mismatch: ${var.domain_config.endpointType} endpoints require certificate in ${local.required_region}, got certificate in ${local.certificate_region}"
  ] : []
}
```

**Domain Name Format Validation:**
```hcl
validation {
  condition     = var.domain_config == null || can(regex("^[a-z0-9][a-z0-9-\\.]*[a-z0-9]$", var.domain_config.domainName))
  error_message = "Field 'customDomain.domainName' must be a valid DNS hostname (RFC 1123 format)."
}
```

**Base Path Format Validation:**
```hcl
locals {
  base_path_errors = var.domain_config.basePath != null && (
    can(regex("^/", var.domain_config.basePath)) ||
    can(regex("/$", var.domain_config.basePath)) ||
    !can(regex("^[a-zA-Z0-9_-]+$", var.domain_config.basePath))
  ) ? [
    "Field 'customDomain.basePath' must contain only alphanumeric characters, hyphens, and underscores with no leading or trailing slashes. Got: '${var.domain_config.basePath}'"
  ] : []
}
```

**Error Collection Pattern:**
```hcl
locals {
  validation_errors = concat(
    local.required_field_errors,
    local.format_validation_errors,
    local.certificate_validation_errors,
    local.certificate_region_errors,
    local.endpoint_type_errors,
    local.hosted_zone_errors,
    local.base_path_errors
  )

  has_errors = length(local.validation_errors) > 0
}

resource "null_resource" "custom_domain_validation" {
  lifecycle {
    precondition {
      condition     = !local.has_errors
      error_message = "Custom domain validation failed:\n- ${join("\n- ", local.validation_errors)}"
    }
  }
}
```

### Default Value Application

**Serverless Framework Default Alignment:**
```hcl
locals {
  # Apply customDomain defaults matching Serverless Framework behavior
  custom_domain_config = var.domain_config != null ? merge(
    var.domain_config,
    {
      createRoute53Record = coalesce(try(var.domain_config.createRoute53Record, null), true)
      endpointType       = coalesce(try(var.domain_config.endpointType, null), "EDGE")
      stage              = coalesce(try(var.domain_config.stage, null), var.api_gateway_stage)
    }
  ) : null
}
```

**Certificate ARN Resolution:**
```hcl
locals {
  # Certificate ARN from config takes precedence over module variable
  certificate_arn = coalesce(
    try(var.domain_config.certificateArn, null),
    var.acm_certificate_arn
  )

  # Error if no certificate provided from either source
  certificate_required_errors = local.certificate_arn == null ? [
    "ACM certificate ARN required for custom domain. Provide via customDomain.certificateArn or acm_certificate_arn module variable."
  ] : []
}
```

**Hosted Zone Resolution:**
```hcl
locals {
  # Determine hosted zone ID from lookup, creation, or config
  hosted_zone_id = coalesce(
    try(var.domain_config.hostedZoneId, null),
    try(aws_route53_zone.custom_domain[0].zone_id, null),
    try(data.aws_route53_zone.existing[0].zone_id, null)
  )

  # Error if hosted zone cannot be determined
  hosted_zone_errors = local.hosted_zone_id == null ? [
    "Route 53 hosted zone required. Provide customDomain.hostedZoneId or set create_hosted_zone=true."
  ] : []
}
```

### Endpoint Type Handling

**Domain Name Target Selection:**
```hcl
locals {
  # Select appropriate target based on endpoint type
  domain_name_target = var.domain_config.endpointType == "EDGE" ? (
    aws_api_gateway_domain_name.custom_domain.cloudfront_domain_name
  ) : (
    aws_api_gateway_domain_name.custom_domain.regional_domain_name
  )

  domain_name_zone_id = var.domain_config.endpointType == "EDGE" ? (
    aws_api_gateway_domain_name.custom_domain.cloudfront_zone_id
  ) : (
    aws_api_gateway_domain_name.custom_domain.regional_zone_id
  )
}
```

**Endpoint Type Validation:**
```hcl
locals {
  valid_endpoint_types = ["EDGE", "REGIONAL", "PRIVATE"]

  endpoint_type_errors = !contains(local.valid_endpoint_types, var.domain_config.endpointType) ? [
    "Field 'customDomain.endpointType' must be one of: EDGE, REGIONAL, PRIVATE. Got: '${var.domain_config.endpointType}'"
  ] : []
}
```

### Module Variables and Outputs

**Input Variables:**
```hcl
variable "domain_config" {
  description = "Custom domain configuration from provider.customDomain"
  type = object({
    domainName          = string
    basePath            = optional(string)
    stage               = optional(string)
    createRoute53Record = optional(bool)
    certificateArn      = optional(string)
    hostedZoneId        = optional(string)
    endpointType        = optional(string)
  })
  default = null
}

variable "api_gateway_rest_api" {
  description = "API Gateway REST API ID from roadmap #4 module"
  type        = string
}

variable "api_gateway_stage" {
  description = "API Gateway deployment stage name"
  type        = string
}

variable "create_hosted_zone" {
  description = "Create Route 53 hosted zone if hostedZoneId not provided"
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN override (fallback if not in config)"
  type        = string
  default     = null
}

variable "aws_region" {
  description = "AWS region for regional endpoint certificate validation"
  type        = string
}
```

**Output Values:**
```hcl
output "custom_domain_name" {
  description = "The custom domain name configured, or null if not configured"
  value       = var.domain_config != null ? aws_api_gateway_domain_name.custom_domain.domain_name : null
}

output "custom_domain_target" {
  description = "CloudFront or regional endpoint DNS target for manual DNS setup"
  value       = var.domain_config != null ? local.domain_name_target : null
}

output "custom_domain_hosted_zone_id" {
  description = "Route 53 hosted zone ID used for DNS records"
  value       = var.domain_config != null ? local.hosted_zone_id : null
}

output "custom_domain_base_path" {
  description = "Base path mapping configured for the domain, or null"
  value       = var.domain_config != null ? try(var.domain_config.basePath, null) : null
}

output "route53_record_fqdn" {
  description = "Fully qualified domain name of created Route 53 record, or null if not created"
  value       = var.domain_config != null && var.domain_config.createRoute53Record ? aws_route53_record.custom_domain[0].fqdn : null
}

output "api_gateway_domain_name_id" {
  description = "API Gateway domain name resource ID for external references"
  value       = var.domain_config != null ? aws_api_gateway_domain_name.custom_domain.id : null
}
```

## Out of Scope

### Excluded from This Feature

**ACM Certificate Creation:**
- Automatic ACM certificate provisioning with DNS validation
- Certificate renewal automation
- Certificate domain validation workflows
- Reason: Certificate creation requires DNS validation loop and is complex enough for separate feature

**Multiple Custom Domains:**
- Support for multiple custom domains per service via array syntax
- Different domains for different functions or endpoints
- Domain routing logic based on request characteristics
- Reason: Single domain support matches current Serverless Framework pattern; multi-domain is future enhancement

**Custom TLS Configuration:**
- TLS version specification (TLS 1.0, 1.1, 1.2, 1.3)
- Security policy selection for API Gateway domain
- Custom cipher suite configuration
- Reason: AWS defaults are sufficient for initial implementation; advanced TLS configuration is enhancement

**PRIVATE Endpoint VPC Configuration:**
- VPC endpoint creation for PRIVATE endpoint type
- VPC endpoint service configuration
- Private DNS settings for VPC
- Reason: PRIVATE endpoints require VPC infrastructure setup beyond domain configuration scope

**Domain Availability Checking:**
- Pre-flight checks for domain name conflicts in API Gateway
- Domain ownership validation before creation
- Existing domain detection and handling
- Reason: AWS API Gateway naturally handles conflicts; let Terraform error surface AWS validation

**DNS Propagation Management:**
- Waiting for DNS propagation after record creation
- Health checks to verify domain resolution
- Automatic retry on DNS resolution failures
- Reason: DNS propagation is operational concern outside IaC scope

**CloudFront Custom Domains:**
- Custom domains for CloudFront distributions (separate from API Gateway)
- CloudFront alternate domain names (CNAMEs)
- CloudFront SSL certificate configuration
- Reason: Covered separately in roadmap item #11 (CloudFront Distribution Support)

**Domain Transfer Operations:**
- Route 53 domain registration
- Domain transfer from other registrars
- Domain renewal management
- Reason: Domain registration is separate service concern outside module scope

**DNSSEC Configuration:**
- DNSSEC signing for hosted zones
- DNSSEC validation configuration
- KMS key management for DNSSEC
- Reason: Advanced DNS security feature not required for basic custom domain setup

**Non-API Gateway Domain Mapping:**
- Custom domains for Lambda function URLs
- Custom domains for Application Load Balancers
- Custom domains for CloudFront (covered in roadmap #11)
- Reason: Scope limited to API Gateway integration per roadmap item description

## Success Criteria

**Configuration Parsing Success:**
- Module correctly parses provider.customDomain block from serverless.yml
- All customDomain fields extracted and accessible (domainName, basePath, stage, etc.)
- Module handles absence of customDomain gracefully (no resources created)
- Defaults applied correctly (createRoute53Record=true, endpointType="EDGE")

**Route 53 Integration Success:**
- Module creates Route 53 hosted zone when create_hosted_zone=true and hostedZoneId not provided
- Module looks up existing hosted zone when hostedZoneId provided
- Module creates ALIAS records pointing to API Gateway endpoint when createRoute53Record=true
- Module skips record creation when createRoute53Record=false
- ALIAS records correctly reference CloudFront or regional endpoints based on endpointType

**API Gateway Domain Creation Success:**
- Module creates aws_api_gateway_domain_name resource with correct certificate and endpoint type
- EDGE endpoints use CloudFront distribution outputs
- REGIONAL endpoints use regional domain name outputs
- Domain name resource references API Gateway REST API from roadmap #4

**Base Path Mapping Success:**
- Module creates base path mapping connecting domain to API Gateway stage
- Mapping uses stage from customDomain.stage or falls back to provider.stage
- Base path correctly applied from customDomain.basePath when specified
- Empty/null base path handled correctly (root path mapping)

**Certificate Management Success:**
- Module uses certificate from customDomain.certificateArn when provided
- Module falls back to acm_certificate_arn module variable when config doesn't specify
- Module errors clearly when no certificate provided from either source
- Certificate ARN format validated before resource creation

**Certificate Region Validation Success:**
- Module validates EDGE endpoints require us-east-1 certificate
- Module validates REGIONAL endpoints require same-region certificate as API
- Module provides clear error message on certificate region mismatch
- Module extracts region from certificate ARN correctly

**Validation Success:**
- Module validates domain name format (valid DNS hostname)
- Module validates base path format (no leading/trailing slashes, valid characters)
- Module validates endpointType is one of EDGE/REGIONAL/PRIVATE
- Module validates hostedZoneId format if provided
- Module collects all validation errors and displays together (not one-at-a-time)
- Error messages are clear, actionable, and reference specific fields

**Output Interface Success:**
- All six outputs populated correctly when custom domain configured
- Outputs return null when customDomain not configured
- custom_domain_target provides DNS target for manual setup scenarios
- route53_record_fqdn shows created DNS record or null if not created
- Outputs usable by external modules or downstream resources

**API Gateway Integration Success:**
- Custom domain resources only created when API Gateway module (roadmap #4) enabled
- Module references correct REST API ID and stage name from API Gateway outputs
- Base path mapping successfully links domain to deployed API stage
- HTTP requests to custom domain route to API Gateway functions

**Conditional Resource Creation Success:**
- No custom domain resources created when customDomain block absent
- Resources created only when enable_custom_domain=true
- Route 53 zone creation respects create_hosted_zone flag
- DNS record creation respects createRoute53Record flag

**Error Handling Success:**
- Clear error when certificate ARN missing from both sources
- Clear error when hosted zone cannot be determined
- Clear error when API Gateway not configured (roadmap #4 dependency)
- Terraform plan fails fast with all errors collected and displayed together

## Testing Requirements

While test implementation is out of scope for this specification, the following test scenarios must be covered:

**Valid Configuration Tests:**
- Create custom domain with existing hosted zone (hostedZoneId provided)
- Create custom domain with new hosted zone (create_hosted_zone=true)
- Create custom domain with base path mapping
- Create custom domain without base path (null/empty)
- Use EDGE endpoint with us-east-1 certificate
- Use REGIONAL endpoint with same-region certificate
- Skip Route 53 record creation (createRoute53Record=false)
- Provide certificate via customDomain.certificateArn
- Provide certificate via acm_certificate_arn module variable
- Use stage from customDomain.stage
- Use stage from provider.stage (fallback)

**Invalid Configuration Tests:**
- Missing certificateArn from both config and module variable (expect error)
- Certificate in wrong region for EDGE endpoint (expect error)
- Certificate in wrong region for REGIONAL endpoint (expect error)
- Invalid domain name format (expect error)
- Invalid base path with leading slash (expect error)
- Invalid base path with trailing slash (expect error)
- Invalid base path with special characters (expect error)
- Invalid endpointType value (expect error)
- Invalid hostedZoneId format (expect error)
- Missing hostedZoneId without create_hosted_zone enabled (expect error)
- API Gateway not configured - roadmap #4 missing (expect error)

**Integration Tests:**
- Custom domain resolves to API Gateway endpoint via DNS
- Base path mapping routes requests to correct API stage
- EDGE endpoint uses CloudFront distribution
- REGIONAL endpoint uses regional API Gateway domain
- Multiple stages using different base paths on same domain
- Route 53 ALIAS record points to correct target
- Certificate validates successfully for domain

**Edge Cases:**
- Domain name is subdomain (e.g., api.example.com)
- Domain name is apex/root domain (e.g., example.com)
- Empty base path string vs null base path
- Stage name with hyphens and numbers
- Long domain names near DNS limits (253 characters)
- HostedZoneId provided for zone in different AWS account (cross-account)

**Conditional Resource Tests:**
- No customDomain block in serverless.yml (no resources created)
- enable_custom_domain=false (no resources created)
- createRoute53Record=false (domain created, no DNS record)
- create_hosted_zone=false and no hostedZoneId (error)

## Non-Functional Requirements

**Maintainability:**
- Clear separation between Route 53 resources (`route53.tf`) and API Gateway resources (`main.tf`)
- Validation logic isolated in `validation.tf` for readability
- Descriptive local value names (hosted_zone_id, certificate_arn, domain_name_target)
- Comments explaining certificate region extraction and endpoint type logic

**Extensibility:**
- Module structure supports future multi-domain feature (array of customDomain configs)
- Output interface supports additional domain metadata without breaking changes
- Validation framework extensible for additional certificate checks (e.g., expiration)
- TLS configuration can be added to domain name resource in future enhancement

**Documentation:**
- Clear variable descriptions explaining certificate requirements
- Output descriptions indicating when values are null
- Inline comments for certificate region validation logic
- Reference to Mermaid diagrams for architecture visualization

**Performance:**
- DNS lookups for existing hosted zones cached by Terraform during plan phase
- Validation runs during plan phase (no runtime overhead)
- No external API calls beyond standard Terraform AWS provider operations

**Security:**
- Certificate ARN not exposed in error messages (prevent information disclosure)
- Hosted zone ID validated for format before AWS API calls
- No sensitive data in Terraform state (certificates, domain names are non-sensitive)
- ALIAS records use evaluate_target_health for automatic failover

**Compatibility:**
- Works with Terraform 1.13.4+ (existing version constraint)
- Compatible with AWS provider 6.0+ (existing constraint)
- Matches Serverless Framework customDomain configuration schema
- No platform-specific dependencies (cross-platform)

**Usability:**
- Error messages reference specific fields (customDomain.domainName, customDomain.basePath)
- Clear guidance on certificate region requirements for endpoint types
- Outputs provide DNS target for users who prefer manual DNS setup
- Default values match Serverless Framework behavior (familiar to users)

## Dependencies and Assumptions

**Dependencies:**
- Roadmap item #4 (API Gateway REST API Integration) must be implemented and enabled
- Terraform 1.13.4 or higher installed
- AWS provider 6.0 or higher configured
- Null provider 3.0 or higher for validation resources
- Valid serverless.yml with provider.customDomain block (optional)
- ACM certificate already provisioned in appropriate region
- Route 53 hosted zone exists OR create_hosted_zone permission granted

**Assumptions:**
- Users have ACM certificate created before running Terraform (manual step)
- Certificate domain matches or is wildcard for custom domain
- Users understand EDGE vs REGIONAL endpoint differences
- Certificate in correct region for endpoint type (validated by module)
- API Gateway REST API deployed with stage (from roadmap #4)
- Users have Route 53 permissions for zone and record management
- DNS propagation after record creation is acceptable delay (no waiting)
- Users managing certificate lifecycle outside this module

**Future Considerations:**
- Multi-domain support will require array syntax for provider.customDomain (not in Serverless Framework currently)
- ACM certificate creation module could integrate with this module in future
- Custom TLS policies could be added via additional customDomain fields
- PRIVATE endpoint support could be extended with VPC endpoint module integration
- Domain validation (ownership checks) could be added if required for compliance

## References

**Planning Documents:**
- Requirements: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-route53-custom-domain/planning/requirements.md`
- Raw Idea: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-route53-custom-domain/planning/raw-idea.md`

**Visual Assets:**
- Custom Domain Architecture: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-route53-custom-domain/planning/visuals/custom-domain-architecture.md`
- Domain Creation Flow: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-route53-custom-domain/planning/visuals/domain-creation-flow.md`
- Configuration Mapping: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-route53-custom-domain/planning/visuals/configuration-mapping.md`
- DNS Record Types: `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-route53-custom-domain/planning/visuals/dns-record-types.md`

**Product Documentation:**
- Mission: `/home/tom/p/t/sls.tf/agent-os/product/mission.md`
- Roadmap: `/home/tom/p/t/sls.tf/agent-os/product/roadmap.md` (item #12)
- Tech Stack: `/home/tom/p/t/sls.tf/agent-os/product/tech-stack.md`

**Related Specifications:**
- Core Module (Roadmap #1): `/home/tom/p/t/sls.tf/agent-os/specs/2025-10-26-core-module-structure-yaml-parsing/spec.md`
- API Gateway Integration (Roadmap #4): Required dependency for custom domain resources

**External References:**
- Serverless Framework Custom Domain Documentation: https://www.serverless.com/framework/docs/providers/aws/events/apigateway#custom-domain
- AWS API Gateway Custom Domain Names: https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-custom-domains.html
- AWS Route 53 ALIAS Records: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html
- AWS ACM Certificate Requirements: https://docs.aws.amazon.com/acm/latest/userguide/acm-regions.html
- Terraform aws_api_gateway_domain_name: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_domain_name
- Terraform aws_route53_record: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record

## Implementation Notes

**Development Order:**
1. Create modules/custom-domain/ directory structure
2. Define input variables in variables.tf (domain_config, api_gateway_rest_api, etc.)
3. Implement certificate ARN resolution logic in locals.tf
4. Implement certificate region extraction and validation in validation.tf
5. Implement Route 53 hosted zone lookup data source in data.tf
6. Implement Route 53 zone creation resource in route53.tf (conditional)
7. Implement API Gateway domain name resource in main.tf
8. Implement base path mapping resource in main.tf
9. Implement Route 53 ALIAS record resource in route53.tf (conditional)
10. Implement validation error collection and enforcement
11. Implement all module outputs in outputs.tf
12. Integrate module into root main.tf with conditional count
13. Test with valid configurations (all endpoint types, with/without zones)
14. Test validation errors (certificate mismatches, missing fields)
15. Verify outputs match expected values for each scenario

**Key Implementation Challenges:**
- Certificate region extraction from ARN string (use split and indexing)
- Conditional hosted zone resolution (lookup vs create vs config)
- Endpoint type-specific outputs (CloudFront vs regional)
- Base path mapping with optional base path (handle null gracefully)
- Validation error collection across multiple validation categories
- Integration with API Gateway module outputs (dependency management)

**Code Quality Guidelines:**
- Run `terraform fmt` on all .tf files in modules/custom-domain/
- Use descriptive local value names matching domain concepts
- Add comments explaining certificate region validation logic
- Keep validation rules readable (one condition per error item)
- Follow Terraform naming conventions (snake_case for all identifiers)
- Document why ALIAS records used instead of A records (AWS-native, no query limits)

**Testing Approach:**
- Create example configurations in tests/ directory for each scenario
- Test with us-east-1 certificate for EDGE endpoint
- Test with us-west-2 certificate for REGIONAL endpoint in us-west-2
- Test validation errors display all issues together
- Verify domain resolution with `dig` or `nslookup` after apply
- Test base path routing with curl to custom domain
- Verify outputs populated correctly for each configuration variant

---

**This specification is ready for implementation.** Developers should reference the visual diagrams in the planning/visuals/ directory for architecture understanding and consult the requirements.md document for detailed Q&A context. The specification depends on roadmap item #4 (API Gateway REST API Integration) being implemented first.
