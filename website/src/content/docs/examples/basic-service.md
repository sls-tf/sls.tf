---
title: Basic Lambda Service
description: Complete example of a basic Lambda service with API Gateway
sidebar:
  order: 1
---

# Basic Lambda Service

Complete example of deploying a basic Lambda service with API Gateway using sls.tf.

## Overview

This example creates a simple serverless API with:
- **Lambda Function**: Node.js function with multiple endpoints
- **API Gateway**: REST API with CORS support
- **DynamoDB**: Simple data storage
- **IAM Role**: Proper permissions for the Lambda function

## Project Structure

```
basic-service/
├── modules/
│   └── sls.tf/                # sls.tf module
├── src/
│   ├── handlers.js            # Lambda handlers
│   └── utils.js               # Utility functions
├── serverless.yml             # Serverless configuration
├── main.tf                    # Terraform configuration
├── package.json               # Node.js dependencies
└── README.md                  # Project documentation
```

## Serverless Configuration

### serverless.yml

```yaml
service: basic-service
frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs18.x
  region: us-east-1
  stage: dev

  # Memory and timeout defaults
  memorySize: 256
  timeout: 30

  # Environment variables
  environment:
    TABLE_NAME: ${self:service}-${self:provider.stage}-items
    REGION: ${self:provider.region}

  # IAM permissions
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
            - "arn:aws:dynamodb:${self:provider.region}:*:table/${self:service}-${self:provider.stage}-items"

# Lambda functions
functions:
  # Health check endpoint
  health:
    handler: src/handlers.health
    description: "Health check endpoint"
    events:
      - http:
          path: /health
          method: get
          cors: true

  # Get all items
  listItems:
    handler: src/handlers.listItems
    description: "List all items"
    events:
      - http:
          path: /items
          method: get
          cors: true

  # Get single item
  getItem:
    handler: src/handlers.getItem
    description: "Get item by ID"
    events:
      - http:
          path: /items/{id}
          method: get
          cors: true
          request:
            parameters:
              paths:
                id: true

  # Create item
  createItem:
    handler: src/handlers.createItem
    description: "Create new item"
    events:
      - http:
          path: /items
          method: post
          cors: true

  # Update item
  updateItem:
    handler: src/handlers.updateItem
    description: "Update existing item"
    events:
      - http:
          path: /items/{id}
          method: put
          cors: true
          request:
            parameters:
              paths:
                id: true

  # Delete item
  deleteItem:
    handler: src/handlers.deleteItem
    description: "Delete item by ID"
    events:
      - http:
          path: /items/{id}
          method: delete
          cors: true
          request:
            parameters:
              paths:
                id: true

# Custom resources
resources:
  Resources:
    # DynamoDB table for items
    ItemsTable:
      Type: AWS::DynamoDB::Table
      Properties:
        TableName: ${self:service}-${self:provider.stage}-items
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - AttributeName: id
            AttributeType: S
          - AttributeName: createdAt
            AttributeType: S
        KeySchema:
          - AttributeName: id
            KeyType: HASH
        GlobalSecondaryIndexes:
          - IndexName: CreatedAtIndex
            KeySchema:
              - AttributeName: createdAt
                KeyType: HASH
            Projection:
              ProjectionType: ALL
        StreamSpecification:
          StreamViewType: NEW_AND_OLD_IMAGES
        TimeToLiveSpecification:
          AttributeName: ttl
          Enabled: true

    # SNS topic for notifications
    NotificationsTopic:
      Type: AWS::SNS::Topic
      Properties:
        TopicName: ${self:service}-${self:provider.stage}-notifications
        DisplayName: "Basic Service Notifications"

  # Outputs for reference
  Outputs:
    ItemsTableName:
      Description: "DynamoDB table name for items"
      Value:
        Ref: ItemsTable
      Export:
        Name: ${self:service}-${self:provider.stage}-items-table

    NotificationsTopicArn:
      Description: "SNS topic ARN for notifications"
      Value:
        Ref: NotificationsTopic
      Export:
        Name: ${self:service}-${self:provider.stage}-notifications-topic
```

## Lambda Function Code

### src/handlers.js

