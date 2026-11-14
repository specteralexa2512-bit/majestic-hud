# Real Life Roleplay HUD + Admin-/Report-System

Das normale HUD bleibt enthalten. Ergänzt wurden ein Report-System, ein F3-Adminmenü, Ticketchat und Adminlevel 1–7. Serverseitige Events prüfen Adminlevel und Login; Clients können sich keine Adminrechte selbst geben.

## Voraussetzungen / Installation

1. `majestic_hud` nach `resources` kopieren. ESX muss vorher gestartet sein.
2. In `server.cfg`:

```cfg
ensure es_extended
ensure majestic_hud
```

3. Den ersten Level-7-Admin ausschließlich über die **Serverkonsole** eintragen:

```text
rlrp_setadmin license:DEINE_LICENSE_ID 7
```

Die License-ID steht in der Spielerliste/Serverkonsole bei den Spieler-Identifiers. Alternativ `Config.BootstrapAdmins` in `config.lua` mit deiner `license:`-ID befüllen. Die Datei enthält absichtlich keine voreingestellte Admin-ID.

## Spielerreports

- Spieler erstellen ein Ticket im Chat mit `/report <Anliegen>`.
- Spieler erhalten Antworten als Chatnachricht und können mit `/reply <Nachricht>` auf ihr offenes Ticket antworten.
- Tickets und Nachrichten liegen aktuell im Arbeitsspeicher; nach einem Serverneustart werden offene Tickets zurückgesetzt.

## Admin-Zugang und Rechte

- `/adminlogin` entsperrt die Adminfunktionen für die aktuelle Sitzung.
- F3 öffnet nach dem Login das Adminmenü. Level 1 sieht offene Reports (nur ansehen); ab Level 2 können Admins F3-Funktionen und Ticketchat nutzen.
- `/admin` schaltet ab Level 2 den Adminmodus ein/aus. Der Spielername mit ID wird für alle Spieler rot und halbtransparent über dem Charakter angezeigt.
- `/giveadmin <ID> [Level 1-7]` ist nur Level 7 erlaubt. Ohne Levelangabe wird Level 1 vergeben. Rechte werden anhand der stabilen `license:`-ID gespeichert.

Das Adminmenü zeigt nur die Bereiche **Offene Tickets**, **Befehle** und **Administration**. Ticket-Schließen/Übernehmen und Antworten sind ab Level 2 verfügbar. Der Report-Zähler erscheint bei eingeloggten Admins, sobald offene Tickets existieren.

## Hinweis zu Wetter/Temperatur

Das Wetterlabel folgt dem GTA-Wetter. GTA/FiveM stellt keine echte Umgebungstemperatur bereit; angezeigte Gradwerte sind eine Näherung.
