---
title: TypeScript Support
description: Complete guide to TypeScript configuration and async exports
sidebar:
  order: 5
---

# TypeScript Support

Complete guide to using TypeScript configurations with sls.tf, including async exports and dynamic values.

## Overview

sls.tf provides first-class support for TypeScript configuration files, enabling:

- **Type Safety**: Catch configuration errors at compile time
- **Async Exports**: Load dynamic values from databases, APIs, or external services
- **Dynamic Configuration**: Generate configuration based on environment, secrets, or runtime values
- **IDE Support**: Better autocompletion and refactoring in modern IDEs

## TypeScript Configuration Format

### Basic TypeScript Configuration

```typescript
import { Serverless } from '@serverless/types/aws';

const serverlessConfiguration: Serverless = {
  service: 'my-typescript-service',
  frameworkVersion: '3',

  provider: {
    name: 'aws',
    runtime: 'nodejs18.x',
    region: 'us-east-1',
    stage: 'dev'
  },

  functions: {
    hello: {
      handler: 'src/handler.hello',
      events: [
        {
          http: {
            path: '/hello',
            method: 'get',
            cors: true
          }
        }
      ]
    }
  }
};

export default serverlessConfiguration;
```

### Terraform Configuration

```hcl
module "serverless_service" {
  source = "./modules/sls.tf"

  config_path = "${path.module}/serverless.ts"
  config_format = "typescript"
  lambda_code_path = "${path.module}/dist"
}
```

## Async Exports

### Dynamic Environment Variables

Load configuration from environment variables, databases, or external APIs:

```typescript
import { Serverless } from '@serverless/types/aws';

async function loadDatabaseConfig() {
  // Simulate database or API call
  const dbConfig = await fetch(`${process.env.CONFIG_API_URL}/database`)
    .then(res => res.json());

  return dbConfig;
}

async function getSecrets() {
  // Load secrets from AWS Secrets Manager or similar
  const secrets = {
    DB_PASSWORD: process.env.DB_PASSWORD,
    API_KEY: process.env.API_KEY,
    JWT_SECRET: process.env.JWT_SECRET
  };

  return secrets;
}

export default async (): Promise<Serverless> => {
  const stage = process.env.NODE_ENV || 'dev';
  const dbConfig = await loadDatabaseConfig();
  const secrets = await getSecrets();

  return {
    service: 'dynamic-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: 'nodejs18.x',
      region: process.env.AWS_REGION || 'us-east-1',
      stage,

      environment: {
        NODE_ENV: stage,
        DB_HOST: dbConfig.host,
        DB_NAME: dbConfig.name,
        DB_PASSWORD: secrets.DB_PASSWORD,
        API_KEY: secrets.API_KEY,
        JWT_SECRET: secrets.JWT_SECRET
      },

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
              Resource: [`arn:aws:dynamodb:*:*:table/my-app-${stage}-data`]
            }
          ]
        }
      }
    },

    functions: {
      api: {
        handler: 'dist/index.handler',
        environment: {
          DB_TABLE: `my-app-${stage}-data`,
          CACHE_TTL: stage === 'prod' ? '300' : '60'
        },
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

    resources: {
      Resources: {
        DataTable: {
          Type: 'AWS::DynamoDB::Table',
          Properties: {
            TableName: `my-app-${stage}-data`,
            BillingMode: 'PAY_PER_REQUEST',
            AttributeDefinitions: [
              { AttributeName: 'id', AttributeType: 'S' }
            ],
            KeySchema: [
              { AttributeName: 'id', KeyType: 'HASH' }
            ]
          }
        }
      }
    }
  };
};
```

### Configuration from Multiple Sources

