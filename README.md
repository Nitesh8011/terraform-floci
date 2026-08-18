# terraform-floci

Learning Terraform against a **local AWS emulator (Floci)** instead of a real AWS account — no cloud costs, no credentials, fully offline-friendly.

[Floci](https://floci.io/aws/) ([GitHub](https://github.com/floci-io/floci)) is a free, open-source local AWS emulator (a LocalStack-style alternative). It exposes AWS-compatible APIs on `http://localhost:4566`, so the AWS CLI, SDKs, and Terraform's `aws` provider can all talk to it as if it were real AWS — just point the endpoint at localhost and use dummy credentials.

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

If that lists your new bucket, Floci is up and answering AWS API calls correctly.

## 4. Point Terraform at Floci

Terraform's `aws` provider needs to be told to hit `localhost:4566` for every service instead of real AWS, and to skip credential/region validation since Floci accepts dummy values. A typical `provider.tf`:

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3     = "http://localhost:4566"
    lambda = "http://localhost:4566"
    ec2    = "http://localhost:4566"
    iam    = "http://localhost:4566"
    # add other services here as you use them
  }
}
```

### State storage: S3 only, no DynamoDB

As of Terraform 1.11+, the S3 backend supports **native state locking** via `use_lockfile` — it writes a `.tflock` file alongside the state object using S3 conditional writes, so a separate DynamoDB lock table is no longer needed:

```hcl
terraform {
  backend "s3" {
    bucket       = "my-floci-tf-state"
    key          = "terraform-floci/terraform.tfstate"
    region       = "us-east-1"
    endpoints    = { s3 = "http://localhost:4566" }
    use_lockfile = true

    # Floci-only overrides so the backend talks to localhost instead of real AWS
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
```

Create the bucket in Floci before running `terraform init` (the backend won't create it for you):

```bash
aws s3 mb s3://my-floci-tf-state
```

> Requires Terraform **1.11+**. `dynamodb_table` is deprecated for locking — drop it if you're migrating an existing config, then run `terraform init -reconfigure`.

Then the usual Terraform workflow works exactly like it would against real AWS:

```bash
terraform init
terraform plan
terraform apply
```

## 5. Useful Floci commands

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
