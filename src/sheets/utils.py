import emoji
from pandas import DataFrame

from src.utils.db_connection import DuckDBConnection
from src.utils.logging_config import setup_logging

setup_logging()


def get_df_from_table(table: str, where_clause: str = '') -> DataFrame:
    if where_clause:
        where_clause = f'where {where_clause}'
    duckdb_con = DuckDBConnection()
    df = duckdb_con.df(f'select * from {table} {where_clause}')
    duckdb_con.close()
    return df.replace([float('inf'), float('-inf'), float('nan')], None)


def clean_category_names(df: DataFrame) -> DataFrame:
    df['category_name'] = df['category_name'].apply(
        lambda x: emoji.replace_emoji(x, replace='').strip() if x else x
    )
    return df
