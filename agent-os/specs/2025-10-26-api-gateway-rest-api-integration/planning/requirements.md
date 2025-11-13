# Spec Requirements: API Gateway REST API Integration

## Initial Description

Generate aws_api_gateway_rest_api, aws_api_gateway_resource, aws_api_gateway_method, and aws_api_gateway_integration resources from Serverless http events, including CORS configuration and deployment stage creation.

**Source:** Product Roadmap - Item #4

**Context:** This feature is the fourth item in the product roadmap and represents a critical component for enabling HTTP API endpoints in serverless applications. It builds upon the foundation established by Core Module Structure & YAML Parsing (Item 1), Lambda Function Translation (Item 2), and IAM Role & Policy Management (Item 3). This feature enables the sls.tf module to translate Serverless Framework HTTP event definitions into fully functional AWS API Gateway REST APIs with Lambda integrations.

## Requirements Discussion

### Design Goals

The primary goal of this feature is to achieve **Serverless Framework parity** for HTTP event definitions, allowing developers to define API endpoints using familiar Serverless Framework syntax while the module generates all necessary AWS API Gateway resources through Terraform. The implementation should:

1. Support both short-form and long-form HTTP event syntax from Serverless Framework
2. Generate a single shared REST API resource per service (matching Serverless Framework behavior)
3. Handle path parameter parsing and nested resource creation
4. Automatically configure CORS when specified
5. Create deployments with proper change triggers and staging
6. Grant necessary Lambda invocation permissions
7. Use AWS_PROXY integration type for seamless Lambda integration

### Serverless Framework HTTP Event Syntax

The module must support both syntax forms used in Serverless Framework:

**Short Form:**
```yaml
functions:
  getUser:
    handler: handlers/users.get
    events:
      - http: GET /users/{id}
```

**Long Form:**
```yaml
functions:
  createUser:
    handler: handlers/users.create
    events:
      - http:
          path: /users
          method: POST
          cors: true
```

**Long Form with CORS Configuration:**
```yaml
functions:
  listUsers:
    handler: handlers/users.list
    events:
      - http:
          path: /users
          method: GET
          cors:
            origin: '*'
            headers:
              - Content-Type
              - X-Amz-Date
              - Authorization
              - X-Api-Key
              - X-Amz-Security-Token
              - X-Amz-User-Agent
            allowCredentials: false
```

### AWS Resources to Generate

The module must generate the following Terraform resources from HTTP event definitions:

#### 1. REST API Resource (Singleton per Service)
```hcl
resource "aws_api_gateway_rest_api" "this" {
  name        = "${service-name}-${stage}"
  description = "API Gateway for ${service-name}"
}
```

**Requirements:**
- Create exactly ONE REST API resource per service, shared across all HTTP events
- Name format: `{service.name}-{provider.stage}`
- Use default endpoint configuration (EDGE)

#### 2. API Gateway Resources (Path Hierarchy)
```hcl
resource "aws_api_gateway_resource" "path_segment" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = # parent resource or root
  path_part   = # segment name or {parameter}
}
```

**Requirements:**
- Parse paths into segments (e.g., `/users/{id}/posts` → ["users", "{id}", "posts"])
- Create nested resources for each path segment
- Reuse existing resources when paths share common prefixes
- Preserve parameter syntax in path_part (e.g., `{id}`, `{userId}`)

#### 3. API Gateway Methods
```hcl
resource "aws_api_gateway_method" "endpoint" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.path_segment.id
  http_method   = # GET, POST, PUT, DELETE, PATCH, etc.
  authorization = "NONE"
}
```

**Requirements:**
- Create one method per HTTP event
- Set authorization to "NONE" (custom authorizers excluded from initial implementation)
- Support standard HTTP methods: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS

#### 4. API Gateway Integrations
```hcl
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.path_segment.id
  http_method             = aws_api_gateway_method.endpoint.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = # Lambda invoke ARN
}
```

**Requirements:**
- Always use `AWS_PROXY` integration type (enables Lambda proxy integration)
- Set `integration_http_method` to "POST" (required for Lambda invocations)
- Construct URI: `arn:aws:apigateway:${region}:lambda:path/2015-03-31/functions/${lambda_arn}/invocations`

