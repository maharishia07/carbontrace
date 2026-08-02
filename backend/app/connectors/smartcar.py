"""Connected-car connector (Smartcar-compatible).

Real mode: set SMARTCAR_CLIENT_ID / SMARTCAR_CLIENT_SECRET / SMARTCAR_REDIRECT_URI
and the OAuth flow + vehicle endpoints below work against api.smartcar.com
(works with Smartcar's simulated vehicles on a free dev account, and with
real cars in supported markets).

Mock mode (default, no credentials): mock_sync() simulates a telematics
pull — odometer + fuel-consumed since the last sync — so the connected-car
data path can be demoed end to end without any external account. The data
lands as `source="connected"` fill-ups, i.e. measured fuel, exactly as a
real API pull would.

Honest scope note: connected-car APIs report odometer and fuel, not
tailpipe gas. CO2 comes from fuel via fixed combustion chemistry.
"""
import os
import urllib.parse
import urllib.request
import json
import random
from datetime import datetime, timezone

AUTH_URL = "https://connect.smartcar.com/oauth/authorize"
TOKEN_URL = "https://auth.smartcar.com/oauth/token"
API_BASE = "https://api.smartcar.com/v2.0"
SCOPES = ["read_odometer", "read_fuel", "read_vehicle_info"]


def configured() -> bool:
    return bool(os.environ.get("SMARTCAR_CLIENT_ID") and os.environ.get("SMARTCAR_CLIENT_SECRET"))


def auth_url(state: str) -> str:
    q = urllib.parse.urlencode({
        "response_type": "code",
        "client_id": os.environ["SMARTCAR_CLIENT_ID"],
        "redirect_uri": os.environ.get("SMARTCAR_REDIRECT_URI", ""),
        "scope": " ".join(SCOPES),
        "state": state,
        "mode": os.environ.get("SMARTCAR_MODE", "simulated"),
    })
    return f"{AUTH_URL}?{q}"


def _post(url: str, data: dict, headers: dict) -> dict:
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers=headers)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


def _get(url: str, token: str) -> dict:
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


def exchange_code(code: str) -> dict:
    import base64
    creds = base64.b64encode(
        f"{os.environ['SMARTCAR_CLIENT_ID']}:{os.environ['SMARTCAR_CLIENT_SECRET']}".encode()
    ).decode()
    return _post(TOKEN_URL, {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": os.environ.get("SMARTCAR_REDIRECT_URI", ""),
    }, {"Authorization": f"Basic {creds}"})


def read_odometer_km(token: str, smartcar_vehicle_id: str) -> float:
    data = _get(f"{API_BASE}/vehicles/{smartcar_vehicle_id}/odometer", token)
    return float(data["distance"])  # km


def read_fuel(token: str, smartcar_vehicle_id: str) -> dict:
    """Returns {'percentRemaining': .., 'amountRemaining': litres, 'range': km}."""
    return _get(f"{API_BASE}/vehicles/{smartcar_vehicle_id}/fuel", token)


# --- mock mode ---------------------------------------------------------------

def mock_sync(last_odometer_km: float, days: float = 7.0, seed: int | None = None,
              l_per_100km: float = 6.2) -> dict:
    """Simulate a weekly telematics pull for demos.

    Returns odometer + litres consumed as a real connected-car sync would.
    """
    rng = random.Random(seed)
    km = max(20.0, days * rng.uniform(18.0, 45.0))
    litres = km * l_per_100km / 100.0 * rng.uniform(0.95, 1.05)
    return {
        "odometer_km": round(last_odometer_km + km, 1),
        "litres_consumed": round(litres, 2),
        "synced_at": datetime.now(timezone.utc).isoformat(),
        "source": "connected-mock",
    }
