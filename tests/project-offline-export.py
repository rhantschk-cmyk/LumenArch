#!/usr/bin/env python3
"""Fixture tests for an immutable Lumen offline snapshot recovery kit."""
import hashlib
import json
import subprocess
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT_DIR / "system/usr/lib/lumen/lumen-project"
module = SourceFileLoader("lumen_project_export", str(MODULE_PATH)).load_module()


def fail(message):
    raise SystemExit(f"FAIL: {message}")


def digest_tree(root):
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*")) if path.is_file()
    }


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
    exports = base / "exports"
    exports.mkdir()
    before = digest_tree(base)

    def successful_run(command, check=True, **kwargs):
        if command[0] == "repo-add":
            Path(command[1]).write_bytes(("database\n" + "\n".join(command[2:])).encode())
        return type("Result", (), {"returncode": 0})()

    module.run = successful_run
    kit = exports / "demo-v000001"
    module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(kit))
    expected = {
        "RECOVERY.md",
        "SHA256SUMS",
        "metadata/snapshot.tar.zst",
        "metadata/project.lumen",
        "metadata/package-lock.json",
        "packages/bash-1.0-1-x86_64.pkg.tar.zst",
        "packages/lumen-local.db.tar.gz",
        "packages/lumen-local.db",
    }
    actual = {path.relative_to(kit).as_posix() for path in kit.rglob("*") if path.is_file()}
    actual == expected or fail(f"unexpected kit contents: {actual!r}")
    source_after = digest_tree(base)
    for path, digest in before.items():
        source_after.get(path) == digest or fail(f"source state changed: {path}")
    sums = {}
    for line in (kit / "SHA256SUMS").read_text().splitlines():
        digest, relative = line.split("  ", 1)
        sums[relative] = digest
    set(sums) == expected - {"SHA256SUMS"} or fail("checksum manifest does not cover every payload file")
    for relative, digest in sums.items():
        hashlib.sha256((kit / relative).read_bytes()).hexdigest() == digest or fail(f"invalid checksum for {relative}")

    lock = project / "locks/v000001.json"
    original_lock = lock.read_text()
    archive.write_bytes(b"changed archive")
    try:
        module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(exports / "checksum-changed"))
    except SystemExit:
        pass
    else:
        fail("checksum-changed archive was accepted")
    not (exports / "checksum-changed").exists() or fail("checksum failure created a kit")
    archive.write_bytes(b"local archive")

    lock.write_text(json.dumps({"packages": [{"name": "bash", "archive": "../unsafe.pkg.tar.zst", "sha256": checksum}]}))
    try:
        module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(exports / "unsafe-lock"))
    except SystemExit:
        pass
    else:
        fail("unsafe archive name was accepted")
    not (exports / "unsafe-lock").exists() or fail("unsafe lock created a kit")
    lock.write_text(original_lock)

    archive.unlink()
    try:
        module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(exports / "missing-archive"))
    except SystemExit:
        pass
    else:
        fail("missing archive was accepted")
    not (exports / "missing-archive").exists() or fail("missing archive created a kit")
    archive.write_bytes(b"local archive")

    blocked = exports / "blocked"
    blocked.mkdir()
    (blocked / "keep").write_text("keep")
    try:
        module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(blocked))
    except SystemExit:
        pass
    else:
        fail("non-empty export destination was accepted")
    (blocked / "keep").exists() or fail("destination refusal modified existing content")

    try:
        module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(exports / ".." / "traversal"))
    except SystemExit:
        pass
    else:
        fail("destination traversal was accepted")
    symlink = exports / "symlink"
    symlink.symlink_to(exports / "linked")
    try:
        module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(symlink))
    except SystemExit:
        pass
    else:
        fail("symlinked destination was accepted")

    failure = exports / "failed-kit"

    def failing_repo_add(command, check=True, **kwargs):
        if command[0] == "repo-add":
            raise subprocess.CalledProcessError(47, command)
        return type("Result", (), {"returncode": 0})()

    module.run = failing_repo_add
    try:
        module.export_snapshot(ident, {"name": "Demo"}, "v000001", str(failure))
    except subprocess.CalledProcessError:
        pass
    else:
        fail("repo-add failure was accepted")
    not failure.exists() or fail("failed export left a completed-looking kit")

print("Project offline export tests passed.")
