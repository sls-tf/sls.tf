# Elemental Event-Driven Service to Serverless Framework Conversion

This document describes the process of converting the custom elemental-event-driven-service YAML configuration to Serverless Framework format compatible with sls.tf.

## Overview

The elemental-event-driven-service uses a custom Terraform module with a declarative YAML configuration. This conversion tool transforms that configuration into a standard Serverless Framework `serverless.yml` file that can be used with the sls.tf Terraform module.

## Conversion Tool

### Location
`scripts/elemental-to-serverless-converter.js`

### Usage
```bash
node scripts/elemental-to-serverless-converter.js <input.yaml> [output.yml]
```

### Example
```bash
node scripts/elemental-to-serverless-converter.js \
  /path/to/elemental-event-driven-service/examples/comprehensive-service.yaml \
  converted-serverless.yml
```

## Conversion Mapping

### Service Configuration
| Elemental YAML | Serverless Framework |
|----------------|---------------------|
| `service.name` | `service` |
| `service.description` | `custom.description` |
| `defaults.lambda.runtime` | `provider.runtime` |
| `defaults.lambda.timeout` | `provider.timeout` |
| `defaults.lambda.memory_size` | `provider.memorySize` |
| `defaults.tags` | Merged with provider tags |

### Lambda Functions
| Elemental YAML | Serverless Framework |
|----------------|---------------------|
| `lambdas.<name>` | `functions.<name>` |
| `description` | `description` |
| `handler` | `handler` |
| `runtime` | `runtime` |
| `timeout` | `timeout` |
| `memory_size` | `memorySize` |
| `environment` | `environment` |
| `dlq.enabled` | `deadLetterArn` (DLQ created automatically) |

### Event Sources

#### API Gateway
| Elemental YAML | Serverless Framework |
|----------------|---------------------|
| `api_gateway.enabled` | HTTP events on functions containing "api" |
| Multiple methods | Individual HTTP events for each method |

#### EventBridge
| Elemental YAML | Serverless Framework |
|----------------|---------------------|
| `eventbridge.rules[].targets[]` | `eventBridge` events on target functions |
| Event patterns | Direct pattern mapping |

#### DynamoDB Streams
| Elemental YAML | Serverless Framework |
|----------------|---------------------|
| `dynamodb_tables.<table>.stream_view_type` | `stream` events (limited support) |

### DynamoDB Tables
| Elemental YAML | Serverless Framework |
|----------------|---------------------|
| `dynamodb_tables.<name>` | `resources.Resources.DynamoDB<Name>Table` |
| `table_name` | `Properties.TableName` |
| `hash_key` | `Properties.KeySchema[0]` |
| `range_key` | `Properties.KeySchema[1]` (if present) |
| `attributes` | `Properties.AttributeDefinitions` |
| `billing_mode` | `Properties.BillingMode` |
| `stream_view_type` | `Properties.StreamSpecification` |
| `pitr_enabled` | `Properties.PointInTimeRecoverySpecification` |
| `ttl_attribute` | `Properties.TimeToLiveSpecification` |

## Converted Example

### Input (Elemental Format)
```yaml
service:
  name: user-service
  description: User management microservice

defaults:
  lambda:
    runtime: nodejs22.x
    timeout: 30
    memory_size: 256
  tags:
    Team: platform

lambdas:
  api-ingest:
    description: Ingests API requests
    handler: handler.processApiRequest
    source_dir: ./lambda/api-ingest
    timeout: 15
    memory_size: 512
    environment:
      LOG_LEVEL: INFO
      TABLE_NAME: users
    dlq:
      enabled: true

dynamodb_tables:
  users:
    table_name: users
    hash_key: userId
    range_key: createdAt
    attributes:
      - name: userId
        type: S
      - name: createdAt
        type: N
    billing_mode: PAY_PER_REQUEST
    pitr_enabled: true
    stream_view_type: NEW_AND_OLD_IMAGES

api_gateway:
  enabled: true
  api_name: user-api
  stage_name: v1

eventbridge:
  bus_name: user-events
  rules:
    user-created:
      event_pattern:
        source:
          - user.service
        detail-type:
          - user.created
      targets:
        - type: lambda
          lambda: user-created-processor
```

