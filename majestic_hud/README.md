# Real Life Roleplay HUD

HUD mit live aus dem Spiel ausgelesener Wetterlage, Uhrzeit und Kontostand. Die Wetterbezeichnung folgt dem aktuell synchronisierten GTA-Wetter (z.B. Klar, Regen oder Gewitter). Da GTA/FiveM keinen echten Umgebungstemperaturwert bereitstellt, wird die Temperatur als Näherungswert aus Wetterlage und Spieluhrzeit berechnet; sie ist kein reales Wetter.

Die Uhrzeit, das Datum (TT.MM.JJJJ) und der Wochentag werden in deutscher Zeitzone (Europe/Berlin) angezeigt. Die native GTA-Minimap bleibt unverändert. Der Tacho wird weich interpoliert und zeigt Tankfüllung.

## Installation

Den Ordner `majestic_hud` nach `resources` kopieren. In `server.cfg` eintragen:

```cfg
ensure es_extended
ensure majestic_hud
```

Für die Online-Spielerzahl ist `server.lua` enthalten. Bargeld und Bank werden aus den ESX-Konten `money` und `bank` gelesen.
