---
title: Resource Types
description: Complete reference for all supported AWS resource types
sidebar:
  order: 3
---

# Supported Resource Types

Complete reference for all AWS resource types supported by sls.tf.

## Compute Resources

### AWS::Lambda::Function

**Description**: Serverless compute functions that run your code in response to events

**Supported Properties**:
- `Handler` - Function handler (e.g., `src/handler.handler`)
- `Runtime` - Runtime environment (nodejs18.x, python3.11, etc.)
- `MemorySize` - Memory allocation (128-10240 MB)
- `Timeout` - Maximum execution time (1-900 seconds)
- `Environment` - Environment variables
- `Layers` - Lambda layers
- `VpcConfig` - VPC networking configuration
- `ReservedConcurrencyLimit` - Reserved concurrency
- `TracingConfig` - X-Ray tracing

**Example**:
```yaml
functions:
  hello:
    handler: src/handler.hello
    runtime: nodejs18.x
    memorySize: 256
    timeout: 30
    environment:
      TABLE_NAME: my-data
    layers:
      - arn:aws:lambda:us-east-1:123456789012:layer:my-layer:1
    vpc:
      securityGroupIds:
        - sg-12345678
      subnetIds:
        - subnet-12345678
        - subnet-87654321
```

### AWS::Lambda::Version

**Description**: Immutable version of Lambda function for deployment

**Created Automatically**: Yes, when deploying API Gateway

**Properties**: Managed by sls.tf

### AWS::Lambda::Alias

**Description**: Alias for Lambda function version

**Supported**: Through `provisioned_concurrency` variable

**Example**:
```hcl
provisioned_concurrency = {
  target = 5
  alias  = "production"
}
```

## API Gateway Resources

### AWS::ApiGateway::RestApi

**Description**: REST API for HTTP endpoints

**Supported Properties**:
- `Name` - API name (derived from service name)
- `Description` - API description
- `EndpointConfiguration` - Endpoint type (REGIONAL, EDGE, PRIVATE)
- `Policy` - Resource-based policy

**Example**:
```yaml
provider:
  apiGateway:
    restApiId: ${cf:my-api-stack.ApiId}
    restApiRootResourceId: ${cf:my-api-stack.RootResourceId}
```

### AWS::ApiGateway::Resource

**Description**: Path resources for API Gateway

**Created Automatically**: From function HTTP events

**Properties**: Managed by sls.tf

### AWS::ApiGateway::Method

**Description**: HTTP methods (GET, POST, PUT, DELETE, etc.)

**Created Automatically**: From function HTTP events

**Supported Properties**:
- `HttpMethod` - HTTP method
- `AuthorizationType` - Authorization (NONE, IAM, CUSTOM)
- `RequestParameters` - URL parameters
- `RequestModels` - Request validation schemas
- `Integration` - Lambda integration configuration

**Example**:
```yaml
functions:
  getUser:
    handler: src/users.get
    events:
      - http:
          path: /users/{id}
          method: get
          cors: true
          request:
            parameters:
              paths:
                id: true
              querystrings:
                include: false
            schemas:
              application/json: ${file(schemas/response.json)}
```

### AWS::ApiGateway::Deployment

**Description**: Deployment of API Gateway configuration

**Created Automatically**: When deploying

**Properties**: Managed by sls.tf

### AWS::ApiGateway::Stage

**Description**: Stage for API Gateway deployment

**Supported Properties**:
- `StageName` - Stage name
- `Variables` - Stage variables
- `AccessLogSetting` - Access logging configuration
- `MethodSettings` - Method-specific settings
- `CacheClusterEnabled` - API caching

**Example**:
```yaml
provider:
  apiGateway:
    websocket:
      stage: ${opt:stage, 'dev'}
    stage:
      variables:
        ENV: production
      accessLogFormat: >-
        { "requestId":"$context.requestId", "ip": "$context.identity.sourceIp" }
```

## Database Resources

### AWS::DynamoDB::Table

**Description**: NoSQL database tables

**Supported Properties**:
- `TableName` - Table name
- `AttributeDefinitions` - Attribute definitions
- `KeySchema` - Primary key schema
- `BillingMode` - Billing mode (PAY_PER_REQUEST, PROVISIONED)
- `ProvisionedThroughput` - Provisioned throughput
- `GlobalSecondaryIndexes` - GSI configuration
- `LocalSecondaryIndexes` - LSI configuration
- `StreamSpecification` - DynamoDB Streams
- `TimeToLiveSpecification` - TTL configuration
- `SSESpecification` - Server-side encryption
- `PointInTimeRecoverySpecification` - Backup configuration

