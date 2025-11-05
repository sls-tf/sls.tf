---
title: Lambda Functions
description: Complete guide to Lambda function configuration and management
sidebar:
  order: 1
---

# Lambda Functions

Complete guide to configuring, deploying, and managing Lambda functions with sls.tf.

## Function Configuration

### Basic Function Definition

```yaml
functions:
  hello:
    handler: src/handler.hello
    description: "Simple hello world function"
```

This creates a Lambda function with:
- **Handler**: `src/handler.hello` (file.method)
- **Runtime**: Inherited from provider (default: nodejs18.x)
- **Memory**: 256 MB (default)
- **Timeout**: 30 seconds (default)

### Function Properties

#### Handler
Specifies the function handler in format `[file].[method]`:

```yaml
functions:
  # JavaScript handlers
  api:
    handler: src/api.handler        # src/api.js, exports.handler
  users:
    handler: services/users.index   # services/users.js, exports.index

  # TypeScript handlers (after compilation)
  app:
    handler: dist/index.main        # dist/index.js, exports.main
```

#### Runtime
Lambda runtime environment:

```yaml
functions:
  nodejs:
    handler: src/node.handler
    runtime: nodejs18.x

  python:
    handler: src/python.handler
    runtime: python3.11

  java:
    handler: com.example.Handler::handleRequest
    runtime: java17

  go:
    handler: bin/main
    runtime: go1.x

  dotnet:
    handler: MyApp::MyApp.Function::FunctionHandler
    runtime: dotnet7
```

#### Memory Size
Memory allocation affects CPU power and cost:

```yaml
functions:
  lightweight:
    handler: src/simple.handler
    memorySize: 128        # 128 MB, minimum

  standard:
    handler: src/standard.handler
    memorySize: 256        # 256 MB, default

  compute_intensive:
    handler: src/heavy.handler
    memorySize: 1024       # 1024 MB, more CPU

  max_power:
    handler: src/max.handler
    memorySize: 10240      # 10240 MB, maximum
```

#### Timeout
Maximum execution time in seconds:

```yaml
functions:
  quick:
    handler: src/quick.handler
    timeout: 3             # 3 seconds

  standard:
    handler: src/standard.handler
    timeout: 30            # 30 seconds, default

  long_running:
    handler: src/batch.handler
    timeout: 300           # 5 minutes

  maximum:
    handler: src/max.handler
    timeout: 900           # 15 minutes, maximum
```

## Environment Variables

### Function-Level Environment Variables

```yaml
functions:
  api:
    handler: src/api.handler
    environment:
      NODE_ENV: production
      LOG_LEVEL: info
      API_VERSION: v1
      DB_HOST: my-db.example.com
```

### Provider-Level Environment Variables

```yaml
provider:
  name: aws
  runtime: nodejs18.x
  environment:
    NODE_ENV: production
    LOG_LEVEL: info
    REGION: ${self:provider.region}
    SERVICE_NAME: ${self:service}

functions:
  api:
    handler: src/api.handler
    # Inherits provider environment variables
    environment:
      API_VERSION: v1      # Function-specific variables
```

### Variable Resolution in Environment Variables

```yaml
provider:
  environment:
    # Self-references
    SERVICE_NAME: ${self:service}
    STAGE: ${self:provider.stage}

    # Environment variables
    NODE_ENV: ${opt:stage, 'dev'}
    DB_PASSWORD: ${env:DB_PASSWORD}

    # File references
    CONFIG_JSON: ${file(config/config.json)}

    # CloudFormation outputs
    VPC_ID: ${cf:my-vpc-stack.VpcId}
```

## VPC Configuration

### Provider-Level VPC Settings

```yaml
provider:
  vpc:
    securityGroupIds:
      - sg-12345678
      - sg-87654321
    subnetIds:
      - subnet-12345678
      - subnet-87654321
      - subnet-abcdef12
      - subnet-fedcba98

functions:
  api:
    handler: src/api.handler
    # Inherits provider VPC configuration
```

### Function-Level VPC Settings

```yaml
functions:
  api:
    handler: src/api.handler
    vpc:
      securityGroupIds:
        - sg-api-specific
      subnetIds:
        - subnet-private-1
        - subnet-private-2

  public:
    handler: src/public.handler
    # No VPC configuration, runs in default VPC
```

## Layers

### Using Lambda Layers

```yaml
functions:
  api:
    handler: src/api.handler
    layers:
      - arn:aws:lambda:us-east-1:123456789012:layer:shared-libraries:1
      - arn:aws:lambda:us-east-1:123456789012:layer:utils:2
      - ${cf:layers-stack.UtilsLayerArn}
```

