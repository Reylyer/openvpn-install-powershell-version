# getting vars
$conf = @{}
if($(Test-Path "conf.txt")){
    $conf = Get-Content "conf.txt" -Raw | ConvertFrom-StringData
}

if(-Not $conf.proto){
    $conf.proto = Read-Host "Using tcp/udp "
    Write-Output "proto=$($conf.proto)" >> "conf.txt"
}

if(-Not $conf.port){
    $conf.port = Read-Host "port (1000-65535) "
    Write-Output "port=$($conf.port)" >> "conf.txt"
}

if(-Not $conf.ip){
    $conf.ip = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
    Write-Output "ip=$($conf.ip)" >> "conf.txt"
}

Write-Output $conf

Set-Location .\easy-rsa
# first time setup
if(-Not $(Test-Path "pki")){
    # create pki
    # creating ca
    # creating diffie hellman key
    # creating server configuration
    Write-Output "
    ./easyrsa init-pki`n
    ./easyrsa build-ca nopass`nezca`n
    " | .\EasyRSA-Start.bat
    Write-Output "
    ./easyrsa gen-dh`n
    ./easyrsa gen-req server nopass`r`n`n
    " | .\EasyRSA-Start.bat 
    Write-Output "
    ./easyrsa sign-req server server`nyes`n
    " | .\EasyRSA-Start.bat
    ..\bin\openvpn.exe --genkey tls-crypt > pki\tls.key

    Write-Output "port $($conf.port)`r
proto $($conf.proto)`r
dev tun`r
client-to-client`r
keepalive 20 300`r
server 10.69.13.0 255.255.255.0`r
ifconfig-pool-persist ipp.txt`r
cipher AES-256-CBC`r
comp-lzo`r
persist-key`r
persist-tun`r
status openvpn-status.log`r
verb 3`r
<ca>`r
$((Get-Content -Path 'pki\ca.crt') -join "`n" )`r
</ca>`r
<cert>`r
$((Get-Content -Path 'pki\issued\server.crt') -join "`n" )`r
</cert>`r
<key>`r
$((Get-Content -Path 'pki\private\server.key') -join "`n" )`r
</key>`r
<dh>`r
$((Get-Content -Path 'pki\dh.pem') -join "`n" )`r
</dh>`r
<tls-crypt>`r
$((Get-Content -Path 'pki\tls.key') -join "`n" )`r
</tls-crypt>`r
" | out-file "../server.ovpn" -encoding utf8

    Write-Output "Successfully creating server.ovpn"
} 
else {
    $client = Read-Host "Client name "
    Write-Output "
    ./easyrsa gen-req $client nopass`r`n`n
    " | .\EasyRSA-Start.bat 
    Write-Output "
    ./easyrsa sign-req client $client`nyes`n
    " | .\EasyRSA-Start.bat

    Write-Output "client`r
dev tun`r
proto $($conf.proto)`r
remote $($conf.ip) $($conf.port)`r
resolv-retry infinite`r
nobind`r
cipher AES-256-CBC`r
comp-lzo`r
verb 3`r
<ca>`r
$((Get-Content -Path 'pki\ca.crt') -join "`n" )`r
</ca>`r
<cert>`r
$((Get-Content -Path ('pki\issued\' + $client + '.crt')) -join "`n" )`r
</cert>`r
<key>`r
$((Get-Content -Path ('pki\private\' + $client + '.key')) -join "`n" )`r
</key>`r
<tls-crypt>`r
$((Get-Content -Path 'pki\tls.key') -join "`n" )`r
</tls-crypt>`r
"| out-file "../$client.ovpn" -encoding utf8

    Write-Output "Successfully creating $client.ovpn"
}


Set-Location ..