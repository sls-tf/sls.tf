---
title: Configuration
description: Complete configuration reference for sls.tf module
sidebar:
  order: 4
---

# Configuration Guide

Learn how to configure sls.tf for your Serverless Framework projects.

## Basic Configuration

### Required Variables

```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  # Path to your Serverless Framework configuration
  config_path = "${path.module}/serverless.yml"

  # Path to your Lambda function code
  lambda_code_path = "${path.module}/src"
}
```

### Optional Variables

```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"

  # Override AWS region (defaults to provider region)
  aws_region = "us-west-2"

  # Environment variables for all functions
  environment = {
    NODE_ENV = "production"
    DEBUG = "false"
  }

  # Tags for all resources
  tags = {
    Project = "my-serverless-app"
    Environment = "production"
    Team = "platform"
  }
}
```

## Configuration File Formats

### YAML Configuration

Standard Serverless Framework YAML format:

```yaml
service: my-service
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
```

### TypeScript Configuration

Modern TypeScript with dynamic values:

```typescript
import { Serverless } from '@serverless/types/aws';

const serverlessConfiguration: Serverless = {
  service: 'my-typescript-service',
  frameworkVersion: '3',

  provider: {
    name: 'aws',
    runtime: 'nodejs18.x',
    region: process.env.AWS_REGION || 'us-east-1',
    stage: process.env.NODE_ENV || 'dev',
  },

  functions: {
    api: {
      handler: 'dist/index.handler',
      environment: {
        TABLE_NAME: `${process.env.SERVICE_NAME}-data`,
        STAGE: process.env.NODE_ENV || 'dev'
      }
    }
  }
};

export default serverlessConfiguration;
```

For TypeScript configurations, set the format:

```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.ts"
  config_format = "typescript"
  lambda_code_path = "${path.module}/dist"
}
```

## Advanced Configuration

### Provider Configuration

```yaml
provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1
  stage: dev

  # Memory and timeout defaults
  memorySize: 256
  timeout: 30

  # VPC configuration
  vpc:
    securityGroupIds:
      - sg-12345678
    subnetIds:
      - subnet-12345678
      - subnet-87654321

  # Environment variables
  environment:
    TABLE_NAME: my-data
    REGION: ${self:provider.region}
```

### IAM Role Configuration

```yaml
provider:
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:Query
            - dynamodb:Scan
            - dynamodb:GetItem
            - dynamodb:PutItem
            - dynamodb:UpdateItem
            - dynamodb:DeleteItem
          Resource:
            - "arn:aws:dynamodb:${self:provider.region}:*:table/${self:service}-${self:provider.stage}-data"
```

### Function Configuration

```yaml
functions:
  api:
    handler: src/api.handler
    description: 'Main API handler'

    # Override provider defaults
    memorySize: 512
    timeout: 60

    # Environment variables
    environment:
      API_VERSION: v1

    # VPC configuration
    vpc:
      securityGroupIds:
        - sg-api-sg
      subnetIds:
        - subnet-private-1
        - subnet-private-2

    # Events
    events:
      - http:
          path: /api/{proxy+}
          method: any
          cors: true

      - schedule:
          rate: rate(5 minutes)
          input:
            action: 'cleanup'
```

## Variable Resolution

sls.tf supports comprehensive variable resolution:

### Self References
```yaml
service: my-service

provider:
  region: us-east-1
  stage: dev

functions:
  hello:
    environment:
      SERVICE_NAME: ${self:service}
      STAGE: ${self:provider.stage}
      REGION: ${self:provider.region}
```

### Environment Variables
```yaml
provider:
  environment:
    NODE_ENV: ${opt:stage, 'dev'}
    DB_HOST: ${env:DB_HOST}
    API_KEY: ${env:API_KEY}
```

### File References
```yaml
provider:
  environment:
    PRIVATE_KEY: ${file(./config/private-key.txt)}
    CONFIG_JSON: ${file(./config/config.json):some.key}
```

### CF Output References
```yaml
provider:
  environment:
    VPC_ID: ${cf:my-vpc-stack.VpcId}
    SUBNET_IDS: ${cf:my-vpc-stack.PrivateSubnetIds}
```

