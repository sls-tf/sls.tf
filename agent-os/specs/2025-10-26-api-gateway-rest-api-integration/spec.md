# Specification: API Gateway REST API Integration

## 1. Overview

### Feature Description
This feature enables the sls.tf Terraform module to translate Serverless Framework HTTP event definitions into fully functional AWS API Gateway REST APIs with Lambda proxy integrations. It generates all necessary AWS resources including REST API, resources, methods, integrations, CORS handling, deployments, stages, and Lambda permissions.

### Goals
- Achieve complete Serverless Framework parity for HTTP event syntax (short-form and long-form)
- Generate production-ready API Gateway REST APIs with proper configuration
- Support CORS with default and custom configurations matching Serverless Framework behavior
- Handle path parameters and nested resource hierarchies correctly
- Enable automatic redeployment when API configuration changes
- Maintain the established module patterns for validation, error handling, and resource naming

### Context
This is the fourth roadmap item building upon:
- **Spec 1**: Core Module Structure & YAML Parsing (parsing infrastructure, validation patterns)
- **Spec 2**: Lambda Function Translation (function resource creation)
- **Spec 3**: IAM Role & Policy Management (permission patterns)

This feature integrates with existing Lambda function resources and uses the established configuration parsing and validation infrastructure.

## 2. Requirements Summary

### Functional Requirements

**HTTP Event Parsing:**
- Parse short-form syntax: `http: GET /users/{id}`
- Parse long-form syntax with path, method, cors properties
- Extract method, path, and CORS configuration
- Associate events with Lambda functions
- Support all standard HTTP methods: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS

**Resource Generation:**
- Create single shared `aws_api_gateway_rest_api` per service
- Parse paths into hierarchical resource trees
- Reuse resources when paths share common prefixes
- Generate methods with AWS_PROXY Lambda integrations
- Create deployments with automatic change triggers
- Create stages with provider.stage name

**CORS Handling:**
- Detect CORS enabled (boolean true or configuration object)
- Generate OPTIONS methods with MOCK integrations
- Configure response headers (origin, headers, methods)
- Support custom CORS configuration
- Apply Serverless Framework default CORS values

**Lambda Permissions:**
- Grant API Gateway invoke permissions per function
- Use wildcard source ARN for all stages and methods
- Ensure unique statement IDs

### Technical Requirements

**Validation:**
- Validate HTTP methods against allowed list
- Validate path syntax (must start with `/`, no empty segments, proper parameter syntax)
- Validate CORS configuration structure
- Validate function references exist
- Collect and display all validation errors at once

**Resource Naming:**
- Follow established module conventions
- Use sanitized path names for resource identifiers
- Generate unique, descriptive resource names
- Ensure Terraform resource stability across applies

**Integration:**
- Build upon local.functions_with_defaults from Spec 1
- Reference Lambda ARNs from Spec 2
- Use validation error collection pattern from Spec 1
- Follow Terraform dynamic block patterns from existing codebase

## 3. Architecture

### System Design

```
Serverless YAML Config
        |
        v
[HTTP Event Parser]
    - Extract http events from functions
    - Parse short/long form syntax
    - Build event-to-function mapping
        |
        v
[Path Parser & Resource Builder]
    - Parse paths into segments
    - Build hierarchical resource tree
    - Identify shared prefixes
    - Handle path parameters
        |
        v
[CORS Configuration Builder]
    - Detect CORS enablement
    - Apply defaults or custom config
    - Identify resources needing OPTIONS
        |
        v
[Resource Generator]
    - REST API (singleton)
    - API Gateway Resources (nested)
    - Methods (per endpoint)
    - Integrations (Lambda proxy)
    - CORS Methods & Integrations (MOCK)
    - Deployment (with triggers)
    - Stage (with stage name)
    - Lambda Permissions
        |
        v
[Output Configuration]
    - API Gateway invoke URL
    - REST API ID
    - Resource mappings
```

### Component Relationships

**Input Dependencies:**
- `local.parsed_config` (from Spec 1)
- `local.functions_with_defaults` (from Spec 1)
- `local.provider_with_defaults` (from Spec 1)
- Lambda function ARNs (from Spec 2)
- Lambda function names (from Spec 2)

**Output Artifacts:**
- `aws_api_gateway_rest_api.this` (singleton)
- `aws_api_gateway_resource.*` (multiple, nested)
- `aws_api_gateway_method.*` (per HTTP event + CORS)
- `aws_api_gateway_integration.*` (per method)
- `aws_api_gateway_method_response.*` (for CORS)
- `aws_api_gateway_integration_response.*` (for CORS)
- `aws_api_gateway_deployment.this` (singleton)
- `aws_api_gateway_stage.this` (singleton)
- `aws_lambda_permission.api_gateway_*` (per function)

