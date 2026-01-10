"""
Batch operations module for Google Sheets.

Queues and executes Google Sheets operations in batches to reduce API calls.
"""

import logging
import random
import time
from typing import Any, Callable, Dict, List, Union

from gspread import Spreadsheet, Worksheet
from gspread.exceptions import APIError
from gspread.utils import a1_range_to_grid_range, column_letter_to_index

from src.utils.logging_config import setup_logging

setup_logging()


class SheetBatcher:
    """Batch Google Sheets operations for efficient API usage."""

    MAX_REQUESTS_PER_BATCH = 100
    MAX_VALUE_RANGES_PER_BATCH = 100

    def __init__(
        self,
        spreadsheet: Spreadsheet,
        max_retries: int = 5,
        base_delay: float = 2.0,
    ):
        """Initialize batcher with a spreadsheet and retry configuration."""
        self._spreadsheet = spreadsheet
        self._max_retries = max_retries
        self._base_delay = base_delay
        self._value_updates: List[Dict[str, Any]] = []
        self._batch_requests: List[Dict[str, Any]] = []
        self._worksheet_cache: Dict[str, int] = {}

    def __enter__(self) -> 'SheetBatcher':
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        if exc_type is None:
            self.flush()

    @property
    def spreadsheet(self) -> Spreadsheet:
        return self._spreadsheet

    def get_worksheet_id(self, worksheet: Union[Worksheet, str, int]) -> int:
        """Get the worksheet ID (sheetId) for a worksheet."""
        if isinstance(worksheet, int):
            return worksheet
        if isinstance(worksheet, Worksheet):
            return worksheet.id
        if worksheet not in self._worksheet_cache:
            self._worksheet_cache[worksheet] = self._spreadsheet.worksheet(worksheet).id
        return self._worksheet_cache[worksheet]

    def register_worksheet(self, worksheet: Worksheet) -> None:
        """Register a worksheet in the cache to avoid extra API lookups."""
        self._worksheet_cache[worksheet.title] = worksheet.id

    def queue_values(
        self,
        range_name: str,
        values: Union[List[List[Any]], Callable[[], List[List[Any]]]],
    ) -> None:
        """Queue a value update."""
        self._value_updates.append({'range': range_name, 'values': values})

    def queue_format(
        self,
        range_name: str,
        format_dict: Dict[str, Any],
        worksheet: Union[Worksheet, str, int],
    ) -> None:
        """Queue a cell formatting operation."""
        grid_range = a1_range_to_grid_range(range_name)
        grid_range['sheetId'] = self.get_worksheet_id(worksheet)

        self._batch_requests.append(
            {
                'repeatCell': {
                    'range': grid_range,
                    'cell': {
                        'userEnteredFormat': self._convert_format_dict(format_dict)
                    },
                    'fields': self._get_format_fields(format_dict),
                }
            }
        )

    def queue_border(
        self,
        range_name: str,
        borders: Dict[str, Any],
        worksheet: Union[Worksheet, str, int],
    ) -> None:
        """Queue a border formatting operation."""
        grid_range = a1_range_to_grid_range(range_name)
        grid_range['sheetId'] = self.get_worksheet_id(worksheet)

        request = {'updateBorders': {'range': grid_range}}
        for side in ('top', 'bottom', 'left', 'right'):
            if side in borders:
                spec = borders[side]
                request['updateBorders'][side] = {
                    'style': spec.get('style', 'SOLID'),
                    'color': spec.get('color', {'red': 0, 'green': 0, 'blue': 0}),
                }
        self._batch_requests.append(request)

    def queue_column_width(
        self,
        column: Union[str, int],
        width: int,
        worksheet: Union[Worksheet, str, int],
    ) -> None:
        """Queue a column width update."""
        # column_letter_to_index returns 1-based, but Sheets API expects 0-based
        col_index = (
            column_letter_to_index(column) - 1 if isinstance(column, str) else column
        )
        self._batch_requests.append(
            {
                'updateDimensionProperties': {
                    'range': {
                        'sheetId': self.get_worksheet_id(worksheet),
                        'dimension': 'COLUMNS',
                        'startIndex': col_index,
                        'endIndex': col_index + 1,
                    },
                    'properties': {'pixelSize': width},
                    'fields': 'pixelSize',
                }
            }
        )

    def queue_columns_auto_resize(
        self,
        start_col: int,
        end_col: int,
        worksheet: Union[Worksheet, str, int],
    ) -> None:
        """Queue auto-resize for columns. Indices are 1-based."""
        self._batch_requests.append(
            {
                'autoResizeDimensions': {
                    'dimensions': {
                        'sheetId': self.get_worksheet_id(worksheet),
                        'dimension': 'COLUMNS',
                        'startIndex': start_col - 1,
                        'endIndex': end_col - 1,
                    },
                }
            }
        )

    def queue_notes(
        self,
        notes_dict: Dict[str, str],
        worksheet: Union[Worksheet, str, int],
    ) -> None:
        """Queue cell notes."""
        worksheet_id = self.get_worksheet_id(worksheet)
        for cell_ref, note_text in notes_dict.items():
            grid_range = a1_range_to_grid_range(cell_ref)
            grid_range['sheetId'] = worksheet_id
            self._batch_requests.append(
                {
                    'updateCells': {
                        'range': grid_range,
                        'rows': [{'values': [{'note': note_text}]}],
                        'fields': 'note',
                    }
                }
            )

    def flush(self) -> None:
        """Execute all queued operations."""
        logging.info(
            f'Flushing batch: {len(self._value_updates)} value updates, '
            f'{len(self._batch_requests)} batch requests'
        )

        if self._value_updates:
            self._flush_value_updates()
        if self._batch_requests:
            self._flush_batch_requests()

    def _flush_value_updates(self) -> None:
        """Send queued value updates to the Sheets API in batches."""
        data = []
        for update in self._value_updates:
            values = update['values']
            if callable(values):
                values = values()
            data.append({'range': update['range'], 'values': values})

        for i in range(0, len(data), self.MAX_VALUE_RANGES_PER_BATCH):
            chunk = data[i : i + self.MAX_VALUE_RANGES_PER_BATCH]
            self._execute_with_retry(
                lambda b={'valueInputOption': 'USER_ENTERED', 'data': chunk}: (
                    self._spreadsheet.values_batch_update(b)
                ),
                f'values_batch_update ({len(chunk)} ranges)',
            )
        self._value_updates.clear()

    def _flush_batch_requests(self) -> None:
        """Send queued batch requests (formats, borders, etc.) to the Sheets API."""
        for i in range(0, len(self._batch_requests), self.MAX_REQUESTS_PER_BATCH):
            chunk = self._batch_requests[i : i + self.MAX_REQUESTS_PER_BATCH]
            self._execute_with_retry(
                lambda b={'requests': chunk}: self._spreadsheet.batch_update(b),
                f'batch_update ({len(chunk)} requests)',
            )
        self._batch_requests.clear()

    def _execute_with_retry(self, operation: Callable, description: str) -> Any:
        """Execute operation with exponential backoff retry on transient errors."""
        for attempt in range(self._max_retries):
            try:
                return operation()
            except APIError as e:
                status = e.response.status_code
                if (
                    status in (429, 500, 502, 503, 504)
                    and attempt < self._max_retries - 1
                ):
                    delay = self._base_delay * (2**attempt) + random.uniform(0, 1)
                    logging.warning(
                        f'API error {status} on {description} '
                        f'(attempt {attempt + 1}/{self._max_retries}). '
                        f'Retrying in {delay:.1f}s...'
                    )
                    time.sleep(delay)
                else:
                    logging.error(f'API error on {description}: {e}')
                    raise

    def _convert_format_dict(self, format_dict: Dict[str, Any]) -> Dict[str, Any]:
        """Convert gspread-style format dict to Sheets API format."""
        result = {}

        text_format = {}
        for key in ('bold', 'italic', 'fontSize'):
            if key in format_dict:
                text_format[key] = format_dict[key]
        if 'textFormat' in format_dict:
            text_format.update(format_dict['textFormat'])
        if text_format:
            result['textFormat'] = text_format

        for key in (
            'numberFormat',
            'horizontalAlignment',
            'verticalAlignment',
            'wrapStrategy',
            'hyperlinkDisplayType',
        ):
            if key in format_dict:
                result[key] = format_dict[key]

        return result

    def _get_format_fields(self, format_dict: Dict[str, Any]) -> str:
        """Build the fields mask string for a repeatCell request."""
        field_map = {
            'bold': 'textFormat',
            'italic': 'textFormat',
            'fontSize': 'textFormat',
            'textFormat': 'textFormat',
            'numberFormat': 'numberFormat',
            'horizontalAlignment': 'horizontalAlignment',
            'verticalAlignment': 'verticalAlignment',
            'wrapStrategy': 'wrapStrategy',
            'hyperlinkDisplayType': 'hyperlinkDisplayType',
        }
        fields = {
            f'userEnteredFormat.{field_map[k]}' for k in format_dict if k in field_map
        }
        return ','.join(fields) if fields else 'userEnteredFormat'
