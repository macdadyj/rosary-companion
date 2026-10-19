#!/usr/bin/env python3
"""Install App Store profiles for the shared iOS Distribution certificate.

Uses the App Store Connect REST API (ES256 JWT, audience appstoreconnect-v1).
Does not print private keys, API tokens, or certificate passwords. Never
creates or revokes a certificate. Profiles are fetched when they are already
tied to the shared certificate, and created only when they are not.
"""

import base64
import io
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API_ROOT = "https://api.appstoreconnect.apple.com"
PROFILE_TYPE = "IOS_APP_STORE"
CERTIFICATE_TYPE = "IOS_DISTRIBUTION"
SHARED_CERTIFICATE_ID = "VJ5MXTN7UT"
TARGETS = (
    ("com.lojo.Rosary", "Rosary App Store"),
    ("com.lojo.Rosary.widget", "RosaryWidget App Store"),
    ("com.lojo.Rosary.watchkitapp", "RosaryWatch App Store"),
)
SIGNING_KEYS = (
    "CODE_SIGN_STYLE",
    "CODE_SIGN_IDENTITY",
    "DEVELOPMENT_TEAM",
    "PROVISIONING_PROFILE_SPECIFIER",
    "OTHER_CODE_SIGN_FLAGS",
)


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def b64url_decode(text):
    pad = "=" * ((-len(text)) % 4)
    return base64.urlsafe_b64decode(text + pad)


def der_to_raw(der):
    """Turn an OpenSSL ECDSA DER signature into the 64-byte JWT form."""
    if len(der) < 8 or der[0] != 0x30:
        raise ValueError("not a DER signature")
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    numbers = []
    for _ in range(2):
        if index >= len(der) or der[index] != 0x02:
            raise ValueError("expected an integer in the signature")
        index += 1
        length = der[index]
        index += 1
        if length & 0x80:
            count = length & 0x7F
            length = int.from_bytes(der[index:index + count], "big")
            index += count
        value = der[index:index + length]
        index += length
        value = value.lstrip(b"\x00")
        if len(value) > 32:
            raise ValueError("signature integer is too wide")
        numbers.append(value.rjust(32, b"\x00"))
    return numbers[0] + numbers[1]


def raw_to_der(raw):
    if len(raw) != 64:
        raise ValueError("expected a 64-byte signature")

    def encode(part):
        value = part.lstrip(b"\x00") or b"\x00"
        if value[0] & 0x80:
            value = b"\x00" + value
        return b"\x02" + bytes([len(value)]) + value

    body = encode(raw[:32]) + encode(raw[32:])
    return b"\x30" + bytes([len(body)]) + body


def sign_es256(pem, message):
    with tempfile.NamedTemporaryFile() as key_file:
        key_file.write(pem if pem.endswith(b"\n") else pem + b"\n")
        key_file.flush()
        signed = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_file.name],
            input=message,
            capture_output=True,
            check=False,
        )
    if signed.returncode != 0 or not signed.stdout:
        raise SystemExit("Could not sign the App Store Connect request.")
    return der_to_raw(signed.stdout)


def make_jwt(pem, key_id, issuer, now):
    header = b64url(json.dumps(
        {"alg": "ES256", "kid": key_id, "typ": "JWT"},
        separators=(",", ":"),
    ).encode())
    payload = b64url(json.dumps(
        {
            "iss": issuer,
            "iat": now,
            "exp": now + (19 * 60),
            "aud": "appstoreconnect-v1",
        },
        separators=(",", ":"),
    ).encode())
    signing_input = f"{header}.{payload}".encode()
    signature = b64url(sign_es256(pem, signing_input))
    return f"{header}.{payload}.{signature}"


def certificate_limit(body):
    lowered = body.lower()
    phrases = (
        "maximum number",
        "already have",
        "too many",
        "certificate limit",
        "exceeded the maximum",
        "reached the maximum",
    )
    return any(phrase in lowered for phrase in phrases)


def stop_api(status, body, context):
    text = body.strip() or f"HTTP {status}"
    sys.stderr.write(text)
    if not text.endswith("\n"):
        sys.stderr.write("\n")
    forbidden = status == 403 or "FORBIDDEN" in body
    if forbidden and context == "certificate":
        sys.stderr.write(
            "Certificate creation was forbidden. Stopped without retrying. "
            "Nothing was revoked. An Admin App Store Connect API key may be required.\n"
        )
    elif forbidden:
        sys.stderr.write(
            f"{context} was forbidden. Stopped without retrying. Nothing was revoked.\n"
        )
    elif context == "certificate" and certificate_limit(body):
        sys.stderr.write(
            "The account is at the iOS Distribution certificate limit. "
            "Stopped. Nothing was revoked.\n"
        )
    else:
        sys.stderr.write(
            f"{context} failed with HTTP {status}. Stopped. Nothing was revoked.\n"
        )
    raise SystemExit(1)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def api(token, method, path, payload=None):
    route = path.split("?", 1)[0]
    if method != "GET" and (route == "/v1/certificates" or route.startswith("/v1/certificates/")):
        raise SystemExit("Refusing to create, change, or revoke an App Store Connect certificate.")
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(API_ROOT + path, data=data, method=method)
    request.add_header("Authorization", "Bearer " + token)
    request.add_header("Accept", "application/json")
    if data is not None:
        request.add_header("Content-Type", "application/json")
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(request, timeout=60) as response:
            return response.status, response.read().decode()
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode()
    except urllib.error.URLError:
        raise SystemExit("Could not reach App Store Connect. Stopped. Nothing was revoked.")


