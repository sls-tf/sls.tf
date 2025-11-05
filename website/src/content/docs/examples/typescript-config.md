---
title: TypeScript Configuration
description: Complete example using TypeScript configuration with async exports
sidebar:
  order: 4
---

# TypeScript Configuration

Complete example of using TypeScript configuration with async exports and dynamic values.

## Overview

This example demonstrates advanced TypeScript configuration capabilities:
- **Async Configuration**: Load dynamic values from external sources
- **Type Safety**: Full TypeScript support with type definitions
- **Environment-Specific Configs**: Different configurations per environment
- **Dynamic Resource Generation**: Generate resources based on runtime values

## Project Structure

```
typescript-service/
├── modules/
│   └── sls.tf/                    # sls.tf module
├── src/
│   ├── handlers/
│   │   ├── index.ts               # Main API handler
│   │   ├── users.ts               # User management
│   │   └── config.ts              # Configuration loader
│   ├── types/
│   │   └── index.ts               # TypeScript type definitions
│   └── utils/
│       ├── database.ts            # Database utilities
│       └── logger.ts              # Logging utilities
├── config/
│   ├── environments.json          # Environment-specific configs
│   └── features.json              # Feature flags
├── scripts/
│   ├── build.sh                   # Build script
│   └── deploy.sh                  # Deployment script
├── serverless.ts                  # TypeScript Serverless configuration
├── tsconfig.json                  # TypeScript configuration
├── package.json                   # Dependencies
├── main.tf                        # Terraform configuration
└── README.md                      # Documentation
```

## TypeScript Configuration

### serverless.ts

