import argparse
import logging
import os

import modal
from eftoolkit.utils import setup_logging

setup_logging()

DEPLOYMENT = {
    'app_name': 'fiscal-pipeline',
    'deployment_sha': os.getenv('FISCAL_DEPLOYMENT_SHA', 'local'),
    'deployment_target': os.getenv('FISCAL_DEPLOYMENT_TARGET', 'development'),
    'modal_environment': os.getenv('MODAL_ENVIRONMENT', 'main'),
    'schedules': {},
    'scheduler': 'railway',
    'image_builder_version': os.getenv('MODAL_IMAGE_BUILDER_VERSION', ''),
}
app = modal.App(DEPLOYMENT['app_name'])

modal_image = (
    modal.Image.debian_slim(python_version='3.10')
    .pip_install_from_pyproject('pyproject.toml')
    .env(
        {
            'FISCAL_DEPLOYMENT_SHA': DEPLOYMENT['deployment_sha'],
            'FISCAL_DEPLOYMENT_TARGET': DEPLOYMENT['deployment_target'],
            'MODAL_ENVIRONMENT': DEPLOYMENT['modal_environment'],
            'MODAL_IMAGE_BUILDER_VERSION': DEPLOYMENT['image_builder_version'],
        }
    )
    .add_local_dir(
        'src/warehouse/sqlmesh_project/',
        remote_path='/root/src/warehouse/sqlmesh_project/',
    )
    .add_local_python_source('src')
)


@app.function(image=modal_image, timeout=30)
def get_deployment_metadata():
    return DEPLOYMENT


@app.function(
    image=modal_image,
    timeout=300,
    max_containers=1,
    secrets=[modal.Secret.from_name('fiscal-pipeline-secrets')],
    retries=modal.Retries(
        max_retries=3,
        backoff_coefficient=1.0,
        initial_delay=60.0,
    ),
)
def update_google_sheet(
    sync_s3: bool = True,
    update_dashboards: bool = True,
    is_local_run: bool = False,
    env: str = 'prod',
):
    from src.etl.etl import etl_ynab_data
    from src.sheets.refresh_sheets import refresh_sheets
    from src.warehouse.create_warehouse import create_data_warehouse

    if sync_s3:
        logging.info('Running S3 sync.')
        etl_ynab_data()
        logging.info('S3 sync completed.')

    if update_dashboards:
        logging.info('Updating dashboards.')
        create_data_warehouse(is_local_run=is_local_run)
        refresh_sheets(env=env)
        logging.info('Dashboard update process completed.')

    if not is_local_run and sync_s3 and update_dashboards and env == 'prod':
        import requests

        healthcheck_url = os.getenv('FISCAL_COMPLETION_HEALTHCHECK_URL')
        if healthcheck_url:
            try:
                requests.get(healthcheck_url, timeout=10).raise_for_status()
            except requests.RequestException:
                logging.error('Completion health check failed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Run the ETL process with specific parameters.'
    )
    parser.add_argument(
        '--sync-s3',
        action='store_true',
        help='Run the S3 sync process.',
    )
    parser.add_argument(
        '--update-dashboards',
        action='store_true',
        help='Run the dashboard update process.',
    )
    parser.add_argument(
        '--env',
        choices=['dev', 'prod'],
        default='dev',
        help='Which Google Sheet/credentials to use. Defaults to dev for local runs.',
    )

    args = parser.parse_args()

    logging.info(f'Running fiscal_pipeline_app locally against {args.env} sheet')
    update_google_sheet.local(
        sync_s3=args.sync_s3,
        update_dashboards=args.update_dashboards,
        is_local_run=True,
        env=args.env,
    )
    logging.info('fiscal_pipeline_app completed')