**Resource Dependency Graph:**
```
aws_api_gateway_rest_api.this
  |
  +-> aws_api_gateway_resource.* (nested hierarchy)
        |
        +-> aws_api_gateway_method.* (HTTP + OPTIONS)
              |
              +-> aws_api_gateway_integration.* (Lambda proxy or MOCK)
              |
              +-> aws_api_gateway_method_response.* (CORS only)
                    |
                    +-> aws_api_gateway_integration_response.* (CORS only)
  |
  +-> aws_api_gateway_deployment.this
        |
        +-> aws_api_gateway_stage.this

aws_lambda_function.* (from Spec 2)
  |
  +-> aws_lambda_permission.api_gateway_*
```

### Data Flow

1. **Parsing Phase:** Extract HTTP events from `local.functions_with_defaults`
2. **Path Analysis Phase:** Parse paths into segments, build resource tree structure
3. **CORS Analysis Phase:** Identify CORS requirements, build configuration
4. **Resource Creation Phase:** Generate all API Gateway resources
5. **Deployment Phase:** Create deployment with triggers, create stage
6. **Permission Phase:** Grant Lambda invocation permissions
7. **Output Phase:** Export API Gateway URLs and resource IDs

## 4. Technical Design

### 4.1 HTTP Event Parsing

**Locals for Event Extraction:**

```hcl
locals {
  # Extract all HTTP events from all functions
  # Structure: [{ function_name, handler, runtime, http_config }]
  http_events = flatten([
    for func_name, func in local.functions_with_defaults : [
      for event in try(func.events, []) : {
        function_name = func_name
        function_arn  = aws_lambda_function.functions[func_name].arn
        handler       = func.handler
        runtime       = func.runtime

        # Parse short-form: "http: GET /users/{id}"
        # Parse long-form: "http: { path: /users, method: GET, cors: true }"
        http_method = can(event.http) && can(regex("^[A-Z]+ ", event.http)) ?
                      upper(split(" ", event.http)[0]) :
                      upper(try(event.http.method, ""))

        http_path = can(event.http) && can(regex("^[A-Z]+ ", event.http)) ?
                    trimsuffix(trimspace(substr(event.http, length(split(" ", event.http)[0]) + 1, -1)), "/") :
                    trimsuffix(try(event.http.path, ""), "/")

        cors_enabled = can(event.http.cors) ? (
          can(tobool(event.http.cors)) ? tobool(event.http.cors) : true
        ) : false

        cors_config = can(event.http.cors) && !can(tobool(event.http.cors)) ?
                      event.http.cors : null
      }
      if can(event.http)
    ]
  ])

  # Deduplicate functions with HTTP events for permissions
  functions_with_http_events = toset([
    for event in local.http_events : event.function_name
  ])
}
```

**Validation for HTTP Events:**

```hcl
locals {
  http_event_validation_errors = flatten([
    for event in local.http_events : concat(
      # Validate HTTP method
      !contains(["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"], event.http_method) ?
      ["Function '${event.function_name}' has invalid HTTP method '${event.http_method}'. Must be one of: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS."] : [],

      # Validate path starts with /
      !can(regex("^/", event.http_path)) ?
      ["Function '${event.function_name}' has invalid HTTP path '${event.http_path}'. Path must start with '/'."] : [],

      # Validate no empty segments
      can(regex("//", event.http_path)) ?
      ["Function '${event.function_name}' has invalid HTTP path '${event.http_path}'. Path cannot contain empty segments (consecutive slashes)."] : [],

      # Validate path parameters
      can(regex("\\{[^a-zA-Z0-9_]", event.http_path)) || can(regex("\\{\\}", event.http_path)) ?
      ["Function '${event.function_name}' has invalid path parameter syntax in '${event.http_path}'. Parameters must be {paramName} with alphanumeric/underscore characters only."] : [],

      # Validate CORS config structure if object
      event.cors_config != null && !can(event.cors_config.origin) && !can(event.cors_config.headers) && !can(event.cors_config.allowCredentials) ?
      ["Function '${event.function_name}' has invalid CORS configuration. Must specify at least one of: origin, headers, allowCredentials."] : []
    )
  ])
}
```

### 4.2 Path Parsing and Resource Tree Building

**Path Segment Parser:**