```typescript
import { Serverless } from '@serverless/types/aws';
import * as fs from 'fs';
import * as path from 'path';

// Type definitions for our configuration
interface EnvironmentConfig {
  name: string;
  region: string;
  runtime: string;
  memorySize: number;
  timeout: number;
  logRetention: number;
  enableTracing: boolean;
  enableMetrics: boolean;
}

interface FeatureConfig {
  name: string;
  enabled: boolean;
  config?: Record<string, any>;
}

interface DatabaseConfig {
  host: string;
  port: number;
  name: string;
  ssl: boolean;
  connectionPoolSize: number;
}

interface ServiceConfig {
  api: {
    version: string;
    corsOrigins: string[];
    rateLimit: number;
  };
  auth: {
    jwtSecret: string;
    tokenExpiry: string;
  };
  database: DatabaseConfig;
  features: FeatureConfig[];
}

// Load environment-specific configuration
async function loadEnvironmentConfig(stage: string): Promise<EnvironmentConfig> {
  const configPath = path.join(__dirname, 'config', 'environments.json');

  try {
    const configData = fs.readFileSync(configPath, 'utf8');
    const environments = JSON.parse(configData);

    if (!environments[stage]) {
      throw new Error(`Environment configuration not found for stage: ${stage}`);
    }

    return environments[stage];
  } catch (error) {
    console.warn(`Failed to load environment config for ${stage}:`, error);

    // Fallback to development defaults
    return {
      name: stage,
      region: 'us-east-1',
      runtime: 'nodejs18.x',
      memorySize: 256,
      timeout: 30,
      logRetention: 7,
      enableTracing: false,
      enableMetrics: false
    };
  }
}

// Load feature flags
async function loadFeatureFlags(stage: string): Promise<FeatureConfig[]> {
  const configPath = path.join(__dirname, 'config', 'features.json');

  try {
    const configData = fs.readFileSync(configPath, 'utf8');
    const allFeatures = JSON.parse(configData);

    // Filter features by stage and enabled status
    return allFeatures.filter((feature: any) => {
      if (feature.stages && !feature.stages.includes(stage)) {
        return false;
      }
      return feature.enabled !== false;
    });
  } catch (error) {
    console.warn('Failed to load feature flags:', error);
    return [];
  }
}

// Load database configuration from environment variables or external source
async function loadDatabaseConfig(stage: string): Promise<DatabaseConfig> {
  // Try to load from environment variables first
  if (process.env.DB_HOST) {
    return {
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432'),
      name: process.env.DB_NAME || `typescript-service-${stage}`,
      ssl: process.env.DB_SSL === 'true',
      connectionPoolSize: parseInt(process.env.DB_POOL_SIZE || '10')
    };
  }

  // Fallback to external configuration service
  try {
    const configServiceUrl = process.env.CONFIG_SERVICE_URL;
    if (configServiceUrl) {
      const response = await fetch(`${configServiceUrl}/database/${stage}`, {
        headers: {
          'Authorization': `Bearer ${process.env.CONFIG_SERVICE_TOKEN}`
        }
      });

      if (response.ok) {
        return await response.json();
      }
    }
  } catch (error) {
    console.warn('Failed to load database config from service:', error);
  }

  // Final fallback to defaults
  return {
    host: stage === 'prod' ? 'prod-db.example.com' : 'localhost',
    port: 5432,
    name: `typescript-service-${stage}`,
    ssl: stage === 'prod',
    connectionPoolSize: stage === 'prod' ? 20 : 5
  };
}

// Load service configuration
async function loadServiceConfig(stage: string): Promise<ServiceConfig> {
  const featureFlags = await loadFeatureFlags(stage);
  const databaseConfig = await loadDatabaseConfig(stage);

  return {
    api: {
      version: stage === 'prod' ? 'v1' : 'v1-beta',
      corsOrigins: stage === 'prod'
        ? ['https://app.example.com', 'https://admin.example.com']
        : ['http://localhost:3000', 'http://localhost:3001'],
      rateLimit: stage === 'prod' ? 1000 : 100
    },
    auth: {
      jwtSecret: process.env.JWT_SECRET || 'fallback-secret-change-in-production',
      tokenExpiry: stage === 'prod' ? '1h' : '24h'
    },
    database: databaseConfig,
    features: featureFlags
  };
}

// Generate DynamoDB table resources based on features
function generateDynamoTables(serviceConfig: ServiceConfig, stage: string) {
  const tables: any = {
    UsersTable: {
      Type: 'AWS::DynamoDB::Table',
      Properties: {
        TableName: `typescript-service-${stage}-users`,
        BillingMode: 'PAY_PER_REQUEST',
        AttributeDefinitions: [
          { AttributeName: 'id', AttributeType: 'S' },
          { AttributeName: 'email', AttributeType: 'S' },
          { AttributeName: 'createdAt', AttributeType: 'S' }
        ],
        KeySchema: [
          { AttributeName: 'id', KeyType: 'HASH' }
        ],
        GlobalSecondaryIndexes: [
          {
            IndexName: 'EmailIndex',
            KeySchema: [
              { AttributeName: 'email', KeyType: 'HASH' }
            ],
            Projection: { ProjectionType: 'ALL' }
          },
          {
            IndexName: 'CreatedAtIndex',
            KeySchema: [
              { AttributeName: 'createdAt', KeyType: 'HASH' }
            ],
            Projection: { ProjectionType: 'ALL' }
          }
        ],
        StreamSpecification: {
          StreamViewType: 'NEW_AND_OLD_IMAGES'
        },
        TimeToLiveSpecification: {
          AttributeName: 'ttl',
          Enabled: true
        },
        SSESpecification: {
          SSEEnabled: true
        },
        PointInTimeRecoverySpecification: {
          PointInTimeRecoveryEnabled: stage === 'prod'
        }
      }
    }
  };

  // Add audit table if audit feature is enabled
  const auditFeature = serviceConfig.features.find(f => f.name === 'audit');
  if (auditFeature && auditFeature.enabled) {
    tables.AuditTable = {
      Type: 'AWS::DynamoDB::Table',
      Properties: {
        TableName: `typescript-service-${stage}-audit`,
        BillingMode: 'PAY_PER_REQUEST',
        AttributeDefinitions: [
          { AttributeName: 'id', AttributeType: 'S' },
          { AttributeName: 'entityId', AttributeType: 'S' },
          { AttributeName: 'entityType', AttributeType: 'S' },
          { AttributeName: 'timestamp', AttributeType: 'S' }
        ],
        KeySchema: [
          { AttributeName: 'id', KeyType: 'HASH' }
        ],
        GlobalSecondaryIndexes: [
          {
            IndexName: 'EntityIndex',
            KeySchema: [
              { AttributeName: 'entityId', KeyType: 'HASH' },
              { AttributeName: 'entityType', KeyType: 'RANGE' }
            ],
            Projection: { ProjectionType: 'ALL' }
          },
          {
            IndexName: 'TimestampIndex',
            KeySchema: [
              { AttributeName: 'timestamp', KeyType: 'HASH' }
            ],
            Projection: { ProjectionType: 'ALL' }
          }
        ],
        TimeToLiveSpecification: {
          AttributeName: 'ttl',
          Enabled: true
        },
        SSESpecification: {
          SSEEnabled: true
        }
      }
    };
  }

  // Add cache table if caching feature is enabled
  const cacheFeature = serviceConfig.features.find(f => f.name === 'cache');
  if (cacheFeature && cacheFeature.enabled) {
    tables.CacheTable = {
      Type: 'AWS::DynamoDB::Table',
      Properties: {
        TableName: `typescript-service-${stage}-cache`,
        BillingMode: 'PAY_PER_REQUEST',
        AttributeDefinitions: [
          { AttributeName: 'cacheKey', AttributeType: 'S' },
          { AttributeName: 'ttl', AttributeType: 'N' }
        ],
        KeySchema: [
          { AttributeName: 'cacheKey', KeyType: 'HASH' }
        ],
        TimeToLiveSpecification: {
          AttributeName: 'ttl',
          Enabled: true
        },
        SSESpecification: {
          SSEEnabled: true
        }
      }
    };
  }

  return tables;
}

// Generate function definitions based on enabled features
function generateFunctions(serviceConfig: ServiceConfig, stage: string) {
  const functions: any = {
    api: {
      handler: 'dist/handlers/index.handler',
      description: 'Main API handler',
      memorySize: serviceConfig.database.connectionPoolSize * 20, // Scale memory with connection pool
      timeout: 60,
      environment: {
        NODE_ENV: stage,
        API_VERSION: serviceConfig.api.version,
        JWT_SECRET: serviceConfig.auth.jwtSecret,
        TOKEN_EXPIRY: serviceConfig.auth.tokenExpiry,
        DB_HOST: serviceConfig.database.host,
        DB_PORT: serviceConfig.database.port.toString(),
        DB_NAME: serviceConfig.database.name,
        DB_SSL: serviceConfig.database.ssl.toString(),
        DB_POOL_SIZE: serviceConfig.database.connectionPoolSize.toString(),
        CORS_ORIGINS: serviceConfig.api.corsOrigins.join(','),
        RATE_LIMIT: serviceConfig.api.rateLimit.toString()
      },
      events: [
        {
          http: {
            path: '/{proxy+}',
            method: 'any',
            cors: {
              origins: serviceConfig.api.corsOrigins,
              headers: ['Content-Type', 'X-Amz-Date', 'Authorization', 'X-Api-Key', 'X-Amz-Security-Token'],
              allowCredentials: true
            }
          }
        }
      ]
    }
  };

  // Add user management functions
  functions.users = {
    handler: 'dist/handlers/users.handler',
    description: 'User management functions',
    memorySize: 256,
    timeout: 30,
    environment: {
      NODE_ENV: stage,
      JWT_SECRET: serviceConfig.auth.jwtSecret,
      TOKEN_EXPIRY: serviceConfig.auth.tokenExpiry
    },
    events: [
      {
        http: {
          path: '/users',
          method: 'post',
          cors: {
            origins: serviceConfig.api.corsOrigins,
            allowCredentials: true
          }
        }
      },
      {
        http: {
          path: '/users/{id}',
          method: 'get',
          cors: {
            origins: serviceConfig.api.corsOrigins,
            allowCredentials: true
          },
          request: {
            parameters: {
              paths: {
                id: true
              }
            }
          }
        }
      }
    ]
  };

  // Add scheduled cleanup function
  functions.cleanup = {
    handler: 'dist/handlers/cleanup.handler',
    description: 'Scheduled cleanup task',
    memorySize: 512,
    timeout: 900, // 15 minutes
    environment: {
      NODE_ENV: stage,
      CLEANUP_RETENTION_DAYS: '30'
    },
    events: [
      {
        schedule: {
          rate: 'rate(6 hours)',
          enabled: stage !== 'dev',
          input: {
            action: 'cleanup_expired_records',
            dryRun: stage === 'dev'
          }
        }
      }
    ]
  };

  // Add audit processor if audit feature is enabled
  const auditFeature = serviceConfig.features.find(f => f.name === 'audit');
  if (auditFeature && auditFeature.enabled) {
    functions.auditProcessor = {
      handler: 'dist/handlers/audit.handler',
      description: 'Process audit events from DynamoDB streams',
      memorySize: 256,
      timeout: 300,
      environment: {
        NODE_ENV: stage,
        AUDIT_TOPIC_ARN: { 'Fn::ImportValue': `${service.name}-${stage}-audit-topic` }
      },
      events: [
        {
          stream: {
            type: 'dynamodb',
            arn: { 'Fn::GetAtt': ['UsersTable', 'StreamArn'] },
            batchSize: 10,
            startingPosition: 'LATEST'
          }
        }
      ]
    };
  }

  return functions;
}

// Main configuration export
export default async (): Promise<Serverless> => {
  const stage = process.env.NODE_ENV || 'dev';

  console.log(`Loading TypeScript configuration for stage: ${stage}`);

  // Load all configurations
  const [envConfig, serviceConfig] = await Promise.all([
    loadEnvironmentConfig(stage),
    loadServiceConfig(stage)
  ]);

  console.log(`Configuration loaded for ${envConfig.name} environment`);
  console.log(`Enabled features: ${serviceConfig.features.map(f => f.name).join(', ')}`);

  const serverlessConfig: Serverless = {
    service: 'typescript-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: envConfig.runtime as any,
      region: envConfig.region,
      stage: envConfig.name,

      memorySize: envConfig.memorySize,
      timeout: envConfig.timeout,

      environment: {
        NODE_ENV: envConfig.name,
        SERVICE_VERSION: '2.1.0',
        CONFIG_LOADED_AT: new Date().toISOString()
      },

      iam: {
        role: {
          statements: [
            // DynamoDB permissions
            {
              Effect: 'Allow',
              Action: [
                'dynamodb:GetItem',
                'dynamodb:PutItem',
                'dynamodb:UpdateItem',
                'dynamodb:DeleteItem',
                'dynamodb:Query',
                'dynamodb:Scan',
                'dynamodb:BatchGetItem',
                'dynamodb:BatchWriteItem'
              ],
              Resource: [
                `arn:aws:dynamodb:${envConfig.region}:*:table/typescript-service-${envConfig.name}-*`,
                `arn:aws:dynamodb:${envConfig.region}:*:table/typescript-service-${envConfig.name}-*/index/*`
              ]
            },
            // CloudWatch Logs permissions
            {
              Effect: 'Allow',
              Action: [
                'logs:CreateLogGroup',
                'logs:CreateLogStream',
                'logs:PutLogEvents'
              ],
              Resource: `arn:aws:logs:${envConfig.region}:*:*`
            },
            // Additional permissions for enabled features
            ...(serviceConfig.features.some(f => f.name === 'audit') ? [{
              Effect: 'Allow',
              Action: [
                'sns:Publish'
              ],
              Resource: `arn:aws:sns:${envConfig.region}:*:typescript-service-${envConfig.name}-audit*`
            }] : [])
          ]
        }
      },

      logs: {
        retentionInDays: envConfig.logRetention
      },

      tracing: {
        lambda: envConfig.enableTracing
      },

      // Tags for all resources
      stackTags: {
        Service: 'typescript-service',
        Environment: envConfig.name,
        ManagedBy: 'sls.tf',
        Configuration: 'typescript'
      }
    },

    functions: generateFunctions(serviceConfig, envConfig.name),

    plugins: serviceConfig.features.some(f => f.name === 'webpack') ? [
      'serverless-webpack'
    ] : [],

    resources: {
      Resources: {
        ...generateDynamoTables(serviceConfig, envConfig.name),

        // SNS topic for notifications
        NotificationsTopic: {
          Type: 'AWS::SNS::Topic',
          Properties: {
            TopicName: `typescript-service-${envConfig.name}-notifications`,
            DisplayName: 'TypeScript Service Notifications',
            KmsMasterKeyId: stage === 'prod' ? 'alias/aws/sns' : undefined
          }
        },

        // CloudWatch alarms for production
        ...(stage === 'prod' ? {
          ApiErrorAlarm: {
            Type: 'AWS::CloudWatch::Alarm',
            Properties: {
              AlarmName: `typescript-service-${envConfig.name}-api-errors`,
              AlarmDescription: 'API error rate is too high',
              MetricName: 'Errors',
              Namespace: 'AWS/Lambda',
              Statistic: 'Sum',
              Period: 300,
              EvaluationPeriods: 2,
              Threshold: 10,
              ComparisonOperator: 'GreaterThanThreshold',
              Dimensions: [
                {
                  Name: 'FunctionName',
                  Value: `typescript-service-${envConfig.name}-api`
                }
              ],
              AlarmActions: [
                { 'Ref': 'NotificationsTopic' }
              ]
            }
          }
        } : {})
      },

      Outputs: {
        ApiUrl: {
          Description: 'API Gateway invoke URL',
          Value: {
            'Fn::Sub': 'https://${ApiGatewayRestApi}.execute-api.${AWS::Region}.amazonaws.com/${envConfig.name}'
          },
          Export: {
            Name: `typescript-service-${envConfig.name}-api-url`
          }
        },

        UsersTableName: {
          Description: 'Users table name',
          Value: { 'Ref': 'UsersTable' },
          Export: {
            Name: `typescript-service-${envConfig.name}-users-table`
          }
        },

        NotificationsTopicArn: {
          Description: 'SNS topic ARN for notifications',
          Value: { 'Ref': 'NotificationsTopic' },
          Export: {
            Name: `typescript-service-${envConfig.name}-notifications-topic`
          }
        }
      }
    }
  };

  console.log('TypeScript configuration generated successfully');
  return serverlessConfig;
};
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "types": ["node", "jest"]
  },
  "include": [
    "src/**/*",
    "serverless.ts",
    "scripts/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "**/*.test.ts",
    "**/*.spec.ts"
  ]
}
```

### config/environments.json

```json
{
  "dev": {
    "name": "dev",
    "region": "us-east-1",
    "runtime": "nodejs18.x",
    "memorySize": 256,
    "timeout": 30,
    "logRetention": 7,
    "enableTracing": false,
    "enableMetrics": false
  },
  "staging": {
    "name": "staging",
    "region": "us-east-1",
    "runtime": "nodejs18.x",
    "memorySize": 512,
    "timeout": 60,
    "logRetention": 30,
    "enableTracing": true,
    "enableMetrics": true
  },
  "prod": {
    "name": "prod",
    "region": "us-west-2",
    "runtime": "nodejs18.x",
    "memorySize": 1024,
    "timeout": 60,
    "logRetention": 90,
    "enableTracing": true,
    "enableMetrics": true
  }
}
```

### config/features.json

```json
[
  {
    "name": "audit",
    "enabled": true,
    "stages": ["staging", "prod"],
    "config": {
      "retention_days": 365,
      "async_processing": true
    }
  },
  {
    "name": "cache",
    "enabled": true,
    "stages": ["prod"],
    "config": {
      "ttl_minutes": 15,
      "max_items": 10000
    }
  },
  {
    "name": "webpack",
    "enabled": true,
    "stages": ["dev", "staging", "prod"]
  },
  {
    "name": "rate_limiting",
    "enabled": true,
    "stages": ["prod"],
    "config": {
      "requests_per_minute": 1000,
      "burst_size": 200
    }
  },
  {
    "name": "debug_mode",
    "enabled": true,
    "stages": ["dev"],
    "config": {
      "verbose_logging": true,
      "performance_monitoring": true
    }
  }
]
```

## Lambda Function Code

### src/handlers/index.ts

```typescript
import { APIGatewayProxyEvent, APIGatewayProxyResult, Context } from 'aws-lambda';
import { APIRouter } from '../utils/router';
import { Logger } from '../utils/logger';
import { Database } from '../utils/database';

