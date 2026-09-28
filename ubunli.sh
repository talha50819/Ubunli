#!/usr/bin/env bash
#
# ubunli.sh  —  Ubunli
# ─────────────────────────────────────────────────────────────────────────────
# A modern, interactive installer for Kali Linux security tools on
# Debian / Ubuntu (latest releases). Safe by design:
#
#   • Kali's repository is added with strict APT pinning, so Kali packages
#     are NEVER auto-installed and can NEVER silently replace your system
#     packages. They only install when YOU pick them.
#   • A "native only" mode is available that skips Kali entirely and pulls
#     the many tools that already exist in Debian/Ubuntu (universe).
#   • Uses the modern signed-by keyring flow (no deprecated apt-key).
#
# Author: generated for a Debian/Ubuntu user.
# License: MIT. Use only on systems you own or are authorized to test.
# ─────────────────────────────────────────────────────────────────────────────

set -Eeuo pipefail

# ═══════════════════════════════════════════════════════════════════════════
#  Appearance / theme
# ═══════════════════════════════════════════════════════════════════════════

# Detect color + unicode support, fall back gracefully.
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]] && command -v tput >/dev/null 2>&1; then
  COLORS=$(tput colors 2>/dev/null || echo 0)
else
  COLORS=0
fi

if [[ "$COLORS" -ge 8 ]]; then
  C_RESET=$'\e[0m';  C_BOLD=$'\e[1m';   C_DIM=$'\e[2m'
  C_RED=$'\e[38;5;203m';   C_GREEN=$'\e[38;5;114m'
  C_YELLOW=$'\e[38;5;221m';C_BLUE=$'\e[38;5;75m'
  C_PURP=$'\e[38;5;141m';  C_CYAN=$'\e[38;5;80m'
  C_GREY=$'\e[38;5;244m';  C_ACCENT=$'\e[38;5;213m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' \
  C_BLUE='' C_PURP='' C_CYAN='' C_GREY='' C_ACCENT=''
fi

# Unicode glyphs with ASCII fallback.
if [[ "${LANG:-}" == *UTF-8* || "${LC_ALL:-}" == *UTF-8* ]]; then
  G_OK="✓"; G_ERR="✗"; G_ARROW="➜"; G_DOT="•"; G_BOX_TL="╭"; G_BOX_TR="╮"
  G_BOX_BL="╰"; G_BOX_BR="╯"; G_H="─"; G_V="│"; G_SPARK="✦"
else
  G_OK="+"; G_ERR="x"; G_ARROW=">"; G_DOT="*"; G_BOX_TL="+"; G_BOX_TR="+"
  G_BOX_BL="+"; G_BOX_BR="+"; G_H="-"; G_V="|"; G_SPARK="*"
fi

WIDTH=64

# ═══════════════════════════════════════════════════════════════════════════
#  Logging helpers
# ═══════════════════════════════════════════════════════════════════════════

log()   { printf '%s %s\n' "${C_BLUE}${G_ARROW}${C_RESET}" "$*"; }
ok()    { printf '%s %s\n' "${C_GREEN}${G_OK}${C_RESET}" "$*"; }
warn()  { printf '%s %s\n' "${C_YELLOW}!${C_RESET}" "$*" >&2; }
err()   { printf '%s %s\n' "${C_RED}${G_ERR}${C_RESET}" "$*" >&2; }
die()   { err "$*"; exit 1; }

hr() { printf "${C_GREY}%*s${C_RESET}\n" "$WIDTH" '' | tr ' ' "$G_H"; }

