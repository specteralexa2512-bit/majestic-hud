# Majestic HUD (ESX)

Ein einfaches FiveM-HUD mit ESX-Spieler-ID, Job, Bargeld, Bankguthaben, Leben, Rüstung, Hunger, Durst sowie Tacho und Tankanzeige im Fahrzeug.

## Installation

1. Lade den Ordner `majestic_hud` herunter oder kopiere ihn in deinen FiveM-Serverordner unter `resources`.
2. Stelle sicher, dass `es_extended` installiert ist. Für Hunger und Durst wird außerdem `esx_status` benötigt.
3. Füge diese Zeilen in deine `server.cfg` ein (nach den Abhängigkeiten):

   ```cfg
   ensure es_extended
   ensure esx_status
   ensure majestic_hud
   ```

4. Starte den Server neu oder führe in der Serverkonsole `ensure majestic_hud` aus.

## Hinweise

- Die Anzeige verwendet das ESX-Konto `money` für Bargeld und `bank` für das Bankkonto.
- Die Tankanzeige nutzt den nativen GTA-Füllstand. Bei einem eigenen Fuel-System kann die Abfrage in `client.lua` angepasst werden.
- Servername, Texte und Farben lassen sich in `html/index.html` und `html/style.css` ändern.