// Initialize utilities
const logger = new Logger();
const database = new Database();
const router = new APIRouter();

// Health check endpoint
router.get('/health', async (event) => {
  return {
    statusCode: 200,
    body: JSON.stringify({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: process.env.SERVICE_NAME || 'typescript-service',
      version: process.env.SERVICE_VERSION || '2.1.0',
      region: process.env.AWS_REGION,
      environment: process.env.NODE_ENV
    })
  };
});

// API info endpoint
router.get('/api/info', async (event) => {
  return {
    statusCode: 200,
    body: JSON.stringify({
      apiVersion: process.env.API_VERSION,
      features: {
        audit: process.env.AUDIT_ENABLED === 'true',
        cache: process.env.CACHE_ENABLED === 'true',
        tracing: process.env.AWS_XRAY_DAEMON_ADDRESS !== undefined
      },
      endpoints: [
        'GET /health',
        'GET /api/info',
        'POST /users',
        'GET /users/{id}'
      ]
    })
  };
});

// 404 handler for unknown routes
router.use('*', async (event) => {
  return {
    statusCode: 404,
    body: JSON.stringify({
      error: 'Not Found',
      message: `Route ${event.httpMethod} ${event.path} not found`,
      timestamp: new Date().toISOString()
    })
  };
});

// Main handler
export const handler = async (
  event: APIGatewayProxyEvent,
  context: Context
): Promise<APIGatewayProxyResult> => {
  // Add request ID to logger context
  logger.setContext('requestId', context.awsRequestId);
  logger.info('Request received', {
    method: event.httpMethod,
    path: event.path,
    userAgent: event.requestContext?.identity?.userAgent
  });

  try {
    // Initialize database connection
    await database.connect();

    // Route the request
    const result = await router.handle(event);

    // Log response
    logger.info('Request completed', {
      statusCode: result.statusCode,
      method: event.httpMethod,
      path: event.path
    });

    return result;
  } catch (error) {
    logger.error('Request failed', error as Error);

    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': process.env.CORS_ORIGINS?.split(',')[0] || '*'
      },
      body: JSON.stringify({
        error: 'Internal Server Error',
        message: process.env.NODE_ENV === 'dev' ? (error as Error).message : undefined,
        requestId: context.awsRequestId,
        timestamp: new Date().toISOString()
      })
    };
  } finally {
    // Close database connection
    await database.disconnect();
  }
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

