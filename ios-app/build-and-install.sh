#!/bin/bash
# TorwartFit bauen, aufs per Kabel angeschlossene iPhone installieren und starten.
# Aufruf (im Ordner ios-app):   ./build-and-install.sh
# Optional:  TEAM=ABCDE12345 DEVICE=<UDID> ./build-and-install.sh
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID="de.timo.torwartfit"

echo "== Xcode"
xcodebuild -version

# --- iPhone finden: bevorzugt per Kabel, sonst verbunden ---
if [ -z "${DEVICE:-}" ]; then
  TMP_JSON="$(mktemp)"
  xcrun devicectl list devices --json-output "$TMP_JSON" >/dev/null
  DEVICE="$(osascript -l JavaScript -e "
    const d = JSON.parse($.NSString.stringWithContentsOfFileEncodingError('$TMP_JSON', 4, null).js).result.devices
      .filter(x => (x.hardwareProperties||{}).platform === 'iOS' && (x.hardwareProperties||{}).udid);
    const c = x => x.connectionProperties || {};
    const pick = d.find(x => c(x).transportType === 'wired')
              || d.find(x => c(x).tunnelState === 'connected')
              || d.find(x => c(x).pairingState === 'paired' && c(x).tunnelState !== 'unavailable');
    pick ? pick.hardwareProperties.udid : '';
  ")"
  rm -f "$TMP_JSON"
fi
if [ -z "$DEVICE" ]; then
  echo "Kein iPhone gefunden. Kabel anstecken, iPhone entsperren, 'Diesem Computer vertrauen' tippen"
  echo "und den Entwicklermodus einschalten (Einstellungen → Datenschutz & Sicherheit → Entwicklermodus)."
  xcrun devicectl list devices || true
  exit 1
fi
xcrun devicectl list devices 2>/dev/null | grep -i "$DEVICE" || true
echo "== iPhone: $DEVICE"

# --- Team-ID aus dem Apple-Development-Zertifikat lesen ---
if [ -z "${TEAM:-}" ]; then
  TEAM="$(security find-certificate -c "Apple Development" -p 2>/dev/null \
          | openssl x509 -noout -subject 2>/dev/null \
          | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)"
fi
if [ -z "$TEAM" ]; then
  echo "Keine Team-ID gefunden. In Xcode → Einstellungen → Accounts die Apple-ID hinzufügen,"
  echo "dann Projekt einmal in Xcode öffnen (Signing & Capabilities → Team wählen) und erneut starten."
  exit 1
fi
echo "== Team: $TEAM"

# --- Bauen ---
xcodebuild -project TorwartFit.xcodeproj -scheme TorwartFit \
  -destination "platform=iOS,id=$DEVICE" -configuration Debug \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM" -derivedDataPath build build

APP="build/Build/Products/Debug-iphoneos/TorwartFit.app"

# --- Installieren und starten ---
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" || {
  echo
  echo "Installiert, aber Start blockiert: auf dem iPhone Einstellungen → Allgemein →"
  echo "VPN & Geräteverwaltung → deine Apple-ID → 'Vertrauen' tippen, dann die App öffnen."
}
