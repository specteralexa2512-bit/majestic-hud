# Real Life Roleplay HUD (ESX)

Ein FiveM ESX-HUD im gewünschten Stil: „Real Life Roleplay“ mit rotem i-Punkt, echter Online-Anzahl, Benutzer-ID/Server-ID, deutschsprachigen Labels, Geld/Bank, Statusleiste und fließendem Tacho mit Tankanzeige.

## Installation

1. Den Ordner `majestic_hud` in `resources` legen.
2. `es_extended` installieren, für Hunger und Durst zusätzlich `esx_status`.
3. In `server.cfg` eintragen:

```cfg
ensure es_extended
ensure esx_status
ensure majestic_hud
```

4. Server neu starten oder `ensure majestic_hud` ausführen.

## Hinweise

- Online-Anzahl wird serverseitig aus der aktuellen Spielerzahl ermittelt und aktualisiert.
- Bargeld und Bank werden aus den ESX-Konten `money` und `bank` gelesen.
- Fahrzeugdaten werden im NUI weich interpoliert, damit das Tacho flüssiger läuft.
- Der Name, Text, Farben und Kartenblöcke lassen sich in `html/index.html` und `html/style.css` anpassen.