```typescript
import { Serverless } from '@serverless/types/aws';
import * as fs from 'fs';
import * as path from 'path';

interface AppConfig {
  api: {
    version: string;
    features: string[];
  };
  database: {
    host: string;
    name: string;
  };
  secrets: {
    jwtSecret: string;
    apiKey: string;
  };
}

async function loadConfigFile(): Promise<Partial<AppConfig>> {
  const configPath = path.join(__dirname, 'config', 'app.json');

  try {
    const configData = fs.readFileSync(configPath, 'utf8');
    return JSON.parse(configData);
  } catch (error) {
    console.warn('Config file not found, using defaults');
    return {};
  }
}

async function loadEnvironmentConfig(): Promise<Partial<AppConfig>> {
  return {
    secrets: {
      jwtSecret: process.env.JWT_SECRET || 'default-secret',
      apiKey: process.env.API_KEY || 'default-key'
    }
  };
}

async function loadRemoteConfig(): Promise<Partial<AppConfig>> {
  const configUrl = process.env.REMOTE_CONFIG_URL;

  if (!configUrl) {
    return {};
  }

  try {
    const response = await fetch(configUrl);
    return await response.json();
  } catch (error) {
    console.warn('Failed to load remote config:', error);
    return {};
  }
}

export default async (): Promise<Serverless> => {
  const stage = process.env.NODE_ENV || 'dev';
  const [fileConfig, envConfig, remoteConfig] = await Promise.all([
    loadConfigFile(),
    loadEnvironmentConfig(),
    loadRemoteConfig()
  ]);

  const config: AppConfig = {
    api: {
      version: 'v1',
      features: ['cors', 'logging'],
      ...fileConfig.api,
      ...remoteConfig.api
    },
    database: {
      host: 'localhost',
      name: 'myapp',
      ...fileConfig.database,
      ...remoteConfig.database
    },
    secrets: {
      jwtSecret: 'fallback-secret',
      apiKey: 'fallback-key',
      ...envConfig.secrets
    }
  };

  return {
    service: 'multi-source-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: 'nodejs18.x',
      region: process.env.AWS_REGION || 'us-east-1',
      stage,

      environment: {
        NODE_ENV: stage,
        API_VERSION: config.api.version,
        DB_HOST: config.database.host,
        DB_NAME: config.database.name,
        JWT_SECRET: config.secrets.jwtSecret,
        API_KEY: config.secrets.apiKey,
        ENABLED_FEATURES: config.api.features.join(',')
      }
    },

    functions: {
      api: {
        handler: 'dist/index.handler',
        memorySize: stage === 'prod' ? 512 : 256,
        timeout: stage === 'prod' ? 60 : 30,
        events: [
          {
            http: {
              path: '/{proxy+}',
              method: 'any',
              cors: config.api.features.includes('cors')
            }
          }
        ]
      }
    }
  };
};
```

### Dynamic Function Configuration

```typescript
import { Serverless } from '@serverless/types/aws';

interface FunctionConfig {
  name: string;
  handler: string;
  memorySize?: number;
  timeout?: number;
  environment?: Record<string, string>;
}

async function loadFunctionConfigs(): Promise<FunctionConfig[]> {
  // Load function configurations from API or database
  const functions = await fetch(`${process.env.FUNCTION_REGISTRY_URL}/functions`)
    .then(res => res.json());

  return functions.map((func: any) => ({
    name: func.name,
    handler: func.handler,
    memorySize: func.memorySize,
    timeout: func.timeout,
    environment: func.environment
  }));
}

export default async (): Promise<Serverless> => {
  const stage = process.env.NODE_ENV || 'dev';
  const functionConfigs = await loadFunctionConfigs();

  // Convert array of configs to functions object
  const functions = functionConfigs.reduce((acc, config) => {
    acc[config.name] = {
      handler: config.handler,
      memorySize: config.memorySize || 256,
      timeout: config.timeout || 30,
      environment: {
        ...config.environment,
        NODE_ENV: stage
      },
      events: [
        {
          http: {
            path: `/${config.name}`,
            method: 'post',
            cors: true
          }
        }
      ]
    };
    return acc;
  }, {} as Record<string, any>);

  return {
    service: 'dynamic-functions-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: 'nodejs18.x',
      region: process.env.AWS_REGION || 'us-east-1',
      stage
    },

    functions
  };
};
```

