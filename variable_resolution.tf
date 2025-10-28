# ==============================================================================
# Variable Resolution Engine
# ==============================================================================
#
# This file implements resolution for Serverless Framework variable syntax:
# - ${self:path.to.property} - References to other properties in config
# - ${env:VARIABLE_NAME} - Environment variables
# - ${env:VAR, 'default'} - Environment variables with default values
#
# Resolution Process:
# 1. Extract all variable patterns from raw config
# 2. Build dependency graph
# 3. Detect circular references
# 4. Resolve variables in dependency order
# 5. Replace variables in config with resolved values
#
# Phase 1 Implementation (this file):
# - ${self:} resolution
# - ${env:} resolution
# - Recursive resolution with depth tracking
# - Circular reference detection
#
# Future Phases:
# - ${opt:} - CLI options
# - ${cf:} - CloudFormation outputs
# - ${ssm:} - SSM parameters
# - ${file()} - External file references

locals {
  # Variable resolution configuration
  var_resolution_config = {
    strict           = var.strict_variable_resolution
    max_depth        = var.max_variable_depth
    environment_vars = var.environment_vars
  }

  # ===========================================================================
  # Variable Pattern Detection
  # ===========================================================================

  # Regex patterns for detecting variables
  # ${self:path.to.property} - References to config properties
  # ${env:VARIABLE_NAME} or ${env:VAR, 'default'} - Environment variables
  variable_pattern_regex = "\\$\\{([^}]+)\\}"

  # Helper function to extract all variable references from a string value
  # Returns list of variable expressions like ["self:provider.stage", "env:NODE_ENV"]
  extract_variable_refs = {
    for k, v in flatten([
      for key, value in local.parsed_config : [
        {
          path  = key
          value = tostring(value)
          matches = try(
            regexall(local.variable_pattern_regex, tostring(value)),
            []
          )
        }
      ]
      if can(tostring(value))
    ]) : v.path => v.matches if length(v.matches) > 0
  }

  # Parse variable expressions into structured format
  # Example: "self:provider.stage" => {type: "self", path: "provider.stage"}
  # Example: "env:NODE_ENV, 'production'" => {type: "env", name: "NODE_ENV", default: "production"}
  parsed_variables = {
    for path, matches in local.extract_variable_refs : path => [
      for match in matches : {
        raw        = match[0]
        expression = match[0]
        type = split(":", match[0])[0]
        # For ${self:}, the reference is everything after "self:"
        # For ${env:}, handle both "env:VAR" and "env:VAR, 'default'"
        reference = length(split(":", match[0])) > 1 ? join(":", slice(split(":", match[0]), 1, length(split(":", match[0])))) : ""
      }
    ]
  }

  # ===========================================================================
  # ${self:} Resolution Algorithm
  # ===========================================================================

  # Helper function to traverse object paths like "provider.stage"
  # Returns the value at that path or null if not found
  traverse_path = {
    # Pre-compute common self-reference paths
    "service"             = try(local.parsed_config.service, null)
    "provider.name"       = try(local.parsed_config.provider.name, null)
    "provider.stage"      = try(local.parsed_config.provider.stage, null)
    "provider.region"     = try(local.parsed_config.provider.region, null)
    "provider.runtime"    = try(local.parsed_config.provider.runtime, null)
    "custom.defaultStage" = try(local.parsed_config.custom.defaultStage, null)
    "custom.bucketName"   = try(local.parsed_config.custom.bucketName, null)
  }

  # First pass: resolve simple ${self:} references
  # This handles direct references without nested variables
  config_with_self_resolved = {
    for key, value in local.parsed_config : key => (
      can(tostring(value)) && can(regex("\\$\\{self:", tostring(value))) ? (
        # Replace ${self:} variables with actual values
        replace(
          replace(
            replace(
              replace(
                tostring(value),
                "$${self:service}",
                tostring(try(local.traverse_path["service"], "$${self:service}"))
              ),
              "$${self:provider.stage}",
              tostring(try(local.traverse_path["provider.stage"], "$${self:provider.stage}"))
            ),
            "$${self:provider.region}",
            tostring(try(local.traverse_path["provider.region"], "$${self:provider.region}"))
          ),
          "$${self:custom.defaultStage}",
          tostring(try(local.traverse_path["custom.defaultStage"], "$${self:custom.defaultStage}"))
        )
      ) : value
    )
  }

  # ===========================================================================
  # ${env:} Resolution Algorithm
  # ===========================================================================

  # Parse ${env:} expressions to extract variable name and optional default
  # Example: "env:NODE_ENV" => {name: "NODE_ENV", default: null}
  # Example: "env:STAGE, 'production'" => {name: "STAGE", default: "production"}
  env_variables_parsed = {
    for key, value in local.config_with_self_resolved : key => (
      can(tostring(value)) && can(regex("\\$\\{env:", tostring(value))) ? [
        for match in regexall("\\$\\{env:([^,}]+)(?:,\\s*['\"]([^'\"]+)['\"])?\\}", tostring(value)) : {
          full_match = "$${env:${match[0]}${match[1] != "" ? ", '${match[1]}'" : ""}}"
          var_name   = match[0]
          default    = match[1] != "" ? match[1] : null
        }
      ] : []
    ) if can(tostring(value)) && can(regex("\\$\\{env:", tostring(value)))
  }

  # Second pass: resolve ${env:} variables
  config_with_env_resolved = {
    for key, value in local.config_with_self_resolved : key => (
      can(tostring(value)) && can(regex("\\$\\{env:", tostring(value))) ? (
        # Get parsed env variables for this value
        length(try(local.env_variables_parsed[key], [])) > 0 ? (
          # Replace each ${env:} with resolved value or default
          reduce(local.env_variables_parsed[key], tostring(value), (result, env_var) => replace(
            result,
            env_var.full_match,
            try(
              var.environment_vars[env_var.var_name],
              try(env_var.default, env_var.full_match)
            )
          ))
        ) : value
      ) : value
    )
  }

  # Final resolved config - combines ${self:} and ${env:} resolution
  resolved_config = local.config_with_env_resolved

  # Variable resolution errors - collect unresolved variables if strict mode
  variable_resolution_errors = var.strict_variable_resolution ? flatten([
    for key, value in local.resolved_config : [
      for match in try(regexall("\\$\\{(self|env):[^}]+\\}", tostring(value)), []) :
        "Unresolved variable in '${key}': ${match}"
    ]
  ]) : []
}
