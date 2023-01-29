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
)

Write-Output "Instalando Paquetes con Winget"

ForEach ($App in $AppsWG) {
    $App = $App.TrimEnd()
    Write-Output "Instalando $App"
    winget install $App --silent --accept-package-agreements
}

