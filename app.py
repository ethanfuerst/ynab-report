import argparse
import logging
from typing import List

import modal
from modal.runner import deploy_app

from utils.logging_config import setup_logging
from ynab_etl.etl import etl_ynab_data

setup_logging()

app = modal.App('ynab-report')

modal_image = modal.Image.debian_slim(python_version='3.10').poetry_install_from_file(
    poetry_pyproject_toml='pyproject.toml'
)


@app.function(
    image=modal_image,
    schedule=modal.Cron('0 4 * * *'),
    secrets=[modal.Secret.from_name('ynab-report-secrets')],
    retries=modal.Retries(
        max_retries=3,
        backoff_coefficient=1.0,
        initial_delay=60.0,
    ),
)
def s3_sync():
    etl_ynab_data()


@app.function(
    image=modal_image,
    schedule=modal.Cron('0 5 * * *'),
    secrets=[modal.Secret.from_name('ynab-report-secrets')],
    retries=modal.Retries(
        max_retries=3,
        backoff_coefficient=1.0,
        initial_delay=60.0,
    ),
)
def update_dashboards():
    return


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

    args = parser.parse_args()

    sync_s3 = args.sync_s3
    update_dashboards = args.update_dashboards

    if sync_s3:
        logging.info('Running S3 sync locally.')
        s3_sync.local()
        logging.info('S3 sync completed.')

    if update_dashboards:
        logging.info('Updating dashboards locally.')
        update_dashboards.local()
        logging.info('Dashboard update process completed.')