### Output (Serverless Framework)
```yaml
service: user-service
frameworkVersion: '3'
configValidationMode: error

provider:
  name: aws
  runtime: nodejs22.x
  region: us-east-1
  stage: dev
  timeout: 30
  memorySize: 256
  iam:
    role:
      statements:
        - Effect: Allow
          Action:
            - dynamodb:GetItem
            - dynamodb:PutItem
            - dynamodb:UpdateItem
            - dynamodb:DeleteItem
            - dynamodb:Query
            - dynamodb:Scan
            - dynamodb:BatchGetItem
            - dynamodb:BatchWriteItem
          Resource:
            - arn:aws:dynamodb:*:*:table/users
        - Effect: Allow
          Action:
            - events:PutEvents
            - events:PutRule
            - events:DeleteRule
            - events:ListTargetsByRule
            - events:PutTargets
            - events:RemoveTargets
          Resource: '*'
        - Effect: Allow
          Action:
            - logs:CreateLogGroup
            - logs:CreateLogStream
            - logs:PutLogEvents
          Resource: arn:aws:logs:*:*:*
  environment: {}
  apiGateway:
    minimumCompressionSize: 1024
    restApiId:
      Fn::ImportValue: user-service-api-id
    restApiRootResourceId:
      Fn::ImportValue: user-service-api-root-id

functions:
  api-ingest:
    description: Ingests API requests and publishes events
    handler: handler.processApiRequest
    runtime: nodejs22.x
    timeout: 15
    memorySize: 512
    environment:
      LOG_LEVEL: INFO
      TABLE_NAME: users
    events:
      - http:
          path: /{proxy+}
          method: post
          cors: true
      - http:
          path: /{proxy+}
          method: get
          cors: true
      - http:
          path: /{proxy+}
          method: put
          cors: true
      - http:
          path: /{proxy+}
          method: delete
          cors: true
    deadLetterArn:
      Fn::GetAtt:
        - Api-ingestDLQ
        - Arn

resources:
  Resources:
    DynamoDBUsersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: users
        AttributeDefinitions:
          - AttributeName: userId
            AttributeType: S
          - AttributeName: createdAt
            AttributeType: N
        KeySchema:
          - AttributeName: userId
            KeyType: HASH
          - AttributeName: createdAt
            KeyType: RANGE
        BillingMode: PAY_PER_REQUEST
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES
        PointInTimeRecoverySpecification:
          PointInTimeRecoveryEnabled: true
        SSESpecification:
          SSEEnabled: true
        TimeToLiveSpecification:
          AttributeName: expiresAt
          Enabled: true

custom:
  originalElementalConfig: {...}
```

## Limitations and Differences

### What Works ✅
- ✅ Lambda functions with all configurations
- ✅ DynamoDB tables with all properties
- ✅ API Gateway HTTP events
- ✅ EventBridge event patterns
- ✅ IAM role statements
- ✅ Dead Letter Queues
- ✅ Environment variables
- ✅ Tags and metadata

### What's Limited ⚠️
- ⚠️ **DynamoDB Streams**: Limited support due to ARN resolution issues
- ⚠️ **EventBridge Rules**: EventBridge event sources work, but custom buses/rules need manual setup
- ⚠️ **DLQ Configuration**: Basic DLQ support, custom DLQ names work but advanced features limited
- ⚠️ **API Gateway**: Basic HTTP endpoints work, advanced features need manual configuration

### What Doesn't Work ❌
- ❌ **SQS/SNS Integration**: Not supported by current sls.tf module
- ❌ **Custom Resource Types**: Only DynamoDB, S3, SNS, SQS, and CloudFront are supported
- ❌ **Advanced API Gateway Features**: Custom domains, authorizers, etc.
- ❌ **Complex EventBridge Targets**: Only Lambda targets are supported

## Testing the Conversion

### 1. Convert the Configuration
```bash
cd /path/to/sls.tf
node scripts/elemental-to-serverless-converter.js \
  ../infra/events/elemental-event-driven-service/examples/comprehensive-service.yaml \
  converted-user-service.yml
```

### 2. Create Lambda Handlers
```bash
mkdir user-service-lambdas
# Create your handler.js file
```

### 3. Test with sls.tf
```bash
terraform plan \
  -var="config_path=converted-user-service.yml" \
  -var="lambda_code_path=user-service-lambdas"
```

### 4. Deploy (Optional)
```bash
terraform apply \
  -var="config_path=converted-user-service.yml" \
  -var="lambda_code_path=user-service-lambdas"
```

## Migration Strategy

1. **Assessment**: Review your elemental configuration for unsupported features
2. **Conversion**: Use the conversion tool to generate serverless.yml
3. **Validation**: Test with `terraform plan` to identify issues
4. **Adjustment**: Manual configuration for unsupported features
5. **Testing**: Deploy to test environment first
6. **Migration**: Gradual migration with feature parity testing

## Benefits of Migration

- 🚀 **Standard Framework**: Uses industry-standard Serverless Framework
- 🔧 **Better Tooling**: Rich ecosystem of Serverless Framework tools
- 📊 **Enhanced Monitoring**: Built-in metrics and dashboards
- 🔄 **CI/CD Integration**: Better CI/CD pipeline support
- 🛡️ **Security**: Standard security patterns and best practices
- 📈 **Scalability**: Improved auto-scaling and performance

## Support

For issues with the conversion tool or sls.tf module:
- Check the sls.tf documentation
- Review the Terraform plan output for errors
- Create GitHub issues for conversion problems
- Consider manual configuration for complex use cases