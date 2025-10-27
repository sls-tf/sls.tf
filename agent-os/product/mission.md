# Product Mission

## Pitch
sls.tf is a Terraform module that helps DevOps engineers, platform teams, and infrastructure developers bridge the gap between Serverless Framework and Terraform by providing a translation layer that parses Serverless configuration files (serverless.yml or serverless.ts) and generates native AWS resources through Terraform, enabling teams to maintain familiar Serverless Framework developer experience while gaining Terraform's state management, modularity, and GitOps capabilities.

## Users

### Primary Customers
- **Platform Engineering Teams**: Organizations standardizing on Terraform for infrastructure-as-code but want to preserve Serverless Framework patterns for application developers
- **Migrating Organizations**: Companies transitioning from Serverless Framework to Terraform who need a gradual migration path
- **Hybrid Infrastructure Teams**: Teams managing multi-tool environments who want unified state management through Terraform

### User Personas

**Platform Engineer** (28-45 years)
- **Role:** Infrastructure Engineer / DevOps Lead
- **Context:** Managing cloud infrastructure for multiple development teams using Terraform as the primary IaC tool
- **Pain Points:** Developers comfortable with Serverless Framework resist learning HCL; maintaining two separate deployment systems creates operational overhead; lack of unified state management across tools
- **Goals:** Enable developers to use familiar tools while maintaining infrastructure consistency; reduce operational complexity; achieve single source of truth for infrastructure state

**Migration Architect** (30-50 years)
- **Role:** Solutions Architect / Technical Lead
- **Context:** Leading infrastructure modernization from Serverless Framework to Terraform across multiple projects
- **Pain Points:** All-or-nothing migration is too risky; need to maintain existing workflows during transition; rewriting configurations is time-consuming and error-prone
- **Goals:** Incremental, low-risk migration path; preserve existing Serverless configurations; leverage Terraform ecosystem (modules, state backends, policy-as-code)

**Full-Stack Developer** (25-40 years)
- **Role:** Application Developer with infrastructure responsibilities
- **Context:** Building serverless applications, familiar with Serverless Framework conventions
- **Pain Points:** Learning Terraform/HCL syntax is time-consuming; want to focus on application logic, not infrastructure syntax; organization requires Terraform for compliance/governance
- **Goals:** Deploy serverless applications using familiar configuration format; minimal context switching between application and infrastructure code; fast iteration cycles

## The Problem

### Fragmented Infrastructure Tooling
Organizations adopting Terraform for infrastructure standardization face resistance from development teams who have invested in Serverless Framework expertise and workflows. This creates a fragmented tooling landscape where some projects use Serverless Framework while others use Terraform, leading to inconsistent state management, duplicated deployment pipelines, and operational complexity.

**Our Solution:** sls.tf bridges this gap by allowing teams to define serverless applications using Serverless Framework's familiar YAML/TypeScript configuration syntax while Terraform handles the actual resource provisioning, state management, and lifecycle. This provides a gradual migration path and enables teams to unify their infrastructure under Terraform without forcing developers to abandon productive workflows.

### Complex Migration from Serverless Framework to Terraform
Teams migrating from Serverless Framework to Terraform face a difficult choice: maintain two separate systems during transition or perform risky "big bang" rewrites that convert all serverless.yml configurations to HCL. Both approaches are costly and error-prone, with manual translation introducing bugs and inconsistencies.

**Our Solution:** sls.tf eliminates the need for manual configuration translation by automatically parsing Serverless Framework configurations at Terraform apply time and generating the corresponding AWS resources. Teams can immediately adopt Terraform's benefits (state management, modules, policy-as-code) while continuing to use existing serverless.yml or serverless.ts files, enabling low-risk incremental migration.

### Loss of Developer Productivity During IaC Transitions
When organizations mandate Terraform adoption, developers experienced with Serverless Framework must learn HCL syntax, resource schemas, and Terraform patterns before they can deploy infrastructure. This learning curve significantly slows down application development and creates friction between platform teams (who want standardization) and application teams (who want velocity).

**Our Solution:** sls.tf preserves developer productivity by accepting Serverless Framework's high-level, opinionated configuration format that developers already know. Developers can continue using serverless.yml or serverless.ts files with familiar conventions (functions, events, resources) while the module handles translation to low-level AWS resources, removing the HCL learning barrier.

## Differentiators

