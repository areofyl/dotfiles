/* Minimal custom lock screen for DWL / wlroots compositors.
 * C rewrite of lockscreen.py — GTK4 + gtk4-layer-shell + PAM.
 *
 * Build:
 *   cc -O2 -o lockscreen lockscreen.c \
 *     $(pkg-config --cflags --libs gtk4-layer-shell-0 gtk4) \
 *     -lpam -lpthread
 *
 * Reads palette from ~/.config/theme/palette.sh
 */

#include <gtk4-layer-shell.h>
#include <gtk/gtk.h>
#include <security/pam_appl.h>

#include <ctype.h>
#include <math.h>
#include <pwd.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

/* ── Limits ─────────────────────────────────────────────────── */

#define MAX_MONITORS    8
#define MAX_QUOTES      16
#define MAX_PW_LEN      256
#define DPMS_TIMEOUT    30
#define FONT            "FantasqueSansM Nerd Font Mono"

/* ── Colors ─────────────────────────────────────────────────── */

static char col_bg[32]       = "#10141a";
static char col_fg[32]       = "#c4ccd4";
static char col_dim[32]      = "#5a6470";
static char col_lavender[32] = "#8a95b0";
static char col_red[32]      = "#9a7590";
static char col_surface[64]  = "rgba(16, 20, 26, 0.85)";
static char col_bg_clear[64] = "rgba(16, 20, 26, 0)";

/* ── Quotes ─────────────────────────────────────────────────── */

typedef struct { const char *text; const char *author; } Quote;

static const Quote quotes[] = {
    {"\"The supreme art of war is to subdue the enemy without fighting.\"",
     "— Sun Tzu, The Art of War"},
    {"\"Appear weak when you are strong, and strong when you are weak.\"",
     "— Sun Tzu, The Art of War"},
    {"\"In the midst of chaos, there is also opportunity.\"",
     "— Sun Tzu, The Art of War"},
    {"\"Every battle is won before it is ever fought.\"",
     "— Sun Tzu, The Art of War"},
    {"\"If you know the enemy and know yourself, you need not fear the result of a hundred battles.\"",
     "— Sun Tzu, The Art of War"},
    {"\"Let your plans be dark and impenetrable as night, and when you move, fall like a thunderbolt.\"",
     "— Sun Tzu, The Art of War"},
    {"\"Victorious warriors win first and then go to war.\"",
     "— Sun Tzu, The Art of War"},
    {"\"Not even close, baby. Technoblade never dies.\"",
     "— Technoblade"},
    {"\"If you wish to defeat me, train for another five hundred years.\"",
     "— Technoblade"},
    {"\"Officer, I drop-kicked that child in self-defense.\"",
     "— Technoblade"},
    {"\"I'm an orphan, Phil. They're the second worst thing to ever happen to those orphans.\"",
     "— Technoblade"},
    {"\"The thing about this world is that it doesn't care. You have to make it care.\"",
     "— Technoblade"},
};
#define N_QUOTES (sizeof(quotes) / sizeof(quotes[0]))

/* ── Global state ───────────────────────────────────────────── */

static GtkApplication *app;
static char lock_file[256];
static char wallpaper[256];
static char blurred_path[] = "/tmp/lockscreen_blurred.png";

/* per-monitor widgets */
static int n_windows;
static GtkWindow    *windows[MAX_MONITORS];
static GtkWidget    *content_boxes[MAX_MONITORS];
static GtkRevealer  *revealers[MAX_MONITORS];
static GtkLabel     *hour_labels[MAX_MONITORS];
static GtkLabel     *minute_labels[MAX_MONITORS];
static GtkEntry     *pw_entries[MAX_MONITORS];
static GtkLabel     *error_labels[MAX_MONITORS];
static GtkWidget    *pw_frames[MAX_MONITORS];

static gboolean is_typing;
static gboolean syncing;
static int      fail_count;
static double   locked_until;
static gboolean dpms_off;
static guint    dpms_timeout_id;
static char     saved_brightness[32];
static const Quote *chosen_quote;

/* ── Lock file path ─────────────────────────────────────────── */

