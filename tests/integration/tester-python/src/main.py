import logging
import asyncio

from pythonjsonlogger.json import JsonFormatter

from conf import get_config, Config, LogConfig
from tt import TarantoolIntegration
from test import Test, TestType
from http_server import Server

async def get_logger(config: LogConfig) -> logging.Logger:
    logger = logging.getLogger(__name__)
    if config.output == 'file':
        handler = logging.FileHandler(config.file_path)
    else:
        handler = logging.StreamHandler()
    if config.format == 'json':
        formatter = JsonFormatter(
            '{asctime}{pathname}{lineno}{funcName}{levelname}{message}',
            style="{",
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
    tt = TarantoolIntegration(config.tarantool, logger)
    test = Test(
        TestType.publish,
        {
            'subject': f'{TestType.publish.name}.sub',
            'headers': True,
            'reply': f'{TestType.publish.name}.reply',
            'work_time': 5
        },
        tt,
        logger,
        config.nats,
        config.app
    )
    server = Server(config.app, test.results)
    await server.run()
    result = await test.run()
    logger.info('Test finished')
    await server.close()
    if result:
        logger.info('Test passed')
    else:
        logger.info('Test failed')
        exit(1)
    test = Test(
        TestType.publish,
        {
            'subject': f'{TestType.publish.name}.sub',
            'headers': True,
            'reply': f'{TestType.publish.name}.reply',
            'msg_count': 100000
        },
        tt,
        logger,
        config.nats,
        config.app
    )
    server = Server(config.app, test.results)
    await server.run()
    result = await test.run()
    logger.info('Test finished')
    await server.close()
    if result:
        logger.info('Test passed')
    else:
        logger.info('Test failed')
        exit(1)


if __name__ == "__main__":
    asyncio.run(main())
