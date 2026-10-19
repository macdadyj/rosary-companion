#!/usr/bin/env bash
# Archive with manual distribution signing and upload to TestFlight.
# Imports the shared distribution certificate from DIST_CERT_P12 into a
# temporary keychain. App Store profiles are fetched or created for that
# certificate. This script does not create or revoke certificates.
# Does not print secret values. Deletes the API key, keychain, and local
# profile files on exit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# TestFlight already holds builds up to 26 from the previous repository, so the
# build number is the run number plus this offset. A re-run of the same run
# appends .attempt so App Store Connect does not reject a repeated upload.
BUILD_NUMBER_OFFSET=100
compute_build_number() {
  local run_number="$1" attempt="${2:-1}" number
  if [[ ! "${run_number}" =~ ^[0-9]+$ ]]; then
    run_number=1
  fi
  number=$((run_number + BUILD_NUMBER_OFFSET))
  if [[ "${attempt}" != "1" ]]; then
    number="${number}.${attempt}"
  fi
  printf '%s' "${number}"
}

# Writes AuthKey_<id>.p8 from ASC_KEY_P8. Accepts base64 (whitespace ignored)
# or PEM text that begins with -----BEGIN PRIVATE KEY-----. Error text never
# includes the secret.
write_api_key() {
  python3 - <<'PY'
import base64
import os
import sys
from pathlib import Path

raw = os.environ.get("ASC_KEY_P8", "")
text = raw.replace("\r\n", "\n").replace("\r", "\n").lstrip("\ufeff").strip()
destination = Path(os.environ["KEY_PATH"])
if text.startswith("-----BEGIN PRIVATE KEY-----"):
    if "PRIVATE KEY" not in text:
        sys.exit("ASC_KEY_P8 does not look like a private key.")
    if not text.endswith("\n"):
        text += "\n"
    destination.write_text(text)
    sys.exit(0)
compact = "".join(text.split())
if not compact:
    sys.exit("ASC_KEY_P8 is empty.")
pad = (-len(compact)) % 4
try:
    data = base64.b64decode(compact + ("=" * pad), validate=True)
except Exception:
    sys.exit("ASC_KEY_P8 is not valid base64 and is not a PEM private key.")
if b"PRIVATE KEY" not in data:
    sys.exit("ASC_KEY_P8 decoded, but it does not look like a .p8 private key.")
destination.write_bytes(data)
PY
}

# Writes a PKCS#12 file from DIST_CERT_P12 (base64, whitespace ignored).
# Error text never includes the secret.
write_p12() {
  python3 - <<'PY'
import base64
import os
import sys
from pathlib import Path

raw = os.environ.get("DIST_CERT_P12", "")
destination = Path(os.environ["P12_PATH"])
compact = "".join(raw.split())
if not compact:
    sys.exit("DIST_CERT_P12 is empty.")
pad = (-len(compact)) % 4
try:
    data = base64.b64decode(compact + ("=" * pad), validate=True)
except Exception:
    sys.exit("DIST_CERT_P12 is not valid base64.")
if len(data) < 2 or data[0] != 0x30:
    sys.exit("DIST_CERT_P12 is not a PKCS#12 file.")
destination.write_bytes(data)
PY
}

extract_certificate_pem() {
  local p12="$1" passfile="$2" pem="$3"
  rm -f "${pem}"
  if openssl pkcs12 -in "${p12}" -nokeys -passin "file:${passfile}" -out "${pem}" >/dev/null 2>&1 \
    && grep -q "BEGIN CERTIFICATE" "${pem}"; then
    return 0
  fi
  rm -f "${pem}"
  if openssl pkcs12 -in "${p12}" -nokeys -legacy -passin "file:${passfile}" -out "${pem}" >/dev/null 2>&1 \
    && grep -q "BEGIN CERTIFICATE" "${pem}"; then
    return 0
  fi
  rm -f "${pem}"
  echo "Could not read the distribution certificate." >&2
  return 1
}

import_distribution_identity() {
  local p12="$1" p12_pass="$2" keychain="$3" keychain_pass="$4"
  security delete-keychain "${keychain}" >/dev/null 2>&1 || true
  security create-keychain -p "$(cat "${keychain_pass}")" "${keychain}"
  security set-keychain-settings -lut 21600 "${keychain}"
  security unlock-keychain -p "$(cat "${keychain_pass}")" "${keychain}"
  if ! security import "${p12}" \
    -k "${keychain}" \
    -P "$(cat "${p12_pass}")" \
    -f pkcs12 -A \
    -T /usr/bin/codesign \
    -T /usr/bin/security >/dev/null 2>&1; then
    echo "The distribution certificate did not import into the temporary keychain." >&2
    return 1
  fi
  if ! security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$(cat "${keychain_pass}")" \
    "${keychain}" >/dev/null 2>&1; then
    echo "Could not allow codesign to use the distribution certificate." >&2
    return 1
  fi
  security list-keychains -d user -s "${keychain}" login.keychain-db >/dev/null
  security default-keychain -s "${keychain}"
}