```javascript
'use strict';

const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sns = new AWS.SNS();

// Environment variables
const TABLE_NAME = process.env.TABLE_NAME;
const TOPIC_ARN = process.env.NOTIFICATIONS_TOPIC_ARN;

// Utility functions
const createResponse = (statusCode, body) => ({
  statusCode,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
  },
  body: JSON.stringify(body)
});

const handleError = (error, context) => {
  console.error('Error:', error);

  // Send error to SNS if topic is configured
  if (TOPIC_ARN) {
    sns.publish({
      TopicArn: TOPIC_ARN,
      Subject: `Error in ${context.functionName}`,
      Message: JSON.stringify({
        error: error.message,
        stack: error.stack,
        requestId: context.awsRequestId,
        timestamp: new Date().toISOString()
      })
    }).catch(err => console.error('Failed to send error notification:', err));
  }

  return createResponse(500, {
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? error.message : undefined
  });
};

// Lambda handlers
module.exports.health = async (event) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: process.env.SERVICE_NAME || 'basic-service',
      version: '1.0.0',
      region: process.env.AWS_REGION
    };

    return createResponse(200, health);
  } catch (error) {
    return handleError(error, { functionName: 'health' });
  }
};

module.exports.listItems = async (event) => {
  try {
    const params = {
      TableName: TABLE_NAME,
      ProjectionExpression: 'id, name, description, createdAt, updatedAt'
    };

    const result = await dynamodb.scan(params).promise();

    return createResponse(200, {
      items: result.Items || [],
      count: result.Count || 0
    });
  } catch (error) {
    return handleError(error, { functionName: 'listItems' });
  }
};

module.exports.getItem = async (event) => {
  try {
    const { id } = event.pathParameters;

    if (!id) {
      return createResponse(400, { message: 'Item ID is required' });
    }

    const params = {
      TableName: TABLE_NAME,
      Key: { id }
    };

    const result = await dynamodb.get(params).promise();

    if (!result.Item) {
      return createResponse(404, { message: 'Item not found' });
    }

    return createResponse(200, { item: result.Item });
  } catch (error) {
    return handleError(error, { functionName: 'getItem' });
  }
};

module.exports.createItem = async (event) => {
  try {
    const body = JSON.parse(event.body);

    if (!body.name) {
      return createResponse(400, { message: 'Item name is required' });
    }

    const item = {
      id: AWS.util.uuid.v4(),
      name: body.name,
      description: body.description || '',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      ttl: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60) // 30 days
    };

    const params = {
      TableName: TABLE_NAME,
      Item: item
    };

    await dynamodb.put(params).promise();

    // Send notification
    if (TOPIC_ARN) {
      await sns.publish({
        TopicArn: TOPIC_ARN,
        Subject: 'Item Created',
        Message: JSON.stringify({
          action: 'created',
          item: { id: item.id, name: item.name },
          timestamp: item.createdAt
        })
      }).promise();
    }

    return createResponse(201, { item });
  } catch (error) {
    return handleError(error, { functionName: 'createItem' });
  }
};

module.exports.updateItem = async (event) => {
  try {
    const { id } = event.pathParameters;
    const body = JSON.parse(event.body);

    if (!id) {
      return createResponse(400, { message: 'Item ID is required' });
    }

    // Check if item exists
    const getParams = {
      TableName: TABLE_NAME,
      Key: { id }
    };

    const existingItem = await dynamodb.get(getParams).promise();

    if (!existingItem.Item) {
      return createResponse(404, { message: 'Item not found' });
    }

    const updateExpression = [];
    const expressionAttributeNames = {};
    const expressionAttributeValues = {};

    if (body.name !== undefined) {
      updateExpression.push('#name = :name');
      expressionAttributeNames['#name'] = 'name';
      expressionAttributeValues[':name'] = body.name;
    }

    if (body.description !== undefined) {
      updateExpression.push('description = :description');
      expressionAttributeValues[':description'] = body.description;
    }

    updateExpression.push('updatedAt = :updatedAt');
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();

    const params = {
      TableName: TABLE_NAME,
      Key: { id },
      UpdateExpression: `SET ${updateExpression.join(', ')}`,
      ExpressionAttributeNames: Object.keys(expressionAttributeNames).length > 0
        ? expressionAttributeNames
        : undefined,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'
    };

    const result = await dynamodb.update(params).promise();

    // Send notification
    if (TOPIC_ARN) {
      await sns.publish({
        TopicArn: TOPIC_ARN,
        Subject: 'Item Updated',
        Message: JSON.stringify({
          action: 'updated',
          item: { id: result.Attributes.id, name: result.Attributes.name },
          timestamp: result.Attributes.updatedAt
        })
      }).promise();
    }

    return createResponse(200, { item: result.Attributes });
  } catch (error) {
    return handleError(error, { functionName: 'updateItem' });
  }
};

module.exports.deleteItem = async (event) => {
  try {
    const { id } = event.pathParameters;

    if (!id) {
      return createResponse(400, { message: 'Item ID is required' });
    }

    // Check if item exists
    const getParams = {
      TableName: TABLE_NAME,
      Key: { id }
    };

    const existingItem = await dynamodb.get(getParams).promise();

    if (!existingItem.Item) {
      return createResponse(404, { message: 'Item not found' });
    }

    const params = {
      TableName: TABLE_NAME,
      Key: { id }
    };

    await dynamodb.delete(params).promise();

    // Send notification
    if (TOPIC_ARN) {
      await sns.publish({
        TopicArn: TOPIC_ARN,
        Subject: 'Item Deleted',
        Message: JSON.stringify({
          action: 'deleted',
          item: { id: existingItem.Item.id, name: existingItem.Item.name },
          timestamp: new Date().toISOString()
        })
      }).promise();
    }

    return createResponse(200, {
      message: 'Item deleted successfully',
      item: existingItem.Item
    });
  } catch (error) {
    return handleError(error, { functionName: 'deleteItem' });
  }
};
```

