---
name: sabre-test-data
description: Generate and manage airline test data in Sabre Global Distribution System (GDS). Use when needing to create PNRs (passenger name records), issue tickets, check in passengers, manage upgrades, search flight availability, or handle re-accommodations. Supports full lifecycle from booking creation through ticketing, check-in, and special services (SSR, FQTU).
---

# Sabre Test Data Generation Skill

## When to Use

Activate when the user request involves:
- Creating flight bookings (PNRs) — one-way, roundtrip, or corporate
- Issuing tickets for existing reservations
- Checking in passengers
- Managing upgrades and priority lists (PALL)
- Searching flight availability
- Re-accommodating passengers (voluntary/involuntary)
- Managing Special Service Requests (SSR, FQTU, FQTZ)
- Looking up tickets by AAdvantage number

---

## Execution Model

Commands run via `scripts/sabre-execute.sh`. No MCP server needed.

```bash
sabre-execute.sh "CMD1" "CMD2" ...   # all commands as quoted args
```

---

## Workflow

1. **Identify** the operation from the user request
2. **Load** the template from `references/command-templates.yaml` (single source of truth)
3. **Substitute** `{PARAM_NAME}` placeholders with actual values; use `references/default-passenger-data.yaml` for missing passenger info
4. **Execute** ALL commands via `sabre-execute.sh` — never skip any
5. **Parse** the response using `references/parsing-guide.md`
6. **Respond** to the user using `references/response-templates.md`

---

## Critical Rules

| Rule | Detail |
|------|--------|
| Templates only | Never construct commands from memory — use `command-templates.yaml` exclusively |
| Execute all | Run every command in the template; never skip steps |
| Stop on ‡ | If response starts with `‡`, stop immediately and report — do not retry blindly |
| PNR format | 6 uppercase letters A–Z only, NO digits (`TQCLUG` ✅ · `HDQ8UP` ❌) |
| Date format | Always `DDMMM` (`15DEC`, `30JAN`) — never include the year |
| Airport codes | Always 3-letter IATA uppercase (`DFW`, `LAX`) |
| No template found | Tell the user — do not improvise commands |

---

## Quick Reference

| Operation | Template Key |
|-----------|-------------|
| One-way booking | `create_pnr` |
| Roundtrip booking | `create_roundtrip_pnr` |
| Corporate booking | `create_corporate_pnr` |
| Retrieve PNR | `retrieve_pnr` |
| Cancel PNR | `cancel_pnr` |
| Issue ticket | `ticket_pnr` |
| Flight search | `display_flight_availability` |
| Flight search (via connection) | `display_flight_availability_via_connection` |
| Check-in | `checkin_passenger` |
| Display PALL | `display_pall` |
| Display PALL history | `display_pall_history` |
| Add upgrade | `add_complementary_upgrade` |
| Lookup ticket by FF# | `lookup_ticket_aadvantage` |
| Display SSR | `display_ssr` |
| Display frequent flyer | `display_frequent_flyer` |
| Add FQTU | `add_fqtu` |
| Add FQTZ SSR | `add_fqtz_ssr` |
| Delete SSR (single) | `delete_ssr_single` |
| Delete SSR (range) | `delete_ssr_range` |
| Error recovery | `ignore_and_discard` |

> Full command sequences, parameters, and defaults are in `references/command-templates.yaml`.

---

## Reference Files

| File | Purpose — Load When |
|------|---------------------|
| `references/command-templates.yaml` | All command sequences — **load for every operation** |
| `references/default-passenger-data.yaml` | Test passenger defaults — load when passenger info is missing |
| `references/parsing-guide.md` | PNR extraction and response parsing — load when parsing Sabre output |
| `references/response-templates.md` | User-facing message templates — load when composing responses |
| `references/setup-guide.md` | Install, credentials, troubleshooting — load only if user asks about setup |
| `scripts/sabre-execute.sh` | Executes commands via direct Sabre API call |
