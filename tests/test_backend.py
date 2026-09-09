"""Exercise the real Linux backend with a controllable stand-in for mpv."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "bin/youtube-music"


@unittest.skipUnless(sys.platform == "linux" and shutil.which("jq"), "Linux and jq required")
class BackendTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        # Deliberately never creates its socket. This reproduces stopping and
        # switching tracks while stream resolution is still in flight.
        (self.bin / "mpv").write_text("#!/usr/bin/env python3\nimport time\ntime.sleep(120)\n")
        (self.bin / "socat").write_text("#!/bin/sh\nexit 1\n")
        for file in self.bin.iterdir():
            file.chmod(0o755)
        self.env = dict(os.environ, XDG_RUNTIME_DIR=str(self.root),
                        PATH=f"{self.bin}:{os.environ['PATH']}")
        self.runtime = self.root / "omarchy-youtube-music"
        self.queue = [{"videoId": f"track{i:06d}", "title": f"Track {i}"} for i in range(3)]

    def call(self, *args):
        return subprocess.run(["bash", str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True, timeout=25, check=True)

    def state(self):
        return json.loads((self.runtime / "state.json").read_text())

    def pid(self):
        return int((self.runtime / "mpv.pid").read_text())

    def start(self, index=0):
        self.call("queue", json.dumps(self.queue), str(index))
        return self.pid()

    def assertStopped(self, pid):
        path = Path(f"/proc/{pid}/cmdline")
        self.assertTrue(not path.exists() or not path.read_bytes())

    def tearDown(self):
        self.call("stop")
        # Let the old watchers observe the removed pid file before cleanup.
        time.sleep(1.1)
        self.tmp.cleanup()

    def test_stop_during_startup(self):
        pid = self.start()
        self.call("stop")
        self.assertStopped(pid)
        self.assertFalse((self.runtime / "mpv.pid").exists())

    def test_recycled_pid_is_not_killed(self):
        self.runtime.mkdir()
        (self.runtime / "mpv.pid").write_text(str(os.getpid()))
        self.call("stop")
        os.kill(os.getpid(), 0)

    def test_concurrent_next_preserves_state_and_audio(self):
        old = self.start()
        callers = [subprocess.Popen(["bash", str(SCRIPT), "next"], env=self.env) for _ in range(2)]
        for caller in callers:
            self.assertEqual(caller.wait(timeout=25), 0)
        self.assertEqual(self.state()["index"], 2)
        cmdline = Path(f"/proc/{self.pid()}/cmdline").read_bytes().decode()
        self.assertIn(self.queue[2]["videoId"], cmdline)
        self.assertStopped(old)

    def test_stale_mix_cannot_replace_new_track(self):
        self.start(1)
        self.call("requeue", json.dumps([self.queue[0]]), "0", self.queue[0]["videoId"])
        self.assertEqual(self.state()["index"], 1)
        self.assertEqual(json.loads((self.runtime / "queue.json").read_text()), self.queue)

    def test_requeue_keeps_audio_process(self):
        pid = self.start(1)
        self.call("requeue", json.dumps([self.queue[1], self.queue[2]]), "0", self.queue[1]["videoId"])
        self.assertEqual(self.pid(), pid)
        self.assertEqual(self.state()["index"], 0)

    def test_automatic_advance_and_stop_at_queue_end(self):
        pid = self.start(1)
        os.kill(pid, 15)
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline and self.state()["index"] != 2:
            time.sleep(0.1)
        self.assertEqual(self.state()["index"], 2)
        os.kill(self.pid(), 15)
        time.sleep(2)
        self.assertFalse((self.runtime / "mpv.pid").exists())
        self.assertEqual(self.state()["index"], 2)


if __name__ == "__main__":
    unittest.main()
