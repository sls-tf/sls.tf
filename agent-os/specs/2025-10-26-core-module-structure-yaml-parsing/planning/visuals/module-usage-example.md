# Module Usage Example

This diagram shows how a user would consume the sls.tf core module in their Terraform configuration.

```mermaid
graph TB
    subgraph "User's Terraform Root Module"
        UserMain[main.tf]
        UserVars[variables.tf]
        UserConf[serverless.yml]
    end

    subgraph "sls.tf Module Invocation"
        ModuleBlock["module sls {<br/>  source = ./sls.tf<br/>  config_path = ./serverless.yml<br/>  config_format = yaml<br/>  aws_region = var.aws_region<br/>}"]
    end

    subgraph "sls.tf Core Module"
        Variables[variables.tf<br/>- config_path<br/>- config_format<br/>- aws_region]
        Main[main.tf<br/>- YAML parsing<br/>- Validation logic]
        Locals[locals.tf<br/>- Default values<br/>- Transformations]
        Outputs[outputs.tf<br/>- parsed_config<br/>- service_name<br/>- provider_config<br/>- functions, etc.]
        Versions[versions.tf<br/>- Terraform version<br/>- AWS provider]
    end

    subgraph "Module Outputs Usage"
        UseLambda["resource aws_lambda_function {<br/>  for_each = module.sls.functions<br/>  ..."]
        UseAPI["resource aws_api_gateway_rest_api {<br/>  name = module.sls.service_name<br/>  ..."]
        UseRole["resource aws_iam_role {<br/>  for_each = module.sls.functions<br/>  ..."]
    end

    UserConf --> ModuleBlock
    UserMain --> ModuleBlock
    UserVars --> ModuleBlock

    ModuleBlock --> Variables
    ModuleBlock --> Main
    ModuleBlock --> Locals
    ModuleBlock --> Outputs
    ModuleBlock --> Versions

    Outputs --> UseLambda
    Outputs --> UseAPI
    Outputs --> UseRole

    style UserMain fill:#E8F4F8
    style UserVars fill:#E8F4F8
    style UserConf fill:#FFE6CC
    style ModuleBlock fill:#D4E6F1
    style Variables fill:#326CE5,color:#fff
    style Main fill:#326CE5,color:#fff
    style Locals fill:#326CE5,color:#fff
    style Outputs fill:#326CE5,color:#fff
    style Versions fill:#326CE5,color:#fff
    style UseLambda fill:#98D8C8
    style UseAPI fill:#98D8C8
    style UseRole fill:#98D8C8
```

## Example Terraform Configuration

### User's `main.tf`

```hcl
# Invoke the sls.tf module
module "serverless" {
  source = "./sls.tf"

  config_path   = "${path.module}/serverless.yml"
  config_format = "yaml"
  aws_region    = var.aws_region  # Optional override
}

# Use module outputs to create AWS resources
# (Future roadmap items will handle this internally)
output "service_name" {
  value = module.serverless.service_name
}

output "parsed_configuration" {
  value = module.serverless.parsed_config
}
```

### User's `serverless.yml`

```yaml
service: my-serverless-app

provider:
  name: aws
  runtime: nodejs20.x
  stage: dev
  region: us-east-1
  memorySize: 1024
  timeout: 30

functions:
  hello:
    handler: handler.hello
    events:
      - http:
          path: hello
          method: get

  world:
    handler: handler.world
    memorySize: 512
    events:
      - http:
          path: world
          method: post

custom:
  myCustomValue: example

resources:
  Resources:
    MyBucket:
      Type: AWS::S3::Bucket
      Properties:
        BucketName: my-serverless-bucket
```

### Module Output Structure

```hcl
# module.serverless.service_name
"my-serverless-app"

# module.serverless.provider_config
{
  name       = "aws"
  runtime    = "nodejs20.x"
  stage      = "dev"
  region     = "us-east-1"
  memorySize = 1024
  timeout    = 30
}

# module.serverless.functions
{
  hello = {
    handler = "handler.hello"
    events = [
      {
        http = {
          path   = "hello"
          method = "get"
        }
      }
    ]
  }
  world = {
    handler    = "handler.world"
    memorySize = 512
    events = [
      {
        http = {
          path   = "world"
          method = "post"
        }
      }
    ]
  }
}
```

## Functionless Configuration Example

```yaml
# Valid serverless.yml without functions
service: infrastructure-only

provider:
  name: aws
  runtime: nodejs20.x
  region: us-east-1

resources:
  Resources:
    MyQueue:
      Type: AWS::SQS::Queue
      Properties:
        QueueName: my-queue

    MyTopic:
      Type: AWS::SNS::Topic
      Properties:
        TopicName: my-topic
```

This configuration is valid and demonstrates infrastructure-only deployments.
