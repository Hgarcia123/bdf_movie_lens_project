# Step 1 — AWS environment

Checked on 2026-11-22 with AWS CLI 2.42.1 (Learner Lab credentials).

## Environment

| Item | Value |
|---|---|
| Region | `us-east-1` |
| Role in use | `voclabs` (assumed role) |
| Account | `****6339` |

## Phase 3 access checks

All four checks succeeded (exit code 0). No resources were created.

| Command | Result |
|---|---|
| `aws s3 ls` | ✅ Lists 7 existing buckets |
| `aws glue get-databases` | ✅ 3 databases: `default`, `moviesdb`, `streamlab` |
| `aws athena list-work-groups` | ✅ Workgroup `primary` (ENABLED) |
| `aws iam get-role --role-name LabRole --query "Role.RoleName"` | ✅ `LabRole` |

## Naming convention

| Resource | Name |
|---|---|
| S3 bucket | `bdf26-movielens-6339` (`bdf26-movielens-<last 4 digits of account ID>`) |
| Glue database | `movielens` |
| Glue/Athena role | `LabRole` |

Note: the Glue database `movielens` and the bucket `bdf26-movielens-6339` don't exist yet. The existing `moviesdb` database is separate.