## Environment-Specific Configuration

### Multi-Environment Setup

```typescript
import { Serverless } from '@serverless/types/aws';

interface EnvironmentConfig {
  region: string;
  memorySize: number;
  timeout: number;
  logRetention: number;
  enableTracing: boolean;
}

const environmentConfigs: Record<string, EnvironmentConfig> = {
  dev: {
    region: 'us-east-1',
    memorySize: 256,
    timeout: 30,
    logRetention: 7,
    enableTracing: false
  },
  staging: {
    region: 'us-east-1',
    memorySize: 512,
    timeout: 60,
    logRetention: 30,
    enableTracing: true
  },
  prod: {
    region: 'us-west-2',
    memorySize: 1024,
    timeout: 60,
    logRetention: 90,
    enableTracing: true
  }
};

export default async (): Promise<Serverless> => {
  const stage = process.env.NODE_ENV || 'dev';
  const config = environmentConfigs[stage] || environmentConfigs.dev;

  return {
    service: 'multi-env-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: 'nodejs18.x',
      region: config.region,
      stage,

      memorySize: config.memorySize,
      timeout: config.timeout,

      environment: {
        NODE_ENV: stage,
        LOG_LEVEL: stage === 'prod' ? 'error' : 'debug',
        ENABLE_METRICS: stage === 'prod' ? 'true' : 'false'
      },

      tracing: {
        lambda: config.enableTracing
      },

      logs: {
        retentionInDays: config.logRetention
      }
    },

    functions: {
      api: {
        handler: 'dist/index.handler',
        memorySize: config.memorySize,
        timeout: config.timeout,
        tracing: config.enableTracing ? 'Active' : 'PassThrough',
        events: [
          {
            http: {
              path: '/{proxy+}',
              method: 'any',
              cors: true
            }
          }
        ]
      },

      background: {
        handler: 'dist/background.handler',
        memorySize: stage === 'prod' ? 512 : 256,
        timeout: 900,
        events: [
          {
            schedule: {
              rate: 'rate(5 minutes)',
              enabled: stage !== 'dev'
            }
          }
        ]
      }
    }
  };
};
```

## TypeScript Project Setup

### Dependencies

Install TypeScript and type definitions:

```bash
npm install --save-dev typescript @types/node
npm install --save-dev @serverless/types @serverless/typescript
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
    "sourceMap": true
  },
  "include": [
    "src/**/*",
    "serverless.ts"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
```

### Build Scripts

```json
{
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "sls:package": "npm run build && serverless package",
    "sls:deploy": "npm run build && serverless deploy"
  }
}
```

## Advanced TypeScript Features

### Type-Safe Configuration

```typescript
import { Serverless } from '@serverless/types/aws';

// Define custom types for your configuration
interface CustomProvider {
  name: 'aws';
  runtime: 'nodejs18.x' | 'python3.11';
  region: string;
  stage: string;
  environment: {
    NODE_ENV: string;
    API_VERSION: 'v1' | 'v2';
    DB_HOST: string;
    ENABLE_CORS: boolean;
  };
}

interface CustomFunction {
  handler: string;
  memorySize?: number;
  timeout?: number;
  environment?: Record<string, string>;
  events: Array<{
    http: {
      path: string;
      method: string;
      cors?: boolean;
    };
  }>;
}

interface CustomServerless extends Omit<Serverless, 'provider' | 'functions'> {
  provider: CustomProvider;
  functions: Record<string, CustomFunction>;
}

async function createConfig(): Promise<CustomServerless> {
  const stage = process.env.NODE_ENV || 'dev';

  const config: CustomServerless = {
    service: 'typed-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: 'nodejs18.x',
      region: process.env.AWS_REGION || 'us-east-1',
      stage,
      environment: {
        NODE_ENV: stage,
        API_VERSION: 'v1',
        DB_HOST: process.env.DB_HOST || 'localhost',
        ENABLE_CORS: stage !== 'prod'
      }
    },

    functions: {
      api: {
        handler: 'dist/index.handler',
        memorySize: 512,
        timeout: 30,
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

  return config;
}

export default createConfig;
```