static void build_lock_path(void) {
    const char *xdg = getenv("XDG_RUNTIME_DIR");
    if (xdg)
        snprintf(lock_file, sizeof(lock_file), "%s/dwl-locked", xdg);
    else
        snprintf(lock_file, sizeof(lock_file), "/run/user/%d/dwl-locked", getuid());
}

/* ── Palette loader ─────────────────────────────────────────── */

static void load_palette(void) {
    char path[256];
    snprintf(path, sizeof(path), "%s/.config/theme/palette.sh", getenv("HOME"));
    FILE *f = fopen(path, "r");
    if (!f) return;

    char line[256];
    char key[64], val[32];
    int bg_r = 16, bg_g = 20, bg_b = 26;

    while (fgets(line, sizeof(line), f)) {
        if (sscanf(line, "%63[a-z_]='%31[^']'", key, val) == 2) {
            if (!strcmp(key, "bg"))           snprintf(col_bg, sizeof(col_bg), "%s", val);
            else if (!strcmp(key, "fg"))       snprintf(col_fg, sizeof(col_fg), "%s", val);
            else if (!strcmp(key, "dim"))      snprintf(col_dim, sizeof(col_dim), "%s", val);
            else if (!strcmp(key, "lavender")) snprintf(col_lavender, sizeof(col_lavender), "%s", val);
            else if (!strcmp(key, "red_error")) snprintf(col_red, sizeof(col_red), "%s", val);
        }
    }
    fclose(f);

    /* derive surface rgba from bg */
    if (strlen(col_bg) == 7 && col_bg[0] == '#') {
        unsigned int r, g, b;
        sscanf(col_bg + 1, "%2x%2x%2x", &r, &g, &b);
        bg_r = r; bg_g = g; bg_b = b;
    }
    snprintf(col_surface,  sizeof(col_surface),  "rgba(%d, %d, %d, 0.85)", bg_r, bg_g, bg_b);
    snprintf(col_bg_clear, sizeof(col_bg_clear), "rgba(%d, %d, %d, 0)",    bg_r, bg_g, bg_b);
}

/* ── Wallpaper blur (box blur + darken via gdk-pixbuf) ──────── */

static void box_blur(GdkPixbuf *pb, int radius) {
    int w = gdk_pixbuf_get_width(pb);
    int h = gdk_pixbuf_get_height(pb);
    int rs = gdk_pixbuf_get_rowstride(pb);
    int ch = gdk_pixbuf_get_n_channels(pb);
    guchar *px = gdk_pixbuf_get_pixels(pb);

    guchar *tmp = malloc(h * rs);
    if (!tmp) return;

    /* horizontal pass */
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            int r = 0, g = 0, b = 0, n = 0;
            for (int dx = -radius; dx <= radius; dx++) {
                int sx = x + dx;
                if (sx < 0 || sx >= w) continue;
                guchar *p = px + y * rs + sx * ch;
                r += p[0]; g += p[1]; b += p[2]; n++;
            }
            guchar *o = tmp + y * rs + x * ch;
            o[0] = r / n; o[1] = g / n; o[2] = b / n;
            if (ch == 4) o[3] = px[y * rs + x * ch + 3];
        }
    }

    /* vertical pass */
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            int r = 0, g = 0, b = 0, n = 0;
            for (int dy = -radius; dy <= radius; dy++) {
                int sy = y + dy;
                if (sy < 0 || sy >= h) continue;
                guchar *p = tmp + sy * rs + x * ch;
                r += p[0]; g += p[1]; b += p[2]; n++;
            }
            guchar *o = px + y * rs + x * ch;
            o[0] = r / n; o[1] = g / n; o[2] = b / n;
        }
    }
    free(tmp);
}

