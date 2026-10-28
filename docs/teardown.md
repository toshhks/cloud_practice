# Teardown and billing

Do this after the evidence is saved. The bucket refuses to delete while it has objects (`force_destroy` is `false`). The gold table also refuses to delete (`deletion_protection` is `true`). Empty both before `terraform destroy`. Keep the local Terraform state until destroy finishes.

Stop new bronze writes, from the repository root:

```bash
gcloud scheduler jobs pause weather-dev-ingest --location=europe-west1
```

Delete the objects and turn off table protection. `weather-dev-YOUR_PROJECT_ID` is output `bucket_name`.

```bash
gcloud storage rm --recursive "gs://weather-dev-YOUR_PROJECT_ID/**"
bq update --table --deletion_protection=false YOUR_PROJECT_ID:weather_dev.realtime_gold
bq rm --force --table YOUR_PROJECT_ID:weather_dev.realtime_gold
```

Destroy the stack and remove the local login copy:

```bash
terraform -chdir=terraform destroy
rm -f .secrets/adc.json
docker compose down
```

In the Google Cloud console, unlink billing from the project or close the billing account. The Free Trial card stays chargeable until billing is disabled, even after the resources are gone.

There is no Airflow service account key to delete. The tomorrow.io key was only a secret version and disappears with the secret during destroy.