### Native Terraform Integration, Not a Wrapper
Unlike tools that wrap Terraform or Serverless Framework with orchestration scripts, sls.tf is a pure Terraform module that uses native HCL constructs (dynamic blocks, for_each, yamldecode, external data sources). This means users get full access to Terraform's ecosystem: remote state backends, workspaces, modules, policy-as-code tools (Sentinel, OPA), and existing CI/CD integrations without custom tooling or additional abstractions.

### Configuration Parsing at Apply Time
Most translation tools require a pre-processing step to convert Serverless configurations to Terraform code. sls.tf parses serverless.yml using yamldecode() or serverless.ts using an external data source with ts-node directly during terraform apply. This eliminates the need for generated HCL files, keeps the Serverless configuration as the single source of truth, and ensures changes to serverless.yml/ts are immediately reflected in Terraform state.

### Gradual Migration Path
Unlike migration guides that recommend manual conversion or scripts that generate one-time Terraform code, sls.tf allows teams to run Serverless Framework configurations under Terraform indefinitely. Teams can adopt Terraform's governance, state management, and module system immediately while deferring the learning curve of native HCL authoring. When ready, configurations can be gradually converted to native Terraform resources without disrupting deployments.

### Multi-Format Configuration Support
While most IaC tools support only one configuration format, sls.tf accepts both YAML (serverless.yml) for simplicity and TypeScript (serverless.ts) for type safety, dynamic configuration, and code reuse. TypeScript support enables advanced patterns like programmatic resource generation, environment-specific logic, and shared configuration libraries while maintaining Serverless Framework's familiar structure.

## Key Features

### Core Features
- **Serverless YAML Parsing:** Parse serverless.yml files using Terraform's native yamldecode() function, extracting functions, events, resources, and provider configuration to generate corresponding AWS resources without external tooling dependencies
- **TypeScript Configuration Support:** Parse serverless.ts files via external data source using Node.js/ts-node, enabling type-safe configurations with dynamic logic, environment-specific values, and code reuse patterns familiar to TypeScript developers
- **Lambda Function Management:** Translate Serverless Framework function definitions (handler, runtime, memory, timeout, environment variables, IAM roles) into terraform aws_lambda_function resources with proper IAM role creation and policy attachments
- **API Gateway Provisioning:** Generate AWS API Gateway REST APIs or HTTP APIs from Serverless Framework http events, including route definitions, integrations, authorizers, CORS configuration, and deployment stages

### Event Source Integration
- **S3 Event Triggers:** Create S3 bucket notifications and Lambda permissions from Serverless Framework s3 events, including event type filtering (s3:ObjectCreated, s3:ObjectRemoved) and prefix/suffix filters
- **DynamoDB Streams:** Configure DynamoDB stream event source mappings for Lambda functions with batch size, starting position, and error handling based on Serverless stream event definitions
- **EventBridge Integration:** Provision EventBridge rules and targets from Serverless Framework eventBridge events, supporting both custom event patterns and scheduled expressions (cron/rate)
- **SQS Queue Triggers:** Create SQS event source mappings for Lambda functions with configurable batch size, visibility timeout, and dead-letter queue handling from Serverless queue events

### Resource Management
- **Custom AWS Resources:** Parse and provision additional AWS resources defined in the serverless.yml resources section (S3 buckets, DynamoDB tables, SNS topics, etc.) by translating CloudFormation-like syntax to Terraform resource blocks
- **IAM Role Generation:** Automatically generate IAM roles and policies for Lambda functions based on Serverless Framework iamRoleStatements, converting action and resource declarations to aws_iam_role_policy documents
- **Environment Variable Injection:** Resolve Serverless Framework variable syntax (${self:provider.stage}, ${env:VAR}, ${cf:stack.output}) and inject values into Lambda environment variables, supporting Terraform variable references and local values

### Infrastructure Outputs
- **CloudFront Distribution Support:** Provision CloudFront distributions for static assets or API acceleration from Serverless Framework cloudFront configuration, including origin settings, cache behaviors, and SSL certificates
- **Route 53 DNS Records:** Create Route 53 hosted zones and records from Serverless Framework customDomain configuration, linking domain names to API Gateway endpoints or CloudFront distributions
- **Output Values:** Expose key infrastructure outputs (Lambda ARNs, API Gateway URLs, S3 bucket names, DynamoDB table names) as Terraform outputs for consumption by other modules or external systems
