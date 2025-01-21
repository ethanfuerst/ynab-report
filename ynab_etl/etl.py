import logging
import os
from datetime import datetime
from typing import Dict, List

import duckdb
import pandas as pd
import requests
from dotenv import load_dotenv

from utils.db_connection import DuckDBConnection
from utils.s3_utils import load_df_to_s3_table

load_dotenv()


def extract_budget_data() -> Dict:
    logging.info('Extracting budget data')

    budget_id = os.getenv('BUDGET_ID')
    url = f'https://api.ynab.com/v1/budgets/{budget_id}'

    bearer_token = os.getenv('BEARER_TOKEN')
    headers = {
        'Authorization': f'Bearer {bearer_token}',
    }

    response = requests.get(url, headers=headers)
    budget_data = response.json()['data']['budget']

    logging.info('Extracted budget data')

    return budget_data


def extract_category_groups(
    budget_data: Dict, duckdb_con: duckdb.DuckDBPyConnection
) -> None:
    category_groups = pd.DataFrame(budget_data['category_groups'])

    today = datetime.now()

    rows_loaded = load_df_to_s3_table(
        duckdb_con=duckdb_con,
        df=category_groups.reset_index(drop=True),
        s3_key=f'category-groups/year={today.year}/month={today.month}/data',
        bucket_name=os.getenv('BUCKET_NAME'),
    )

    logging.info(f'Loaded {rows_loaded} rows')


def extract_categories(
    budget_data: Dict, duckdb_con: duckdb.DuckDBPyConnection
) -> None:
    rows_loaded = 0

    for month in budget_data['months']:
        month_date = month['month']
        monthly_categories = pd.DataFrame(month['categories'])

        month_date = datetime.strptime(month_date, '%Y-%m-%d')

        rows_added = load_df_to_s3_table(
            duckdb_con=duckdb_con,
            df=monthly_categories.reset_index(drop=True),
            s3_key=f'monthly-categories/year={month_date.year}/month={month_date.month}/data',
            bucket_name=os.getenv('BUCKET_NAME'),
        )

        rows_loaded += rows_added

    logging.info(f'Loaded {rows_loaded} rows')


def extract_transactions(
    budget_data: Dict, duckdb_con: duckdb.DuckDBPyConnection
) -> None:
    transactions = pd.DataFrame(budget_data['transactions'])

    rows_loaded = 0

    transactions['date'] = pd.to_datetime(transactions['date'])
    transactions['year'] = transactions['date'].dt.year
    transactions['month'] = transactions['date'].dt.month

    for (year, month), group in transactions.groupby(['year', 'month']):
        rows_added = load_df_to_s3_table(
            duckdb_con=duckdb_con,
            df=group.drop(columns=['year', 'month']).reset_index(drop=True),
            s3_key=f'transactions/year={year}/month={month}/data',
            bucket_name=os.getenv('BUCKET_NAME'),
        )

        rows_loaded += rows_added

    logging.info(f'Loaded {rows_loaded} rows')


def extract_subtransactions(
    budget_data: Dict, duckdb_con: duckdb.DuckDBPyConnection
) -> None:
    subtransactions = pd.DataFrame(budget_data['subtransactions'])

    rows_loaded = load_df_to_s3_table(
        duckdb_con=duckdb_con,
        df=subtransactions,
        s3_key=f'subtransactions/all_data',
        bucket_name=os.getenv('BUCKET_NAME'),
    )

    logging.info(f'Loaded {rows_loaded} rows')


etl_functions = {
    'category-groups': extract_category_groups,
    'monthly-categories': extract_categories,
    'transactions': extract_transactions,
    'subtransactions': extract_subtransactions,
}


def etl_ynab_data():
    budget_data = extract_budget_data()

    duckdb_con = DuckDBConnection(need_write_access=True).get_connection()

    logging.info('Extracting data from endpoints')
    for endpoint, function in etl_functions.items():
        logging.info(f'Extracting {endpoint} data')
        function(budget_data, duckdb_con)
        logging.info(f'Extracted {endpoint} data')
