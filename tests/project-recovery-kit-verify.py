#!/usr/bin/env python3
"""Fixture tests for read-only verification of a Lumen offline recovery kit."""
import hashlib
import json
import shutil
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT_DIR / "system/usr/lib/lumen/lumen-project"
module = SourceFileLoader("lumen_project_kit_verify", str(MODULE_PATH)).load_module()


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

    stale = {"value": False}
    missing = {"value": False}
    corrupt_snapshot = {"value": False}
    calls = []

    def fake_run(command, check=True, **kwargs):
        calls.append(command)
        if command[0] == "tar":
            return type("Result", (), {"returncode": 2 if corrupt_snapshot["value"] else 0, "stdout": ""})()
        if command[:2] == ["pacman", "-Qp"]:
            return type("Result", (), {"returncode": 0, "stdout": "bash 1.0-1\n"})()
        if command[0] == "pacman" and "-Sy" in command:
            return type("Result", (), {"returncode": 0, "stdout": ""})()
        if command[0] == "pacman" and "-Si" in command:
            if missing["value"]:
                return type("Result", (), {"returncode": 1, "stdout": ""})()
            version = "9.9-9" if stale["value"] else "1.0-1"
            return type("Result", (), {"returncode": 0, "stdout": f"Name            : bash\nVersion         : {version}\n"})()
        fail(f"unexpected command: {command!r}")

    module.run = fake_run
    module.shutil.which = lambda name: "/mock/pacman" if name == "pacman" else shutil.which(name)
    before = digest_tree(kit)
    module.main(["verify-kit", str(kit)])
    digest_tree(kit) == before or fail("valid verification changed the kit")
    any(command[0] == "pacman" and "-Si" in command for command in calls) or fail("database was not queried")

    archive.write_bytes(b"changed archive")
    try:
        module.verify_recovery_kit(str(kit))
    except SystemExit:
        pass
    else:
        fail("changed archive was accepted")
    archive.write_bytes(b"local archive")
    checksum_manifest(kit)

    (kit / "extra").write_text("unexpected")
    try:
        module.verify_recovery_kit(str(kit))
    except SystemExit:
        pass
    else:
        fail("extra kit payload was accepted")
    (kit / "extra").unlink()
    checksum_manifest(kit)

    stale["value"] = True
    try:
        module.verify_recovery_kit(str(kit))
    except SystemExit:
        pass
    else:
        fail("stale local database entry was accepted")
    stale["value"] = False

    missing["value"] = True
    try:
        module.verify_recovery_kit(str(kit))
    except SystemExit:
        pass
    else:
        fail("missing local database entry was accepted")
    missing["value"] = False

    corrupt_snapshot["value"] = True
    try:
        module.verify_recovery_kit(str(kit))
    except SystemExit:
        pass
    else:
        fail("corrupt snapshot was accepted")
    corrupt_snapshot["value"] = False

    (metadata / "snapshot.tar.zst").unlink()
    (metadata / "snapshot.tar.zst").symlink_to("../RECOVERY.md")
    try:
        module.verify_recovery_kit(str(kit))
    except SystemExit:
        pass
    else:
        fail("symlinked snapshot was accepted")

print("Project recovery-kit verification tests passed.")
