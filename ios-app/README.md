# TorwartFit – iOS-App (SwiftUI)

Native iPhone-App für dein Torwart- und Gym-Training. Nicht für den App Store gedacht – du spielst sie mit Xcode direkt auf dein iPhone.

## Was drin ist (Version 1.3)
- **Heute:** Tagesansicht mit heutiger Einheit, Ziel, Tagesform, Wochenplan (abhängig von Spieltag und Ziel), Schritte und Gewicht aus Apple Health
- **Training:** 11 Einheiten (Torwart + Gym A/B/C) und 55 Übungen mit Suche und Kategorien
- **Geführtes Training:** Satz für Satz, Gewicht/Wiederholungen, Pausen-Timer mit Ton und Vibration, Steigerungsvorschlag, Display bleibt an, Zusammenfassung mit Anstrengung (RPE)
- **Übungen:** echte Fotos (Start ⇄ Ende, gemeinfrei aus der Free Exercise DB) oder animierte Figur, Ausrüstung, Schritte, Fehler, Nutzen
- **Coach:** KI-Coach (Claude) mit deinen Trainingsdaten – braucht einen eigenen API-Schlüssel
- **Statistik:** Aktivitätsringe, Diagramm, Leistungstests, Bestwerte, Verlauf
- **Essen:** Mahlzeitenplan für 10 Tage passend zu deinem Dienst (frei / nach Nacht / Spät / Früh-Nacht), 18 Rezepte mit auf dein Kalorienziel skalierten Mengen, „Gegessen“ abhaken, Gerichte tauschen, Eiweiß/Kohlenhydrate, Einkaufsliste (7 Tage, teilbar)
- **Abnehmen:** Gewicht mit Soll-Linie (Start → Ziel), Kalorienziel (Mifflin-St Jeor, Defizit aus Zieldatum, Trainingsbonus), Eingabe oder Apple Health
- **Laufplan:** 1–4 Läufe pro Woche, automatisch auf freie Tage gelegt (nie am Spieltag oder Tag davor, möglichst nicht auf Torwart-Tage). Woche 1–2 Lauf-Geh-Intervalle, dann lockerer und langer Lauf, ab Woche 5 Intervalle, jede 4. Woche leichter. Tempo aus deinen Läufen (Start: 6:20 /km)
- **Lauf-Coach (Sprache):** sagt Gehen/Traben- und Intervall-Wechsel an, jeden Kilometer Zeit, Tempo und Puls, und jede Minute „etwas langsamer“ / „etwas schneller“ – zuerst nach Puls (lockere Läufe in Zone 2 = 60–75 % vom Max-Puls), sonst nach Tempo. Musik wird dabei kurz leiser.
- **Puls live:** Bluetooth-Brustgurt bzw. Uhr mit Pulsübertragung (Polar, Garmin, Wahoo …) oder Apple Watch (Training auf der Uhr starten, Puls kommt über Apple Health). Ø- und Max-Puls werden gespeichert.
- **GPS-Tracker:** Zeit, Strecke, Tempo, Kalorien, Pause, läuft auch mit gesperrtem Bildschirm weiter, Route auf der Karte, Speichern in Apple Health
- **Dienstplan:** 4-Tage-Rhythmus (frei, frei, Spät, Früh/Nacht) vorausgefüllt, per Tippen änderbar; an Früh/Nacht-Tagen automatisch kurzes Training
- **Profil** (Symbol oben rechts auf „Heute“): Ziel, Spieltag, Körperdaten, Dienstplan, Studio/Zuhause, Block-Woche, Apple Health, Erinnerungen, Coach-Schlüssel, Backup (auch Import aus der Web-App)

Noch nicht enthalten: Widget, Strava-Import.

## Voraussetzungen
- Mac mit **Xcode 16 oder neuer** (kostenlos im Mac App Store)
- iPhone mit **iOS 17 oder neuer** und USB-Kabel
- Eine Apple-ID (kostenlos reicht)

