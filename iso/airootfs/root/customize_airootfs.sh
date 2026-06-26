#!/usr/bin/env bash
# ━━━ BITE-OS — archiso build-time customisation ━━━
# Runs inside the airootfs chroot once, after pacstrap. Sets up the LIVE ISO as
# a dedicated Calamares installer kiosk: it autologins the `bite` user and cage
# runs the installer fullscreen. No Hyprland/caelestia in the live session, so
# nothing can crash and hijack it. The full rice ships untouched in /etc/skel,
# so users INSTALLED to disk get the real BITE-OS desktop.
set -uo pipefail
echo "[customize_airootfs] start"

# 1. Live user + creds (bite/bite, root/bite). bite just needs to exist so the
#    kiosk autologin works; its home content is irrelevant (cage ignores it).
if ! id bite &>/dev/null; then
    useradd -m -u 1000 -G wheel,video,audio,network,storage,input,lp -s /bin/bash bite
fi
echo 'bite:bite' | chpasswd
echo 'root:bite' | chpasswd

# 2. Belt-and-suspenders: the live `bite` home was seeded from /etc/skel (the
#    full rice). The kiosk never reads it, but strip the self-repair service +
#    caelestia autostart so nothing can possibly spawn caelestia in the live
#    session. /etc/skel itself stays untouched, so installs are unaffected.
rm -rf /home/bite/.config/systemd/user/graphical-session.target.wants/bite-os-healthcheck.service \
       /home/bite/.config/systemd/user/*/bite-os-healthcheck.service \
       /home/bite/.config/hypr \
       /home/bite/.config/quickshell \
       /home/bite/.config/caelestia 2>/dev/null || true
chown -R bite:bite /home/bite 2>/dev/null || true

# 3. Passwordless sudo so the kiosk can launch Calamares as root. This file is
#    removed on the installed system by bite-os-firstboot-cleanup.
install -d -m 0750 /etc/sudoers.d
cat > /etc/sudoers.d/00-bite-live <<'EOF'
bite ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/00-bite-live

# 3. Make Calamares do an OFFLINE install of BITE-OS.
#    cachyos' default settings.conf is an ONLINE netinstall: it pacstraps
#    vanilla CachyOS + a DE you pick from a menu — it would NOT install our
#    rice. The offline variant copies THIS live squashfs (the full riced
#    BITE-OS) to disk via unpackfs, with no desktop/bootloader chooser. That is
#    exactly what BITE-OS is: one opinionated, pre-riced Hyprland system.
if [ -f /usr/share/calamares/settings_offline.conf ]; then
    cp -f /usr/share/calamares/settings_offline.conf /usr/share/calamares/settings.conf
    echo "[customize_airootfs] calamares set to OFFLINE install (unpackfs of the live system)"
fi

# Brand every settings variant to bite-os (our branding dir ships alongside).
for f in /usr/share/calamares/settings.conf \
         /usr/share/calamares/settings_offline.conf \
         /usr/share/calamares/settings_online.conf \
         /etc/calamares/settings.conf; do
    [ -f "$f" ] || continue
    if grep -q '^branding:' "$f"; then
        sed -i -E 's/^branding:.*/branding: bite-os/' "$f"
    else
        echo 'branding: bite-os' >> "$f"
    fi
done
echo "[customize_airootfs] calamares rebranded to bite-os"

# The offline 'removeuser' step deletes the live user after copy; point it at
# our live user 'bite' (cachyos defaults to 'liveuser').
if [ -f /etc/calamares/modules/removeuser.conf ]; then
    sed -i -E 's/^username:.*/username: bite/' /etc/calamares/modules/removeuser.conf
fi

