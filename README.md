# terraform-floci

Learning Terraform against a **local AWS emulator (Floci)** instead of a real AWS account — no cloud costs, no credentials, fully offline-friendly.

[Floci](https://floci.io/aws/) ([GitHub](https://github.com/floci-io/floci)) is a free, open-source local AWS emulator (a LocalStack-style alternative). It exposes AWS-compatible APIs on `http://localhost:4566`, so the AWS CLI, SDKs, and Terraform's `aws` provider can all talk to it as if it were real AWS — just point the endpoint at localhost and use dummy credentials.

## What's in this repo

| File | Purpose |
|---|---|
| [provider.tf](provider.tf) | `aws` provider (`~> 6.0`) pinned to the Floci endpoints for `s3` and `sts`, plus an `s3` backend block for remote state |
| [variables.tf](variables.tf) | Input variables: `region`, `bucket_name`, `dynamodb_table`, `dynamodb_billing_mode` |
| [s3.tf](s3.tf) | An `aws_s3_bucket` (named from `var.bucket_name` + account id + region) with versioning enabled |
| [dynamodb.tf](dynamodb.tf) | One `aws_dynamodb_table` per entry in `var.table_names`, each with a single string hash key (`id`) |
| [output.tf](output.tf) | Outputs the S3 bucket's ARN/domain name/region and the list of DynamoDB table names |
| [run.sh](run.sh) | Convenience script that runs `terraform fmt`, `validate`, `plan`, and `apply` in sequence |
| [production/production.tfvars](production/production.tfvars) | Var overrides for the `production` workspace (e.g. `dynamodb_billing_mode = "PROVISIONED"`) |
| [staging/staging.tfvars](staging/staging.tfvars) | Var overrides for the `staging` workspace (e.g. `dynamodb_billing_mode = "PAY_PER_REQUEST"`) |

State is stored remotely in an S3 bucket (`floci-tf-state-bucket`, in Floci) via the `backend "s3"` block in [provider.tf](provider.tf), using native S3 state locking (`use_lockfile = true`) instead of a DynamoDB lock table. Use `terraform workspace` (`staging`/`production`) with the matching `.tfvars` file to keep environments separate — each workspace gets its own state within that same bucket.

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

> Add more entries to the `endpoints` block (`lambda`, `ec2`, `iam`, `dynamodb`, ...) if you extend this config to use other services — the `aws_dynamodb_table` in [dynamodb.tf](dynamodb.tf) currently relies on the provider's default (real AWS) DynamoDB endpoint unless Floci intercepts it automatically for you.

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

## 5. Run it

Override the defaults in [variables.tf](variables.tf) (`region`, `bucket_name`, `dynamodb_table`, `dynamodb_billing_mode`, `table_names`) with `-var` flags or one of the provided `.tfvars` files.

```bash
terraform init
terraform plan -var-file=staging/staging.tfvars
terraform apply -var-file=staging/staging.tfvars
```

Swap in `production/production.tfvars` to target the production var set instead.

Or run the default (no `-var-file`) plan/apply via the included script:

```bash
./run.sh
```

On success you'll get the outputs defined in [output.tf](output.tf): the S3 bucket's ARN/domain name/region, and the list of DynamoDB table names.

## 6. Verify resources with the AWS CLI

Once `terraform apply` finishes, point the AWS CLI at the same region you deployed to (`-var-file`'s `region`, e.g. `us-east-2` for staging) and check what actually got created:

```bash
# List all DynamoDB tables in the region
aws dynamodb list-tables --region us-east-2

# Inspect a specific table's attributes/key schema/billing mode
aws dynamodb describe-table --table-name staging-table-1 --region us-east-2

# List all S3 buckets
aws s3 ls

# Check which region a bucket lives in
aws s3api get-bucket-location --bucket <bucket_name>
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
- Not every AWS API has 100% parity (complex services like DynamoDB have known gaps) — treat this as a fast local feedback loop for learning/testing Terraform, not a guarantee of production behavior.
- Remember to run `floci stop` when you're done to free up the Docker containers it spun up.
