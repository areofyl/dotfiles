#!/usr/bin/env python3
"""Minimal custom lock screen for DWL / wlroots compositors.

Nimbus palette — source of truth: ~/.config/nimbus/palette.sh
The COLORS dict below is the canonical origin of the Nimbus scheme;
palette.sh is kept in sync with these values.
"""

import gi
import subprocess
import os
import datetime
import threading
import ctypes
import signal
import random
import time
from PIL import Image, ImageFilter, ImageEnhance

gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')

from gi.repository import Gtk, Gdk, GLib
from gi.repository import Gtk4LayerShell as LayerShell

# Waybar palette
COLORS = {
    'bg':      '#10141a',
    'fg':      '#c4ccd4',
    'dim':     '#5a6470',
    'green':   '#7a9a8a',
    'lavender':'#8a95b0',
    'accent':  '#8ab4d0',
    'surface': 'rgba(16, 20, 26, 0.85)',
}

QUOTES = [
    ('"The supreme art of war is to subdue the enemy without fighting."', "— Sun Tzu, The Art of War"),
    ('"Appear weak when you are strong, and strong when you are weak."', "— Sun Tzu, The Art of War"),
    ('"In the midst of chaos, there is also opportunity."', "— Sun Tzu, The Art of War"),
    ('"Every battle is won before it is ever fought."', "— Sun Tzu, The Art of War"),
    ('"If you know the enemy and know yourself, you need not fear the result of a hundred battles."', "— Sun Tzu, The Art of War"),
    ('"Let your plans be dark and impenetrable as night, and when you move, fall like a thunderbolt."', "— Sun Tzu, The Art of War"),
    ('"Victorious warriors win first and then go to war."', "— Sun Tzu, The Art of War"),
    ('"Not even close, baby. Technoblade never dies."', "— Technoblade"),
    ('"If you wish to defeat me, train for another five hundred years."', "— Technoblade"),
    ('"Officer, I drop-kicked that child in self-defense."', "— Technoblade"),
    ('"I\'m an orphan, Phil. They\'re the second worst thing to ever happen to those orphans."', "— Technoblade"),
    ('"The thing about this world is that it doesn\'t care. You have to make it care."', "— Technoblade"),
]

DPMS_TIMEOUT = 30
FONT = "FantasqueSansM Nerd Font Mono"
WALLPAPER = os.path.expanduser("~/Pictures/wallpapers/clouds.jpg")
BLURRED_PATH = "/tmp/lockscreen_blurred.png"

# -- PAM authentication via ctypes --

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

    ret = _libpam.pam_start(b"custom-lock", user.encode('utf-8'), ctypes.byref(conv), ctypes.byref(handle))
    if ret != PAM_SUCCESS:
        return False

    ret = _libpam.pam_authenticate(handle, 0)
    _libpam.pam_end(handle, ret)
    return ret == PAM_SUCCESS


