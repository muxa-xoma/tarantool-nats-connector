import asynctnt

from logging import Logger
from uuid import UUID
from dataclasses import dataclass

from conf import TarantoolConfig

@dataclass(slots=True)
class TarantoolResult:
    success: bool
    data: str|UUID


class TarantoolIntegration:

    def __init__(self, config: TarantoolConfig, logger: Logger):
        self._client: asynctnt.Connection = asynctnt.Connection(
            host=config.host,
            port=config.port,
            username=config.user,
            password=config.password
        )
        self._logger = logger
        self._entity_name: str|None = None

    async def connect(self) -> bool:
        if not self._client.is_connected:
            self._logger.info(
                f'Connecting to {self._client.host}:{self._client.port}'
            )
            await self._client.connect()
            if self._client.is_connected:
                self._logger.info(
                    f'Connected to {self._client.host}:{self._client.port}'
                )
            else:
                self._logger.error(
                    f'Could not connect to {self._client.host}:{self._client.port}'
                )
        return self._client.is_connected

    async def disconnect(self) -> bool:
        if self._client.is_connected:
            self._logger.info(
                f'Disconnecting from {self._client.host}:{self._client.port}'
            )
            await self._client.disconnect()
            if not self._client.is_connected:
                self._logger.info(
                    f'Disconnected from {self._client.host}:{self._client.port}'
                )
            else:
                self._logger.error(
                    f'Could not disconnect from {self._client.host}:{self._client.port}'
                )
        return not self._client.is_connected

    async def create_test_entity(
            self, name: str, nats_servers: list[str] or str, nats_options: dict, result_url:str
    ) -> bool:
        assert self._client.is_connected, 'the connect function call must be first'
        response = await self._client.call16(
            'create_test_nats',
            [name, nats_servers, nats_options, result_url],
            timeout=5
        )
        if response.body:
            if response.body[0] and response.body[0][0]:
                self._entity_name = name
                return True
        return False

    @property
    def entity_name(self) -> str|None:
        if self._entity_name:
            return self._entity_name
        else:
            return None

    async def start_test(self, name: str, options: dict) -> TarantoolResult:
        assert self._entity_name, 'the create_test_entity function call must be first'
        response = await self._client.call16(self._entity_name + ':' + name, [options], timeout=5)
        if response.body:
            if response.body[0]:
                result = TarantoolResult(response.body[0][0], response.body[0][1])
            else:
                result = TarantoolResult(False, response.errmsg)
        else:
            result = TarantoolResult(False, 'Timeout')
        return result

    async def end_test(self, name: str, *args) -> TarantoolResult:
        assert self._entity_name, 'the create_test_entity function call must be first'
        response = await self._client.call16(self._entity_name + ':' + name, [*args], timeout=5)
        if response.body:
            if response.body[0]:
                result = TarantoolResult(response.body[0][0], response.body[0][1])
            else:
                result = TarantoolResult(False, response.errmsg)
        else:
            result = TarantoolResult(False, 'Timeout')
        return result


__all__ = ['TarantoolIntegration', 'TarantoolResult']
