# Spec Requirements: Route 53 & Custom Domain Management

## Initial Description

Provision aws_route53_zone and aws_route53_record resources from Serverless customDomain configuration, with automatic API Gateway domain name and base path mapping creation.

This is roadmap item #12 for sls.tf, a Terraform module that bridges Serverless Framework configuration syntax with Terraform-managed AWS infrastructure.

## Requirements Discussion

### First Round Questions

**Q1: What Serverless Framework custom domain configuration should we support?**
**Answer:** Support the `provider.customDomain` configuration block which includes:
- `domainName` (string, required): The custom domain name (e.g., "api.example.com")
- `basePath` (string, optional): Base path mapping (e.g., "v1")
- `stage` (string, optional): Stage for the domain (defaults to provider.stage)
- `createRoute53Record` (boolean, optional, default true): Whether to create DNS record
- `certificateArn` (string, optional): ARN of ACM certificate
- `hostedZoneId` (string, optional): Route 53 hosted zone ID
- `endpointType` (string, optional, default "EDGE"): API Gateway endpoint type (EDGE, REGIONAL, PRIVATE)

**Q2: Should we create the hosted zone or assume it exists?**
**Answer:** Support both modes:
- If `hostedZoneId` is provided: use existing hosted zone (lookup via data source)
- If `hostedZoneId` is not provided: create new hosted zone from domainName
- Add module variable `create_hosted_zone` (default false) to control creation

**Q3: How should we handle ACM certificate management?**
**Answer:** Certificate management has two modes:
- If `certificateArn` is provided: use existing certificate
- If `certificateArn` is not provided: require user to provide via module variable or fail with clear error
- Do NOT create certificates automatically (out of scope - requires DNS validation)
- Add module variable `acm_certificate_arn` to allow override

**Q4: What API Gateway resources do we need to create?**
**Answer:** Create the following resources for custom domain:
- `aws_api_gateway_domain_name`: Custom domain configuration
- `aws_api_gateway_base_path_mapping`: Maps domain to API stage
- `aws_route53_record`: DNS A record (if createRoute53Record is true)
- Link to API Gateway REST API created by roadmap item #4

**Q5: Should we support multiple domains per service?**
**Answer:** No, keep it simple for this roadmap item. Support single custom domain per service defined in provider.customDomain. Future enhancement can add support for multiple domains via array syntax.

**Q6: How should we handle regional vs edge-optimized endpoints?**
**Answer:** Respect the `endpointType` configuration:
- EDGE: Creates CloudFront distribution (edge-optimized, certificate must be in us-east-1)
- REGIONAL: Regional endpoint (certificate in same region as API)
- PRIVATE: VPC endpoint (requires VPC configuration)
- Default to EDGE to match Serverless Framework behavior
- Validate certificate region matches endpoint type requirements

**Q7: What validation should we perform?**
**Answer:** Validate:
- Required field: `domainName` must be valid DNS name format
- Required: ACM certificate must be provided (via config or module variable)
- Certificate region validation: EDGE requires us-east-1, REGIONAL requires API region
- BasePath format: no leading/trailing slashes, alphanumeric with hyphens
- EndpointType: must be one of EDGE, REGIONAL, PRIVATE
- HostedZoneId format if provided

**Q8: How should we handle domain name conflicts?**
**Answer:** Let AWS API Gateway handle conflicts naturally - Terraform will error if domain already exists. Don't add custom conflict detection. User should manage domain lifecycle explicitly.

