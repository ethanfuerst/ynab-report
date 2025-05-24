import glob
import logging
import os
import shutil

from src.utils.db_connection import DuckDBConnection
from src.utils.logging_config import setup_logging

setup_logging()


def copy_duckdb_file() -> None:
    '''Need to do this so evidence can read the file'''
    source_path = 'ynab_report.duckdb'
    destination_path = 'dashboards/sources/ynab_report/ynab_report.duckdb'

    try:
        shutil.copy(source_path, destination_path)
        logging.info(f'Successfully copied {source_path} to {destination_path}')
    except Exception as e:
        logging.error(f'Failed to copy {source_path} to {destination_path}: {e}')


def create_data_warehouse(is_local_run: bool = True) -> None:
    duckdb_con = DuckDBConnection(need_write_access=False)

    for sql_script in sorted(glob.glob('src/warehouse/*.sql')):
        with open(sql_script, 'r') as file:
            sql = file.read().replace('$bucket_name', os.getenv('BUCKET_NAME'))

        logging.info(f'Executing {sql_script}')
        duckdb_con.execute(sql)
        logging.info(f'Successfully executed {sql_script}')

    duckdb_con.close()

    if is_local_run:
        copy_duckdb_file()