# Environment variables for TypeScript configuration
environment {
  NODE_ENV = "dev"
  DB_HOST = "localhost"
  DB_SSL = "false"
  JWT_SECRET = "dev-secret-change-in-production"
  CONFIG_SERVICE_URL = "https://config.example.com"
}

# sls.tf module with TypeScript configuration
module "typescript_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.ts"
  config_format = "typescript"
  lambda_code_path = "${path.module}/dist"

  # Custom variables for TypeScript configuration
  custom_variables = {
    NODE_ENV = var.environment
    DB_HOST = var.db_host
    DB_SSL = var.db_ssl
    JWT_SECRET = var.jwt_secret
    CONFIG_SERVICE_URL = var.config_service_url
  }

  # Environment-specific settings
  environment = {
    NODE_ENV = var.environment
    CONFIG_LOADED_AT = timestamp()
  }

  tags = {
    Service = "typescript-service"
    Environment = var.environment
    Configuration = "typescript"
    ManagedBy = "terraform"
  }

  providers = {
    aws = aws
  }
}

# Variables
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = "localhost"
}

variable "db_ssl" {
  description = "Enable SSL for database connections"
  type        = bool
  default     = false
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  sensitive   = true
  default     = "dev-secret-change-in-production"
}

variable "config_service_url" {
  description = "External configuration service URL"
  type        = string
  default     = ""
}

