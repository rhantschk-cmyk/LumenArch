#!/usr/bin/env python3
"""Fixture tests for one saved Lumen project snapshot's offline rehearsal."""
import hashlib
from importlib.machinery import SourceFileLoader
import json
import tempfile
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT_DIR / "system/usr/lib/lumen/lumen-project"
module = SourceFileLoader("lumen_project", str(MODULE_PATH)).load_module()


def fail(message):
    raise SystemExit(f"FAIL: {message}")


with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    module.ROOT = base / "projects"
    module.REPO = base / "repo"
    module.REPO.mkdir(parents=True)
    ident = "demo-1234567890"
    project = module.ROOT / ident
    for child in ("snapshots", "locks", "manifests"):
        (project / child).mkdir(parents=True)
    archive = module.REPO / "bash-1.0-1-x86_64.pkg.tar.zst"
    archive.write_bytes(b"local archive")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (project / "snapshots/v000001.tar.zst").write_bytes(b"snapshot")
    (project / "locks/v000001.json").write_text(json.dumps({"packages": [{"name": "bash", "version": "1.0-1", "archive": archive.name, "sha256": checksum}]}))
    (project / "manifests/v000001.lumen").write_text("[Environment]\nPackages = [\"bash\"]\nMode = \"shell\"\n")
    calls = []

    class Temporary:
        def cleanup(self):
            calls.append(["cleanup"])

    def fake_locked_repository(packages):
        calls.append(["locked", packages])
        return Temporary(), base / "temporary-repo"

    def fake_run(command, check=True, **kwargs):
        calls.append(command)
        return type("Result", (), {"returncode": 0})()

    module.locked_repository = fake_locked_repository
    module.run = fake_run
    module.SHELL = "/mock/lumen-shell"
    module.rehearse_snapshot(ident, {"name": "Demo"}, "v000001")
    command = next(call for call in calls if call and call[0] == "/mock/lumen-shell")
    expected = ["/mock/lumen-shell", "--package", "bash", "--repo-dir", str(base / "temporary-repo"), "--offline-only", "--prepare"]
    command == expected or fail(f"unexpected shell invocation: {command!r}")
    not any("--dir" in call for call in calls if isinstance(call, list)) or fail("rehearsal mounted a workspace")
    ["cleanup"] in calls or fail("temporary repository was not cleaned up")

    def failing_run(command, check=True, **kwargs):
        calls.append(command)
        return type("Result", (), {"returncode": 23})()

    module.run = failing_run
    try:
        module.rehearse_snapshot(ident, {"name": "Demo"}, "v000001")
    except SystemExit as exc:
        exc.code == 23 or fail("failed offline bootstrap used the wrong exit code")
    else:
        fail("missing package closure was accepted")
    calls.count(["cleanup"]) >= 2 or fail("failed rehearsal did not clean up its temporary repository")
    module.run = fake_run

    try:
        module.rehearse_snapshot(ident, {"name": "Demo"}, "../v000001")
    except SystemExit as exc:
        exc.code == 2 or fail("unsafe version selector used the wrong exit code")
    else:
        fail("unsafe version selector was accepted")

    (project / "locks/v000001.json").unlink()
    try:
        module.rehearse_snapshot(ident, {"name": "Demo"}, "v000001")
    except SystemExit:
        pass
    else:
        fail("missing saved lock was accepted")

print("Project offline rehearsal tests passed.")