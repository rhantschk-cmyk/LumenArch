#!/usr/bin/env python3
"""Fixture tests for bootstrapping one verified Lumen recovery kit offline."""
import hashlib
import json
import shutil
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT_DIR / "system/usr/lib/lumen/lumen-project"
module = SourceFileLoader("lumen_project_kit_rehearsal", str(MODULE_PATH)).load_module()


def fail(message):
    raise SystemExit(f"FAIL: {message}")


def digest_tree(root):
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*")) if path.is_file()
    }


def checksum_manifest(kit):
    payloads = sorted(path for path in kit.rglob("*") if path.is_file() and path.name != "SHA256SUMS")
    (kit / "SHA256SUMS").write_text("\n".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(kit).as_posix()}"
        for path in payloads
    ) + "\n")


with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    kit = base / "kit"
    metadata = kit / "metadata"
    packages = kit / "packages"
    metadata.mkdir(parents=True)
    packages.mkdir()
    archive = packages / "bash-1.0-1-x86_64.pkg.tar.zst"
    archive.write_bytes(b"local archive")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (metadata / "snapshot.tar.zst").write_bytes(b"snapshot")
    (metadata / "project.lumen").write_text("[Environment]\nPackages = [\"bash\"]\nMode = \"shell\"\n")
    (metadata / "package-lock.json").write_text(json.dumps({"packages": [{
        "name": "bash", "version": "1.0-1", "archive": archive.name, "sha256": checksum,
    }]}))
    (packages / "lumen-local.db.tar.gz").write_bytes(b"database")
    (packages / "lumen-local.db").write_bytes(b"database")
    (kit / "RECOVERY.md").write_text("Recovery instructions\n")
    checksum_manifest(kit)

    calls = []
    helper_failed = {"value": False}

    def fake_run(command, check=True, **kwargs):
        calls.append(command)
        if command[0] == "tar":
            return type("Result", (), {"returncode": 0, "stdout": ""})()
        if command[:2] == ["pacman", "-Qp"]:
            return type("Result", (), {"returncode": 0, "stdout": "bash 1.0-1\n"})()
        if command[0] == "pacman" and "-Sy" in command:
            return type("Result", (), {"returncode": 0, "stdout": ""})()
        if command[0] == "pacman" and "-Si" in command:
            return type("Result", (), {"returncode": 0, "stdout": "Name            : bash\nVersion         : 1.0-1\n"})()
        if command[0] == "/mock/lumen-shell":
            return type("Result", (), {"returncode": 23 if helper_failed["value"] else 0, "stdout": ""})()
        fail(f"unexpected command: {command!r}")

    module.run = fake_run
    module.shutil.which = lambda name: "/mock/pacman" if name == "pacman" else shutil.which(name)
    module.SHELL = "/mock/lumen-shell"
    before = digest_tree(kit)
    module.rehearse_recovery_kit(str(kit))
    command = next(call for call in calls if call and call[0] == "/mock/lumen-shell")
    expected = ["/mock/lumen-shell", "--package", "bash", "--repo-dir", str(packages), "--offline-only", "--prepare"]
    command == expected or fail(f"unexpected shell invocation: {command!r}")
    not any(argument in ("--dir", "--command", "--lock-file") for call in calls for argument in call) or fail("kit rehearsal mounted or ran project content")
    digest_tree(kit) == before or fail("successful rehearsal changed the kit")

    helper_failed["value"] = True
    try:
        module.rehearse_recovery_kit(str(kit))
    except SystemExit as exc:
        exc.code == 23 or fail("failed kit bootstrap used the wrong exit code")
    else:
        fail("failed kit bootstrap was accepted")
    helper_failed["value"] = False

    helper_calls_before_altered_kit = sum(call and call[0] == "/mock/lumen-shell" for call in calls)
    archive.write_bytes(b"changed archive")
    try:
        module.rehearse_recovery_kit(str(kit))
    except SystemExit:
        pass
    else:
        fail("changed kit archive was accepted")
    sum(call and call[0] == "/mock/lumen-shell" for call in calls) == helper_calls_before_altered_kit or fail("altered kit reached the shell helper")

print("Project recovery-kit rehearsal tests passed.")