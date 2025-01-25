# %%
import logging
import os
from typing import Dict

import requests


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


budget_data = extract_budget_data()
