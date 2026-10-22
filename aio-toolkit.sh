#!/usr/bin/env bash
# AIO Toolkit — macOS and Linux system information and app catalog.
# MIT License

set -u
IFS="$(printf ' \t\n')"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
CATALOG_FILE="$SCRIPT_DIR/catalog/apps.tsv"
OS_FAMILY="unknown"
OS_NAME="Unknown"
OS_VERSION="Unknown"
PKG_MANAGER=""
PKG_LABEL=""

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }
pause() { printf '\nPress Enter to continue...'; IFS= read -r _ || true; }
have() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
    case "$(uname -s 2>/dev/null || printf unknown)" in
        Darwin)
            OS_FAMILY="macos"
            OS_NAME="macOS"
            OS_VERSION="$(sw_vers -productVersion 2>/dev/null || printf 'Unknown')"
            ;;
        Linux)
            OS_FAMILY="linux"
            if [ -r /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                OS_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
                OS_VERSION="${VERSION_ID:-${VERSION:-Unknown}}"
            else
                OS_NAME="Linux (unknown distribution)"
                OS_VERSION="Unknown"
            fi
            ;;
        *)
            OS_FAMILY="unknown"
            OS_NAME="$(uname -s 2>/dev/null || printf 'Unknown')"
            OS_VERSION="Unknown"
            ;;
    esac
}

detect_package_manager() {
    PKG_MANAGER=""
    PKG_LABEL=""
    if [ "$OS_FAMILY" = "macos" ]; then
        if have brew; then PKG_MANAGER="brew"; PKG_LABEL="Homebrew"; fi
        return
    fi
    [ "$OS_FAMILY" = "linux" ] || return
    if have apt-get; then PKG_MANAGER="apt-get"; PKG_LABEL="APT"
    elif have dnf; then PKG_MANAGER="dnf"; PKG_LABEL="DNF"
    elif have yum; then PKG_MANAGER="yum"; PKG_LABEL="YUM"
    elif have pacman; then PKG_MANAGER="pacman"; PKG_LABEL="Pacman"
    elif have zypper; then PKG_MANAGER="zypper"; PKG_LABEL="Zypper"
    elif have apk; then PKG_MANAGER="apk"; PKG_LABEL="APK"
    fi
}

show_system_info() {
    detect_os
    detect_package_manager
    bold "System Information"
    printf 'Operating system : %s\n' "$OS_NAME"
    printf 'OS version       : %s\n' "$OS_VERSION"
    printf 'Kernel           : %s\n' "$(uname -sr 2>/dev/null || printf Unknown)"
    printf 'Architecture     : %s\n' "$(uname -m 2>/dev/null || printf Unknown)"
    printf 'Hostname         : %s\n' "$(hostname 2>/dev/null || printf Unknown)"
    printf 'Shell            : %s\n' "${SHELL:-Unknown}"
    printf 'Package manager  : %s\n' "${PKG_LABEL:-Not detected}"
    if [ "$OS_FAMILY" = "macos" ]; then
        printf 'Mac model        : %s\n' "$(sysctl -n hw.model 2>/dev/null || printf Unknown)"
        printf 'CPU cores        : %s\n' "$(sysctl -n hw.ncpu 2>/dev/null || printf Unknown)"
        printf 'Memory           : '
        if have sysctl; then
            bytes="$(sysctl -n hw.memsize 2>/dev/null || printf 0)"
            awk -v b="$bytes" 'BEGIN { if (b > 0) printf "%.1f GiB\n", b/1073741824; else print "Unknown" }'
        else printf 'Unknown\n'; fi
    elif [ "$OS_FAMILY" = "linux" ]; then
        if [ -r /etc/os-release ]; then
            printf 'Distro ID        : %s\n' "${ID:-unknown}"
            printf 'Distro codename  : %s\n' "${VERSION_CODENAME:-${UBUNTU_CODENAME:-Not reported}}"
        fi
        if [ -r /proc/meminfo ]; then
            awk '/MemTotal:/ { printf "Memory           : %.1f GiB\n", $2/1048576; exit }' /proc/meminfo
        fi
    fi
    printf '\n'
}

open_brew_help() {
    printf '\nHomebrew is required to install catalog apps on macOS, but it was not found.\n'
    printf 'Install it using the official instructions: https://brew.sh/\n'
    printf 'The toolkit will not run a remote installer automatically.\n\n'
    if have open; then
        printf 'Open the Homebrew website now? [y/N] '
        IFS= read -r answer || answer="n"
        case "$answer" in y|Y|yes|YES) open "https://brew.sh/" ;; esac
    elif have xdg-open; then
        printf 'Open the Homebrew website now? [y/N] '
        IFS= read -r answer || answer="n"
        case "$answer" in y|Y|yes|YES) xdg-open "https://brew.sh/" >/dev/null 2>&1 & ;; esac
    fi
}