## Installation aufs iPhone
1. Den Ordner `ios-app` auf den Mac holen (z. B. Repository klonen oder als ZIP herunterladen).
2. `ios-app/TorwartFit.xcodeproj` doppelklicken – Xcode öffnet das Projekt.
3. Links das blaue Projekt **TorwartFit** anklicken → Target **TorwartFit** → Reiter **Signing & Capabilities**:
   - **Team:** deine Apple-ID auswählen (ggf. über „Add an Account…“ anmelden).
   - **Bundle Identifier:** auf etwas Eindeutiges ändern, z. B. `de.deinname.torwartfit`.
4. iPhone per Kabel anschließen und oben in der Leiste als Ziel auswählen.
5. Auf dem iPhone den **Entwicklermodus** einschalten: Einstellungen → Datenschutz & Sicherheit → Entwicklermodus (danach Neustart).
6. In Xcode auf ▶︎ (Run) klicken.
7. Beim ersten Start auf dem iPhone: Einstellungen → Allgemein → VPN & Geräteverwaltung → deiner Apple-ID vertrauen.

Mit kostenloser Apple-ID läuft die App **7 Tage**, danach einfach in Xcode erneut auf ▶︎ klicken (deine Daten bleiben erhalten). Mit Apple-Entwicklerkonto (99 €/Jahr) läuft sie ein Jahr.

## Falls etwas nicht klappt
- **Fehler bei HealthKit-Berechtigung (Signing):** In „Signing & Capabilities“ die Fähigkeit **HealthKit** mit „+ Capability“ hinzufügen bzw. neu hinzufügen. Notfalls die Zeile `CODE_SIGN_ENTITLEMENTS` entfernen – dann läuft die App ohne Apple Health.
- **Projekt lässt sich nicht öffnen:** In Xcode „File → New → Project → iOS App“ (SwiftUI, Name *TorwartFit*) anlegen, den automatisch erzeugten Inhalt löschen und den Ordner `TorwartFit` (mit `App`, `Model`, `Services`, `Views`, `Resources`, `Assets.xcassets`) hineinziehen. Bei den Info-Einträgen `NSHealthShareUsageDescription` und `NSHealthUpdateUsageDescription` ergänzen.
- **Kompilierfehler:** Die Fehlermeldung kopieren und mir schicken – ich korrigiere sie.

## Lauf-Coach einrichten
Profil → Lauf-Coach: Sprachansagen an, Pulsquelle wählen.
- **Brustgurt:** „Pulsgurt koppeln“ antippen, Gurt anlegen – er erscheint in der Liste. Danach verbindet er sich beim Laufen automatisch.
- **Apple Watch:** Apple Health in der App verbinden (Puls-Leserecht erlauben) und vor dem Lauf auf der Uhr „Laufen im Freien“ starten.

## KI-Coach einrichten
1. Auf <https://console.anthropic.com> anmelden → **API Keys** → neuen Schlüssel erstellen und ggf. Guthaben aufladen.
2. In der App: Profil → KI-Coach → Schlüssel einfügen → „Schlüssel speichern“.
Der Schlüssel liegt nur im iOS-Schlüsselbund deines iPhones. Jede Antwort kostet ein paar Cent (Modell Claude Opus 5.5, kurze Antworten).

## Daten aus der Web-App übernehmen
In der Web-App unter Profil → „Backup exportieren“, Datei auf das iPhone (z. B. iCloud Drive) legen, dann in der iOS-App Profil → „Backup importieren“.

## Aufbau
```
TorwartFit/
  App/        App-Start, Tabs, Design (Farben, Schrift, Buttons)
  Model/      Katalog (Übungen, Einheiten, Ziele) und Store (Plan-Logik, Speichern)
  Services/   Apple Health, Erinnerungen, Schlüsselbund, Claude-API
  Views/      Heute, Training, Geführtes Training, Übung, Coach, Statistik, Profil
  Resources/  catalog.json (aus der Web-App erzeugt)
  Assets.xcassets/  App-Icon, Farben, 78 Übungsfotos
```
