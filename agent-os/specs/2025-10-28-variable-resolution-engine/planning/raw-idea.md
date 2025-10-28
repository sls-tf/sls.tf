# Variable Resolution Engine - Raw Idea

**Feature Name:** Variable Resolution Engine

**Raw Idea:**
Implement resolution for Serverless Framework variable syntax (${self:}, ${env:}, ${opt:}, ${cf:}) by mapping them to Terraform variables, local values, and data source lookups where applicable.

The Serverless Framework supports several variable types:
- ${self:path.to.property} - Reference to other properties in the same config
- ${env:VARIABLE_NAME} - Environment variables
- ${opt:option} - CLI options passed to serverless deploy
- ${cf:stackName.outputKey} - CloudFormation stack outputs
- ${ssm:/path/to/param} - AWS Systems Manager parameters
- ${file(./path.json):property} - External file references

The goal is to parse these variables in the serverless.yml configuration and translate them to equivalent Terraform constructs where possible, enabling dynamic configuration and cross-stack references.

**Context:**
- This is feature #11 in the roadmap
- The module already parses YAML configurations successfully
- We need to extend the parsing logic to handle variable interpolation
- Some variable types can be resolved at Terraform plan time, others need runtime resolution
- This is a critical feature for real-world Serverless Framework configurations
