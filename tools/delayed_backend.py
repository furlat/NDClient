"""Test-only real HTTP forwarding; delay one command before the owned backend.

Bodies, auth and SSE bytes are forwarded unchanged. Connection close avoids
hiding a later command inside a reused HTTP connection. No packet fabrication.
"""
import asyncio


async def start_delayed_backend(backend_port: int, delay_ms: int, listen_port: int = 0) -> dict:
    tasks: set[asyncio.Task] = set()
    state = {"delayed_commands": 0, "requests": 0, "errors": []}

    async def forward(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        task = asyncio.current_task()
        tasks.add(task)
        upstream_writer = None
        try:
            state["requests"] += 1
            header = await reader.readuntil(b"\r\n\r\n")
            lines = header[:-4].split(b"\r\n")
            request_line = lines[0].split(b" ")
            length = 0
            kept = [lines[0]]
            for line in lines[1:]:
                key, _, value = line.partition(b":")
                if key.lower() == b"content-length":
                    length = int(value.strip())
                if key.lower() != b"connection":
                    kept.append(line)
            if not 0 <= length <= 64 * 1024 * 1024:
                raise ValueError("Test request size outside native contract")
            body = await reader.readexactly(length)
            if request_line[0] == b"POST" and request_line[1].endswith(b"/commands") and state["delayed_commands"] == 0:
                state["delayed_commands"] += 1
                await asyncio.sleep(delay_ms / 1000)
            upstream_reader, upstream_writer = await asyncio.open_connection("127.0.0.1", backend_port)
            upstream_writer.write(b"\r\n".join(kept) + b"\r\nConnection: close\r\n\r\n" + body)
            await upstream_writer.drain()
            while chunk := await upstream_reader.read(65536):
                writer.write(chunk)
                await writer.drain()
        except (ConnectionError, asyncio.IncompleteReadError, asyncio.LimitOverrunError, TimeoutError) as error:
            state["errors"].append(type(error).__name__)
        finally:
            if upstream_writer is not None:
                upstream_writer.close()
            writer.close()
            tasks.discard(task)

    server = await asyncio.start_server(forward, "0.0.0.0", listen_port)
    return {"server": server, "tasks": tasks, "state": state, "port": server.sockets[0].getsockname()[1]}


async def close_delayed_backend(proxy: dict) -> None:
    proxy["server"].close()
    await proxy["server"].wait_closed()
    pending = tuple(proxy["tasks"])
    for task in pending:
        task.cancel()
    await asyncio.gather(*pending, return_exceptions=True)
