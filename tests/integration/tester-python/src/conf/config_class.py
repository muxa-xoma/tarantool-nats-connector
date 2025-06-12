from dataclasses import dataclass
from pathlib import Path
from urllib.parse import ParseResult


@dataclass(slots=True)
class AppConfig:
    ip: str = "127.0.0.1"
    port: int = 8080
    results_path: str = "/results"
    runner_path: str = "/run"


@dataclass(slots=True)
class LogConfig:
    level: str = "INFO"
    format: str = 'json'
    output: str = "console"
    file_path: Path or None = None


@dataclass(slots=True)
class NatsConfig:
    urls: list[ParseResult]
    user: str or None = None
    password: str or None = None


@dataclass(slots=True)
class TarantoolConfig:
    host: str
    port: int
    user: str = "client"
    password: str = "secret"


@dataclass(slots=True)
class Config:
    nats: NatsConfig
    app: AppConfig
    log: LogConfig
    tarantool: TarantoolConfig


__all__ = [
    'AppConfig',
    'LogConfig',
    'NatsConfig',
    'TarantoolConfig',
    'Config'
]
