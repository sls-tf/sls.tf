# S3 Event Configuration Flow

This diagram shows how S3 event configurations are parsed, normalized, validated, and transformed into AWS resources.

```mermaid
graph TD
    A[Parse serverless.yml] --> B{S3 events found?}
    B -->|No| Z[Skip S3 processing]
    B -->|Yes| C[Extract S3 event configs]
    C --> D{Shorthand or Object?}
    D -->|Shorthand| E[Use bucket name, default event type]
    D -->|Object| F[Extract bucket, event, rules, existing, forceDeploy]
    E --> G[Apply defaults]
    F --> G
    G --> H[Validate configurations]
    H --> I{Existing bucket?}
    I -->|No| J[Create new bucket]
    I -->|Yes| K[Reference existing bucket]
    J --> L[Group by bucket name]
    K --> L
    L --> M[Aggregate notifications per bucket]
    M --> N[Create Lambda permissions]
    M --> O[Create S3 bucket notifications]
    N --> P[Complete]
    O --> P

    style A fill:#e1f5ff
    style C fill:#e1f5ff
    style G fill:#fff4e1
    style H fill:#fff4e1
    style M fill:#ffe1e1
    style N fill:#e1ffe1
    style O fill:#e1ffe1
```

## Flow Stages

**1. Parsing (Blue):**
- Read serverless.yml configuration
- Extract S3 event definitions from function events

**2. Normalization (Yellow):**
- Distinguish between shorthand and object syntax
- Apply default values (event type, etc.)
- Validate configurations

**3. Aggregation (Red):**
- Group events by bucket name
- Merge multiple function subscriptions into single notification resource

**4. Resource Creation (Green):**
- Generate Lambda permissions for S3 invocation
- Create S3 bucket notification configurations
- Create new buckets or reference existing ones