def load_pem(path):
    return Path(path).read_bytes()


def jwt_from_env():
    pem = load_pem(os.environ["KEY_PATH"])
    return make_jwt(
        pem,
        os.environ["ASC_KEY_ID"],
        os.environ["ASC_ISSUER_ID"],
        int(time.time()),
    )


def parse_data(status, body, context):
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError:
        stop_api(status, body, context)
    if status not in (200, 201) or "data" not in parsed:
        stop_api(status, body, context)
    return parsed


def find_bundle_id(token, identifier):
    query = urllib.parse.urlencode(
        {"filter[identifier]": identifier, "limit": "5"}
    )
    status, body = api(token, "GET", "/v1/bundleIds?" + query)
    parsed = parse_data(status, body, "bundle ID lookup")
    for item in parsed["data"]:
        if item.get("attributes", {}).get("identifier") == identifier:
            return item["id"]
    sys.stderr.write(
        f"No App Store Connect bundle ID for {identifier}. "
        "Create that App ID first. Nothing was revoked.\n"
    )
    raise SystemExit(1)


def delete_profile(token, profile_id):
    status, body = api(token, "DELETE", "/v1/profiles/" + urllib.parse.quote(profile_id))
    if status in (204, 404):
        return
    stop_api(status, body, "profile delete")


def parse_apple_time(value):
    if not value or not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def certificate_public_key(data):
    command = ["openssl", "x509", "-pubkey", "-noout"]
    if b"BEGIN CERTIFICATE" not in data:
        command.extend(["-inform", "DER"])
    result = subprocess.run(command, input=data, capture_output=True, check=False)
    if result.returncode != 0 or b"BEGIN PUBLIC KEY" not in result.stdout:
        raise SystemExit("The distribution certificate could not be read.")
    return result.stdout.strip()


def public_keys_from_file(path):
    data = Path(path).read_bytes()
    if b"BEGIN CERTIFICATE" not in data:
        return [certificate_public_key(data)]
    keys = []
    for part in data.split(b"-----END CERTIFICATE-----"):
        if b"BEGIN CERTIFICATE" not in part:
            continue
        pem = part[part.index(b"-----BEGIN CERTIFICATE-----"):] + b"-----END CERTIFICATE-----\n"
        keys.append(certificate_public_key(pem))
    if not keys:
        raise SystemExit("The distribution certificate could not be read.")
    return keys


def assert_shared_certificate(token, local_keys):
    status, body = api(token, "GET", "/v1/certificates/" + SHARED_CERTIFICATE_ID)
    parsed = parse_data(status, body, "certificate lookup")
    attributes = parsed["data"].get("attributes") or {}
    if attributes.get("certificateType") != CERTIFICATE_TYPE:
        raise SystemExit(
            "The shared certificate is not an iOS Distribution certificate. "
            "No certificate was created."
        )
    content = attributes.get("certificateContent")
    if not content:
        raise SystemExit("The shared certificate could not be read. No certificate was created.")
    remote = certificate_public_key(base64.b64decode(content))
    if remote not in local_keys:
        raise SystemExit(
            "The installed distribution certificate does not match the shared certificate. "
            "No certificate was created."
        )
    expiration = parse_apple_time(attributes.get("expirationDate"))
    if expiration is not None and expiration <= datetime.now(timezone.utc):
        raise SystemExit("The shared distribution certificate is expired. No certificate was created.")
    print("Installed distribution certificate matches the shared certificate.", flush=True)


def bundle_identifier(profile, included):
    relation = ((profile.get("relationships") or {}).get("bundleId") or {}).get("data") or {}
    item = included.get((relation.get("type") or "bundleIds", relation.get("id")))
    if not item:
        return None
    return (item.get("attributes") or {}).get("identifier")


def profile_certificate_ids(profile):
    relation = ((profile.get("relationships") or {}).get("certificates") or {}).get("data") or []
    return [item.get("id") for item in relation if item.get("id")]


