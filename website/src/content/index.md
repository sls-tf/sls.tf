---
title: Welcome to sls.tf
description: The comprehensive Serverless Framework to Terraform conversion module
layout: ../../layouts/Layout.astro
---

import { Badge } from '@astrojs/starlight/components';

# sls.tf

<div class="hero">
  <h1>Serverless Framework to Terraform</h1>
  <p>Convert your Serverless Framework configurations to production-ready AWS infrastructure with Terraform.</p>

  <div class="hero-buttons">
    <a href="/docs/quick-start" class="btn">Get Started</a>
    <a href="/docs/introduction" class="btn secondary">Learn More</a>
  </div>
</div>

## 🚀 What is sls.tf?

sls.tf is a comprehensive Terraform module that seamlessly converts Serverless Framework YAML and TypeScript configurations into production-ready AWS infrastructure.

<div class="features-grid">
  <div class="feature-card">
    <h3>📋 Parse Serverless Config</h3>
    <p>Support for both YAML and TypeScript configurations with comprehensive validation and error handling.</p>
  </div>

  <div class="feature-card">
    <h3>⚡ Generate Infrastructure</h3>
    <p>Automatically creates Lambda functions, API Gateway, DynamoDB tables, and all necessary AWS resources.</p>
  </div>

  <div class="feature-card">
    <h3>🔧 Advanced Features</h3>
    <p>Variable resolution, custom resources, EventBridge integration, and TypeScript support with async exports.</p>
  </div>

  <div class="feature-card">
    <h3>🛡️ Production Ready</h3>
    <p>Built-in best practices, security hardening, monitoring, and disaster recovery capabilities.</p>
  </div>
</div>

## ✨ Key Features

### Configuration Support
- <Badge>YAML</Badge> Standard Serverless Framework syntax
- <Badge>Powerful</Badge> TypeScript configurations with async exports
- <Badge>Dynamic</Badge> Variable resolution with `${self:}`, `${env:}` support
- <Badge>Validated</Badge> Comprehensive error checking and helpful messages

### Resource Generation
- <Badge>Lambda</Badge> Complete with IAM roles and permissions
- <Badge>API Gateway</Badge> REST APIs with CORS and custom domains
- <Badge>DynamoDB</Badge> Tables with streams, TTL, and global indexes
- <Badge>EventBridge</Badge> Event patterns and rule targeting
- <Badge>Custom</Badge> Support for any CloudFormation resource

### Advanced Capabilities
- <Badge>TypeScript</Badge> Full async export support with dynamic values
- <Badge>Variables</Badge> Complex variable resolution engine
- <Badge>LocalStack</Badge> Local development and testing
- <Badge>CLI Tool</Badge> Elemental service conversion
- <Badge>CloudFront</Badge> Static hosting and CDN distribution

## 🎯 Quick Start

### 1. Add sls.tf to Your Project

```bash
git submodule add https://github.com/your-org/sls.tf.git modules/sls.tf
git submodule update --init --recursive
```

### 2. Create Terraform Configuration

```hcl
module "serverless_service" {
  source       = "./modules/sls.tf"
  config_path  = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"
}
```

### 3. Deploy Your Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

That's it! Your Serverless Framework application is now deployed with all the benefits of Terraform.

## 📚 What's Included

### ✅ Completed Features

<details>
<summary>🔧 Core Infrastructure</summary>

- **Lambda Functions** - Complete translation with IAM roles
- **API Gateway** - REST APIs with CORS and custom domains
- **DynamoDB** - Tables with streams, TTL, and indexes
- **IAM Roles** - Automatic permission management
- **Event Sources** - S3, SQS, DynamoDB streams, schedules
- **Custom Resources** - S3, DynamoDB, SNS, SQS, CloudFront
</details>

<details>
<summary>🚀 Advanced Features</summary>

- **TypeScript Parser** - Node.js-based async export support
- **Variable Resolution** - Complex variable handling
- **EventBridge Integration** - Event patterns and routing
- **Route 53** - DNS and custom domain management
- **LocalStack** - Local development environment
- **CLI Tools** - Service conversion utilities
</details>

### 🎉 Recent Additions

- **Elemental Service Converter** - Convert existing services to Serverless Framework
- **CloudFront Variable Resolution** - Full variable support in static hosting
- **TypeScript Configuration** - Modern configuration with dynamic values
- **Comprehensive Testing** - Full test suite with fixtures
- **Documentation Website** - Complete documentation and examples

## 🛠️ Example: Complete API Service

### Serverless Configuration
```yaml
service: my-api-service
frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1

functions:
  api:
    handler: src/handler.handler
    events:
      - http:
          path: /{proxy+}
          method: any
          cors: true
    environment:
      TABLE_NAME: my-data

resources:
  Resources:
    MyTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: my-data
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: id
            AttributeType: S
        KeySchema:
          - AttributeName: id
            KeyType: HASH
```

### Generated Resources
- ✅ Lambda function with proper IAM role
- ✅ API Gateway with CORS and deployment
- ✅ DynamoDB table with appropriate permissions
- ✅ CloudWatch log groups and monitoring
- ✅ All necessary permissions and connections

## 🚦 Roadmap Status

<div class="status complete">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
    <polyline points="22 4 12 14.01 9 11.01"></polyline>
  </svg>
  Production Ready
</div>

## 🤝 Contributing

We welcome contributions! Here's how you can help:

- 🐛 **Report Issues**: Found a bug? [Create an issue](https://github.com/your-org/sls.tf/issues)
- 💡 **Feature Requests**: Have an idea? [Start a discussion](https://github.com/your-org/sls.tf/discussions)
- 🔧 **Code Contributions**: See our [Contributing Guide](../CONTRIBUTING.md)
- 📖 **Documentation**: Improve docs or add examples

## 📖 Learn More

<div class="hero-buttons">
  <a href="/docs/quick-start" class="btn">Quick Start Guide</a>
  <a href="/docs/examples/basic-service" class="btn secondary">View Examples</a>
  <a href="/docs/features/typescript" class="btn secondary">TypeScript Support</a>
</div>

## 🆘 Need Help?

- 📚 **Documentation**: Browse our comprehensive guides
- 💬 **Community**: Join our [Discord server](https://discord.gg/sls-tf)
- 🐛 **Issues**: [Report problems on GitHub](https://github.com/your-org/sls.tf/issues)
- 📧 **Email**: Contact us at support@sls.tf

---

<div class="status complete">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
    <polyline points="22 4 12 14.01 9 11.01"></polyline>
  </svg>
  Ready to transform your serverless deployment?
</div>