```hcl
locals {
  # Parse all unique paths into segments
  # Example: /users/{id}/posts -> ["users", "{id}", "posts"]
  all_paths = toset([for event in local.http_events : event.http_path])

  path_segments = {
    for path in local.all_paths : path => [
      for segment in split("/", trimprefix(path, "/")) : segment
      if segment != ""
    ]
  }

  # Build complete resource tree with all intermediate paths
  # Example: /users/{id}/posts requires /users, /users/{id}, /users/{id}/posts
  all_resource_paths = toset(flatten([
    for path in local.all_paths : [
      for i in range(1, length(local.path_segments[path]) + 1) :
        "/${join("/", slice(local.path_segments[path], 0, i))}"
    ]
  ]))

  # Map each resource path to its segments and parent
  resource_tree = {
    for resource_path in local.all_resource_paths : resource_path => {
      segments    = local.path_segments[resource_path]
      depth       = length(local.path_segments[resource_path])
      path_part   = local.path_segments[resource_path][length(local.path_segments[resource_path]) - 1]
      parent_path = length(local.path_segments[resource_path]) > 1 ?
                    "/${join("/", slice(local.path_segments[resource_path], 0, length(local.path_segments[resource_path]) - 1))}" :
                    "/"
      # Sanitized name for Terraform resource identifier
      resource_name = replace(replace(resource_path, "/", "_"), "{", "").replace("}", "")
    }
  }
}
```

### 4.3 CORS Configuration

**CORS Defaults and Merging:**

```hcl
locals {
  # Serverless Framework default CORS configuration
  cors_defaults = {
    origin           = "'*'"
    headers          = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token", "X-Amz-User-Agent"]
    allowCredentials = false
  }

  # Build CORS configuration per resource path
  resource_cors_config = {
    for resource_path in local.all_resource_paths : resource_path => {
      enabled = anytrue([
        for event in local.http_events :
        event.http_path == resource_path && event.cors_enabled
      ])

      # Merge custom CORS configs from all events on this resource
      custom_config = merge(
        local.cors_defaults,
        flatten([
          for event in local.http_events :
          event.http_path == resource_path && event.cors_config != null ?
          [event.cors_config] : []
        ])...
      )

      # Methods that exist on this resource (for Access-Control-Allow-Methods)
      methods = distinct([
        for event in local.http_events :
        event.http_method
        if event.http_path == resource_path
      ])
    }
  }

  # Format CORS headers for integration response
  cors_headers = {
    for resource_path, cors in local.resource_cors_config : resource_path => {
      origin  = "'${cors.custom_config.origin}'"
      headers = "'${join(",", cors.custom_config.headers)}'"
      methods = "'${join(",", concat(cors.methods, ["OPTIONS"]))}'"
    }
    if cors.enabled
  }
}
```

### 4.4 AWS Resource Generation

**REST API (Singleton):**

```hcl
resource "aws_api_gateway_rest_api" "this" {
  count = length(local.http_events) > 0 ? 1 : 0

  name        = "${local.parsed_config.service}-${local.provider_with_defaults.stage}"
  description = "API Gateway for ${local.parsed_config.service}"

  endpoint_configuration {
    types = ["EDGE"]
  }
}
```

**API Gateway Resources (Nested Hierarchy):**

```hcl
resource "aws_api_gateway_resource" "paths" {
  for_each = length(local.http_events) > 0 ? local.resource_tree : {}

  rest_api_id = aws_api_gateway_rest_api.this[0].id

  # Parent is either root resource or another created resource
  parent_id = each.value.parent_path == "/" ?
              aws_api_gateway_rest_api.this[0].root_resource_id :
              aws_api_gateway_resource.paths[each.value.parent_path].id

  path_part = each.value.path_part
}
```

**API Gateway Methods (HTTP):**

```hcl
resource "aws_api_gateway_method" "endpoints" {
  for_each = length(local.http_events) > 0 ? {
    for event in local.http_events :
    "${event.function_name}_${lower(event.http_method)}" => event
  } : {}

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  resource_id   = aws_api_gateway_resource.paths[each.value.http_path].id
  http_method   = each.value.http_method
  authorization = "NONE"
}
```

**API Gateway Integrations (Lambda Proxy):**

```hcl
resource "aws_api_gateway_integration" "lambda" {
  for_each = length(local.http_events) > 0 ? {
    for event in local.http_events :
    "${event.function_name}_${lower(event.http_method)}" => event
  } : {}

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.paths[each.value.http_path].id
  http_method             = aws_api_gateway_method.endpoints[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${local.provider_with_defaults.region}:lambda:path/2015-03-31/functions/${each.value.function_arn}/invocations"
}
```

**CORS Methods (OPTIONS):**

```hcl
resource "aws_api_gateway_method" "cors_options" {
  for_each = {
    for path, cors in local.resource_cors_config : path => cors
    if cors.enabled
  }

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  resource_id   = aws_api_gateway_resource.paths[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}
```

**CORS Integrations (MOCK):**

```hcl
resource "aws_api_gateway_integration" "cors_options" {
  for_each = {
    for path, cors in local.resource_cors_config : path => cors
    if cors.enabled
  }

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  resource_id = aws_api_gateway_resource.paths[each.key].id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}
```