## Resource Configuration

### DynamoDB Tables

```yaml
resources:
  Resources:
    UserData:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:service}-${self:provider.stage}-users
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: userId
            AttributeType: S
          - AttributeName: email
            AttributeType: S
        KeySchema:
          - AttributeName: userId
            KeyType: HASH
        GlobalSecondaryIndexes:
          - IndexName: EmailIndex
            KeySchema:
              - AttributeName: email
                KeyType: HASH
            Projection:
              ProjectionType: ALL
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES
        TimeToLiveSpecification:
          AttributeName: ttl
          Enabled: true
```

### S3 Buckets

```yaml
resources:
  Resources:
    UploadsBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: ${self:service}-${self:provider.stage}-uploads
        PublicAccessBlockConfiguration:
          BlockPublicAcls: true
          BlockPublicPolicy: true
          IgnorePublicAcls: true
          RestrictPublicBuckets: true
        BucketEncryption:
          ServerSideEncryptionConfiguration:
            - ServerSideEncryptionByDefault:
                SSEAlgorithm: AES256
        NotificationConfiguration:
          LambdaConfigurations:
            - Event: s3:ObjectCreated:*
              Function: !GetAtt ProcessUploadFunction.Arn

    ProcessUploadFunction:
      Type: AWS::Lambda::Function
      Properties:
        Handler: src/upload.handler
        Role: !GetAtt UploadRole.Arn
        Runtime: nodejs18.x
```

## Event Sources

### API Gateway Events

```yaml
functions:
  getUsers:
    handler: src/users.getUsers
    events:
      - http:
          path: /users
          method: get
          cors: true
          private: false

  getUser:
    handler: src/users.getUser
    events:
      - http:
          path: /users/{id}
          method: get
          request:
            parameters:
              paths:
                id: true
              querystrings:
                include: false

  createUser:
    handler: src/users.createUser
    events:
      - http:
          path: /users
          method: post
          request:
            schemas:
              application/json: ${file(schemas/create-user.json)}
```

### S3 Events

```yaml
functions:
  processImage:
    handler: src/image.process
    events:
      - s3:
          bucket: uploads
          event: s3:ObjectCreated:*
          rules:
            - prefix: uploads/
            - suffix: .jpg
          existing: false
```

### DynamoDB Events

```yaml
functions:
  processUserChange:
    handler: src/users.processChange
    events:
      - stream:
          type: dynamodb
          arn:
            Fn::GetAtt:
              - UserData
              - StreamArn
          batchSize: 10
          startingPosition: LATEST
```

### Schedule Events

```yaml
functions:
  cleanup:
    handler: src/cleanup.handler
    events:
      - schedule:
          rate: rate(1 hour)
          enabled: true
          input:
            action: cleanup
            retention: 7

      - schedule:
          rate: cron(0 2 * * ? *)
          enabled: ${opt:stage, 'dev' == 'prod'}
          input:
            action: daily-report
```

## Configuration Validation

sls.tf validates your configuration with helpful error messages:

### Common Validation Errors

**Missing Handler:**
```
Error: Function 'api' is missing handler property
```

**Invalid Runtime:**
```
Error: Invalid runtime 'nodejs16.x' in provider configuration
```

**Missing Required Fields:**
```
Error: Service name is required in serverless configuration
```

**Circular References:**
```
Error: Circular reference detected in variable resolution
```

### Configuration Best Practices

1. **Use Environment Variables** for sensitive data
2. **Define Variables** at the provider level when possible
3. **Use Meaningful Names** for functions and resources
4. **Document Custom Resources** with comments
5. **Test Configuration** with `terraform plan` before applying

## Next Steps

- 📖 [API Reference](../api/variables) - Complete variable reference
- 🚀 [Examples](../examples/basic-service) - Real-world configurations
- 🔧 [Advanced Features](../advanced/custom-resources) - Custom resources and extensions
- 📚 [Migration Guide](../migration/serverless-migration) - Migrate existing applications

---

<div class="hero-buttons">
  <a href="../api/variables" class="btn">Next: API Reference</a>
  <a href="../examples/basic-service" class="btn secondary">View Examples</a>
</div>