#### 5. CORS Methods (OPTIONS)
```hcl
resource "aws_api_gateway_method" "cors_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.path_segment.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.path_segment.id
  http_method = aws_api_gateway_method.cors_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "cors_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.path_segment.id
  http_method = aws_api_gateway_method.cors_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "cors_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.path_segment.id
  http_method = aws_api_gateway_method.cors_options.http_method
  status_code = aws_api_gateway_method_response.cors_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = # header list
    "method.response.header.Access-Control-Allow-Methods" = # method list
    "method.response.header.Access-Control-Allow-Origin"  = # origin value
  }
}
```

**Requirements:**
- Create OPTIONS method when `cors: true` or cors object is specified
- Use MOCK integration (no backend required)
- Set response headers based on CORS configuration or defaults

#### 6. Lambda Permissions
```hcl
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke-${function_name}-${method}-${path_hash}"
  action        = "lambda:InvokeFunction"
  function_name = # Lambda function name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${region}:${account}:${api_id}/*/*"
}
```

**Requirements:**
- Create one permission per function referenced by HTTP events
- Use wildcard source ARN: `${api_id}/*/*` (all stages and methods)
- Generate unique statement_id to avoid conflicts

#### 7. API Gateway Deployment
```hcl
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      # List of method and integration IDs that trigger redeployment
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

**Requirements:**
- Create deployment that depends on all methods and integrations
- Use triggers to force redeployment when API configuration changes
- Include sha1 hash of all method/integration resource IDs in triggers
- Use create_before_destroy lifecycle to prevent downtime

#### 8. API Gateway Stage
```hcl
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = # provider.stage value
}
```

**Requirements:**
- Stage name should match `provider.stage` from serverless configuration
- Default to "dev" if stage not specified
- Stage depends on deployment resource

### Resource Mapping and Relationships

**Dependency Graph:**
```
aws_api_gateway_rest_api (singleton)
  └─> aws_api_gateway_resource (path segments, nested)
        └─> aws_api_gateway_method (HTTP methods)
              └─> aws_api_gateway_integration (Lambda proxy)
              └─> aws_api_gateway_method_response (CORS)
                    └─> aws_api_gateway_integration_response (CORS)
        └─> aws_api_gateway_method (OPTIONS for CORS)
              └─> aws_api_gateway_integration (MOCK)
                    └─> aws_api_gateway_integration_response (CORS headers)
  └─> aws_api_gateway_deployment (depends on all methods/integrations)
        └─> aws_api_gateway_stage (stage name from provider.stage)

aws_lambda_permission (per function, references API Gateway)
```

**Resource Naming Convention:**
- REST API: `aws_api_gateway_rest_api.this`
- Resources: `aws_api_gateway_resource.{sanitized_path}` (e.g., `users_id_posts`)
- Methods: `aws_api_gateway_method.{function_name}_{method}` (e.g., `get_user_get`)
- Integrations: `aws_api_gateway_integration.{function_name}_{method}`
- CORS Methods: `aws_api_gateway_method.{sanitized_path}_cors_options`
- Deployment: `aws_api_gateway_deployment.this`
- Stage: `aws_api_gateway_stage.this`
- Lambda Permission: `aws_lambda_permission.api_gateway_{function_name}`

### CORS Handling Details

**When to Enable CORS:**
1. HTTP event specifies `cors: true`
2. HTTP event specifies cors object with configuration

**CORS Default Values (Serverless Framework Parity):**
```yaml
cors:
  origin: '*'
  headers:
    - Content-Type
    - X-Amz-Date
    - Authorization
    - X-Api-Key
    - X-Amz-Security-Token
    - X-Amz-User-Agent
  allowCredentials: false
```

**CORS Implementation Requirements:**
1. Create OPTIONS method for each resource with CORS-enabled endpoints
2. Use MOCK integration (returns 200 without backend invocation)
3. Add method response with header parameters
4. Add integration response with CORS header values:
   - `Access-Control-Allow-Origin`: From cors.origin or default '*'
   - `Access-Control-Allow-Headers`: Comma-separated list from cors.headers or defaults
   - `Access-Control-Allow-Methods`: Comma-separated list of methods defined on the resource
5. Quote header values in integration response parameters (e.g., `"'*'"`)

**CORS Configuration Variations:**
```yaml
# Boolean (use all defaults)
cors: true

