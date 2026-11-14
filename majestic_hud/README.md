# Real Life Roleplay HUD + Admin-/Report-System

Das normale HUD bleibt erhalten. Das Adminmenü wurde neu gestaltet. Eingeloggte Admins sehen offene Reports und den Ticket-/Nachrichtenverlauf jetzt zusätzlich als transparentes Live-Panel links über der Minimap; F3 ist dafür nicht nötig. F3 öffnet weiterhin das detaillierte Adminmenü.

## Installation

`majestic_hud` nach `resources` kopieren und in der `server.cfg` nach ESX starten:

```cfg
ensure es_extended
ensure majestic_hud
```

Der konfigurierte Bootstrap-Admin wird in `config.lua` gepflegt. Nach Updates die Resource neu starten.

## Reports / Zugriff

- Spieler: `/report <Anliegen>` und im offenen Ticket `/reply <Nachricht>`.
- Admin: `/adminlogin`, danach F3. Level 1 kann Reports ansehen; Level 2+ kann Antworten, Tickets übernehmen/schließen und `/admin` verwenden. Level 7 vergibt mit `/giveadmin ID [Level 1-7]` Rechte.
- Die transparente Report-Übersicht ist nach Admin-Login links über der Minimap sichtbar und zeigt aktuelle Reports plus die letzten Nachrichten.
- Das Befehle-Tab bildet die in den Referenzbildern genannten Serverbefehle ab. Manche davon (z.B. Jail/Jobradio/Media) benötigen eine Integration mit der auf dem jeweiligen Server installierten Jail-, Job- oder Medic-Resource.
- Tickets und Nachrichten sind aktuell nur im Arbeitsspeicher gespeichert und werden beim Neustart zurückgesetzt.