### Creating Layers with sls.tf

```yaml
resources:
  Resources:
    SharedLibsLayer:
      Type: AWS::Lambda::LayerVersion
      Properties:
        LayerName: ${self:service}-${self:provider.stage}-shared-libs
        CompatibleRuntimes:
          - nodejs18.x
          - nodejs16.x
        LicenseInfo: MIT
        Content:
          S3Bucket: ${cf:deployment-bucket-stack.BucketName}
          S3Key: layers/shared-libs.zip

functions:
  api:
    handler: src/api.handler
    layers:
      - !Ref SharedLibsLayer
```

## IAM Permissions

### Provider-Level IAM Statements

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
            - "arn:aws:dynamodb:${self:provider.region}:*:table/${self:service}-${self:provider.stage}-users"

        - Effect: Allow
          Action:
            - s3:GetObject
            - s3:PutObject
            - s3:DeleteObject
          Resource:
            - "arn:aws:s3:::${self:service}-${self:provider.stage}-uploads/*"
```

### Function-Level IAM Statements

```yaml
functions:
  api:
    handler: src/api.handler
    iam:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:GetItem
            - dynamodb:PutItem
          Resource:
            - "arn:aws:dynamodb:${self:provider.region}:*:table/${self:service}-${self:provider.stage}-users"

        - Effect: Allow
          Action:
            - ssm:GetParameter
          Resource:
            - "arn:aws:ssm:${self:provider.region}:*:parameter/api/*"
```

### Using Existing IAM Roles

```hcl
# In Terraform
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"

  role_arn = aws_iam_role.existing_role.arn
}
```

```yaml
# serverless.yml
provider:
  iam:
    role: arn:aws:iam::123456789012:role/my-existing-role
```

## Event Sources

### HTTP API Events

```yaml
functions:
  api:
    handler: src/api.handler
    events:
      - http:
          path: /{proxy+}
          method: any
          cors: true

  getUsers:
    handler: src/users.get
    events:
      - http:
          path: /users
          method: get
          cors: true

  createUser:
    handler: src/users.create
    events:
      - http:
          path: /users
          method: post
          cors: true
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

  deleteCleanup:
    handler: src/cleanup.handler
    events:
      - s3:
          bucket: uploads
          event: s3:ObjectRemoved:*
          existing: false
```

### DynamoDB Stream Events

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
          maximumRetryAttempts: 3
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

  dailyReport:
    handler: src/report.generate
    events:
      - schedule:
          rate: cron(0 2 * * ? *)
          enabled: ${opt:stage, 'dev' == 'prod'}
          input:
            report_type: daily
            recipients: admin@example.com
```

### SQS Events

```yaml
functions:
  processJob:
    handler: src/job.process
    events:
      - sqs:
          arn:
            Fn::GetAtt:
              - JobQueue
              - Arn
          batchSize: 10
          maximumBatchingWindowInSeconds: 5
```

### SNS Events

```yaml
functions:
  handleNotification:
    handler: src.notification.handle
    events:
      - sns:
          topicArn:
            Fn::GetAtt:
              - NotificationsTopic
              - Arn
          filterPolicy:
            event_type:
              - user_created
              - payment_processed
```

### EventBridge Events

```yaml
functions:
  processUserEvent:
    handler: src.events.processUser
    events:
      - eventBridge:
          eventBus: default
          pattern:
            source:
              - com.myapp.users
            detail-type:
              - UserCreated
              - UserUpdated
            detail:
              userId:
                exists: true
```

## Advanced Configuration

### Reserved and Provisioned Concurrency

```yaml
functions:
  critical_api:
    handler: src/critical.handler
    reservedConcurrency: 10

  high_traffic_api:
    handler: src/traffic.handler
    provisionedConcurrency: 20
    reservedConcurrency: 50
```

### Dead Letter Queues

```yaml
functions:
  api:
    handler: src/api.handler
    deadLetterArn:
      Fn::GetAtt:
        - ApiDLQ
        - Arn
```

### Tracing Configuration

```yaml
functions:
  api:
    handler: src/api.handler
    tracing: Active

  debug:
    handler: src/debug.handler
    tracing: PassThrough

  simple:
    handler: src/simple.handler
    tracing: Disabled
```

### Error Handling

```yaml
functions:
  api:
    handler: src/api.handler
    onError:
      Fn::GetAtt:
        - ErrorTopic
        - Arn
    maximumRetryAttempts: 2
```

## Deployment Configuration

### Package Configuration

