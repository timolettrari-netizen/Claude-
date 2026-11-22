# GymPlan – iOS-App (SwiftUI, Liquid Glass)

Native iPhone-App fürs Gym: erstellt dir automatisch einen Trainingsplan und speichert Gewicht und Wiederholungen jedes Satzes, damit du deinen Fortschritt siehst. Das Design nutzt das echte **Liquid Glass** von iOS 26 (`glassEffect`, Glas-Buttons, schwebende Tab-Leiste).

## Funktionen

**Plan-Generator** (beim ersten Start oder unter Plan → „Neu erstellen“)
- **Ziel:** Muskelaufbau, Maximalkraft, Fettabbau oder Fitness. Danach richten sich Sätze, Wiederholungen und Pausen.
- **Erfahrung:** Anfänger, Fortgeschritten oder Profi. Anfänger bekommen mehr Maschinen, Profis mehr Sätze und schwerere Übungen.
- **Trainingstage:** 2–6 Wochentage frei wählbar. Das Split ergibt sich automatisch:
  - 2 Tage: Ganzkörper A/B
  - 3 Tage: Ganzkörper A/B/C (Anfänger) oder Push/Pull/Beine
  - 4 Tage: Ober-/Unterkörper
  - 5 Tage: Push/Pull/Beine + Ober/Unter
  - 6 Tage: Push/Pull/Beine ×2
- **Zeit pro Training:** 30–90 Minuten. Die Zahl der Übungen wird passend zur Zeit (inkl. Pausen und Aufwärmen) gewählt.
- **Ausrüstung:** Fitnessstudio, Kurzhanteln zuhause oder nur Körpergewicht.
- **Schwerpunkt:** Brust & Schultern, Beine & Po, Arme oder Rücken. Dafür gibt es zusätzliche Übungen und einen Satz mehr.
- **Beschwerden:** Knie, Schulter, unterer Rücken. Belastende Übungen werden durch schonendere ersetzt.
- **Plandauer:** 4, 8 oder 12 Wochen oder offen. Jede 4. Woche ist eine Entlastungswoche.
- Vorschau des Plans, bevor du ihn erstellst.

**Plan anpassen:** Übung tauschen (passende Alternativen), Sätze ändern, Reihenfolge ändern, Übungen hinzufügen oder entfernen.

**Training**
- Gewicht und Wiederholungen je Satz eintragen, Satz abhaken (deutsches Komma geht: `62,5`).
- Vorschlag aus dem letzten Training (doppelte Progression): Hast du überall die obere Wiederholungszahl geschafft, schlägt die App mehr Gewicht vor. Sonst steigerst du zuerst die Wiederholungen.
- „Letztes Mal: 60 kg × 10 · 10 · 9“ direkt bei der Übung.
- Pausen-Timer mit −15 s / +15 s / Überspringen. Mitteilung mit Ton und Vibration, wenn die Pause vorbei ist (auch bei gesperrtem iPhone).
- Display bleibt an. Training lässt sich minimieren und später fortsetzen, auch nach einem Neustart der App.
- Zusammenfassung mit Dauer, Sätzen, Volumen und **neuen Bestleistungen**.

**Fortschritt**
- Wochenvolumen (Diagramm), Trainings gesamt, Wochen in Folge, Bestleistungen.
- Je Übung ein Diagramm: geschätztes 1RM (Epley), Höchstgewicht, Volumen, Wiederholungen. Dazu alle Einheiten.
- Körpergewicht eintragen, mit Verlauf.
- Trainingsverlauf mit Details, Einträge lassen sich löschen.

**Essen** (eigener Tab)
- Essensplan für die nächsten 10 Tage, passend zu deinem Gym-Plan: **Trainingstage** bekommen mehr Kalorien und einen Snack nach dem Training mit Kohlenhydraten. An **Ruhetagen** gibt es beim Abnehmen kohlenhydratärmere Gerichte.
- **46 Gerichte mit Fotos:** die 31 aus TorwartFit plus 15 neue (z. B. Teriyaki-Bowl, Vollkorn-Bolognese, Burrito-Bowl, Linsen-Dal, Gnocchi-Pfanne, Protein-Porridge, Bananen-Shake). Keine Garnelen.
- Portionen werden automatisch auf dein Kalorienziel skaliert, mit Zutatenmengen und Zubereitung.
- Mahlzeiten abhaken, Gerichte tauschen, sonstiges Essen eintragen (auswärts, Snacks).
- Tagesbilanz: Kalorien, Eiweiß, Kohlenhydrate.
- Einkaufsliste für 3, 7 oder 10 Tage, abhaken und teilen.

**Gewichtsziel** (Essen → 🎯, Fortschritt → Körpergewicht oder Einstellungen)
- Startgewicht, Zielgewicht und Zieldatum, Größe, Alter, Geschlecht und Alltagsaktivität. Vorausgefüllt mit deinen Werten aus TorwartFit.
- Daraus entstehen das Kalorienziel (Mifflin-St Jeor, Defizit aus dem Zieldatum, 300–900 kcal), der Trainingstag-Bonus und das Eiweißziel (1,8 g/kg).
- Live-Vorschau beim Bearbeiten, mit Warnung, wenn das Ziel zu ehrgeizig ist.
- **Automatik:** Jeden Montag wird dein tatsächliches Tempo der letzten 4 Wochen mit dem Plan verglichen und die Hälfte der Abweichung ausgeglichen (±300 kcal).
- Gewichtsverlauf mit Soll-Linie, Fortschrittsbalken, Tempo pro Woche und Prognose, wann du das Ziel erreichst.

**Übungen:** 85 Übungen nach Muskelgruppe, mit Suche, Ausführungstipps und deinem Fortschritt.

**Einstellungen:** Backup exportieren und importieren (JSON), Pausen-Mitteilung, alle Daten löschen. Alles bleibt lokal auf dem iPhone.

## Voraussetzungen
- Mac mit **Xcode 26** oder neuer (für Liquid Glass)
- iPhone mit **iOS 26** oder neuer
- Apple-ID (kostenlos reicht)

## Installation
Wie bei TorwartFit:

```bash
cd gym-app
./build-and-install.sh
```

Oder von Hand: `gym-app/GymPlan.xcodeproj` öffnen → Target **GymPlan** → *Signing & Capabilities* → dein Team wählen → iPhone oben auswählen → ▶︎.

Beim ersten Start auf dem iPhone: Einstellungen → Allgemein → VPN & Geräteverwaltung → deiner Apple-ID vertrauen.

Wenn der Bundle Identifier `de.timo.gymplan` belegt ist, ändere ihn in Xcode und im Skript (`BUNDLE_ID`).

**Kompilierfehler?** Die Meldung kopieren und mir schicken – ich korrigiere sie.

## Aufbau
```
GymPlan/
  App/     App-Start, Tabs, Pausen-Mitteilung, Design (Hintergrund, Glas-Karten, Chips)
  Model/   Datenmodell, Übungsbibliothek, Plan-Generator, Store (Progression, Statistik, Speichern),
           Nutrition (Kalorienziel, Essensplan, Einkaufsliste)
  Views/   Heute, Plan, Generator, Training, Essen, Gewichtsziel, Fortschritt, Übungen, Einstellungen
  Resources/recipes.json   46 Rezepte mit Zutaten, Nährwerten und Zubereitung
  Assets.xcassets/  App-Icon, Akzentfarbe, Food/ (46 Fotos)
```
