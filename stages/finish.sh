# Stage: finish - summary.

POOL=$(root_pool)
if [ -n "$POOL" ] && ! zfs list -H -t snapshot "$POOL/ROOT/default@post-setup" >/dev/null 2>&1; then
	zfs snapshot -r "$POOL@post-setup" && say "snapshot $POOL@post-setup taken"
fi

printf '\n\033[1;32mSetup finished.\033[0m Log: %s\n' "$LOG"
if [ -n "${WARNINGS:-}" ]; then
	printf '\n\033[1;33mThings that need your attention:\033[0m%s\n' "$WARNINGS"
fi
cat <<EOF

Next steps
  1. Reboot:            shutdown -r now
  2. Log in at the login screen as $TARGET_USER, session "Hyprland (Caelestia)"
     (no login screen? log in on the console and run: hypr-session)
  3. Super+T opens a terminal, Super (tap) the launcher, Super+Q closes a window.
  4. Check the GPUs:    glxinfo -B | grep renderer ;  nvrun glxinfo -B | grep renderer
  5. Steam:             steam-setup   (once), then ~/.local/bin/steam
  6. Updates:           sysup         (makes a boot environment first)
  7. Snapshots:         snap          (list) / snap take / zfs rollback
  Problems? docs/TROUBLESHOOTING.md - and "bectl activate pre-setup-..." undoes
  everything this script changed.
EOF
