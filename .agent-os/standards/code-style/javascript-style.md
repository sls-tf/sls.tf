# Javascript Style Guide
## Formatting
Use Prettier with default settings. No configuration needed.
## Linting
Use Oxlint with default rules. No configuration needed.
## Setup
bashnpm install --save-dev prettier oxlint
package.json scripts:
```
json{
  "scripts": {
    "format": "prettier --write .",
    "lint": "oxlint"
  }
}
```

## Key Defaults to Know

- Prettier: 2-space indents, semicolons, double quotes, trailing commas (es5)
- Oxlint: No unused variables, prefer const, no console.log in production, standard ESLint correctness rules

## Legacy Code

Existing codebases can remain as-is for now. Apply these standards to:

New files
Files being significantly refactored
Gradual migration when touching existing files

That's it. Let the tools handle the rest.
