import ast
from pathlib import Path
from unittest.mock import Mock

import pytest

from scripts.modal_deployment import verify_deployment
from scripts.railway_trigger import trigger

EXPECTED = {
    'app_name': 'fiscal-pipeline',
    'deployment_sha': 'a' * 40,
    'deployment_target': 'production',
    'modal_environment': 'main',
    'schedules': {},
    'scheduler': 'railway',
    'image_builder_version': '2025.06',
}


def lookup_for(metadata):
    function = Mock()
    function.remote.return_value = metadata
    function.spawn.return_value.object_id = 'fc-test'
    return Mock(return_value=function)


def test_verify_deployment():
    lookup = lookup_for(EXPECTED)
    assert (
        verify_deployment(
            'fiscal-pipeline', 'main', 'production', 'a' * 40, function_lookup=lookup
        )
        == EXPECTED
    )
    lookup.assert_called_once_with(
        'fiscal-pipeline', 'get_deployment_metadata', environment_name='main'
    )


@pytest.mark.parametrize('key', EXPECTED)
def test_verify_rejects_mismatches(key):
    lookup = lookup_for({**EXPECTED, key: 'wrong'})
    with pytest.raises(RuntimeError, match='verification failed'):
        verify_deployment(
            'fiscal-pipeline', 'main', 'production', 'a' * 40, function_lookup=lookup
        )


def test_disabled_trigger_does_not_contact_modal(monkeypatch):
    monkeypatch.delenv('RAILWAY_TRIGGERS_ENABLED', raising=False)
    lookup = Mock()
    trigger('daily', function_lookup=lookup)
    lookup.assert_not_called()


def test_trigger_spawns_and_logs_call_id(monkeypatch, capsys):
    monkeypatch.setenv('RAILWAY_TRIGGERS_ENABLED', 'true')
    lookup = lookup_for(EXPECTED)
    trigger('daily', function_lookup=lookup)
    lookup.assert_called_with(
        'fiscal-pipeline', 'update_google_sheet', environment_name='main'
    )
    lookup.return_value.spawn.assert_called_once_with()
    assert 'fc-test' in capsys.readouterr().out


def test_check_only_never_spawns():
    lookup = lookup_for(EXPECTED)
    trigger('daily', check_only=True, function_lookup=lookup)
    lookup.return_value.hydrate.assert_called_once_with()
    lookup.return_value.spawn.assert_not_called()


@pytest.mark.parametrize(
    'key',
    ['app_name', 'modal_environment', 'deployment_target', 'schedules', 'scheduler'],
)
def test_trigger_rejects_wrong_deployment(monkeypatch, key):
    monkeypatch.setenv('RAILWAY_TRIGGERS_ENABLED', 'true')
    lookup = lookup_for({**EXPECTED, key: 'wrong'})
    with pytest.raises(RuntimeError, match='not ready'):
        trigger('daily', function_lookup=lookup)
    lookup.return_value.spawn.assert_not_called()


def test_spawn_failure_is_not_retried(monkeypatch):
    monkeypatch.setenv('RAILWAY_TRIGGERS_ENABLED', 'true')
    lookup = lookup_for(EXPECTED)
    lookup.return_value.spawn.side_effect = RuntimeError('submission failed')
    with pytest.raises(RuntimeError, match='submission failed'):
        trigger('daily', function_lookup=lookup)
    lookup.return_value.spawn.assert_called_once()


def test_app_is_schedule_free():
    tree = ast.parse(Path('app.py').read_text())
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            assert not any(keyword.arg == 'schedule' for keyword in node.keywords)
            if isinstance(node.func, ast.Attribute):
                assert node.func.attr not in {'Cron', 'Period'}
    import app

    assert app.get_deployment_metadata.local()['schedules'] == {}


@pytest.mark.parametrize('pipeline_fails', [False, True])
def test_completion_heartbeat_only_after_success(monkeypatch, pipeline_fails):
    import app
    import src.etl.etl
    import src.sheets.refresh_sheets
    import src.warehouse.create_warehouse

    monkeypatch.setenv(
        'FISCAL_COMPLETION_HEALTHCHECK_URL', 'https://example.invalid/ping'
    )
    monkeypatch.setattr(src.etl.etl, 'etl_ynab_data', Mock())
    monkeypatch.setattr(src.warehouse.create_warehouse, 'create_data_warehouse', Mock())
    refresh = Mock(
        side_effect=RuntimeError('refresh failed') if pipeline_fails else None
    )
    monkeypatch.setattr(src.sheets.refresh_sheets, 'refresh_sheets', refresh)
    ping = Mock()
    monkeypatch.setattr('requests.get', ping)
    if pipeline_fails:
        with pytest.raises(RuntimeError, match='refresh failed'):
            app.update_google_sheet.local()
        ping.assert_not_called()
    else:
        app.update_google_sheet.local()
        ping.assert_called_once_with('https://example.invalid/ping', timeout=10)
