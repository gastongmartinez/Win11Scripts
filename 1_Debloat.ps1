Import-Module -Name $PSScriptRoot\Debloat.psm1 -Force

$SN = Read-Host -Prompt "Al finalizar se reiniciara el equipo, desea continuar? (S/N)"
if ( $SN -eq "N" ) {
    exit
}

# Comentar para omitir
$MSApss = @(
    "Microsoft.XboxGameCallableUI"
    "Clipchamp.Clipchamp"
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.People"
    "Microsoft.ScreenSketch"
    "Microsoft.WindowsMaps"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"
    "MicrosoftTeams"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "Microsoft.XboxGameOverlay"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.GamingApp"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Todos"
    "MicrosoftCorporationII.QuickAssist"
)

RemoveApps $MSApss