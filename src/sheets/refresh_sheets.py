import json
import logging
import os
from datetime import datetime

import gspread_formatting as gsf
from dotenv import load_dotenv
from gspread import Worksheet, service_account_from_dict
from gspread.exceptions import WorksheetNotFound
from pandas import to_datetime

from src.sheets.utils import (
    apply_format_dict,
    df_to_sheet,
    get_df_from_table,
    load_json_config,
    retry_gspread_operation,
)
from src.utils.logging_config import setup_logging

setup_logging()
load_dotenv()

OVERVIEW_COLUMN_WIDTH_MAPPING = {
    'A': 21,
    'B': 60,
    'C': 85,
    'D': 82,
    'E': 82,
    'F': 100,
    'G': 85,
    'H': 110,
    'I': 110,
    'J': 100,
    'K': 100,
    'L': 80,
    'M': 100,
    'N': 120,
    'O': 120,
    'P': 85,
    'Q': 85,
    'R': 85,
    'S': 95,
    'T': 75,
    'U': 100,
    'V': 100,
    'W': 95,
    'X': 85,
    'Y': 80,
    'Z': 21,
}
OVERVIEW_COLUMN_TITLES = [
    'Pre-Tax Earnings',
    'Salary',
    'Bonus',
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
YEARLY_CATEGORIES_COLUMN_WIDTH_MAPPING = {
    'A': 21,
    'B': 185,
    'C': 90,
    'D': 21,
    'E': 190,
    'F': 175,
    'G': 85,
    'H': 21,
    'I': 210,
    'J': 180,
    'K': 85,
    'L': 21,
    'M': 230,
    'N': 85,
    'O': 85,
    'P': 21,
}

def refresh_sheet_tab(
    sh: Worksheet, title: str, sheet_height: int, cols: int
) -> Worksheet:
    logging.info(f'Refreshing {title}')
    try:
        sh.del_worksheet(sh.worksheet(title))
    except WorksheetNotFound:
        pass
    except Exception as e:
        logging.warning(f'Error deleting worksheet {title}: {e}')

    result = retry_gspread_operation(
        lambda: sh.add_worksheet(title=title, rows=sheet_height, cols=cols)
    )
    if result is None:
        logging.error(f'Failed to add worksheet {title}')
        raise Exception(f'Cannot continue without worksheet: {title}')

    worksheet = retry_gspread_operation(lambda: sh.worksheet(title))
    if worksheet is None:
        logging.error(f'Failed to access worksheet {title}')
        raise Exception(f'Cannot continue without worksheet: {title}')

    logging.info(f'{title} refreshed')
    return worksheet


def add_last_updated_cell(worksheet: Worksheet, cell: str = 'B1') -> None:
    retry_gspread_operation(
        lambda: worksheet.update_acell(
            cell, 'Last Updated: ' + datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')
        )
    )


def refresh_overview_dashboard(sh: Worksheet, grain: str) -> None:
    title = f'Overview - {grain.capitalize()}'
    logging.info(f'Updating {title}')

    column_label = grain.capitalize().replace('ly', '')

    df = get_df_from_table(f'dashboards.{grain}_level')

    df.columns = [column_label] + OVERVIEW_COLUMN_TITLES

    if grain == 'monthly':
        df[column_label] = to_datetime(df[column_label]).dt.strftime('%-m/%Y')

    sheet_height = len(df) + 3
    sheet_width = len(df.columns) + 2

    worksheet = refresh_sheet_tab(sh, title, sheet_height, sheet_width)

    format_dict = load_json_config(
        'src/sheets/assets/formatting_configs/overview_dashboard_format.json'
    )

    df_to_sheet(df, worksheet, 'B2', format_dict)

    retry_gspread_operation(lambda: worksheet.format('B2:Y2', format_dict['B2:Y2']))

    retry_gspread_operation(lambda: worksheet.columns_auto_resize(2, sheet_width))
    for column, width in OVERVIEW_COLUMN_WIDTH_MAPPING.items():
        gsf.set_column_width(worksheet, column, width)

    notes_dict = load_json_config(
        'src/sheets/assets/formatting_configs/overview_notes.json'
    )
    retry_gspread_operation(lambda: worksheet.insert_notes(notes_dict))

    add_last_updated_cell(worksheet)

    # Format the following with lines
    # B2 to Y(sheet height - 1) outer border
    # Format non-corner cells first, then corner cells with all borders

    # Left border: column B excluding corners (B3 to B{sheet_height-2})
    if sheet_height > 4:
        worksheet.format(f'B3:B{sheet_height - 2}', {
            'borders': {
                'left': {
                    'style': 'SOLID',
                },
            }
        })

    # Right border: column Y excluding corners (Y3 to Y{sheet_height-2})
    if sheet_height > 4:
        worksheet.format(f'Y3:Y{sheet_height - 2}', {
            'borders': {
                'right': {
                    'style': 'SOLID',
                },
            }
        })

    # Top border: row 2 excluding corners (C2 to X2)
    worksheet.format('C2:X2', {
        'borders': {
            'top': {
                'style': 'SOLID',
            },
            'bottom': {
                'style': 'SOLID',
            },
        }
    })

    # Bottom border: last row excluding corners (C{sheet_height-1} to X{sheet_height-1})
    worksheet.format(f'C{sheet_height - 1}:X{sheet_height - 1}', {
        'borders': {
            'bottom': {
                'style': 'SOLID',
            },
        }
    })

    # Corner cells with all borders combined
    # Top-left corner (B2): left + top
    worksheet.format('B2', {
        'borders': {
            'left': {
                'style': 'SOLID',
            },
            'top': {
                'style': 'SOLID',
            },
            'bottom': {
                'style': 'SOLID',
            },
        }
    })

    # Top-right corner (Y2): right + top
    worksheet.format('Y2', {
        'borders': {
            'right': {
                'style': 'SOLID',
            },
            'top': {
                'style': 'SOLID',
            },
            'bottom': {
                'style': 'SOLID',
            },
        }
    })

    # Bottom-left corner (B{sheet_height-1}): left + bottom
    worksheet.format(f'B{sheet_height - 1}', {
        'borders': {
            'left': {
                'style': 'SOLID',
            },
            'bottom': {
                'style': 'SOLID',
            },
        }
    })

    # Bottom-right corner (Y{sheet_height-1}): right + bottom
    worksheet.format(f'Y{sheet_height - 1}', {
        'borders': {
            'right': {
                'style': 'SOLID',
            },
            'bottom': {
                'style': 'SOLID',
            },
        }
    })
    # following columns row 3 to row (sheet height - 1) left border
    # C, D, F, K, L, P, T, W, X, Y
    columns_to_format = ['C', 'D', 'F', 'K', 'L', 'P', 'T', 'W', 'X', 'Y']

    def create_border_dict(sides):
        """Create a border format dictionary for the specified sides."""
        border_style = {'style': 'SOLID'}
        borders = {}
        for side in sides:
            borders[side] = border_style
        return {'borders': borders}

    # Format each column: middle rows, row 3, and row (sheet_height-1)
    for col in columns_to_format:
        is_column_y = (col == 'Y')

        # Middle rows (4 to sheet_height-2): left border (and right for column Y)
        if sheet_height > 5:
            sides = ['left', 'right'] if is_column_y else ['left']
            worksheet.format(f'{col}4:{col}{sheet_height - 2}', create_border_dict(sides))

        # Row 3: left + top borders (and right for column Y)
        sides = ['left', 'top', 'right'] if is_column_y else ['left', 'top']
        worksheet.format(f'{col}3', create_border_dict(sides))

        # Row (sheet_height-1): left + bottom borders (and right for column Y)
        sides = ['left', 'right', 'bottom'] if is_column_y else ['left', 'bottom']
        worksheet.format(f'{col}{sheet_height - 1}', create_border_dict(sides))

    logging.info(f'{title} updated')


def refresh_yearly_categories_dashboards(sh: Worksheet) -> None:
    years = sorted(get_df_from_table('dashboards.yearly_level')['budget_year'].values, reverse=True)

    notes_dict = load_json_config(
        'src/sheets/assets/formatting_configs/yearly_categories_notes.json'
    )

    logging.info(
        f'Updating yearly categories dashboards for years: {", ".join(map(str, years))}'
    )

    for year in years:
        logging.info(f'Updating {year} - Categories')
        title = f'{year} - Categories'
        worksheet = refresh_sheet_tab(sh, title, 34, 16)

        df_needs = get_df_from_table('dashboards.yearly_needs', f'budget_year = {year}')[['subcategory_group', 'category_name', 'spend']]
        df_needs.columns = ['Subcategory Group', 'Needs', 'Spend']
        df_to_sheet(df_needs, worksheet, 'E2')

        df_wants = get_df_from_table('dashboards.yearly_wants', f'budget_year = {year}')[['subcategory_group', 'category_name', 'spend']]
        df_wants.columns = ['Subcategory Group', 'Wants', 'Spend']
        df_to_sheet(df_wants, worksheet, 'I2')

        df_savings_emergency_investments = get_df_from_table('dashboards.yearly_other', f'budget_year = {year}')[['category_name', 'assigned', 'spend']]
        df_savings_emergency_investments.columns = ['Other', 'Assigned', 'Spend']
        df_to_sheet(df_savings_emergency_investments, worksheet, 'M2')

        df_other = get_df_from_table('dashboards.yearly_category_group', f'budget_year = {year}')[['category_group_name_mapping', 'assigned', 'spend']]
        df_other.columns = ['Category Group', 'Assigned', 'Spend']
        df_to_sheet(df_other, worksheet, 'M12')

        df_subcategory_groups = get_df_from_table('dashboards.yearly_subcategory_group', f'budget_year = {year}')[['subcategory_group', 'assigned', 'spend']]
        df_subcategory_groups.columns = ['Subcategory Group', 'Assigned',  'Spend']
        df_to_sheet(df_subcategory_groups, worksheet, 'M20')

        df_paycheck = get_df_from_table('dashboards.yearly_paychecks', f'budget_year = {year}')[['paycheck_column', 'paycheck_value']]
        df_paycheck.columns = ['Paycheck Value', 'Amount']
        df_to_sheet(df_paycheck, worksheet, 'B2')

        format_dict = load_json_config(
            'src/sheets/assets/formatting_configs/yearly_categories_dashboard_format.json'
        )
        apply_format_dict(worksheet, format_dict)

        for column, column_width in YEARLY_CATEGORIES_COLUMN_WIDTH_MAPPING.items():
            gsf.set_column_width(worksheet, column, column_width)

        retry_gspread_operation(lambda: worksheet.insert_notes(notes_dict))
        add_last_updated_cell(worksheet)
        logging.info(f'{year} - Categories updated')


def refresh_sheets() -> None:
    credentials_dict = json.loads(os.getenv('GSPREAD_CREDENTIALS').replace('\n', '\\n'))
    gc = service_account_from_dict(credentials_dict)
    sh = gc.open('Spending Dashboard')

    logging.info('Refreshing overview dashboards')
    try:
        refresh_overview_dashboard(sh, 'yearly')
    except Exception as e:
        logging.error(f'Failed to refresh yearly overview dashboard: {e}')

    try:
        refresh_overview_dashboard(sh, 'monthly')
    except Exception as e:
        logging.error(f'Failed to refresh monthly overview dashboard: {e}')

    logging.info('Refreshing yearly categories dashboards')
    try:
        refresh_yearly_categories_dashboards(sh)
    except Exception as e:
        logging.error(f'Failed to refresh yearly categories dashboards: {e}')
