# Setup and Terraform apply

Create the accounts before the first apply. One Google Cloud project covers Storage, Secret Manager, BigQuery, Cloud Functions, Cloud Run, Cloud Build, Artifact Registry, and Cloud Scheduler. Those APIs are enabled by Terraform. tomorrow.io is a separate account: the function reads the latest secret version while it deploys, so the key has to exist before the full apply.

Do not commit the API key, `terraform/terraform.tfvars`, Terraform state, or `.secrets/`.

## Accounts

1. Open a Google Cloud Free Trial, create a project, and attach billing.
2. Create a tomorrow.io account and an API key. Leave the key in the tomorrow.io UI for the next step.

## Tools

Install the Google Cloud CLI and Terraform on Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl lsb-release

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update
sudo apt-get install -y google-cloud-cli terraform
```

Sign in and select the project:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Apply

From the repository root:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Set `project_id` in `terraform/terraform.tfvars`. Leave `force_destroy` as `false`.

Create only the secret, then store the tomorrow.io key, then apply the rest. `terraform apply` of the whole stack fails if the secret has no version.

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply -target=google_secret_manager_secret.tomorrow_api_key
```

```bash
read -rs TOMORROW_API_KEY
printf '%s' "$TOMORROW_API_KEY" \
  | gcloud secrets versions add weather-dev-tomorrow-api-key --data-file=- --project=YOUR_PROJECT_ID
unset TOMORROW_API_KEY
```

`weather-dev-tomorrow-api-key` matches `env = "dev"`. Then:

```bash
terraform -chdir=terraform apply
terraform -chdir=terraform output
```

Copy `GCP_PROJECT_ID` into `.env` (from `.env.example`) before starting Airflow. The DAG builds the bucket name as `weather-$WEATHER_ENV-$GCP_PROJECT_ID` when `WEATHER_BUCKET` is empty.