# Outputs
output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = module.typescript_service.api_gateway_invoke_url
}

output "service_name" {
  description = "Service name"
  value       = module.typescript_service.service_name
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "lambda_functions" {
  description = "Deployed Lambda function names"
  value       = module.typescript_service.function_names
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.typescript_service.dynamodb_table_names
}

# Local file provisioner to show deployment info
resource "null_resource" "deployment_info" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "=================================================="
      echo "TypeScript Service Deployment Complete!"
      echo "=================================================="
      echo "Environment: ${var.environment}"
      echo "API Gateway URL: ${module.typescript_service.api_gateway_invoke_url}"
      echo "Health Check: ${module.typescript_service.api_gateway_invoke_url}/health"
      echo "API Info: ${module.typescript_service.api_gateway_invoke_url}/api/info"
      echo ""
      echo "Configuration Type: TypeScript"
      echo "Features: Enabled based on config/features.json"
      echo "=================================================="
    EOT
  }

  depends_on = [module.typescript_service]
}
```

## Build and Deployment

### scripts/build.sh

```bash
#!/bin/bash

set -e

echo "Building TypeScript service..."

# Clean previous build
rm -rf dist/

# Install dependencies
echo "Installing dependencies..."
npm ci

# Run TypeScript compiler
echo "Compiling TypeScript..."
npx tsc

