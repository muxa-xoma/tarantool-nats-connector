import nats
import asyncio
import json

from nats.aio.msg import Msg
from logging import Logger
from enum import IntEnum
from uuid import UUID
from typing import Any
from datetime import datetime

from tt import TarantoolIntegration, TarantoolResult
from conf import AppConfig, NatsConfig


class TestType(IntEnum):
    publish = 1
    subscribe = 2
    request = 3


class Test:

    def __init__(
            self, test_type: TestType, test_options: dict[str, Any] | None, tarantool: TarantoolIntegration, logger: Logger,
            nats_options: NatsConfig, http_options: AppConfig
    ) -> None:
        self._logger: Logger = logger
        self._type: TestType = test_type
        self._options: dict[str, Any]|None = test_options
        self._tarantool: TarantoolIntegration = tarantool
        self._nats_options: NatsConfig = nats_options
        self._http_options: AppConfig = http_options
        self._nats_client: nats.NATS|None = None
        self.id: UUID|None = None
        self.results: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self.message_count: int = 0
        self.publish_test_messages: list[tuple[UUID, datetime]] = []

    async def __nc_error_callback(self, err: Exception) -> None:
        self._logger.error(f'NATS error: {err}')

    async def __nats_init(self) -> bool:
        self._nats_client = await nats.connect(
            servers=[f'{url.scheme}://{url.hostname}:{url.port}' for url in self._nats_options.urls],
            user=self._nats_options.user,
            password=self._nats_options.password,
            name='Tarantool integration tests',
            error_cb=self.__nc_error_callback
        )
        if not self._nats_client.is_connected:
            self._logger.error('NATS connection failed')
            return False
        return True

    async def __tarantool_init(self, entity_name: str) -> bool:
        result = await self._tarantool.connect()
        if not result:
            self._logger.error('Tarantool connection failed')
            return False
        if self._tarantool.entity_name is not None:
            if self._tarantool.entity_name != entity_name:
                self._logger.error(f'Tarantool entity name mismatch: {self._tarantool.entity_name} != {entity_name}')
                return False
        else:
            if not await self._tarantool.create_test_entity(
                entity_name,
                [f'{url.scheme}://{url.hostname}:{url.port}' for url in self._nats_options.urls],
                {'user': self._nats_options.user, 'password': self._nats_options.password},
                f'http://{self._http_options.ip}:{self._http_options.port}{self._http_options.runner_path}'
            ):
                self._logger.error('Tarantool entity creation failed')
                return False
        return True

    async def __publish_test_callback(self, msg: Msg) -> None:
        self._logger.debug(f'Received message: {msg}')
        self.message_count += 1
        payload = json.loads(msg.data)
        self.publish_test_messages.append((UUID(payload['msg_id']), datetime.fromisoformat(payload['published_at'])))

    async def __publish_test(self) -> bool:
        sub = await self._nats_client.subscribe(subject=self._options['subject'], cb=self.__publish_test_callback)
        result = await self._tarantool.start_test('publish_test_start', self._options)
        if not result.success:
            self._logger.error(result.data)
            return False
        self.id = result.data
        result = await self.results.get()
        self._logger.warning(f'Result: {result}')
        if not result['error']:
            await sub.drain()
            self._logger.info(f'Published messages: {result['result']['msg_count']}, received messages: {self.message_count}')
        result = await self._tarantool.end_test('publish_test_end', self.id, self.publish_test_messages)
        if not result.success or result.data != self.id:
            self._logger.error(result.data)
            return False
        result = await self._tarantool.disconnect()
        if not result:
            self._logger.error('Tarantool disconnection failed')
        await self._nats_client.close()
        result = await self.results.get()
        self._logger.warning(f'Result: {result}')
        return True

    async def run(self) -> bool:
        if not await self.__nats_init():
            return False
        if not await self.__tarantool_init(self._type.name):
            return False
        result = False
        match self._type:
            case TestType.publish:
                result = await self.__publish_test()
            case TestType.subscribe:
                result = False
                self._logger.error('Subscribe test is not implemented')
            case TestType.request:
                result = False
                self._logger.error('Request test is not implemented')
        return result


__all__ = ['Test', 'TestType']