**CORS Method Responses:**

```hcl
resource "aws_api_gateway_method_response" "cors_options_200" {
  for_each = {
    for path, cors in local.resource_cors_config : path => cors
    if cors.enabled
  }

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  resource_id = aws_api_gateway_resource.paths[each.key].id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}
```

**CORS Integration Responses:**

```hcl
resource "aws_api_gateway_integration_response" "cors_options_200" {
  for_each = {
    for path, cors in local.resource_cors_config : path => cors
    if cors.enabled
  }

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  resource_id = aws_api_gateway_resource.paths[each.key].id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  status_code = aws_api_gateway_method_response.cors_options_200[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers[each.key].headers
    "method.response.header.Access-Control-Allow-Methods" = local.cors_headers[each.key].methods
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers[each.key].origin
  }
}
```

**Deployment with Triggers:**

```hcl
resource "aws_api_gateway_deployment" "this" {
  count = length(local.http_events) > 0 ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id

  # Trigger redeployment when any method or integration changes
  triggers = {
    redeployment = sha1(jsonencode([
      for k, v in aws_api_gateway_method.endpoints : v.id,
      for k, v in aws_api_gateway_integration.lambda : v.id,
      for k, v in aws_api_gateway_method.cors_options : v.id,
      for k, v in aws_api_gateway_integration.cors_options : v.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.endpoints,
    aws_api_gateway_integration.lambda,
    aws_api_gateway_method.cors_options,
    aws_api_gateway_integration.cors_options,
    aws_api_gateway_integration_response.cors_options_200
  ]
}
```

**Stage:**

```hcl
resource "aws_api_gateway_stage" "this" {
  count = length(local.http_events) > 0 ? 1 : 0

  deployment_id = aws_api_gateway_deployment.this[0].id
  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  stage_name    = local.provider_with_defaults.stage
}
```

**Lambda Permissions:**

```hcl
resource "aws_lambda_permission" "api_gateway" {
  for_each = local.functions_with_http_events

  statement_id  = "AllowAPIGatewayInvoke-${each.value}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.value].function_name
  principal     = "apigateway.amazonaws.com"

  # Allow invocation from any stage/method on this API
  source_arn = "${aws_api_gateway_rest_api.this[0].execution_arn}/*/*"
}
```

### 4.5 Output Configuration

```hcl
output "api_gateway_rest_api_id" {
  description = "ID of the API Gateway REST API"
  value       = length(local.http_events) > 0 ? aws_api_gateway_rest_api.this[0].id : null
}

output "api_gateway_invoke_url" {
  description = "Invoke URL for the API Gateway stage"
  value       = length(local.http_events) > 0 ? aws_api_gateway_stage.this[0].invoke_url : null
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = length(local.http_events) > 0 ? aws_api_gateway_stage.this[0].stage_name : null
}

output "api_gateway_resources" {
  description = "Map of API Gateway resource paths to resource IDs"
  value = length(local.http_events) > 0 ? {
    for path, resource in aws_api_gateway_resource.paths : path => resource.id
  } : {}
}
```

## 5. Data Structures

### Input Schema (from serverless.yml)

**Short-Form HTTP Event:**
```yaml
functions:
  getUser:
    handler: users.get
    events:
      - http: GET /users/{id}
```

**Long-Form HTTP Event:**
```yaml
functions:
  createUser:
    handler: users.create
    events:
      - http:
          path: /users
          method: POST
          cors: true
```

**Long-Form with Custom CORS:**
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
            allowCredentials: false
