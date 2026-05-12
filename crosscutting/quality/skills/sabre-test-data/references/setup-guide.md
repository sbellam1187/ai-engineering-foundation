# Sabre Test Data — Setup & Troubleshooting

## Prerequisites

| Tool | Verify | Install |
|------|--------|---------|
| `curl` | `curl --version` | Pre-installed on macOS; `sudo apt install curl` on Linux |
| `jq` | `jq --version` | `brew install jq` (macOS) or `sudo apt install jq` (Linux) |
| `bash 4+` | `bash --version` | macOS ships 3.x — upgrade: `brew install bash` |

---

## Install the Skill

```bash
# Clone and copy to Copilot skills directory
git clone https://github.com/AAInternal/aa-ct-agent-skills.git /tmp/aa-ct-agent-skills
mkdir -p ~/.copilot/skills
cp -r /tmp/aa-ct-agent-skills/skills/sabre-test-data ~/.copilot/skills/
rm -rf /tmp/aa-ct-agent-skills

# Make script executable
chmod +x ~/.copilot/skills/sabre-test-data/scripts/sabre-execute.sh
```

**Expected structure:**

```
~/.copilot/skills/sabre-test-data/
├── SKILL.md
├── references/
│   ├── command-templates.yaml
│   ├── default-passenger-data.yaml
│   ├── parsing-guide.md
│   ├── response-templates.md
│   └── setup-guide.md
└── scripts/
    └── sabre-execute.sh
```

---

## Configure Credentials

Add to `~/.zshrc` (macOS) or `~/.bashrc` (Linux):

```bash
export SABRE_USER_ID=your_user_id
export SABRE_PASSCODE=your_passcode
export SABRE_ENVIRONMENT=CERT   # CERT = test, PROD = production
export SABRE_SUFFIX=AAO
export SABRE_DUTY_CODE=5
```

Apply immediately: `source ~/.zshrc`

### Environment Variable Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SABRE_USER_ID` | ✅ Yes | — | Sabre agent user ID |
| `SABRE_PASSCODE` | ✅ Yes | — | Sabre agent passcode |
| `SABRE_ENVIRONMENT` | No | `CERT` | `CERT` (test) or `PROD` (production) |
| `SABRE_SUFFIX` | No | `AAO` | Agency suffix |
| `SABRE_DUTY_CODE` | No | `5` | Duty code for ticketing |

---

## Test Connectivity

```bash
~/.copilot/skills/sabre-test-data/scripts/sabre-execute.sh "115MARDFWLAX'AA"
```

Expected: flight availability display with times and flight numbers.
If auth error (`‡`): double-check `SABRE_USER_ID` and `SABRE_PASSCODE`.
If `curl` error: confirm you are on the AA internal network or VPN.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `SABRE_USER_ID env var is not set` | Missing env var | Add `export SABRE_USER_ID=...` to `~/.zshrc` then `source ~/.zshrc` |
| `jq is required but not installed` | Missing dependency | `brew install jq` |
| `‡INVALID ENTRY` | Wrong credentials or command format | Verify user ID/passcode; check command against template |
| `curl` timeout / connection refused | Not on AA network | Connect to VPN |
| Skill not activating in Copilot | Wrong install path | Ensure path is exactly `~/.copilot/skills/sabre-test-data/` |
| `Permission denied` on script | Not executable | `chmod +x ~/.copilot/skills/sabre-test-data/scripts/sabre-execute.sh` |

---

## Restart VS Code

After installing, restart VS Code so Copilot picks up the skill:

```bash
code .
```

Then open Copilot Chat (`Cmd+Shift+I` on Mac) and test: _"Create a test PNR from DFW to LAX"_