**Q9: Should we support custom domain for non-API Gateway resources?**
**Answer:** No, scope is limited to API Gateway REST API integration only. CloudFront domains (roadmap #11) and other services are separate concerns.

**Q10: What outputs should we provide?**
**Answer:** Output:
- `domain_name`: The custom domain name
- `domain_name_target`: The CloudFront/regional endpoint target (for manual DNS setup)
- `domain_name_hosted_zone_id`: The Route 53 zone ID used
- `base_path_mapping_id`: The base path mapping resource ID
- `route53_record_fqdn`: The FQDN of the created DNS record (if created)

### Follow-up Questions - Round 2

**Q11: Should we support Route 53 alias records or A records?**
**Answer:** Use Route 53 ALIAS records, not A records. Alias records are AWS-native, don't count against Route 53 query limits, and automatically update if the target changes. Point alias to the API Gateway domain name target.

**Q12: How should we handle base path conflicts?**
**Answer:** API Gateway base path mappings must be unique per domain. Let AWS handle validation - Terraform will error if conflict exists. Don't add custom validation.

**Q13: What happens if API Gateway REST API doesn't exist?**
**Answer:** This feature depends on roadmap item #4 (API Gateway REST API Integration). Module should reference the REST API ID and stage outputs from that module. If API Gateway module not enabled, custom domain resources should not be created (conditional creation based on module variables).

**Q14: Should we handle DNS propagation waiting?**
**Answer:** No, DNS propagation is an operational concern. Create the Route 53 record and let normal DNS propagation happen. Don't add artificial delays or waiters.

**Q15: How should we handle subdomain extraction for hosted zones?**
**Answer:** If creating a new hosted zone and domainName is a subdomain (e.g., "api.example.com"), create zone for the exact domain provided. Don't try to extract parent domain. User should manage zone hierarchy explicitly.

### Follow-up Questions - Round 3

**Q16: Should we validate ACM certificate domain matches custom domain?**
**Answer:** No, skip certificate domain validation. AWS API Gateway will validate this when creating the domain name. Let AWS handle domain/certificate matching errors naturally with its own error messages.

**Q17: How do we handle stage-specific domains?**
**Answer:** Base path mapping connects domain to specific API stage. Use `stage` field from customDomain config (or fall back to provider.stage). Each stage can have its own base path (e.g., /dev, /prod) or separate domains entirely.

**Q18: Should we support custom TLS configuration?**
**Answer:** Not in this phase. Use API Gateway defaults for TLS version and security policy. Future enhancement can add support for securityPolicy configuration.

## Visual Assets

### Files Provided:
No image/screenshot visual assets provided by user.

### Generated Visual Documentation:
Create Mermaid diagram documentation files:
- `custom-domain-architecture.md`: Shows relationship between Route 53, ACM, API Gateway domain, and base path mapping
- `domain-creation-flow.md`: Decision tree for creating vs using existing hosted zones and certificates
- `configuration-mapping.md`: Maps Serverless Framework customDomain fields to Terraform resources
- `dns-record-types.md`: Illustrates ALIAS record structure pointing to API Gateway

### Visual Insights:
The diagrams should illustrate:
- Hosted zone lookup vs creation logic
- ACM certificate requirement and regional constraints
- API Gateway domain name resource structure
- Base path mapping connecting domain to API stage
- Route 53 ALIAS record creation conditional logic
- Edge-optimized vs regional endpoint differences

**Fidelity Level:** Technical architecture diagrams (Mermaid format for maintainability)

## Requirements Summary

### Functional Requirements

**Custom Domain Parsing:**
- Parse `provider.customDomain` configuration block from serverless.yml
- Extract required field: `domainName`
- Extract optional fields: `basePath`, `stage`, `createRoute53Record`, `certificateArn`, `hostedZoneId`, `endpointType`
- Apply defaults: `createRoute53Record = true`, `endpointType = "EDGE"`, `stage = provider.stage`

**Route 53 Hosted Zone Management:**
- If `hostedZoneId` provided: lookup existing hosted zone using `data.aws_route53_zone`
- If `hostedZoneId` not provided and `create_hosted_zone = true`: create `aws_route53_zone` for domainName
- If `hostedZoneId` not provided and `create_hosted_zone = false`: error with message to provide hostedZoneId
- Accept module variable `create_hosted_zone` (bool, default false)

**ACM Certificate Handling:**
- If `certificateArn` provided in config: use that certificate
- If `certificateArn` not provided in config: use module variable `acm_certificate_arn`
- If neither provided: error with message requiring certificate ARN
- Validate certificate region matches endpoint type:
  - EDGE endpoint: certificate must be in us-east-1
  - REGIONAL endpoint: certificate must be in same region as API
  - PRIVATE endpoint: certificate must be in same region as API

**API Gateway Domain Name Creation:**
- Create `aws_api_gateway_domain_name` resource with:
  - `domain_name`: from customDomain.domainName
  - `certificate_arn`: from certificate resolution logic above
  - `endpoint_configuration.types`: [customDomain.endpointType]
  - For EDGE: use `cloudfront_zone_id` and `cloudfront_domain_name` outputs
  - For REGIONAL: use `regional_zone_id` and `regional_domain_name` outputs

**Base Path Mapping Creation:**
- Create `aws_api_gateway_base_path_mapping` resource with:
  - `domain_name`: reference to aws_api_gateway_domain_name
  - `api_id`: reference to REST API ID from roadmap #4 module
  - `stage_name`: from customDomain.stage or provider.stage
  - `base_path`: from customDomain.basePath (if provided)

**Route 53 Record Creation:**
- If `customDomain.createRoute53Record = true`:
  - Create `aws_route53_record` with type ALIAS
  - Point to API Gateway domain name target (cloudfront or regional)
  - Use appropriate zone_id from API Gateway domain name
  - Set `evaluate_target_health = true`
- If `customDomain.createRoute53Record = false`:
  - Skip record creation
  - Output target for manual DNS setup

**Conditional Resource Creation:**
- Only create custom domain resources if `provider.customDomain` is defined
- Custom domain requires API Gateway REST API (roadmap #4) to exist
- Add module variable `enable_custom_domain` (bool, default false) for explicit control

**Configuration Validation:**
- Validate `domainName` format: valid DNS hostname pattern
- Validate `basePath` format: no leading/trailing slashes, alphanumeric with hyphens/underscores
- Validate `endpointType`: must be "EDGE", "REGIONAL", or "PRIVATE"
- Validate `hostedZoneId` format: starts with "Z" followed by alphanumeric
- Validate ACM certificate ARN format: arn:aws:acm:region:account:certificate/id
- Validate certificate region matches endpoint type requirements

**Output Generation:**
- Output `custom_domain_name`: The configured domain name (or null if not configured)
- Output `custom_domain_target`: CloudFront or regional endpoint target
- Output `custom_domain_hosted_zone_id`: Route 53 hosted zone ID
- Output `custom_domain_base_path`: Configured base path (or null)
- Output `route53_record_fqdn`: FQDN of created DNS record (or null if not created)
- Output `api_gateway_domain_name_id`: Resource ID for reference

### Reusability Opportunities

**Leverage Existing Module Patterns:**
- Use conditional resource creation pattern from existing modules
- Use validation error collection pattern from core module (roadmap #1)
- Reference API Gateway REST API outputs from roadmap #4 module
- Follow module output interface patterns

**Existing Code to Reference:**
Similar features in existing specs:
- Core module validation patterns (roadmap #1 spec)
- API Gateway integration patterns (roadmap #4 spec)
- Conditional resource creation based on configuration presence

### Scope Boundaries

**In Scope:**
- Parse `provider.customDomain` configuration from serverless.yml
- Create/lookup Route 53 hosted zones
- Create API Gateway custom domain name resource
- Create API Gateway base path mapping
- Create Route 53 ALIAS record (conditional)
- Validate domain name, certificate, and configuration
- Support EDGE, REGIONAL, and PRIVATE endpoint types
- Certificate ARN resolution from config or module variables
- Stage-specific base path mappings
- Conditional resource creation based on module variables

**Out of Scope (Future Roadmap):**
- ACM certificate creation and DNS validation
- Multiple custom domains per service (array support)
- Custom TLS/security policy configuration
- Domain name validation or availability checking
- DNS propagation waiting or health checks
- CloudFront distribution custom domains (separate - roadmap #11)
- Custom domain for non-API Gateway services (Lambda URLs, ALB, etc.)
- Domain transfer or registration operations
- DNSSEC configuration
- Route 53 private hosted zones for PRIVATE endpoint type
- VPC endpoint configuration for PRIVATE endpoint type

### Technical Considerations

**Terraform Resources Used:**
- `data.aws_route53_zone`: Lookup existing hosted zone
- `aws_route53_zone`: Create new hosted zone (conditional)
- `aws_route53_record`: Create ALIAS record (conditional)
- `aws_api_gateway_domain_name`: Custom domain configuration
- `aws_api_gateway_base_path_mapping`: Connect domain to API stage
- Reference to `aws_api_gateway_rest_api` from roadmap #4
- Reference to `aws_api_gateway_deployment` from roadmap #4

**Serverless Framework Compatibility:**
- Match `provider.customDomain` configuration structure
- Default `endpointType = "EDGE"` matches Serverless Framework
- Default `createRoute53Record = true` matches framework behavior
- Support stage-specific domain configuration

**Certificate Region Constraints:**
- Edge-optimized endpoints require ACM certificate in us-east-1 (CloudFront requirement)
- Regional endpoints require certificate in same region as API
- Validation should check certificate region matches endpoint type
- Use AWS provider data source to lookup certificate details if needed

**API Gateway Integration:**
- Depends on REST API resource from roadmap #4
- Requires API ID and stage name from deployment
- Base path mapping connects domain to specific stage
- Multiple stages can use same domain with different base paths

**DNS Considerations:**
- Use ALIAS records (AWS-native, no query charges)
- Point to appropriate target based on endpoint type:
  - EDGE: CloudFront distribution domain
  - REGIONAL: Regional API Gateway domain
  - PRIVATE: VPC endpoint domain
- Set `evaluate_target_health = true` for automatic failover

**Module Variables:**
- `enable_custom_domain` (bool, default false): Enable custom domain creation
- `create_hosted_zone` (bool, default false): Create Route 53 zone if hostedZoneId not in config
- `acm_certificate_arn` (string, optional): Override certificate ARN
- Configuration from serverless.yml takes precedence over module variables

**Validation Strategy:**
- Validate before resource creation using Terraform validation blocks
- Collect validation errors and display together
- Certificate region validation using data source lookup
- Domain name DNS format validation using regex
- Base path format validation (no slashes, valid characters)

**Error Handling:**
- Missing certificate: Clear error with instructions to provide ARN
- Certificate region mismatch: Error with details on edge vs regional requirements
- Missing hosted zone: Error with instructions to provide hostedZoneId or enable creation
- Invalid domain format: Error with regex pattern explanation
- API Gateway not configured: Error indicating roadmap #4 dependency

**Conditional Logic:**
- Create resources only if `enable_custom_domain = true`
- Create hosted zone only if `create_hosted_zone = true` and `hostedZoneId` not provided
- Create Route 53 record only if `createRoute53Record = true`
- Different domain name outputs based on endpoint type

**File Organization:**
```
sls.tf/
├── modules/
│   └── custom-domain/
│       ├── main.tf              # Custom domain resources
│       ├── variables.tf         # Module input variables
│       ├── outputs.tf           # Domain outputs
│       ├── data.tf              # Route 53 zone lookup
│       └── validation.tf        # Certificate and config validation
└── main.tf                      # Root module invoking custom-domain module
```

**Integration Pattern:**
```hcl
module "custom_domain" {
  source = "./modules/custom-domain"

  count = var.enable_custom_domain ? 1 : 0

  domain_config        = local.provider_with_defaults.customDomain
  api_gateway_rest_api = module.api_gateway[0].rest_api
  api_gateway_stage    = module.api_gateway[0].stage_name
  create_hosted_zone   = var.create_hosted_zone
  acm_certificate_arn  = var.acm_certificate_arn
}
```

## Testing Considerations (Not in Scope for Implementation)

**Valid Configuration Tests:**
- Create domain with existing hosted zone (hostedZoneId provided)
- Create domain with new hosted zone (create_hosted_zone = true)
- Create domain with base path mapping
- Create domain without base path (empty string)
- Use EDGE endpoint type with us-east-1 certificate
- Use REGIONAL endpoint type with regional certificate
- Skip Route 53 record creation (createRoute53Record = false)

**Invalid Configuration Tests:**
- Missing certificateArn (both config and module variable)
- Certificate in wrong region for endpoint type
- Invalid domain name format
- Invalid base path format (with slashes)
- Invalid endpointType value
- Missing hostedZoneId without create_hosted_zone enabled
- API Gateway not configured (roadmap #4 missing)

**Integration Tests:**
- Domain connects to correct API Gateway stage
- Base path mapping routes requests correctly
- Route 53 ALIAS record resolves to correct target
- Certificate validates for domain
- Multiple stages with different base paths

**Edge Cases:**
- Domain name is subdomain (e.g., api.example.com)
- Domain name is apex (e.g., example.com)
- Empty base path vs null base path
- Stage name with special characters
- Long domain names (DNS limits)