# 3b. Reconcile cachyos-calamares with BITE-OS's archiso `releng` base. cachyos
#     ships its installer configs tuned for ITS OWN single-kernel, limine ISO;
#     ours differs in three ways that each break the offline install:
#
#   (a) Dual kernel. releng pulls in stock `linux` — whose `linux.preset` is the
#       LIVE-medium one: PRESETS=('archiso'), pointing at the archiso-only
#       /etc/mkinitcpio.conf.d/archiso.conf — AND we add `linux-cachyos`. The
#       Calamares `initcpio` module defaults to `kernel: all`, i.e. it runs
#       `mkinitcpio -P`, which walks EVERY preset on the target. So it reaches
#       linux.preset and dies with "archiso.conf ... must be readable" (that
#       drop-in is meaningless on an installed disk) -> the install ABORTS at
#       the initcpio step (#13), long before any shellprocess cleanup (#21+)
#       could run. Fix: point the initcpio module at our real kernel only
#       (`kernel: linux-cachyos` -> `mkinitcpio -p linux-cachyos`), so it builds
#       JUST our preset and never touches the live archiso one. The now-dead
#       linux.preset/archiso.conf (+ the stock linux kernel images) are then
#       purged from the target in the post step, so a later `mkinitcpio -P` from
#       a pacman hook on the installed system can't resurrect the same failure.
#   (b) Wrong bootloader. bootloader.conf defaults to `limine`, which is NOT in
#       our package set — the bootloader step would fail. `grub` IS installed
#       and handles BOTH BIOS and UEFI, so point Calamares at grub.
#   (c) Oversized ESP. The limine layout wants a 2 GB EFI partition mounted at
#       /boot. grub keeps kernels on the root /boot and only needs a small ESP
#       at /boot/efi, so drop it to 512M.
#
# Patch whichever location each module config lives in (/etc wins over /usr/share).
for I in /etc/calamares/modules/initcpio.conf /usr/share/calamares/modules/initcpio.conf; do
    [ -f "$I" ] || continue
    if grep -qE '^kernel:' "$I"; then
        sed -i -E 's/^kernel:.*/kernel: linux-cachyos/' "$I"
    else
        echo 'kernel: linux-cachyos' >> "$I"
    fi
    echo "[customize_airootfs] initcpio: kernel -> linux-cachyos (mkinitcpio -p, skips the live archiso linux.preset) ($I)"
done
for B in /etc/calamares/modules/bootloader.conf /usr/share/calamares/modules/bootloader.conf; do
    [ -f "$B" ] || continue
    sed -i -E 's/^efiBootLoader:.*/efiBootLoader: "grub"/' "$B"
    echo "[customize_airootfs] bootloader: efiBootLoader -> grub ($B)"
done
for P in /etc/calamares/modules/partition.conf /usr/share/calamares/modules/partition.conf; do
    [ -f "$P" ] || continue
    sed -i -E 's#^(efiSystemPartition:[[:space:]]+).*#\1"/boot/efi"#' "$P"
    sed -i -E 's/^(efiSystemPartitionSize:[[:space:]]+).*/\1512M/' "$P"
    echo "[customize_airootfs] partition: ESP -> /boot/efi @ 512M ($P)"
done

# 3c. cachyos-calamares' two shellprocess steps (shellprocess@before and the
#     post-install shellprocess, both in the OFFLINE sequence) call helper
#     scripts that only exist on CachyOS's OWN live-ISO overlay, or that assume
#     its limine/pacman-more layout. On BITE-OS's archiso `releng` base each of
#     these ABORTS the offline install — a shellprocess command that fails and
#     is NOT prefixed with '-' kills Calamares. The offenders:
#
#       try-v3   swaps /etc/pacman.conf for CachyOS's split /etc/pacman-more.conf
#                to pick v3/v4 repos. That file doesn't exist here, so its seds
#                fail AND its unconditional `mv /etc/pacman.conf .bak` WIPES the
#                target's pacman.conf before it dies with exit 1 — both aborting
#                the install and, if it ever ran to completion, leaving the
#                installed system with no pacman.conf at all. Our squashfs already
#                ships a correct pacman.conf, so this swap is pure CachyOS baggage.
#       remove-nvidia / removeun / dmcheck
#                ship only on the CachyOS ISO, not in cachyos-calamares and not in
#                our airootfs overlay -> "command not found" aborts the step. None
#                are needed: keeping all GPU drivers is what makes BITE-OS "run on
#                any GPU", the `displaymanager` module already enables sddm, and
#                our own bite-os-firstboot-cleanup handles live-only cleanup.
#       shell-setup  chsh's the new user to fish — harmless, but made non-fatal so
#                a chsh/etc-shells hiccup can't abort an otherwise-good install.
#       bootloader-post-setup  left as-is: on our grub install both its limine and
#                its systemd-boot branches are skipped, so it's already a no-op.
#
# Fix: OVERWRITE try-v3 wholesale with a safe rewrite (a surgical sed insert can
# half-apply in the chroot and leave it unguarded — that bit us once already), and
# mark the missing/optional helper calls with Calamares' documented leading-'-'
# "ignore failure" prefix. The rewrite keeps upstream CachyOS arch-detection
# behaviour when a real /etc/pacman-more.conf exists, but is a clean `exit 0`
# no-op when it doesn't — and it NEVER moves pacman.conf aside unless it can
# actually replace it, so it can neither abort the install nor leave the target
# without a pacman.conf.
TRYV3=/etc/calamares/scripts/try-v3
if [ -f "$TRYV3" ]; then
    cat > "$TRYV3" <<'TRYV3_EOF'