class LockScreen(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='com.custom.lockscreen')
        self.is_typing = False
        self._syncing = False
        self._fail_count = 0
        self._locked_until = 0
        self._dpms_off = False
        self._dpms_timeout_id = None
        self.quote, self.quote_author = random.choice(QUOTES)
        self.windows = []
        self.content_boxes = []
        self.revealers = []
        self.hour_labels = []
        self.minute_labels = []
        self.password_entries = []
        self.error_labels = []
        self.password_frames = []

        signal.signal(signal.SIGTERM, self._on_signal)
        signal.signal(signal.SIGINT, self._on_signal)

    def _on_signal(self, signum, frame):
        self._dpms_on()
        self.quit()

    def _dpms_on(self):
        if self._dpms_off:
            subprocess.run(['wlr-randr', '--output', 'eDP-1', '--on'], capture_output=True)
            self._dpms_off = False

    def _dpms_off_cmd(self):
        subprocess.run(['wlr-randr', '--output', 'eDP-1', '--off'], capture_output=True)
        self._dpms_off = True
        self._dpms_timeout_id = None
        return False

    def _reset_dpms_timer(self):
        if self._dpms_timeout_id:
            GLib.source_remove(self._dpms_timeout_id)
        self._dpms_timeout_id = GLib.timeout_add_seconds(DPMS_TIMEOUT, self._dpms_off_cmd)

    def _create_blurred_wallpaper(self):
        try:
            if not os.path.exists(WALLPAPER):
                return None
            wall_mtime = os.path.getmtime(WALLPAPER)
            if os.path.exists(BLURRED_PATH):
                if os.path.getmtime(BLURRED_PATH) > wall_mtime:
                    return BLURRED_PATH
            img = Image.open(WALLPAPER)
            img = img.filter(ImageFilter.GaussianBlur(radius=12))
            img = ImageEnhance.Brightness(img).enhance(0.35)
            img.save(BLURRED_PATH)
            return BLURRED_PATH
        except:
            return None

    def do_activate(self):
        self._blurred = self._create_blurred_wallpaper()

        display = Gdk.Display.get_default()
        monitors = display.get_monitors()

        for i in range(monitors.get_n_items()):
            monitor = monitors.get_item(i)
            win = self._create_window(monitor)
            self.windows.append(win)
            win.present()

        self._apply_css()
        self._update_time()
        GLib.timeout_add_seconds(1, self._update_time)
        self._reset_dpms_timer()

    def _create_window(self, monitor):
        win = Gtk.ApplicationWindow(application=self)

        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_monitor(win, monitor)
        LayerShell.set_exclusive_zone(win, -1)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)
        LayerShell.set_namespace(win, "lockscreen")

        for edge in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM,
                     LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(win, edge, True)

        overlay = Gtk.Overlay()
        overlay.set_vexpand(True)
        overlay.set_hexpand(True)

        if self._blurred and os.path.exists(self._blurred):
            bg_picture = Gtk.Picture.new_for_filename(self._blurred)
            bg_picture.set_content_fit(Gtk.ContentFit.COVER)
            bg_picture.set_can_shrink(True)
            overlay.set_child(bg_picture)
        else:
            bg_box = Gtk.Box()
            bg_box.add_css_class('main-bg')
            overlay.set_child(bg_box)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content.set_valign(Gtk.Align.FILL)
        content.set_halign(Gtk.Align.FILL)
        content.set_vexpand(True)
        content.set_hexpand(True)

        view = self._create_view()
        content.append(view)
        self.content_boxes.append(content)
        overlay.add_overlay(content)

        win.set_child(overlay)

        key_controller = Gtk.EventControllerKey()
        key_controller.connect('key-pressed', self._on_key_press)
        win.add_controller(key_controller)

        return win

    def _create_view(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.set_valign(Gtk.Align.FILL)
        box.set_halign(Gtk.Align.FILL)
        box.set_vexpand(True)

        # top spacer
        spacer1 = Gtk.Box()
        spacer1.set_vexpand(True)
        box.append(spacer1)

        # center: clock + password
        center = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        center.set_halign(Gtk.Align.CENTER)
        center.set_valign(Gtk.Align.CENTER)

        hour, minute = self._get_time()

        hour_label = Gtk.Label(label=hour)
        hour_label.add_css_class('time-hour')
        self.hour_labels.append(hour_label)
        center.append(hour_label)

        # password revealer — slides between hour and minute
        revealer = Gtk.Revealer()
        revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        revealer.set_transition_duration(120)
        revealer.set_reveal_child(False)
        self.revealers.append(revealer)

        pw_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        pw_box.set_halign(Gtk.Align.CENTER)
        pw_box.set_spacing(8)
        pw_box.set_margin_top(12)
        pw_box.set_margin_bottom(12)

        pw_frame = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        pw_frame.add_css_class('pw-frame')
        pw_frame.set_halign(Gtk.Align.CENTER)
        pw_frame.set_overflow(Gtk.Overflow.HIDDEN)
        self.password_frames.append(pw_frame)

        pw_overlay = Gtk.Overlay()

        pw_entry = Gtk.Entry()
        pw_entry.set_visibility(False)
        pw_entry.set_invisible_char('●')
        pw_entry.set_alignment(0.5)
        pw_entry.set_width_chars(1)
        pw_entry.set_max_width_chars(0)
        pw_entry.add_css_class('pw-entry')
        pw_entry.connect('activate', self._on_activate)
        pw_entry.connect('changed', self._on_changed)
        self.password_entries.append(pw_entry)

        pw_overlay.set_child(pw_entry)

        fade_left = Gtk.Box()
        fade_left.add_css_class('pw-fade-left')
        fade_left.set_halign(Gtk.Align.START)
        fade_left.set_valign(Gtk.Align.FILL)
        fade_left.set_vexpand(True)
        pw_overlay.add_overlay(fade_left)

        pw_frame.append(pw_overlay)
        pw_box.append(pw_frame)

        error_label = Gtk.Label()
        error_label.add_css_class('error')
        self.error_labels.append(error_label)
        pw_box.append(error_label)

        revealer.set_child(pw_box)
        center.append(revealer)

        minute_label = Gtk.Label(label=minute)
        minute_label.add_css_class('time-minute')
        self.minute_labels.append(minute_label)
        center.append(minute_label)

        box.append(center)

        # bottom spacer
        spacer2 = Gtk.Box()
        spacer2.set_vexpand(True)
        box.append(spacer2)

        # quote at bottom
        quote_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        quote_box.set_halign(Gtk.Align.CENTER)
        quote_box.set_margin_bottom(50)
        quote_box.set_spacing(4)

        quote_label = Gtk.Label(label=self.quote)
        quote_label.add_css_class('quote')

        author_label = Gtk.Label(label=self.quote_author)
        author_label.add_css_class('quote-author')

        quote_box.append(quote_label)
        quote_box.append(author_label)
        box.append(quote_box)

        return box

    def _apply_css(self):
        css = f"""
        .main-bg {{
            background-color: {COLORS['bg']};
        }}

        .time-hour, .time-minute {{
            font-family: "{FONT}";
            font-size: 180px;
            font-weight: 800;
            color: {COLORS['fg']};
            margin: -30px 0;
            text-shadow: 0 2px 20px rgba(0, 0, 0, 0.6);
        }}

        .time-minute {{
            color: {COLORS['dim']};
        }}

        .pw-frame {{
            background-color: {COLORS['surface']};
            border: 2px solid {COLORS['dim']};
            border-radius: 20px;
            min-width: 180px;
            max-width: 350px;
            min-height: 44px;
            padding: 4px 14px;
        }}

        .pw-fade-left {{
            min-width: 30px;
            background-image: linear-gradient(to right, {COLORS['surface']}, rgba(16, 20, 26, 0));
        }}

        entry.pw-entry {{
            font-family: "{FONT}";
            font-size: 24px;
            color: {COLORS['fg']};
            letter-spacing: 6px;
            background: none;
            background-color: transparent;
            border: none;
            border-image: none;
            box-shadow: none;
            outline: none;
            outline-style: none;
            caret-color: {COLORS['lavender']};
            min-height: 0;
            padding: 0 4px;
            margin: 0;
        }}

        entry.pw-entry:focus {{
            background: none;
            background-color: transparent;
            border: none;
            box-shadow: none;
            outline: none;
            outline-style: none;
        }}

        entry.pw-entry > text {{
            background: none;
            background-color: transparent;
            border: none;
            box-shadow: none;
            outline: none;
            min-height: 0;
        }}

        .error {{
            font-family: "{FONT}";
            font-size: 13px;
            color: {COLORS['accent']};
        }}

        .quote {{
            font-family: "{FONT}";
            font-size: 18px;
            font-style: italic;
            color: {COLORS['fg']};
        }}

        .quote-author {{
            font-family: "{FONT}";
            font-size: 14px;
            color: {COLORS['lavender']};
        }}

        @keyframes shake {{
            0%   {{ margin-left: 0; }}
            15%  {{ margin-left: -10px; }}
            30%  {{ margin-left: 10px; }}
            45%  {{ margin-left: -6px; }}
            60%  {{ margin-left: 6px; }}
            75%  {{ margin-left: -3px; }}
            100% {{ margin-left: 0; }}
        }}

        .shake {{
            animation: shake 0.35s ease-in-out;
        }}

        .pw-frame-error {{
            border: 2px solid {COLORS['accent']};
        }}

        @keyframes fadeout {{
            0%   {{ opacity: 1; }}
            100% {{ opacity: 0; }}
        }}

        .fadeout {{
            animation: fadeout 0.25s ease-in forwards;
        }}
        """

        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_USER,
        )

    def _get_time(self):
        now = datetime.datetime.now()
        return now.strftime("%I"), now.strftime("%M")

    def _update_time(self):
        hour, minute = self._get_time()
        for l in self.hour_labels:
            l.set_text(hour)
        for l in self.minute_labels:
            l.set_text(minute)
        return True

    def _on_key_press(self, controller, keyval, keycode, state):
        self._reset_dpms_timer()

        if self._dpms_off:
            self._dpms_on()
            return True

        keyname = Gdk.keyval_name(keyval)

        if keyname in ('Shift_L', 'Shift_R', 'Control_L', 'Control_R',
                       'Alt_L', 'Alt_R', 'Super_L', 'Super_R',
                       'Num_Lock', 'Scroll_Lock', 'Caps_Lock'):
            return True

        if keyname == 'Escape':
            self.is_typing = False
            self._syncing = True
            for e in self.password_entries:
                e.set_text("")
            self._syncing = False
            for l in self.error_labels:
                l.set_text("")
            for r in self.revealers:
                r.set_reveal_child(False)
            return True

        if not self.is_typing:
            is_printable = 32 <= keyval <= 126 or keyname == 'space'
            if is_printable:
                self.is_typing = True
                for r in self.revealers:
                    r.set_reveal_child(True)

                entry = self.password_entries[0] if self.password_entries else None
                for e in self.password_entries:
                    win = e.get_root()
                    if win and win.is_active():
                        entry = e
                        break
                if entry:
                    entry.grab_focus()
                    char = chr(keyval) if 32 <= keyval <= 126 else ' '
                    entry.set_text(char)
                    entry.set_position(-1)
                return True

        return False

    def _on_activate(self, entry):
        self._try_unlock()

    def _on_changed(self, entry):
        if self._syncing:
            return
        text = entry.get_text()
        chars = max(len(text) + 1, 1)
        self._syncing = True
        for e in self.password_entries:
            e.set_width_chars(chars)
            if e is not entry:
                e.set_text(text)
        self._syncing = False
        if not text and self.is_typing:
            self.is_typing = False
            for r in self.revealers:
                r.set_reveal_child(False)

    def _try_unlock(self):
        now = time.time()
        if now < self._locked_until:
            remaining = int(self._locked_until - now) + 1
            for l in self.error_labels:
                l.set_text(f"wait {remaining}s")
            return

        password = self.password_entries[0].get_text() if self.password_entries else ""
        if not password:
            return

        user = os.environ.get('USER', '')

        def auth_thread():
            success = _check_password(user, password)
            GLib.idle_add(self._on_auth_result, success)

        threading.Thread(target=auth_thread, daemon=True).start()

    def _on_auth_result(self, success):
        if success:
            for box in self.content_boxes:
                box.add_css_class('fadeout')
            for win in self.windows:
                LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
            GLib.timeout_add(300, self.quit)
        else:
            self._fail_count += 1
            delay = min(2 ** (self._fail_count - 1), 30) if self._fail_count > 1 else 0

            for f in self.password_frames:
                f.add_css_class('shake')
                f.add_css_class('pw-frame-error')
            GLib.timeout_add(350, self._remove_shake)

            if delay > 0:
                self._locked_until = time.time() + delay
                for l in self.error_labels:
                    l.set_text(f"wrong password — wait {delay}s")
                self._start_lockout()
            else:
                for l in self.error_labels:
                    l.set_text("wrong password")

            self._syncing = True
            for e in self.password_entries:
                e.set_text("")
            self._syncing = False
        return False

    def _remove_shake(self):
        for f in self.password_frames:
            f.remove_css_class('shake')
            f.remove_css_class('pw-frame-error')
        return False

    def _start_lockout(self):
        GLib.timeout_add_seconds(1, self._update_lockout)

    def _update_lockout(self):
        remaining = int(self._locked_until - time.time())
        if remaining <= 0:
            for l in self.error_labels:
                l.set_text("")
            return False
        for l in self.error_labels:
            l.set_text(f"wait {remaining}s")
        return True


if __name__ == '__main__':
    app = LockScreen()
    app.run()
