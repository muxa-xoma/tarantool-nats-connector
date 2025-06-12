import json

from quart import Quart, request
from asyncio import Queue, Task, create_task

from conf import AppConfig


class Server:

    def __init__(self, config: AppConfig, queue: Queue):
        self._config = config
        self._queue = queue
        self._app = Quart(__name__)
        self._task: Task|None = None

    async def run(self) -> None:
        @self._app.route(f"{self._config.runner_path}", methods=['POST'])
        async def route():
            await self._queue.put(json.loads(await request.get_data()))
            return {'message': 'ok'}, 200
        self._task = create_task(self._app.run_task(host=self._config.ip, port=self._config.port))

    async def close(self) -> None:
        await self._app.shutdown()
        self._task.cancel()

    @property
    def task(self) -> Task:
        return self._task


__all__ = ['Server']