#!/bin/bash
# BITE-OS safe rewrite of cachyos-calamares' try-v3.
# Upstream unconditionally `mv`d /etc/pacman.conf to .bak and swapped in
# /etc/pacman-more.conf to enable CPU-arch (v3/v4/znver) repos. On BITE-OS's
# archiso base that split config does not exist, so the original failed its
# seds, WIPED the target's pacman.conf with the mv, then died exit 1 — aborting
# the install. This version is a strict no-op unless a real, non-empty
# /etc/pacman-more.conf is present, and never moves pacman.conf away unless it
# can be replaced.
set -u

pacman_conf="/etc/pacman.conf"
pacman_conf_cachyos="/etc/pacman-more.conf"
pacman_conf_path_backup="${pacman_conf}.bak"

# Safety guard: without CachyOS's split config there is nothing to swap, and
# BITE-OS already ships a correct pacman.conf. Exit cleanly so the step passes.
if [ ! -s "$pacman_conf_cachyos" ]; then
    echo "try-v3: no $pacman_conf_cachyos present — keeping existing pacman.conf (BITE-OS repos already set)."
    exit 0
fi

# A real pacman-more.conf exists -> preserve upstream CachyOS arch behaviour.
check_v3="$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep 'x86-64-v3 (' | awk '{print $1}')"
check_v4="$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep 'x86-64-v4 (' | awk '{print $1}')"
check_znver4_znver5="$(gcc -march=native -Q --help=target 2>&1 | head -n 37 | grep -E '(znver4|znver5)')"

if [ -n "$check_znver4_znver5" ]; then
    echo "znver4 or znver5 is supported"
    sed -i 's/#<disabled_znver4>//g' "$pacman_conf_cachyos"
    sed -i '/disabled_v[34]/d' "$pacman_conf_cachyos"
elif [ "$check_v4" = "x86-64-v4" ]; then
    echo "x86-64-v4 is supported"
    sed -i 's/#<disabled_v4>//g' "$pacman_conf_cachyos"
    sed -i '/disabled_v3/d' "$pacman_conf_cachyos"
    sed -i '/disabled_znver4/d' "$pacman_conf_cachyos"
elif [ "$check_v3" = "x86-64-v3" ]; then
    echo "x86-64-v3 is supported"
    sed -i 's/#<disabled_v3>//g' "$pacman_conf_cachyos"
    sed -i '/disabled_znver4/d' "$pacman_conf_cachyos"
    sed -i '/disabled_v4/d' "$pacman_conf_cachyos"
else
    echo "x86-64-v3/v4 not detected — using baseline CachyOS repos"
fi

# Only swap if the source is still present and non-empty after the seds, so we
# can never strand the target without a pacman.conf.
if [ -s "$pacman_conf_cachyos" ]; then
    echo "backup old config"
    mv -f "$pacman_conf" "$pacman_conf_path_backup"
    echo "CachyOS repo config applied"
    mv -f "$pacman_conf_cachyos" "$pacman_conf"
fi
exit 0
TRYV3_EOF
    chmod +x "$TRYV3"
    echo "[customize_airootfs] try-v3 replaced with BITE-OS safe rewrite (can neither wipe pacman.conf nor abort on missing /etc/pacman-more.conf)"
