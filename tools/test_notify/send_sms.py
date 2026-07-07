"""Send a randomized shipping-notification test SMS via Naver Cloud SENS.

Usage:
    python send_sms.py
    python send_sms.py --courier lotte --status out_for_delivery

Requires a Naver Cloud Platform SENS project with a pre-registered
sender phone number - see README.md in this folder.
This is a paid API per message; NCP may grant trial credit on signup,
but there is no unconditional free tier.
"""

import argparse
import base64
import hashlib
import hmac
import json
import sys
import time
import urllib.error
import urllib.request

from env_loader import require_env
from send_email import build_shipment
from samples import sms_body

# Windows consoles often default to cp949, which can't encode some Unicode
# punctuation and breaks argparse --help / print() output. Force UTF-8.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass

API_HOST = "https://sens.apigw.ntruss.com"


def _signature(method: str, uri: str, timestamp: str, access_key: str, secret_key: str) -> str:
    message = f"{method} {uri}\n{timestamp}\n{access_key}".encode("utf-8")
    digest = hmac.new(secret_key.encode("utf-8"), message, hashlib.sha256).digest()
    return base64.b64encode(digest).decode("utf-8")


def send_sms(shipment: dict) -> None:
    env = require_env(
        "NCP_ACCESS_KEY",
        "NCP_SECRET_KEY",
        "NCP_SENS_SERVICE_ID",
        "NCP_SENS_SENDER_PHONE",
        "RECIPIENT_PHONE",
    )
    uri = f"/sms/v2/services/{env['NCP_SENS_SERVICE_ID']}/messages"
    timestamp = str(int(time.time() * 1000))
    signature = _signature(
        "POST", uri, timestamp, env["NCP_ACCESS_KEY"], env["NCP_SECRET_KEY"]
    )

    body_text = sms_body(shipment)
    payload = {
        "type": "LMS" if len(body_text.encode("euc-kr", errors="ignore")) > 90 else "SMS",
        "contentType": "COMM",
        "countryCode": "82",
        "from": env["NCP_SENS_SENDER_PHONE"],
        "content": body_text,
        "messages": [{"to": env["RECIPIENT_PHONE"]}],
    }

    request = urllib.request.Request(
        API_HOST + uri,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "x-ncp-apigw-timestamp": timestamp,
            "x-ncp-iam-access-key": env["NCP_ACCESS_KEY"],
            "x-ncp-apigw-signature-v2": signature,
        },
    )
    try:
        with urllib.request.urlopen(request) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"SENS request failed ({error.code}): {detail}") from error

    print(
        f"requestId={result.get('requestId')} status={result.get('statusCode')} "
        f"-> {env['RECIPIENT_PHONE']} | {shipment['courier_name']} "
        f"{shipment['tracking']} | {shipment['status_phrase']}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--courier", help="cj|hanjin|lotte|epost|logen")
    parser.add_argument(
        "--status", help="registered|picked_up|in_transit|out_for_delivery|delivered"
    )
    args = parser.parse_args()

    shipment = build_shipment(args.courier, args.status)
    send_sms(shipment)


if __name__ == "__main__":
    main()
