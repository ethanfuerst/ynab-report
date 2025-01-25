import logging
import os

import duckdb
from pandas import DataFrame

from src.utils.logging_config import setup_logging

setup_logging()


def load_df_to_s3_table(
    duckdb_con: duckdb.DuckDBPyConnection,
    df: DataFrame,
    s3_key: str,
    bucket_name: str,
) -> int:
    logging.info(f'Loading {s3_key} to {bucket_name}')

    file_name = f'{s3_key}.json'.replace('/', '_')
    s3_file = f's3://{bucket_name}/{s3_key}.parquet'

    with open(file_name, 'w') as file:
        df.to_json(file, orient='records')

    duckdb_con.execute(
        f'copy (select * from read_json_auto("{file_name}")) to "{s3_file}";'
    )

    row_count_query = f'select count(*) from "{s3_file}";'
    rows_loaded = duckdb_con.sql(row_count_query).fetchnumpy()["count_star()"][0]

    logging.info(f'Updated {s3_file} with {rows_loaded} rows.')

    os.remove(file_name)

    return rows_loaded
