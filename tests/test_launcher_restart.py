"""Explicit local HTTP/native-worker restart check; never launches Godot."""
import asyncio
import os
from pathlib import Path
import socket
import tempfile
import unittest
from uuid import uuid4

import httpx
import uvicorn

from devtools.player_server_acceptance.fixtures import combat_configuration
from dnd_player import Follower, acknowledge, attach, connect, follow, status, wait_for_cursor
from play_host import create_play_app


@unittest.skipUnless(os.environ.get("NDCLIENT_HOST_RESTART_TEST") == "1", "explicit native-worker lane")
class LocalEncounterRestart(unittest.IsolatedAsyncioTestCase):
    async def test_restart_resets_turn_without_replacing_server_or_worker(self):
        with tempfile.TemporaryDirectory() as directory, socket.socket() as listener:
            config = combat_configuration("melee", Path(directory))
            app = create_play_app(config)
            listener.bind(("127.0.0.1", 0))
            server = uvicorn.Server(uvicorn.Config(app, log_level="warning", timeout_graceful_shutdown=5))
            serving = asyncio.create_task(server.serve(sockets=[listener]))

            async def ready():
                host = app.state.player_host
                async with asyncio.timeout(60), host.changed:
                    await host.changed.wait_for(lambda: host.failure is not None or
                        all(seat.publication is not None for seat in host.seats.values()) and
                        any(seat.publication.boundary.input_actor_uuid is not None for seat in host.seats.values()))
                self.assertIsNone(host.failure)
                return host.process.process

            async def initialization(http):
                connection = await connect(str(http.base_url), config.credentials[0].token)
                initial = []
                async def consume(packet, _raw):
                    if packet["cursor"]["sequence"] == 0: initial.append(packet)
                follower = Follower(connection, consume)
                task = None
                try:
                    attached = await attach(connection, {"acquisition_id": str(uuid4()), "expected_attachment_epoch": None})
                    task = asyncio.create_task(follow(follower))
                    boot = await status(connection)
                    await wait_for_cursor(follower, boot["published_cursor"])
                    await acknowledge(connection, follower.consumed)
                    headers = {"X-Game-Epoch": boot["game_epoch"], "X-Audience-Id": boot["audience_id"],
                        "X-Attachment-Epoch": attached["attachment_epoch"]}
                    return boot, headers, "/api/v1/games/" + boot["game_id"], initial[0]
                finally:
                    if task is not None:
                        task.cancel()
                        await asyncio.gather(task, return_exceptions=True)
                    await connection.http.aclose()

            try:
                async with asyncio.timeout(10):
                    while not server.started:
                        if serving.done(): await serving
                        await asyncio.sleep(.01)
                worker = await ready()
                async with httpx.AsyncClient(base_url=f"http://127.0.0.1:{listener.getsockname()[1]}",
                        headers={"Authorization": "Bearer " + config.credentials[0].token}, timeout=30) as http:
                    initial, headers, route, opening = await initialization(http)
                    epoch = initial["game_epoch"]
                    response = await http.post("/local/restart", headers={"Authorization": "Bearer wrong", "X-Game-Epoch": epoch})
                    self.assertEqual(response.status_code, 401)
                    self.assertEqual((await http.post("/local/restart")).status_code, 400)
                    response = await http.post(route + "/commands", headers=headers, json={
                        "command_number": 1, "actor_uuid": initial["boundary"]["input_actor_uuid"],
                        "state_revision": initial["boundary"]["state_revision"], "intent": {"kind": "end_turn"}})
                    response.raise_for_status()
                    async with asyncio.timeout(30):
                        while response.json()["receipt"]["kind"] == "pending":
                            await asyncio.sleep(.01)
                            response = await http.get(route + "/commands/1", headers=headers)
                            response.raise_for_status()
                    self.assertEqual(response.json()["receipt"]["kind"], "committed")
                    changed = (await http.get(route + "/status", headers=headers)).json()["status"]
                    self.assertEqual(changed["next_command_number"], 2)
                    self.assertGreater(changed["published_cursor"]["sequence"], initial["published_cursor"]["sequence"])
                    self.assertNotEqual(changed["boundary"]["input_actor_uuid"], initial["boundary"]["input_actor_uuid"])
                    saved = list((config.spool_directory / epoch).glob("*.frames"))
                    self.assertTrue(saved)

                    # Concurrent presses carry the same old epoch: exactly one reset.
                    replies = await asyncio.gather(*(http.post("/local/restart", headers={"X-Game-Epoch": epoch}) for _ in range(2)))
                    self.assertEqual(sorted(reply.status_code for reply in replies), [200, 409])
                    self.assertIs(await ready(), worker)
                    self.assertIsNone(worker.returncode)
                    self.assertFalse(serving.done())
                    fresh, _, _, fresh_opening = await initialization(http)
                    self.assertNotEqual(fresh["game_epoch"], epoch)
                    self.assertEqual(fresh["next_command_number"], 1)
                    self.assertEqual(fresh["published_cursor"]["sequence"], initial["published_cursor"]["sequence"])
                    self.assertEqual(fresh_opening["initialization"]["world"], opening["initialization"]["world"])
                    self.assertEqual(len(fresh_opening["initialization"]["hud"]["initiative"]),
                        len(opening["initialization"]["hud"]["initiative"]))
                    self.assertEqual((await http.get(route + "/status", headers=headers)).status_code, 409)
                    self.assertTrue(all(path.is_file() and path.stat().st_size > 0 for path in saved))
                    self.assertEqual(len(app.state.player_service.games), 1)
                    print("LOCAL_RESTART_OK: same HTTP listener and native worker; fresh epoch, turn and command count; old recordings retained")
            finally:
                server.should_exit = True
                await asyncio.wait_for(serving, 20)
            self.assertEqual(app.state.player_service.workers.count, 0)


if __name__ == "__main__":
    unittest.main()