# Custom origin only
cors:
  origin: 'https://example.com'

# Custom headers
cors:
  headers:
    - Content-Type
    - X-Custom-Header

# Full configuration
cors:
  origin: 'https://example.com'
  headers:
    - Content-Type
    - Authorization
  allowCredentials: true
  maxAge: 86400
```

### Path Parameter Parsing Logic

**Path Parsing Algorithm:**

1. **Split path into segments:**
   ```
   /users/{id}/posts/{postId} → ["users", "{id}", "posts", "{postId}"]
   ```

2. **Create resources hierarchically:**
   ```
   Root resource (implicit, from REST API)
     └─> /users
           └─> /users/{id}
                 └─> /users/{id}/posts
                       └─> /users/{id}/posts/{postId}
   ```

3. **Handle parameter syntax:**
   - Preserve curly braces in path_part: `{id}`, `{userId}`, etc.
   - Validate parameter names (alphanumeric + underscore only)
   - Reject invalid syntax: `{id}extra`, `{id-hyphen}`, `{}`, etc.

4. **Resource reuse:**
   - Paths sharing prefixes reuse intermediate resources
   - Example: `/users/{id}` and `/users/{id}/posts` share `/users` and `/users/{id}` resources

**Validation Rules:**
- Path must start with `/`
- Path segments cannot be empty (e.g., `/users//posts` is invalid)
- Parameter names must match: `^[a-zA-Z0-9_]+$`
- Parameters must be complete segments (e.g., `/users/{id}foo` is invalid)

### Deployment and Staging Strategy

**Deployment Trigger Mechanism:**

The deployment must automatically redeploy when API configuration changes. This is achieved using Terraform triggers:

```hcl
triggers = {
  redeployment = sha1(jsonencode([
    aws_api_gateway_method.endpoint_1.id,
    aws_api_gateway_integration.endpoint_1.id,
    aws_api_gateway_method.endpoint_2.id,
    aws_api_gateway_integration.endpoint_2.id,
    # ... all methods and integrations
  ]))
}
```

**Requirements:**
- Include ALL method and integration resource IDs in triggers
- Use `sha1(jsonencode(...))` to create hash of configuration
- When any method/integration changes, hash changes, triggering redeployment
- Use `create_before_destroy = true` to prevent API downtime during redeployment

**Stage Configuration:**
- Stage name from `provider.stage` in serverless configuration
- Default to "dev" if not specified
- Stage resource depends on deployment (must be created after deployment)
- Output stage invoke URL: `https://${api_id}.execute-api.${region}.amazonaws.com/${stage_name}`

### Lambda Permission Requirements

**Permission Scope:**

Each Lambda function referenced by HTTP events needs permission for API Gateway to invoke it.

**Source ARN Pattern:**
```
arn:aws:execute-api:${region}:${account_id}:${api_id}/*/*
```

**ARN Components:**
- `${region}`: AWS region (e.g., us-east-1)
- `${account_id}`: AWS account ID
- `${api_id}`: API Gateway REST API ID
- `/*/*`: Wildcard for stage and method (allows all stages and HTTP methods)

**Requirements:**
- Create one `aws_lambda_permission` per Lambda function (not per HTTP event)
- Multiple HTTP events for same function share one permission
- Permission allows invocation from any stage or method on the API
- Statement ID must be unique and descriptive: `AllowAPIGatewayInvoke-${function_name}`

### Validation Rules

**HTTP Event Validation:**
1. **Method validation:**
   - Must be one of: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
   - Case-insensitive matching, convert to uppercase
   - Reject unknown methods

2. **Path validation:**
   - Must start with `/`
   - Cannot end with `/` (except root path `/`)
   - No empty segments (e.g., `/users//posts`)
   - No consecutive slashes
   - Path parameters must match pattern: `{[a-zA-Z0-9_]+}`
   - Path parameters must be complete segments (e.g., `/users/{id}` valid, `/users/{id}suffix` invalid)

3. **CORS validation:**
   - If boolean, must be `true` (false is treated as no CORS)
   - If object, validate structure:
     - `origin`: string (URL or '*')
     - `headers`: array of strings
     - `allowCredentials`: boolean
     - `maxAge`: number (seconds)
   - Reject unknown properties in CORS object

4. **Function reference validation:**
   - HTTP event must reference an existing function in the configuration
   - Function must have valid handler and runtime

