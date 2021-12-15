Write-Output "Instalando Chocolatey"

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Write-Output "Instalando Paquetes"
# Comentar para omitir
$Applist = @(
    "vscode"
    "firefox"
    "jdk8"
    "powertoys"
    "git"
    "python"
    "brave"
    "googlechrome"
    "qbittorrent"
    "vlc"
    "mpv" 
    "winscp"
    "glaryutilities-free"
    #"calibre"
    "sumatrapdf"
    "neovim"
    "etcher"
    "filezilla"
    "powershell-core"
    #"handbrake"
    #"coretemp"
    "miktex"
    "shellcheck"
    "alacritty"
    #"joplin"
    "nodejs"
    "yarn"
    #"virtualbox"
    "winrar"
    #"pycharm-community"
    #"intellijidea-community"
    "ripgrep"
    "fd"
    "llvm"
    "anaconda3"
    "ninja"
)

# Instalacion de PowerISO directa hasta que validen la ultima actualizacion en choco
# $PISO = "$PSScriptRoot\PowerISO7-x64.exe"
# Invoke-WebRequest -Uri "https://www.poweriso.net/PowerISO7-x64.exe" -OutFile $PISO
# $Proc = Start-Process $PISO -ArgumentList "/S" -PassThru
# Wait-Process -Id $Proc.Id -Timeout 30

ForEach ($App in $Applist) {
    $App = $App.TrimEnd()
    Write-Output "Instalando $App"
    choco install $App -y
}

Stop-Process -Name "brave" -ErrorAction SilentlyContinue
Stop-Process -Name "flux" -ErrorAction SilentlyContinue

$SN = Read-Host -Prompt "Se recomienda reiniciar el equipo, desea hacerlo ahora? (S/N): "
if ( $SN -eq "S" ) {
    Restart-Computer
}