remove_signing_keychain() {
  local keychain="$1"
  security delete-keychain "${keychain}" >/dev/null 2>&1 || true
  security default-keychain -s login.keychain-db >/dev/null 2>&1 || true
  security list-keychains -d user -s login.keychain-db >/dev/null 2>&1 || true
}

check_encryption() {
  local plist
  for plist in Config/Info.plist Config/WatchInfo.plist; do
    if ! awk '
      $0 ~ /<key>ITSAppUsesNonExemptEncryption<\/key>/ { found=1; next }
      found { exit ($0 ~ /<false\/>/) ? 0 : 1 }
      END { if (!found) exit 1 }
    ' "${ROOT}/${plist}"; then
      echo "${plist} must set ITSAppUsesNonExemptEncryption to false." >&2
      exit 1
    fi
  done
}

if [[ "${1:-}" == "--cleanup-keychain" ]]; then
  remove_signing_keychain "${SIGNING_KEYCHAIN:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/rosary-signing.keychain-db}"
  exit 0
fi

if [[ "${1:-}" == "--self-test" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT
  pem=$'-----BEGIN PRIVATE KEY-----\nMIIB\n-----END PRIVATE KEY-----\n'
  # Wrapped base64, the shape `base64` writes and GitHub often stores.
  b64="$(printf '%s' "${pem}" | base64 | fold -w 20)"
  run_case() {
    local label="$1"
    local value="$2"
    local out="${tmp}/${label}.p8"
    ASC_KEY_P8="${value}" KEY_PATH="${out}" write_api_key
    python3 - "${out}" "${label}" <<'PY'
import sys
from pathlib import Path
body = Path(sys.argv[1]).read_bytes()
if b"PRIVATE KEY" not in body or b"BEGIN" not in body:
    sys.exit("self-test failed for " + sys.argv[2])
print("asc key decode ok: " + sys.argv[2])
PY
  }
  run_case "pem" "${pem}"
  run_case "base64-wrapped" "${b64}"$'\n'
  run_case "base64-spaces" "$(printf '%s' "${pem}" | base64 | tr -d '\n' | sed 's/..../& /g')"
  if ASC_KEY_P8="not a key" KEY_PATH="${tmp}/bad.p8" write_api_key 2>"${tmp}/err"; then
    echo "self-test failed: invalid input was accepted" >&2
    exit 1
  fi
  if grep -q "not a key" "${tmp}/err"; then
    echo "self-test failed: error text included the secret" >&2
    exit 1
  fi
  echo "asc key decode rejected invalid input"
  marker="SECRET-P12-MARKER"
  if DIST_CERT_P12="${marker}" P12_PATH="${tmp}/bad.p12" write_p12 2>"${tmp}/p12err"; then
    echo "self-test failed: invalid certificate was accepted" >&2
    exit 1
  fi
  if grep -q "${marker}" "${tmp}/p12err"; then
    echo "self-test failed: certificate error text included the secret" >&2
    exit 1
  fi
  printf '\x30\x03\x02\x01\x01' > "${tmp}/expected.p12"
  encoded="$(base64 < "${tmp}/expected.p12" | fold -w 8)"
  DIST_CERT_P12="${encoded}" P12_PATH="${tmp}/ok.p12" write_p12
  if ! cmp -s "${tmp}/expected.p12" "${tmp}/ok.p12"; then
    echo "self-test failed: certificate decode mismatch" >&2
    exit 1
  fi
  echo "distribution certificate decode ok"
  rm -rf "${tmp}"
  trap - EXIT
  check_encryption
  [[ "$(compute_build_number 1 1)" == "101" ]] || { echo "self-test failed: build number for run 1" >&2; exit 1; }
  [[ "$(compute_build_number 27 1)" == "127" ]] || { echo "self-test failed: build number for run 27" >&2; exit 1; }
  [[ "$(compute_build_number 5 3)" == "105.3" ]] || { echo "self-test failed: build number for a re-run" >&2; exit 1; }
  [[ "$(compute_build_number "" 1)" == "101" ]] || { echo "self-test failed: build number without a run" >&2; exit 1; }
  echo "build number ok: run 1 -> 101, run 5 attempt 3 -> 105.3"
  python3 "${SCRIPT_DIR}/asc_signing.py" --self-test
  python3 "${SCRIPT_DIR}/asc_testflight.py" --self-test
  python3 "${SCRIPT_DIR}/patch-watch-embed.py" --self-test
  exit 0
fi

missing=0
for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8 DIST_CERT_P12 DIST_CERT_PASSWORD DEVELOPMENT_TEAM; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing GitHub secret ${name}." >&2
    missing=1
  fi
done
if [[ "${missing}" -ne 0 ]]; then
  echo "Add the App Store Connect secrets before uploading. See docs/TESTFLIGHT.md." >&2
  exit 1
fi
TEAM="${DEVELOPMENT_TEAM}"
BUILD_NUMBER="$(compute_build_number "${GITHUB_RUN_NUMBER:-1}" "${GITHUB_RUN_ATTEMPT:-1}")"
echo "Archive build number ${BUILD_NUMBER} for com.lojo.Rosary, com.lojo.Rosary.widget, and com.lojo.Rosary.watchkitapp."
WORKDIR="$(mktemp -d)"
KEYCHAIN="${SIGNING_KEYCHAIN:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/rosary-signing.keychain-db}"
MANIFEST="${WORKDIR}/signing-manifest.json"
KEY_PATH="${WORKDIR}/private_keys/AuthKey_${ASC_KEY_ID}.p8"
KEYCHAIN_READY=0
cleanup() {
  local status=$?
  if [[ "${KEYCHAIN_READY}" == "1" ]]; then
    remove_signing_keychain "${KEYCHAIN}"
  fi
  if [[ -f "${MANIFEST}" ]]; then
    SIGNING_MANIFEST="${MANIFEST}" python3 "${SCRIPT_DIR}/asc_signing.py" cleanup || \
      echo "Warning: could not remove local provisioning profiles for this run." >&2
  fi
  rm -rf "${WORKDIR}"
  exit "${status}"
}
trap cleanup EXIT
mkdir -p "${WORKDIR}/private_keys"
export KEY_PATH
export P12_PATH="${WORKDIR}/distribution.p12"
umask 077
write_api_key
write_p12
printf '%s' "${DIST_CERT_PASSWORD}" > "${WORKDIR}/p12.pass"
chmod 600 "${WORKDIR}/p12.pass" "${WORKDIR}/distribution.p12"
extract_certificate_pem "${WORKDIR}/distribution.p12" "${WORKDIR}/p12.pass" "${WORKDIR}/distribution.pem"

cd "${ROOT}"
if [[ ! -d Rosary.xcodeproj ]]; then
  xcodegen generate
fi
check_encryption

openssl rand -base64 32 | tr -d '\n' > "${WORKDIR}/keychain.pass"
chmod 600 "${WORKDIR}/keychain.pass"
KEYCHAIN_READY=1
import_distribution_identity \
  "${WORKDIR}/distribution.p12" \
  "${WORKDIR}/p12.pass" \
  "${KEYCHAIN}" \
  "${WORKDIR}/keychain.pass"
python3 - "${KEYCHAIN}" "${WORKDIR}/identity.txt" <<'PY'
import re
import subprocess
import sys

keychain, destination = sys.argv[1], sys.argv[2]
result = subprocess.run(
    ["security", "find-identity", "-p", "codesigning", "-v", keychain],
    capture_output=True,
    text=True,
)
names = re.findall(r'"([^"]*Distribution[^"]*)"', result.stdout)
if result.returncode != 0 or not names:
    sys.exit("The distribution certificate did not import into the temporary keychain.")
with open(destination, "w", encoding="utf-8") as handle:
    handle.write(names[0])
PY
echo "Imported the shared distribution certificate into the temporary keychain."

python3 "${SCRIPT_DIR}/asc_signing.py" prepare \
  --certificate "${WORKDIR}/distribution.pem" \
  --manifest "${MANIFEST}" \
  --profiles-dir "${HOME}/Library/MobileDevice/Provisioning Profiles" \
  --team "${TEAM}" \
  --keychain "${KEYCHAIN}" \
  --pbxproj "${ROOT}/Rosary.xcodeproj/project.pbxproj" \
  --export-plist "${ROOT}/build/ExportOptions.plist" \
  --identity-file "${WORKDIR}/identity.txt"

echo "Archiving with manual distribution signing."
# The app, widget, and watch targets were switched to Manual in the generated
# project, each with its own App Store profile. A global Manual setting would
# also hit unsigned package targets. Provisioning is installed before this
# archive, so xcodebuild is not asked to create signing assets.
xcodebuild archive \
  -project Rosary.xcodeproj \
  -scheme Rosary \
  -destination "generic/platform=iOS" \
  -archivePath "${ROOT}/build/Rosary.xcarchive" \
  -clonedSourcePackagesDirPath "${ROOT}/build/SourcePackages" \
  -derivedDataPath "${ROOT}/build/ArchiveDerivedData" \
  DEVELOPMENT_TEAM="${TEAM}" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}"

python3 "${SCRIPT_DIR}/patch-watch-embed.py" --check-app \
  "${ROOT}/build/Rosary.xcarchive/Products/Applications/Rosary.app"

xcodebuild -exportArchive \
  -archivePath "${ROOT}/build/Rosary.xcarchive" \
  -exportPath "${ROOT}/build/export" \
  -exportOptionsPlist "${ROOT}/build/ExportOptions.plist" \
  -authenticationKeyPath "${KEY_PATH}" \
  -authenticationKeyID "${ASC_KEY_ID}" \
  -authenticationKeyIssuerID "${ASC_ISSUER_ID}"
echo "Uploaded to App Store Connect."
echo "Releasing build ${BUILD_NUMBER} to the internal TestFlight group."
KEY_PATH="${KEY_PATH}" BUILD_NUMBER="${BUILD_NUMBER}" \
  python3 "${SCRIPT_DIR}/asc_testflight.py" release --wait-seconds 1800 --require-ready
