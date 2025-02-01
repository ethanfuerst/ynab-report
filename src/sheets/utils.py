import json
import logging
from typing import Any, Dict, List, Union

import emoji
from gspread import Worksheet
from pandas import Categorical, DataFrame

from src.utils.db_connection import DuckDBConnection
from src.utils.logging_config import setup_logging

setup_logging()


def remove_comments(obj: Union[Dict, List]) -> Union[Dict, List]:
    if isinstance(obj, dict):
        return {
            k: remove_comments(v)
            for k, v in obj.items()
            if not k.startswith('_comment')
        }
    elif isinstance(obj, list):
        return [remove_comments(item) for item in obj]
    else:
        return obj


def load_format_config(file_path: str) -> Dict[str, Any]:
    with open(file_path, 'r') as file:
        config = json.load(file)
    return remove_comments(config)


def get_df_from_table(table: str) -> DataFrame:
    duckdb_con = DuckDBConnection()
    df = duckdb_con.df(f'select * from {table}')
    duckdb_con.close()
    return df.replace([float('inf'), float('-inf'), float('nan')], None)


def apply_format_dict(worksheet: Worksheet, format_dict: Dict[str, Any]) -> None:
    for format_location, format_rules in format_dict.items():
        worksheet.format(ranges=format_location, format=format_rules)

        logging.info(f'Formatted {format_location} with {format_rules.keys()}')


def df_to_sheet(
    df: DataFrame,
    worksheet: Worksheet,
    location: str,
    format_dict: Dict[str, Any] = None,
) -> None:
    worksheet.update(
        range_name=location, values=[df.columns.values.tolist()] + df.values.tolist()
    )

    logging.info(
        f'Updated {location} with {df.shape[0]} rows and {df.shape[1]} columns'
    )

    if format_dict:
        apply_format_dict(worksheet, format_dict)


def clean_category_names(df: DataFrame) -> DataFrame:
    df['category_name'] = df['category_name'].apply(
        lambda x: emoji.replace_emoji(x, replace='').strip() if x else x
    )
    return df


def sort_columns(
    df: DataFrame, column_name: str, column_orders: List[str]
) -> DataFrame:
    df = df.copy()

    vals_missing_from_order = list(set(df[column_name].values) - set(column_orders))
    if vals_missing_from_order:
        print(
            f"Warning: {', '.join(vals_missing_from_order)} not found in column_orders for {column_name}"
        )

    df[column_name] = Categorical(
        df[column_name], categories=column_orders, ordered=True
    )
    return df.sort_values(column_name)
