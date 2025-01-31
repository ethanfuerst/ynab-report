import argparse
import logging
from typing import List

import modal
from modal.runner import deploy_app

from src.etl.etl import etl_ynab_data
from src.sheets.refresh_sheets import refresh_sheets
from src.utils.logging_config import setup_logging
from src.warehouse.create_warehouse import create_data_warehouse

setup_logging()

app = modal.App('ynab-report')

modal_image = (
    modal.Image.debian_slim(python_version='3.10')
    .poetry_install_from_file(poetry_pyproject_toml='pyproject.toml')
    .add_local_dir(
        'src/sheets/assets/formatting_configs/',
        remote_path='/app/src/sheets/assets/formatting_configs/',
    )
    .add_local_dir(
        'src/sheets/assets/column_ordering/',
        remote_path='/app/src/sheets/assets/column_ordering/',
    )
)


@app.function(
    image=modal_image,
    schedule=modal.Cron('5 8 * * *'),
    secrets=[modal.Secret.from_name('ynab-report-secrets')],
    retries=modal.Retries(
        max_retries=3,
        backoff_coefficient=1.0,
        initial_delay=60.0,
    ),
)
def ynab_report_app(sync_s3: bool = True, update_dashboards: bool = True):
    if sync_s3:
        logging.info('Running S3 sync.')
        etl_ynab_data()
        logging.info('S3 sync completed.')

    if update_dashboards:
        logging.info('Updating dashboards.')
        create_data_warehouse()
        refresh_sheets()
        logging.info('Dashboard update process completed.')


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

    logging.info('Running ynab_report_app locally')
    ynab_report_app.local(sync_s3=sync_s3, update_dashboards=update_dashboards)
    logging.info('ynab_report_app completed')
