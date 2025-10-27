# Module Interface Diagram

This diagram shows the inputs and outputs of the sls.tf core module.

```mermaid
graph TB
    subgraph "Module Inputs"
        I1[config_path<br/>string - required<br/>Path to serverless.yml]
        I2[config_format<br/>string - optional<br/>default: yaml]
        I3[aws_region<br/>string - optional<br/>Override for provider.region]
    end

    subgraph "sls.tf Core Module"
        M[Core Module<br/>YAML Parsing & Validation]
    end

    subgraph "Module Outputs"
        O1[parsed_config<br/>object<br/>Full parsed configuration]
        O2[service_name<br/>string<br/>Service identifier]
        O3[provider_config<br/>object<br/>AWS provider settings]
        O4[functions<br/>map of objects<br/>Lambda function definitions]
        O5[custom<br/>object<br/>Custom configuration]
        O6[resources<br/>object<br/>AWS resources to provision]
        O7[package<br/>object<br/>Packaging configuration]
    end

    I1 --> M
    I2 --> M
    I3 --> M

    M --> O1
    M --> O2
    M --> O3
    M --> O4
    M --> O5
    M --> O6
    M --> O7

    style M fill:#326CE5,color:#fff
    style I1 fill:#E8F4F8
    style I2 fill:#E8F4F8
    style I3 fill:#E8F4F8
    style O1 fill:#D4F1F4
    style O2 fill:#D4F1F4
    style O3 fill:#D4F1F4
    style O4 fill:#D4F1F4
    style O5 fill:#D4F1F4
    style O6 fill:#D4F1F4
    style O7 fill:#D4F1F4
```

## Input Variables

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `config_path` | string | yes | - | Path to serverless.yml or serverless.ts file |
| `config_format` | string | no | "yaml" | Configuration file format (yaml or typescript) |
| `aws_region` | string | no | null | Override AWS region (warns if different from config) |

## Output Values

| Output | Type | Description |
|--------|------|-------------|
| `parsed_config` | object | Complete parsed serverless configuration |
| `service_name` | string | Service name from configuration |
| `provider_config` | object | AWS provider configuration block |
| `functions` | map(object) | Map of Lambda function definitions |
| `custom` | object | Custom configuration section |
| `resources` | object | Additional AWS resources to create |
| `package` | object | Packaging configuration |