fi
for C in /etc/calamares/modules/shellprocess-before.conf \
         /usr/share/calamares/modules/shellprocess-before.conf; do
    [ -f "$C" ] || continue
    sed -i 's#command: "/usr/local/bin/remove-nvidia"#command: "-/usr/local/bin/remove-nvidia"#' "$C"
    sed -i 's#command: "/usr/local/bin/removeun"#command: "-/usr/local/bin/removeun"#' "$C"
    echo "[customize_airootfs] shellprocess@before: missing CachyOS helpers (remove-nvidia/removeun) made non-fatal ($C)"
done
for C in /etc/calamares/modules/shellprocess.conf \
         /usr/share/calamares/modules/shellprocess.conf; do
    [ -f "$C" ] || continue
    sed -i 's#command: "/usr/local/bin/dmcheck"#command: "-/usr/local/bin/dmcheck"#' "$C"
    sed -i 's#command: "/etc/calamares/scripts/shell-setup ${USER}"#command: "-/etc/calamares/scripts/shell-setup ${USER}"#' "$C"
    # bootloader-post-setup is a verified no-op on our grub install (its limine
    # and systemd-boot branches are both skipped), but it's the last un-'-' call
    # in this step — guard it too so nothing in the post step can ever abort.
    sed -i 's#command: "/etc/calamares/scripts/bootloader-post-setup"#command: "-/etc/calamares/scripts/bootloader-post-setup"#' "$C"
    echo "[customize_airootfs] shellprocess(post): dmcheck/shell-setup/bootloader-post-setup all made non-fatal ($C)"
    # Post-step cleanup of the live-medium initramfs leftovers (belt-and-braces on
    # top of the 3c-a `kernel: linux-cachyos` fix). The target still carries, from
    # the squashfs, the stock `linux` package's live archiso bits:
    #   /etc/mkinitcpio.d/linux.preset   (PRESETS=('archiso'))
    #   /etc/mkinitcpio.conf.d/archiso.conf
    # Calamares' initcpio step (#13) no longer touches them (it now runs
    # `mkinitcpio -p linux-cachyos`), so they no longer break the install — but if
    # left on disk, the NEXT `mkinitcpio -P` triggered by a routine pacman hook
    # (kernel/mkinitcpio upgrade) would walk linux.preset and fail exactly as the
    # installer used to. So purge them here, plus the stock linux kernel images
    # (no initramfs is ever built for them, so they'd only yield a dead GRUB entry),
    # then run one clean `mkinitcpio -P` — now safe, since only linux-cachyos.preset
    # remains. grub.cfg is regenerated afterwards by bootloader-post-setup (3e), so
    # the removed kernel drops out of the menu. We can't delete these at build time
    # (the LIVE ISO's own initramfs needs them) and no chroot hook runs before #13,
    # so this is the right place. Injected at the FRONT of the script list via a
    # single-line sub (robust, unlike a multi-line append) and guarded so it's idempotent.
    if ! grep -q 'mkinitcpio.conf.d/archiso.conf' "$C"; then
        sed -i 's#    - "-rm /etc/systemd/system/etc-pacman.d-gnupg.mount"#    - "-rm -f /etc/mkinitcpio.conf.d/archiso.conf /etc/mkinitcpio.d/linux.preset /boot/vmlinuz-linux /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img"\n    - "mkinitcpio -P"\n    - "-rm /etc/systemd/system/etc-pacman.d-gnupg.mount"#' "$C"
        echo "[customize_airootfs] shellprocess(post): purges live archiso linux.preset/archiso.conf + stock linux kernel, then rebuilds a clean target initramfs ($C)"
    fi
    # 3d-2. Post-install user/password sanity check. The kiosk uses the stock
    #       Calamares `users` page, so nothing in our config drops credentials —
    #       but a silent abort or users-job failure shows up as the "username
    #       became `user`, password blank" symptom. bite-os-verify-install reads
    #       the target's passwd/shadow and writes a plain verdict to
    #       /var/log/bite-os-install.log (read it off the live USB at
    #       /mnt/var/log/... before rebooting). Leading '-' = never fails install.
    if ! grep -q 'bite-os-verify-install' "$C"; then
        sed -i 's#    - "-rm /etc/systemd/system/etc-pacman.d-gnupg.mount"#    - "-rm /etc/systemd/system/etc-pacman.d-gnupg.mount"\n    - "-/usr/local/bin/bite-os-verify-install"#' "$C"
        echo "[customize_airootfs] shellprocess(post): added bite-os-verify-install user/password sanity check ($C)"
    fi