def matching_profile(profiles, included, bundle_id, certificate_id, now):
    chosen = None
    chosen_key = None
    for profile in profiles:
        attributes = profile.get("attributes") or {}
        if attributes.get("profileType") != PROFILE_TYPE:
            continue
        if attributes.get("profileState") not in (None, "ACTIVE"):
            continue
        if bundle_identifier(profile, included) != bundle_id:
            continue
        if certificate_id not in profile_certificate_ids(profile):
            continue
        expiration = parse_apple_time(attributes.get("expirationDate"))
        if expiration is not None and expiration <= now:
            continue
        key = expiration.timestamp() if expiration is not None else float("inf")
        if chosen is None or key > chosen_key:
            chosen = profile
            chosen_key = key
    return chosen


def list_app_store_profiles(token):
    profiles = []
    included = {}
    query = urllib.parse.urlencode({
        "filter[profileType]": PROFILE_TYPE,
        "include": "bundleId,certificates",
        "limit": "200",
    })
    path = "/v1/profiles?" + query
    while path:
        status, body = api(token, "GET", path)
        parsed = parse_data(status, body, "profile lookup")
        for item in parsed.get("included", []):
            included[(item.get("type"), item.get("id"))] = item
        profiles.extend(parsed.get("data") or [])
        next_link = ((parsed.get("links") or {}).get("next")) or ""
        if next_link.startswith(API_ROOT):
            path = next_link[len(API_ROOT):]
        else:
            path = None
    return profiles, included


def profiles_named(token, name):
    query = urllib.parse.urlencode({
        "filter[name]": name,
        "filter[profileType]": PROFILE_TYPE,
        "include": "bundleId,certificates",
        "limit": "20",
    })
    status, body = api(token, "GET", "/v1/profiles?" + query)
    parsed = parse_data(status, body, "profile lookup")
    included = {}
    for item in parsed.get("included", []):
        included[(item.get("type"), item.get("id"))] = item
    return parsed.get("data") or [], included


def clear_stale_named_profiles(token, name, bundle_id, now):
    """Drop same-named profiles that are not tied to the shared certificate.

    A profile that is already tied to it is returned so the caller can reuse it.
    """
    items, included = profiles_named(token, name)
    reusable = matching_profile(items, included, bundle_id, SHARED_CERTIFICATE_ID, now)
    for item in items:
        if reusable is not None and item.get("id") == reusable.get("id"):
            continue
        attributes = item.get("attributes") or {}
        if attributes.get("name") != name or attributes.get("profileType") != PROFILE_TYPE:
            continue
        if bundle_identifier(item, included) != bundle_id:
            continue
        if SHARED_CERTIFICATE_ID in profile_certificate_ids(item):
            continue
        delete_profile(token, item["id"])
    return reusable


def profile_content(token, profile):
    content = (profile.get("attributes") or {}).get("profileContent")
    if not content:
        status, body = api(token, "GET", "/v1/profiles/" + urllib.parse.quote(profile["id"]))
        parsed = parse_data(status, body, "profile")
        content = (parsed["data"].get("attributes") or {}).get("profileContent")
        if not content:
            stop_api(status, body, "profile")
    return base64.b64decode(content)


def embedded_profile_name(raw):
    if shutil.which("security") is None:
        return None
    decoded = subprocess.run(
        ["security", "cms", "-D"],
        input=raw,
        capture_output=True,
        check=False,
    )
    if decoded.returncode != 0 or not decoded.stdout:
        return None
    try:
        payload = plistlib.loads(decoded.stdout)
    except Exception:
        return None
    name = payload.get("Name")
    if isinstance(name, str) and name:
        return name
    return None


def safe_setting(value, label):
    if not isinstance(value, str) or not value or any(char in value for char in '"\n\r\\'):
        raise SystemExit(f"The {label} cannot be used for signing.")
    return value


def duplicate_profile_name(status, body):
    if status == 409:
        return True
    lowered = body.lower()
    return status == 422 and ("already exists" in lowered or "duplicate" in lowered)


def create_profile(token, name, bundle_resource_id, certificate_id):
    status, body = api(
        token,
        "POST",
        "/v1/profiles",
        {
            "data": {
                "type": "profiles",
                "attributes": {
                    "name": name,
                    "profileType": PROFILE_TYPE,
                },
                "relationships": {
                    "bundleId": {
                        "data": {"type": "bundleIds", "id": bundle_resource_id}
                    },
                    "certificates": {
                        "data": [{"type": "certificates", "id": certificate_id}]
                    },
                },
            }
        },
    )
    if duplicate_profile_name(status, body):
        return None
    parsed = parse_data(status, body, "profile")
    content = parsed["data"].get("attributes", {}).get("profileContent")
    if not content:
        stop_api(status, body, "profile")
    return parsed["data"]["id"], base64.b64decode(content)


