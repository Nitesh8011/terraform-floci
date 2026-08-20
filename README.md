# terraform-floci

Learning Terraform against a **local AWS emulator (Floci)** instead of a real AWS account — no cloud costs, no credentials, fully offline-friendly.

[Floci](https://floci.io/aws/) ([GitHub](https://github.com/floci-io/floci)) is a free, open-source local AWS emulator (a LocalStack-style alternative). It exposes AWS-compatible APIs on `http://localhost:4566`, so the AWS CLI, SDKs, and Terraform's `aws` provider can all talk to it as if it were real AWS — just point the endpoint at localhost and use dummy credentials.

## What's in this repo

| File | Purpose |
|---|---|
| [provider.tf](provider.tf) | `aws` provider (`~> 6.0`) pinned to the Floci endpoints for `s3` and `sts`, plus an `s3` backend block for remote state |
| [backend.tf](backend.tf) | Root module: looks up the current account id and calls the `s3_bucket` module to create the (versioned) bucket |
| [variables.tf](variables.tf) | Root input variables: `region`, `bucket_name` |
| [modules/s3_bucket/](modules/s3_bucket/) | Reusable module: `main.tf` (bucket + versioning), `variable.tf` (`bucket_name`, `region`, `version_status`), `output.tf` (`arn`) |
| [run.sh](run.sh) | Convenience script that runs `terraform fmt`, `validate`, `plan`, and `apply` in sequence |
| [production/production.tfvars](production/production.tfvars) | Var overrides for the `production` workspace |
| [staging/staging.tfvars](staging/staging.tfvars) | Var overrides for the `staging` workspace |
| [01_old-terra-files/](01_old-terra-files/) | Pre-module flat config (`s3.tf`, `dynamodb.tf`, `output.tf`, `variables.tf`) kept for reference; excluded from `terraform` via [.terraformignore](.terraformignore) |

State is stored remotely in an S3 bucket (`floci-tf-state-bucket`, in Floci) via the `backend "s3"` block in [provider.tf](provider.tf), using native S3 state locking (`use_lockfile = true`) instead of a DynamoDB lock table. Use `terraform workspace` (`staging`/`production`) with the matching `.tfvars` file to keep environments separate — each workspace gets its own state within that same bucket.

### The `s3_bucket` module

The root config no longer creates the S3 bucket directly — [backend.tf](backend.tf) delegates to [modules/s3_bucket](modules/s3_bucket/):

```hcl
data "aws_caller_identity" "current" {}

module "module_bucket_config" {
  source         = "./modules/s3_bucket"
  bucket_name    = format("%s-%s-%s-an", var.bucket_name, data.aws_caller_identity.current.account_id, var.region)
  region         = var.region
  version_status = "Enabled"
}
```

The module itself (`modules/s3_bucket/main.tf`) creates the `aws_s3_bucket` and an `aws_s3_bucket_versioning` resource set to `var.version_status`, and exposes the bucket's `arn` as a module output. This makes the bucket reusable — e.g. calling the module a second time with different `bucket_name`/`region` inputs to stand up another bucket, without duplicating the versioning boilerplate.

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

Terraform's `aws` provider needs to be told to hit `localhost:4566` instead of real AWS, and to skip credential/region validation since Floci accepts dummy values. This repo's [provider.tf](provider.tf) does exactly that for the services it uses (`s3`, `sts`):

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
  }
}
```

> Add more entries to the `endpoints` block (`lambda`, `ec2`, `iam`, `dynamodb`, ...) if you extend this config to use other services. The archived [01_old-terra-files/dynamodb.tf](01_old-terra-files/dynamodb.tf) is a reference for a DynamoDB table resource, but it's not wired into the current root module.

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

Override the defaults in [variables.tf](variables.tf) (`region`, `bucket_name`) with `-var` flags or one of the provided `.tfvars` files.

```bash
terraform init
terraform plan -var-file=staging/staging.tfvars
terraform apply -var-file=staging/staging.tfvars
```

Swap in `production/production.tfvars` to target the production var set instead.

> The `.tfvars` files still carry `dynamodb_table` / `dynamodb_billing_mode` / `table_names` entries left over from before the module refactor — Terraform will just warn about undeclared variables for those since the root module (`variables.tf`) only declares `region` and `bucket_name` now. Safe to ignore, or trim those lines if they bother you.

Or run the default (no `-var-file`) plan/apply via the included script:

```bash
./run.sh
```

On success you'll get the `arn` output from the `module_bucket_config` module (the S3 bucket's ARN).

## 6. Verify resources with the AWS CLI

Once `terraform apply` finishes, point the AWS CLI at the same region you deployed to (`-var-file`'s `region`, e.g. `us-east-2` for staging) and check what actually got created:

```bash
# List all S3 buckets
aws s3 ls

# Check which region a bucket lives in
aws s3api get-bucket-location --bucket <bucket_name>

# Confirm versioning is enabled
aws s3api get-bucket-versioning --bucket <bucket_name>
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
- Not every AWS API has 100% parity (complex services like DynamoDB, referenced in [01_old-terra-files/](01_old-terra-files/), have known gaps) — treat this as a fast local feedback loop for learning/testing Terraform, not a guarantee of production behavior.
- Remember to run `floci stop` when you're done to free up the Docker containers it spun up.