```

### Intermediate Data Structures

**http_events local:**
```hcl
[
  {
    function_name = "getUser"
    function_arn  = "arn:aws:lambda:us-east-1:123456789012:function:my-service-dev-getUser"
    handler       = "users.get"
    runtime       = "nodejs18.x"
    http_method   = "GET"
    http_path     = "/users/{id}"
    cors_enabled  = false
    cors_config   = null
  },
  {
    function_name = "createUser"
    function_arn  = "arn:aws:lambda:us-east-1:123456789012:function:my-service-dev-createUser"
    handler       = "users.create"
    runtime       = "nodejs18.x"
    http_method   = "POST"
    http_path     = "/users"
    cors_enabled  = true
    cors_config   = null  # Uses defaults
  }
]
```

**resource_tree local:**
```hcl
{
  "/users" = {
    segments      = ["users"]
    depth         = 1
    path_part     = "users"
    parent_path   = "/"
    resource_name = "_users"
  }
  "/users/{id}" = {
    segments      = ["users", "{id}"]
    depth         = 2
    path_part     = "{id}"
    parent_path   = "/users"
    resource_name = "_users_id"
  }
}
```

**resource_cors_config local:**
```hcl
{
  "/users" = {
    enabled = true
    custom_config = {
      origin           = "'*'"
      headers          = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key", "X-Amz-Security-Token", "X-Amz-User-Agent"]
      allowCredentials = false
    }
    methods = ["POST", "GET"]
  }
  "/users/{id}" = {
    enabled = false
    custom_config = {}
    methods = ["GET"]
  }
}
```

### Terraform Resource Outputs

**Generated Resources Example:**
```
aws_api_gateway_rest_api.this[0]
aws_api_gateway_resource.paths["/users"]
aws_api_gateway_resource.paths["/users/{id}"]
aws_api_gateway_method.endpoints["getUser_get"]
aws_api_gateway_method.endpoints["createUser_post"]
aws_api_gateway_integration.lambda["getUser_get"]
aws_api_gateway_integration.lambda["createUser_post"]
aws_api_gateway_method.cors_options["/users"]
aws_api_gateway_integration.cors_options["/users"]
aws_api_gateway_method_response.cors_options_200["/users"]
aws_api_gateway_integration_response.cors_options_200["/users"]
aws_api_gateway_deployment.this[0]
aws_api_gateway_stage.this[0]
aws_lambda_permission.api_gateway["getUser"]
aws_lambda_permission.api_gateway["createUser"]
```

## 6. Edge Cases

### 6.1 Error Handling

**Invalid HTTP Method:**
```yaml
functions:
  test:
    events:
      - http: INVALID /path
```
**Error:** "Function 'test' has invalid HTTP method 'INVALID'. Must be one of: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS."

**Invalid Path Syntax:**
```yaml
functions:
  test:
    events:
      - http: GET users  # Missing leading /
```
**Error:** "Function 'test' has invalid HTTP path 'users'. Path must start with '/'."

**Empty Path Segments:**
```yaml
functions:
  test:
    events:
      - http: GET /users//posts
```
**Error:** "Function 'test' has invalid HTTP path '/users//posts'. Path cannot contain empty segments (consecutive slashes)."

**Invalid Path Parameter:**
```yaml
functions:
  test:
    events:
      - http: GET /users/{id-invalid}
```
**Error:** "Function 'test' has invalid path parameter syntax in '/users/{id-invalid}'. Parameters must be {paramName} with alphanumeric/underscore characters only."

**Empty Path Parameter:**
```yaml
functions:
  test:
    events:
      - http: GET /users/{}
```
**Error:** "Function 'test' has invalid path parameter syntax in '/users/{}'. Parameters must be {paramName} with alphanumeric/underscore characters only."

**Incomplete Parameter:**
```yaml
functions:
  test:
    events:
      - http: GET /users/{id}suffix
```
**Error:** "Function 'test' has invalid path parameter syntax in '/users/{id}suffix'. Parameters must be complete segments."

### 6.2 Validation Rules

**Multiple Validation Errors:**
Collect and display all errors at once using the established pattern from Spec 1:
```hcl
validation_errors = concat(
  local.http_event_validation_errors,
  # ... other validation errors
)
```

**CORS Configuration Validation:**
- Boolean `cors: false` is treated as no CORS (don't create OPTIONS)
- Boolean `cors: true` uses default values
- Object CORS config must have at least one property (origin, headers, or allowCredentials)
- Unknown CORS properties are ignored (permissive approach)

### 6.3 Boundary Conditions

**No HTTP Events:**
- Don't create any API Gateway resources
- Output null values for API Gateway outputs
- Use conditional creation with `count` parameter

**Functionless Configuration:**
- Configuration without functions section is valid (from Spec 1)
- No HTTP events to process
- No API Gateway resources created

**Single Function with Multiple HTTP Events:**
```yaml
functions:
  api:
    events:
      - http: GET /users
      - http: POST /users
      - http: GET /users/{id}
```
- Create all resources correctly
- Single Lambda permission for the function
- Multiple methods on shared resources

**Duplicate Method on Same Resource:**
```yaml
functions:
  getUser1:
    events:
      - http: GET /users
  getUser2:
    events:
      - http: GET /users
```
- Terraform error: Cannot create duplicate method
- Should validate and error early (add validation check)

**Root Path:**
```yaml
functions:
  root:
    events:
      - http: GET /
```
- Use REST API root_resource_id (don't create resource for "/")
- Method attached directly to root

**Deep Nesting:**
```yaml
functions:
  deep:
    events:
      - http: GET /a/b/c/d/e/f/g
```
- Create all intermediate resources
- Validate depth doesn't exceed API Gateway limits (typically fine for reasonable depths)

**CORS on Multiple Methods:**
```yaml
functions:
  getUsers:
    events:
      - http:
          path: /users
          method: GET
          cors: true
  createUser:
    events:
      - http:
          path: /users
          method: POST
          cors: true