def install_profile(raw, profile_id, directory):
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{profile_id}.mobileprovision"
    path.write_bytes(raw)
    os.chmod(path, 0o644)
    return path


def bundle_in_block(text, bundle_id):
    return (
        f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};" in text
        or f'PRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";' in text
    )


def patch_pbxproj(text, team, keychain, profiles, identity="Apple Distribution"):
    lines = text.splitlines(keepends=True)
    output = []
    index = 0
    while index < len(lines):
        if "buildSettings = {" not in lines[index]:
            output.append(lines[index])
            index += 1
            continue
        block = [lines[index]]
        index += 1
        depth = lines[index - 1].count("{") - lines[index - 1].count("}")
        while index < len(lines) and depth > 0:
            block.append(lines[index])
            depth += lines[index].count("{") - lines[index].count("}")
            index += 1
        joined = "".join(block)
        matched = None
        for bundle_id, profile_name in profiles:
            if bundle_in_block(joined, bundle_id):
                matched = profile_name
                break
        if matched is None:
            output.extend(block)
            continue
        output.extend(rewrite_settings(block, team, keychain, matched, identity))
    return "".join(output)


def rewrite_settings(block, team, keychain, profile_name, identity="Apple Distribution"):
    indent = "\t\t\t\t"
    for line in block:
        stripped = line.lstrip()
        if stripped.startswith("PRODUCT_BUNDLE_IDENTIFIER"):
            indent = line[:len(line) - len(stripped)]
            break
    kept = []
    for line in block[:-1]:
        stripped = line.strip()
        if any(stripped.startswith(key + " ") or stripped.startswith(key + "=") for key in SIGNING_KEYS):
            continue
        kept.append(line)
    flag = f"--keychain {keychain}"
    settings = [
        f"{indent}CODE_SIGN_STYLE = Manual;\n",
        f'{indent}CODE_SIGN_IDENTITY = "{identity}";\n',
        f"{indent}DEVELOPMENT_TEAM = {team};\n",
        f'{indent}PROVISIONING_PROFILE_SPECIFIER = "{profile_name}";\n',
        f'{indent}OTHER_CODE_SIGN_FLAGS = "{flag}";\n',
    ]
    kept.extend(settings)
    kept.append(block[-1])
    return kept