static const char *create_blurred_wallpaper(void) {
    snprintf(wallpaper, sizeof(wallpaper), "%s/Pictures/wallpapers/clouds.jpg", getenv("HOME"));

    if (access(wallpaper, R_OK) != 0) return NULL;

    struct stat ws, bs;
    if (stat(wallpaper, &ws) != 0) return NULL;
    if (stat(blurred_path, &bs) == 0 && bs.st_mtime > ws.st_mtime)
        return blurred_path;

    GError *err = NULL;
    GdkPixbuf *pb = gdk_pixbuf_new_from_file(wallpaper, &err);
    if (!pb) { if (err) g_error_free(err); return NULL; }

    /* 3-pass box blur ≈ gaussian blur with radius ~12 */
    box_blur(pb, 12);
    box_blur(pb, 12);
    box_blur(pb, 12);

    /* darken to ~35% brightness */
    int w = gdk_pixbuf_get_width(pb);
    int h = gdk_pixbuf_get_height(pb);
    int rs = gdk_pixbuf_get_rowstride(pb);
    int ch = gdk_pixbuf_get_n_channels(pb);
    guchar *px = gdk_pixbuf_get_pixels(pb);
    for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++) {
            guchar *p = px + y * rs + x * ch;
            p[0] = p[0] * 35 / 100;
            p[1] = p[1] * 35 / 100;
            p[2] = p[2] * 35 / 100;
        }

    gdk_pixbuf_save(pb, blurred_path, "png", &err, NULL);
    g_object_unref(pb);
    if (err) { g_error_free(err); return NULL; }
    return blurred_path;
}

/* ── PAM authentication ─────────────────────────────────────── */

typedef struct { const char *password; } PamCtx;

static int pam_conv_fn(int n, const struct pam_message **msgs,
                       struct pam_response **resp, void *data) {
    PamCtx *ctx = data;
    *resp = calloc(n, sizeof(struct pam_response));
    if (!*resp) return PAM_BUF_ERR;
    for (int i = 0; i < n; i++) {
        if (msgs[i]->msg_style == PAM_PROMPT_ECHO_OFF)
            (*resp)[i].resp = strdup(ctx->password);
    }
    return PAM_SUCCESS;
}

static gboolean check_password(const char *user, const char *password) {
    PamCtx ctx = { .password = password };
    struct pam_conv conv = { .conv = pam_conv_fn, .appdata_ptr = &ctx };
    pam_handle_t *handle = NULL;

    int ret = pam_start("custom-lock", user, &conv, &handle);
    if (ret != PAM_SUCCESS) return FALSE;

    ret = pam_authenticate(handle, 0);
    pam_end(handle, ret);
    return ret == PAM_SUCCESS;
}

/* ── DPMS (brightnessctl) ───────────────────────────────────── */

static void dpms_on(void) {
    if (!dpms_off) return;
    if (saved_brightness[0]) {
        char cmd[64];
        snprintf(cmd, sizeof(cmd), "brightnessctl s %s", saved_brightness);
        (void)!system(cmd);
    }
    dpms_off = FALSE;

    /* clear any partial password so attacker can't just finish typing */
    if (is_typing) {
        is_typing = FALSE;
        syncing = TRUE;
        for (int i = 0; i < n_windows; i++) {
            GtkEntryBuffer *buf = gtk_entry_get_buffer(pw_entries[i]);
            gtk_entry_buffer_set_text(buf, "", -1);
            gtk_label_set_text(error_labels[i], "");
            gtk_revealer_set_reveal_child(revealers[i], FALSE);
        }
        syncing = FALSE;
    }
}

static gboolean dpms_off_cmd(gpointer data) {
    (void)data;
    FILE *p = popen("brightnessctl g", "r");
    saved_brightness[0] = '\0';
    if (p) {
        if (fgets(saved_brightness, sizeof(saved_brightness), p)) {
            char *nl = strchr(saved_brightness, '\n');
            if (nl) *nl = '\0';
        }
        pclose(p);
    }
    (void)!system("brightnessctl s 0 >/dev/null 2>&1");
    dpms_off = TRUE;
    dpms_timeout_id = 0;
    return G_SOURCE_REMOVE;
}

static void reset_dpms_timer(void) {
    if (dpms_timeout_id)
        g_source_remove(dpms_timeout_id);
    dpms_timeout_id = g_timeout_add_seconds(DPMS_TIMEOUT, dpms_off_cmd, NULL);
}