**Example**:
```yaml
resources:
  Resources:
    UsersTable:
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
        SSESpecification:
          SSEEnabled: true
        PointInTimeRecoverySpecification:
          PointInTimeRecoveryEnabled: true
```

### AWS::DynamoDB::GlobalTable

**Description**: Multi-region DynamoDB tables

**Support**: Basic configuration through Table resource

## Storage Resources

### AWS::S3::Bucket

**Description**: Object storage buckets

**Supported Properties**:
- `BucketName` - Bucket name
- `AccessControl` - Access control
- `PublicAccessBlockConfiguration` - Public access blocking
- `BucketEncryption` - Server-side encryption
- `VersioningConfiguration` - Object versioning
- `LifecycleConfiguration` - Object lifecycle rules
- `NotificationConfiguration` - Event notifications
- `LoggingConfiguration` - Access logging
- `WebsiteConfiguration` - Static website hosting
- `CorsConfiguration` - CORS configuration
- `ReplicationConfiguration` - Cross-region replication

**Example**:
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
        VersioningConfiguration:
          Status: Enabled
        NotificationConfiguration:
          LambdaConfigurations:
            - Event: s3:ObjectCreated:*
              Function: !GetAtt ProcessUploadFunction.Arn
              Filter:
                S3Key:
                  Rules:
                    - Name: suffix
                      Value: .jpg
```

### AWS::S3::BucketPolicy

**Description**: Bucket access policies

**Support**: Through bucket resource configuration

## Messaging Resources

### AWS::SNS::Topic

**Description**: Pub/sub messaging topics

**Supported Properties**:
- `TopicName` - Topic name
- `DisplayName` - Display name
- `Subscription` - Subscriptions list
- `DeliveryPolicy` - Delivery policy
- `KmsMasterKeyId` - KMS key for encryption

**Example**:
```yaml
resources:
  Resources:
    NotificationsTopic:
      Type: AWS::SNS::Topic
      Properties:
        TopicName: ${self:service}-${self:provider.stage}-notifications
        DisplayName: "Application Notifications"
        Subscription:
          - Protocol: email
            Endpoint: admin@example.com
          - Protocol: lambda
            Endpoint: !GetAtt NotificationHandlerFunction.Arn
```

### AWS::SQS::Queue

**Description**: Message queues

**Supported Properties**:
- `QueueName` - Queue name
- `VisibilityTimeout` - Visibility timeout
- `MessageRetentionPeriod` - Message retention
- `RedrivePolicy` - Dead-letter queue
- `KmsMasterKeyId` - KMS key for encryption
- `DelaySeconds` - Default delay
- `MaximumMessageSize` - Maximum message size

**Example**:
```yaml
resources:
  Resources:
    JobQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: ${self:service}-${self:provider.stage}-jobs
        VisibilityTimeout: 300
        MessageRetentionPeriod: 1209600
        RedrivePolicy:
          deadLetterTargetArn: !GetAtt JobQueueDLQ.Arn
          maxReceiveCount: 5
```

## Event Resources

### AWS::Events::Rule

**Description**: EventBridge rules for event routing

**Supported Properties**:
- `Name` - Rule name
- `EventPattern` - Event pattern
- `ScheduleExpression` - Schedule expression
- `State` - Rule state (ENABLED, DISABLED)
- `Targets` - Event targets

**Example**:
```yaml
functions:
  processUserCreated:
    handler: src/users.processCreated
    events:
      - eventBridge:
          eventBus: default
          pattern:
            source:
              - com.myapp.users
            detail-type:
              - UserCreated
            detail:
              userId:
                - exists: true

  cleanupJob:
    handler: src/cleanup.handler
    events:
      - schedule:
          rate: rate(1 hour)
          enabled: true
          input:
            action: cleanup
            retention: 7
```

### AWS::Events::EventBus

**Description**: Custom event buses

**Support**: Basic configuration through rule events

## Security Resources

### AWS::IAM::Role

**Description**: IAM roles for Lambda execution

**Created Automatically**: For Lambda functions

**Supported Properties**:
- `RoleName` - Role name
- `AssumeRolePolicyDocument` - Trust policy
- `Policies` - Managed policies
- `ManagedPolicyArns` - AWS managed policies

**Example**:
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
        - Effect: Allow
          Action:
            - s3:GetObject
            - s3:PutObject
          Resource:
            - "arn:aws:s3:::${self:service}-${self:provider.stage}-uploads/*"
```

### AWS::IAM::Policy

**Description**: IAM policies

**Support**: Through role configuration

### AWS::IAM::ManagedPolicy

**Description**: Managed IAM policies

**Support**: Through role configuration

## Monitoring Resources

### AWS::Logs::LogGroup

