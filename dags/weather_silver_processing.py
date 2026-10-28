from datetime import datetime

from airflow import DAG
from airflow.models.param import Param
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator

from weather_silver.config import BQ_SCHEMA, DAG_DESCRIPTION, DAG_ID, GCP_CONN_ID
from weather_silver.func import resolve_source_prefix, write_silver_csv

with DAG(
    dag_id=DAG_ID,
    description=DAG_DESCRIPTION,
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 0},
    params={
        "source_path": Param(
            default=None,
            type=["null", "string"],
            description="GCS prefix to read. Empty processes the previous UTC hour.",
        ),
    },
    tags=["weather", "silver"],
) as dag:
    resolve_source_prefix_task = PythonOperator(
        task_id="resolve_source_prefix",
        python_callable=resolve_source_prefix,
    )
    write_silver_csv_task = PythonOperator(
        task_id="write_silver_csv",
        python_callable=write_silver_csv,
    )
    load_gold = GCSToBigQueryOperator(
        task_id="load_gold",
        bucket="{{ ti.xcom_pull(task_ids='write_silver_csv')['bucket'] }}",
        source_objects=["{{ ti.xcom_pull(task_ids='write_silver_csv')['object_name'] }}"],
        destination_project_dataset_table=(
            "{{ ti.xcom_pull(task_ids='write_silver_csv')['destination_table'] }}"
        ),
        source_format="CSV",
        skip_leading_rows=1,
        write_disposition="WRITE_APPEND",
        create_disposition="CREATE_NEVER",
        autodetect=False,
        schema_fields=BQ_SCHEMA,
        gcp_conn_id=GCP_CONN_ID,
    )

    resolve_source_prefix_task >> write_silver_csv_task >> load_gold
