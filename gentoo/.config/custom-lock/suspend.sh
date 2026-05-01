#!/bin/sh
# Suspend wrapper — display-off is now handled by the system-sleep hook
# (apple-drm-fix.sh), so this just triggers suspend.
systemctl suspend
