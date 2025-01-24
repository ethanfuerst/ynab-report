import glob
import logging
import os

from utils.db_connection import DuckDBConnection
from utils.logging_config import setup_logging

setup_logging()


def create_data_warehouse() -> None:
    duckdb_con = DuckDBConnection(need_write_access=False)

    for sql_script in sorted(glob.glob('transform/*.sql')):
        with open(sql_script, 'r') as file:
            sql = file.read().replace('$bucket_name', os.getenv('BUCKET_NAME'))

        logging.info(f'Executing {sql_script}')
        duckdb_con.execute(sql)
        logging.info(f'Successfully executed {sql_script}')

    duckdb_con.close()
