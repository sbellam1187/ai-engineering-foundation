# Sabre Response Parsing Guide

## PNR Extraction

### Format Rules

A PNR is exactly **6 uppercase letters (A–Z only)**. No digits, no special characters.

- ✅ Valid: `TQCLUG`, `ABCDEF`, `PJIDTN`
- ❌ Invalid: `HDQ8UP` (has digit), `ABC123` (has digit), `ABCD` (too short)

### Where to Find the PNR

The PNR appears at the **end** of the response after the `ER` command:

```
RECEIVED FROM - S
HDQ.HDQ8UPH 1402/13NOV25 PJIDTN
                         ^^^^^^
                         This is the PNR
```

Pattern: `[OFFICE].[IDENTIFIER] [TIME]/[DATE] [PNR]`
The **last word** on the `HDQ.` line is the PNR.

### Extraction Algorithm

1. Find the line containing `HDQ.XXXXXXX` (office code pattern)
2. Take the **last word** on that line
3. Verify: exactly 6 characters, all A–Z
4. That is the PNR

### Common Mistakes

| Wrong Extract | Why Wrong | Correct Action |
|---------------|-----------|----------------|
| `HDQ8UPH` | Contains digit '8' | Take the last word, not the middle token |
| `HDQ` | Only 3 letters | Too short — read to the end of the line |
| `900-H` | Phone number from command | Not from the HDQ line |

---

## Parsing PNR Display

### Passenger Name

```
 1.1SMITH/JOHN
```

Regex: `\d+\.\d+([A-Z]+)/([A-Z]+)` → Group 1 = LAST_NAME, Group 2 = FIRST_NAME

### Flight Segment

```
 1   1639Y 15DEC M DFWLAX HK1  0615  0734
```

Regex: `\s+(\d+)\s+(\d{3,4})([A-Z])\s+(\d{1,2}[A-Z]{3})\s+[A-Z]\s+([A-Z]{3})([A-Z]{3})`

| Group | Field | Example |
|-------|-------|---------|
| 1 | Segment # | `1` |
| 2 | FLIGHT_NUMBER | `1639` |
| 3 | BOOKING_CLASS | `Y` |
| 4 | DEP_DATE | `15DEC` |
| 5 | ORIGIN | `DFW` |
| 6 | DEST | `LAX` |

---

## Error Detection

**Error indicator:** Response line starting with `‡`

When `‡` is detected: **stop immediately**, do not execute remaining commands.

| Error | Meaning | Recovery |
|-------|---------|----------|
| `‡FINISH OR IGNORE PNR` | Uncommitted transaction exists | Run `IGD` (`ignore_and_discard` template) |
| `‡INVALID ENTRY` | Wrong command format or invalid params | Check template and parameters |
| `‡NO AVAIL` | No flight availability | Try a different date or route |
| `‡DUPLICATE NAME FIELD` | Passenger already exists in PNR | Check existing PNR before adding |
| `‡.FRMT.NOT ENT BGNG WITH` | Command syntax error | Verify command format against template |
