from schema import Use, And, Optional
from pathlib import Path
from urllib.parse import urlparse, ParseResult

def str_to_url(urls: str) -> list[ParseResult]:
    return [urlparse(url) for url in urls.split(',')]


config_schema = {
    Optional('app'): {
        'ip': And(str, len),
        'port': And(Use(int), lambda number: number > 0),
        'results_path': And(str, Use(str.lower), lambda string: string.startswith('/')),
        'runner_path': And(str, Use(str.lower), lambda string: string.startswith('/'))
    },
    Optional('log'): {
        'level': And(
            str,
            Use(str.upper),
            lambda string: string in ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
        ),
        'format': And(str, Use(str.lower), lambda string: string in ['json', 'text']),
        'output': And(str, Use(str.lower), lambda string: string in ['console', 'file']),
        Optional('file_path'): And(str, Use(Path), lambda path:  path.is_file())
    },
    'tarantool': {
        'host': And(str, len),
        'port': And(Use(int), lambda number: number > 0),
        Optional('user'): And(str, len),
        Optional('pass'): And(str, len)
    },
    'nats': [
        {
            'urls': And(list[ParseResult], Use(str_to_url), lambda urls: all(url.scheme == 'nats' for url in urls)),
            Optional('user'): And(str, len),
            Optional('pass'): And(str, len)
        }
    ]
}


__all__ = ['config_schema']
