**Reports/Tickets funktionieren nicht?** Stelle sicher, dass du den neuesten Resource-Ordner vollständig ersetzt hast, danach `restart majestic_hud` (oder Server-Neustart). `/report <Anliegen>` funktioniert für Spieler; Admins müssen `/adminlogin` eingeben, dann werden Ticketliste, Zähler und transparentes Live-Panel links über der Map synchronisiert. Die bisherige Ticketablage ist RAM-basiert und wird beim Neustart geleert.

## Adminbefehle ab Level 2

Nach `/adminlogin` stehen folgende serverseitig geprüfte Befehle ab Level 2 zur Verfügung: `/admin`, `/mute [ID]`, `/unmute [ID]`, `/spawnwep [WEAPON_NAME] [ammo]`, `/spawncar [model] [color1] [color2]`, `/setkevlar [ID] [amount]`, `/sethealth [ID] [amount]`, `/goto [ID]`, `/gethere [ID]`, `/kick [ID] [reason]`, `/ban [ID] [reason]`. `/giveadmin [ID] [Level]` bleibt Level 7 vorbehalten. Ban-Gründe werden in FiveM Resource-KVP gespeichert und beim Reconnect geprüft; es wird keine externe Ban-Datei erzeugt.