def write_export_options(path, team, profiles, identity="Apple Distribution"):
    payload = {
        "method": "app-store-connect",
        "signingStyle": "manual",
        "signingCertificate": identity,
        "teamID": team,
        "destination": "upload",
        "uploadSymbols": True,
        "manageAppVersionAndBuildNumber": False,
        "provisioningProfiles": {bundle_id: name for bundle_id, name in profiles},
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        plistlib.dump(payload, handle)


def write_manifest(path, profiles):
    Path(path).write_text(json.dumps({"profiles": profiles}))
    os.chmod(path, 0o600)


def install_resolved_profile(token, profile, preferred_name, bundle_id, profiles_dir):
    raw = profile_content(token, profile)
    name = embedded_profile_name(raw) or (profile.get("attributes") or {}).get("name") or preferred_name
    safe_setting(name, "profile name")
    path = install_profile(raw, profile["id"], profiles_dir)
    return name, {
        "id": profile["id"],
        "name": name,
        "bundleId": bundle_id,
        "path": str(path),
    }


def prepare(argv):
    manifest_path = Path(argv["manifest"])
    profiles_dir = Path(argv["profiles_dir"]).expanduser()
    identity = safe_setting(Path(argv["identity_file"]).read_text().strip(), "distribution identity")
    local_keys = public_keys_from_file(argv["certificate"])
    token = jwt_from_env()
    assert_shared_certificate(token, local_keys)
    profiles, included = list_app_store_profiles(token)
    now = datetime.now(timezone.utc)
    installed = []
    resolved = []
    try:
        for bundle_id, preferred_name in TARGETS:
            chosen = matching_profile(profiles, included, bundle_id, SHARED_CERTIFICATE_ID, now)
            if chosen is None:
                chosen = clear_stale_named_profiles(token, preferred_name, bundle_id, now)
            if chosen is None:
                print(f"Creating an App Store profile for {bundle_id}.", flush=True)
                resource_id = find_bundle_id(token, bundle_id)
                created = create_profile(token, preferred_name, resource_id, SHARED_CERTIFICATE_ID)
                if created is None:
                    chosen = clear_stale_named_profiles(token, preferred_name, bundle_id, now)
                    if chosen is None:
                        created = create_profile(token, preferred_name, resource_id, SHARED_CERTIFICATE_ID)
                if created is not None:
                    profile_id, raw = created
                    name = embedded_profile_name(raw) or preferred_name
                    safe_setting(name, "profile name")
                    path = install_profile(raw, profile_id, profiles_dir)
                    record = {
                        "id": profile_id,
                        "name": name,
                        "bundleId": bundle_id,
                        "path": str(path),
                    }
                elif chosen is not None:
                    print(f"Using the App Store profile for {bundle_id}.", flush=True)
                    name, record = install_resolved_profile(
                        token, chosen, preferred_name, bundle_id, profiles_dir
                    )
                else:
                    raise SystemExit(
                        f"Could not install an App Store profile for {bundle_id}. "
                        "No certificate was created."
                    )
            else:
                print(f"Using the App Store profile for {bundle_id}.", flush=True)
                name, record = install_resolved_profile(
                    token, chosen, preferred_name, bundle_id, profiles_dir
                )
            installed.append(record)
            resolved.append((bundle_id, name))
            write_manifest(manifest_path, installed)
    except SystemExit:
        write_manifest(manifest_path, installed)
        raise
    project = Path(argv["pbxproj"])
    patched = patch_pbxproj(
        project.read_text(), argv["team"], argv["keychain"], resolved, identity
    )
    if patched.count("CODE_SIGN_STYLE = Manual;") < 3:
        raise SystemExit("Could not set manual signing on the app, widget, and watch.")
    if identity not in patched:
        raise SystemExit("Could not set the distribution signing identity.")
    for _bundle_id, profile_name in resolved:
        if f'PROVISIONING_PROFILE_SPECIFIER = "{profile_name}";' not in patched:
            raise SystemExit("Could not set an App Store profile for manual signing.")
    project.write_text(patched)
    write_export_options(Path(argv["export_plist"]), argv["team"], resolved, identity)
    write_manifest(manifest_path, installed)


def cleanup():
    """Remove local profile files. Does not delete remote profiles or certificates."""
    manifest_path = Path(os.environ["SIGNING_MANIFEST"])
    if not manifest_path.is_file():
        return
    manifest = json.loads(manifest_path.read_text())
    for profile in manifest.get("profiles", []):
        path = profile.get("path")
        if path:
            Path(path).unlink(missing_ok=True)


def self_test():
    der_roundtrip()
    jwt_roundtrip()
    pbxproj_roundtrip()
    export_roundtrip()
    forbidden_roundtrip()
    cleanup_roundtrip()
    refuses_certificate_mutation()
    profile_choice_roundtrip()
    prepare_roundtrip()
    source_roundtrip()
    print("asc signing ok")


def der_roundtrip():
    raw = bytes(range(32)) + bytes(range(32, 64))
    # Make the high bit set so the DER form needs a leading zero.
    raw = b"\x80" + raw[1:32] + b"\x7f" + raw[33:]
    der = raw_to_der(raw)
    if der_to_raw(der) != raw:
        raise SystemExit("DER signature roundtrip failed")


def jwt_roundtrip():
    with tempfile.TemporaryDirectory() as directory:
        key_path = Path(directory) / "key.pem"
        created = subprocess.run(
            [
                "openssl",
                "ecparam",
                "-name",
                "prime256v1",
                "-genkey",
                "-noout",
                "-out",
                str(key_path),
            ],
            capture_output=True,
            check=False,
        )
        if created.returncode != 0:
            raise SystemExit("Could not generate a test signing key.")
        pem = key_path.read_bytes()
        token = make_jwt(pem, "KEYID1234", "issuer-id", 1_700_000_000)
        header_text, payload_text, signature_text = token.split(".")
        header = json.loads(b64url_decode(header_text))
        payload = json.loads(b64url_decode(payload_text))
        if header.get("alg") != "ES256" or header.get("kid") != "KEYID1234":
            raise SystemExit("JWT header was not ES256")
        if payload.get("aud") != "appstoreconnect-v1" or payload.get("iss") != "issuer-id":
            raise SystemExit("JWT audience was not appstoreconnect-v1")
        if b"BEGIN PRIVATE KEY" in token.encode() or b"BEGIN EC PRIVATE KEY" in token.encode():
            raise SystemExit("JWT included the private key")
        public_path = Path(directory) / "pub.pem"
        extracted = subprocess.run(
            ["openssl", "ec", "-pubout", "-in", str(key_path), "-out", str(public_path)],
            capture_output=True,
            check=False,
        )
        if extracted.returncode != 0:
            raise SystemExit("Could not read the test public key.")
        signature = raw_to_der(b64url_decode(signature_text))
        signature_path = Path(directory) / "sig.der"
        signature_path.write_bytes(signature)
        verified = subprocess.run(
            [
                "openssl",
                "dgst",
                "-sha256",
                "-verify",
                str(public_path),
                "-signature",
                str(signature_path),
            ],
            input=f"{header_text}.{payload_text}".encode(),
            capture_output=True,
            check=False,
        )
        if verified.returncode != 0:
            raise SystemExit("JWT signature did not verify")


def pbxproj_roundtrip():
    fixture = """
\t\tbuildSettings = {
\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\tDEVELOPMENT_TEAM = EXAMPLETEAM;
\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary;
\t\t};
\t\tbuildSettings = {
\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary.widget;
\t\t};
\t\tbuildSettings = {
\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary.tests;
\t\t};
\t\tbuildSettings = {
\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary.watchkitapp;
\t\t};
"""
    patched = patch_pbxproj(fixture, "EXAMPLETEAM", "/tmp/signing.keychain-db", TARGETS)
    if 'PRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary;' not in patched:
        raise SystemExit("pbxproj lost the iOS bundle id")
    if patched.count("CODE_SIGN_STYLE = Manual;") != 3:
        raise SystemExit("pbxproj did not set manual signing on the app, widget, and watch")
    if 'PROVISIONING_PROFILE_SPECIFIER = "Rosary App Store";' not in patched:
        raise SystemExit("pbxproj missed the iOS profile name")
    if 'PROVISIONING_PROFILE_SPECIFIER = "RosaryWatch App Store";' not in patched:
        raise SystemExit("pbxproj missed the watch profile name")
    if "com.lojo.Rosary.tests" not in patched or patched.count("CODE_SIGN_STYLE = Automatic;") != 1:
        raise SystemExit("pbxproj changed the test bundle")
    if "Apple Distribution" not in patched or "/tmp/signing.keychain-db" not in patched:
        raise SystemExit("pbxproj missed the distribution identity or keychain")


def export_roundtrip():
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "ExportOptions.plist"
        write_export_options(path, "EXAMPLETEAM", TARGETS)
        with path.open("rb") as handle:
            payload = plistlib.load(handle)
        if payload["method"] != "app-store-connect" or payload["signingStyle"] != "manual":
            raise SystemExit("export options were not manual app-store-connect")
        if payload["signingCertificate"] != "Apple Distribution":
            raise SystemExit("export options missed Apple Distribution")
        if payload["destination"] != "upload" or payload["manageAppVersionAndBuildNumber"] is not False:
            raise SystemExit("export options did not keep the build number or upload destination")
        profiles = payload["provisioningProfiles"]
        if profiles.get("com.lojo.Rosary") != "Rosary App Store":
            raise SystemExit("export options missed the iOS profile")
        if profiles.get("com.lojo.Rosary.watchkitapp") != "RosaryWatch App Store":
            raise SystemExit("export options missed the watch profile")
        if profiles.get("com.lojo.Rosary.widget") != "RosaryWidget App Store":
            raise SystemExit("export options missed the widget profile")


def forbidden_roundtrip():
    held = sys.stderr
    captured = io.StringIO()
    sys.stderr = captured
    try:
        stop_api(
            403,
            '{"errors":[{"status":"403","code":"FORBIDDEN_ERROR","detail":"The resource is not allowed."}]}',
            "certificate",
        )
    except SystemExit as error:
        if error.code != 1:
            raise SystemExit("forbidden path did not stop")
    else:
        raise SystemExit("forbidden path did not stop")
    finally:
        sys.stderr = held
    text = captured.getvalue()
    if "FORBIDDEN_ERROR" not in text or "The resource is not allowed." not in text:
        raise SystemExit("forbidden path did not keep the API response")
    if "Nothing was revoked" not in text or "Admin" not in text:
        raise SystemExit("forbidden path did not say to stop")
    limit = io.StringIO()
    sys.stderr = limit
    try:
        stop_api(
            409,
            "You have already reached the maximum number of certificates of this type.",
            "certificate",
        )
    except SystemExit:
        pass
    finally:
        sys.stderr = held
    if "Nothing was revoked" not in limit.getvalue() or "certificate limit" not in limit.getvalue():
        raise SystemExit("certificate limit was not reported clearly")


def cleanup_roundtrip():
    """Cleanup removes local profile files and does not call the API."""
    with tempfile.TemporaryDirectory() as tmp:
        profile_file = Path(tmp) / "p.mobileprovision"
        profile_file.write_bytes(b"x")
        manifest = Path(tmp) / "m.json"
        write_manifest(
            manifest,
            [{"id": "PROF1", "name": "n", "bundleId": "b", "path": str(profile_file)}],
        )

        def boom(token, method, path, payload=None):
            raise SystemExit("cleanup called the App Store Connect API")

        real_api = globals()["api"]
        globals()["api"] = boom
        os.environ["SIGNING_MANIFEST"] = str(manifest)
        try:
            cleanup()
        finally:
            globals()["api"] = real_api
            os.environ.pop("SIGNING_MANIFEST", None)
        if profile_file.exists():
            raise SystemExit("cleanup left the profile file behind")


def refuses_certificate_mutation():
    for method, path in (
        ("POST", "/v1/certificates"),
        ("DELETE", "/v1/certificates/" + SHARED_CERTIFICATE_ID),
        ("PATCH", "/v1/certificates/" + SHARED_CERTIFICATE_ID),
    ):
        try:
            api("token", method, path, {"data": {}})
        except SystemExit as error:
            if "Refusing" not in str(error):
                raise SystemExit("certificate mutation was not refused") from error
        else:
            raise SystemExit("certificate mutation was not refused")


def profile_record(profile_id, bundle_resource_id, bundle_id, certificate_id, name, expiration, state="ACTIVE"):
    return {
        "type": "profiles",
        "id": profile_id,
        "attributes": {
            "name": name,
            "profileType": PROFILE_TYPE,
            "profileState": state,
            "expirationDate": expiration,
            "profileContent": base64.b64encode(b"profile-" + profile_id.encode()).decode(),
        },
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
            "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
        },
    }


