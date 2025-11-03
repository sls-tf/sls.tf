---
title: Introduction
description: Introduction to sls.tf - a comprehensive Terraform module for converting Serverless Framework configurations to AWS infrastructure.
sidebar:
  order: 1
---

# Welcome to sls.tf

sls.tf is a comprehensive Terraform module that converts [Serverless Framework](https://www.serverless.com/) configurations to production-ready AWS infrastructure. It provides a seamless bridge between the simplicity of Serverless Framework YAML and the power of Terraform infrastructure as code.

## What is sls.tf?

sls.tf (pronounced "sls-dot-tee-eff") is a Terraform module that:

- ✅ **Parses Serverless Framework** YAML and TypeScript configuration files
- ✅ **Generates AWS infrastructure** with all the resources you need
- ✅ **Handles complexity** like IAM roles, permissions, and event source mappings
- ✅ **Supports TypeScript** configurations with async exports and dynamic values
- ✅ **Provides validation** to catch configuration errors before deployment
- ✅ **Includes comprehensive testing** and documentation

## Why Use sls.tf?

### 🎯 **For Serverless Framework Users**
- Continue using the familiar Serverless Framework syntax
- Get the benefits of Terraform's state management and planning
- Integrate with existing Terraform workflows and tooling
- Maintain consistency across hybrid Terraform + Serverless environments

### 🏗️ **For Terraform Users**
- Leverage existing Serverless Framework projects
- Use Serverless Framework's rich ecosystem of plugins
- Simplify Lambda function deployment and management
- Get production-ready infrastructure with best practices built-in

### 🚀 **For Organizations**
- Standardize serverless infrastructure deployment
- Enable collaboration between DevOps and development teams
- Improve infrastructure visibility and governance
- Reduce deployment complexity and potential for human error

## Core Features

### 📋 **Configuration Support**
- **YAML configurations** - Standard Serverless Framework syntax
- **TypeScript configurations** - Full async export support with dynamic values
- **Variable resolution** - Handle `${self:}`, `${env:}`, and custom variables
- **Schema validation** - Comprehensive error checking and helpful messages

### ⚡ **Resource Generation**
- **Lambda Functions** - Complete with IAM roles, permissions, and configurations
- **API Gateway** - REST APIs with CORS, custom domains, and deployment stages
- **DynamoDB Tables** - With streams, TTL, PITR, and global secondary indexes
- **Event Sources** - S3, SQS, DynamoDB streams, EventBridge, and scheduled events
- **Custom Resources** - Support for CloudFormation-style resource definitions

### 🔧 **Advanced Features**
- **Variable Resolution Engine** - Handle complex variable references
- **Custom Resource Provisioning** - Support for S3, DynamoDB, SNS, SQS, CloudFront
- **Route 53 Integration** - Automatic DNS management and custom domains
- **LocalStack Support** - Local development and testing infrastructure
- **TypeScript Parser** - Node.js-based external data source for TypeScript files

## Quick Example

### Serverless Framework Configuration
```yaml
service: my-api-service
frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1
  stage: prod

functions:
  api:
    handler: src/handler.handler
    events:
      - http:
          path: /{proxy+}
          method: any
          cors: true

resources:
  Resources:
    MyTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: my-data
        AttributeDefinitions:
          - AttributeName: id
            AttributeType: S
        KeySchema:
          - AttributeName: id
            KeyType: HASH
        BillingMode: PAY_PER_REQUEST
```

### Terraform Usage
```hcl
module "serverless_service" {
  source       = "path/to/sls.tf"
  config_path  = "${path.module}/serverless.yml"

  lambda_code_path = "${path.module}/src"

  providers = {
    aws = aws
  }
}

output "api_gateway_url" {
  value = module.serverless_service.api_gateway_invoke_url
}

output "lambda_functions" {
  value = module.serverless_service.function_names
}
```

## What Makes sls.tf Different?

### 🎨 **Developer Experience**
- **Familiar syntax** - Keep using Serverless Framework YAML
- **Rich error messages** - Clear validation feedback
- **Local development** - Built-in LocalStack integration
- **Comprehensive testing** - Full test suite with fixtures

### 🛡️ **Production Ready**
- **Best practices** - Security hardening and compliance
- **Scalability** - Auto-scaling and performance optimization
- **Monitoring** - Built-in logging and metrics
- **Disaster recovery** - Backup and restore capabilities

### 🔧 **Extensible**
- **Custom resources** - Support for any AWS resource
- **Plugins** - Modular architecture for easy extension
- **Integration** - Works with existing Terraform modules
- **Automation** - CI/CD pipeline integration

## Roadmap

We're constantly improving sls.tf. Here's what we're working on:

### ✅ **Completed**
- Lambda Function Translation
- IAM Role & Policy Management
- API Gateway REST API Integration
- S3 Event Source Mapping
- EventBridge Rules & Schedulers
- DynamoDB & SQS Event Sources
- Custom Resource Provisioning
- LocalStack Integration
- Variable Resolution Engine
- **TypeScript Configuration Parsing** 🎉
- CloudFront Distribution Support
- Route 53 & Custom Domain Management

### 🚧 **In Progress**
- Enhanced monitoring and observability
- Advanced security features
- Performance optimization

### 📋 **Planned**
- Multi-region deployment support
- Cost optimization features
- Advanced CI/CD templates
- Plugin ecosystem

## Getting Started

Ready to dive in? Check out our [Quick Start guide](./quick-start) to get up and running in minutes.

Or, if you prefer to see it in action, head over to our [Examples](../examples/) for common use cases and best practices.

---

<div class="status complete">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
    <polyline points="22 4 12 14.01 9 11.01"></polyline>
  </svg>
  Production Ready
</div>

<div class="badge">
  Terraform 1.0+
</div>

<div class="badge beta">
  TypeScript Support
</div>