### src/utils.js

```javascript
'use strict';

const AWS = require('aws-sdk');

// Utility function to validate UUID
const isValidUUID = (id) => {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
};

// Utility function to sanitize input
const sanitizeInput = (input) => {
  if (typeof input !== 'string') {
    return input;
  }

  return input
    .replace(/[<>]/g, '') // Remove potential HTML tags
    .trim();
};

// Utility function for pagination
const getPaginationParams = (event) => {
  const queryStringParameters = event.queryStringParameters || {};

  return {
    limit: Math.min(parseInt(queryStringParameters.limit) || 10, 100), // Max 100 items
    nextToken: queryStringParameters.nextToken || null
  };
};

// Utility function to format item response
const formatItem = (item) => {
  if (!item) return null;

  const { ttl, ...formattedItem } = item; // Remove TTL from response

  return formattedItem;
};

// Utility function for error logging
const logError = (error, context) => {
  const errorDetails = {
    message: error.message,
    name: error.name,
    stack: error.stack,
    requestId: context.awsRequestId,
    functionName: context.functionName,
    timestamp: new Date().toISOString()
  };

  console.error(JSON.stringify(errorDetails, null, 2));
};

module.exports = {
  isValidUUID,
  sanitizeInput,
  getPaginationParams,
  formatItem,
  logError
};
```

## Terraform Configuration

### main.tf

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

# Get SNS topic ARN for notifications
data "aws_sns_topic" "notifications" {
  name = "basic-service-dev-notifications"
}

# sls.tf module configuration
module "basic_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.yml"
  lambda_code_path = "${path.module}/src"

  # Environment variables for all functions
  environment = {
    SERVICE_NAME = "basic-service"
    NOTIFICATIONS_TOPIC_ARN = data.aws_sns_topic.notifications.arn
  }

  # Tags for all resources
  tags = {
    Project = "basic-service"
    Environment = "development"
    ManagedBy = "terraform"
  }

  # CloudWatch log retention
  log_retention = 14

  providers = {
    aws = aws
  }
}

# Outputs
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.basic_service.api_gateway_invoke_url
}

output "lambda_functions" {
  description = "Deployed Lambda function names"
  value       = module.basic_service.function_names
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.basic_service.dynamodb_table_names_map["ItemsTable"]
}

output "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  value       = data.aws_sns_topic.notifications.arn
}

