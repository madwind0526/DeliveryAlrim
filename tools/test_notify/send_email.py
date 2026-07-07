"""Send a randomized shipping-notification test email via Gmail SMTP.

Usage:
    python send_email.py --to gmail
    python send_email.py --to naver --count 3
    python send_email.py --to gmail --courier hanjin --status delivered

Sends through the sender Gmail account's SMTP relay (works for any
recipient domain, including Naver), using an app password - not the
account's normal login password.
"""

import argparse
import smtplib
import sys
import time
from email.message import EmailMessage

from env_loader import require_env
from samples import COURIERS, STATUS_PHRASES, email_body, email_subject, random_shipment

# Windows consoles often default to cp949, which can't encode some Unicode
# punctuation and breaks argparse --help / print() output. Force UTF-8.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587


def build_shipment(courier_code: str | None, status_code: str | None) -> dict:
    shipment = random_shipment()
    if courier_code:
        match = next((c for c in COURIERS if c[1] == courier_code), None)
        if match is None:
            raise SystemExit(
                f"Unknown --courier '{courier_code}'. "
                f"Choices: {', '.join(c[1] for c in COURIERS)}"
            )
        name, code, min_len, max_len = match
        shipment["courier_name"] = name
        shipment["courier_code"] = code
    if status_code:
        if status_code not in STATUS_PHRASES:
            raise SystemExit(
                f"Unknown --status '{status_code}'. "
                f"Choices: {', '.join(STATUS_PHRASES)}"
            )
        shipment["status_code"] = status_code
        shipment["status_phrase"] = STATUS_PHRASES[status_code]
    return shipment


def send_one(smtp: smtplib.SMTP, sender: str, recipient: str, shipment: dict) -> None:
    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = recipient
    msg["Subject"] = email_subject(shipment)
    msg.set_content(email_body(shipment))
    smtp.send_message(msg)
    print(
        f"sent -> {recipient} | {shipment['courier_name']} "
        f"{shipment['tracking']} | {shipment['status_phrase']}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--to", choices=["gmail", "naver"], required=True)
    parser.add_argument("--count", type=int, default=1)
    parser.add_argument("--courier", help="cj|hanjin|lotte|epost|logen")
    parser.add_argument("--status", help="registered|picked_up|in_transit|out_for_delivery|delivered")
    parser.add_argument("--interval", type=float, default=2.0, help="seconds between sends")
    args = parser.parse_args()

    env = require_env("SENDER_GMAIL_ADDRESS", "SENDER_GMAIL_APP_PASSWORD")
    recipient_env = "RECIPIENT_GMAIL" if args.to == "gmail" else "RECIPIENT_NAVER"
    recipient = require_env(recipient_env)[recipient_env]

    sender = env["SENDER_GMAIL_ADDRESS"]
    # Google displays app passwords as "xxxx xxxx xxxx xxxx"; strip any
    # spaces in case they were copied verbatim.
    app_password = env["SENDER_GMAIL_APP_PASSWORD"].replace(" ", "")

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as smtp:
        smtp.starttls()
        try:
            smtp.login(sender, app_password)
        except smtplib.SMTPAuthenticationError as error:
            raise SystemExit(
                f"Gmail login rejected for {sender} ({error.smtp_code} "
                f"{error.smtp_error.decode(errors='replace')}).\n"
                "Check: (1) that account's inbox for a Google "
                "'sign-in blocked' email and confirm it, (2) 2-Step "
                "Verification is ON for that exact account, (3) the app "
                "password wasn't revoked/mistyped - generate a fresh one "
                "at https://myaccount.google.com/apppasswords."
            ) from error
        for i in range(args.count):
            shipment = build_shipment(args.courier, args.status)
            send_one(smtp, sender, recipient, shipment)
            if i < args.count - 1:
                time.sleep(args.interval)


if __name__ == "__main__":
    main()