```
- Single OPTIONS method on /users
- Access-Control-Allow-Methods includes both GET and POST

**Conflicting CORS Configurations:**
```yaml
functions:
  getUsers:
    events:
      - http:
          path: /users
          method: GET
          cors:
            origin: 'https://example.com'
  createUser:
    events:
      - http:
          path: /users
          method: POST
          cors:
            origin: 'https://different.com'
```
- Last-wins merge behavior (Terraform merge semantics)
- Document limitation: Use consistent CORS config per resource path
- Consider validation error for conflicting configs

## 7. Testing Strategy

### 7.1 Unit Tests (Terraform Tests)

Create `tests/api_gateway_parsing.tftest.hcl`:

**Test 1: Short-form HTTP event parsing**
```hcl
run "short_form_http_event" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-short-form.yml"
  }

  assert {
    condition     = length(local.http_events) == 1
    error_message = "Should parse one HTTP event"
  }

  assert {
    condition     = local.http_events[0].http_method == "GET"
    error_message = "Should extract GET method"
  }

  assert {
    condition     = local.http_events[0].http_path == "/users/{id}"
    error_message = "Should extract path correctly"
  }
}
```

**Test 2: Long-form HTTP event parsing**
```hcl
run "long_form_http_event" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-long-form.yml"
  }

  assert {
    condition     = local.http_events[0].cors_enabled == true
    error_message = "Should detect CORS enabled"
  }
}
```

**Test 3: Path parameter parsing**
```hcl
run "path_parameter_parsing" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-path-params.yml"
  }

  assert {
    condition     = contains(local.all_resource_paths, "/users")
    error_message = "Should create /users resource"
  }

  assert {
    condition     = contains(local.all_resource_paths, "/users/{id}")
    error_message = "Should create /users/{id} resource"
  }

  assert {
    condition     = local.resource_tree["/users/{id}"].parent_path == "/users"
    error_message = "Should set correct parent relationship"
  }
}
```

**Test 4: CORS default configuration**
```hcl
run "cors_defaults" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-cors-default.yml"
  }

  assert {
    condition     = local.resource_cors_config["/users"].custom_config.origin == "'*'"
    error_message = "Should apply default CORS origin"
  }

  assert {
    condition     = length(local.resource_cors_config["/users"].custom_config.headers) == 6
    error_message = "Should apply default CORS headers"
  }
}
```

**Test 5: Custom CORS configuration**
```hcl
run "cors_custom" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-cors-custom.yml"
  }

  assert {
    condition     = local.resource_cors_config["/users"].custom_config.origin == "'https://example.com'"
    error_message = "Should apply custom CORS origin"
  }
}
```

**Test 6: HTTP event validation errors**
```hcl
run "invalid_http_method" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-invalid-method.yml"
  }

  expect_failures = [
    null_resource.config_validation
  ]
}

run "invalid_http_path" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-invalid-path.yml"
  }

  expect_failures = [
    null_resource.config_validation
  ]
}
```

**Test 7: Resource deduplication**
```hcl
run "resource_reuse" {
  command = plan

  variables {
    config_path = "tests/fixtures/http-shared-paths.yml"
  }

  # Two endpoints: GET /users/{id}, PUT /users/{id}
  assert {
    condition     = length(local.all_resource_paths) == 2  # /users and /users/{id}
    error_message = "Should reuse resources for shared paths"
  }

  assert {
    condition     = length(local.http_events) == 2
    error_message = "Should have two HTTP events"
  }
}
```

**Test 8: No HTTP events**
```hcl
run "no_http_events" {
  command = plan

  variables {
    config_path = "tests/fixtures/no-http-events.yml"
  }

  assert {
    condition     = length(local.http_events) == 0
    error_message = "Should have no HTTP events"
  }

  # API Gateway resources should not be created
}
```

### 7.2 Integration Tests

Create `tests/api_gateway_integration.tftest.hcl`:

**Test 1: Full API Gateway deployment**
```hcl
run "full_deployment" {
  command = apply

  variables {
    config_path = "tests/fixtures/http-full-example.yml"
  }

  assert {
    condition     = aws_api_gateway_rest_api.this[0].name == "test-service-dev"
    error_message = "Should create REST API with correct name"
  }

  assert {
    condition     = length(aws_api_gateway_resource.paths) > 0
    error_message = "Should create API Gateway resources"
  }

  assert {
    condition     = length(aws_api_gateway_method.endpoints) > 0
    error_message = "Should create API Gateway methods"
  }

  assert {
    condition     = output.api_gateway_invoke_url != null
    error_message = "Should output invoke URL"
  }
}
```

**Test 2: Deployment triggers**
```hcl
run "deployment_triggers" {
  command = apply

  variables {
    config_path = "tests/fixtures/http-basic.yml"
  }

  # Capture initial deployment ID
}