done

# 3e. Bootloader hardening (THE boot-or-not fix). The Calamares `bootloader`
#     module installs grub with a NAMED EFI entry (efibootmgr/NVRAM). VirtualBox
#     and QEMU EFI firmware do NOT persist NVRAM boot entries across reboots, so
#     the named entry vanishes and the freshly-installed disk appears unbootable
#     ("no bootable medium" / drops to the live medium). Fix: ALSO install grub to
#     the removable fallback path \EFI\BOOT\BOOTX64.EFI, which all firmware tries
#     unconditionally — and on BIOS, to the disk MBR. Appended to bootloader-post-
#     setup, which already runs in the target chroot via the post shellprocess
#     step (after the bootloader module + initramfs rebuild). No-op-safe on real
#     hardware; decisive in a VM.
BPS=/etc/calamares/scripts/bootloader-post-setup
if [ -f "$BPS" ] && ! grep -q 'BITE-OS: removable grub fallback' "$BPS"; then
    cat >> "$BPS" <<'BPS_EOF'

# --- BITE-OS: removable grub fallback (VirtualBox/QEMU EFI drop NVRAM entries) ---
if command -v grub-install >/dev/null 2>&1 && ! pacman -Qq limine 2>/dev/null; then
    if [ -d /sys/firmware/efi ]; then
        esp="$(findmnt -no TARGET /boot/efi 2>/dev/null)"; [ -n "$esp" ] || esp=/boot/efi
        grub-install --target=x86_64-efi --efi-directory="$esp" --bootloader-id=BITE-OS --recheck || true
        grub-install --target=x86_64-efi --efi-directory="$esp" --bootloader-id=BITE-OS --removable --recheck || true
    else
        rootdev="$(findmnt -no SOURCE / 2>/dev/null)"
        disk="/dev/$(lsblk -no PKNAME "$rootdev" 2>/dev/null | head -1)"
        [ -b "$disk" ] && grub-install --target=i386-pc --recheck "$disk" || true
    fi
    grub-mkconfig -o /boot/grub/grub.cfg || true
fi
BPS_EOF
    echo "[customize_airootfs] bootloader-post-setup: added removable grub fallback (EFI fallback path + BIOS MBR)"
fi

