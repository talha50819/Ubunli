#!/usr/bin/env bash
#
# ubunli.sh  —  Ubunli
# Version: 3.0  (dynamic)
# ─────────────────────────────────────────────────────────────────────────────
# A modern installer for Kali Linux security tools on Debian / Ubuntu.
#
# Nothing is hardcoded. Ubunli discovers Kali's OFFICIAL metapackages and the
# tools inside them LIVE from APT, then lets you choose what to install:
#
#   • Browse official tool categories (kali-tools-*) fetched from the package
#     index, drill into any category, and pick exactly which tools to install.
#   • Install full system collections (kali-linux-headless / default / large /
#     everything, …) straight from Kali — the "Others" sets included.
#   • Kali's repository is added with strict APT pinning, so Kali packages are
#     NEVER auto-installed and can NEVER silently replace your system packages.
#   • Modern signed-by keyring flow (no deprecated apt-key).
#
# Reference: https://www.kali.org/docs/general-use/metapackages/
# License: MIT. Use only on systems you own or are authorized to test.
# ─────────────────────────────────────────────────────────────────────────────

set -Eeuo pipefail

# ═══════════════════════════════════════════════════════════════════════════
#  Theme
# ═══════════════════════════════════════════════════════════════════════════

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

if [[ "${LANG:-}" == *UTF-8* || "${LC_ALL:-}" == *UTF-8* ]]; then
  G_OK="✓"; G_ERR="✗"; G_ARROW="➜"; G_DOT="•"; G_SPARK="✦"
  G_TL="╭"; G_TR="╮"; G_BL="╰"; G_BR="╯"; G_H="─"; G_V="│"
  G_FULL="█"; G_EMPTY="░"; G_ELL="…"
else
  G_OK="+"; G_ERR="x"; G_ARROW=">"; G_DOT="*"; G_SPARK="*"
  G_TL="+"; G_TR="+"; G_BL="+"; G_BR="+"; G_H="-"; G_V="|"
  G_FULL="#"; G_EMPTY="-"; G_ELL="..."
fi

# Clear-to-end-of-line (only meaningful on a real terminal).
if [[ "$COLORS" -ge 8 ]]; then CLR=$'\e[K'; else CLR=''; fi

WIDTH=66
BAR_WIDTH=20

