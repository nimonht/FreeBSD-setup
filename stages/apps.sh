# Stage: apps - everyday software. Edit the lists to taste.

[ "$INSTALL_APPS" = yes ] || { say "INSTALL_APPS=no - skipped"; return 0 2>/dev/null || true; }

say "browser, mail, office, media"
pkg_install firefox mpv imv zathura zathura-pdf-mupdf
pkg_try chromium thunderbird libreoffice obs-studio telegram-desktop keepassxc \
	qbittorrent gimp

say "developer tools"
pkg_try vscode gmake llvm rust go node npm python3 py312-pip tig gh

say "filesystems: read your Windows (NTFS) and Linux (ext4) partitions, USB sticks"
pkg_install fusefs-ntfs fusefs-exfat exfat-utils fusefs-ext2 e2fsprogs-core
pkg_try automount

say "webcam"
pkg_try webcamd
sysrc webcamd_enable=YES >/dev/null 2>&1 || true
pw groupmod webcamd -m "$TARGET_USER" 2>/dev/null || true