# Put the BITE-OS wolf on the GRUB boot screen (the offline install uses GRUB
# with the cachyos theme; swap its background image for ours).
GRUB_THEME=/usr/share/grub/themes/cachyos
if [ -d "$GRUB_THEME" ] && [ -f /usr/share/backgrounds/bite-os/wolf_logo.png ]; then
    for bg in "$GRUB_THEME"/background.png "$GRUB_THEME"/*.png; do
        [ -f "$bg" ] || continue
        cp -f /usr/share/backgrounds/bite-os/wolf_logo.png "$bg"
    done
    echo "[customize_airootfs] GRUB theme rebranded with BITE-OS wolf"
fi

# Make the GRUB menu say "BITE-OS" (not CachyOS/Arch). grub-mkconfig titles every
# entry with $GRUB_DISTRIBUTOR; cachyos' grub ships it set to CachyOS. Set it in
# the live /etc/default/grub — unpackfs copies that to the target, so the
# bootloader module's grub-mkconfig (#18) and the 3e fallback render "BITE-OS".
# This is a branding STRING only; it never touches the ESP/loader install path.
GRUB_DEFAULT_FILE=/etc/default/grub
if [ -f "$GRUB_DEFAULT_FILE" ]; then
    if grep -q '^[[:space:]]*GRUB_DISTRIBUTOR=' "$GRUB_DEFAULT_FILE"; then
        sed -i -E 's/^[[:space:]]*GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="BITE-OS"/' "$GRUB_DEFAULT_FILE"
    else
        echo 'GRUB_DISTRIBUTOR="BITE-OS"' >> "$GRUB_DEFAULT_FILE"
    fi
    echo "[customize_airootfs] GRUB_DISTRIBUTOR -> BITE-OS (boot menu entries will say BITE-OS)"
fi

# Wire the [bite-os] UPDATE repo — but ONLY if a signing key has been set up
# (repo/setup-signing.sh ships bite-os-repo.pub here). This lets installed
# systems pull rice updates you publish, with signature verification so nobody
# can push fake BITE-OS packages. If no key is present, this is skipped entirely
# so the OS just tracks CachyOS upstream as before.
REPO_PUBKEY=/usr/share/bite-os/bite-os-repo.pub
if [ -s "$REPO_PUBKEY" ]; then
    pacman-key --add "$REPO_PUBKEY" 2>/dev/null || true
    FPR="$(gpg --with-colons --show-keys "$REPO_PUBKEY" 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')"
    [ -n "$FPR" ] && pacman-key --lsign-key "$FPR" 2>/dev/null || true
    if ! grep -q '^\[bite-os\]' /etc/pacman.conf; then
        cat >> /etc/pacman.conf <<'EOF'

# BITE-OS rice updates (signed) — delivers GLITCH-BITE404's own changes,
# on top of the normal CachyOS/Arch upstream.
[bite-os]
SigLevel = Required
Server = https://github.com/GLITCH-BITE404/BITE-OS/releases/download/repo
EOF
    fi
    echo "[customize_airootfs] [bite-os] signed update repo wired + key trusted"
else
    echo "[customize_airootfs] no repo signing key — skipping [bite-os] update repo (CachyOS-only updates)"
fi

# 3d. Performance stack — sched-ext scheduler (scx_lavd) + the spaceship max-perf
#     power helper. Installed SYSTEM-WIDE so every BITE-OS install gets them; the
#     rice scripts that DRIVE this (ppd-spaceship-watch.sh + the fuzzel chooser)
#     ship per-user in /etc/skel via the bite-os package.
install -Dm755 /dev/stdin /usr/local/bin/bite-spaceship-power <<'SPACESHIP_EOF'
#!/usr/bin/env bash
# BITE-OS spaceship power helper (ROOT, via NOPASSWD sudo). ondemand|pinned|off
# Portable across intel_pstate + amd_pstate/generic cpufreq; every write guarded.
set -u
PSTATE=/sys/devices/system/cpu/intel_pstate
set_node() { for f in /sys/devices/system/cpu/cpu*/cpufreq/"$1"; do [ -w "$f" ] && echo "$2" > "$f" 2>/dev/null; done; return 0; }
set_turbo() {
    if [ -w "$PSTATE/no_turbo" ]; then [ "$1" = 1 ] && echo 0 > "$PSTATE/no_turbo" 2>/dev/null || echo 1 > "$PSTATE/no_turbo" 2>/dev/null; fi
    [ -w /sys/devices/system/cpu/cpufreq/boost ] && echo "$1" > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null
    return 0
}
set_floor() {
    if [ -w "$PSTATE/min_perf_pct" ]; then
        [ "$1" = max ] && echo 100 > "$PSTATE/min_perf_pct" 2>/dev/null || echo 10 > "$PSTATE/min_perf_pct" 2>/dev/null
    else
        for d in /sys/devices/system/cpu/cpu*/cpufreq; do
            [ -w "$d/scaling_min_freq" ] || continue
            if [ "$1" = max ]; then [ -r "$d/cpuinfo_max_freq" ] && cat "$d/cpuinfo_max_freq" > "$d/scaling_min_freq" 2>/dev/null
            else [ -r "$d/cpuinfo_min_freq" ] && cat "$d/cpuinfo_min_freq" > "$d/scaling_min_freq" 2>/dev/null; fi
        done
    fi
    return 0
}
case "${1:-}" in
  ondemand) set_node scaling_governor powersave;   set_node energy_performance_preference performance; set_turbo 1; set_floor low ;;
  pinned)   set_node scaling_governor performance; set_node energy_performance_preference performance; set_turbo 1; set_floor max ;;
  off)      set_node scaling_governor powersave;   set_floor low ;;
  *) echo "usage: ${0##*/} ondemand|pinned|off" >&2; exit 2 ;;
