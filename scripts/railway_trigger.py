"""Submit one production Modal call and exit; execution stays on Modal."""

import argparse
import json
import os
from collections.abc import Callable, Sequence
from typing import Any

import modal

APP_NAME = 'fiscal-pipeline'
ENVIRONMENT = 'main'
FUNCTIONS = {'daily': 'update_google_sheet'}


def trigger(
    job: str,
    *,
    check_only: bool = False,
    function_lookup: Callable[..., Any] = modal.Function.from_name,
) -> None:
    function_name = FUNCTIONS[job]
    context = {'app': APP_NAME, 'environment': ENVIRONMENT, 'function': function_name}
    if not check_only and os.getenv('RAILWAY_TRIGGERS_ENABLED') != 'true':
        print(json.dumps({**context, 'status': 'disabled'}), flush=True)
        return

    try:
        metadata = function_lookup(
            APP_NAME, 'get_deployment_metadata', environment_name=ENVIRONMENT
        ).remote()
        expected = {
            'app_name': APP_NAME,
            'modal_environment': ENVIRONMENT,
            'deployment_target': 'production',
            'schedules': {},
            'scheduler': 'railway',
        }
        if any(metadata.get(key) != value for key, value in expected.items()):
            raise RuntimeError('Modal deployment is not ready for Railway triggers.')
        function = function_lookup(
            APP_NAME, function_name, environment_name=ENVIRONMENT
        )
        function.hydrate()
        if check_only:
            print(json.dumps({**context, 'status': 'verified'}), flush=True)
            return
        call = function.spawn()
        print(
            json.dumps({**context, 'status': 'submitted', 'call_id': call.object_id}),
            flush=True,
        )
    except Exception:
        print(json.dumps({**context, 'status': 'failed'}), flush=True)
        raise


def main(argv: Sequence[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('job', choices=FUNCTIONS)
    parser.add_argument('--check-only', action='store_true')
    args = parser.parse_args(argv)
    trigger(args.job, check_only=args.check_only)


if __name__ == '__main__':
    main()