/* ── Time ───────────────────────────────────────────────────── */

static void get_time(char *hour, char *minute) {
    time_t t = time(NULL);
    struct tm *tm = localtime(&t);
    strftime(hour, 8, "%I", tm);
    strftime(minute, 8, "%M", tm);
}

static gboolean is_charging(void) {
    FILE *f = fopen("/sys/class/power_supply/macsmc-battery/status", "r");
    if (!f) return FALSE;
    char buf[32];
    if (!fgets(buf, sizeof(buf), f)) { fclose(f); return FALSE; }
    fclose(f);
    char *nl = strchr(buf, '\n');
    if (nl) *nl = '\0';
    return !strcmp(buf, "Charging") || !strcmp(buf, "Full");
}

static gboolean update_time(gpointer data) {
    (void)data;
    char hour[8], minute[8];
    get_time(hour, minute);
    gboolean charging = is_charging();

    for (int i = 0; i < n_windows; i++) {
        gtk_label_set_text(hour_labels[i], hour);
        gtk_label_set_text(minute_labels[i], minute);
        if (charging)
            gtk_widget_add_css_class(GTK_WIDGET(minute_labels[i]), "charging");
        else
            gtk_widget_remove_css_class(GTK_WIDGET(minute_labels[i]), "charging");
    }
    return G_SOURCE_CONTINUE;
}

/* ── Password helpers ───────────────────────────────────────── */

static const char *get_password(void) {
    if (n_windows == 0) return "";
    GtkEntryBuffer *buf = gtk_entry_get_buffer(pw_entries[0]);
    return gtk_entry_buffer_get_text(buf);
}

static void set_password(const char *text) {
    int len = strlen(text);
    int chars = len + 1;
    if (chars < 1) chars = 1;

    syncing = TRUE;
    for (int i = 0; i < n_windows; i++) {
        gtk_editable_set_width_chars(GTK_EDITABLE(pw_entries[i]), chars);
        GtkEntryBuffer *buf = gtk_entry_get_buffer(pw_entries[i]);
        gtk_entry_buffer_set_text(buf, text, -1);
        gtk_editable_set_position(GTK_EDITABLE(pw_entries[i]), -1);
    }
    syncing = FALSE;
    /* keep revealer open even when empty; Escape hides it */
}

/* ── Auth result (called from main thread) ──────────────────── */

static gboolean quit_app(gpointer data) {
    (void)data;
    g_application_quit(G_APPLICATION(app));
    return G_SOURCE_REMOVE;
}

static gboolean remove_shake(gpointer data) {
    (void)data;
    for (int i = 0; i < n_windows; i++) {
        gtk_widget_remove_css_class(pw_frames[i], "shake");
        gtk_widget_remove_css_class(pw_frames[i], "pw-frame-error");
    }
    return G_SOURCE_REMOVE;
}

static gboolean update_lockout(gpointer data) {
    (void)data;
    int remaining = (int)(locked_until - g_get_real_time() / 1e6);
    if (remaining <= 0) {
        for (int i = 0; i < n_windows; i++)
            gtk_label_set_text(error_labels[i], "");
        return G_SOURCE_REMOVE;
    }
    char msg[32];
    snprintf(msg, sizeof(msg), "wait %ds", remaining);
    for (int i = 0; i < n_windows; i++)
        gtk_label_set_text(error_labels[i], msg);
    return G_SOURCE_CONTINUE;
}