def profile_choice_roundtrip():
    now = datetime(2026, 10, 19, tzinfo=timezone.utc)
    included = {
        ("bundleIds", "APP"): {"attributes": {"identifier": "com.lojo.Rosary"}},
        ("bundleIds", "WIDGET"): {"attributes": {"identifier": "com.lojo.Rosary.widget"}},
    }
    profiles = [
        profile_record("OLD", "APP", "com.lojo.Rosary", SHARED_CERTIFICATE_ID, "Old", "2020-01-01T00:00:00Z"),
        profile_record("OTHER", "APP", "com.lojo.Rosary", "OTHERCERT", "Other", "2028-01-01T00:00:00Z"),
        profile_record("SOON", "APP", "com.lojo.Rosary", SHARED_CERTIFICATE_ID, "Soon", "2027-01-01T00:00:00Z"),
        profile_record("LATER", "APP", "com.lojo.Rosary", SHARED_CERTIFICATE_ID, "Later", "2028-01-01T00:00:00Z"),
        profile_record("DEAD", "APP", "com.lojo.Rosary", SHARED_CERTIFICATE_ID, "Dead", "2029-01-01T00:00:00Z", "INVALID"),
        profile_record("WIDGET", "WIDGET", "com.lojo.Rosary.widget", "OTHERCERT", "Widget", "2028-01-01T00:00:00Z"),
    ]
    chosen = matching_profile(profiles, included, "com.lojo.Rosary", SHARED_CERTIFICATE_ID, now)
    if chosen is None or chosen["id"] != "LATER":
        raise SystemExit("profile choice did not keep the shared certificate")
    if matching_profile(profiles, included, "com.lojo.Rosary.widget", SHARED_CERTIFICATE_ID, now) is not None:
        raise SystemExit("profile choice reused a profile for a different certificate")