box() {
  # Draw a titled box around a single line of text.
  local title="$1"
  local pad line
  line=$(printf "%*s" "$((WIDTH - 2))" '' | tr ' ' "$G_H")
  printf "${C_PURP}%s%s%s${C_RESET}\n" "$G_BOX_TL" "$line" "$G_BOX_TR"
  pad=$(( (WIDTH - 2 - ${#title}) / 2 ))
  printf "${C_PURP}%s${C_RESET}%*s${C_BOLD}${C_ACCENT}%s${C_RESET}%*s${C_PURP}%s${C_RESET}\n" \
    "$G_V" "$pad" '' "$title" "$(( WIDTH - 2 - pad - ${#title} ))" '' "$G_V"
  printf "${C_PURP}%s%s%s${C_RESET}\n" "$G_BOX_BL" "$line" "$G_BOX_BR"
}

banner() {
  clear 2>/dev/null || true
  printf "\n"
  printf "${C_ACCENT}${C_BOLD}"
  cat <<'EOF'
   ▗▖ ▗▖▗▄▄▖ ▗▖ ▗▖▗▖  ▗▖▗▖   ▗▄▄▄▖
   ▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌▐▛▚▖▐▌▐▌     █
   ▐▌ ▐▌▐▛▀▚▖▐▌ ▐▌▐▌ ▝▜▌▐▌     █
   ▝▚▄▞▘▐▙▄▞▘▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖▗▄█▄▖
EOF
  printf "${C_RESET}"
  printf "${C_GREY}   Ubunli ${G_DOT} modern Kali-tools installer for Debian / Ubuntu${C_RESET}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Spinner for long-running commands
# ═══════════════════════════════════════════════════════════════════════════

run_step() {
  # run_step "Message" cmd args...
  local msg="$1"; shift
  local logf; logf=$(mktemp)
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  [[ "${LANG:-}" == *UTF-8* ]] || frames='|/-\'

  ( "$@" >"$logf" 2>&1 ) &
  local pid=$!
  local i=0
  if [[ "$COLORS" -ge 8 ]]; then
    while kill -0 "$pid" 2>/dev/null; do
      i=$(( (i + 1) % ${#frames} ))
      printf "\r${C_CYAN}%s${C_RESET} %s" "${frames:$i:1}" "$msg"
      sleep 0.1
    done
  else
    printf "%s ... " "$msg"
    wait "$pid" 2>/dev/null || true
  fi

  if wait "$pid"; then
    printf "\r${C_GREEN}%s${C_RESET} %s%*s\n" "$G_OK" "$msg" 6 ''
    rm -f "$logf"
    return 0
  else
    printf "\r${C_RED}%s${C_RESET} %s\n" "$G_ERR" "$msg"
    printf "${C_DIM}%s${C_RESET}\n" "$(tail -n 15 "$logf")"
    rm -f "$logf"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  Environment checks
# ═══════════════════════════════════════════════════════════════════════════

SUDO=""
require_root() {
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
      log "Elevated privileges required; commands will use ${C_BOLD}sudo${C_RESET}."
    else
      die "Run as root or install sudo."
    fi
  fi
}

OS_ID=""; OS_CODENAME=""; OS_LIKE=""
detect_os() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_LIKE="${ID_LIKE:-}"
  OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"

  case "$OS_ID" in
    debian|ubuntu|kali|pop|linuxmint|elementary|zorin) : ;;
    *)
      if [[ "$OS_LIKE" != *debian* && "$OS_LIKE" != *ubuntu* ]]; then
        die "This script targets Debian/Ubuntu-based systems. Detected: $OS_ID"
      fi
      ;;
  esac
  ok "Detected ${C_BOLD}${PRETTY_NAME:-$OS_ID}${C_RESET} (${OS_CODENAME:-unknown codename})"
}

ARCH=""
detect_arch() {
  ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
}

# ═══════════════════════════════════════════════════════════════════════════
#  Kali repository (safe, pinned) setup
# ═══════════════════════════════════════════════════════════════════════════

KALI_KEYRING="/usr/share/keyrings/kali-archive-keyring.gpg"
KALI_LIST="/etc/apt/sources.list.d/kali-tools-installer.list"
KALI_PIN="/etc/apt/preferences.d/kali-tools-installer.pref"
KALI_KEY_URL="https://archive.kali.org/archive-keyring.gpg"
KALI_REPO="https://http.kali.org/kali"

kali_repo_present() { [[ -f "$KALI_LIST" && -f "$KALI_PIN" ]]; }

setup_kali_repo() {
  if kali_repo_present; then
    ok "Kali repository already configured (pinned)."
    return 0
  fi

  box "ADDING KALI REPOSITORY (PINNED / SAFE)"
  printf "${C_GREY}A pin is written so Kali packages have a LOWER priority than your\n"
  printf "system's. Nothing from Kali installs or upgrades unless you name it.\n${C_RESET}"
  hr

  run_step "Installing prerequisites" \
    $SUDO apt-get install -y --no-install-recommends ca-certificates curl gnupg apt-transport-https

  log "Fetching Kali archive signing key"
  if ! curl -fsSL "$KALI_KEY_URL" | $SUDO gpg --dearmor -o "$KALI_KEYRING" 2>/dev/null; then
    die "Failed to fetch/verify Kali signing key. Check your network settings."
  fi
  $SUDO chmod 0644 "$KALI_KEYRING"
  ok "Signing key installed at $KALI_KEYRING"

  printf 'deb [signed-by=%s] %s kali-rolling main contrib non-free non-free-firmware\n' \
    "$KALI_KEYRING" "$KALI_REPO" | $SUDO tee "$KALI_LIST" >/dev/null
  ok "Repository written to $KALI_LIST"

  # The critical safety net: pin everything from Kali below the system default.
  $SUDO tee "$KALI_PIN" >/dev/null <<EOF
# Installed by kali-tools-installer.sh
# Kali packages are never auto-selected; they must be requested explicitly.
Package: *
Pin: release o=Kali
Pin-Priority: 50
EOF
  ok "APT pin written to $KALI_PIN (priority 50 = never automatic)"

  run_step "Refreshing package lists" $SUDO apt-get update
}

remove_kali_repo() {
  box "REMOVING KALI REPOSITORY"
  $SUDO rm -f "$KALI_LIST" "$KALI_PIN" "$KALI_KEYRING"
  run_step "Refreshing package lists" $SUDO apt-get update
  ok "Kali repository, pin, and key removed. System packages untouched."
}

# ═══════════════════════════════════════════════════════════════════════════
#  Tool categories
#  Each entry: "Label|package1 package2 ...|short description"
#  Packages are chosen to exist in Debian/Ubuntu universe OR Kali repo.
# ═══════════════════════════════════════════════════════════════════════════

declare -A CAT_PKGS CAT_DESC
CATEGORIES_ORDER=()

add_cat() {
  local key="$1" desc="$2" pkgs="$3"
  CATEGORIES_ORDER+=("$key")
  CAT_DESC["$key"]="$desc"
  CAT_PKGS["$key"]="$pkgs"
}

add_cat "essentials"   "Core toolkit (recommended starter set)" \
  "nmap netcat-openbsd tcpdump curl wget git dnsutils whois net-tools socat"

add_cat "recon"        "Information gathering / recon" \
  "nmap masscan dnsrecon dnsenum whatweb theharvester recon-ng amass fierce"

add_cat "webapp"       "Web application testing" \
  "nikto sqlmap wfuzz gobuster dirb ffuf wpscan whatweb"

add_cat "passwords"    "Password / hash cracking" \
  "hashcat john hydra hashid crunch wordlists seclists"

add_cat "wireless"     "Wireless / Wi-Fi auditing" \
  "aircrack-ng reaver wifite kismet hostapd macchanger"

add_cat "sniffing"     "Sniffing & spoofing" \
  "wireshark tshark ettercap-text-only bettercap tcpdump mitmproxy dsniff"

add_cat "exploit"      "Exploitation frameworks" \
  "metasploit-framework exploitdb set"

add_cat "forensics"    "Digital forensics" \
  "sleuthkit autopsy foremost binwalk testdisk ddrescue exiftool"

add_cat "reversing"    "Reverse engineering" \
  "radare2 gdb ltrace strace binutils patchelf"

add_cat "vuln"         "Vulnerability analysis" \
  "nikto legion sqlmap wapiti nuclei"

# ═══════════════════════════════════════════════════════════════════════════
#  Selection state
# ═══════════════════════════════════════════════════════════════════════════

declare -A SELECTED
NATIVE_ONLY=0   # 1 = don't use Kali repo, only system repos

toggle_select() {
  local key="$1"
  if [[ "${SELECTED[$key]:-0}" == "1" ]]; then
    SELECTED[$key]=0
  else
    SELECTED[$key]=1
  fi
}

selected_count() {
  local n=0 k
  for k in "${CATEGORIES_ORDER[@]}"; do
    [[ "${SELECTED[$k]:-0}" == "1" ]] && ((n++)) || true
  done
  echo "$n"
}

collect_packages() {
  local k pkgs=""
  for k in "${CATEGORIES_ORDER[@]}"; do
    [[ "${SELECTED[$k]:-0}" == "1" ]] && pkgs+=" ${CAT_PKGS[$k]}"
  done
  echo "$pkgs" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' '
}

# ═══════════════════════════════════════════════════════════════════════════
#  Category picker (interactive multi-select)
# ═══════════════════════════════════════════════════════════════════════════

category_menu() {
  while true; do
    banner
    box "SELECT TOOL CATEGORIES"
    printf "${C_GREY} Toggle a number to add/remove. Mode: %s${C_RESET}\n\n" \
      "$([[ $NATIVE_ONLY -eq 1 ]] && printf "${C_YELLOW}native repos only${C_RESET}" || printf "${C_PURP}Kali + native (pinned)${C_RESET}")"

    local i=1 key mark
    for key in "${CATEGORIES_ORDER[@]}"; do
      if [[ "${SELECTED[$key]:-0}" == "1" ]]; then
        mark="${C_GREEN}[${G_OK}]${C_RESET}"
      else
        mark="${C_GREY}[ ]${C_RESET}"
      fi
      printf "  %s ${C_BOLD}%2d${C_RESET}  ${C_CYAN}%-12s${C_RESET} ${C_GREY}%s${C_RESET}\n" \
        "$mark" "$i" "$key" "${CAT_DESC[$key]}"
      ((i++))
    done

    hr
    printf "  ${C_BOLD}a${C_RESET} select all   ${C_BOLD}n${C_RESET} select none   ${C_BOLD}m${C_RESET} toggle native-only mode\n"
    printf "  ${C_BOLD}i${C_RESET} ${C_GREEN}install selected (%s)${C_RESET}   ${C_BOLD}e${C_RESET} ${C_ACCENT}install everything${C_RESET}   ${C_BOLD}b${C_RESET} back   ${C_BOLD}q${C_RESET} quit\n\n" "$(selected_count)"
    printf "${C_ACCENT}${G_SPARK}${C_RESET} choose ${C_ARROW} "
    read -r choice

    case "$choice" in
      [0-9]*)
        if (( choice >= 1 && choice <= ${#CATEGORIES_ORDER[@]} )); then
          toggle_select "${CATEGORIES_ORDER[$((choice-1))]}"
        fi
        ;;
      a|A) for key in "${CATEGORIES_ORDER[@]}"; do SELECTED[$key]=1; done ;;
      n|N) for key in "${CATEGORIES_ORDER[@]}"; do SELECTED[$key]=0; done ;;
      m|M) NATIVE_ONLY=$(( NATIVE_ONLY == 1 ? 0 : 1 )) ;;
      i|I)
        if [[ "$(selected_count)" -eq 0 ]]; then
          warn "Nothing selected."; sleep 1
        else
          do_install; read -rp "$(printf "\n${C_GREY}Press Enter to continue...${C_RESET}")" _
        fi
        ;;
      e|E) install_everything ;;
      b|B) return ;;
      q|Q) exit 0 ;;
      *) : ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════
#  Installation
# ═══════════════════════════════════════════════════════════════════════════

apt_install_target() {
  # Installs given packages. If NATIVE_ONLY=0, allows Kali via -t.
  local pkgs="$1"
  if [[ "$NATIVE_ONLY" -eq 1 ]]; then
    $SUDO apt-get install -y --no-install-recommends $pkgs
  else
    # -t kali-rolling lets APT satisfy names from Kali when the system repo
    # lacks them, while the pin keeps everything else on your system's version.
    $SUDO apt-get install -y --no-install-recommends -t kali-rolling $pkgs
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  Upstream fallback installers
#  For tools that are NOT packaged in plain Debian/Ubuntu repos, install them
#  directly from their official upstream source when apt can't find them.
# ═══════════════════════════════════════════════════════════════════════════

ensure_pkgs() {
  # Quietly ensure helper packages are present (curl, unzip, etc.)
  $SUDO apt-get install -y --no-install-recommends "$@" >/dev/null 2>&1 || true
}

gh_latest_tag() {
  # Print the latest release tag (e.g. v3.3.0) for owner/repo.
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1
}

dl_arch() {
  # Map dpkg arch -> the naming used by Go release binaries.
  case "$ARCH" in
    amd64) echo amd64 ;;
    arm64) echo arm64 ;;
    armhf) echo arm ;;
    i386)  echo 386 ;;
    *)     echo "$ARCH" ;;
  esac
}

