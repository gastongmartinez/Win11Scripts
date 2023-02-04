Write-Output "Instalando Chocolatey"

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Write-Output "Instalando Paquetes"
# Comentar para omitir
$AppsCT = @(
    "jdk8"
    "mpv"
    "filezilla"
    "shellcheck"
    "ripgrep"
    "fd"
    "nerd-fonts-jetbrainsmono"
)

ForEach ($App in $AppsCT) {
    $App = $App.TrimEnd()
    Write-Output "Instalando $App"
    choco install $App -y
}

# Comentar para omitir
$AppsWG = @(
    "Microsoft Visual Studio Code"
    "Mozilla.Firefox"
    "Microsoft PowerToys"
    "Git.Git"
    "GitHub Desktop"
    "Python.Python.3.11"
    "Brave.Brave"
    "Google Chrome"
    "qBittorrent.qBittorrent"
    "VLC media player"
    "WinSCP"
    "Glary Utilities"
    "calibre"
    "Obsidian.Obsidian"
    "TheDocumentFoundation.LibreOffice"
    "SumatraPDF"
    "Neovim"
    "balenaEtcher"
    "HandBrake"
    "Core Temp"
    "Alacritty"
    "Node.js"
    "Yarn.Yarn"
    "Oracle VM VirtualBox"
    "WinRAR"
    "LLVM"
    "Meson Build System"
    "Oracle.MySQL"
    "PostgreSQL 14"
    "pgAdmin 4"
    "PyCharm Professional Edition"
    "DataGrip"
    "CLion"
    "JetBrains Rider"
    "Apple.iTunes"
    "Microsoft.PowerShell"
    "JanDeDobbeleer.OhMyPosh"
    "Microsoft.PowerBI"
    "Tableau.Public"
    "Rainmeter"
    "Microsoft.VisualStudio.2022.Community"
    "Microsoft.SQLServerManagementStudio"
    "OO-Software.ShutUp10"
    "Flameshot"
)

winget source update

Write-Output "Instalando Paquetes con Winget"

ForEach ($App in $AppsWG) {
    $App = $App.TrimEnd()
    Write-Output "Instalando $App"
    winget install $App --silent --accept-package-agreements
}

# Limpieza Escritorio
Get-ChildItem -Path $HOME\Desktop -Include *.lnk -File -Recurse | ForEach-Object { $_.Delete() }
Get-ChildItem -Path C:\Users\Public\Desktop -Include *.lnk -File -Recurse | ForEach-Object { $_.Delete() }

# Orden iconos escritorio
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" -Name FFlags -Value "1075839525"

$SN = Read-Host -Prompt "Se recomienda reiniciar el equipo, desea hacerlo ahora? (S/N): "
if ( $SN -eq "S" ) {
    Restart-Computer
}