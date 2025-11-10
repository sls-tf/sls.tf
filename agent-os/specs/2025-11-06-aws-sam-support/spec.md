# Specification: AWS SAM Support Integration

## Goal
Add comprehensive AWS SAM (Serverless Application Model) template support to sls.tf, enabling users to parse, validate, and deploy AWS SAM templates using Terraform while maintaining compatibility with existing Serverless Framework functionality.

## User Stories
- As a DevOps engineer, I want to use my existing AWS SAM templates with Terraform workflows so that I can standardize on Terraform across my organization
- As a developer, I want to migrate from Serverless Framework to AWS SAM gradually so that I can adopt AWS SAM features incrementally
- As a platform engineer, I want to validate AWS SAM templates before deployment so that I can catch configuration errors early
- As a security engineer, I want to review IAM permissions generated from SAM templates so that I can ensure security compliance

## Core Requirements
- Parse AWS SAM template.yaml files with Transform: AWS::Serverless-2016-10-31
- Translate AWS::Serverless::Function resources to aws_lambda_function
- Translate AWS::Serverless::Api resources to aws_api_gateway_rest_api
- Support Globals section for default configurations
- Handle SAM template parameters and outputs
- Generate appropriate IAM roles and policies
- Support event source mappings (API, S3, DynamoDB, SQS, EventBridge)
- Integrate with existing variable resolution engine
- Provide comprehensive validation and error handling

## Visual Design
No visual assets provided for this specification. The implementation focuses on backend parsing and resource generation without UI components.

## Reusable Components

### Existing Code to Leverage
- YAML parsing logic from locals.tf using yamldecode()
- Validation pattern from generated validation files
- Lambda function creation patterns from main.tf
- API Gateway resource creation from main.tf
- IAM role and policy generation from main.tf
- Multi-format support pattern from typescript-parser.tf
- Error collection and reporting from locals.tf
- Variable resolution engine from variable_resolution.tf
- LocalStack integration patterns from existing tests

### New Components Required
- **SAM Template Parser**: New parser logic to handle SAM-specific syntax and transform declarations
- **SAM Resource Translator**: Translation layer for SAM resource types to Terraform resources
- **Globals Processor**: Logic to apply global configurations to resources
- **Parameter Resolver**: Template parameter resolution with CloudFormation-like behavior
- **SAM Validation Rules**: SAM-specific validation logic for resource types and properties

## Technical Approach

### Configuration Format Extension
Extend the existing config_format variable to support "sam" option alongside "yaml" and "typescript". Add new variable sam_template_path for SAM template files.

### Parsing Strategy
- Use existing yamldecode() function for template parsing
- Validate Transform declaration for AWS SAM templates
- Process Parameters section with CloudFormation-like resolution
- Apply Globals section defaults to resources
- Parse Resources section for SAM resource types

### Resource Translation Architecture
Create translation mapping for each SAM resource type:
- AWS::Serverless::Function → aws_lambda_function with event source mappings
- AWS::Serverless::Api → aws_api_gateway_rest_api with methods and integrations
- AWS::Serverless::SimpleTable → aws_dynamodb_table with simplified configuration
- AWS::Serverless::LayerVersion → aws_lambda_layer_version

### Validation Integration
Extend existing validation pipeline with SAM-specific rules:
- Template format validation (AWSTemplateFormatVersion, Transform)
- SAM resource type validation
- Property validation for SAM-specific attributes
- Parameter validation and dependency checking

### Variable Resolution Integration
Leverage existing variable resolution engine to handle:
- CloudFormation parameter references (${Param})
- Pseudo variables (${AWS::Region}, ${AWS::AccountId})
- Resource attribute references (!GetAtt, !Ref)

## Implementation Details

### New Variables
```hcl
variable "sam_template_path" {
  description = "Path to AWS SAM template.yaml file"
  type        = string
}

variable "sam_template_parameters" {
  description = "Parameter values for SAM template"
  type        = map(string)
  default     = {}
}

variable "sam_capabilities" {
  description = "CloudFormation capabilities for SAM deployment"
  type        = list(string)
  default     = []
}
```

### New Resources
- SAM template parsing logic in new sam-parser.tf file
- Resource translation logic in new sam-translator.tf file
- SAM-specific validation in new sam-validation.tf file

### Integration Points
- Extend locals.tf to handle SAM template parsing
- Modify main.tf to support translated SAM resources
- Update outputs.tf to expose SAM-specific outputs
- Integrate with existing LocalStack testing framework

## Out of Scope
- Direct CloudFormation deployment (only translation to Terraform)
- AWS SAM CLI integration or local development features
- Visual template design or editing tools
- Multi-region deployment orchestration
- Blue/green deployment strategies
- Cost estimation or optimization features
- SAM template generation from Terraform resources

## Success Criteria
- Parse valid AWS SAM templates without errors
- Generate syntactically correct Terraform configuration
- Deploy translated resources successfully to AWS
- Maintain functional behavior equivalent to original SAM template
- Pass all existing tests and new SAM-specific tests
- Complete validation coverage for SAM resource types
- Clear error messages for invalid SAM templates
- Documentation with migration examples and patterns