#!/usr/bin/env python3
import json
import os
import subprocess
import threading

import gi
gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk


class LumenInstaller(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.lumen.installer")
        self.connect("activate", self.activate)

    def disks(self):
        rows = subprocess.check_output(
            ["lsblk", "-dn", "-o", "PATH,SIZE,MODEL,TYPE"], text=True
        ).splitlines()
        live_source = subprocess.run(
            ["findmnt", "-nro", "SOURCE", "/run/archiso/bootmnt"],
            text=True, capture_output=True, check=False,
        ).stdout.strip()
        live_disk = ""
        if live_source.startswith("/dev/"):
            live_source = os.path.realpath(live_source)
            parent = subprocess.run(
                ["lsblk", "-ndo", "PKNAME", live_source],
                text=True, capture_output=True, check=False,
            ).stdout.strip()
            live_disk = f"/dev/{parent}" if parent else live_source
        return [row.strip() for row in rows
                if row.strip().endswith(" disk") and row.split()[0] != live_disk]

    def activate(self, *_):
        window = Gtk.ApplicationWindow(application=self, title="Lumen Arch Installer")
        window.fullscreen()
        box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=14,
            margin_top=40,
            margin_bottom=40,
            margin_start=80,
            margin_end=80,
        )
        title = Gtk.Label(label="LUMEN ARCH", xalign=0)
        title.add_css_class("title-1")
        box.append(title)
        development_iso = os.path.exists("/opt/lumen/DEVELOPMENT_ISO")
        box.append(Gtk.Label(
            label=("Development ISO — graphical installer preview; disk installation is disabled."
                   if development_iso else
                   "A focused, offline-first desktop — installed entirely from this USB."),
            xalign=0,
        ))

        grid = Gtk.Grid(row_spacing=10, column_spacing=18, margin_top=16)
        self.user = Gtk.Entry(placeholder_text="Username", hexpand=True)
        self.userpass = Gtk.PasswordEntry(placeholder_text="User password", hexpand=True)
        self.rootpass = Gtk.PasswordEntry(placeholder_text="Root password", hexpand=True)
        self.timezone = Gtk.Entry(
            placeholder_text="Timezone, e.g. Europe/Berlin",
            text="Europe/Berlin",
            hexpand=True,
        )
        self.hostname = Gtk.Entry(placeholder_text="Hostname", text="lumen", hexpand=True)
        self.keymap = Gtk.Entry(placeholder_text="Console keymap", text="de", hexpand=True)
        self.filesystem = Gtk.DropDown.new_from_strings(["ext4", "btrfs"])
        self.disk = Gtk.DropDown.new_from_strings(self.disks() or ["No safe disk detected"])
        fields = [
            ("Username", self.user),
            ("User password", self.userpass),
            ("Root password", self.rootpass),
            ("Timezone", self.timezone),
            ("Hostname", self.hostname),
            ("Console keyboard", self.keymap),
            ("Filesystem", self.filesystem),
            ("Target disk — WILL BE ERASED", self.disk),
        ]
        for row, (label, widget) in enumerate(fields):
            grid.attach(Gtk.Label(label=label, xalign=0), 0, row, 1, 1)
            grid.attach(widget, 1, row, 1, 1)
        box.append(grid)

        profiles = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12, margin_top=8)
        profiles.append(Gtk.Label(label="Included profiles", xalign=0))
        self.profile_checks = {}
        for profile, label in [("developer", "Developer"), ("creator", "Creator"),
                               ("gaming", "Gaming")]:
            check = Gtk.CheckButton(label=label, active=True)
            self.profile_checks[profile] = check
            profiles.append(check)
        box.append(profiles)

        warning = Gtk.Label(
            label="All data on the selected disk will be permanently deleted. "
                  "Packages are installed from this USB; no target network is used.",
            wrap=True,
            xalign=0,
        )
        warning.add_css_class("error")
        box.append(warning)

        self.status = Gtk.Label(
            label="Ready. Network is not required after this point.", xalign=0, wrap=True
        )
        box.append(self.status)
        self.install_button = Gtk.Button(label="Erase disk and install Lumen", halign=Gtk.Align.START)
        self.install_button.add_css_class("suggested-action")
        self.install_button.connect("clicked", self.confirm)
        self.install_button.set_sensitive(not development_iso)
        box.append(self.install_button)

        self.close_button = Gtk.Button(
            label="Close installer and return to console",
            halign=Gtk.Align.START,
            visible=False,
        )
        self.close_button.connect("clicked", lambda *_: self.quit())
        box.append(self.close_button)

        self.reboot_button = Gtk.Button(
            label="Reboot now and remove the USB drive",
            halign=Gtk.Align.START,
            visible=False,
        )
        self.reboot_button.add_css_class("suggested-action")
        self.reboot_button.connect("clicked", lambda *_: subprocess.Popen(["systemctl", "reboot"]))
        box.append(self.reboot_button)

        self.log_buffer = Gtk.TextBuffer()
        self.log_view = Gtk.TextView(
            buffer=self.log_buffer, editable=False, cursor_visible=False, monospace=True, vexpand=True
        )
        self.log_window = Gtk.ScrolledWindow(vexpand=True, min_content_height=260, visible=False)
        self.log_window.set_child(self.log_view)
        box.append(self.log_window)
        window.set_child(box)
        window.present()

    def confirm(self, *_):
        disk = self.disk.get_selected_item().get_string()
        if (not self.user.get_text() or not self.userpass.get_text() or not self.rootpass.get_text()
                or not self.hostname.get_text() or not self.keymap.get_text() or not disk.startswith("/dev/")):
            self.status.set_text("Enter username, passwords, hostname, keyboard and select a safe target disk.")
            return
        dialog = Gtk.AlertDialog(
            message="Erase " + disk.split()[0] + "?",
            detail="This permanently destroys all partitions and data on that disk.",
            buttons=["Cancel", "Erase and install"],
        )
        dialog.choose(self.get_active_window(), None, self.start)

    def start(self, dialog, result):
        if dialog.choose_finish(result) != 1:
            return
        config = {
            "username": self.user.get_text(),
            "user_password": self.userpass.get_text(),
            "root_password": self.rootpass.get_text(),
            "timezone": self.timezone.get_text(),
            "hostname": self.hostname.get_text(),
            "keymap": self.keymap.get_text(),
            "filesystem": self.filesystem.get_selected_item().get_string(),
            "profiles": [name for name, check in self.profile_checks.items() if check.get_active()],
            "disk": self.disk.get_selected_item().get_string().split()[0],
        }
        os.makedirs("/run/lumen-installer", exist_ok=True)
        path = "/run/lumen-installer/config.json"
        with open(path, "w", encoding="utf-8") as file:
            json.dump(config, file)
        os.chmod(path, 0o600)
        self.status.set_text("Installing Lumen. Do not power off…")
        self.install_button.set_sensitive(False)
        self.log_window.set_visible(True)
        self.log_buffer.set_text("Starting offline installation…\n")
        threading.Thread(target=self.run_install, args=(path,), daemon=True).start()

    def append_log(self, line):
        self.log_buffer.insert(self.log_buffer.get_end_iter(), line)
        self.log_view.scroll_to_iter(self.log_buffer.get_end_iter(), 0.0, False, 0.0, 1.0)
        return False

    def finish_install(self, code, last_line):
        if code == 0:
            self.status.set_text("Installation complete — reboot and remove the USB.")
            self.reboot_button.set_visible(True)
        else:
            detail = last_line or "No log line was produced."
            self.status.set_text(f"Installation failed (exit {code}): {detail}")
            self.close_button.set_visible(True)
        return False

    def run_install(self, path):
        process = subprocess.Popen(
            ["/usr/local/bin/lumen-offline-install", path],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        last_line = ""
        for line in process.stdout:
            if line.strip():
                last_line = line.strip()
            GLib.idle_add(self.append_log, line)
        GLib.idle_add(self.finish_install, process.wait(), last_line)


app = LumenInstaller()
app.run(None)
