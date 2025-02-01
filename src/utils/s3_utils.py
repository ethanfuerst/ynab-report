import logging

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

    s3_file = f's3://{bucket_name}/{s3_key}.parquet'

    duckdb_con.register('df', df)
    duckdb_con.execute('create or replace table all_data as select * from df')
    duckdb_con.execute(f'copy (select * from all_data) to "{s3_file}";')

    row_count_query = f'select count(*) from "{s3_file}";'
    rows_loaded = duckdb_con.sql(row_count_query).fetchnumpy()['count_star()'][0]

    logging.info(f'Updated {s3_file} with {rows_loaded} rows.')

    return rows_loaded
