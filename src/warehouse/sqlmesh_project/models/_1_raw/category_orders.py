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
        'id': 'int',
        'category_group': 'text',
        'subcategory_group': 'text',
        'category_name': 'text',
    },
    column_descriptions={
        'id': 'Row Id',
        'category_group': 'Category Group',
        'subcategory_group': 'Subcategory Group',
        'category_name': 'Category Name',
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
    df.insert(0, 'id', range(1, len(df) + 1))

    return df
