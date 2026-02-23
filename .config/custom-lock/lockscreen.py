#!/usr/bin/env python3
"""
Custom Lock Screen for Hyprland
"""

import gi
import subprocess
import os
import datetime
import threading
import ctypes
import signal
import glob as globmod
import time
import json

gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')

from gi.repository import Gtk, Gdk, GLib
from gi.repository import Gtk4LayerShell as LayerShell

# Catppuccin Mocha colors
COLORS = {
    'bg': 'rgba(17, 17, 27, 0.8)',
    'fg': '#cdd6f4',
    'fg_dim': '#6c7086',
    'accent': '#89b4fa',
    'green': '#a6e3a1',
    'red': '#f38ba8',
    'yellow': '#f9e2af',
    'surface': 'rgba(30, 30, 46, 0.95)',
    'outer': 'rgba(137, 180, 250, 0.5)',
}

_libc = ctypes.CDLL("libc.so.6")
_libpam = ctypes.CDLL("libpam.so.0")

_libc.calloc.restype = ctypes.c_void_p
_libc.calloc.argtypes = [ctypes.c_size_t, ctypes.c_size_t]
_libc.strdup.restype = ctypes.c_void_p
_libc.strdup.argtypes = [ctypes.c_char_p]

PAM_PROMPT_ECHO_OFF = 1
PAM_SUCCESS = 0

class PamMessage(ctypes.Structure):
    _fields_ = [("msg_style", ctypes.c_int), ("msg", ctypes.c_char_p)]

class PamResponse(ctypes.Structure):
    _fields_ = [("resp", ctypes.c_void_p), ("resp_retcode", ctypes.c_int)]

_conv_func_t = ctypes.CFUNCTYPE(
    ctypes.c_int, ctypes.c_int,
    ctypes.POINTER(ctypes.POINTER(PamMessage)),
    ctypes.POINTER(ctypes.POINTER(PamResponse)),
    ctypes.c_void_p,
)

class PamConv(ctypes.Structure):
    _fields_ = [("conv", _conv_func_t), ("appdata_ptr", ctypes.c_void_p)]

_libpam.pam_start.restype = ctypes.c_int
_libpam.pam_start.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.POINTER(PamConv), ctypes.POINTER(ctypes.c_void_p)]
_libpam.pam_authenticate.restype = ctypes.c_int
_libpam.pam_authenticate.argtypes = [ctypes.c_void_p, ctypes.c_int]
_libpam.pam_end.restype = ctypes.c_int
_libpam.pam_end.argtypes = [ctypes.c_void_p, ctypes.c_int]

def _check_password(user, password):
    """Authenticate via PAM directly using ctypes."""
    pw_bytes = password.encode('utf-8')

    @_conv_func_t
    def _conv(n_messages, messages, p_response, app_data):
        resp_array = _libc.calloc(n_messages, ctypes.sizeof(PamResponse))
        if not resp_array:
            return 1
        p_response[0] = ctypes.cast(resp_array, ctypes.POINTER(PamResponse))
        for i in range(n_messages):
            if messages[i].contents.msg_style == PAM_PROMPT_ECHO_OFF:
                p_response[0][i].resp = _libc.strdup(pw_bytes)
        return PAM_SUCCESS

    conv = PamConv(_conv)
    handle = ctypes.c_void_p()

    ret = _libpam.pam_start(b"login", user.encode('utf-8'), ctypes.byref(conv), ctypes.byref(handle))
    if ret != PAM_SUCCESS:
        return False

    ret = _libpam.pam_authenticate(handle, 0)
    _libpam.pam_end(handle, ret)
    return ret == PAM_SUCCESS


DPMS_TIMEOUT = 30
STATS_FILE = os.path.expanduser("~/.config/custom-lock/stats.json")