run "deployment_triggers_change" {
  command = apply

  variables {
    config_path = "tests/fixtures/http-basic-modified.yml"
  }

  # Verify deployment ID changed (redeployment triggered)
  assert {
    condition     = aws_api_gateway_deployment.this[0].id != run.deployment_triggers.aws_api_gateway_deployment.this[0].id
    error_message = "Should create new deployment when configuration changes"
  }
}
```

**Test 3: Lambda permissions created**
```hcl
run "lambda_permissions" {
  command = apply

  variables {
    config_path = "tests/fixtures/http-multiple-functions.yml"
  }

  assert {
    condition     = length(aws_lambda_permission.api_gateway) == 2
    error_message = "Should create Lambda permissions for both functions"
  }
}
```

### 7.3 Test Fixtures Required

**tests/fixtures/http-short-form.yml:**
```yaml
service: test-service
provider:
  name: aws
  runtime: nodejs18.x
functions:
  getUser:
    handler: users.get
    events:
      - http: GET /users/{id}
```

**tests/fixtures/http-long-form.yml:**
```yaml
service: test-service
provider:
  name: aws
  runtime: nodejs18.x
functions:
  createUser:
    handler: users.create
    events:
      - http:
          path: /users
          method: POST
          cors: true
```

**tests/fixtures/http-path-params.yml:**
```yaml
service: test-service
provider:
  name: aws
  runtime: nodejs18.x
functions:
  getPost:
    handler: posts.get
    events:
      - http: GET /users/{userId}/posts/{postId}
```

**tests/fixtures/http-cors-custom.yml:**
```yaml
service: test-service
provider:
  name: aws
  runtime: nodejs18.x
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

**tests/fixtures/http-invalid-method.yml:**
```yaml
service: test-service
provider:
  name: aws
  runtime: nodejs18.x
functions:
  test:
    handler: test.handler
    events:
      - http: INVALID /path
```

**tests/fixtures/http-invalid-path.yml:**
```yaml
service: test-service
provider:
  name: aws
  runtime: nodejs18.x
functions:
  test:
    handler: test.handler
    events:
      - http: GET users  # Missing /
```