### Configuration Validation

```typescript
import { Serverless } from '@serverless/types/aws';

interface ConfigSchema {
  service: string;
  provider: {
    region: string;
    stage: string;
    runtime: string;
  };
  functions: Record<string, {
    handler: string;
    memorySize?: number;
    timeout?: number;
  }>;
}

function validateConfig(config: any): ConfigSchema {
  if (!config.service) {
    throw new Error('Service name is required');
  }

  if (!config.provider?.region) {
    throw new Error('Provider region is required');
  }

  if (!config.provider?.stage) {
    throw new Error('Provider stage is required');
  }

  const validRuntimes = ['nodejs18.x', 'python3.11', 'java17'];
  if (!validRuntimes.includes(config.provider?.runtime)) {
    throw new Error(`Invalid runtime: ${config.provider?.runtime}`);
  }

  return config as ConfigSchema;
}

export default async (): Promise<Serverless> => {
  const stage = process.env.NODE_ENV || 'dev';

  const rawConfig = {
    service: process.env.SERVICE_NAME || 'my-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: process.env.RUNTIME || 'nodejs18.x',
      region: process.env.AWS_REGION || 'us-east-1',
      stage
    },

    functions: {
      api: {
        handler: 'dist/index.handler',
        memorySize: 256,
        timeout: 30
      }
    }
  };

  const validatedConfig = validateConfig(rawConfig);

  return validatedConfig as Serverless;
};
```

## Error Handling

### Robust Error Handling

```typescript
import { Serverless } from '@serverless/types/aws';

interface ConfigError extends Error {
  configPath?: string;
  stage?: string;
}

class ConfigurationError extends Error implements ConfigError {
  constructor(message: string, public configPath?: string, public stage?: string) {
    super(message);
    this.name = 'ConfigurationError';
  }
}

async function loadConfigWithFallbacks(): Promise<Serverless> {
  const stage = process.env.NODE_ENV || 'dev';

  try {
    // Try to load from remote config first
    const remoteConfig = await loadRemoteConfig();
    return mergeConfigs(remoteConfig, getDefaultConfig(stage));
  } catch (error) {
    console.warn('Failed to load remote config, using defaults:', error);

    try {
      // Try to load from local file
      const localConfig = await loadLocalConfig();
      return mergeConfigs(localConfig, getDefaultConfig(stage));
    } catch (error) {
      console.warn('Failed to load local config, using defaults:', error);

      // Fall back to default configuration
      return getDefaultConfig(stage);
    }
  }
}

async function loadRemoteConfig(): Promise<Partial<Serverless>> {
  const configUrl = process.env.REMOTE_CONFIG_URL;

  if (!configUrl) {
    throw new ConfigurationError('REMOTE_CONFIG_URL not set');
  }

  try {
    const response = await fetch(configUrl, {
      timeout: 5000, // 5 second timeout
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return await response.json();
  } catch (error) {
    throw new ConfigurationError(
      `Failed to load remote config: ${error.message}`,
      configUrl,
      process.env.NODE_ENV
    );
  }
}

function getDefaultConfig(stage: string): Serverless {
  return {
    service: 'fallback-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: 'nodejs18.x',
      region: 'us-east-1',
      stage,
      environment: {
        NODE_ENV: stage,
        CONFIG_SOURCE: 'fallback'
      }
    },

    functions: {
      health: {
        handler: 'dist/health.handler',
        events: [
          {
            http: {
              path: '/health',
              method: 'get',
              cors: true
            }
          }
        ]
      }
    }
  };
}

export default loadConfigWithFallbacks;
```

## Performance Optimization

### Caching and Memoization

