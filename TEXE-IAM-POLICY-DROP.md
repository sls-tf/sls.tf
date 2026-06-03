# Bug: inline SAM `Policies` silently dropped for most functions

## Summary

When a SAM `AWS::Serverless::Function` declares inline IAM policies, sls-tf
**silently fails to create the `aws_iam_role_policy`** for the function unless
its `Policies` list and every `Statement` in it are *type-homogeneous*. The
function still gets a role (with only `AWSLambdaBasicExecutionRole` attached),
so it deploys and runs but is missing all its custom permissions — failing at
runtime with `AccessDenied`.

In the texe `env-initializer-lambdas` template this dropped **12 of 14**
functions' policies. It was invisible at plan/apply time (no error, no diff —
the policy resource simply never enters `for_each`), and only surfaced when the
health-reconciler Lambda started throwing `dynamodb:Scan ... AccessDenied` in
production.

## Root cause

Two `tolist()` coercions over data that is legitimately heterogeneous in SAM:

1. **`tolist(resource.Properties.Policies)`** — in both `sam-parser.tf`
   (`iamRoleStatements`) and `locals.tf` (`_function_has_policies`). A SAM
   `Policies` list may mix forms, e.g.:

   ```yaml
   Policies:
     - VPCAccessPolicy: {}          # SAM policy template  → object {VPCAccessPolicy=...}
     - Statement: [ ... ]           # inline document      → object {Statement=...}
   ```

   Those two elements have different object types, so `tolist()` cannot unify
   them and throws. The surrounding `try(..., [])` swallows the error to an
   empty list → the function is treated as having **no** policies at all.

2. **`tolist(policy.Statement)`** — a `Statement` list is heterogeneous whenever
   statements differ in shape: some carry a `Condition`, `Resource` is sometimes
   a string and sometimes a list, and an `!If`-gated entry has a different shape
   again. Same failure mode.

3. **`try(policy.Statement, null) != null ? [ ...objects... ] : []`** — once (1)
   and (2) are fixed by iterating directly, this ternary fails with
   *"Inconsistent conditional result types"*: its branches are length-typed
   tuples (`tuple([obj,obj,obj])` vs the empty `tuple([])`) which Terraform
   cannot unify for complex object elements.

Why some functions survived: a function whose `Policies` is a single inline
`Statement` entry, with statements uniform enough to coerce, passes `tolist()`
and renders correctly. In the texe template exactly the two such functions
(`EnvGatewayManager`, `UpdateAmi`) kept their policies; the other twelve — those
mixing `VPCAccessPolicy` with `Statement`, or with mixed-shape statements, or an
`!If`-gated statement — lost theirs.

## Fix

Iterate the `Policies` and `Statement` lists **directly** instead of via
`tolist()`, and replace the `? [...] : []` ternary with a nested comprehension
(a policy-template entry has no `.Statement`, so it just yields nothing). `for`
tolerates heterogeneous tuples; `tolist` does not.

- `sam-parser.tf` — `iamRoleStatements`
- `locals.tf` — `_function_has_policies`

Both are applied in this working tree. The per-statement field handling
(`Effect`/`Action`/`Resource`/`Condition` with their `try`/`compact`/stringify
guards) is unchanged, as is the empty-Resource skip.

## Verification

Against the texe `env-initializer-lambdas` SAM template (14 functions, a mix of
inline `Statement`, `VPCAccessPolicy` + `Statement`, mixed-shape statements, and
`!If`-gated statements):

| state | `aws_iam_role_policy` created |
|-------|-------------------------------|
| before (v0.3.8) | 2 / 14 |
| inner `Statement` fix only | 11 / 14 |
| full fix (both lists + ternary) | **14 / 14**, `plan` clean, 0 destroy |

Spot-checked that the rendered HealthReconciler policy contains the expected
`dynamodb:Scan`/`dynamodb:UpdateItem` (table + `/index/*`),
`elasticloadbalancing:DescribeTargetHealth`, and the `!If HasAuroraCluster`
`rds:*` statement — i.e. statement content and `!If` resolution are preserved;
only the gating/coercion changed.

## Follow-up: action-format validator rejects hyphenated services (v0.3.10)

Once the policies above actually parse, the IAM action-format validator
(`provider_iam_validation_errors` / `iam_validation_errors` in `locals.tf`)
rejected valid actions whose **service segment contains a hyphen** — e.g.
`rds-data:ExecuteStatement`, `execute-api:Invoke`, `cognito-idp:*`. The regex
was `^[a-z0-9]+:[*a-zA-Z0-9]+$`; widened the service class to `[a-z0-9-]+`.
This only surfaced on `develop` (its `CreatePgDatabaseFunction`, which uses the
RDS Data API, is gated off on `test`).

## Suggested regression test

Add a fixture function whose `Policies` mixes a policy template with an inline
`Statement`, and whose statements include one with a `Condition` and one
`!If`-gated entry, then assert `aws_iam_role_policy` is planned for it.
