---
title: Installation
description: How to install and set up sls.tf for your Serverless Framework projects.
sidebar:
  order: 3
---

# Installation

Get started with sls.tf by adding it to your Serverless Framework project or Terraform configuration.

## Prerequisites

### Required Tools
- **Terraform** >= 1.0.0
- **Node.js** >= 14.0.0 (for TypeScript support only)
- **AWS CLI** configured with appropriate permissions
- **Git** for version control (recommended)

### AWS Permissions
The AWS credentials you use need permissions for:
- Lambda function creation and management
- API Gateway configuration
- DynamoDB table operations
- IAM role and policy management
- S3 bucket operations (for custom resources)
- EventBridge rule and event source management
- CloudWatch Logs for monitoring

## Option 1: Git Submodule (Recommended)

Add sls.tf as a Git submodule to keep it updated easily:

```bash
# Add sls.tf as a git submodule
git submodule add https://github.com/your-org/sls.tf.git modules/sls.tf

# Initialize the submodule
git submodule update --init --recursive
```

Then in your Terraform configuration:

```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"

  # Optional: Override AWS region
  # aws_region = "us-west-2"
}
```

### Update Submodule
When updates are available:

```bash
# Update to latest version
git submodule update --remote --merge

# Or checkout a specific version
cd modules/sls.tf
git checkout v1.0.0
```

## Option 2: Direct Copy

Copy the sls.tf module to your project:

```bash
# Clone the repository
git clone https://github.com/your-org/sls.tf.git modules/sls.tf

# Or copy from local copy
cp -r /path/to/sls.tf ./modules/sls.tf
```

## Option 3: Terraform Registry

Use sls.tf from the Terraform Registry (if published):

```hcl
module "serverless_service" {
  source  = "your-org/sls.tf/aws"
  version = "1.0.0"

  config_path = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"
}
```

## TypeScript Support Dependencies

If you plan to use TypeScript configuration files, install the required dependencies:

```bash
cd modules/sls.tf/scripts
npm install
```

This installs:
- **ts-node** - TypeScript execution engine
- **typescript** - TypeScript compiler
- **js-yaml** - YAML parsing for validation

## Quick Setup

### 1. Create Your Serverless Configuration

Create or update your `serverless.yml`:

```yaml
service: my-awesome-service
frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1
  stage: dev

functions:
  hello:
    handler: src/handler.hello
    events:
      - http:
          path: /hello
          method: get
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

### 2. Create Lambda Handler

Create `src/handler.js`:

```javascript
'use strict';

exports.hello = async (event) => {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify({
      message: 'Hello from sls.tf!',
      input: event,
    }),
  };
};
```

### 3. Configure Terraform

Create `main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "serverless_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"

  providers = {
    aws = aws
  }
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.serverless_service.api_gateway_invoke_url
}

output "lambda_functions" {
  description = "Deployed Lambda function names"
  value       = module.serverless_service.function_names
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.serverless_service.dynamodb_table_names
}
```

## Verify Installation

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Plan Deployment

```bash
terraform plan
```

You should see output similar to:

```
Terraform will perform the following actions:

  # aws_iam_role.lambda_execution_role will be created
  + resource "aws_iam_role.lambda_execution_role" {
  +   + name         = "my-awesome-service-dev-lambda-execution-role"
  +   + assume_role  = false
  +   + managed_policy_arns = [
  +   +   "arn:aws:iam::aws:policy/BasicLambdaExecutionRole"
  +   + ]
  +   + }
  +   + # ... more resources

Plan: 15 to add, 0 to change, 0 to destroy.
```

### 3. Deploy Infrastructure

```bash
terraform apply
```

Terraform will show you exactly what resources will be created before deploying.

### 4. Test Your API

```bash
# Get the API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)

# Test the endpoint
curl "${API_URL}hello"
```

Expected response:

```json
{
  "message": "Hello from sls.tf!",
  "input": {
    "path": "/hello",
    "httpMethod": "GET",
    "headers": {...}
  }
}
```

## TypeScript Configuration (Optional)

If you prefer TypeScript configuration, create `serverless.ts`:

```typescript
import { AwsProvider } from '@serverless/types/aws';

const serverlessConfiguration: Serverless = {
  service: 'my-typescript-service',
  frameworkVersion: '3',

  provider: {
    name: 'aws',
    runtime: 'nodejs18.x',
    region: 'us-east-1',
    stage: 'dev',

    iam: {
      role: {
        statements: [
          {
            Effect: 'Allow',
            Action: [
              'dynamodb:GetItem',
              'dynamodb:PutItem',
              'dynamodb:UpdateItem',
              'dynamodb:DeleteItem'
            ],
            Resource: ['arn:aws:dynamodb:*:*:table/my-data']
          }
        ]
      }
    }
  },

  functions: {
    api: {
      handler: 'dist/index.handler',
      events: [
        {
          http: {
            path: '/{proxy+}',
            method: 'any',
            cors: true
          }
        }
      ]
    }
  },

  plugins: [
    {
      serverless-webpack: {
        webpackConfig: {
          mode: 'development'
        }
      }
    }
  }
};

export default serverlessConfiguration;
```

Update your Terraform configuration for TypeScript:

```hcl
module "serverless_service" {
  source       = "./modules/sls.tf"

  config_path   = "${path.module}/serverless.ts"
  config_format = "typescript"
  lambda_code_path = "${path.module}/dist"
}
```

## Directory Structure

Your project structure should look like this:

```
my-serverless-project/
├── modules/
│   └── sls.tf/                # sls.tf module
├── serverless.yml              # or serverless.ts
├── src/
│   └── handler.js               # Lambda handlers
├── main.tf                    # Terraform configuration
├── terraform.tfstate
├── terraform.tfstate.backup
└── .terraform/
    ├── .terraform.lock.hcl
    └── providers/
```

## Troubleshooting

### Common Issues

#### Error: "No matching version found for rehype-toc"
```bash
# Clean and reinstall
rm -rf node_modules package-lock.json
npm install
```

#### Error: "Could not load content collection"
```bash
# Ensure content files are in correct directories
ls -la src/content/docs/
# Move files if needed
```

#### Error: "Permission denied" when running terraform apply
```bash
# Check AWS credentials
aws sts get-caller-identity

# Configure AWS CLI with proper permissions
aws configure
```

#### Error: "Module not found"
```bash
# Check submodule status
git submodule status

# Update submodule if needed
git submodule update --init --recursive
```

### Getting Help

If you encounter issues with installation:

- 📖 **Documentation**: Browse our comprehensive guides
- 🐛 **GitHub Issues**: [Report problems on GitHub](https://github.com/your-org/sls.tf/issues)
- 💬 **Community**: Join our [Discord server](https://discord.gg/sls-tf)
- 📧 **Email**: Contact support@sls.tf

## Next Steps

- 📖 [Configuration Guide](./configuration) - Learn about all configuration options
- 🚀 [Examples](../examples/) - See real-world implementations
- 🔧 [Advanced Features](../advanced/) - Explore advanced capabilities
- 📚 [API Reference](../api/) - Detailed API documentation

---

<div class="hero-buttons">
  <a href="./configuration" class="btn">Next: Configuration</a>
  <a href="../examples/basic-service" class="btn secondary">View Examples</a>
</div>