fallback_metasploit() {
  # Rapid7's official omnibus installer (adds their signed APT repo).
  ensure_pkgs curl ca-certificates gnupg
  local f; f=$(mktemp)
  curl -fsSL \
    "https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb" \
    -o "$f"
  chmod 0755 "$f"
  $SUDO "$f"
  rm -f "$f"
}

fallback_nuclei() {
  # ProjectDiscovery prebuilt release binary -> /usr/local/bin.
  ensure_pkgs curl unzip ca-certificates
  local a tag ver url tmp
  a=$(dl_arch); tag=$(gh_latest_tag projectdiscovery/nuclei); ver="${tag#v}"
  [[ -n "$tag" ]] || { echo "could not resolve latest nuclei release"; return 1; }
  url="https://github.com/projectdiscovery/nuclei/releases/download/${tag}/nuclei_${ver}_linux_${a}.zip"
  tmp=$(mktemp -d)
  curl -fsSL "$url" -o "$tmp/nuclei.zip"
  unzip -o "$tmp/nuclei.zip" -d "$tmp" >/dev/null
  $SUDO install -m0755 "$tmp/nuclei" /usr/local/bin/nuclei
  rm -rf "$tmp"
}

fallback_bettercap() {
  # bettercap prebuilt release binary -> /usr/local/bin (+ runtime libs).
  # Asset names look like: bettercap_linux_amd64_2.41.0.zip  (no 'v' in version,
  # and 64-bit ARM is 'aarch64', not 'arm64').
  ensure_pkgs curl unzip ca-certificates libpcap0.8 libusb-1.0-0
  local a tag ver url tmp
  case "$ARCH" in
    amd64) a=amd64 ;;
    arm64) a=aarch64 ;;
    armhf) a=armhf ;;
    *)     a="$ARCH" ;;
  esac
  tag=$(gh_latest_tag bettercap/bettercap); ver="${tag#v}"
  [[ -n "$tag" ]] || { echo "could not resolve latest bettercap release"; return 1; }
  url="https://github.com/bettercap/bettercap/releases/download/${tag}/bettercap_linux_${a}_${ver}.zip"
  tmp=$(mktemp -d)
  curl -fsSL "$url" -o "$tmp/bettercap.zip"
  unzip -o "$tmp/bettercap.zip" -d "$tmp" >/dev/null
  $SUDO install -m0755 "$tmp/bettercap" /usr/local/bin/bettercap
  rm -rf "$tmp"
}