```typescript
import { Serverless } from '@serverless/types/aws';

interface CachedConfig {
  config: Partial<Serverless>;
  timestamp: number;
  ttl: number;
}

const configCache = new Map<string, CachedConfig>();

async function loadConfigWithCache(stage: string): Promise<Partial<Serverless>> {
  const cacheKey = `config-${stage}`;
  const now = Date.now();
  const cached = configCache.get(cacheKey);

  // Return cached config if still valid
  if (cached && (now - cached.timestamp) < cached.ttl) {
    console.log(`Using cached config for stage: ${stage}`);
    return cached.config;
  }

  console.log(`Loading fresh config for stage: ${stage}`);

  try {
    const config = await loadConfigFromSource(stage);

    // Cache for 5 minutes
    configCache.set(cacheKey, {
      config,
      timestamp: now,
      ttl: 5 * 60 * 1000 // 5 minutes
    });

    return config;
  } catch (error) {
    // If we have a stale cache, use it as fallback
    if (cached) {
      console.warn('Using stale cache due to error:', error.message);
      return cached.config;
    }

    throw error;
  }
}

async function loadConfigFromSource(stage: string): Promise<Partial<Serverless>> {
  const configUrl = `${process.env.CONFIG_API_URL}/config/${stage}`;

  const response = await fetch(configUrl, {
    headers: {
      'Authorization': `Bearer ${process.env.CONFIG_API_TOKEN}`
    }
  });

  if (!response.ok) {
    throw new Error(`Failed to load config: ${response.statusText}`);
  }

  return await response.json();
}

export default async (): Promise<Serverless> => {
  const stage = process.env.NODE_ENV || 'dev';
  const dynamicConfig = await loadConfigWithCache(stage);

  return {
    service: 'cached-config-service',
    frameworkVersion: '3',

    provider: {
      name: 'aws',
      runtime: 'nodejs18.x',
      region: 'us-east-1',
      stage
    },

    ...dynamicConfig
  };
};
```

## Best Practices

### Configuration Organization

1. **Separate Configuration Logic**: Keep configuration loading separate from service definition
2. **Use Environment Variables**: Store environment-specific values in environment variables
3. **Provide Fallbacks**: Always have sensible defaults when external config fails
4. **Validate Inputs**: Validate configuration before using it
5. **Document Configuration**: Document all configuration options and their sources

### Performance Considerations

1. **Avoid Blocking Calls**: Use `Promise.all()` for parallel async operations
2. **Implement Caching**: Cache external configuration calls
3. **Set Timeouts**: Set reasonable timeouts for external API calls
4. **Error Handling**: Handle errors gracefully with fallbacks

### Security

1. **Never Log Secrets**: Avoid logging sensitive configuration values
2. **Use Secure Sources**: Load secrets from AWS Secrets Manager or Parameter Store
3. **Validate Inputs**: Validate all external inputs
4. **Principle of Least Privilege**: Only request necessary permissions

## Troubleshooting

### Common Issues

**TypeScript Compilation Errors**:
```bash
# Install missing type definitions
npm install --save-dev @types/node @serverless/types
```

**Module Resolution Errors**:
```json
// tsconfig.json
{
  "compilerOptions": {
    "moduleResolution": "node",
    "esModuleInterop": true
  }
}
```

**Async Export Errors**:
```typescript
// Ensure the default export is a function that returns a Promise
export default async (): Promise<Serverless> => {
  // your async logic
};
```

**Environment Variable Access**:
```typescript
// Load environment variables if needed
import * as dotenv from 'dotenv';
dotenv.config();

const stage = process.env.NODE_ENV || 'dev';
```

## Next Steps

- 📖 [Variable Resolution](../features/variable-resolution) - Advanced variable handling
- 📚 [Examples](../examples/typescript-config) - TypeScript configuration examples
- 🔧 [Advanced Features](../advanced/custom-resources) - Custom resources and extensions

---

<div class="hero-buttons">
  <a href="../features/variable-resolution" class="btn">Next: Variable Resolution</a>
  <a href="../examples/typescript-config" class="btn secondary">TypeScript Examples</a>
</div>