**tests/fixtures/http-shared-paths.yml:**
```yaml
service: test-service
provider:
  name: aws
  runtime: nodejs18.x
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

## 8. Success Criteria

The implementation is successful when:

1. **Short-form parsing works:** Parse `http: GET /users/{id}` correctly
2. **Long-form parsing works:** Parse `http: { path: /users, method: POST }` correctly
3. **Path parameters work:** Create nested resources for `/users/{userId}/posts/{postId}`
4. **Resource reuse works:** Share `/users/{id}` resource between GET and PUT methods
5. **CORS defaults work:** `cors: true` generates OPTIONS with default headers
6. **Custom CORS works:** Custom origin, headers, allowCredentials applied correctly
7. **Lambda integration works:** AWS_PROXY integration type with correct URI
8. **Deployment triggers work:** Changing configuration triggers redeployment
9. **Stage creation works:** Stage name matches provider.stage
10. **Lambda permissions work:** One permission per function with wildcard ARN
11. **Invoke URL output works:** Module outputs functional API Gateway URL
12. **Validation works:** Invalid methods, paths, parameters rejected with clear errors
13. **Multiple events work:** Multiple HTTP events on same function handled correctly
14. **No events work:** Configuration without HTTP events doesn't create API Gateway resources
15. **All tests pass:** Unit and integration tests pass successfully

## 9. Out of Scope

The following features are explicitly excluded from this implementation:

### Excluded Features

1. **Custom Authorizers:**
   - Lambda authorizers (TOKEN, REQUEST types)
   - Cognito User Pool authorizers
   - All `http.authorizer` configurations

2. **API Keys and Usage Plans:**
   - `http.private: true` configuration
   - API key resources
   - Usage plan resources
   - Rate limiting via API keys

3. **Request/Response Validation:**
   - Request body validation
   - Request parameter validation
   - Model definitions
   - `http.request.schemas` configuration

4. **Access Logging:**
   - CloudWatch log group integration
   - Access log format configuration
   - Execution logging settings

5. **Throttling:**
   - Method-level throttling
   - Stage-level throttling
   - Burst limits

6. **Custom Domain Names:**
   - ACM certificate integration
   - Base path mappings
   - Route 53 record creation
   - Custom domain configuration

7. **Binary Media Types:**
   - `binaryMediaTypes` configuration
   - Content handling transformations

8. **Request/Response Transformations:**
   - VTL (Velocity Template Language) templates
   - Mapping templates
   - Non-proxy integrations (HTTP, HTTP_PROXY, AWS integrations)

9. **WAF Integration:**
   - Web ACL associations
   - WAF rules configuration

10. **HTTP API (v2):**
    - Only REST API (v1) supported
    - HTTP API support is separate roadmap item

11. **Advanced CORS:**
    - `maxAge` configuration (parsed but not applied)
    - `allowCredentials` header configuration (parsed but not applied)
    - Pre-flight cache control

12. **Regional/Private APIs:**
    - Only EDGE endpoint type supported
    - Regional endpoint configuration excluded
    - Private API configuration excluded

### Rationale

These exclusions allow focus on the core use case: Lambda-backed REST API endpoints with basic CORS support. This matches the most common Serverless Framework usage patterns and provides a solid foundation. Advanced features can be added incrementally in future iterations.

## 10. Implementation Notes

### 10.1 Dependencies

**Module Dependencies:**
- Requires Spec 1 (Core Module Structure & YAML Parsing) outputs:
  - `local.parsed_config`
  - `local.functions_with_defaults`
  - `local.provider_with_defaults`
  - `local.validation_errors` pattern
- Requires Spec 2 (Lambda Function Translation) resources:
  - `aws_lambda_function.functions[*].arn`
  - `aws_lambda_function.functions[*].function_name`

**Provider Requirements:**
- AWS Provider >= 4.0 (stable API Gateway resources)
- No beta or experimental features required

### 10.2 Constraints

**API Gateway Limits:**
- 300 resources per REST API (validate or document)
- 10 path parameters per method (validate or document)
- Resource paths limited to 512 characters (validate or document)

**Terraform Constraints:**
- Resource names must be valid Terraform identifiers
- Use `for_each` instead of `count` for stability
- Explicit `depends_on` for deployment resource
- Use `count` for conditional singleton resources (REST API, deployment, stage)

**Serverless Framework Compatibility:**
- Match Serverless Framework default values exactly
- Support both short-form and long-form syntax
- Apply same validation rules as Serverless Framework

### 10.3 Recommendations

**File Organization:**
- Add API Gateway resource definitions to `main.tf` or create `api_gateway.tf`
- Add HTTP event parsing to `locals.tf`
- Add validation errors to existing validation collection in `locals.tf`
- Add API Gateway outputs to `outputs.tf`

**Code Organization:**
```
main.tf or api_gateway.tf:
  - aws_api_gateway_rest_api
  - aws_api_gateway_resource
  - aws_api_gateway_method
  - aws_api_gateway_integration
  - aws_api_gateway_method_response
  - aws_api_gateway_integration_response
  - aws_api_gateway_deployment
  - aws_api_gateway_stage
  - aws_lambda_permission (API Gateway)

locals.tf:
  - local.http_events
  - local.all_paths
  - local.path_segments
  - local.all_resource_paths
  - local.resource_tree
  - local.cors_defaults
  - local.resource_cors_config
  - local.cors_headers
  - local.functions_with_http_events
  - local.http_event_validation_errors (added to validation_errors)

outputs.tf:
  - output.api_gateway_rest_api_id
  - output.api_gateway_invoke_url
  - output.api_gateway_stage_name
  - output.api_gateway_resources
```

**Validation Strategy:**
- Add `local.http_event_validation_errors` to existing `local.validation_errors` concat
- Follow established error message format from Spec 1
- Validate early (in locals) to fail fast before resource creation

**Testing Strategy:**
- Follow existing test pattern from `tests/validation.tftest.hcl`
- Create fixtures in `tests/fixtures/` directory
- Use `expect_failures` for validation tests
- Use `assert` blocks for positive tests

**Documentation:**
- Update README.md with HTTP event examples
- Document CORS configuration options
- Add API Gateway outputs to documentation
- Include path parameter examples

**Future Extensibility:**
- Design locals to be reusable for HTTP API (v2) implementation
- Keep CORS logic modular for reuse
- Use consistent naming patterns for future event types
- Consider adding `local.api_type = "REST"` for future API type support

---

## Summary

This specification provides a comprehensive blueprint for implementing API Gateway REST API integration in the sls.tf module. It covers:

- Complete HTTP event parsing (short and long form)
- Hierarchical resource tree creation with path parameter support
- CORS handling with defaults and custom configuration
- All necessary AWS resources (8 resource types)
- Comprehensive validation and error handling
- Detailed testing strategy with 15+ test scenarios
- Clear scope boundaries and out-of-scope items
- Implementation guidance following established module patterns

The implementation should integrate seamlessly with the existing codebase, following established patterns for validation, resource naming, and testing while enabling developers to use familiar Serverless Framework syntax for defining HTTP API endpoints.
