locals {
  # File reading with error handling
  file_content = try(
    file(var.config_path),
    null
  )

  # YAML parsing with friendly error messages
  parsed_config = var.config_format == "yaml" ? try(
    yamldecode(local.file_content),
    null
  ) : null
  # Future: TypeScript parsing support (roadmap item #6)
  # parsed_config = var.config_format == "typescript" ? ... : local.yaml_config

  # Comprehensive validation error collection
  validation_errors = local.parsed_config == null ? [] : concat(
    # Required field validations
    try(local.parsed_config.service, null) == null || try(local.parsed_config.service, "") == "" ?
    ["Required field 'service' is missing or empty. Specify service name in serverless.yml."] : [],

    try(local.parsed_config.provider, null) == null ?
    ["Required field 'provider' is missing. Add provider configuration in serverless.yml."] : [],

    try(local.parsed_config.provider.name, null) != "aws" ?
    ["Required field 'provider.name' must be 'aws', got: '${try(local.parsed_config.provider.name, "none")}'."] : [],

    # Strict runtime validation
    local.parsed_config != null ? local.runtime_validation_errors : [],

    # Optional provider field validations
    local.parsed_config != null ? local.provider_field_errors : [],

    # Function-level validations
    local.parsed_config != null ? local.function_validation_errors : [],

    # IAM statement validations (Roadmap #3)
    local.parsed_config != null ? local.provider_iam_validation_errors : [],
    local.parsed_config != null ? local.iam_validation_errors : [],

    # HTTP event validations (Roadmap #4)
    local.parsed_config != null ? local.http_event_validation_errors : []
  )

  # Runtime validation errors (strict mode)
  runtime_validation_errors = try(local.parsed_config.provider.runtime, null) == null && try(local.parsed_config.functions, null) != null ? flatten([
    for func_name, func in try(local.parsed_config.functions, {}) :
    try(func.runtime, null) == null ?
    ["Function '${func_name}' missing required 'runtime' field. Either set provider.runtime or specify runtime for each function."] : []
  ]) : []

  # Provider field validation errors
  provider_field_errors = concat(
    # Validate frameworkVersion if specified
    try(local.parsed_config.frameworkVersion, null) != null &&
    !can(regex("^[234](\\..*)?$", local.parsed_config.frameworkVersion)) ?
    ["Field 'frameworkVersion' must be 2.x, 3.x, or 4.x, got: '${local.parsed_config.frameworkVersion}'."] : [],

    # Validate provider.memorySize range
    try(local.parsed_config.provider.memorySize, null) != null &&
    (local.parsed_config.provider.memorySize < 128 || local.parsed_config.provider.memorySize > 10240) ?
    ["Field 'provider.memorySize' must be between 128 and 10240 MB, got: ${local.parsed_config.provider.memorySize}."] : [],

    # Validate provider.timeout range
    try(local.parsed_config.provider.timeout, null) != null &&
    (local.parsed_config.provider.timeout < 1 || local.parsed_config.provider.timeout > 900) ?
    ["Field 'provider.timeout' must be between 1 and 900 seconds, got: ${local.parsed_config.provider.timeout}."] : []
  )

  # Function-level validation errors
  function_validation_errors = flatten([
    for func_name, func in try(local.parsed_config.functions, {}) : concat(
      # Validate required handler field
      try(func.handler, null) == null ?
      ["Function '${func_name}' missing required 'handler' field."] : [],

      # Validate function memorySize range
      try(func.memorySize, null) != null &&
      (func.memorySize < 128 || func.memorySize > 10240) ?
      ["Function '${func_name}' has invalid 'memorySize'. Must be between 128 and 10240 MB, got: ${func.memorySize}."] : [],

      # Validate function timeout range
      try(func.timeout, null) != null &&
      (func.timeout < 1 || func.timeout > 900) ?
      ["Function '${func_name}' has invalid 'timeout'. Must be between 1 and 900 seconds, got: ${func.timeout}."] : []
    )
  ])

  # Provider-level IAM validation errors (Roadmap #3)
  provider_iam_validation_errors = try(local.parsed_config.provider.iamRoleStatements, null) != null ? flatten([
    for idx, stmt in local.parsed_config.provider.iamRoleStatements : concat(
      # Validate Effect field
      !contains(["Allow", "Deny"], try(stmt.Effect, "")) ?
      ["Provider iamRoleStatement[${idx}]: Effect must be 'Allow' or 'Deny', got '${try(stmt.Effect, "none")}'."] : [],

      # Validate Action field exists
      try(stmt.Action, null) == null ?
      ["Provider iamRoleStatement[${idx}]: Required field 'Action' is missing."] : [],

      # Validate Resource field exists
      try(stmt.Resource, null) == null ?
      ["Provider iamRoleStatement[${idx}]: Required field 'Resource' is missing."] : [],

      # Validate Action format (service:action pattern)
      try(stmt.Action, null) != null ? flatten([
        for act in try(tolist(stmt.Action), [stmt.Action]) :
        !can(regex("^[a-z0-9]+:[*a-zA-Z0-9]+$", act)) ?
        ["Provider iamRoleStatement[${idx}]: Invalid action format '${act}'. Must match 'service:action' pattern."] : []
      ]) : []
    )
  ]) : []

  # Function-level IAM validation errors (Roadmap #3)
  iam_validation_errors = flatten([
    for func_name, func in try(local.parsed_config.functions, {}) :
    try(func.iamRoleStatements, null) != null ? flatten([
      for idx, stmt in func.iamRoleStatements : concat(
        # Validate Effect field
        !contains(["Allow", "Deny"], try(stmt.Effect, "")) ?
        ["Function '${func_name}' iamRoleStatement[${idx}]: Effect must be 'Allow' or 'Deny', got '${try(stmt.Effect, "none")}'."] : [],

        # Validate Action field exists
        try(stmt.Action, null) == null ?
        ["Function '${func_name}' iamRoleStatement[${idx}]: Required field 'Action' is missing."] : [],

        # Validate Resource field exists
        try(stmt.Resource, null) == null ?
        ["Function '${func_name}' iamRoleStatement[${idx}]: Required field 'Resource' is missing."] : [],

        # Validate Action format (service:action pattern)
        try(stmt.Action, null) != null ? flatten([
          for act in try(tolist(stmt.Action), [stmt.Action]) :
          !can(regex("^[a-z0-9]+:[*a-zA-Z0-9]+$", act)) ?
          ["Function '${func_name}' iamRoleStatement[${idx}]: Invalid action format '${act}'. Must match 'service:action' pattern."] : []
        ]) : []
      )
    ]) : []
  ])

  # Provider-level defaults application
  provider_with_defaults = local.parsed_config == null ? null : merge(
    try(local.parsed_config.provider, {}),
    {
      stage      = coalesce(try(local.parsed_config.provider.stage, null), "dev")
      region     = coalesce(try(local.parsed_config.provider.region, null), var.aws_region, "us-east-1")
      memorySize = coalesce(try(local.parsed_config.provider.memorySize, null), 1024)
      timeout    = coalesce(try(local.parsed_config.provider.timeout, null), 6)
      # Runtime has NO default - must be explicitly specified (strict validation)
    }
  )

  # Function-level default inheritance
  functions_with_defaults = {
    for func_name, func in try(local.parsed_config.functions, {}) :
    func_name => merge(func, {
      runtime    = try(coalesce(try(func.runtime, null), try(local.parsed_config.provider.runtime, null)), null)
      memorySize = coalesce(try(func.memorySize, null), local.provider_with_defaults.memorySize)
      timeout    = coalesce(try(func.timeout, null), local.provider_with_defaults.timeout)
    })
    if length(local.validation_errors) == 0
  }

  # Region override warning
  region_warnings = (
    var.aws_region != null &&
    try(local.parsed_config.provider.region, null) != null &&
    var.aws_region != local.parsed_config.provider.region
    ) ? [
    "WARNING: aws_region override '${var.aws_region}' differs from serverless.yml region '${local.parsed_config.provider.region}'. Using override value."
  ] : []

  # IAM Role Statement Parsing (Roadmap #3)
  # Provider-level iamRoleStatements
  provider_iam_statements = try(local.parsed_config.provider.iamRoleStatements, [])

  # Normalize provider-level statements (Action/Resource: string -> array)
  provider_iam_statements_normalized = [
    for stmt in local.provider_iam_statements :
    merge(stmt, {
      Action   = try(tolist(stmt.Action), [stmt.Action])
      Resource = try(tolist(stmt.Resource), [stmt.Resource])
    })
  ]

  # Function-level iamRoleStatements (map of function_name -> statements)
  function_iam_statements = {
    for func_name, func in local.functions_with_defaults :
    func_name => try(func.iamRoleStatements, [])
  }

  # Normalize function-level statements (Action/Resource: string -> array)
  function_iam_statements_normalized = {
    for func_name, stmts in local.function_iam_statements :
    func_name => [
      for stmt in stmts :
      merge(stmt, {
        Action   = try(tolist(stmt.Action), [stmt.Action])
        Resource = try(tolist(stmt.Resource), [stmt.Resource])
      })
    ]
  }

  # Merge provider and function statements per function
  merged_iam_statements = {
    for func_name, func in local.functions_with_defaults :
    func_name => concat(
      local.provider_iam_statements_normalized,
      local.function_iam_statements_normalized[func_name]
    )
  }

  # Functions requiring custom policies (non-empty statements)
  functions_with_policies = {
    for func_name, statements in local.merged_iam_statements :
    func_name => statements
    if length(statements) > 0
  }

  # HTTP Event Parsing (Roadmap #4)
  # Extract all HTTP events from all functions
  http_events = flatten([
    for func_name, func in local.functions_with_defaults : [
      for event in try(func.events, []) : {
        function_name = func_name
        # Don't reference Lambda ARN here to avoid circular dependency
        # ARN will be referenced in API Gateway resources
        handler       = func.handler
        runtime       = func.runtime

        # Parse short-form: "http: GET /users/{id}"
        # Parse long-form: "http: { path: /users, method: GET, cors: true }"
        http_method = (can(event.http) && can(regex("^[A-Z]+ ", tostring(event.http)))) ? upper(split(" ", tostring(event.http))[0]) : upper(try(event.http.method, ""))

        http_path = (can(event.http) && can(regex("^[A-Z]+ ", tostring(event.http)))) ? trimprefix(trimsuffix(trimspace(substr(tostring(event.http), length(split(" ", tostring(event.http))[0]) + 1, -1)), "/"), "") : trimsuffix(try(event.http.path, ""), "/")

        cors_enabled = can(event.http.cors) ? (can(tobool(event.http.cors)) ? tobool(event.http.cors) : true) : false

        cors_config = (can(event.http.cors) && !can(tobool(event.http.cors))) ? event.http.cors : null
      }
      if can(event.http)
    ]
  ])

  # Deduplicate functions with HTTP events for permissions
  functions_with_http_events = toset([
    for event in local.http_events : event.function_name
  ])

  # HTTP event validation errors
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
      ["Function '${event.function_name}' has invalid path parameter syntax in '${event.http_path}'. Parameters must be {paramName} with alphanumeric/underscore characters only."] : []
    )
  ])
}