# Display important information after deployment
resource "null_resource" "deployment_info" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "============================================"
      echo "Basic Service Deployment Complete!"
      echo "============================================"
      echo "API Gateway URL: ${module.basic_service.api_gateway_invoke_url}"
      echo "Health Check: ${module.basic_service.api_gateway_invoke_url}/health"
      echo "Items API: ${module.basic_service.api_gateway_invoke_url}/items"
      echo ""
      echo "Lambda Functions:"
      for func in ${join(" ", module.basic_service.function_names)}; do
        echo "  - $func"
      done
      echo ""
      echo "DynamoDB Table: ${module.basic_service.dynamodb_table_names_map["ItemsTable"]}"
      echo "SNS Topic: ${data.aws_sns_topic.notifications.arn}"
      echo "============================================"
    EOT
  }

  depends_on = [module.basic_service]
}
```

### package.json

```json
{
  "name": "basic-service",
  "version": "1.0.0",
  "description": "Basic serverless service example",
  "main": "src/handlers.js",
  "scripts": {
    "test": "jest",
    "lint": "eslint src/",
    "package": "zip -r deployment.zip src/ package.json",
    "local": "serverless offline"
  },
  "dependencies": {
    "aws-sdk": "^2.1500.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "eslint": "^8.50.0",
    "serverless-offline": "^13.3.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

## Deployment Steps

### 1. Initialize Terraform

```bash
# Initialize Terraform and download providers
terraform init

# Download sls.tf submodule
git submodule update --init --recursive
```

### 2. Review the Plan

```bash
# See what resources will be created
terraform plan
```

Expected output:
```
Terraform will perform the following actions:

  # aws_iam_role.lambda_execution_role will be created
  + resource "aws_iam_role" "lambda_execution_role" {
      + name               = "basic-service-dev-lambda-execution-role"
      + assume_role_policy = jsonencode(...)
    }

  # aws_dynamodb_table.items_table will be created
  + resource "aws_dynamodb_table" "items_table" {
      + name           = "basic-service-dev-items"
      + billing_mode   = "PAY_PER_REQUEST"
      + hash_key       = "id"
    }

  # aws_lambda_function.health will be created
  + resource "aws_lambda_function" "health" {
      + function_name = "basic-service-dev-health"
      + handler       = "src/handlers.health"
      + runtime       = "nodejs18.x"
      + memory_size   = 256
      + timeout       = 30
    }

  # aws_api_gateway_rest_api.api will be created
  # aws_sns_topic.notifications will be created
  # ... and many more resources

Plan: 25 to add, 0 to change, 0 to destroy.
```

### 3. Deploy the Service

```bash
# Apply the Terraform configuration
terraform apply
```

### 4. Test the Deployment

```bash
# Get the API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)

# Test health check
curl "${API_URL}/health"

# Test creating an item
curl -X POST "${API_URL}/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "This is a test item"}'

# Test listing items
curl "${API_URL}/items"

# Test getting a specific item (replace with actual ID)
curl "${API_URL}/items/YOUR_ITEM_ID"
```

## API Endpoints

### Health Check
```bash
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "service": "basic-service",
  "version": "1.0.0",
  "region": "us-east-1"
}
```

### List Items
```bash
GET /items
```

**Response:**
```json
{
  "items": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "name": "Test Item",
      "description": "This is a test item",
      "createdAt": "2024-01-15T10:30:00.000Z",
      "updatedAt": "2024-01-15T10:30:00.000Z"
    }
  ],
  "count": 1
}
```

### Create Item
```bash
POST /items
Content-Type: application/json

{
  "name": "New Item",
  "description": "Item description"
}
```

**Response:**
```json
{
  "item": {
    "id": "456e7890-e89b-12d3-a456-426614174001",
    "name": "New Item",
    "description": "Item description",
    "createdAt": "2024-01-15T10:35:00.000Z",
    "updatedAt": "2024-01-15T10:35:00.000Z"
  }
}
```

### Get Item
```bash
GET /items/{id}
```

### Update Item
```bash
PUT /items/{id}
Content-Type: application/json

{
  "name": "Updated Item",
  "description": "Updated description"
}
```

### Delete Item
```bash
DELETE /items/{id}
```

## Monitoring and Logs

### View CloudWatch Logs

```bash
# List log groups
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/basic-service-dev"

# View logs for health function
aws logs tail /aws/lambda/basic-service-dev-health --follow
```

### Monitor with CloudWatch Metrics

```bash
# Get Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=basic-service-dev-health \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## Cost Breakdown

This example creates resources that typically cost:

- **Lambda Functions**: ~$0.20/month (based on 1M requests)
- **API Gateway**: ~$3.50/month (based on 1M requests)
- **DynamoDB**: ~$1.25/month (based on on-demand pricing)
- **SNS**: ~$0.50/month (based on 1M notifications)
- **CloudWatch Logs**: ~$0.50/month (based on 5GB logs)

**Total Estimated Cost**: ~$6/month for moderate usage

## Next Steps

- 📖 [API Service Example](../examples/api-service) - More advanced API example
- 🚀 [Event-Driven Architecture](../examples/event-driven) - Event-driven examples
- 🔧 [Advanced Features](../../advanced/custom-resources) - Custom resources and extensions

---

<div class="hero-buttons">
  <a href="../examples/api-service" class="btn">Next: API Service</a>
  <a href="../features/lambda-functions" class="btn secondary">Learn About Functions</a>
</div>