**Serverless Configuration Validation:**
1. **Provider configuration:**
   - `provider.name` must be "aws"
   - `provider.region` should be valid AWS region (use default if not specified)
   - `provider.stage` defaults to "dev" if not specified

2. **Service naming:**
   - `service.name` is required
   - Used for API Gateway REST API name: `${service.name}-${stage}`

### Out of Scope Items

The following features are explicitly **excluded** from the initial implementation to focus on core HTTP event translation:

1. **Custom Authorizers:**
   - Lambda authorizers (TOKEN, REQUEST)
   - Cognito User Pool authorizers
   - All `http.authorizer` configurations ignored

2. **API Keys and Usage Plans:**
   - `http.private: true` configuration
   - `aws_api_gateway_api_key` resources
   - `aws_api_gateway_usage_plan` resources
   - API key required settings

3. **Request/Response Validation:**
   - Request body validation
   - Request parameter validation
   - `http.request.schemas` configuration
   - Model definitions

4. **Access Logging:**
   - CloudWatch log group integration
   - Access log format configuration
   - Execution logging

5. **Throttling and Rate Limiting:**
   - Method-level throttling
   - Stage-level throttling
   - Burst limits

6. **Custom Domain Names:**
   - ACM certificate integration
   - Base path mappings
   - Route 53 record creation

7. **Binary Media Types:**
   - `binaryMediaTypes` configuration
   - Content handling transformations

8. **Request/Response Transformations:**
   - VTL templates
   - Mapping templates
   - Non-proxy integrations

9. **WAF Integration:**
   - Web ACL associations
   - WAF rules

10. **API Gateway HTTP API (v2):**
    - Only REST API (v1) is in scope
    - HTTP API support is a separate feature

**Rationale:** These exclusions allow the initial implementation to focus on the most common use case: creating Lambda-backed REST API endpoints with CORS support. Advanced features can be added incrementally in future iterations.

### Success Criteria

The implementation will be considered successful when:

1. **Short-form HTTP events work:**
   ```yaml
   functions:
     getUser:
       handler: users.get
       events:
         - http: GET /users/{id}
   ```
   - Creates REST API, resource `/users/{id}`, GET method, Lambda integration
   - Lambda permission grants API Gateway invocation rights

2. **Long-form HTTP events work:**
   ```yaml
   functions:
     createUser:
       handler: users.create
       events:
         - http:
             path: /users
             method: POST
   ```
   - Creates REST API, resource `/users`, POST method, Lambda integration

3. **CORS configuration works:**
   ```yaml
   functions:
     listUsers:
       handler: users.list
       events:
         - http:
             path: /users
             method: GET
             cors: true
   ```
   - Creates OPTIONS method with MOCK integration
   - Returns CORS headers with default values

4. **Custom CORS configuration works:**
   ```yaml
   functions:
     listUsers:
       handler: users.list
       events:
         - http:
             path: /users
             method: GET
             cors:
               origin: 'https://example.com'
               headers:
                 - Content-Type
                 - Authorization
   ```
   - OPTIONS method returns custom CORS headers

5. **Path parameters work:**
   ```yaml
   functions:
     getPost:
       handler: posts.get
       events:
         - http: GET /users/{userId}/posts/{postId}
   ```
   - Creates nested resources: `/users` → `/users/{userId}` → `/users/{userId}/posts` → `/users/{userId}/posts/{postId}`
   - Lambda receives path parameters in event.pathParameters

6. **Resource reuse works:**
   ```yaml
   functions:
     getUser:
       handler: users.get
       events:
         - http: GET /users/{id}
     updateUser:
       handler: users.update
       events:
         - http: PUT /users/{id}
   ```
   - Single `/users/{id}` resource with both GET and PUT methods

7. **Deployment triggers work:**
   - Changing method configuration triggers redeployment
   - Changing integration configuration triggers redeployment
   - Adding/removing HTTP events triggers redeployment

8. **Stage outputs work:**
   - Module outputs API Gateway invoke URL
   - Format: `https://{api-id}.execute-api.{region}.amazonaws.com/{stage}`