# repeat <string> <count>  — multibyte-safe (tr mangles UTF-8 glyphs).
repeat() {
  local out="" i
  for ((i = 0; i < $2; i++)); do out+="$1"; done
  printf '%s' "$out"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Logging
# ═══════════════════════════════════════════════════════════════════════════

log()  { printf '%s %s\n' "${C_BLUE}${G_ARROW}${C_RESET}" "$*"; }
ok()   { printf '%s %s\n' "${C_GREEN}${G_OK}${C_RESET}" "$*"; }
warn() { printf '%s %s\n' "${C_YELLOW}!${C_RESET}" "$*" >&2; }
err()  { printf '%s %s\n' "${C_RED}${G_ERR}${C_RESET}" "$*" >&2; }
die()  { err "$*"; exit 1; }

hr() { printf "${C_GREY}%s${C_RESET}\n" "$(repeat "$G_H" "$WIDTH")"; }

box() {
  local title="$1" pad line
  line=$(repeat "$G_H" "$((WIDTH - 2))")
  printf "${C_PURP}%s%s%s${C_RESET}\n" "$G_TL" "$line" "$G_TR"
  pad=$(( (WIDTH - 2 - ${#title}) / 2 ))
  printf "${C_PURP}%s${C_RESET}%*s${C_BOLD}${C_ACCENT}%s${C_RESET}%*s${C_PURP}%s${C_RESET}\n" \
    "$G_V" "$pad" '' "$title" "$(( WIDTH - 2 - pad - ${#title} ))" '' "$G_V"
  printf "${C_PURP}%s%s%s${C_RESET}\n" "$G_BL" "$line" "$G_BR"
}

banner() {
  clear 2>/dev/null || true
  printf "\n${C_ACCENT}${C_BOLD}"
  cat <<'EOF'
   ▗▖ ▗▖▗▄▄▖ ▗▖ ▗▖▗▖  ▗▖▗▖   ▗▄▄▄▖
   ▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌▐▛▚▖▐▌▐▌     █
   ▐▌ ▐▌▐▛▀▚▖▐▌ ▐▌▐▌ ▝▜▌▐▌     █
   ▝▚▄▞▘▐▙▄▞▘▝▚▄▞▘▐▌  ▐▌▐▙▄▄▖▗▄█▄▖
EOF
  printf "${C_RESET}${C_GREY}   Ubunli ${G_DOT} dynamic Kali metapackage installer${C_RESET}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Progress bars & time estimates
# ═══════════════════════════════════════════════════════════════════════════

# fmt_time <seconds>  ->  "42s" / "3m07s" / "1h05m"
fmt_time() {
  local s=$1
  if   (( s >= 3600 )); then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif (( s >= 60 ));   then printf '%dm%02ds' $((s / 60)) $((s % 60))
  else                       printf '%ds' "$s"
  fi
}

# progress_bar <percent>  ->  "██████░░░░░░░░░░░░░░"
progress_bar() {
  local fill=$(( $1 * BAR_WIDTH / 100 ))
  printf '%s%s' "$(repeat "$G_FULL" "$fill")" "$(repeat "$G_EMPTY" "$((BAR_WIDTH - fill))")"
}

# pulse_bar <tick>  ->  a block bouncing across the bar (unknown progress)
pulse_bar() {
  local blk=4 span=$(( BAR_WIDTH - 4 )) pos
  pos=$(( $1 % (2 * span) )); (( pos > span )) && pos=$(( 2 * span - pos ))
  printf '%s%s%s' "$(repeat "$G_EMPTY" "$pos")" "$(repeat "$G_FULL" "$blk")" \
    "$(repeat "$G_EMPTY" "$((span - pos))")"
}

# step_status <logfile>  ->  "<percent>\t<detail>\t<summary>"
#   percent: 0-100 from APT's Status-Fd lines, or -1 if unknown.
#            Download (dlstatus) maps to 0-30%, unpack/configure (pmstatus) to 30-100%.
#   detail : what is happening right now, e.g. "Downloading nmap · 12/345"
#            or "Setting up nmap (7.94) · 120/345 set up".
#   summary: totals for the finished step, e.g. "345 downloaded · 340 set up".
step_status() {
  awk '
    function isarch(a) { return a ~ /^(amd64|i386|arm64|armhf|armel|all|ppc64el|s390x|riscv64|mips64el|loong64)$/ }
    /^(dl|pm)status:/ { last = $0; next }
    /^Get:[0-9]+ / {
      gets++; getn = substr($1, 5) + 0
      # "Get:N <url> <suite/comp> [arch] <pkg> [arch] <ver> [size]"
      item = isarch($4) ? $5 : $4
      if ($0 ~ /(In)?Release|Packages|Translation|Contents|Sources/ && NF <= 6) item = $3 " " $4
      next
    }
    /^[0-9]+ upgraded, [0-9]+ newly installed/ { total = $1 + $3; next }
    /^Setting up / { setup++; next }
    END {
      pct = -1; detail = ""; sep = " \xc2\xb7 "
      if (last != "") {
        n = split(last, f, ":")
        for (k = 3; k <= n; k++) if (f[k] ~ /^[0-9]+(\.[0-9]+)?$/) break
        if (k <= n) {
          p = int(f[k]); desc = ""
          for (j = k + 1; j <= n; j++) desc = desc (j > k + 1 ? ":" : "") f[j]
          if (f[1] == "dlstatus") {
            pct = int(p * 30 / 100)
            dltot = (match(desc, /of [0-9]+/) ? substr(desc, RSTART + 3, RLENGTH - 3) : "")
            detail = "Downloading " (item != "" ? item : "packages")
            if (getn > 0) detail = detail sep getn (dltot != "" ? "/" dltot : "")
          } else {
            pct = 30 + int(p * 70 / 100)
            detail = desc
            if (total > 0) detail = detail sep (setup + 0) "/" total " set up"
          }
        }
      } else if (item != "") detail = "Fetching " item
      summary = ""
      if (gets > 0)  summary = gets " downloaded"
      if (setup > 0) summary = summary (summary != "" ? sep : "") setup " set up"
      printf "%d\t%s\t%s\n", pct, detail, summary
    }' "$1" 2>/dev/null || printf -- '-1\t\t\n'
}

# Durations of past steps, used to estimate steps that report no progress.
STEP_HISTORY="${XDG_CACHE_HOME:-$HOME/.cache}/ubunli/step-times"
step_hint() {
  [[ -r "$STEP_HISTORY" ]] || return 0
  awk -F'\t' -v k="$1" '$1 == k { v = $2 } END { if (v != "") print v }' "$STEP_HISTORY"
}
step_record() {
  mkdir -p "$(dirname "$STEP_HISTORY")" 2>/dev/null || return 0
  { awk -F'\t' -v k="$1" '$1 != k' "$STEP_HISTORY" 2>/dev/null | tail -n 300
    printf '%s\t%s\n' "$1" "$2"; } >"$STEP_HISTORY.tmp" 2>/dev/null \
    && mv -f "$STEP_HISTORY.tmp" "$STEP_HISTORY" 2>/dev/null || true
}

# The log of the most recent failed step (read by the auto-repair logic).
LAST_LOG=$(mktemp)
trap 'rm -f "$LAST_LOG"' EXIT

run_step() {
  local msg="$1"; shift
  local logf; logf=$(mktemp)
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  [[ "${LANG:-}" == *UTF-8* ]] || frames='|/-\'
  local key="${msg#\[*\] }"             # "[3/9] Installing x" -> "Installing x"
  local hint; hint=$(step_hint "$key")
  local start=$SECONDS

  ( "$@" >"$logf" 2>&1 ) &
  local pid=$! tick=0 pct=-1 p el eta bar detail="" summary="" short="$msg"
  (( ${#short} > 26 )) && short="${short:0:25}${G_ELL}"
  local dmax=$(( ${COLUMNS:-$(tput cols 2>/dev/null || echo 80)} - 6 ))

  if [[ "$COLORS" -ge 8 ]]; then
    # Two live lines: the progress bar, then what is being downloaded/installed.
    printf '\n\e[1A'
    while kill -0 "$pid" 2>/dev/null; do
      tick=$((tick + 1))
      IFS=$'\t' read -r p detail summary < <(step_status "$logf") || true
      (( p > pct )) && pct=$p
      (( ${#detail} > dmax )) && detail="${detail:0:$((dmax - 1))}${G_ELL}"
      el=$(( SECONDS - start ))
      if (( pct > 0 )); then
        bar=$(progress_bar "$pct")
        eta="~$(fmt_time $(( el * (100 - pct) / pct ))) left"
      else
        bar=$(pulse_bar "$tick")
        if [[ -n "$hint" ]] && (( hint > el )); then eta="~$(fmt_time $((hint - el))) left"
        elif [[ -n "$hint" ]]; then eta="almost done"
        else eta="estimating${G_ELL}"; fi
      fi
      printf "\r${C_CYAN}%s${C_RESET} %-26s ${C_PURP}%s${C_RESET} ${C_BOLD}%4s${C_RESET} ${C_GREY}%s ${G_DOT} %s${C_RESET}%s\n" \
        "${frames:$((tick % ${#frames})):1}" "$short" "$bar" \
        "$( (( pct >= 0 )) && printf '%d%%' "$pct" || printf -- '--')" \
        "$(fmt_time "$el")" "$eta" "$CLR"
      printf "  ${C_GREY}%s %s${C_RESET}%s\e[1A\r" "$G_ARROW" "${detail:-working${G_ELL}}" "$CLR"
      sleep 0.2
    done
  else
    printf "%s%s " "$msg" "$([[ -n "$hint" ]] && printf ' (~%s)' "$(fmt_time "$hint")")"
    printf "... "
  fi

  local rc=0; wait "$pid" || rc=$?
  el=$(( SECONDS - start ))
  if (( rc == 0 )); then
    # The trailing $CLR wipes the "what's happening" line below the bar.
    printf "\r${C_GREEN}%s${C_RESET} %s ${C_GREY}(%s)${C_RESET}%s\n%s" "$G_OK" "$msg" "$(fmt_time "$el")" "$CLR" "$CLR"
    IFS=$'\t' read -r _ _ summary < <(step_status "$logf") || true
    [[ -n "$summary" ]] && printf "  ${C_GREY}%s %s${C_RESET}\n" "$G_ARROW" "$summary"
    step_record "$key" "$el"
    rm -f "$logf"; return 0
  else
    printf "\r${C_RED}%s${C_RESET} %s ${C_GREY}(%s)${C_RESET}%s\n%s" "$G_ERR" "$msg" "$(fmt_time "$el")" "$CLR" "$CLR"
    printf "${C_DIM}%s${C_RESET}\n" "$(grep -avE '^(dl|pm|media)status:' "$logf" | tail -n 12)"
    cp -f "$logf" "$LAST_LOG" 2>/dev/null || true
    rm -f "$logf"; return 1
  fi
}

# overall_progress <done> <total> <start-seconds>  — multi-step summary line.
overall_progress() {
  local done=$1 total=$2 el=$(( SECONDS - $3 )) pct eta
  pct=$(( done * 100 / total ))
  if (( done == 0 )); then eta="estimating${G_ELL}"
  elif (( done == total )); then eta="done"
  else eta="~$(fmt_time $(( el * (total - done) / done ))) left"; fi
  printf "\n  ${C_BOLD}Overall${C_RESET} ${C_ACCENT}%s${C_RESET} ${C_BOLD}%d/%d${C_RESET} (%d%%) ${C_GREY}%s elapsed ${G_DOT} %s${C_RESET}\n" \
    "$(progress_bar "$pct")" "$done" "$total" "$pct" "$(fmt_time "$el")" "$eta"
}

# apt-get wrapper: non-interactive (no debconf / conffile prompts can hang a
# backgrounded step, existing configs are kept) and machine-readable progress
# on stdout so run_step can draw a real progress bar.
apt_get() {
  $SUDO env DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 apt-get \
    -o APT::Status-Fd=1 -o Dpkg::Use-Pty=0 \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Auto-repair — diagnose a failed step, fix the cause, and retry
# ═══════════════════════════════════════════════════════════════════════════

MAX_ATTEMPTS=3

wait_for_apt_lock() {
  local waited=0 max=300
  if ! command -v fuser >/dev/null 2>&1; then
    log "Waiting 20s for the APT/dpkg lock to be released"; sleep 20; return 0
  fi
  while $SUDO fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
          /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
    if (( waited >= max )); then
      printf "\n"; warn "APT is still locked by another process after $(fmt_time $max)."; return 1
    fi
    printf "\r${C_YELLOW}%s${C_RESET} Another package manager is running ${G_DOT} waiting %s%s" \
      "$G_ARROW" "$(fmt_time $waited)" "$CLR"
    sleep 3; waited=$((waited + 3))
  done
  printf "\r%s" "$CLR"; ok "APT lock is free."
}

wait_for_network() {
  local waited=0 max=90
  until curl -fsSI --max-time 5 -o /dev/null "$KALI_REPO/"; do
    if (( waited >= max )); then
      printf "\n"; warn "Kali mirror still unreachable after $(fmt_time $max). Check your network."; return 1
    fi
    printf "\r${C_YELLOW}%s${C_RESET} Network/mirror unreachable ${G_DOT} retrying (%s)%s" \
      "$G_ARROW" "$(fmt_time $waited)" "$CLR"
    sleep 5; waited=$((waited + 5))
  done
  printf "\r%s" "$CLR"; ok "Network is reachable."
}

# repair_from_log <logfile>  — returns 0 if at least one fix was applied.
repair_from_log() {
  local f; f=$(mktemp); cp -f "$1" "$f"   # fix steps may overwrite LAST_LOG
  local applied=1 matched=1
  has() { grep -qiE "$1" "$f"; }

  printf "\n${C_YELLOW}${G_SPARK} Diagnosing the failure and applying fixes${C_RESET}\n"

  if has 'could not get lock|unable to acquire the dpkg|is another process using it|dpkg frontend lock'; then
    matched=0; wait_for_apt_lock && applied=0
  fi
  if has 'temporary failure resolving|could not resolve|network is unreachable|connection timed out|unable to connect|connection failed'; then
    matched=0; wait_for_network && applied=0
  fi
  if has 'no space left on device'; then
    matched=0; run_step "Cleaning APT download cache" $SUDO apt-get clean && applied=0
    warn "Disk is low: $(df -Ph / 2>/dev/null | awk 'NR==2{print $4}') free on /."
  fi
  if has 'NO_PUBKEY|EXPKEYSIG|KEYEXPIRED|signatures couldn.t be verified|is not signed'; then
    matched=0; install_kali_key && applied=0
  fi
  if has 'hash sum mismatch|failed to fetch|404 +not found|unexpected size|mirror sync in progress|not valid yet|unable to locate package|has no installation candidate|NO_PUBKEY|EXPKEYSIG'; then
    matched=0
    run_step "Clearing partial downloads" $SUDO sh -c 'rm -rf /var/lib/apt/lists/partial/* /var/cache/apt/archives/partial/*' || true
    SESSION_UPDATED=0; refresh_index && applied=0
  fi
  if has 'dpkg was interrupted|dpkg --configure -a|sub-process /usr/bin/dpkg returned an error|dpkg: error processing'; then
    matched=0; run_step "Finishing interrupted package setup" $SUDO dpkg --configure -a && applied=0
  fi
  if has 'unmet dependencies|broken packages|--fix-broken|held broken|but it is not (going to be )?installed|dpkg: error processing|trying to overwrite'; then
    matched=0; run_step "Repairing broken dependencies" apt_get install -f -y && applied=0
  fi
  if has 'trying to overwrite'; then
    warn "A Kali package conflicts with a file owned by a system package."
    warn "Ubunli will not force-overwrite system files; the retry may still fail."
  fi

  if (( matched != 0 )); then
    # Unknown error: run the standard APT/dpkg recovery sequence.
    log "Unrecognised error — running the standard recovery sequence"
    run_step "Finishing interrupted package setup" $SUDO dpkg --configure -a && applied=0
    run_step "Repairing broken dependencies" apt_get install -f -y && applied=0
  fi

  rm -f "$f"
  return "$applied"
}

# run_with_repair <message> <command...>  — run_step, auto-fix and retry on failure.
run_with_repair() {
  local msg="$1"; shift
  local attempt=1
  while true; do
    run_step "$msg" "$@" && return 0
    if (( attempt >= MAX_ATTEMPTS )); then
      err "Still failing after ${attempt} attempts — giving up on this step."
      return 1
    fi
    if ! repair_from_log "$LAST_LOG"; then
      err "No automatic fix could be applied."
      return 1
    fi
    attempt=$((attempt + 1))
    log "Retrying ${C_BOLD}${msg}${C_RESET} (attempt ${attempt}/${MAX_ATTEMPTS})"
  done
}

pause() { read -rp "$(printf "\n${C_GREY}Press Enter to continue...${C_RESET}")" _; }

# ═══════════════════════════════════════════════════════════════════════════
#  Environment
# ═══════════════════════════════════════════════════════════════════════════

SUDO=""
require_root() {
  if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || die "Run as root or install sudo."
    SUDO="sudo"
    # Ask for the password now, before any progress line can hide the prompt.
    sudo -v || die "sudo authentication failed."
  fi
}

check_base_commands() {
  local miss=() c
  for c in apt-get apt-cache dpkg-query curl gpg awk sed grep; do
    command -v "$c" >/dev/null 2>&1 || miss+=("$c")
  done
  [[ ${#miss[@]} -eq 0 ]] || die "Missing required commands: ${miss[*]}"
}

OS_ID=""; OS_CODENAME=""; ARCH=""
detect_env() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release."
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  local like="${ID_LIKE:-}"
  case "$OS_ID" in
    debian|ubuntu|kali|pop|linuxmint|elementary|zorin) : ;;
    *) [[ "$like" == *debian* || "$like" == *ubuntu* ]] \
         || die "This script targets Debian/Ubuntu-based systems (detected: $OS_ID)." ;;
  esac
  ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
  ok "Detected ${C_BOLD}${PRETTY_NAME:-$OS_ID}${C_RESET} (${OS_CODENAME:-?}, ${ARCH})"
}

# ═══════════════════════════════════════════════════════════════════════════
#  Kali repository (pinned / safe)
# ═══════════════════════════════════════════════════════════════════════════

KALI_KEYRING="/usr/share/keyrings/kali-archive-keyring.gpg"
KALI_LIST="/etc/apt/sources.list.d/ubunli-kali.list"
KALI_PIN="/etc/apt/preferences.d/ubunli-kali.pref"
KALI_KEY_URL="https://archive.kali.org/archive-keyring.gpg"
KALI_REPO="https://http.kali.org/kali"

kali_repo_present() { [[ -f "$KALI_LIST" && -f "$KALI_PIN" ]]; }

install_kali_key() {
  log "Fetching Kali archive signing key"
  curl -fsSL --retry 3 "$KALI_KEY_URL" | $SUDO gpg --batch --yes --dearmor -o "$KALI_KEYRING" 2>/dev/null \
    || return 1
  $SUDO chmod 0644 "$KALI_KEYRING"
}

setup_kali_repo() {
  kali_repo_present && return 0
  box "ADDING KALI REPOSITORY (PINNED / SAFE)"
  printf "${C_GREY} Kali packages are pinned BELOW your system's, so they never install\n"
  printf " or upgrade automatically — only when you explicitly choose them.${C_RESET}\n"
  hr
  run_with_repair "Installing prerequisites" \
    apt_get install -y --no-install-recommends ca-certificates curl gnupg apt-transport-https \
    || die "Could not install prerequisites."

  install_kali_key || die "Failed to fetch/verify Kali signing key. Check your network settings."

  printf 'deb [signed-by=%s] %s kali-rolling main contrib non-free non-free-firmware\n' \
    "$KALI_KEYRING" "$KALI_REPO" | $SUDO tee "$KALI_LIST" >/dev/null

  $SUDO tee "$KALI_PIN" >/dev/null <<EOF
# Installed by ubunli.sh — Kali packages never auto-selected (priority 50).
Package: *
Pin: release o=Kali
Pin-Priority: 50
EOF
  ok "Repository, pin, and key installed."
  SESSION_UPDATED=0
  refresh_index
}

remove_kali_repo() {
  box "REMOVING KALI REPOSITORY"
  $SUDO rm -f "$KALI_LIST" "$KALI_PIN" "$KALI_KEYRING"
  run_step "Refreshing package index" apt_get update
  ok "Kali repository, pin, and key removed. Installed tools remain."
}

ensure_repo_ready() {
  # Everything is discovered from Kali's index, so the repo must exist AND its
  # package index must be downloaded before we can list or install anything.
  kali_repo_present || setup_kali_repo
  refresh_index
  if ! kali_index_ready; then
    err "The Kali package index isn't available to APT."
    err "A Kali mirror was probably unreachable during 'apt-get update'."
    err "Check your network settings / proxy, then use menu option 3 to"
    err "re-add the repository, and try again."
    return 1
  fi
  return 0
}

SESSION_UPDATED=0
refresh_index() {
  # Refresh the APT index once per session; surface failures clearly.
  [[ "$SESSION_UPDATED" == "1" ]] && return 0
  if run_step "Refreshing package index" apt_get update; then
    SESSION_UPDATED=1
  else
    warn "'apt-get update' reported errors — the Kali index may be incomplete."
    warn "If a Kali mirror is unreachable, check your network settings."
  fi
}

kali_index_ready() {
  # True only if APT actually has the Kali repository in its index.
  apt-cache policy 2>/dev/null \
    | grep -qiE 'o=kali|kali-rolling|https?://[^ ]*kali'
}

has_candidate() {
  # True if APT has an installable candidate version for the package.
  local c
  c=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2}')
  [[ -n "$c" && "$c" != "(none)" ]]
}

# ═══════════════════════════════════════════════════════════════════════════
#  Dynamic discovery — everything below is fetched LIVE from APT
# ═══════════════════════════════════════════════════════════════════════════

# Print "name<TAB>description" for every metapackage matching a regex.
# Load matches of a pattern into parallel arrays NAMES[] and DESCS[].
# Splits each "name - description" line on the FIRST " - " using pure bash,
# so package names never pick up stray whitespace.
declare -a NAMES DESCS
load_list() {
  local pattern="$1" line name desc
  NAMES=(); DESCS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    name="${line%% *}"          # first token = package name (no trailing space)
    if [[ "$line" == *" - "* ]]; then
      desc="${line#* - }"       # text after the first " - "
    else
      desc="$name"
    fi
    [[ -n "$name" ]] || continue
    NAMES+=("$name"); DESCS+=("$desc")
  done < <(apt-cache search --names-only "$pattern" 2>/dev/null | sort)
}

# Print the member tools of a metapackage (its Depends + Recommends),
# fetched live. Virtual packages and nested kali-* metas are filtered out.
members() {
  apt-cache depends "$1" 2>/dev/null \
    | awk '/Depends:|Recommends:/ {print $NF}' \
    | grep -Ev '^<|^kali-' | sort -u
}

# ═══════════════════════════════════════════════════════════════════════════
#  Selection parser  ("1 3 5-7 a")
# ═══════════════════════════════════════════════════════════════════════════

parse_selection() {
  # parse_selection "<input>" <max> -> echoes sorted unique indices (1-based)
  local input="$1" max="$2" tok out=()
  for tok in $input; do
    if [[ "$tok" =~ ^[0-9]+-[0-9]+$ ]]; then
      local a="${tok%-*}" b="${tok#*-}" i
      (( a <= b )) || { local t=$a; a=$b; b=$t; }
      for ((i=a; i<=b; i++)); do (( i>=1 && i<=max )) && out+=("$i"); done
    elif [[ "$tok" =~ ^[0-9]+$ ]]; then
      (( tok>=1 && tok<=max )) && out+=("$tok")
    fi
  done
  printf '%s\n' "${out[@]:-}" | grep -v '^$' | sort -nu
}

# ═══════════════════════════════════════════════════════════════════════════
#  Install
# ═══════════════════════════════════════════════════════════════════════════

# Install a list of individual packages (pinned to prefer system versions,
# reaching into Kali only where needed), one at a time, then verify.
install_packages() {
  local pkgs=("$@")
  [[ ${#pkgs[@]} -gt 0 ]] || { warn "Nothing to install."; return; }

  banner
  box "INSTALL PLAN"
  printf "${C_GREY} %d package(s):${C_RESET}\n\n" "${#pkgs[@]}"
  printf '%s ' "${pkgs[@]}" | fold -s -w "$WIDTH" | sed 's/^/  /'
  hr
  printf "${C_YELLOW}Proceed? [y/N] ${C_RESET}"; read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] || { warn "Cancelled."; return; }

  run_step "Refreshing package index" apt_get update || true

  local failed=() p total=${#pkgs[@]} done_n=0 t0=$SECONDS
  for p in "${pkgs[@]}"; do
    overall_progress "$done_n" "$total" "$t0"
    done_n=$((done_n + 1))
    if ! has_candidate "$p"; then
      warn "No candidate for ${p} (not in index for your release/arch) — skipping."
      failed+=("$p"); continue
    fi
    if run_with_repair "[${done_n}/${total}] Installing ${p}" \
         apt_get install -y --no-install-recommends -t kali-rolling "$p"; then :; else
      failed+=("$p")
    fi
  done
  overall_progress "$total" "$total" "$t0"

  # Verify via dpkg.
  local n_ok=0 n_miss=0
  for p in "${pkgs[@]}"; do
    if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed"; then
      n_ok=$((n_ok+1)); else n_miss=$((n_miss+1)); fi
  done

  hr
  printf "  ${C_GREEN}Installed:${C_RESET} %d    ${C_RED}Unavailable:${C_RESET} %d\n" "$n_ok" "$n_miss"
  if [[ ${#failed[@]} -gt 0 ]]; then
    warn "Not installable on ${OS_ID}/${ARCH}: ${failed[*]}"
    printf "${C_GREY}  (These may not be built for your release/architecture.)${C_RESET}\n"
  else
    ok "${C_BOLD}All selected tools installed.${C_RESET}"
  fi
}

# Install a whole metapackage directly (APT resolves its members).
install_metapackage() {
  local pkg="$1" label="$2"
  banner
  box "$label"

  if ! has_candidate "$pkg"; then
    refresh_index
    if ! has_candidate "$pkg"; then
      err "APT has no installable candidate for '${pkg}'."
      err "The Kali index isn't loaded for your system. Likely causes:"
      err "  • a Kali mirror was unreachable during 'apt-get update'"
      err "  • the repository wasn't added (menu option 3)"
      err "Check your network settings, re-add the repo, then retry."
      return 1
    fi
  fi

  printf "${C_GREY} '%s' is an official Kali metapackage; APT resolves everything it\n" "$pkg"
  printf " pulls in. This can be a large download.${C_RESET}\n"
  [[ "$pkg" == "kali-linux-everything" ]] && {
    printf "\n${C_RED}${C_BOLD} WARNING:${C_RESET}${C_RED} kali-linux-everything installs every Kali tool and\n"
    printf " metapackage — very large, and pulls many Kali-specific dependencies\n"
    printf " onto a Debian/Ubuntu system.${C_RESET}\n"
  }
  hr
  printf "${C_YELLOW}Run a dry-run simulation first? [Y/n] ${C_RESET}"; read -r sim
  if [[ ! "$sim" =~ ^[Nn]$ ]]; then
    run_step "Simulating ${pkg}" \
      $SUDO apt-get install -s -t kali-rolling "$pkg" \
      || { err "Simulation failed; nothing was installed."; return 1; }
  fi
  printf "\n${C_YELLOW}Install ${pkg} now? [y/N] ${C_RESET}"; read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] || { warn "Cancelled."; return; }
  run_with_repair "Installing ${pkg}" \
    apt_get install -y -t kali-rolling "$pkg" \
    && ok "${pkg} installed." || err "Failed to install ${pkg}."
}

# ═══════════════════════════════════════════════════════════════════════════
#  Flow 1 — browse tool categories, then pick tools
# ═══════════════════════════════════════════════════════════════════════════

pick_tools_from_category() {
  local cat="$1" desc="$2"
  local tools=()
  banner
  box "LOADING: $cat"
  mapfile -t tools < <(members "$cat")
  if [[ ${#tools[@]} -eq 0 ]]; then
    warn "No tools resolved for ${cat} (is the Kali index loaded?)."
    pause; return
  fi

  while true; do
    banner
    box "$cat"
    printf "${C_GREY} %s${C_RESET}\n\n" "$desc"
    local i
    for i in "${!tools[@]}"; do
      printf "  ${C_BOLD}%3d${C_RESET}  ${C_CYAN}%s${C_RESET}\n" "$((i+1))" "${tools[$i]}"
    done
    hr
    printf "  ${C_GREY}Select tools to install: numbers/ranges (e.g. ${C_RESET}1 3 5-8${C_GREY}),\n"
    printf "  ${C_BOLD}a${C_RESET} all   ${C_BOLD}m${C_RESET} install the whole ${cat} metapackage   ${C_BOLD}b${C_RESET} back\n\n"
    printf "${C_ACCENT}${G_SPARK}${C_RESET} choose ${G_ARROW} "
    read -r sel

    case "$sel" in
      b|B|"") return ;;
      m|M) install_metapackage "$cat" "$cat"; pause; return ;;
      a|A) install_packages "${tools[@]}"; pause; return ;;
      *)
        local idxs; mapfile -t idxs < <(parse_selection "$sel" "${#tools[@]}")
        if [[ ${#idxs[@]} -eq 0 ]]; then warn "No valid selection."; sleep 1; continue; fi
        local chosen=() n
        for n in "${idxs[@]}"; do chosen+=("${tools[$((n-1))]}"); done
        install_packages "${chosen[@]}"; pause; return
        ;;
    esac
  done
}

tools_flow() {
  ensure_repo_ready || { pause; return; }
  banner
  box "LOADING OFFICIAL TOOL CATEGORIES"
  load_list '^kali-tools-'
  if [[ ${#NAMES[@]} -eq 0 ]]; then
    err "No kali-tools-* categories found. Check network / repo, then retry."
    pause; return
  fi

  while true; do
    banner
    box "OFFICIAL KALI TOOL CATEGORIES"
    printf "${C_GREY} Fetched live from the package index — pick a category to explore.${C_RESET}\n\n"
    local i
    for i in "${!NAMES[@]}"; do
      printf "  ${C_BOLD}%2d${C_RESET}  ${C_CYAN}%-32s${C_RESET} ${C_GREY}%s${C_RESET}\n" \
        "$((i+1))" "${NAMES[$i]}" "${DESCS[$i]}"
    done
    hr
    printf "  ${C_BOLD}#${C_RESET} open a category   ${C_BOLD}b${C_RESET} back\n\n"
    printf "${C_ACCENT}${G_SPARK}${C_RESET} choose ${G_ARROW} "
    read -r sel
    case "$sel" in
      b|B|"") return ;;
      [0-9]*)
        if (( sel>=1 && sel<=${#NAMES[@]} )); then
          pick_tools_from_category "${NAMES[$((sel-1))]}" "${DESCS[$((sel-1))]}"
        fi ;;
      *) : ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════
#  Flow 2 — full system collections (System + Others)
# ═══════════════════════════════════════════════════════════════════════════

system_flow() {
  ensure_repo_ready || { pause; return; }
  banner
  box "LOADING SYSTEM COLLECTIONS"
  load_list '^kali-linux-'
  if [[ ${#NAMES[@]} -eq 0 ]]; then
    err "No kali-linux-* metapackages found. Check network / repo, then retry."
    pause; return
  fi

  while true; do
    banner
    box "KALI SYSTEM COLLECTIONS"
    printf "${C_GREY} Official system + 'Others' metapackages (headless, default, large,\n"
    printf " everything, …), fetched live. Larger installs.${C_RESET}\n\n"
    local i
    for i in "${!NAMES[@]}"; do
      printf "  ${C_BOLD}%2d${C_RESET}  ${C_CYAN}%-26s${C_RESET} ${C_GREY}%s${C_RESET}\n" \
        "$((i+1))" "${NAMES[$i]}" "${DESCS[$i]}"
    done
    hr
    printf "  ${C_BOLD}#${C_RESET} install a collection   ${C_BOLD}b${C_RESET} back\n\n"
    printf "${C_ACCENT}${G_SPARK}${C_RESET} choose ${G_ARROW} "
    read -r sel
    case "$sel" in
      b|B|"") return ;;
      [0-9]*)
        if (( sel>=1 && sel<=${#NAMES[@]} )); then
          install_metapackage "${NAMES[$((sel-1))]}" "${NAMES[$((sel-1))]}"
          pause
        fi ;;
      *) : ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════
#  Status & main menu
# ═══════════════════════════════════════════════════════════════════════════

show_status() {
  banner
  box "STATUS"
  printf "  ${C_CYAN}OS${C_RESET}         : %s\n" "${PRETTY_NAME:-$OS_ID}"
  printf "  ${C_CYAN}Arch${C_RESET}       : %s\n" "$ARCH"
  printf "  ${C_CYAN}Kali repo${C_RESET}  : %s\n" \
    "$(kali_repo_present && printf "${C_GREEN}configured (pinned)${C_RESET}" || printf "${C_GREY}not configured${C_RESET}")"
  printf "  ${C_CYAN}Disk (/)${C_RESET}   : %s free\n" \
    "$(df -Ph / 2>/dev/null | awk 'NR==2{print $4}')"
  printf "  ${C_CYAN}Privileges${C_RESET} : %s\n" "${SUDO:-root}"
}

main_menu() {
  while true; do
    banner
    printf "  ${C_GREY}%s${C_RESET}\n" "$(hr)"
    printf "  ${C_BOLD}1${C_RESET}  ${C_GREEN}${G_DOT}${C_RESET} Browse tool categories & pick tools  ${C_GREY}(kali-tools-*)${C_RESET}\n"
    printf "  ${C_BOLD}2${C_RESET}  ${C_PURP}${G_DOT}${C_RESET} Install a full system collection     ${C_GREY}(kali-linux-*)${C_RESET}\n"
    printf "  ${C_BOLD}3${C_RESET}  ${C_BLUE}${G_DOT}${C_RESET} Add / configure Kali repository (pinned)\n"
    printf "  ${C_BOLD}4${C_RESET}  ${C_YELLOW}${G_DOT}${C_RESET} Update all installed packages\n"
    printf "  ${C_BOLD}5${C_RESET}  ${C_RED}${G_DOT}${C_RESET} Remove Kali repository (keeps installed tools)\n"
    printf "  ${C_BOLD}6${C_RESET}  ${C_CYAN}${G_DOT}${C_RESET} Show status\n"
    printf "  ${C_BOLD}q${C_RESET}  ${C_GREY}${G_DOT}${C_RESET} Quit\n"
    printf "  ${C_GREY}%s${C_RESET}\n\n" "$(hr)"
    printf "${C_ACCENT}${G_SPARK}${C_RESET} select ${G_ARROW} "
    read -r opt
    case "$opt" in
      1) tools_flow ;;
      2) system_flow ;;
      3) setup_kali_repo; pause ;;
      4) run_with_repair "Updating index" apt_get update || true
         run_with_repair "Upgrading packages" apt_get upgrade -y || true; pause ;;
      5) remove_kali_repo; pause ;;
      6) show_status; pause ;;
      q|Q) printf "\n${C_GREY}Stay ethical. Test only what you're authorized to.${C_RESET}\n\n"; exit 0 ;;
      *) : ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════
#  Entry point
# ═══════════════════════════════════════════════════════════════════════════

trap 'printf "\n${C_RED}Interrupted.${C_RESET}\n"; exit 130' INT

main() {
  banner
  check_base_commands
  detect_env
  require_root
  printf "\n${C_GREY} Ubunli discovers Kali's official metapackages and tools live from APT —\n"
  printf " nothing is hardcoded. Use only on systems you own or may test.${C_RESET}\n"
  pause
  main_menu
}

main "$@"