MEDIA_KEYS = {
    'XF86AudioRaiseVolume':  ['bash', os.path.expanduser('~/.config/hypr/scripts/Volume.sh'), '--inc'],
    'XF86AudioLowerVolume':  ['bash', os.path.expanduser('~/.config/hypr/scripts/Volume.sh'), '--dec'],
    'XF86AudioMute':         ['bash', os.path.expanduser('~/.config/hypr/scripts/Volume.sh'), '--toggle'],
    'XF86AudioMicMute':      ['bash', os.path.expanduser('~/.config/hypr/scripts/Volume.sh'), '--toggle-mic'],
    'XF86AudioPlay':         ['bash', os.path.expanduser('~/.config/hypr/scripts/MediaCtrl.sh'), '--pause'],
    'XF86AudioPause':        ['bash', os.path.expanduser('~/.config/hypr/scripts/MediaCtrl.sh'), '--pause'],
    'XF86AudioPlayPause':    ['bash', os.path.expanduser('~/.config/hypr/scripts/MediaCtrl.sh'), '--pause'],
    'XF86AudioNext':         ['bash', os.path.expanduser('~/.config/hypr/scripts/MediaCtrl.sh'), '--nxt'],
    'XF86AudioPrev':         ['bash', os.path.expanduser('~/.config/hypr/scripts/MediaCtrl.sh'), '--prv'],
    'XF86AudioStop':         ['bash', os.path.expanduser('~/.config/hypr/scripts/MediaCtrl.sh'), '--stop'],
    'XF86MonBrightnessUp':   ['bash', os.path.expanduser('~/.config/hypr/scripts/Brightness.sh'), '--inc'],
    'XF86MonBrightnessDown': ['bash', os.path.expanduser('~/.config/hypr/scripts/Brightness.sh'), '--dec'],
    'XF86KbdBrightnessUp':   ['bash', os.path.expanduser('~/.config/hypr/scripts/BrightnessKbd.sh'), '--inc'],
    'XF86KbdBrightnessDown': ['bash', os.path.expanduser('~/.config/hypr/scripts/BrightnessKbd.sh'), '--dec'],
}


