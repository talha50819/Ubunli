<div align="center">

# Ubunli

<p>
  <img src="https://cdn.simpleicons.org/kalilinux/557C94" alt="Kali Linux" height="64" />
  &nbsp;&nbsp;&nbsp;
  <img src="https://cdn.simpleicons.org/debian/A81D33" alt="Debian" height="64" />
  &nbsp;&nbsp;&nbsp;
  <img src="https://cdn.simpleicons.org/ubuntu/E95420" alt="Ubuntu" height="64" />
</p>

**A modern installer for Kali Linux security tools on Debian &amp; Ubuntu — driven entirely by Kali's own metapackages.**

Nothing is hardcoded. Ubunli discovers the official categories and their tools **live from APT**, then lets you pick exactly what to install.

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

## How it works

Ubunli does **not** ship a list of tools. Instead it uses Kali's [official metapackages](https://www.kali.org/docs/general-use/metapackages/) as the source of truth:

1. It adds Kali's repository (pinned, see below) and refreshes the package index.
2. **Categories** are discovered with `apt-cache search '^kali-tools-'` — the same categories Kali documents, with their live descriptions.
3. **The tools inside a category** are read with `apt-cache depends` on that metapackage, so the list is always current — no maintenance, no stale names.
4. You pick a category, then pick exactly which tools to install (or install the whole metapackage).

Because everything comes from APT at runtime, Ubunli automatically reflects new tools, renames, and removals as Kali publishes them.

---

## Features

- 🔎 **Zero hardcoded tools** — categories and their tools are fetched live from Kali's package index.
- 🧭 **Browse official categories** (`kali-tools-*`) with real descriptions, then drill into any one.
- 🎯 **Granular selection** — choose tools by number or range (`1 3 5-8`), install all, or install the whole metapackage.
- 🐉 **Full system collections** (`kali-linux-*`) including the "Others" sets: `kali-linux-large`, `kali-linux-everything`, and more.
- 🛡️ **Safe by design** — Kali's repo is pinned so it can **never** silently upgrade or replace your system packages.
- ✅ **Verification &amp; dry-runs** — per-package `dpkg` verification, and an optional APT simulation before big metapackage installs.
- 🔑 **Modern keyring flow** — uses `signed-by` keyrings, not the deprecated `apt-key`.

---

## Requirements

- Debian or Ubuntu (latest releases) or a close derivative (Pop!\_OS, Mint, Zorin, elementary).
- `bash`, `sudo`, `curl`, `gpg`, and standard tools (`apt-get`, `apt-cache`, `dpkg-query`, `awk`, `sed`, `grep`) — checked at startup.
- An internet connection (the whole catalog is fetched online).

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
| 1 | Browse tool categories &amp; pick tools (`kali-tools-*`) |
| 2 | Install a full system collection (`kali-linux-*`, incl. "Others") |
| 3 | Add / configure the Kali repository (pinned) |
| 4 | Update all installed packages |
| 5 | Remove the Kali repository (keeps installed tools) |
| 6 | Show status |

### Selecting tools

Inside a category you'll see the live tool list. At the prompt you can:

- type numbers and ranges — e.g. `1 3 5-8` — to install just those tools,
- press `a` to install every tool in the category,
- press `m` to install the whole category metapackage (APT resolves it), or
- press `b` to go back.

---

## 🛡️ Safety design

The common way to get Kali tools on Ubuntu — dropping Kali's full repo into your sources — is dangerous: it lets Kali packages upgrade core system libraries and frequently **breaks the OS**. Ubunli avoids this:

1. **APT pinning.** Every package originating from Kali is pinned to `Pin-Priority: 50`, well below your system's default. Kali packages are **never** auto-selected and **never** replace an existing system package — they install **only** when you explicitly request them.
2. **Explicit targeting.** Installs use `-t kali-rolling`, so APT only reaches into Kali for the specific package you asked for.
3. **Clean removal.** Option 5 removes the repository, pin, and signing key in one step. Already-installed tools remain.

You can inspect exactly what gets written:

```
/etc/apt/sources.list.d/ubunli-kali.list       # the repo
/etc/apt/preferences.d/ubunli-kali.pref        # the pin
/usr/share/keyrings/kali-archive-keyring.gpg   # the signing key
```

> Even with pinning, some risk remains when mixing repositories on a system you rely on. For serious or repeated use, run Ubunli in a VM/container.

---

## Notes &amp; limitations

- The catalog only appears **after** the Kali repository is configured and the index is refreshed — Ubunli sets this up automatically the first time you browse.
- Some Kali tools are built only for certain architectures; anything not installable on your release/arch is reported at the end of an install and the run never aborts.
- Installing large collections such as `kali-linux-everything` pulls a very large number of packages and Kali-specific dependencies onto a Debian/Ubuntu system. Use a dry-run first (Ubunli offers one) and prefer a VM.

---

## Troubleshooting

- **No categories/tools appear.** The Kali index isn't loaded yet — choose option 3 to add the repository, or let Ubunli set it up when you open a category, then retry.
- **`E: The repository ... is not signed`.** Re-run option 3 to reinstall the signing key.
- **A tool is reported "unavailable."** It isn't built for your distro/architecture. Try a different tool, or install from the project's upstream source.
- **Something feels broken after installing.** Run option 5 to remove the Kali repo, then `sudo apt update`. Pinning prevents system packages from being replaced, so your base system should be intact.

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