# Copy additional files
echo "Copying additional files..."
cp package*.json dist/
cp -r config dist/

# Run tests
echo "Running tests..."
npm test

echo "Build complete! Output: ./dist/"
```

### scripts/deploy.sh

```bash
#!/bin/bash

set -e

# Default environment
ENVIRONMENT=${1:-dev}

echo "Deploying TypeScript service to $ENVIRONMENT environment..."

# Set environment variables
export NODE_ENV=$ENVIRONMENT
export TF_VAR_environment=$ENVIRONMENT

# Build the project
echo "Building project..."
./scripts/build.sh

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan deployment
echo "Planning deployment..."
terraform plan -var="environment=$ENVIRONMENT" -out=tfplan

# Apply deployment
echo "Applying deployment..."
terraform apply tfplan

echo "Deployment complete!"
```

### package.json

```json
{
  "name": "typescript-service",
  "version": "2.1.0",
  "description": "TypeScript-powered serverless service",
  "main": "dist/handlers/index.js",
  "scripts": {
    "build": "npx tsc",
    "build:watch": "npx tsc --watch",
    "test": "jest",
    "test:watch": "jest --watch",
    "lint": "eslint src/**/*.ts",
    "lint:fix": "eslint src/**/*.ts --fix",
    "start": "serverless offline",
    "deploy:dev": "./scripts/deploy.sh dev",
    "deploy:staging": "./scripts/deploy.sh staging",
    "deploy:prod": "./scripts/deploy.sh prod",
    "package": "./scripts/build.sh && zip -r deployment.zip dist/"
  },
  "dependencies": {
    "aws-lambda": "^1.0.7",
    "aws-sdk": "^2.1500.0"
  },
  "devDependencies": {
    "@types/aws-lambda": "^8.10.119",
    "@types/jest": "^29.5.5",
    "@types/node": "^20.6.3",
    "@typescript-eslint/eslint-plugin": "^6.7.0",
    "@typescript-eslint/parser": "^6.7.0",
    "eslint": "^8.49.0",
    "jest": "^29.7.0",
    "serverless": "^3.35.2",
    "serverless-offline": "^13.3.0",
    "serverless-webpack": "^5.13.0",
    "ts-jest": "^29.1.1",
    "ts-node": "^10.9.1",
    "typescript": "^5.2.2",
    "webpack": "^5.88.2"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

## Deployment Steps

### 1. Setup Environment

```bash
# Clone the repository
git clone <repository-url>
cd typescript-service

# Add sls.tf submodule
git submodule add https://github.com/your-org/sls.tf.git modules/sls.tf
git submodule update --init --recursive

# Install dependencies
npm install
```

### 2. Configure Environment Variables

```bash
# Set environment variables
export NODE_ENV=dev
export DB_HOST=localhost
export JWT_SECRET=your-secret-key
```

### 3. Build and Deploy

```bash
# Build the TypeScript configuration
npm run build

# Deploy to development environment
npm run deploy:dev

# Or deploy to other environments
npm run deploy:staging
npm run deploy:prod
```

### 4. Test the Deployment

```bash
# Get the API URL
API_URL=$(terraform output -raw api_gateway_url)

# Test health check
curl "${API_URL}/health"

# Test API info
curl "${API_URL}/api/info"

# Test user creation
curl -X POST "${API_URL}/users" \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'
```

## Benefits of TypeScript Configuration

### 1. Type Safety
- Catch configuration errors at compile time
- Autocomplete and IDE support
- Refactoring safety

### 2. Dynamic Configuration
- Load configuration from external sources
- Environment-specific settings
- Runtime value generation

### 3. Maintainability
- Code organization and reusability
- Documentation through types
- Easier testing and validation

### 4. Advanced Features
- Async/await support
- Complex logic and calculations
- Integration with external services

## Next Steps

- 📖 [Event-Driven Architecture](../examples/event-driven) - Event-driven examples
- 🔧 [Advanced Features](../../advanced/custom-resources) - Custom resources and extensions
- 📚 [Variable Resolution](../../features/variable-resolution) - Advanced variable handling

---

<div class="hero-buttons">
  <a href="../examples/event-driven" class="btn">Next: Event-Driven</a>
  <a href="../../features/typescript" class="btn secondary">Learn About TypeScript</a>
</div>