def fixture_certificate(directory):
    cert = Path(directory) / "cert.pem"
    key = Path(directory) / "key.pem"
    created = subprocess.run(
        [
            "openssl", "req", "-x509", "-newkey", "ec",
            "-pkeyopt", "ec_paramgen_curve:prime256v1",
            "-keyout", str(key),
            "-out", str(cert),
            "-days", "1",
            "-nodes",
            "-subj", "/CN=Test",
        ],
        capture_output=True,
        check=False,
    )
    if created.returncode != 0:
        raise SystemExit("Could not create a fixture certificate.")
    der = subprocess.run(
        ["openssl", "x509", "-in", str(cert), "-outform", "DER"],
        capture_output=True,
        check=False,
    )
    if der.returncode != 0 or not der.stdout:
        raise SystemExit("Could not read the fixture certificate.")
    return cert, der.stdout


def prepare_roundtrip():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        cert, der = fixture_certificate(root)
        project = root / "project.pbxproj"
        project.write_text(
            "\n".join((
                "\t\tbuildSettings = {",
                "\t\t\tCODE_SIGN_STYLE = Automatic;",
                "\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary;",
                "\t\t};",
                "\t\tbuildSettings = {",
                "\t\t\tCODE_SIGN_STYLE = Automatic;",
                "\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary.widget;",
                "\t\t};",
                "\t\tbuildSettings = {",
                "\t\t\tCODE_SIGN_STYLE = Automatic;",
                "\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.lojo.Rosary.watchkitapp;",
                "\t\t};",
                "",
            ))
        )
        identity = "Apple Distribution: Test (TEAM)"
        identity_path = root / "identity.txt"
        identity_path.write_text(identity)
        calls = []

        def fake_api(token, method, path, payload=None):
            route = path.split("?", 1)[0]
            calls.append((method, route))
            if method != "GET" and route.startswith("/v1/certificates"):
                raise SystemExit("prepare mutated a certificate")
            if method == "GET" and route == "/v1/certificates/" + SHARED_CERTIFICATE_ID:
                return 200, json.dumps({
                    "data": {
                        "id": SHARED_CERTIFICATE_ID,
                        "attributes": {
                            "certificateType": CERTIFICATE_TYPE,
                            "expirationDate": "2027-01-01T00:00:00Z",
                            "certificateContent": base64.b64encode(der).decode(),
                        },
                    }
                })
            if method == "GET" and route == "/v1/profiles":
                return 200, json.dumps({
                    "data": [
                        profile_record(
                            "APPPROF",
                            "BIDAPP",
                            "com.lojo.Rosary",
                            SHARED_CERTIFICATE_ID,
                            "Rosary App Store",
                            "2027-06-01T00:00:00Z",
                        )
                    ],
                    "included": [{
                        "type": "bundleIds",
                        "id": "BIDAPP",
                        "attributes": {"identifier": "com.lojo.Rosary"},
                    }],
                })
            if method == "GET" and route == "/v1/bundleIds":
                identifier = urllib.parse.parse_qs(path.split("?", 1)[1]).get("filter[identifier]", [""])[0]
                return 200, json.dumps({
                    "data": [{"id": "BID-" + identifier, "attributes": {"identifier": identifier}}]
                })
            if method == "POST" and route == "/v1/profiles":
                certificates = payload["data"]["relationships"]["certificates"]["data"]
                if certificates != [{"type": "certificates", "id": SHARED_CERTIFICATE_ID}]:
                    raise SystemExit("profile was not tied to the shared certificate")
                name = payload["data"]["attributes"]["name"]
                return 201, json.dumps({
                    "data": {
                        "id": "NEW-" + name,
                        "attributes": {
                            "name": name,
                            "profileContent": base64.b64encode(name.encode()).decode(),
                        },
                    }
                })
            return 500, "{}"

        real_api = globals()["api"]
        real_jwt = globals()["jwt_from_env"]
        globals()["api"] = fake_api
        globals()["jwt_from_env"] = lambda: "token"
        try:
            prepare({
                "certificate": str(cert),
                "manifest": str(root / "manifest.json"),
                "profiles_dir": str(root / "profiles"),
                "team": "EXAMPLETEAM",
                "keychain": "/tmp/signing.keychain-db",
                "pbxproj": str(project),
                "export_plist": str(root / "ExportOptions.plist"),
                "identity_file": str(identity_path),
            })
        finally:
            globals()["api"] = real_api
            globals()["jwt_from_env"] = real_jwt
        posts = [route for method, route in calls if method == "POST"]
        if posts != ["/v1/profiles", "/v1/profiles"]:
            raise SystemExit("prepare did not create only the missing profiles: " + repr(calls))
        if any(method != "GET" and route.startswith("/v1/certificates") for method, route in calls):
            raise SystemExit("prepare mutated a certificate")
        text = project.read_text()
        if text.count("CODE_SIGN_STYLE = Manual;") != 3 or identity not in text:
            raise SystemExit("prepare did not apply manual signing")
        with (root / "ExportOptions.plist").open("rb") as handle:
            exported = plistlib.load(handle)
        if exported["signingStyle"] != "manual" or exported["signingCertificate"] != identity:
            raise SystemExit("prepare did not export manual signing")
        if exported["provisioningProfiles"].get("com.lojo.Rosary.watchkitapp") != "RosaryWatch App Store":
            raise SystemExit("prepare missed the watch profile")


