import logging
import asyncio

from pythonjsonlogger.json import JsonFormatter

from conf import get_config, Config, LogConfig

async def get_logger(config: LogConfig) -> logging.Logger:
    logger = logging.getLogger(__name__)
    if config.output == 'file':
        handler = logging.FileHandler(config.file_path)
    else:
        handler = logging.StreamHandler()
    if config.format == 'json':
        formatter = JsonFormatter(
            '{asctime}{pathname}{lineno}{funcName}{levelname}{message}',
            rename_fields={
                'levelname': 'level',
                'asctime': 'time',
                'pathname': 'file',
                'lineno': 'line',
                'funcName': 'function'
            }
        )
    else:
        formatter = logging.Formatter(
            fmt='[%(asctime)s] %(pathname)s-%(lineno)d-%(funcName)s %(levelname)s: %(message)s'
        )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.setLevel(config.level)
    return logger


async def main():
    config: Config = await get_config()
    logger = await get_logger(config.log)


if __name__ == "__main__":
    asyncio.run(main())
