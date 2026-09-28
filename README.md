<div align="center">

# Ubunli

<p>
  <img src="https://cdn.simpleicons.org/kalilinux/557C94" alt="Kali Linux" height="64" />
  &nbsp;&nbsp;&nbsp;
  <img src="https://cdn.simpleicons.org/debian/A81D33" alt="Debian" height="64" />
  &nbsp;&nbsp;&nbsp;
  <img src="https://cdn.simpleicons.org/ubuntu/E95420" alt="Ubuntu" height="64" />
</p>

**A modern, interactive installer for Kali Linux security tools on Debian &amp; Ubuntu.**

Pick tool categories from a clean terminal menu — or install everything — without breaking your system.

<p>
  <img src="https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge&logo=kalilinux&logoColor=white" alt="Kali Linux" />
  <img src="https://img.shields.io/badge/Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white" alt="Debian" />
  <img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu" />
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
</p>

</div>

---

## ⚠️ Legal &amp; Safety Warning — Read Before Use

> **Ubunli installs offensive security and penetration-testing tools.** These tools are powerful and can cause harm if misused.

- **Authorized use only.** Use these tools **exclusively** on systems, networks, and accounts that you **own** or have **explicit written permission** to test. Unauthorized scanning, access, or attack of computers and networks is a **crime** in most jurisdictions (e.g. the U.S. Computer Fraud and Abuse Act, the UK Computer Misuse Act, and equivalents worldwide) and can lead to **criminal prosecution and civil liability**.
- **You are solely responsible** for how you use this software and the tools it installs. The authors and contributors accept **no liability** for misuse or for any damage to your systems or data.
- **This is not a Kali replacement.** Adding another distribution's packages to Debian/Ubuntu always carries some risk. Ubunli mitigates this with strict APT pinning (see [Safety design](#-safety-design)), but the safest environment for this kind of work is a **dedicated VM or container**, or **Kali Linux** itself.
- **No warranty.** This project is provided "as is", without warranty of any kind. See [License](#-license).

By downloading, running, or contributing to this project you acknowledge that you have read and understood this warning.

---

## Features

- 🎛️ **Interactive TUI** — colored menus, category toggles, progress spinners.
- 🧩 **Category-based selection** — recon, web, passwords, wireless, sniffing, exploitation, forensics, reversing, and more.
- 📦 **Install everything** — one option to pull every listed tool.
- 🐉 **Kali metapackages** — install Kali's own curated `kali-tools-*` bundles.
- 🛡️ **Safe by design** — Kali's repo is added with a pin so it can **never** silently upgrade or replace your system packages.
- 🌿 **Native-only mode** — skip Kali entirely and install the many tools already in Debian/Ubuntu `universe`.
- ⬆️ **Upstream fallbacks** — tools missing from apt (Metasploit, nuclei, bettercap, wpscan) install automatically from their official upstream sources.
- 🔑 **Modern keyring flow** — uses `signed-by` keyrings, not the deprecated `apt-key`.

---

## Requirements

- Debian or Ubuntu (latest releases) or a close derivative (Pop!\_OS, Mint, Zorin, elementary).
- `bash`, `sudo`, and an internet connection.
- On Ubuntu, enable the `universe` component for native mode:
  ```bash
  sudo add-apt-repository universe
  ```

---

## Installation &amp; Usage

```bash
# 1. Clone the repository
git clone https://github.com/talha50819/Ubunli.git
cd Ubunli

# 2. Make the script executable
chmod +x ubunli.sh

# 3. Run it
./ubunli.sh
```

The script requests elevated privileges via `sudo` only when it needs to touch APT.

### Main menu

| Option | Action |
| :----: | :----- |
| 1 | Choose tool categories &amp; install |
| 2 | **Install everything** (all categories) |
| 3 | Install Kali metapackages (curated bundles) |
| 4 | Add / configure the Kali repository (pinned) |
| 5 | Update all installed packages |
| 6 | Remove the Kali repository (keeps installed tools) |
| 7 | Show system / status info |

### Modes

- **Kali + native (default):** installs from Debian/Ubuntu where possible, and falls back to the pinned Kali repo for tools not packaged natively.
- **Native only:** toggle with `m` in the category picker to avoid third-party repositories entirely.

---

## 🛡️ Safety design

The common way to get Kali tools on Ubuntu — dropping Kali's full repo into your sources — is dangerous: it lets Kali packages upgrade core system libraries and frequently **breaks the OS**. Ubunli avoids this:

1. **APT pinning.** Every package originating from Kali is pinned to `Pin-Priority: 50`, well below your system's default. This means Kali packages are **never** auto-selected and **never** replace an existing system package. They install **only** when you explicitly request them.
2. **Explicit targeting.** Installs from Kali use `-t kali-rolling`, so APT only reaches into Kali for the specific tool you asked for.
3. **Clean removal.** Option 6 removes the repository, pin, and signing key in one step. Already-installed tools remain.

You can inspect exactly what gets written:

```
/etc/apt/sources.list.d/kali-tools-installer.list   # the repo
/etc/apt/preferences.d/kali-tools-installer.pref    # the pin
/usr/share/keyrings/kali-archive-keyring.gpg        # the signing key
```

> Even with pinning, some risk remains when mixing repositories on a system you rely on. For serious or repeated use, run Ubunli in a VM/container.

---

## Tool categories

| Category | Contents (examples) |
| :------- | :------------------ |
| `essentials` | nmap, netcat, tcpdump, curl, git, whois |
| `recon` | masscan, dnsrecon, theharvester, amass, fierce |
| `webapp` | nikto, sqlmap, wfuzz, gobuster, ffuf, wpscan |
| `passwords` | hashcat, john, hydra, crunch, seclists |
| `wireless` | aircrack-ng, reaver, wifite, kismet, macchanger |
| `sniffing` | wireshark, ettercap, bettercap, mitmproxy, dsniff |
| `exploit` | metasploit-framework, exploitdb, set |
| `forensics` | sleuthkit, autopsy, foremost, binwalk, exiftool |
| `reversing` | radare2, gdb, ltrace, strace, binutils |
| `vuln` | nikto, wapiti, nuclei, legion |

Some packages (e.g. `metasploit-framework`, `nuclei`, `bettercap`, `wpscan`) are not in plain Debian/Ubuntu repos. When apt can't find one, Ubunli automatically falls back to the tool's **official upstream installer** (Rapid7's signed repo for Metasploit, GitHub release binaries for nuclei and bettercap into `/usr/local/bin`, and the `wpscan` Ruby gem). Only if both apt and the upstream fallback fail is a package reported as unavailable — the run never aborts.

---

## Troubleshooting

- **A tool "was unavailable for your release/arch."** It isn't packaged for your distro/architecture. Try Kali mode, or install it from the project's upstream source.
- **`E: The repository ... is not signed`.** Re-run option 4 to reinstall the signing key.
- **Something feels broken after installing.** Run option 6 to remove the Kali repo, then `sudo apt update`. Pinning prevents system packages from being replaced, so your base system should be intact.

---

## Contributing

Issues and pull requests are welcome. Please keep the safety model intact — any change that could let Kali packages override system packages without user consent will not be merged.

---

## Security

Found a vulnerability in Ubunli itself? Please report it privately — see
[`SECURITY.md`](SECURITY.md). Do not open a public issue for security problems.

---

## ⚖️ Trademarks &amp; Affiliation

Ubunli is an **independent, community project**. It is **not affiliated with,
endorsed by, or sponsored by** OffSec (Kali Linux), the Debian Project, or
Canonical Ltd. (Ubuntu).

"Kali Linux" and the Kali dragon logo are trademarks of OffSec. "Debian" and the
Debian logo are trademarks of Software in the Public Interest, Inc. / the Debian
Project. "Ubuntu" and the Ubuntu logo are trademarks of Canonical Ltd. All other
tool names and logos are the property of their respective owners. They are used
here only to indicate compatibility.

---

## 📄 License

Released under the **MIT License**. See [`LICENSE`](LICENSE).

The software is provided "as is", without warranty of any kind, express or implied. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability arising from the use of this software or the tools it installs.

---

<div align="center">
<sub>Stay ethical. Test only what you're authorized to.</sub>
</div>
