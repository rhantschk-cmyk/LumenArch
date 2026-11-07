#!/usr/bin/env python3
"""Fixture tests for atomic, local-only recovery-kit snapshot restoration."""
import hashlib
import shutil
import tempfile
from importlib.machinery import SourceFileLoader
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT_DIR / "system/usr/lib/lumen/lumen-project"
module = SourceFileLoader("lumen_project_kit_restore", str(MODULE_PATH)).load_module()


def fail(message):
    raise SystemExit(f"FAIL: {message}")


def digest_tree(root):
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*")) if path.is_file()
    }


with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    kit = base / "kit"
    snapshot = kit / "metadata" / "snapshot.tar.zst"
    snapshot.parent.mkdir(parents=True)
    snapshot.write_bytes(b"snapshot")
    destination = base / "recovered"
    kit_before = digest_tree(kit)
    verified = []
    unsafe = {"value": False}
    unsafe_path = {"value": ""}
    extraction_fails = {"value": False}
    calls = []

    def fake_verify(value):
        verified.append(value)
        return kit, [], ["bash"]

    def fake_run(command, check=True, **kwargs):
        calls.append(command)
        if command[:4] == ["tar", "--zstd", "-tf", str(snapshot)]:
            name = unsafe_path["value"] or "workspace/readme.txt"
            return type("Result", (), {"returncode": 0, "stdout": f"workspace/\n{name}\n"})()
        if command[:4] == ["tar", "--zstd", "-tvf", str(snapshot)]:
            kind = "l" if unsafe["value"] else "-"
            return type("Result", (), {"returncode": 0, "stdout": f"drwxr-xr-x root/root 0 2026-01-01 00:00 workspace/\n{kind}rw-r--r-- root/root 5 2026-01-01 00:00 workspace/readme.txt\n"})()
        if command[:2] == ["tar", "--zstd"] and "-xf" in command:
            target = Path(command[command.index("-C") + 1])
            if extraction_fails["value"]:
                return type("Result", (), {"returncode": 7, "stdout": ""})()
            (target / "workspace").mkdir()
            (target / "workspace" / "readme.txt").write_text("hello\n")
            return type("Result", (), {"returncode": 0, "stdout": ""})()
        fail(f"unexpected command: {command!r}")

    module.verify_recovery_kit = fake_verify
    module.run = fake_run
    module.restore_recovery_kit(str(kit), str(destination), True)
    verified == [str(kit)] or fail("kit was not fully verified before restoration")
    (destination / "workspace" / "readme.txt").read_text() == "hello\n" or fail("safe snapshot content was not restored")
    digest_tree(kit) == kit_before or fail("restore changed the kit")
    not any("pacman" in call or "lumen-shell" in call for call in calls) or fail("restore invoked package tooling")

    existing = base / "existing-empty"
    existing.mkdir()
    module.restore_recovery_kit(str(kit), str(existing), True)
    (existing / "workspace" / "readme.txt").exists() or fail("empty destination was not atomically published")

    no_confirmation = base / "no-confirmation"
    try:
        module.restore_recovery_kit(str(kit), str(no_confirmation), False)
    except SystemExit as exc:
        exc.code == 2 or fail("missing confirmation used the wrong exit code")
    else:
        fail("restore without --yes was accepted")
    not no_confirmation.exists() or fail("restore without confirmation created a destination")

    unsafe["value"] = True
    unsafe_destination = base / "unsafe"
    try:
        module.restore_recovery_kit(str(kit), str(unsafe_destination), True)
    except SystemExit:
        pass
    else:
        fail("unsafe snapshot link was accepted")
    not unsafe_destination.exists() or fail("unsafe snapshot created a destination")
    unsafe["value"] = False

    for malicious in ("../outside.txt", "/absolute.txt"):
        unsafe_path["value"] = malicious
        malicious_destination = base / f"malicious-{len(malicious)}"
        try:
            module.restore_recovery_kit(str(kit), str(malicious_destination), True)
        except SystemExit:
            pass
        else:
            fail(f"unsafe snapshot path was accepted: {malicious}")
        not malicious_destination.exists() or fail("unsafe snapshot path created a destination")
    unsafe_path["value"] = ""

    extraction_fails["value"] = True
    failed_destination = base / "failed"
    try:
        module.restore_recovery_kit(str(kit), str(failed_destination), True)
    except SystemExit as exc:
        exc.code == 7 or fail("tar failure used the wrong exit code")
    else:
        fail("failed extraction was accepted")
    not failed_destination.exists() or fail("failed extraction left a completed-looking destination")
    extraction_fails["value"] = False

    linked = base / "linked"
    linked.symlink_to(base / "target")
    try:
        module.restore_recovery_kit(str(kit), str(linked), True)
    except SystemExit:
        pass
    else:
        fail("symlinked destination was accepted")

print("Project recovery-kit restore tests passed.")