def source_roundtrip():
    shell = Path(__file__).with_name("archive-upload.sh").read_text()
    for phrase in (
        "openssl genrsa",
        "openssl req",
        "allowProvisioningUpdates",
        "fastlane",
        "csr" + "Content",
    ):
        if phrase in shell:
            raise SystemExit("archive script still mints certificates")
    own = Path(__file__).read_text()
    for name in ("create_certificate", "free_distribution_slot", "revoke_own_certificate"):
        if f"def {name}" in own:
            raise SystemExit("signing script still mints certificates")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        self_test()
        return
    if len(sys.argv) > 1 and sys.argv[1] == "cleanup":
        cleanup()
        return
    if len(sys.argv) > 1 and sys.argv[1] == "prepare":
        required = (
            "certificate",
            "manifest",
            "profiles_dir",
            "team",
            "keychain",
            "pbxproj",
            "export_plist",
            "identity_file",
        )
        values = {}
        args = sys.argv[2:]
        index = 0
        while index < len(args):
            name = args[index][2:].replace("-", "_")
            if index + 1 >= len(args):
                raise SystemExit("Missing a signing argument.")
            values[name] = args[index + 1]
            index += 2
        missing = [name for name in required if name not in values]
        if missing:
            raise SystemExit("Missing signing arguments.")
        prepare(values)
        return
    raise SystemExit("Usage: asc_signing.py --self-test | prepare | cleanup")


if __name__ == "__main__":
    main()
