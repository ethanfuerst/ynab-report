import json
import logging
import os

import gspread_formatting as gsf
from dotenv import load_dotenv
from gspread import Worksheet, service_account_from_dict
from gspread.exceptions import WorksheetNotFound
from pandas import to_datetime

from src.sheets.utils import *
from src.utils.logging_config import setup_logging

setup_logging()
load_dotenv()

OVERVIEW_COLUMN_WIDTH_MAPPING = {
    'A': 21,
    'B': 60,
    'C': 85,
    'D': 100,
    'E': 85,
    'F': 110,
    'G': 110,
    'H': 100,
    'I': 100,
    'J': 80,
    'K': 100,
    'L': 120,
    'M': 120,
    'N': 85,
    'O': 85,
    'P': 85,
    'Q': 95,
    'R': 75,
    'S': 100,
    'T': 100,
    'U': 95,
    'V': 85,
    'W': 80,
    'X': 21,
}
OVERVIEW_COLUMN_TITLES = [
    'Pre-Tax Earnings',
    'Pre-Tax Deductions',
    'Taxes',
    'Retirement Fund Contribution',
    'HSA Contribution',
    'Post-Tax Deductions',
    'Total Deductions',
    'Net Pay',
    'Reimbursed Income',
    'Miscellaneous Income',
    'Total Income (Net to Account)',
    'Needs Spend',
    'Wants Spend',
    'Savings Spend',
    'Emergency Fund Spend',
    'Savings Saved',
    'Emergency Fund Saved',
    'Investments Saved',
    'Emergency Fund in HSA',
    'Total Spend',
    'Net Income',
]
CATEGORY_DETAIL_COLUMNS = ['Category', 'Assigned', 'Spend']
YEARLY_CATEGORIES_COLUMN_WIDTH_MAPPING = {
    'A': 21,
    'B': 125,
    'C': 80,
    'D': 80,
    'E': 21,
    'F': 190,
    'G': 85,
    'H': 85,
    'I': 21,
    'J': 150,
    'K': 85,
    'L': 85,
    'M': 21,
    'N': 202,
    'O': 85,
    'P': 85,
    'Q': 21,
}


def refresh_sheet_tab(
    sh: Worksheet, title: str, sheet_height: int, cols: int
) -> Worksheet:
    logging.info(f'Refreshing {title}')
    try:
        sh.del_worksheet(sh.worksheet(title))
    except WorksheetNotFound:
        pass
    sh.add_worksheet(title=title, rows=sheet_height, cols=cols)
    worksheet = sh.worksheet(title)
    logging.info(f'{title} refreshed')
    return worksheet


def refresh_overview_dashboard(sh: Worksheet, grain: str) -> None:
    title = f'Overview - {grain.capitalize()}'
    logging.info(f'Updating {title}')

    column_label = grain.capitalize().replace('ly', '')

    df = get_df_from_table(f'{grain}_level_dashboard')

    df.columns = [column_label] + OVERVIEW_COLUMN_TITLES

    df[column_label] = to_datetime(df[column_label]).dt.strftime(
        '%-m/%Y' if grain == 'monthly' else '%Y'
    )

    sheet_height = len(df) + 3

    worksheet = refresh_sheet_tab(sh, title, sheet_height, 24)

    format_dict = load_format_config(
        'src/sheets/assets/formatting_configs/overview_dashboard_format.json'
    )

    df_to_sheet(df, worksheet, 'B2', format_dict)

    worksheet.format('B2:W2', format_dict['B2:W2'])

    worksheet.columns_auto_resize(2, 23)
    for column, width in OVERVIEW_COLUMN_WIDTH_MAPPING.items():
        gsf.set_column_width(worksheet, column, width)
    logging.info(f'{title} updated')


def refresh_yearly_categories_dashboards(sh: Worksheet) -> None:
    df = get_df_from_table('yearly_category_level_dashboard')
    years = sorted(to_datetime(df['budget_year']).dt.year.unique(), reverse=True)
    sheet_height = int(df.groupby(['category_group', 'budget_year']).size().max()) + 3

    df = clean_category_names(df)
    with open('src/sheets/assets/column_ordering/column_orders.json', 'r') as f:
        column_orders = json.load(f)

    logging.info(
        f'Updating yearly categories dashboards for years: {", ".join(map(str, years))}'
    )

    for year in years:
        logging.info(f'Updating {year} - Categories')

        df_year = df[df['budget_year'].dt.year == year]
        title = f'{year} - Categories'

        df_year.columns = ['Category', 'Category Group', 'Year', 'Spend', 'Assigned']

        df_needs = df_year[df_year['Category Group'] == 'Needs'][
            CATEGORY_DETAIL_COLUMNS
        ]
        df_wants = df_year[df_year['Category Group'] == 'Wants'][
            CATEGORY_DETAIL_COLUMNS
        ]
        df_savings_emergency_investments = df_year[
            df_year['Category Group'].isin(['Savings', 'Emergency Fund', 'Investments'])
        ][CATEGORY_DETAIL_COLUMNS]

        worksheet = refresh_sheet_tab(sh, title, sheet_height, 17)

        df_needs = sort_columns(df_needs, 'Category', column_orders['needs'])
        df_wants = sort_columns(df_wants, 'Category', column_orders['wants'])
        df_savings_emergency_investments = sort_columns(
            df_savings_emergency_investments, 'Category', column_orders['other']
        )

        df_needs.columns = ['Needs', 'Assigned', 'Spend']
        df_to_sheet(df_needs, worksheet, 'F2')

        df_wants.columns = ['Wants', 'Assigned', 'Spend']
        df_to_sheet(df_wants, worksheet, 'J2')

        df_savings_emergency_investments.columns = ['Other', 'Assigned', 'Spend']
        df_to_sheet(df_savings_emergency_investments, worksheet, 'N2')

        df_category_groups = (
            df_year.groupby('Category Group')[['Assigned', 'Spend']].sum().reset_index()
        )

        df_income = df_category_groups[
            df_category_groups['Category Group'] == 'Income'
        ][['Category Group', 'Spend']]
        df_other = df_category_groups[
            ~df_category_groups['Category Group'].isin(
                ['Income', 'Credit Card Payments']
            )
        ]

        df_income.columns = ['', '']
        df_to_sheet(df_income, worksheet, 'B1')

        df_other = sort_columns(
            df_other, 'Category Group', column_orders['category_groups']
        )
        df_other.columns = ['', 'Assigned', 'Spend']
        df_to_sheet(df_other, worksheet, 'B4')

        format_dict = load_format_config(
            'src/sheets/assets/formatting_configs/yearly_categories_dashboard_format.json'
        )
        apply_format_dict(worksheet, format_dict)

        for column, column_width in YEARLY_CATEGORIES_COLUMN_WIDTH_MAPPING.items():
            gsf.set_column_width(worksheet, column, column_width)

        logging.info(f'{year} - Categories updated')


def refresh_sheets() -> None:
    credentials_dict = json.loads(os.getenv('GSPREAD_CREDENTIALS').replace('\n', '\\n'))
    gc = service_account_from_dict(credentials_dict)
    sh = gc.open('Spending Dashboard')

    logging.info('Refreshing overview dashboards')
    refresh_overview_dashboard(sh, 'yearly')
    refresh_overview_dashboard(sh, 'monthly')
    logging.info('Refreshing yearly categories dashboards')
    refresh_yearly_categories_dashboards(sh)