linux_pkg_install() {
    package="$1"
    case "$PKG_MANAGER" in
        apt-get) sudo apt-get install -y -- "$package" ;;
        dnf) sudo dnf install -y -- "$package" ;;
        yum) sudo yum install -y -- "$package" ;;
        pacman) sudo pacman -S --needed --noconfirm -- "$package" ;;
        zypper) sudo zypper --non-interactive install -- "$package" ;;
        apk) sudo apk add -- "$package" ;;
        *) error "No supported Linux package manager was detected."; return 1 ;;
    esac
}

install_package() {
    package="$1"
    if [ "$OS_FAMILY" = "macos" ]; then
        if ! have brew; then open_brew_help; return 1; fi
        brew install -- "$package"
        return $?
    fi
    if [ "$OS_FAMILY" != "linux" ]; then
        error "Application installation is only supported on macOS and Linux."
        return 1
    fi
    detect_package_manager
    if [ -z "$PKG_MANAGER" ]; then
        error "No supported package manager found (APT, DNF, YUM, Pacman, Zypper, APK)."
        printf 'You can install Flatpak separately if you prefer its catalog entries.\n'
        return 1
    fi
    linux_pkg_install "$package"
}

install_flatpak() {
    app_id="$1"
    if ! have flatpak; then
        warn "Flatpak is not installed. Install Flatpak using your distribution's instructions, then retry."
        return 1
    fi
    flatpak install --user -y flathub "$app_id"
}

catalog_menu() {
    if [ ! -r "$CATALOG_FILE" ]; then
        error "Catalog not found: $CATALOG_FILE"
        return
    fi
    if [ "$OS_FAMILY" = "unknown" ]; then
        error "The catalog supports macOS and Linux only."
        return
    fi
    if [ "$OS_FAMILY" = "macos" ] && ! have brew; then
        open_brew_help
        return
    fi

    while :; do
        printf '\n'
        bold "Application Catalog — $OS_NAME"
        printf '  0) Back\n'
        awk -F '\t' -v os="$OS_FAMILY" 'NR > 1 && ($1 == os || $1 == "both") { printf "  %d) %s — %s\n", ++n, $3, $4 } END { if (n == 0) print "No apps available for this platform." }' "$CATALOG_FILE"
        printf '\nSelect an app to install: '
        IFS= read -r choice || return
        [ "$choice" = "0" ] && return
        case "$choice" in ''|*[!0-9]*) warn "Enter a valid number."; continue ;; esac

        selected="$(awk -F '\t' -v os="$OS_FAMILY" -v wanted="$choice" '
            NR > 1 && ($1 == os || $1 == "both") {
                n++
                if (n == wanted) { print $2 "\t" $3; exit }
            }' "$CATALOG_FILE")"
        if [ -z "$selected" ]; then warn "No app exists at that number."; continue; fi
        package="${selected%%$(printf '\t')*}"
        display="${selected#*$(printf '\t')}"
        printf '\nInstall %s? [y/N] ' "$display"
        IFS= read -r confirm || confirm="n"
        case "$confirm" in y|Y|yes|YES) ;; *) info "Cancelled."; continue ;; esac

        case "$package" in
            flatpak:*)
                install_flatpak "${package#flatpak:}"
                result=$?
                ;;
            *)
                install_package "$package"
                result=$?
                ;;
        esac
        if [ "$result" -eq 0 ]; then info "$display installation completed."
        else warn "Installation failed. Check the package name and your distribution's repositories."; fi
    done
}

show_help() {
    cat <<'EOF'
AIO Toolkit — Help

1. System Information: show detected OS, version, architecture, and hardware.
2. Application Catalog: install an app from the bundled catalog.
3. Package Manager Status: check supported package managers.
4. Help: show this help.
5. Exit: quit the toolkit.

macOS catalog installs use Homebrew. Linux installs use the first detected
supported native package manager. Entries beginning with "flatpak:" use Flatpak.
Review catalog/apps.tsv before adding or installing entries.
EOF
}

show_package_status() {
    bold "Package Manager Status"
    for manager in brew apt-get dnf yum pacman zypper apk flatpak; do
        if have "$manager"; then printf '  %-10s Available (%s)\n' "$manager" "$(command -v "$manager")"
        else printf '  %-10s Not found\n' "$manager"; fi
    done
    if [ "$OS_FAMILY" = "macos" ] && ! have brew; then
        printf '\nHomebrew is required for macOS app installation.\n'
    fi
}

main() {
    detect_os
    while :; do
        printf '\n'
        bold "================================"
        bold "          AIO TOOLKIT"
        bold "================================"
        printf 'Detected: %s %s (%s)\n\n' "$OS_NAME" "$OS_VERSION" "$(uname -m 2>/dev/null || printf unknown)"
        printf '  1) System Information\n'
        printf '  2) Application Catalog\n'
        printf '  3) Package Manager Status\n'
        printf '  4) Help\n'
        printf '  5) Exit\n'
        printf '\nChoose an option: '
        IFS= read -r choice || { printf '\n'; exit 0; }
        case "$choice" in
            1) show_system_info; pause ;;
            2) catalog_menu ;;
            3) show_package_status; pause ;;
            4) show_help; pause ;;
            5) printf 'Goodbye!\n'; exit 0 ;;
            *) warn "Invalid choice. Select 1–5." ;;
        esac
    done
}

main "$@"
