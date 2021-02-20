fx_version 'bodacious'
games {'gta5'}

description 'PixelWorld Automated Car Park'
name 'PixelWorld: pw_carpark'
author 'PixelWorldRP creaKtive - https://PixelWorldrp.com'
version 'v1.0.0'

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'config/config.lua',
    'server/main.lua',
}

client_scripts {
    'config/config.lua',
    'client/main.lua',
}

dependencies {
    'es_extended',
    'mysql-async',
    'esx_vehicleshop'
}