esac
SPACESHIP_EOF

install -d -m 0750 /etc/sudoers.d
cat > /etc/sudoers.d/bite-spaceship <<'SUDO_EOF'
# group-based so it works for any installed username (not just the builder's)
%wheel ALL=(root) NOPASSWD: /usr/local/bin/bite-spaceship-power ondemand, /usr/local/bin/bite-spaceship-power pinned, /usr/local/bin/bite-spaceship-power off
SUDO_EOF
chmod 440 /etc/sudoers.d/bite-spaceship

# scx_lavd as the default sched-ext scheduler (great for busy interactive desktops)
cat > /etc/scx_loader.toml <<'SCX_EOF'
default_sched = "scx_lavd"
default_mode = "Auto"
SCX_EOF
systemctl enable scx_loader.service 2>/dev/null || true
echo "[customize_airootfs] perf stack wired — bite-spaceship-power + sudoers + scx_lavd"

# 3f. Fish shell: make glitch-fetch the fetch tool for new users. cachyos-fish-config
#     OWNS /etc/skel/.config/fish/config.fish, so the bite-os package cannot ship it
#     (pacman file conflict). Instead we carry our version as an overlay asset and
#     drop it into /etc/skel here, AFTER pacstrap — overwriting CachyOS's, so a fresh
#     user's shell aliases fastfetch -> glitch-fetch and greets with the gacha engine
#     (in a TTY glitch-fetch falls back to the BITE-OS ASCII logo, never cachy).
if [ -f /usr/share/bite-os/skel-config.fish ]; then
    mkdir -p /etc/skel/.config/fish
    cp -f /usr/share/bite-os/skel-config.fish /etc/skel/.config/fish/config.fish
    echo "[customize_airootfs] /etc/skel fish config -> glitch-fetch wiring (overrode cachyos-fish-config)"
else
    echo "[customize_airootfs] WARN: /usr/share/bite-os/skel-config.fish missing — new users would get the cachyos fish config" >&2
fi

# 3g. System default cursor -> Bibata. /usr/share/icons/default/index.theme is
#     OWNED by the `default-cursors` package, so the bite-os package can't ship it
#     (pacman file conflict). Force the content here, after pacstrap, so SDDM and
#     anything before the Hyprland session use Bibata instead of the black X cursor.
if [ -d /usr/share/icons/Bibata-Modern-Classic ]; then
    mkdir -p /usr/share/icons/default
    cat > /usr/share/icons/default/index.theme <<'CURSOR_EOF'
[Icon Theme]
Name=Default
Comment=BITE-OS default cursor
Inherits=Bibata-Modern-Classic
CURSOR_EOF
    echo "[customize_airootfs] system default cursor -> Bibata-Modern-Classic"
else
    echo "[customize_airootfs] WARN: Bibata-Modern-Classic not installed — default cursor left as-is" >&2
fi

# 4. Sanity checks — fail the build loudly if a critical piece is missing.
for f in /usr/bin/cage /usr/local/bin/bite-os-installer-session \
         /usr/local/bin/bite-os-kiosk \
         /usr/share/wayland-sessions/bite-os-install.desktop \
         /etc/sddm.conf.d/99-bite-os-autologin.conf; do
    [ -e "$f" ] || { echo "[customize_airootfs] FATAL: missing $f" >&2; exit 1; }
done
command -v calamares >/dev/null || { echo "[customize_airootfs] FATAL: calamares not installed" >&2; exit 1; }
command -v grub-install >/dev/null || { echo "[customize_airootfs] FATAL: grub not installed — Calamares bootloader step (efiBootLoader: grub) would fail" >&2; exit 1; }
[ -f /etc/mkinitcpio.d/linux.preset ] && [ -f /etc/mkinitcpio.d/linux-cachyos.preset ] || { echo "[customize_airootfs] FATAL: expected both linux + linux-cachyos presets (the live build needs linux.preset=archiso for the live initramfs; the installer builds only linux-cachyos and purges linux.preset on the target)" >&2; exit 1; }
# 3c-a core fix: the installer MUST target only our kernel. If it ever reverts to
# kernel:all -> `mkinitcpio -P`, it walks the live archiso linux.preset and aborts
# the whole install ("archiso.conf must be readable"). Fail the build if not set.
for I in /etc/calamares/modules/initcpio.conf /usr/share/calamares/modules/initcpio.conf; do
    [ -f "$I" ] || continue
    grep -qE '^kernel:[[:space:]]*linux-cachyos$' "$I" || { echo "[customize_airootfs] FATAL: $I is not 'kernel: linux-cachyos' — the installer would run mkinitcpio -P and die on the live archiso linux.preset. Re-check section 3c-a." >&2; exit 1; }
