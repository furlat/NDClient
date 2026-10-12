"""Windows/WSL launcher admission and owned-listener lifecycle.

Fast cases use real WSL sockets and substitute only the external Windows port
allocation response. Set NDCLIENT_NATIVE_PORT_TEST=1 for actual Windows socket
allocation/rebind; neither lane starts Godot or a gameplay backend.
"""
import os
import socket
import subprocess
import unittest
from unittest.mock import patch

from delayed_backend import close_delayed_backend, start_delayed_backend
from play import available_port


def local_candidate() -> int:
    with socket.socket() as probe:
        probe.bind(("0.0.0.0", 0))
        return probe.getsockname()[1]


class LauncherPorts(unittest.TestCase):
    def test_selected_port_is_released_for_actual_backend_bind(self):
        candidate = local_candidate()
        with patch("play.subprocess.check_output", return_value=str(candidate)):
            selected = available_port()
        self.assertEqual(selected, candidate)
        with socket.socket() as backend:
            backend.bind(("0.0.0.0", selected))

    def test_wsl_collision_retries_without_disturbing_other_listener(self):
        with socket.socket() as occupied:
            occupied.bind(("127.0.0.1", 0))
            occupied.listen(1)
            busy = occupied.getsockname()[1]
            free = local_candidate()
            with patch("play.subprocess.check_output", side_effect=[str(busy), str(free)]):
                self.assertEqual(available_port(), free)
            self.assertEqual(occupied.getsockname()[1], busy)
            with socket.create_connection(("127.0.0.1", busy), timeout=1):
                accepted, _ = occupied.accept()
                accepted.close()

    def test_backend_and_delayed_proxy_cannot_select_same_port(self):
        backend = local_candidate()
        with socket.socket() as held:
            held.bind(("127.0.0.1", backend))
            proxy = local_candidate()
        with patch("play.subprocess.check_output", side_effect=[str(backend), str(proxy)]):
            self.assertEqual(available_port((backend,)), proxy)

    def test_persistent_cross_host_conflict_fails_with_bounded_error(self):
        with socket.socket() as occupied:
            occupied.bind(("0.0.0.0", 0))
            with patch("play.subprocess.check_output", return_value=str(occupied.getsockname()[1])):
                with self.assertRaisesRegex(RuntimeError, "after 10 attempts"):
                    available_port()

    def test_native_failure_does_not_fall_back_to_wsl_only_selection(self):
        for failure in (subprocess.CalledProcessError(1, "powershell.exe"),
                        subprocess.TimeoutExpired("powershell.exe", 10)):
            with self.subTest(failure=type(failure).__name__):
                with patch("play.subprocess.check_output", side_effect=failure):
                    with self.assertRaisesRegex(RuntimeError, "Native Windows"):
                        available_port()
        for output in ("", "invalid", "0", "65536"):
            with self.subTest(output=output):
                with patch("play.subprocess.check_output", return_value=output):
                    with self.assertRaisesRegex(RuntimeError, "Native Windows"):
                        available_port()


class DelayedProxyPort(unittest.IsolatedAsyncioTestCase):
    async def test_proxy_binds_selected_port_and_close_releases_it(self):
        port = local_candidate()
        proxy = await start_delayed_backend(1, 1, port)
        try:
            self.assertEqual(proxy["port"], port)
            self.assertEqual(proxy["server"].sockets[0].getsockname(), ("0.0.0.0", port))
        finally:
            await close_delayed_backend(proxy)
        with socket.socket() as next_owner:
            next_owner.bind(("0.0.0.0", port))
        self.assertFalse(proxy["tasks"])
        self.assertFalse(proxy["state"]["errors"])


@unittest.skipUnless(os.environ.get("NDCLIENT_NATIVE_PORT_TEST") == "1", "explicit native Windows lane")
class NativeWindowsPort(unittest.TestCase):
    def test_real_native_allocation_then_native_and_wsl_rebind(self):
        port = available_port()
        # Independent native exclusive rebind checks Windows accepted the actual
        # selected port, rather than merely trusting a WSL ephemeral allocation.
        script = (
            "$ErrorActionPreference = 'Stop'; "
            "$probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, "
            + str(port) + "); $probe.ExclusiveAddressUse = $true; "
            "try { $probe.Start(1); $probe.LocalEndpoint.Port } finally { $probe.Stop() }"
        )
        output = subprocess.check_output(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
                                         text=True, stderr=subprocess.PIPE, timeout=10)
        self.assertEqual(int(output.strip()), port)
        with socket.socket() as backend:
            backend.bind(("0.0.0.0", port))
        print("NATIVE_WINDOWS_AND_WSL_PORT", port, flush=True)


if __name__ == "__main__":
    unittest.main()
