# terraform-floci

Learning Terraform against a **local AWS emulator (Floci)** instead of a real AWS account — no cloud costs, no credentials, fully offline-friendly.

[Floci](https://floci.io/aws/) ([GitHub](https://github.com/floci-io/floci)) is a free, open-source local AWS emulator (a LocalStack-style alternative). It exposes AWS-compatible APIs on `http://localhost:4566`, so the AWS CLI, SDKs, and Terraform's `aws` provider can all talk to it as if it were real AWS — just point the endpoint at localhost and use dummy credentials.

## What's in this repo

| File | Purpose |
|---|---|
| [provider.tf](provider.tf) | `aws` provider (`~> 6.0`) pinned to the Floci endpoints for `s3`, `sts`, and `sqs`, plus an `s3` backend block for remote state |
| [backend.tf](backend.tf) | Root module: looks up the current account id and calls the `s3_bucket`, `dynamodb_table`, and `sqs` modules |
| [variables.tf](variables.tf) | Root input variables (no defaults — every value comes from a `.tfvars` file or `-var`): `region`, `bucket_name`, `billing_mode`, `table_names`, `sqs_name`, `module_delay_seconds`, `module_max_message_size`, `module_message_retention_seconds`, `module_receive_wait_time_seconds` |
| [modules/s3_bucket/](modules/s3_bucket/) | Reusable module: `main.tf` (bucket + versioning), `variable.tf` (`bucket_name`, `region`, `version_status`), `output.tf` (`arn`) |
| [modules/dynamodb_table/](modules/dynamodb_table/) | Reusable module: `main.tf` (one `aws_dynamodb_table` per entry in `module_table_names`, via `for_each`), `variable.tf` (`module_table_names`, `module_billing_mode`, `module_region`), `output.tf` (`module_dynamodb_table_arn`, `module_dynamodb_table_name`) |
| [modules/sqs/](modules/sqs/) | Reusable module: `main.tf` (one FIFO `aws_sqs_queue` per entry in `module_sqs_name`, via `for_each`), `variable.tf` (`module_sqs_name`, `module_region`, `module_delay_seconds`, `module_max_message_size`, `module_message_retention_seconds`, `module_receive_wait_time_seconds`), `output.tf` (`queue_name`, `queue_arn`) |
| [run.sh](run.sh) | Convenience script: `terraform fmt`, prompts you to pick a `staging`/`production` workspace, then `validate`, `plan`, `apply` using that workspace's `.tfvars` file |
| [staging.tfvars](staging.tfvars) | Var overrides for the `staging` workspace |
| [production.tfvars](production.tfvars) | Var overrides for the `production` workspace |
| [single-file/](single-file/) | Pre-module flat config (`s3.tf`, `dynamodb.tf`, `sqs.tf`, `output.tf`, `variables.tf`) kept for reference; meant to be excluded from `terraform` via [.terraformignore](.terraformignore) |

State is stored remotely in an S3 bucket (`floci-tf-state-bucket`, in Floci) via the `backend "s3"` block in [provider.tf](provider.tf), using native S3 state locking (`use_lockfile = true`) instead of a DynamoDB lock table. Use `terraform workspace` (`staging`/`production`) with the matching `.tfvars` file to keep environments separate — each workspace gets its own state within that same bucket, and `terraform.workspace` is baked directly into resource names (see below) so the two environments' resources never collide.

> **Heads up:** [.terraformignore](.terraformignore) still points at the old `01_old-terra-files` folder name — that directory was renamed to [single-file/](single-file/), so the ignore entry no longer matches anything. Update it to `single-file` if you don't want those `.tf` files picked up by `terraform`.

### The `s3_bucket` module

[backend.tf](backend.tf) delegates bucket creation to [modules/s3_bucket](modules/s3_bucket/), naming the bucket from the region, account id, **and now the active workspace**, so `staging` and `production` never fight over the same bucket name:

```hcl
data "aws_caller_identity" "current" {}

module "module_bucket_config" {
  source         = "./modules/s3_bucket"
  bucket_name    = format("%s-%s-%s-%s", var.bucket_name, terraform.workspace, data.aws_caller_identity.current.account_id, var.region)
  region         = var.region
  version_status = "Enabled"
}
```

The module itself (`modules/s3_bucket/main.tf`) creates the `aws_s3_bucket` and an `aws_s3_bucket_versioning` resource set to `var.version_status`, and exposes the bucket's `arn` as a module output.

### The `dynamodb_table` module

[backend.tf](backend.tf) also calls [modules/dynamodb_table](modules/dynamodb_table/) to create one or more DynamoDB tables:

```hcl
module "module_dynamodb_table_config" {
  source              = "./modules/dynamodb_table"
  module_table_names  = var.table_names
  module_billing_mode = var.billing_mode
  module_region       = var.region
}
```

The module (`modules/dynamodb_table/main.tf`) uses `for_each` over `module_table_names` to create one `aws_dynamodb_table` per name, all sharing the same hash key (`ModuleTableHashKey`, type `S`) and `module_billing_mode`, and exposes each table's `arn`/`name` as list outputs.

### The `sqs` module

[backend.tf](backend.tf) also calls [modules/sqs](modules/sqs/) to create one or more FIFO SQS queues:

```hcl
module "module_sqs_queue_config" {
  source                           = "./modules/sqs"
  module_sqs_name                  = var.sqs_name
  module_delay_seconds             = var.module_delay_seconds
  module_max_message_size          = var.module_max_message_size
  module_region                    = var.region
  module_message_retention_seconds = var.module_message_retention_seconds
  module_receive_wait_time_seconds = var.module_receive_wait_time_seconds
}
```

The module (`modules/sqs/main.tf`) uses `for_each` over `module_sqs_name` to create one `aws_sqs_queue` per name, all as FIFO queues (`fifo_queue = true`). Each queue is named `floci-<name>-<workspace>-queue.fifo` — `terraform.workspace` is baked into the name the same way it is for the S3 bucket, so `staging`/`production` queues don't collide. Outputs are `queue_name` and `queue_arn` (one per queue). [provider.tf](provider.tf)'s `endpoints` block now includes `sqs = "http://localhost:4566"` so this module can talk to Floci.

## Prerequisites

- **Docker** (and Docker Compose) — Floci runs service backends (Lambda, RDS, ECS, etc.) as real Docker containers
- **Terraform** — [install docs](https://developer.hashicorp.com/terraform/install)
- **AWS CLI v2** (optional, but handy for poking at resources directly) — [install docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## 1. Install Floci

**macOS (Homebrew):**
```bash
brew install floci-io/floci/floci
```

**macOS/Linux (install script):**
```bash
curl -fsSL https://floci.io/install.sh | sh
```

**Windows (PowerShell):**
```powershell
iwr https://floci.io/install.ps1 | iex
```

> Prefer not to run a remote install script? Use Docker directly instead — see the alternative below.

## 2. Start Floci

```bash
floci start
```

Load the emulator's environment variables (AWS endpoint + dummy credentials) into your current shell:

```bash
eval $(floci env)
```

Check it's healthy:

```bash
floci status
floci doctor
```

### Alternative: run via Docker directly (no CLI install)

```bash
docker run -d --name floci \
  -p 4566:4566 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  floci/floci:latest
```

Then export the same environment variables manually:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

## 3. Sanity-check with the AWS CLI

```bash
aws s3 mb s3://my-test-bucket
aws s3 ls
```

If that lists your new bucket, Floci is up and answering AWS API calls correctly. `aws s3 mb` here was just a smoke test — feel free to delete that bucket afterward.

## 4. Point Terraform at Floci

Terraform's `aws` provider needs to be told to hit `localhost:4566` instead of real AWS, and to skip credential/region validation since Floci accepts dummy values. This repo's [provider.tf](provider.tf) does exactly that for the services it uses (`s3`, `sts`, `sqs`):

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3  = "http://localhost:4566"
    sts = "http://localhost:4566"
    sqs = "http://localhost:4566"
  }
}
```

> Add more entries to the `endpoints` block (`lambda`, `ec2`, `iam`, `dynamodb`, ...) if you extend this config to use other services. Note that `dynamodb` isn't in the block above yet even though the `dynamodb_table` module is wired into `backend.tf` — add it before applying against Floci.

### Backend: S3 state, no DynamoDB lock table

[provider.tf](provider.tf) also configures a `backend "s3"` block, so `terraform init` stores state remotely instead of in a local `terraform.tfstate` file:

```hcl
backend "s3" {
  bucket = "floci-tf-state-bucket"
  key    = "terraform-floci/terraform.tfstate"
  region = "us-east-1"
  endpoints = {
    s3 = "http://localhost:4566"
  }
  use_lockfile = true

  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  use_path_style              = true
}
```

`use_lockfile` uses the S3 backend's native locking (Terraform 1.11+) — it writes a `.tflock` file alongside the state object via S3 conditional writes, so no separate DynamoDB lock table is needed.

**Create the state bucket in Floci before running `terraform init`** — the backend won't create it for you:

```bash
aws s3 mb s3://floci-tf-state-bucket
```

Enable versioning on it too — this keeps prior state file versions around so a corrupted or bad `apply` can be rolled back:

```bash
aws s3api put-bucket-versioning --bucket floci-tf-state-bucket --versioning-configuration Status=Enabled
```

## 5. Run it

None of the root variables in [variables.tf](variables.tf) have defaults anymore, so you must supply every value via `-var-file` (or individual `-var` flags) — plain `terraform plan`/`apply` with no var file will fail with "no value for variable" errors.

Create and select a workspace, then plan/apply with the matching `.tfvars` file:

```bash
terraform init
terraform workspace new staging      # or: terraform workspace select staging
terraform plan  -var-file=staging.tfvars
terraform apply -var-file=staging.tfvars
```

Swap in `terraform workspace select production` + `production.tfvars` to target the production var set instead. Each workspace's `.tfvars` sets: `region`, `bucket_name`, `billing_mode`, `table_names`, `sqs_name`, and the SQS tuning vars (`module_delay_seconds`, `module_max_message_size`, `module_message_retention_seconds`, `module_receive_wait_time_seconds`).

Or run the interactive helper, which formats, lets you pick the workspace, then validates/plans/applies with that workspace's `.tfvars` for you:

```bash
./run.sh
```

On success you'll get: `arn` from `module_bucket_config` (the S3 bucket), `module_dynamodb_table_arn`/`module_dynamodb_table_name` from `module_dynamodb_table_config` (one entry per table in `table_names`), and `queue_name`/`queue_arn` from `module_sqs_queue_config` (one entry per queue in `sqs_name`).

## 6. Verify resources with the AWS CLI

Once `terraform apply` finishes, point the AWS CLI at the same region you deployed to (`-var-file`'s `region`, e.g. `us-east-2` for staging) and check what actually got created:

```bash
# List all S3 buckets
aws s3 ls

# Check which region a bucket lives in
aws s3api get-bucket-location --bucket <bucket_name>

# Confirm versioning is enabled
aws s3api get-bucket-versioning --bucket <bucket_name>

# List DynamoDB tables
aws dynamodb list-tables

# List SQS queues
aws sqs list-queues
```

## 7. Useful Floci commands

| Command | Purpose |
|---|---|
| `floci status` | Check whether the emulator is running |
| `floci logs --follow` | Tail live logs |
| `floci snapshot save` / `floci snapshot restore` | Persist and reload emulator state between sessions |
| `floci stop` | Shut the emulator down |

## Notes

- Credentials are dummy values (`test`/`test`) — Floci doesn't authenticate by default, so never point real AWS credentials at it.
- Not every AWS API has 100% parity — treat this as a fast local feedback loop for learning/testing Terraform, not a guarantee of production behavior.
- `terraform.workspace` is now baked into both the S3 bucket name and the SQS queue names, so `staging` and `production` resources are guaranteed not to collide even though they share the same `bucket_name`/`sqs_name` base values in their respective `.tfvars` files.
- Remember to run `floci stop` when you're done to free up the Docker containers it spun up.
