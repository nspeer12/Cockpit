"""Regression tests for Cockpit's mobile web companion server."""
from __future__ import annotations

import http.client
import importlib.util
import json
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER_PATH = ROOT / "server.py"

spec = importlib.util.spec_from_file_location("cockpit_web_server", SERVER_PATH)
assert spec and spec.loader
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class CockpitWebServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.httpd = server.create_server("127.0.0.1", 0)
        cls.port = cls.httpd.server_address[1]
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join(timeout=2)

    def get(self, path: str) -> tuple[int, dict[str, str], bytes]:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        connection.request("GET", path)
        response = connection.getresponse()
        body = response.read()
        headers = {name.lower(): value for name, value in response.getheaders()}
        connection.close()
        return response.status, headers, body

    def test_stats_contract_contains_mobile_dashboard_metrics(self) -> None:
        stats = server.api_stats()
        self.assertTrue({"hostname", "cpu", "memory", "disk", "model", "timestamp"} <= stats.keys())
        self.assertTrue({"cores", "load", "percent"} <= stats["cpu"].keys())
        self.assertTrue({"used_gb", "total_gb", "percent"} <= stats["memory"].keys())

    def test_health_and_stats_endpoints(self) -> None:
        status, _, body = self.get("/health")
        self.assertEqual(status, 200)
        self.assertEqual(body, b"ok")

        status, headers, body = self.get("/api/stats")
        self.assertEqual(status, 200)
        self.assertIn("application/json", headers["content-type"])
        self.assertIn("hostname", json.loads(body))

    def test_pwa_assets_are_served(self) -> None:
        for path, content_type in [
            ("/", "text/html"),
            ("/manifest.webmanifest", "application/manifest+json"),
            ("/service-worker.js", "javascript"),
        ]:
            with self.subTest(path=path):
                status, headers, _ = self.get(path)
                self.assertEqual(status, 200)
                self.assertIn(content_type, headers["content-type"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
