import json
import os
import typing as t
from datetime import datetime

import pandas as pd
from gspread import service_account_from_dict
from pandas import DataFrame
from sqlmesh import ExecutionContext, model


@model(
    'raw.category_orders',
    columns={
        'needs': 'text',
        'wants': 'text',
        'other': 'text',
        'category_groups': 'text',
        'paycheck': 'text',
    },
    column_descriptions={
        'needs': 'List of needs categories',
        'wants': 'List of wants categories',
        'other': 'List of other categories',
        'category_groups': 'List of category groups',
        'paycheck': 'List of paycheck categories',
    },
)
def execute(
    context: ExecutionContext,
    start: datetime,
    end: datetime,
    execution_time: datetime,
    **kwargs: t.Any,
) -> pd.DataFrame:
    credentials_dict = json.loads(os.getenv('GSPREAD_CREDENTIALS').replace('\n', '\\n'))
    gc = service_account_from_dict(credentials_dict)
    sh = gc.open(context.var('sheet_name')).worksheet('Category Orders')

    raw = sh.get_all_values()
    df = DataFrame(data=raw[1:], columns=raw[0]).astype(str)

    return df
