"""Verify Modal deployments without running the data pipeline."""

import argparse
import json
from collections.abc import Callable
from typing import Any

import modal


def verify_deployment(
    app_name: str,
    environment: str,
    target: str,
    deployment_sha: str,
    *,
    function_lookup: Callable[..., Any] = modal.Function.from_name,
) -> dict[str, Any]:
    """Invoke the lightweight metadata function and validate its deployment."""
    function = function_lookup(
        app_name,
        'get_deployment_metadata',
        environment_name=environment,
    )
    metadata = function.remote()
    expected = {
        'app_name': app_name,
        'deployment_sha': deployment_sha,
        'deployment_target': target,
        'modal_environment': environment,
        'schedules': {},
        'scheduler': 'railway' if target == 'production' else None,
        'image_builder_version': '2025.06',
    }
    mismatches = [
        f'{key}: expected {value!r}, received {metadata.get(key)!r}'
        for key, value in expected.items()
        if metadata.get(key) != value
    ]
    if mismatches:
        raise RuntimeError(
            'Modal deployment verification failed: ' + '; '.join(mismatches)
        )

    print(json.dumps(metadata, sort_keys=True))
    return metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--deployment-sha', required=True)
    args = parser.parse_args()
    verify_deployment('fiscal-pipeline', 'main', 'production', args.deployment_sha)


if __name__ == '__main__':
    main()
