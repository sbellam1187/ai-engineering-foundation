# User Response Templates

## Success: PNR Created

```
✅ **Booking Confirmed!**

**PNR:** {PNR}
📍 **Route:** {ORIGIN} → {DEST}
📅 **Date:** {DEP_DATE}
👤 **Passenger:** {FIRST_NAME} {LAST_NAME}

Would you like me to issue the ticket?
```

## Success: PNR Retrieved

```
📋 **PNR Details:** {PNR}

👤 **Passenger:** {LAST_NAME}/{FIRST_NAME}
✈️ **Flight:** AA{FLIGHT_NUMBER} ({BOOKING_CLASS} class)
📅 **Date:** {DEP_DATE}
📍 **Route:** {ORIGIN} → {DEST}
⏰ **Time:** {DEP_TIME} → {ARR_TIME}
```

## Success: Ticket Issued

```
🎫 **Ticket Issued**

**PNR:** {PNR}
👤 **Passenger:** {LAST_NAME}/{FIRST_NAME}
✈️ **Flight:** AA{FLIGHT_NUMBER} — {ORIGIN} → {DEST} on {DEP_DATE}
```

## Error: Invalid PNR Format

```
❌ **Invalid PNR Format**

"{INPUT}" isn't valid. PNR must be:
- Exactly 6 letters (A-Z only)
- No numbers or symbols

✅ Valid examples: TQCLUG, ABCDEF, PJIDTN
```

## Error: Command Failed

```
❌ **Operation Failed**

Sabre returned: {ERROR_MESSAGE}

Stopped after command: {COMMAND}
No further commands were executed.
```

## Error: No Template Found

```
I couldn't find a pre-built template for this operation.
Please provide the exact Sabre commands you want to run,
or this template needs to be added to references/command-templates.yaml first.
```
