"""Owned local play host; restart replaces its encounter inside the same service."""
import argparse
import asyncio
import json
import os
from pathlib import Path
import secrets
from uuid import UUID

from fastapi import HTTPException, Request
import uvicorn

from server.app import create_app
from server import host as owner, service as hosting
from server.config import ServerConfig


def create_play_app(config: ServerConfig):
    app = create_app(config)
    reset_lock = asyncio.Lock()

    @app.post("/local/restart", include_in_schema=False)
    async def restart(request: Request):
        authorization = request.headers.get("authorization", "")
        token = authorization[7:] if authorization.startswith("Bearer ") else ""
        if not secrets.compare_digest(token.encode(), config.credentials[0].token.encode()):
            raise HTTPException(401, "Invalid local owner credential")
        try:
            expected_epoch = UUID(request.headers["x-game-epoch"])
        except (KeyError, ValueError):
            raise HTTPException(400, "Expected the current game epoch") from None
        async with reset_lock:
            old = app.state.player_host
            if old.epoch != expected_epoch:
                raise HTTPException(409, "This encounter has already been replaced")
            service = app.state.player_service
            # EndGame resets and releases the native world before its Host's
            # retention task is retired. Saved recording files stay on disk.
            await hosting.end_game(service, old.config.game_id)
            await owner.shutdown(old)
            del service.games[old.config.game_id]
            fresh = hosting.start_game(service, config)
            app.state.player_host = fresh
            print(f"Encounter restarted: {old.epoch} -> {fresh.epoch}", flush=True)
            return {"game_epoch": str(fresh.epoch)}

    return app


async def run(args):
    app = create_play_app(ServerConfig.model_validate_json(args.config.read_bytes()))
    server = uvicorn.Server(uvicorn.Config(app, host=args.host, port=args.port,
        log_level="warning", timeout_graceful_shutdown=5))

    async def watch():
        announced = False
        while not args.stop.exists():
            if server.started and not announced:
                args.result.with_name("host.ready").touch()
                announced = True
            await asyncio.sleep(.05)
        server.should_exit = True

    watcher = asyncio.create_task(watch())
    try:
        await server.serve()
    finally:
        watcher.cancel()
        await asyncio.gather(watcher, return_exceptions=True)
        host = app.state.player_host
        args.result.write_text(json.dumps({"pid": os.getpid(), "game_epoch": str(host.epoch),
            "timings": host.timings, "owned_workers_after_shutdown": app.state.player_service.workers.count}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--stop", type=Path, required=True)
    parser.add_argument("--result", type=Path, required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    asyncio.run(run(parser.parse_args()))


if __name__ == "__main__":
    main()