```yaml
package:
  individually: true    # Package functions individually

  exclude:
    - .git/**
    - .terraform/**
    - node_modules/aws-sdk/**

  include:
    - src/**
    - config/**

functions:
  api:
    handler: src/api.handler
    package:
      individually: true
      exclude:
        - test/**
        - docs/**
      include:
        - src/api/**
        - shared/utils/**
```

### Artifact Storage

```yaml
provider:
  deploymentBucket:
    name: ${self:service}-${self:provider.stage}-deployments
    serverSideEncryption: AES256
```

## Function Examples

### REST API Function

```yaml
functions:
  usersAPI:
    handler: src/users.handler
    description: "Users management API"
    memorySize: 512
    timeout: 30
    environment:
      TABLE_NAME: ${self:service}-${self:provider.stage}-users
      JWT_SECRET: ${env:JWT_SECRET}
    events:
      - http:
          path: /users
          method: get
          cors: true
          request:
            parameters:
              querystrings:
                page: false
                limit: false
      - http:
          path: /users
          method: post
          cors: true
          request:
            schemas:
              application/json: ${file(schemas/create-user.json)}
      - http:
          path: /users/{id}
          method: get
          cors: true
          request:
            parameters:
              paths:
                id: true
      - http:
          path: /users/{id}
          method: put
          cors: true
          request:
            parameters:
              paths:
                id: true
            schemas:
              application/json: ${file(schemas/update-user.json)}
      - http:
          path: /users/{id}
          method: delete
          cors: true
          request:
            parameters:
              paths:
                id: true
    iam:
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
            - "arn:aws:dynamodb:${self:provider.region}:*:table/${self:service}-${self:provider.stage}-users"
```

### Background Worker Function

```yaml
functions:
  imageProcessor:
    handler: src/image.process
    description: "Process uploaded images"
    memorySize: 1024
    timeout: 300
    environment:
      UPLOAD_BUCKET: ${self:service}-${self:provider.stage}-uploads
      PROCESSED_BUCKET: ${self:service}-${self:provider.stage}-processed
      IMAGE_QUALITY: 80
    events:
      - s3:
          bucket: uploads
          event: s3:ObjectCreated:*
          rules:
            - prefix: raw/
            - suffix: .jpg
          existing: false
    iam:
      statements:
        - Effect: Allow
          Action:
            - s3:GetObject
          Resource:
            - "arn:aws:s3:::${self:service}-${self:provider.stage}-uploads/raw/*"
        - Effect: Allow
          Action:
            - s3:PutObject
          Resource:
            - "arn:aws:s3:::${self:service}-${self:provider.stage}-processed/*"
```

### Scheduled Task Function

```yaml
functions:
  dataCleanup:
    handler: src/cleanup.handler
    description: "Periodic data cleanup task"
    memorySize: 256
    timeout: 900
    environment:
      RETENTION_DAYS: 30
      BATCH_SIZE: 100
    events:
      - schedule:
          rate: cron(0 2 * * ? *)  # Daily at 2 AM UTC
          enabled: ${opt:stage, 'dev' == 'prod'}
          input:
            action: cleanup_expired_data
            dry_run: false
    iam:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:Query
            - dynamodb:Scan
            - dynamodb:DeleteItem
          Resource:
            - "arn:aws:dynamodb:${self:provider.region}:*:table/${self:service}-${self:provider.stage}-*"
```

## Best Practices

### Function Design

1. **Single Responsibility**: Each function should do one thing well
2. **Stateless**: Don't store state between invocations
3. **Idempotent**: Make functions safe to retry
4. **Small and Focused**: Keep functions under 50 lines when possible

### Performance

1. **Right-Size Memory**: Choose appropriate memory for your workload
2. **Optimize Cold Starts**: Minimize initialization code
3. **Use Keep-Alive**: For frequently called functions
4. **Bundle Efficiently**: Only include necessary dependencies

### Security

1. **Principle of Least Privilege**: Only grant necessary permissions
2. **Environment Variables**: Store secrets securely
3. **VPC When Needed**: Only use VPC when required
4. **Input Validation**: Validate all inputs

### Monitoring

1. **Structured Logging**: Use structured logs for better analysis
2. **Custom Metrics**: Add business metrics
3. **Error Handling**: Handle and log errors appropriately
4. **Performance Monitoring**: Track duration and memory usage

## Next Steps

- 📖 [API Gateway](../features/api-gateway) - API Gateway configuration
- 📚 [Event Sources](../features/event-sources) - All supported event sources
- 🔧 [Advanced Features](../advanced/custom-resources) - Custom resources and extensions

---

<div class="hero-buttons">
  <a href="../features/api-gateway" class="btn">Next: API Gateway</a>
  <a href="../examples/basic-service" class="btn secondary">View Examples</a>
</div>