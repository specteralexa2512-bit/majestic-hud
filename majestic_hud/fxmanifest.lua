fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Custom HUD'
description 'Real Life Roleplay HUD + Admin/Report system'
version '2.2.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