fallback_wpscan() {
  # WPScan is a Ruby gem; install a build toolchain then the gem.
  ensure_pkgs ruby ruby-dev build-essential ca-certificates \
    libcurl4-openssl-dev libxml2 libxml2-dev libxslt1-dev zlib1g-dev
  $SUDO gem install wpscan
}

declare -A FALLBACKS=(
  [metasploit-framework]=fallback_metasploit
  [nuclei]=fallback_nuclei
  [bettercap]=fallback_bettercap
  [wpscan]=fallback_wpscan
)

do_install() {
  local pkgs; pkgs=$(collect_packages)
  [[ -n "$pkgs" ]] || { warn "No packages resolved."; return; }

  banner
  box "INSTALL PLAN"
  printf "${C_GREY} Mode : %s${C_RESET}\n" \
    "$([[ $NATIVE_ONLY -eq 1 ]] && echo "native repositories only" || echo "Kali (pinned) + native")"
  printf "${C_GREY} Packages (%s):${C_RESET}\n\n" "$(wc -w <<<"$pkgs")"
  printf "%s\n" "$pkgs" | fold -s -w "$WIDTH" | sed 's/^/  /'
  hr
  printf "${C_YELLOW}Proceed with installation? [y/N] ${C_RESET}"
  read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] || { warn "Cancelled."; return; }

  if [[ "$NATIVE_ONLY" -eq 0 ]]; then
    setup_kali_repo
  fi

  run_step "Updating package index" $SUDO apt-get update || true

  # Install package-by-package so one missing tool doesn't abort the batch.
  local failed=() p
  for p in $pkgs; do
    if run_step "Installing ${p}" bash -c "$(declare -f apt_install_target); SUDO='$SUDO' NATIVE_ONLY='$NATIVE_ONLY' apt_install_target '$p'"; then
      :
    else
      failed+=("$p")
    fi
  done

  hr

  # For anything apt couldn't install, try the official upstream installer.
  if [[ ${#failed[@]} -gt 0 ]]; then
    local recoverable=() still_failed=()
    for p in "${failed[@]}"; do
      [[ -n "${FALLBACKS[$p]:-}" ]] && recoverable+=("$p") || still_failed+=("$p")
    done

    if [[ ${#recoverable[@]} -gt 0 ]]; then
      log "Trying upstream sources for: ${recoverable[*]}"
      for p in "${recoverable[@]}"; do
        if run_step "Installing ${p} (upstream)" "${FALLBACKS[$p]}"; then
          :
        else
          still_failed+=("$p")
        fi
      done
    fi
    failed=("${still_failed[@]}")
  fi

  if [[ ${#failed[@]} -eq 0 ]]; then
    ok "${C_BOLD}All selected tools installed successfully.${C_RESET}"
  else
    warn "Installed with ${#failed[@]} package(s) unavailable for your release/arch:"
    printf "   ${C_DIM}%s${C_RESET}\n" "${failed[*]}"
    printf "${C_GREY}   (Not packaged for %s/%s and no upstream fallback succeeded.\n" "$OS_ID" "$ARCH"
    printf "   Check your network settings or install them manually.)${C_RESET}\n"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  Install everything (all categories at once)
# ═══════════════════════════════════════════════════════════════════════════

install_everything() {
  banner
  box "INSTALL EVERYTHING"
  printf "${C_YELLOW} This selects ALL categories and installs every listed tool.\n"
  printf " Expect a large download and significant disk usage.${C_RESET}\n"
  hr
  printf "${C_GREY} Mode: %s${C_RESET}\n\n" \
    "$([[ $NATIVE_ONLY -eq 1 ]] && echo "native repositories only" || echo "Kali (pinned) + native")"
  printf "${C_YELLOW}Continue? [y/N] ${C_RESET}"
  read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] || { warn "Cancelled."; return; }

  local key
  for key in "${CATEGORIES_ORDER[@]}"; do SELECTED[$key]=1; done
  # Skip the extra confirmation inside do_install by pre-answering.
  do_install <<<"y"
  read -rp "$(printf "\n${C_GREY}Press Enter to continue...${C_RESET}")" _
}

# ═══════════════════════════════════════════════════════════════════════════
#  Kali metapackage shortcut (uses Kali's own kali-tools-* bundles)
# ═══════════════════════════════════════════════════════════════════════════

metapackage_menu() {
  local metas=(
    "kali-linux-headless|Core CLI tool set (no GUI)"
    "kali-tools-top10|The 10 most-used Kali tools"
    "kali-tools-web|Web assessment metapackage"
    "kali-tools-passwords|Password attack metapackage"
    "kali-tools-wireless|Wireless metapackage"
    "kali-tools-information-gathering|Recon metapackage"
  )
  banner
  box "KALI METAPACKAGES (requires Kali repo)"
  printf "${C_GREY} These are Kali's own curated bundles. Larger downloads.${C_RESET}\n\n"
  local i=1 m
  for m in "${metas[@]}"; do
    printf "  ${C_BOLD}%2d${C_RESET}  ${C_CYAN}%-32s${C_RESET} ${C_GREY}%s${C_RESET}\n" \
      "$i" "${m%%|*}" "${m#*|}"
    ((i++))
  done
  hr
  printf "${C_ACCENT}${G_SPARK}${C_RESET} number to install, ${C_BOLD}b${C_RESET} back ${C_ARROW} "
  read -r sel
  [[ "$sel" =~ ^[0-9]+$ ]] || return
  (( sel >= 1 && sel <= ${#metas[@]} )) || return
  local pkg="${metas[$((sel-1))]%%|*}"

  NATIVE_ONLY=0
  setup_kali_repo
  run_step "Installing ${pkg} (this can take a while)" \
    bash -c "$SUDO apt-get install -y -t kali-rolling $pkg" \
    && ok "${pkg} installed." || err "Failed to install ${pkg}."
  read -rp "$(printf "\n${C_GREY}Press Enter to continue...${C_RESET}")" _
}

# ═══════════════════════════════════════════════════════════════════════════
#  Main menu
# ═══════════════════════════════════════════════════════════════════════════

main_menu() {
  while true; do
    banner
    printf "  ${C_GREY}%s${C_RESET}\n" "$(hr)"
    printf "  ${C_BOLD}1${C_RESET}  ${C_GREEN}${G_DOT}${C_RESET} Choose tool categories & install\n"
    printf "  ${C_BOLD}2${C_RESET}  ${C_ACCENT}${G_SPARK}${C_RESET} ${C_BOLD}Install EVERYTHING${C_RESET} (all categories)\n"
    printf "  ${C_BOLD}3${C_RESET}  ${C_PURP}${G_DOT}${C_RESET} Install Kali metapackages (curated bundles)\n"
    printf "  ${C_BOLD}4${C_RESET}  ${C_BLUE}${G_DOT}${C_RESET} Add / configure Kali repository (pinned)\n"
    printf "  ${C_BOLD}5${C_RESET}  ${C_YELLOW}${G_DOT}${C_RESET} Update all installed packages\n"
    printf "  ${C_BOLD}6${C_RESET}  ${C_RED}${G_DOT}${C_RESET} Remove Kali repository (keeps installed tools)\n"
    printf "  ${C_BOLD}7${C_RESET}  ${C_CYAN}${G_DOT}${C_RESET} Show system / status info\n"
    printf "  ${C_BOLD}q${C_RESET}  ${C_GREY}${G_DOT}${C_RESET} Quit\n"
    printf "  ${C_GREY}%s${C_RESET}\n\n" "$(hr)"
    printf "${C_ACCENT}${G_SPARK}${C_RESET} select ${C_ARROW} "
    read -r opt

    case "$opt" in
      1) category_menu ;;
      2) install_everything ;;
      3) metapackage_menu ;;
      4) NATIVE_ONLY=0; setup_kali_repo; read -rp "$(printf "\n${C_GREY}Press Enter...${C_RESET}")" _ ;;
      5) run_step "Updating index" $SUDO apt-get update
         run_step "Upgrading packages" $SUDO apt-get upgrade -y
         read -rp "$(printf "\n${C_GREY}Press Enter...${C_RESET}")" _ ;;
      6) remove_kali_repo; read -rp "$(printf "\n${C_GREY}Press Enter...${C_RESET}")" _ ;;
      7) show_status; read -rp "$(printf "\n${C_GREY}Press Enter...${C_RESET}")" _ ;;
      q|Q) printf "\n${C_GREY}Stay ethical. Test only what you're authorized to.${C_RESET}\n\n"; exit 0 ;;
      *) : ;;
    esac
  done
}

show_status() {
  banner
  box "STATUS"
  printf "  ${C_CYAN}OS${C_RESET}          : %s\n" "${PRETTY_NAME:-$OS_ID}"
  printf "  ${C_CYAN}Codename${C_RESET}    : %s\n" "${OS_CODENAME:-unknown}"
  printf "  ${C_CYAN}Arch${C_RESET}        : %s\n" "$ARCH"
  printf "  ${C_CYAN}Kali repo${C_RESET}   : %s\n" \
    "$(kali_repo_present && printf "${C_GREEN}configured (pinned)${C_RESET}" || printf "${C_GREY}not configured${C_RESET}")"
  printf "  ${C_CYAN}sudo${C_RESET}        : %s\n" "${SUDO:-running as root}"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Entry point
# ═══════════════════════════════════════════════════════════════════════════

trap 'printf "\n${C_RED}Interrupted.${C_RESET}\n"; exit 130' INT

main() {
  banner
  detect_os
  detect_arch
  require_root
  printf "\n${C_GREY}Only use these tools on systems you own or are explicitly authorized\n"
  printf "to test. Unauthorized access is illegal.${C_RESET}\n"
  read -rp "$(printf "\n${C_GREY}Press Enter to open the menu...${C_RESET}")" _
  main_menu
}

main "$@"