9. **Multiple functions share one API:**
   ```yaml
   functions:
     getUser:
       events:
         - http: GET /users/{id}
     listUsers:
       events:
         - http: GET /users
     createUser:
       events:
         - http: POST /users
   ```
   - Single `aws_api_gateway_rest_api` resource
   - All functions integrated into same API

10. **Lambda proxy integration works:**
    - Lambda receives API Gateway event with requestContext, pathParameters, queryStringParameters, headers, body
    - Lambda response format matches AWS_PROXY requirements (statusCode, headers, body)
    - API Gateway returns Lambda response to client without modification

### Functional Requirements Summary

Based on the requirements discussion, the core functional requirements are:

1. **HTTP Event Parsing:**
   - Parse short-form HTTP event syntax: `http: METHOD /path`
   - Parse long-form HTTP event syntax with path, method, cors properties
   - Extract method, path, and CORS configuration
   - Associate HTTP events with their Lambda functions

2. **REST API Resource Generation:**
   - Create single shared `aws_api_gateway_rest_api` per service
   - Parse paths into hierarchical `aws_api_gateway_resource` tree
   - Generate `aws_api_gateway_method` for each HTTP event
   - Generate `aws_api_gateway_integration` with AWS_PROXY type
   - Create `aws_api_gateway_deployment` with change triggers
   - Create `aws_api_gateway_stage` with stage name from provider.stage

3. **CORS Support:**
   - Detect CORS enabled (boolean or object)
   - Generate OPTIONS methods for CORS-enabled resources
   - Create MOCK integration for OPTIONS methods
   - Configure CORS response headers (origin, headers, methods)
   - Support custom CORS configuration (origin, headers, allowCredentials)
   - Use Serverless Framework default CORS values when not specified

4. **Path Parameter Handling:**
   - Parse path segments including parameters (e.g., `{id}`)
   - Create nested resource hierarchy
   - Validate parameter syntax
   - Preserve parameter names in path_part

5. **Lambda Permission Management:**
   - Generate `aws_lambda_permission` for each function with HTTP events
   - Use wildcard source ARN for all stages and methods
   - Ensure unique statement IDs

6. **Configuration Validation:**
   - Validate HTTP methods
   - Validate path syntax
   - Validate CORS configuration
   - Validate function references

### Reusability Opportunities

**No existing code to reference** - this is a greenfield implementation.

However, the implementation should be designed for future reusability:

1. **Modular path parsing logic** that can be reused for HTTP API (v2) implementation
2. **CORS configuration utilities** that can be shared across API types
3. **Resource naming conventions** that can be extended to other event sources
4. **Validation patterns** that can be applied to other Serverless Framework event types

### Technical Considerations

1. **Terraform Dynamic Blocks:**
   - Use `for_each` to iterate over functions and their HTTP events
   - Use dynamic blocks for generating nested resources
   - Leverage local values for intermediate computations

2. **State Management:**
   - Ensure resource IDs are stable across applies
   - Avoid unnecessary recreation of resources
   - Use lifecycle rules (create_before_destroy) for deployments

3. **Integration with Existing Module:**
   - Builds on Lambda function resources from Item #2
   - Uses service name and stage from provider configuration (Item #1)
   - Requires Lambda ARNs and function names from lambda module outputs

4. **AWS API Gateway Constraints:**
   - REST API has default resource `/` (root)
   - Resources must form a tree (single parent)
   - Methods cannot be duplicated on same resource
   - Deployment must depend on all methods/integrations
   - Stage requires deployment to exist first

5. **Terraform Provider Version:**
   - Requires AWS provider 4.0+ for stable API Gateway resources
   - No beta or experimental features required

### Visual Assets

No visual assets provided.

### Existing Code to Reference

No similar existing features identified for reference.

## Requirements Completion

This requirements document comprehensively captures:
- Feature overview and alignment with Serverless Framework parity goals
- Complete HTTP event syntax specification (short and long form)
- Detailed AWS resource requirements for all 8 resource types
- Resource dependency graph and naming conventions
- CORS handling logic with defaults and customization
- Path parameter parsing algorithm and validation rules
- Deployment trigger strategy for automatic redeployment
- Lambda permission requirements and ARN patterns
- Comprehensive validation rules for all configurations
- Clear scope boundaries (in-scope and out-of-scope features)
- Success criteria with 10 testable scenarios
- Technical considerations for implementation

The specification is ready for detailed technical design and implementation planning.
