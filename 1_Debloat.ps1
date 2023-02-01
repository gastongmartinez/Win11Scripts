#Requires -RunAsAdministrator
#Requires -Version 5.1

Import-Module -Name $PSScriptRoot\Debloat.psm1 -Force

$SN = Read-Host -Prompt "Al finalizar se reiniciara el equipo, desea continuar? (S/N)"
if ( $SN -eq "N" ) {
    exit
}

# Comentar para omitir
$MSApss = @(
    "Clipchamp.Clipchamp"
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.People"
    "Microsoft.ScreenSketch"
    "Microsoft.WindowsAlarms"
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
    "microsoft.windowscommunicationsapps"
)

RemoveApps $MSApss


# Privacy & Telemetry
DiagTrackService -Disable
DiagnosticDataLevel -Minimal
ErrorReporting -Disable
FeedbackFrequency -Never
ScheduledTasks -Disable
SigninInfo -Disable
LanguageListAccess -Disable
AdvertisingID -Disable
WindowsWelcomeExperience -Hide
WindowsTips -Disable
SettingsSuggestedContent -Hide
AppsSilentInstalling -Disable
WhatsNewInWindows -Disable
TailoredExperiences -Disable
BingSearch -Disable


# UI & Personalization
ThisPC -Show
UserFolder -Show
CheckBoxes -Disable
HiddenItems -Enable
FileExtensions -Show
OpenFileExplorerTo -ThisPC
FileExplorerCompactMode -Disable
SnapAssist -Disable
SnapAssistFlyout -Enable
FileTransferDialog -Detailed
RecycleBinDeleteConfirmation -Enable
QuickAccessRecentFiles -Hide
QuickAccessFrequentFolders -Show
TaskbarAlignment -Left
TaskbarSearch -Hide
TaskViewButton -Hide
TaskbarWidgets -Hide
TaskbarChat -Hide
UnpinTaskbarShortcuts -Shortcuts Edge, Store
ControlPanelView -SmallIcons
WindowsColorMode -Dark
AppColorMode -Dark
FirstLogonAnimation -Disable
JPEGWallpapersQuality -Max
RestartNotification -Show
ShortcutsSuffix -Disable
PrtScnSnippingTool -Enable
AeroShaking -Enable
FolderGroupBy -None

# System
StorageSense -Disable
Hibernation -Disable
Win32LongPathLimit -Disable
BSoDStopError -Enable
AdminApprovalMode -Default
DeliveryOptimization -Disable
WindowsFeatures -Disable
WindowsCapabilities -Uninstall
UpdateMicrosoftProducts -Enable
PowerPlan -High
NetworkAdaptersSavePower -Disable
WinPrtScrFolder -Desktop
NumLock -Enable
StickyShift -Disable
SaveRestartableApps -Enable
DefaultTerminalApp -WindowsTerminal
