import os
import sys

from pyconfigparser import configparser
from pathlib import Path

from conf.config_class import Config, AppConfig, LogConfig, NatsConfig, TarantoolConfig
from conf.schema import config_schema

async def get_config(file_path: str = './conf.yaml') -> Config:
    env_file_path = os.getenv('CONFIG_FILE', None)
    if env_file_path:
        file_path = Path(env_file_path)
    else:
        file_path = Path(file_path)
    conf_dir = ''
    if os.getcwd() != str(file_path.absolute().parent):
        conf_dir = str(file_path.absolute().parent).lstrip(os.getcwd())
    try:
        config = configparser.get_config(
            schema=config_schema,
            config_dir=conf_dir,
            file_name=file_path.name
        )
    except Exception as e:
        sys.stderr.write(f'Config error: {e}\n')
        sys.exit(1)
    if config.get('app', None):
        app = AppConfig(
            ip=config['app'].get('ip'),
            port=config['app'].get('port'),
            results_path=config['app'].get('results_path'),
            runner_path=config['app'].get('runner_path')
        )
    else:
        app = AppConfig()
    if config.get('log', None):
        log = LogConfig(
            level=config['log'].get('level'),
            format=config['log'].get('format'),
            output=config['log'].get('output'),
            file_path=config['log'].get('file_path')
        )
    else:
        log = LogConfig

    return Config(
        app=app,
        log=log,
        nats=NatsConfig(
            urls=config['nats']['urls'],
            user=config['nats'].get('user'),
            password=config['nats'].get('pass')
        ),
        tarantool=TarantoolConfig(
            host=config['tarantool']['host'],
            port=config['tarantool']['port'],
            user=config['tarantool'].get('user'),
            password=config['tarantool'].get('pass')
        )
    )


__all__ = [
    'get_config',
    'Config',
    'AppConfig',
    'LogConfig',
    'NatsConfig',
    'TarantoolConfig'
]