**Description**: CloudWatch log groups

**Created Automatically**: For Lambda functions

**Supported Properties**:
- `LogGroupName` - Log group name
- `RetentionInDays` - Log retention period

**Control**: Through `log_retention` variable

### AWS::CloudWatch::Alarm

**Description**: CloudWatch alarms

**Support**: Basic alarm configuration

**Control**: Through `enable_cloudwatch_alarms` variable

## CDN Resources

### AWS::CloudFront::Distribution

**Description**: CDN distributions for static content

**Support**: Basic CloudFront configuration for custom domains

**Example**:
```yaml
provider:
  apiGateway:
    restApiId: ${cf:cloudfront-stack.ApiGatewayRestApiId}
    restApiRootResourceId: ${cf:cloudfront-stack.ApiGatewayRestApiRootResourceId}
```

## DNS Resources

### AWS::Route53::RecordSet

**Description**: DNS records for custom domains

**Support**: Through custom resources

### AWS::Route53::HostedZone

**Description**: Route 53 hosted zones

**Support**: Manual configuration required

## Resource Generation Examples

### Complete API Service

```yaml
service: my-api-service
frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1
  stage: dev
  memorySize: 256
  timeout: 30

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

functions:
  api:
    handler: src/api.handler
    events:
      - http:
          path: /{proxy+}
          method: any
          cors: true

  getUser:
    handler: src/users.get
    events:
      - http:
          path: /users/{id}
          method: get
          cors: true
          request:
            parameters:
              paths:
                id: true

  createUser:
    handler: src/users.create
    events:
      - http:
          path: /users
          method: post
          cors: true

  processUpload:
    handler: src/upload.process
    events:
      - s3:
          bucket: uploads
          event: s3:ObjectCreated:*
          existing: false

  processUserEvent:
    handler: src/events.processUser
    events:
      - eventBridge:
          pattern:
            source:
              - com.myapp.users
            detail-type:
              - UserCreated
              - UserUpdated

resources:
  Resources:
    UserData:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:service}-${self:provider.stage}-data
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: id
            AttributeType: S
        KeySchema:
          - AttributeName: id
            KeyType: HASH
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES
        TimeToLiveSpecification:
          AttributeName: ttl
          Enabled: true

    UploadsBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: ${self:service}-${self:provider.stage}-uploads
        PublicAccessBlockConfiguration:
          BlockPublicAcls: true
          BlockPublicPolicy: true
          IgnorePublicAcls: true
          RestrictPublicBuckets: true
        NotificationConfiguration:
          LambdaConfigurations:
            - Event: s3:ObjectCreated:*
              Function: !GetAtt ProcessUploadFunction.Arn

    NotificationsTopic:
      Type: AWS::SNS::Topic
      Properties:
        TopicName: ${self:service}-${self:provider.stage}-notifications
```

This single configuration generates:

1. **Compute**: 4 Lambda functions with execution role
2. **API Gateway**: REST API with endpoints
3. **Database**: 1 DynamoDB table with streams
4. **Storage**: 1 S3 bucket with event notifications
5. **Messaging**: 1 SNS topic
6. **Events**: 1 EventBridge rule
7. **Monitoring**: CloudWatch log groups
8. **Security**: IAM roles and policies
9. **Network**: VPC configuration if specified

## Resource Limitations

### Not Currently Supported

- **AWS::ElasticLoadBalancingV2::LoadBalancer** - Application/Network Load Balancers
- **AWS::ElasticLoadBalancing::LoadBalancer** - Classic Load Balancers
- **AWS::EC2::Instance** - EC2 instances
- **AWS::ECS::Service** - ECS services
- **AWS::EKS::Cluster** - EKS clusters
- **AWS::RDS::DBInstance** - RDS databases
- **AWS::Kinesis::Stream** - Kinesis streams
- **AWS::Cognito::UserPool** - Cognito user pools
- **AWS::ApiGatewayV2::Api** - HTTP API Gateway v2
- **AWS::StepFunctions::StateMachine** - Step Functions

### Partial Support

- **AWS::CloudFront::Distribution** - Basic configuration only
- **AWS::Route53::RecordSet** - Through custom resources
- **AWS::CertificateManager::Certificate** - Manual setup required

## Next Steps

- 📖 [Variable Reference](../api/variables) - Module variables
- 📚 [Examples](../examples/basic-service) - Real-world examples
- 🔧 [Advanced Features](../advanced/custom-resources) - Custom resources

---

<div class="hero-buttons">
  <a href="../examples/basic-service" class="btn">View Examples</a>
  <a href="../features/lambda-functions" class="btn secondary">Learn About Features</a>
</div>