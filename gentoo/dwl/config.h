/* Taken from https://github.com/djpohly/dwl/issues/466 */
#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }
/* appearance */
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;
static const int smartgaps                 = 0;  /* 1 means no outer gap when there is only one window */
static const int monoclegaps               = 0;  /* 1 means outer gaps in monocle layout */
static const unsigned int borderpx         = 1;  /* matches default_border pixel 1 */
static const unsigned int gappih           = 10; /* horiz inner gap between windows */
static const unsigned int gappiv           = 10; /* vert inner gap between windows */
static const unsigned int gappoh           = 10; /* horiz outer gap between windows and screen edge */
static const unsigned int gappov           = 10; /* vert outer gap between windows and screen edge */
static const float rootcolor[]             = COLOR(0x222222ff);
static const float bordercolor[]           = COLOR(0x2c2822ff);
static const float focuscolor[]            = COLOR(0x9a9ab8ff);
static const float urgentcolor[]           = COLOR(0xff0000ff);
static const float fullscreen_bg[]         = {0.0f, 0.0f, 0.0f, 1.0f};

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (10)

/* logging */
static int log_level = WLR_ERROR;

static const Rule rules[] = {
	/* app_id             title       tags mask     isfloating   monitor */
	{ NULL,               NULL,       0,            0,           -1 },
};

/* layout(s) */
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* monitors */
static const MonitorRule monrules[] = {
	/* name       mfact  nmaster scale layout       rotate/reflect                x    y */
	{ "eDP-1",   0.60f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   0,    0 },
	{ "DP-1",    0.60f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   2560, 0 },
	{ NULL,      0.60f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
};

/* keyboard */
static const struct xkb_rule_names xkb_rules = {
	.options = "caps:escape",
};

static const int repeat_rate = 50;
static const int repeat_delay = 300;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 1;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.25;

static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* Super key like sway config */
#define MODKEY WLR_MODIFIER_LOGO

#define TAGKEYS(KEY,SKEY,TAG) \
	{ MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,            toggleview,      {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, SKEY,           tagandview,      {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,SKEY,toggletag, {.ui = 1 << TAG} }

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *termcmd[] = { "kitty", NULL };
static const char *menucmd[] = { "/home/aarav/bin/launcher", NULL };

static const Key keys[] = {
	/* modifier                  key                  function          argument */

	/* matches sway: $mod+Return exec $term */
	{ MODKEY,                    XKB_KEY_Return,      spawn,            {.v = termcmd} },
	/* matches sway: $mod+d exec wmenu-run */
	{ MODKEY,                    XKB_KEY_d,           spawn,            {.v = menucmd} },
	/* $mod+f: launch lf file manager */
	{ MODKEY,                    XKB_KEY_f,           spawn,            SHCMD("kitty lf") },
	/* $mod+b: launch ungoogled-chromium */
	{ MODKEY,                    XKB_KEY_b,           spawn,            SHCMD("/home/aarav/.local/bin/ungoogled-chromium --password-store=basic") },
	/* matches sway: $mod+x exec swaylock */
	{ MODKEY,                    XKB_KEY_x,           spawn,            SHCMD("/home/aarav/.config/custom-lock/lock.sh") },

	/* matches sway: $mod+q kill */
	{ MODKEY,                    XKB_KEY_q,           killclient,       {0} },
	/* matches sway: $mod+Shift+f fullscreen */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_F,           togglefullscreen, {0} },
	/* matches sway: $mod+space floating toggle */
	{ MODKEY,                    XKB_KEY_space,       togglefloating,   {0} },

	/* window focus (vim keys) */
	{ MODKEY,                    XKB_KEY_j,           focusstack,       {.i = +1} },
	{ MODKEY,                    XKB_KEY_k,           focusstack,       {.i = -1} },

	/* master area resize (h/l like sway arrow resize) */
	{ MODKEY,                    XKB_KEY_h,           setmfact,         {.f = -0.05f} },
	{ MODKEY,                    XKB_KEY_l,           setmfact,         {.f = +0.05f} },
	{ MODKEY,                    XKB_KEY_i,           incnmaster,       {.i = +1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_I,           incnmaster,       {.i = -1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return,      zoom,             {0} },

	/* layouts */
	{ MODKEY,                    XKB_KEY_t,           setlayout,        {.v = &layouts[0]} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space,       setlayout,        {.v = &layouts[1]} },
	{ MODKEY,                    XKB_KEY_m,           setlayout,        {.v = &layouts[2]} },

	/* matches sway: $mod+Tab workspace next */
	{ MODKEY,                    XKB_KEY_Tab,         view,             {0} },
	/* Super+0 / Super+Shift+0 now target tag 10 (was: view/tag all) */

	/* matches sway: $mod+comma/period */
	{ MODKEY,                    XKB_KEY_comma,       focusmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY,                    XKB_KEY_period,      focusmon,         {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_less,        tagmon,           {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_greater,     tagmon,           {.i = WLR_DIRECTION_RIGHT} },

	/* matches sway media keys */
	{ 0, XKB_KEY_XF86AudioRaiseVolume,  spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") },
	{ 0, XKB_KEY_XF86AudioLowerVolume,  spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
	{ 0, XKB_KEY_XF86AudioMute,         spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
	{ 0, XKB_KEY_XF86AudioMicMute,      spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") },
	{ 0, XKB_KEY_XF86AudioPlay,         spawn, SHCMD("playerctl play-pause") },
	{ 0, XKB_KEY_XF86AudioNext,         spawn, SHCMD("playerctl next") },
	{ 0, XKB_KEY_XF86AudioPrev,         spawn, SHCMD("playerctl previous") },
	{ 0, XKB_KEY_XF86AudioStop,         spawn, SHCMD("playerctl stop") },
	{ 0, XKB_KEY_XF86MonBrightnessUp,   spawn, SHCMD("/home/aarav/bin/brightnessctl set +5%") },
	{ 0, XKB_KEY_XF86MonBrightnessDown, spawn, SHCMD("/home/aarav/bin/brightnessctl set 5%-") },

	/* matches sway screenshot binds */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_S, spawn, SHCMD("grim -t jpeg -q 95 -g \"$(slurp -b 00000000 -s 00000040)\" ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).jpg") },
	{ 0, XKB_KEY_Print, spawn, SHCMD("grim -t jpeg -q 95 ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).jpg") },

	/* matches sway: Ctrl+Alt+Delete exit */
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_Delete, quit, {0} },
	/* matches sway: $mod+Shift+q (dwl convention) */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Q,           quit,             {0} },

	/* tag keys (workspaces 1-9) */
	TAGKEYS(          XKB_KEY_1, XKB_KEY_exclam,                        0),
	TAGKEYS(          XKB_KEY_2, XKB_KEY_at,                            1),
	TAGKEYS(          XKB_KEY_3, XKB_KEY_numbersign,                    2),
	TAGKEYS(          XKB_KEY_4, XKB_KEY_dollar,                        3),
	TAGKEYS(          XKB_KEY_5, XKB_KEY_percent,                       4),
	TAGKEYS(          XKB_KEY_6, XKB_KEY_asciicircum,                   5),
	TAGKEYS(          XKB_KEY_7, XKB_KEY_ampersand,                     6),
	TAGKEYS(          XKB_KEY_8, XKB_KEY_asterisk,                      7),
	TAGKEYS(          XKB_KEY_9, XKB_KEY_parenleft,                     8),
	TAGKEYS(          XKB_KEY_0, XKB_KEY_parenright,                    9),

	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_Terminate_Server, quit, {0} },
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT,XKB_KEY_XF86Switch_VT_##n, chvt, {.ui = (n)} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};
