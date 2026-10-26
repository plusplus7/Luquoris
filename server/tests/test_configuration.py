from loquiris_server.config import Settings


def test_default_deployment_advertises_only_primary_prepared_profile(monkeypatch):
    monkeypatch.setenv("LOQUIRIS_CLIENT_TOKENS", '{"phone":"' + "a" * 32 + '"}')
    assert list(Settings.from_env().profiles) == ["qwen-1.7b"]


def test_whisper_is_enabled_explicitly(monkeypatch):
    monkeypatch.setenv("LOQUIRIS_CLIENT_TOKENS", '{"phone":"' + "a" * 32 + '"}')
    monkeypatch.setenv("LOQUIRIS_ENABLED_PROFILES", "qwen-1.7b,whisper-large-v3")
    assert set(Settings.from_env().profiles) == {"qwen-1.7b", "whisper-large-v3"}


def test_deployment_can_configure_actual_retention(monkeypatch):
    monkeypatch.setenv("LOQUIRIS_CLIENT_TOKENS", '{"phone":"' + "a" * 32 + '"}')
    monkeypatch.setenv("LOQUIRIS_RETENTION_SECONDS", "7200")
    assert Settings.from_env().retention_seconds == 7200
