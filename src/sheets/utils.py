import json
import logging
import time
from typing import Any, Callable, Dict, List, Union

import emoji
from gspread import Worksheet
from gspread.exceptions import APIError
from pandas import DataFrame

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


def load_json_config(file_path: str) -> Dict[str, Any]:
    with open(file_path, 'r') as file:
        config = json.load(file)
    return remove_comments(config)


def get_df_from_table(table: str, where_clause: str = '') -> DataFrame:
    if where_clause:
        where_clause = f'where {where_clause}'
    duckdb_con = DuckDBConnection()
    df = duckdb_con.df(f'select * from {table} {where_clause}')
    duckdb_con.close()
    return df.replace([float('inf'), float('-inf'), float('nan')], None)


def retry_gspread_operation(
    operation: Callable, max_retries: int = 5, base_delay: int = 2
) -> Any:
    """Retry a gspread operation with exponential backoff on 503 errors.
    Logs errors and returns None if all retries fail, allowing script to continue.
    """
    for attempt in range(max_retries):
        try:
            return operation()
        except APIError as e:
            if e.response.status_code == 503 and attempt < max_retries - 1:
                delay = base_delay * (2**attempt)
                logging.warning(
                    f'Google Sheets API 503 error (attempt {attempt + 1}/{max_retries}). '
                    f'Retrying in {delay} seconds...'
                )
                time.sleep(delay)
            else:
                logging.error(f'Google Sheets API operation failed: {e}')
                return None
        except Exception as e:
            logging.error(f'Google Sheets API operation failed: {e}')
            return None

    logging.error(f'Google Sheets API operation failed after {max_retries} retries')
    return None


def apply_format_dict(worksheet: Worksheet, format_dict: Dict[str, Any]) -> None:
    for format_location, format_rules in format_dict.items():
        result = retry_gspread_operation(
            lambda: worksheet.format(ranges=format_location, format=format_rules)
        )
        if result is not None:
            logging.info(f'Formatted {format_location} with {format_rules.keys()}')
        else:
            logging.warning(f'Skipped formatting {format_location} due to API errors')


def df_to_sheet(
    df: DataFrame,
    worksheet: Worksheet,
    location: str,
    format_dict: Dict[str, Any] = None,
) -> None:
    result = retry_gspread_operation(
        lambda: worksheet.update(
            range_name=location,
            values=[df.columns.values.tolist()] + df.values.tolist(),
        )
    )

    if result is not None:
        logging.info(
            f'Updated {location} with {df.shape[0]} rows and {df.shape[1]} columns'
        )
    else:
        logging.warning(f'Skipped updating {location} due to API errors')
        return  # Don't try to format if update failed

    if format_dict:
        apply_format_dict(worksheet, format_dict)


def clean_category_names(df: DataFrame) -> DataFrame:
    df['category_name'] = df['category_name'].apply(
        lambda x: emoji.replace_emoji(x, replace='').strip() if x else x
    )
    return df