done
# If cachyos-calamares ships try-v3, it MUST be our safe rewrite (see 3c) — the
# upstream one silently wipes the installed system's pacman.conf. Assert both
# that our marker is present AND that no bare `mv $pacman_conf ...` survived.
if [ -f /etc/calamares/scripts/try-v3 ]; then
    grep -q 'BITE-OS safe rewrite' /etc/calamares/scripts/try-v3 || { echo "[customize_airootfs] FATAL: try-v3 present but NOT our safe rewrite — it would wipe the target pacman.conf. cachyos-calamares layout changed; re-check section 3c." >&2; exit 1; }
    grep -Eq '^[[:space:]]*if \[ ! -s "\$pacman_conf_cachyos" \]' /etc/calamares/scripts/try-v3 || { echo "[customize_airootfs] FATAL: try-v3 is missing its missing-file guard — re-check section 3c." >&2; exit 1; }
fi
# The missing CachyOS-only helpers must be neutralised, or the offline install aborts mid-way.
for chk in '/usr/local/bin/remove-nvidia#shellprocess-before.conf' '/usr/local/bin/removeun#shellprocess-before.conf' '/usr/local/bin/dmcheck#shellprocess.conf'; do
    cmd="${chk%%#*}"; cfg="/etc/calamares/modules/${chk##*#}"
    [ -f "$cfg" ] || continue
    if grep -q "command: \"$cmd\"" "$cfg"; then
        echo "[customize_airootfs] FATAL: $cfg still calls $cmd un-neutralised — offline install will abort. Re-check section 3c." >&2; exit 1
    fi
done
# The target initramfs MUST be rebuilt clean of archiso hooks, or the installed
# system emergency-shells on boot. Assert the post step injection took.
if [ -f /etc/calamares/modules/shellprocess.conf ]; then
    grep -q 'mkinitcpio.conf.d/archiso.conf' /etc/calamares/modules/shellprocess.conf || { echo "[customize_airootfs] FATAL: shellprocess.conf did not get the archiso-initramfs cleanup injected — installed system would boot to an emergency shell. cachyos-calamares layout changed; re-check section 3c." >&2; exit 1; }
    grep -q '"mkinitcpio -P"' /etc/calamares/modules/shellprocess.conf || { echo "[customize_airootfs] FATAL: shellprocess.conf is missing the post-install 'mkinitcpio -P' rebuild — re-check section 3c." >&2; exit 1; }
fi
if [ ! -s /etc/skel/.config/hypr/hyprland.conf ]; then
    echo "[customize_airootfs] FATAL: /etc/skel rice missing — installed users won't get BITE-OS" >&2
    exit 1
fi

# 5. cachyos shipped Calamares 3.4.1-8 linked against Boost 1.89 but bumped the
#    repos to Boost 1.91 without rebuilding it, so calamares can't find
#    libboost_python314.so.1.89.0. We bundle the Boost 1.89 .so files (in
#    /usr/lib via the airootfs overlay) alongside 1.91; regenerate the linker
#    cache so calamares finds them.
if ls /usr/lib/libboost_python314.so.1.89.0 >/dev/null 2>&1; then
    ldconfig
    echo "[customize_airootfs] Boost 1.89 compat libs present; ldconfig refreshed"
else
    echo "[customize_airootfs] WARN: Boost 1.89 compat libs missing — calamares may not start" >&2
fi

echo "[customize_airootfs] done — live ISO is a Calamares kiosk; /etc/skel rice intact for installs."
