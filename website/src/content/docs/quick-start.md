---
title: Quick Start
description: Get up and running with sls.tf in just a few minutes.
sidebar:
  order: 2
---

# Quick Start

Get your Serverless Framework application running with Terraform in just a few minutes!

## Prerequisites

Before you begin, make sure you have:

- **Terraform** >= 1.0.0 installed
- **Node.js** >= 14.0.0 (for TypeScript support)
- **AWS CLI** configured with appropriate permissions
- **Existing Serverless Framework** configuration

## Step 1: Add sls.tf to Your Project

### Using Git Submodule (Recommended)

```bash
# Add sls.tf as a git submodule
git submodule add https://github.com/your-org/sls.tf.git modules/sls.tf

# Initialize the submodule
git submodule update --init --recursive
```

### Using Direct Copy

```bash
# Copy the sls.tf module to your project
cp -r /path/to/sls.tf ./modules/sls.tf
```

## Step 2: Create Your Terraform Configuration

Create a `main.tf` file:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# Add the sls.tf module
module "serverless_service" {
  source = "./modules/sls.tf"

  # Path to your Serverless Framework configuration
  config_path = "${path.module}/serverless.yml"

  # Path to your Lambda function code
  lambda_code_path = "${path.module}/src"

  # Optional: Override AWS region
  # aws_region = "us-west-2"
}

# Outputs
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

## Step 3: Prepare Your Serverless Configuration

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
    handler: handler.hello
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
        TableName: my-awesome-table
        AttributeDefinitions:
          - AttributeName: id
            AttributeType: S
        KeySchema:
          - AttributeName: id
            KeyType: HASH
        BillingMode: PAY_PER_REQUEST
```

## Step 4: Create Your Lambda Handler

Create `src/handler.js`:

```javascript
'use strict';

module.exports.hello = async (event) => {
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

## Step 5: Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Deploy your infrastructure
terraform apply
```

Terraform will show you exactly what resources will be created before deploying.

## Step 6: Test Your Deployment

Once the deployment is complete, test your API:

```bash
# Get the API Gateway URL from Terraform outputs
API_URL=$(terraform output -raw api_gateway_url)

# Test your endpoint
curl "${API_URL}hello"
```

Expected response:
```json
{
  "message": "Hello from sls.tf!",
  "input": { ... }
}
```

## TypeScript Configuration (Optional)

If you prefer TypeScript, create `serverless.ts`:

```typescript
const serverless = {
  service: 'my-typescript-service',
  frameworkVersion: '3',

  provider: {
    name: 'aws',
    runtime: 'nodejs18.x',
    region: 'us-east-1',
    stage: 'dev'
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
  }
};

export default serverless;
```

Update your Terraform configuration:

```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path   = "${path.module}/serverless.ts"
  config_format = "typescript"
  lambda_code_path = "${path.module}/dist"
}
```

## What Happens Behind the Scenes?

sls.tf automatically:

1. **Parses** your Serverless Framework configuration
2. **Validates** all settings and provides helpful error messages
3. **Generates** all necessary AWS resources:
   - Lambda functions with proper IAM roles
   - API Gateway with CORS and stages
   - DynamoDB tables with proper permissions
   - Event source mappings and permissions
   - CloudWatch log groups and monitoring
4. **Packages** your Lambda code
5. **Creates** all the necessary connections between resources

## Common Use Cases

### API Gateway + Lambda

```yaml
functions:
  api:
    handler: src/api.handler
    events:
      - http:
          path: /api/{proxy+}
          method: any
          cors: true
```

### Event-Driven Architecture

```yaml
functions:
  processor:
    handler: src/processor.handle
    events:
      - s3:
          bucket: my-bucket
          event: s3:ObjectCreated:*
          prefix: uploads/
      - stream:
          type: dynamodb
          arn: arn:aws:dynamodb:region:account:table/MyTable
```

### Scheduled Jobs

```yaml
functions:
  cleanup:
    handler: src/cleanup.run
    events:
      - schedule:
          rate: rate(1 hour)
```

### Custom Resources

```yaml
resources:
  Resources:
    MyBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: my-custom-bucket
        PublicAccessBlockConfiguration:
          BlockPublicAcls: true
          BlockPublicPolicy: true
```

## Next Steps

- 📖 **[Configuration Guide](./configuration)** - Learn about all configuration options
- 🚀 **[Examples](../examples/)** - See real-world implementations
- 🔧 **[Advanced Features](../advanced/)** - Explore advanced capabilities
- 📚 **[API Reference](../api/)** - Detailed API documentation

## Troubleshooting

### Common Issues

**Error: "Configuration validation failed"**
- Check your serverless.yml syntax
- Ensure required fields are present
- Review the error message for specific issues

**Error: "Lambda function size exceeds limits"**
- Optimize your dependencies
- Use Lambda layers for shared libraries
- Consider splitting large functions

**Error: "IAM permission denied"**
- Ensure your AWS credentials have sufficient permissions
- Check that the IAM user/role can create the required resources

### Getting Help

- 📖 Check our [documentation](../)
- 🐛 [Report issues on GitHub](https://github.com/your-org/sls.tf/issues)
- 💬 Join our [Discord community](https://discord.gg/your-invite)

<div class="hero-buttons">
  <a href="./configuration" class="btn">Next: Configuration</a>
  <a href="../examples/basic-service" class="btn secondary">View Examples</a>
</div>