# Data Flow Diagram

This diagram illustrates how YAML configuration flows through parsing, validation, and output generation.

```mermaid
flowchart TD
    Start([Module Invocation]) --> LoadFile[Load Configuration File<br/>using file function]
    LoadFile --> CheckFormat{config_format<br/>== yaml?}

    CheckFormat -->|Yes| ParseYAML[Parse YAML<br/>using yamldecode]
    CheckFormat -->|No| FutureTS[Future: TypeScript Support<br/>Roadmap Item 6]

    ParseYAML --> TryCatch{YAML Valid?}
    TryCatch -->|No| YAMLError[HALT: Invalid YAML<br/>Show friendly error message]
    TryCatch -->|Yes| ValidateSchema[Validate Schema]

    ValidateSchema --> CheckService{service<br/>field exists?}
    CheckService -->|No| ErrorService[ERROR: Missing service name]

    CheckService -->|Yes| CheckProvider{provider.name<br/>== aws?}
    CheckProvider -->|No| ErrorProvider[ERROR: Provider must be aws]

    CheckProvider -->|Yes| CheckFunctions{functions<br/>defined?}
    CheckFunctions -->|Yes| ValidFunctions[Validate function definitions]
    CheckFunctions -->|No| AllowEmpty[Allow empty functions<br/>Valid configuration]

    ValidFunctions --> CheckVersion{frameworkVersion<br/>specified?}
    AllowEmpty --> CheckVersion

    CheckVersion -->|Yes| ValidateVersion[Validate against<br/>Serverless Framework 4.x]
    CheckVersion -->|No| SkipVersion[Skip version validation]

    ValidateVersion --> ApplyDefaults
    SkipVersion --> ApplyDefaults[Apply Default Values]

    ApplyDefaults --> SetStage[provider.stage<br/>default: dev]
    SetStage --> SetRegion[provider.region<br/>default: us-east-1]
    SetRegion --> SetRuntime[provider.runtime<br/>default: none - must be explicit]

    SetRuntime --> CheckOverride{aws_region<br/>variable set?}
    CheckOverride -->|Yes| CompareRegion{Override != config<br/>region?}
    CheckOverride -->|No| BuildOutputs

    CompareRegion -->|Yes| WarnRegion[WARNING: Region mismatch<br/>Continue with override]
    CompareRegion -->|No| BuildOutputs[Build Output Objects]
    WarnRegion --> BuildOutputs

    BuildOutputs --> OutService[Output: service_name]
    BuildOutputs --> OutProvider[Output: provider_config]
    BuildOutputs --> OutFunctions[Output: functions]
    BuildOutputs --> OutCustom[Output: custom]
    BuildOutputs --> OutResources[Output: resources]
    BuildOutputs --> OutPackage[Output: package]
    BuildOutputs --> OutFull[Output: parsed_config]

    OutService --> Complete([Module Ready])
    OutProvider --> Complete
    OutFunctions --> Complete
    OutCustom --> Complete
    OutResources --> Complete
    OutPackage --> Complete
    OutFull --> Complete

    ErrorService --> CollectErrors[Collect All Validation Errors]
    ErrorProvider --> CollectErrors
    CollectErrors --> ShowErrors[HALT: Show all errors together]
    YAMLError --> End([Execution Halted])
    ShowErrors --> End

    style Start fill:#90EE90
    style Complete fill:#90EE90
    style End fill:#FFB6C1
    style YAMLError fill:#FF6B6B,color:#fff
    style ErrorService fill:#FF6B6B,color:#fff
    style ErrorProvider fill:#FF6B6B,color:#fff
    style ShowErrors fill:#FF6B6B,color:#fff
    style WarnRegion fill:#FFA500,color:#fff
    style ParseYAML fill:#326CE5,color:#fff
    style ValidateSchema fill:#326CE5,color:#fff
    style ApplyDefaults fill:#326CE5,color:#fff
    style BuildOutputs fill:#326CE5,color:#fff
```

## Key Processing Steps

1. **File Loading**: Read configuration file from `config_path`
2. **Format Detection**: Check `config_format` variable (YAML only for now)
3. **YAML Parsing**: Use `yamldecode()` wrapped in `try()` for error handling
4. **Schema Validation**: Validate required fields (service, provider.name)
5. **Function Validation**: Allow empty functions list (functionless configs valid)
6. **Framework Version**: Validate `frameworkVersion` if specified
7. **Default Application**: Apply Serverless Framework defaults (stage, region)
8. **Region Override**: Compare `aws_region` variable with config, warn if different
9. **Output Generation**: Build all output objects for downstream modules
10. **Error Collection**: Gather ALL validation errors and display together