class LockScreen(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='com.custom.lockscreen')
        subprocess.run(['hyprctl', 'dispatch', 'submap', 'lockscreen'], capture_output=True)
        self.show_password = False
        self.is_typing = False
        self._syncing = False
        self._fail_count = 0
        self._locked_until = 0
        self._lockout_timer_id = None
        self._dpms_off = False
        self._dpms_timeout_id = None
        self.quote = self.get_quote()
        self.windows = []
        self.revealers = []
        self.date_labels = []
        self.battery_labels = []
        self.hour_labels = []
        self.minute_labels = []
        self.password_entries = []
        self.error_labels = []
        self.capslock_labels = []
        self.view_buttons = []
        self.password_frames = []
        self.streak_labels = []
        self.unlock_count = self._load_stats()
        self.wallpaper_path = os.path.expanduser("~/.config/hypr/wallpaper_effects/.wallpaper_current")

        signal.signal(signal.SIGTERM, self._on_signal)
        signal.signal(signal.SIGINT, self._on_signal)

    def _on_signal(self, signum, frame):
        subprocess.run(['hyprctl', 'dispatch', 'submap', 'reset'], capture_output=True)
        subprocess.run(['hyprctl', 'dispatch', 'dpms', 'on'], capture_output=True)
        self.quit()

    def _load_stats(self):
        try:
            with open(STATS_FILE, 'r') as f:
                return json.load(f).get('unlocks', 0)
        except:
            return 0

    def _save_stats(self):
        try:
            os.makedirs(os.path.dirname(STATS_FILE), exist_ok=True)
            with open(STATS_FILE, 'w') as f:
                json.dump({'unlocks': self.unlock_count}, f)
        except:
            pass

    def get_quote(self):
        quote_script = os.path.expanduser("~/.config/hypr/scripts/RandomQuote.sh")
        try:
            if os.path.exists(quote_script):
                result = subprocess.run(['bash', quote_script], capture_output=True, text=True, timeout=2)
                return result.stdout.strip() or "The supreme art of war is to subdue the enemy without fighting."
        except:
            pass
        return "The supreme art of war is to subdue the enemy without fighting."

    def get_battery(self):
        try:
            for path in globmod.glob('/sys/class/power_supply/*/capacity'):
                with open(path, 'r') as f:
                    capacity = int(f.read().strip())
                status_path = os.path.join(os.path.dirname(path), 'status')
                status = ""
                try:
                    with open(status_path, 'r') as f:
                        status = f.read().strip()
                except:
                    pass
                charging = status in ("Charging", "Full")
                if charging:
                    icons = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
                else:
                    icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
                icon_idx = min(capacity // 10, 10)
                return f"{icons[icon_idx]} {capacity}%"
        except:
            pass
        return "󰁹 --"

    def get_date(self):
        now = datetime.datetime.now()
        return now.strftime("%A, %b %-d")

    def get_time(self):
        now = datetime.datetime.now()
        return now.strftime("%H"), now.strftime("%M")

    def create_blurred_wallpaper(self):
        try:
            blurred_path = "/tmp/lockscreen_blurred.png"
            if os.path.exists(self.wallpaper_path):
                wall_mtime = os.path.getmtime(self.wallpaper_path)
                if os.path.exists(blurred_path):
                    blur_mtime = os.path.getmtime(blurred_path)
                    if blur_mtime > wall_mtime:
                        return blurred_path
                subprocess.run([
                    'magick', self.wallpaper_path,
                    '-resize', '1920x1080>',
                    '-blur', '0x3',
                    '-brightness-contrast', '-15x0',
                    blurred_path
                ], capture_output=True, timeout=10)
                if os.path.exists(blurred_path):
                    return blurred_path
        except:
            pass
        return None

    def do_activate(self):
        self.blurred_wallpaper = self.create_blurred_wallpaper()

        display = Gdk.Display.get_default()
        monitors = display.get_monitors()

        for i in range(monitors.get_n_items()):
            monitor = monitors.get_item(i)
            win = self.create_lock_window(monitor)
            self.windows.append(win)
            win.present()

        self.apply_css()
        self.update_time()
        GLib.timeout_add_seconds(1, self.update_time)
        self._reset_dpms_timer()

    def create_lock_window(self, monitor):
        win = Gtk.ApplicationWindow(application=self)

        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_monitor(win, monitor)
        LayerShell.set_exclusive_zone(win, -1)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)
        LayerShell.set_namespace(win, "lockscreen")

        LayerShell.set_anchor(win, LayerShell.Edge.TOP, True)
        LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_anchor(win, LayerShell.Edge.LEFT, True)
        LayerShell.set_anchor(win, LayerShell.Edge.RIGHT, True)

        overlay = Gtk.Overlay()
        overlay.set_vexpand(True)
        overlay.set_hexpand(True)

        if self.blurred_wallpaper and os.path.exists(self.blurred_wallpaper):
            bg_picture = Gtk.Picture.new_for_filename(self.blurred_wallpaper)
            bg_picture.set_content_fit(Gtk.ContentFit.COVER)
            bg_picture.set_can_shrink(True)
            overlay.set_child(bg_picture)
        else:
            bg_box = Gtk.Box()
            bg_box.add_css_class('fallback-bg')
            overlay.set_child(bg_box)

        dark_overlay = Gtk.Box()
        dark_overlay.add_css_class('dark-overlay')
        dark_overlay.set_vexpand(True)
        dark_overlay.set_hexpand(True)
        overlay.add_overlay(dark_overlay)

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        main_box.set_valign(Gtk.Align.FILL)
        main_box.set_halign(Gtk.Align.FILL)
        main_box.set_vexpand(True)
        main_box.set_hexpand(True)

        view = self.create_lock_view()
        main_box.append(view)
        overlay.add_overlay(main_box)

        win.set_child(overlay)

        key_controller = Gtk.EventControllerKey()
        key_controller.connect('key-pressed', self.on_key_press)
        win.add_controller(key_controller)

        return win

    def create_top_bar(self):
        top_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        top_bar.set_halign(Gtk.Align.FILL)
        top_bar.set_hexpand(True)
        top_bar.set_margin_top(40)
        top_bar.set_margin_start(50)
        top_bar.set_margin_end(50)

        date_label = Gtk.Label(label=self.get_date())
        date_label.add_css_class('top-text')
        date_label.set_halign(Gtk.Align.START)
        self.date_labels.append(date_label)
        top_bar.append(date_label)

        quote_label = Gtk.Label(label=f'"{self.quote}"')
        quote_label.add_css_class('top-text')
        quote_label.add_css_class('quote')
        quote_label.set_halign(Gtk.Align.CENTER)
        quote_label.set_hexpand(True)
        quote_label.set_ellipsize(3)
        top_bar.append(quote_label)

        battery_label = Gtk.Label(label=self.get_battery())
        battery_label.add_css_class('top-text')
        battery_label.add_css_class('battery')
        battery_label.set_halign(Gtk.Align.END)
        self.battery_labels.append(battery_label)
        top_bar.append(battery_label)

        return top_bar

    def create_lock_view(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.set_valign(Gtk.Align.FILL)
        box.set_halign(Gtk.Align.FILL)
        box.set_vexpand(True)
        box.set_hexpand(True)

        box.append(self.create_top_bar())

        spacer1 = Gtk.Box()
        spacer1.set_vexpand(True)
        box.append(spacer1)

        center_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        center_box.set_halign(Gtk.Align.CENTER)
        center_box.set_valign(Gtk.Align.CENTER)

        hour, minute = self.get_time()

        hour_label = Gtk.Label(label=hour)
        hour_label.add_css_class('time-large')
        self.hour_labels.append(hour_label)
        center_box.append(hour_label)

        # Revealer slides password area between hour and minute
        revealer = Gtk.Revealer()
        revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        revealer.set_transition_duration(200)
        revealer.set_reveal_child(False)
        self.revealers.append(revealer)

        password_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        password_box.set_halign(Gtk.Align.CENTER)
        password_box.set_spacing(10)
        password_box.set_margin_top(15)
        password_box.set_margin_bottom(15)

        # Password frame with entry + view button
        password_frame = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        password_frame.add_css_class('password-frame')
        password_frame.set_halign(Gtk.Align.CENTER)
        password_frame.set_valign(Gtk.Align.CENTER)
        self.password_frames.append(password_frame)

        password_entry = Gtk.Entry()
        password_entry.set_visibility(False)
        password_entry.set_invisible_char('●')
        password_entry.set_alignment(0.5)
        password_entry.set_hexpand(False)
        password_entry.set_width_chars(8)
        password_entry.set_max_width_chars(0)
        password_entry.add_css_class('password-entry')
        password_entry.connect('activate', self.on_entry_activate)
        password_entry.connect('changed', self.on_entry_changed)
        self.password_entries.append(password_entry)

        view_btn = Gtk.Button(label="󰈈")
        view_btn.add_css_class('view-btn')
        view_btn.set_focusable(False)
        view_btn.connect('clicked', self.toggle_password_visibility)
        self.view_buttons.append(view_btn)

        password_frame.append(password_entry)
        password_frame.append(view_btn)
        password_box.append(password_frame)

        capslock_label = Gtk.Label()
        capslock_label.add_css_class('capslock')
        self.capslock_labels.append(capslock_label)
        password_box.append(capslock_label)

        error_label = Gtk.Label()
        error_label.add_css_class('error')
        self.error_labels.append(error_label)
        password_box.append(error_label)

        revealer.set_child(password_box)
        center_box.append(revealer)

        minute_label = Gtk.Label(label=minute)
        minute_label.add_css_class('time-large')
        self.minute_labels.append(minute_label)
        center_box.append(minute_label)

        box.append(center_box)

        spacer2 = Gtk.Box()
        spacer2.set_vexpand(True)
        box.append(spacer2)

        streak_label = Gtk.Label(label=f"󰍁 {self.unlock_count:,} unlocks")
        streak_label.add_css_class('streak')
        streak_label.set_halign(Gtk.Align.CENTER)
        streak_label.set_margin_bottom(40)
        self.streak_labels.append(streak_label)
        box.append(streak_label)

        return box

    def apply_css(self):
        css = f"""
        .fallback-bg {{
            background-color: rgb(17, 17, 27);
        }}

        .dark-overlay {{
            background-color: rgba(0, 0, 0, 0.4);
        }}

        .top-text {{
            font-family: "JetBrainsMono Nerd Font";
            font-size: 24px;
            font-weight: 500;
            color: {COLORS['fg']};
        }}

        .quote {{
            font-style: italic;
            color: {COLORS['accent']};
        }}

        .battery {{
            color: {COLORS['green']};
        }}

        .time-large {{
            font-family: "JetBrainsMono Nerd Font Mono";
            font-size: 200px;
            font-weight: 800;
            color: {COLORS['fg']};
            margin: -35px 0;
        }}

        .password-frame {{
            background-color: {COLORS['surface']};
            border: 3px solid {COLORS['outer']};
            border-radius: 25px;
            min-width: 200px;
            min-height: 50px;
            padding: 5px 15px;
        }}

        entry.password-entry {{
            font-family: "JetBrainsMono Nerd Font Mono";
            font-size: 28px;
            color: {COLORS['fg']};
            letter-spacing: 8px;
            background: none;
            background-color: transparent;
            border: none;
            border-image: none;
            box-shadow: none;
            outline: none;
            outline-style: none;
            caret-color: {COLORS['accent']};
            min-height: 0;
            padding: 0 5px;
            margin: 0;
        }}

        entry.password-entry:focus {{
            background: none;
            background-color: transparent;
            border: none;
            box-shadow: none;
            outline: none;
            outline-style: none;
        }}

        entry.password-entry > text {{
            background: none;
            background-color: transparent;
            border: none;
            box-shadow: none;
            outline: none;
            outline-style: none;
            min-height: 0;
        }}

        entry.password-entry > text > selection {{
            background-color: rgba(137, 180, 250, 0.3);
        }}

        entry.password-entry > text > cursor {{
            color: {COLORS['accent']};
        }}

        .view-btn {{
            font-family: "JetBrainsMono Nerd Font Mono";
            font-size: 22px;
            color: {COLORS['fg_dim']};
            background: none;
            background-color: transparent;
            border: none;
            box-shadow: none;
            min-width: 40px;
            min-height: 40px;
            padding: 0;
            margin: 0;
        }}

        .view-btn:hover {{
            color: {COLORS['fg']};
        }}

        .capslock {{
            font-family: "JetBrainsMono Nerd Font";
            font-size: 14px;
            color: {COLORS['yellow']};
        }}

        .error {{
            font-family: "JetBrainsMono Nerd Font";
            font-size: 14px;
            color: {COLORS['red']};
        }}

        @keyframes shake {{
            0%   {{ margin-left: 0px; }}
            15%  {{ margin-left: -12px; }}
            30%  {{ margin-left: 12px; }}
            45%  {{ margin-left: -8px; }}
            60%  {{ margin-left: 8px; }}
            75%  {{ margin-left: -4px; }}
            90%  {{ margin-left: 4px; }}
            100% {{ margin-left: 0px; }}
        }}

        .shake {{
            animation: shake 0.4s ease-in-out;
        }}

        .password-frame-error {{
            border: 3px solid {COLORS['red']};
        }}

        .streak {{
            font-family: "JetBrainsMono Nerd Font";
            font-size: 14px;
            color: {COLORS['fg_dim']};
        }}
        """

        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )

    def update_time(self):
        hour, minute = self.get_time()
        date = self.get_date()
        battery = self.get_battery()

        for label in self.date_labels:
            label.set_text(date)
        for label in self.battery_labels:
            label.set_text(battery)
        for label in self.hour_labels:
            label.set_text(hour)
        for label in self.minute_labels:
            label.set_text(minute)

        return True

    def update_capslock(self):
        try:
            display = Gdk.Display.get_default()
            seat = display.get_default_seat()
            keyboard = seat.get_keyboard()
            caps_on = keyboard.get_caps_lock_state() if keyboard else False
        except:
            caps_on = False

        text = "󰪛 Caps Lock is on" if caps_on else ""
        for label in self.capslock_labels:
            label.set_text(text)

    def toggle_password_visibility(self, btn):
        self.show_password = not self.show_password
        icon = "󰈈" if not self.show_password else "󰈉"
        for b in self.view_buttons:
            b.set_label(icon)
        for entry in self.password_entries:
            entry.set_visibility(self.show_password)
            if not self.show_password:
                entry.set_invisible_char('●')

    def shake_password(self):
        for frame in self.password_frames:
            frame.add_css_class('shake')
            frame.add_css_class('password-frame-error')
        GLib.timeout_add(400, self._remove_shake)

    def _remove_shake(self):
        for frame in self.password_frames:
            frame.remove_css_class('shake')
            frame.remove_css_class('password-frame-error')
        return False

    def switch_view(self, view_name):
        reveal = view_name == "typing"
        for revealer in self.revealers:
            revealer.set_reveal_child(reveal)

    # -- DPMS -----------------------------------------------------------------

    def _reset_dpms_timer(self):
        if self._dpms_timeout_id:
            GLib.source_remove(self._dpms_timeout_id)
        self._dpms_timeout_id = GLib.timeout_add_seconds(DPMS_TIMEOUT, self._dpms_turn_off)

    def _dpms_turn_off(self):
        subprocess.run(['hyprctl', 'dispatch', 'dpms', 'off'], capture_output=True)
        self._dpms_off = True
        self._dpms_timeout_id = None
        return False

    def _dpms_turn_on(self):
        if self._dpms_off:
            subprocess.run(['hyprctl', 'dispatch', 'dpms', 'on'], capture_output=True)
            self._dpms_off = False

    # -- Key handling ---------------------------------------------------------

    def on_key_press(self, controller, keyval, keycode, state):
        self._reset_dpms_timer()

        # Wake screen on any key, but consume it
        if self._dpms_off:
            self._dpms_turn_on()
            return True

        keyname = Gdk.keyval_name(keyval)

        if keyname in ('Shift_L', 'Shift_R', 'Control_L', 'Control_R',
                       'Alt_L', 'Alt_R', 'Super_L', 'Super_R',
                       'Num_Lock', 'Scroll_Lock'):
            return True

        if keyname == 'Caps_Lock':
            GLib.timeout_add(50, self.update_capslock)
            return True

        # Media keys — run the command directly
        if keyname in MEDIA_KEYS:
            subprocess.Popen(MEDIA_KEYS[keyname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True

        if keyname == 'Escape':
            self.show_password = False
            self.is_typing = False
            self._syncing = True
            for entry in self.password_entries:
                entry.set_text("")
                entry.set_visibility(False)
                entry.set_invisible_char('●')
            self._syncing = False
            for label in self.error_labels:
                label.set_text("")
            for label in self.capslock_labels:
                label.set_text("")
            for b in self.view_buttons:
                b.set_label("󰈈")
            self.switch_view("idle")
            return True

        # If not typing yet, switch to typing view and focus the entry
        if not self.is_typing:
            is_printable = (keyval >= 32 and keyval <= 126) or keyname == 'space'
            if is_printable:
                self.is_typing = True
                self.switch_view("typing")
                self.update_capslock()
                entry = self.password_entries[0] if self.password_entries else None
                for e in self.password_entries:
                    win = e.get_root()
                    if win and win.is_active():
                        entry = e
                        break
                if entry:
                    entry.grab_focus()
                    char = chr(keyval) if keyval >= 32 and keyval <= 126 else ' '
                    entry.set_text(char)
                    entry.set_position(-1)
                return True

        # Let the entry handle all other keys when in typing mode
        return False

    def on_entry_activate(self, entry):
        self.try_unlock()

    def on_entry_changed(self, entry):
        if self._syncing:
            return
        text = entry.get_text()
        # Resize all entries to fit content (extra padding for letter-spacing)
        chars = max(len(text) + len(text) // 2 + 2, 8)
        self._syncing = True
        for e in self.password_entries:
            e.set_width_chars(chars)
            if e is not entry:
                e.set_text(text)
        self._syncing = False
        # Switch back to idle if password fully deleted
        if not text and self.is_typing:
            self.is_typing = False
            self.switch_view("idle")

    # -- Authentication -------------------------------------------------------

    def try_unlock(self):
        now = time.time()
        if now < self._locked_until:
            remaining = int(self._locked_until - now) + 1
            for label in self.error_labels:
                label.set_text(f"󰅜 Try again in {remaining}s")
            return

        password = self.password_entries[0].get_text() if self.password_entries else ""
        if not password:
            return

        user = os.environ.get('USER', 'aarav')

        def auth_thread():
            success = _check_password(user, password)
            GLib.idle_add(self._on_auth_result, success)

        threading.Thread(target=auth_thread, daemon=True).start()

    def _on_auth_result(self, success):
        if success:
            self.unlock_count += 1
            self._save_stats()
            self.quit()
        else:
            self._fail_count += 1
            delay = min(2 ** (self._fail_count - 1), 30) if self._fail_count > 1 else 0

            self.shake_password()

            if delay > 0:
                self._locked_until = time.time() + delay
                for label in self.error_labels:
                    label.set_text(f"󰅜 Wrong password · wait {delay}s")
                self._start_lockout_countdown()
            else:
                for label in self.error_labels:
                    label.set_text("󰅜 Wrong password")

            self._syncing = True
            for entry in self.password_entries:
                entry.set_text("")
            self._syncing = False
        return False

    def _start_lockout_countdown(self):
        if self._lockout_timer_id:
            GLib.source_remove(self._lockout_timer_id)
        self._lockout_timer_id = GLib.timeout_add_seconds(1, self._update_lockout_countdown)

    def _update_lockout_countdown(self):
        remaining = int(self._locked_until - time.time())
        if remaining <= 0:
            for label in self.error_labels:
                label.set_text("")
            self._lockout_timer_id = None
            return False
        for label in self.error_labels:
            label.set_text(f"󰅜 Try again in {remaining}s")
        return True


if __name__ == '__main__':
    app = LockScreen()
    app.run()
