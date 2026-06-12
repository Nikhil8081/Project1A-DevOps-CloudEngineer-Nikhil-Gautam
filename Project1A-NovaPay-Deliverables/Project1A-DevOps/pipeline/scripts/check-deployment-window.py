#!/usr/bin/env python3
"""
NovaPay Deployment Window Checker
Blocks deployments during defined blackout periods.
Used in Stage 8 of the CI/CD pipeline (and MUST be called from hotfix path too).
"""
import sys
from datetime import datetime
import pytz

IST = pytz.timezone("Asia/Kolkata")

def is_blackout(now: datetime) -> tuple[bool, str]:
    day = now.day
    hour = now.hour
    weekday = now.weekday()  # Monday=0

    # Salary days: 1st, 7th, 15th — 08:00 to 14:00 IST
    if day in (1, 7, 15) and 8 <= hour < 14:
        return True, f"Salary day blackout (day {day}, {hour}:00 IST)"

    # Month-end processing: 28th-31st, 18:00-23:59 IST
    if day >= 28 and 18 <= hour <= 23:
        return True, f"Month-end processing blackout (day {day}, {hour}:00 IST)"

    # Daily peak hours: 10:00-12:00 and 17:00-20:00 IST
    if 10 <= hour < 12 or 17 <= hour < 20:
        return True, f"Daily peak hour blackout ({hour}:00 IST)"

    # TODO: integrate festival calendar (Diwali, Eid, Christmas, Holi) via external API
    # TODO: integrate RBI settlement window feed

    return False, "OK"

def main():
    now = datetime.now(IST)
    blocked, reason = is_blackout(now)

    print(f"Current time (IST): {now.strftime('%Y-%m-%d %H:%M:%S')}")

    if blocked:
        print(f"BLOCKED: {reason}")
        print("Deployment cannot proceed. Reschedule outside blackout window,")
        print("or obtain CAB pre-approval for emergency hotfix override.")
        sys.exit(1)
    else:
        print(f"OK — not in blackout period")
        sys.exit(0)

if __name__ == "__main__":
    main()