static gboolean on_auth_result(gpointer data) {
    gboolean success = GPOINTER_TO_INT(data);

    if (success) {
        unlink(lock_file);
        dpms_on();
        for (int i = 0; i < n_windows; i++) {
            gtk_widget_add_css_class(content_boxes[i], "fadeout");
            gtk_layer_set_keyboard_mode(windows[i], GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
        }
        g_timeout_add(300, quit_app, NULL);
    } else {
        fail_count++;
        int delay = fail_count > 1 ? (int)fmin(pow(2, fail_count - 1), 30) : 0;

        for (int i = 0; i < n_windows; i++) {
            gtk_widget_add_css_class(pw_frames[i], "shake");
            gtk_widget_add_css_class(pw_frames[i], "pw-frame-error");
        }
        g_timeout_add(350, remove_shake, NULL);

        if (delay > 0) {
            locked_until = g_get_real_time() / 1e6 + delay;
            char msg[64];
            snprintf(msg, sizeof(msg), "wrong password — wait %ds", delay);
            for (int i = 0; i < n_windows; i++)
                gtk_label_set_text(error_labels[i], msg);
            g_timeout_add_seconds(1, update_lockout, NULL);
        } else {
            for (int i = 0; i < n_windows; i++)
                gtk_label_set_text(error_labels[i], "wrong password");
        }

        set_password("");
    }
    return G_SOURCE_REMOVE;
}

/* ── Auth thread ────────────────────────────────────────────── */

typedef struct { char user[64]; char password[MAX_PW_LEN]; } AuthData;

static gpointer auth_thread(gpointer data) {
    AuthData *ad = data;
    gboolean ok = check_password(ad->user, ad->password);
    /* zero the password before freeing */
    memset(ad->password, 0, sizeof(ad->password));
    free(ad);
    g_idle_add(on_auth_result, GINT_TO_POINTER(ok));
    return NULL;
}

static void try_unlock(void) {
    double now = g_get_real_time() / 1e6;
    if (now < locked_until) {
        int remaining = (int)(locked_until - now) + 1;
        char msg[32];
        snprintf(msg, sizeof(msg), "wait %ds", remaining);
        for (int i = 0; i < n_windows; i++)
            gtk_label_set_text(error_labels[i], msg);
        return;
    }

    const char *pw = get_password();
    if (!pw || !pw[0]) return;

    AuthData *ad = malloc(sizeof(AuthData));
    const char *user = getenv("USER");
    snprintf(ad->user, sizeof(ad->user), "%s", user ? user : "");
    snprintf(ad->password, sizeof(ad->password), "%s", pw);

    g_thread_new("pam-auth", auth_thread, ad);
}

/* ── Key press handler ──────────────────────────────────────── */

static gboolean on_key_press(GtkEventControllerKey *ctrl, guint keyval,
                             guint keycode, GdkModifierType state, gpointer data) {
    (void)ctrl; (void)keycode; (void)state; (void)data;

    reset_dpms_timer();

    if (dpms_off) {
        dpms_on();
        return TRUE;
    }

    const char *keyname = gdk_keyval_name(keyval);
    if (!keyname) return TRUE;

    /* ignore modifier-only keys */
    if (!strcmp(keyname, "Shift_L")   || !strcmp(keyname, "Shift_R")   ||
        !strcmp(keyname, "Control_L") || !strcmp(keyname, "Control_R") ||
        !strcmp(keyname, "Alt_L")     || !strcmp(keyname, "Alt_R")     ||
        !strcmp(keyname, "Super_L")   || !strcmp(keyname, "Super_R")   ||
        !strcmp(keyname, "Num_Lock")  || !strcmp(keyname, "Scroll_Lock") ||
        !strcmp(keyname, "Caps_Lock"))
        return TRUE;

    if (!strcmp(keyname, "Escape")) {
        is_typing = FALSE;
        syncing = TRUE;
        for (int i = 0; i < n_windows; i++) {
            GtkEntryBuffer *buf = gtk_entry_get_buffer(pw_entries[i]);
            gtk_entry_buffer_set_text(buf, "", -1);
        }
        syncing = FALSE;
        for (int i = 0; i < n_windows; i++) {
            gtk_label_set_text(error_labels[i], "");
            gtk_revealer_set_reveal_child(revealers[i], FALSE);
        }
        return TRUE;
    }

    gboolean printable = (keyval >= 32 && keyval <= 126);

    if (!is_typing) {
        if (printable) {
            is_typing = TRUE;
            for (int i = 0; i < n_windows; i++)
                gtk_revealer_set_reveal_child(revealers[i], TRUE);
            char ch[2] = { (char)keyval, '\0' };
            set_password(ch);
        }
        return TRUE;
    }

    if (!strcmp(keyname, "Return")) {
        try_unlock();
    } else if (!strcmp(keyname, "BackSpace")) {
        const char *text = get_password();
        int len = strlen(text);
        if (len > 0) {
            char *trimmed = g_strndup(text, len - 1);
            set_password(trimmed);
            g_free(trimmed);
        }
    } else if (printable) {
        const char *text = get_password();
        char *appended = g_strdup_printf("%s%c", text, (char)keyval);
        set_password(appended);
        g_free(appended);
    }

    return TRUE;
}

/* ── CSS ────────────────────────────────────────────────────── */

static void apply_css(void) {
    char *css = g_strdup_printf(
        ".main-bg { background-color: %s; }\n"
        ".time-hour, .time-minute {\n"
        "  font-family: \"%s\"; font-size: 180px; font-weight: 800;\n"
        "  color: %s; margin: -30px 0;\n"
        "  text-shadow: 0 2px 20px rgba(0, 0, 0, 0.6);\n"
        "}\n"
        ".time-minute { color: %s; }\n"
        ".time-minute.charging { color: #4d5952; }\n"
        ".pw-frame {\n"
        "  background-color: %s; border: 2px solid %s;\n"
        "  border-radius: 20px; min-width: 180px; max-width: 350px;\n"
        "  min-height: 44px; padding: 4px 14px;\n"
        "}\n"
        ".pw-fade-left {\n"
        "  min-width: 30px;\n"
        "  background-image: linear-gradient(to right, %s, %s);\n"
        "}\n"
        "entry.pw-entry {\n"
        "  font-family: \"%s\"; font-size: 24px; color: %s;\n"
        "  letter-spacing: 6px; background: none; background-color: transparent;\n"
        "  border: none; border-image: none; box-shadow: none;\n"
        "  outline: none; outline-style: none; caret-color: %s;\n"
        "  min-height: 0; padding: 0 4px; margin: 0;\n"
        "}\n"
        "entry.pw-entry:focus {\n"
        "  background: none; background-color: transparent;\n"
        "  border: none; box-shadow: none; outline: none; outline-style: none;\n"
        "}\n"
        "entry.pw-entry > text {\n"
        "  background: none; background-color: transparent;\n"
        "  border: none; box-shadow: none; outline: none; min-height: 0;\n"
        "}\n"
        ".error { font-family: \"%s\"; font-size: 13px; color: %s; }\n"
        ".quote { font-family: \"%s\"; font-size: 18px; font-style: italic; color: %s; }\n"
        ".quote-author { font-family: \"%s\"; font-size: 14px; color: %s; }\n"
        "@keyframes shake {\n"
        "  0%%   { margin-left: 0; }\n"
        "  15%%  { margin-left: -10px; }\n"
        "  30%%  { margin-left: 10px; }\n"
        "  45%%  { margin-left: -6px; }\n"
        "  60%%  { margin-left: 6px; }\n"
        "  75%%  { margin-left: -3px; }\n"
        "  100%% { margin-left: 0; }\n"
        "}\n"
        ".shake { animation: shake 0.35s ease-in-out; }\n"
        ".pw-frame-error { border: 2px solid %s; }\n"
        "@keyframes fadeout { 0%% { opacity: 1; } 100%% { opacity: 0; } }\n"
        ".fadeout { animation: fadeout 0.25s ease-in forwards; }\n",
        col_bg,
        FONT, col_fg,
        col_dim,
        col_surface, col_dim,
        col_surface, col_bg_clear,
        FONT, col_fg, col_lavender,
        FONT, col_red,
        FONT, col_fg,
        FONT, col_lavender,
        col_red
    );

    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_string(provider, css);
    gtk_style_context_add_provider_for_display(
        gdk_display_get_default(),
        GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_USER);
    g_free(css);
}

/* ── Window creation ────────────────────────────────────────── */

static const char *blurred_file;

static GtkWidget *create_view(int idx) {
    char hour[8], minute[8];
    get_time(hour, minute);

    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_valign(box, GTK_ALIGN_FILL);
    gtk_widget_set_halign(box, GTK_ALIGN_FILL);
    gtk_widget_set_vexpand(box, TRUE);

    /* top spacer */
    GtkWidget *spacer1 = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_vexpand(spacer1, TRUE);
    gtk_box_append(GTK_BOX(box), spacer1);

    /* center: clock + password */
    GtkWidget *center = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_halign(center, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(center, GTK_ALIGN_CENTER);

    GtkWidget *hour_lbl = gtk_label_new(hour);
    gtk_widget_add_css_class(hour_lbl, "time-hour");
    hour_labels[idx] = GTK_LABEL(hour_lbl);
    gtk_box_append(GTK_BOX(center), hour_lbl);

    /* password revealer */
    GtkWidget *revealer = gtk_revealer_new();
    gtk_revealer_set_transition_type(GTK_REVEALER(revealer), GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN);
    gtk_revealer_set_transition_duration(GTK_REVEALER(revealer), 120);
    gtk_revealer_set_reveal_child(GTK_REVEALER(revealer), FALSE);
    revealers[idx] = GTK_REVEALER(revealer);

    GtkWidget *pw_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_halign(pw_box, GTK_ALIGN_CENTER);
    gtk_widget_set_margin_top(pw_box, 12);
    gtk_widget_set_margin_bottom(pw_box, 12);

    GtkWidget *pw_frame = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_add_css_class(pw_frame, "pw-frame");
    gtk_widget_set_halign(pw_frame, GTK_ALIGN_CENTER);
    gtk_widget_set_overflow(pw_frame, GTK_OVERFLOW_HIDDEN);
    pw_frames[idx] = pw_frame;

    GtkWidget *pw_overlay = gtk_overlay_new();

    GtkWidget *pw_entry = gtk_entry_new();
    gtk_entry_set_visibility(GTK_ENTRY(pw_entry), FALSE);
    gtk_entry_set_invisible_char(GTK_ENTRY(pw_entry), 0x25CF); /* ● */
    gtk_editable_set_alignment(GTK_EDITABLE(pw_entry), 0.5);
    gtk_editable_set_width_chars(GTK_EDITABLE(pw_entry), 1);
    gtk_editable_set_max_width_chars(GTK_EDITABLE(pw_entry), 0);
    gtk_widget_add_css_class(pw_entry, "pw-entry");
    pw_entries[idx] = GTK_ENTRY(pw_entry);

    gtk_overlay_set_child(GTK_OVERLAY(pw_overlay), pw_entry);

    GtkWidget *fade_left = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_add_css_class(fade_left, "pw-fade-left");
    gtk_widget_set_halign(fade_left, GTK_ALIGN_START);
    gtk_widget_set_valign(fade_left, GTK_ALIGN_FILL);
    gtk_widget_set_vexpand(fade_left, TRUE);
    gtk_overlay_add_overlay(GTK_OVERLAY(pw_overlay), fade_left);

    gtk_box_append(GTK_BOX(pw_frame), pw_overlay);
    gtk_box_append(GTK_BOX(pw_box), pw_frame);

    GtkWidget *err_lbl = gtk_label_new("");
    gtk_widget_add_css_class(err_lbl, "error");
    error_labels[idx] = GTK_LABEL(err_lbl);
    gtk_box_append(GTK_BOX(pw_box), err_lbl);

    gtk_revealer_set_child(GTK_REVEALER(revealer), pw_box);
    gtk_box_append(GTK_BOX(center), revealer);

    GtkWidget *min_lbl = gtk_label_new(minute);
    gtk_widget_add_css_class(min_lbl, "time-minute");
    minute_labels[idx] = GTK_LABEL(min_lbl);
    gtk_box_append(GTK_BOX(center), min_lbl);

    gtk_box_append(GTK_BOX(box), center);

    /* bottom spacer */
    GtkWidget *spacer2 = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_vexpand(spacer2, TRUE);
    gtk_box_append(GTK_BOX(box), spacer2);

    /* quote */
    GtkWidget *qbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_set_halign(qbox, GTK_ALIGN_CENTER);
    gtk_widget_set_margin_bottom(qbox, 50);

    GtkWidget *qlbl = gtk_label_new(chosen_quote->text);
    gtk_widget_add_css_class(qlbl, "quote");
    GtkWidget *albl = gtk_label_new(chosen_quote->author);
    gtk_widget_add_css_class(albl, "quote-author");

    gtk_box_append(GTK_BOX(qbox), qlbl);
    gtk_box_append(GTK_BOX(qbox), albl);
    gtk_box_append(GTK_BOX(box), qbox);


    return box;
}

static void create_window(GdkMonitor *monitor) {
    if (n_windows >= MAX_MONITORS) return;
    int idx = n_windows++;

    GtkWindow *win = GTK_WINDOW(gtk_application_window_new(app));
    windows[idx] = win;

    gtk_layer_init_for_window(win);
    gtk_layer_set_layer(win, GTK_LAYER_SHELL_LAYER_OVERLAY);
    gtk_layer_set_monitor(win, monitor);
    gtk_layer_set_exclusive_zone(win, -1);
    gtk_layer_set_keyboard_mode(win, GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE);
    gtk_layer_set_namespace(win, "lockscreen");

    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
    gtk_layer_set_anchor(win, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);

    GtkWidget *overlay = gtk_overlay_new();
    gtk_widget_set_vexpand(overlay, TRUE);
    gtk_widget_set_hexpand(overlay, TRUE);

    if (blurred_file) {
        GtkWidget *bg = gtk_picture_new_for_filename(blurred_file);
        gtk_picture_set_content_fit(GTK_PICTURE(bg), GTK_CONTENT_FIT_COVER);
        gtk_picture_set_can_shrink(GTK_PICTURE(bg), TRUE);
        gtk_overlay_set_child(GTK_OVERLAY(overlay), bg);
    } else {
        GtkWidget *bg = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
        gtk_widget_add_css_class(bg, "main-bg");
        gtk_overlay_set_child(GTK_OVERLAY(overlay), bg);
    }

    GtkWidget *content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_valign(content, GTK_ALIGN_FILL);
    gtk_widget_set_halign(content, GTK_ALIGN_FILL);
    gtk_widget_set_vexpand(content, TRUE);
    gtk_widget_set_hexpand(content, TRUE);

    GtkWidget *view = create_view(idx);
    gtk_box_append(GTK_BOX(content), view);
    content_boxes[idx] = content;
    gtk_overlay_add_overlay(GTK_OVERLAY(overlay), content);

    gtk_window_set_child(win, overlay);

    GtkEventController *key_ctrl = gtk_event_controller_key_new();
    g_signal_connect(key_ctrl, "key-pressed", G_CALLBACK(on_key_press), NULL);
    gtk_widget_add_controller(GTK_WIDGET(win), key_ctrl);

    gtk_window_present(win);
}

/* ── Activate ───────────────────────────────────────────────── */

static void on_activate(GtkApplication *a, gpointer data) {
    (void)data;
    app = a;

    blurred_file = create_blurred_wallpaper();

    GdkDisplay *display = gdk_display_get_default();
    GListModel *monitors = gdk_display_get_monitors(display);
    guint n = g_list_model_get_n_items(monitors);

    for (guint i = 0; i < n; i++) {
        GdkMonitor *mon = g_list_model_get_item(monitors, i);
        create_window(mon);
        g_object_unref(mon);
    }

    apply_css();
    update_time(NULL);
    g_timeout_add_seconds(1, update_time, NULL);
    reset_dpms_timer();
}

/* ── Signal handler ─────────────────────────────────────────── */

static void on_signal(int sig) {
    (void)sig;
    dpms_on();
    _exit(1);
}

/* ── Main ───────────────────────────────────────────────────── */

int main(int argc, char *argv[]) {
    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);

    srand(time(NULL));
    chosen_quote = &quotes[rand() % N_QUOTES];

    build_lock_path();
    load_palette();

    app = gtk_application_new("com.custom.lockscreen", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);

    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
    return status;
}
