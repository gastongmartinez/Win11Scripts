<#
	.SYNOPSIS
	"Win11 Script" es un modulo de PowerShell para la limpieza de aplicaciones y servicios de M$.

	Fecha: 29/01/2023

    .NOTES
	Ejecutar previamente 0_HabilitarScripts.bat o el comando:
		Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

	.NOTES
    Vesiones de Windows 11 soportadas: 22H2
	Ediciones: Home/Pro/Enterprise
	Arquitectura: x64

    .Notes
    Basado en:
        https://github.com/farag2/Sophia-Script-for-Windows
        https://github.com/ChrisTitusTech/
#>

#region MS Apps
Function RemoveApps ($Apps) {
        
    $Logfile = "$env:SystemRoot\Temp\LimpiezaApps.log"
    Set-Content -Path $Logfile -Value "Remove builtin apps based on $Applist"

    ForEach ($App in $Apps) {
        $App = $App.TrimEnd()
        $PackageFullName = (Get-AppxPackage $App).PackageFullName
        $ProPackageFullName = (Get-AppxProvisionedPackage -online | Where-Object { $_.Displayname -eq $App }).PackageName

        if ($PackageFullName) {
            "`r`nRemoving Package: $App" | Out-File -FilePath $Logfile -Append -Encoding ascii
            start-sleep -Seconds 5
            remove-AppxPackage -package $PackageFullName | Out-File -FilePath $Logfile -Append -Encoding ascii
        }
        else {
            "Unable to find package: $App" | Out-File -FilePath $Logfile -Append -Encoding ascii 
        }

        if ($ProPackageFullName) {
            "`r`nRemoving Provisioned Package: $ProPackageFullName" | Out-File -FilePath $Logfile -Append -Encoding ascii
            start-sleep -Seconds 5 
            Remove-AppxProvisionedPackage -online -packagename $ProPackageFullName | Out-File -FilePath $Logfile -Append -Encoding ascii  
        }
        else {
            "Unable to find provisioned package: $App" | Out-File -FilePath $Logfile -Append -Encoding ascii
        }
    }

    Get-Content -Path $Logfile
    
    winget uninstall "Microsoft OneDrive"
    winget uninstall "Cortana"
    winget uninstall "Microsoft 365 (Office)"
}
#endregion MS Apps

#region Privacy & Telemetry
<#
	.SYNOPSIS
	The Connected User Experiences and Telemetry (DiagTrack) service

	.PARAMETER Disable
	Disable the Connected User Experiences and Telemetry (DiagTrack) service, and block connection for the Unified Telemetry Client Outbound Traffic

	.PARAMETER Enable
	Enable the Connected User Experiences and Telemetry (DiagTrack) service, and allow connection for the Unified Telemetry Client Outbound Traffic

	.EXAMPLE
	DiagTrackService -Disable

	.EXAMPLE
	DiagTrackService -Enable

	.NOTES
	Disabling the "Connected User Experiences and Telemetry" service (DiagTrack) can cause you not being able to get Xbox achievements anymore

	.NOTES
	Current user
#>
function DiagTrackService {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            # Connected User Experiences and Telemetry
            # Disabling the "Connected User Experiences and Telemetry" service (DiagTrack) can cause you not being able to get Xbox achievements anymore
            Get-Service -Name DiagTrack | Stop-Service -Force
            Get-Service -Name DiagTrack | Set-Service -StartupType Disabled

            # Block connection for the Unified Telemetry Client Outbound Traffic
            Get-NetFirewallRule -Group DiagTrack | Set-NetFirewallRule -Enabled False -Action Block
        }
        "Enable" {
            # Connected User Experiences and Telemetry
            Get-Service -Name DiagTrack | Set-Service -StartupType Automatic
            Get-Service -Name DiagTrack | Start-Service

            # Allow connection for the Unified Telemetry Client Outbound Traffic
            Get-NetFirewallRule -Group DiagTrack | Set-NetFirewallRule -Enabled True -Action Allow
        }
    }
}

<#
	.SYNOPSIS
	Diagnostic data

	.PARAMETER Minimal
	Set the diagnostic data collection to minimum

	.PARAMETER Default
	Set the diagnostic data collection to default

	.EXAMPLE
	DiagnosticDataLevel -Minimal

	.EXAMPLE
	DiagnosticDataLevel -Default

	.NOTES
	Machine-wide
#>
function DiagnosticDataLevel {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Minimal"
        )]
        [switch]
        $Minimal,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Minimal" {
            if (Get-WindowsEdition -Online | Where-Object -FilterScript { ($_.Edition -like "Enterprise*") -or ($_.Edition -eq "Education") }) {
                # Diagnostic data off
                if (-not (Test-Path -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection)) {
                    New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Force
                }
                New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -PropertyType DWord -Value 0 -Force
                Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Type DWORD -Value 0
            }
            else {
                # Send required diagnostic data
                if (-not (Test-Path -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection)) {
                    New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Force
                }
                New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -PropertyType DWord -Value 1 -Force
                Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Type DWORD -Value 1
            }

            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Force
            }
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection -Name MaxTelemetryAllowed -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Name ShowedToastAtLevel -PropertyType DWord -Value 1 -Force
        }
        "Default" {
            # Optional diagnostic data
            Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Force -ErrorAction Ignore
            Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Type CLEAR

            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Force
            }
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection -Name MaxTelemetryAllowed -PropertyType DWord -Value 3 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Name ShowedToastAtLevel -PropertyType DWord -Value 3 -Force
        }
    }
}

<#
	.SYNOPSIS
	Windows Error Reporting

	.PARAMETER Disable
	Turn off Windows Error Reporting

	.PARAMETER Enable
	Turn on Windows Error Reporting

	.EXAMPLE
	ErrorReporting -Disable

	.EXAMPLE
	ErrorReporting -Enable

	.NOTES
	Current user
#>
function ErrorReporting {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            if ((Get-WindowsEdition -Online).Edition -notmatch "Core") {
                Get-ScheduledTask -TaskName QueueReporting | Disable-ScheduledTask
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" -Name Disabled -PropertyType DWord -Value 1 -Force
            }

            Get-Service -Name WerSvc | Stop-Service -Force
            Get-Service -Name WerSvc | Set-Service -StartupType Disabled
        }
        "Enable" {
            Get-ScheduledTask -TaskName QueueReporting | Enable-ScheduledTask
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Force -ErrorAction Ignore

            Get-Service -Name WerSvc | Set-Service -StartupType Manual
            Get-Service -Name WerSvc | Start-Service
        }
    }
}

<#
	.SYNOPSIS
	The feedback frequency

	.PARAMETER Never
	Change the feedback frequency to "Never"

	.PARAMETER Automatically
	Change feedback frequency to "Automatically"

	.EXAMPLE
	FeedbackFrequency -Never

	.EXAMPLE
	FeedbackFrequency -Automatically

	.NOTES
	Current user
#>
function FeedbackFrequency {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Never"
        )]
        [switch]
        $Never,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Automatically"
        )]
        [switch]
        $Automatically
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Never" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Siuf\Rules)) {
                New-Item -Path HKCU:\Software\Microsoft\Siuf\Rules -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Siuf\Rules -Name NumberOfSIUFInPeriod -PropertyType DWord -Value 0 -Force
        }
        "Automatically" {
            Remove-Item -Path HKCU:\Software\Microsoft\Siuf\Rules -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	The diagnostics tracking scheduled tasks

	.PARAMETER Disable
	Turn off the diagnostics tracking scheduled tasks

	.PARAMETER Enable
	Turn on the diagnostics tracking scheduled tasks

	.EXAMPLE
	ScheduledTasks -Disable

	.EXAMPLE
	ScheduledTasks -Enable

	.NOTES
	A pop-up dialog box lets a user select tasks

	.NOTES
	Current user
#>
function ScheduledTasks {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    Add-Type -AssemblyName PresentationCore, PresentationFramework

    #region Variables
    # Initialize an array list to store the selected scheduled tasks
    $SelectedTasks = New-Object -TypeName System.Collections.ArrayList($null)

    # The following tasks will have their checkboxes checked
    [string[]]$CheckedScheduledTasks = @(
        # Collects program telemetry information if opted-in to the Microsoft Customer Experience Improvement Program
        "ProgramDataUpdater",

        # This task collects and uploads autochk SQM data if opted-in to the Microsoft Customer Experience Improvement Program
        "Proxy",

        # If the user has consented to participate in the Windows Customer Experience Improvement Program, this job collects and sends usage data to Microsoft
        "Consolidator",

        # The USB CEIP (Customer Experience Improvement Program) task collects Universal Serial Bus related statistics and information about your machine and sends it to the Windows Device Connectivity engineering group at Microsoft
        "UsbCeip",

        # The Windows Disk Diagnostic reports general disk and system information to Microsoft for users participating in the Customer Experience Program
        "Microsoft-Windows-DiskDiagnosticDataCollector",

        # This task shows various Map related toasts
        "MapsToastTask",

        # This task checks for updates to maps which you have downloaded for offline use
        "MapsUpdateTask",

        # Initializes Family Safety monitoring and enforcement
        "FamilySafetyMonitor",

        # Synchronizes the latest settings with the Microsoft family features service
        "FamilySafetyRefreshTask",

        # XblGameSave Standby Task
        "XblGameSaveTask"
    )

    # Check if device has a camera
    $DeviceHasCamera = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object -FilterScript { (($_.PNPClass -eq "Camera") -or ($_.PNPClass -eq "Image")) -and ($_.Service -ne "StillCam") }
    if (-not $DeviceHasCamera) {
        # Windows Hello
        $CheckedScheduledTasks += "FODCleanupTask"
    }
    #endregion Variables

    #region XAML Markup
    # The section defines the design of the upcoming dialog box
    [xml]$XAML = '
	<Window
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Name="Window"
		MinHeight="450" MinWidth="400"
		SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen"
		TextOptions.TextFormattingMode="Display" SnapsToDevicePixels="True"
		FontFamily="Candara" FontSize="16" ShowInTaskbar="True"
		Background="#F1F1F1" Foreground="#262626">
		<Window.Resources>
			<Style TargetType="StackPanel">
				<Setter Property="Orientation" Value="Horizontal"/>
				<Setter Property="VerticalAlignment" Value="Top"/>
			</Style>
			<Style TargetType="CheckBox">
				<Setter Property="Margin" Value="10, 10, 5, 10"/>
				<Setter Property="IsChecked" Value="True"/>
			</Style>
			<Style TargetType="TextBlock">
				<Setter Property="Margin" Value="5, 10, 10, 10"/>
			</Style>
			<Style TargetType="Button">
				<Setter Property="Margin" Value="20"/>
				<Setter Property="Padding" Value="10"/>
			</Style>
			<Style TargetType="Border">
				<Setter Property="Grid.Row" Value="1"/>
				<Setter Property="CornerRadius" Value="0"/>
				<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
				<Setter Property="BorderBrush" Value="#000000"/>
			</Style>
			<Style TargetType="ScrollViewer">
				<Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
				<Setter Property="BorderBrush" Value="#000000"/>
				<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
			</Style>
		</Window.Resources>
		<Grid>
			<Grid.RowDefinitions>
				<RowDefinition Height="Auto"/>
				<RowDefinition Height="*"/>
				<RowDefinition Height="Auto"/>
			</Grid.RowDefinitions>
			<ScrollViewer Name="Scroll" Grid.Row="0"
				HorizontalScrollBarVisibility="Disabled"
				VerticalScrollBarVisibility="Auto">
				<StackPanel Name="PanelContainer" Orientation="Vertical"/>
			</ScrollViewer>
			<Button Name="Button" Grid.Row="2"/>
		</Grid>
	</Window>
	'
    #endregion XAML Markup

    $Reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $XAML)
    $Form = [Windows.Markup.XamlReader]::Load($Reader)
    $XAML.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
        Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)
    }

    #region Functions
    function Get-CheckboxClicked {
        [CmdletBinding()]
        param
        (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [ValidateNotNull()]
            $CheckBox
        )

        $Task = $Tasks | Where-Object -FilterScript { $_.TaskName -eq $CheckBox.Parent.Children[1].Text }

        if ($CheckBox.IsChecked) {
            [void]$SelectedTasks.Add($Task)
        }
        else {
            [void]$SelectedTasks.Remove($Task)
        }

        if ($SelectedTasks.Count -gt 0) {
            $Button.IsEnabled = $true
        }
        else {
            $Button.IsEnabled = $false
        }
    }

    function DisableButton {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        [void]$Window.Close()

        $SelectedTasks | ForEach-Object -Process { Write-Verbose $_.TaskName -Verbose }
        $SelectedTasks | Disable-ScheduledTask
    }

    function EnableButton {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        [void]$Window.Close()

        $SelectedTasks | ForEach-Object -Process { Write-Verbose $_.TaskName -Verbose }
        $SelectedTasks | Enable-ScheduledTask
    }

    function Add-TaskControl {
        [CmdletBinding()]
        param
        (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [ValidateNotNull()]
            $Task
        )

        process {
            $CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
            $CheckBox.Add_Click({ Get-CheckboxClicked -CheckBox $_.Source })

            $TextBlock = New-Object -TypeName System.Windows.Controls.TextBlock
            $TextBlock.Text = $Task.TaskName

            $StackPanel = New-Object -TypeName System.Windows.Controls.StackPanel
            [void]$StackPanel.Children.Add($CheckBox)
            [void]$StackPanel.Children.Add($TextBlock)
            [void]$PanelContainer.Children.Add($StackPanel)

            # If task checked add to the array list
            if ($CheckedScheduledTasks | Where-Object -FilterScript { $Task.TaskName -match $_ }) {
                [void]$SelectedTasks.Add($Task)
            }
            else {
                $CheckBox.IsChecked = $false
            }
        }
    }
    #endregion Functions

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {

            $State = "Disabled"
            $ButtonContent = $Localization.Enable
            $ButtonAdd_Click = { EnableButton }
        }
        "Disable" {
            $State = "Ready"
            $ButtonContent = $Localization.Disable
            $ButtonAdd_Click = { DisableButton }
        }
    }

    Write-Information -MessageData "" -InformationAction Continue
    Write-Verbose -Message $Localization.Patient -Verbose

    # Getting list of all scheduled tasks according to the conditions
    $Tasks = Get-ScheduledTask | Where-Object -FilterScript { ($_.State -eq $State) -and ($_.TaskName -in $CheckedScheduledTasks) }

    if (-not ($Tasks)) {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.NoData -Verbose

        return
    }

    Write-Information -MessageData "" -InformationAction Continue
    Write-Verbose -Message $Localization.DialogBoxOpening -Verbose

    #region Sendkey function
    # Emulate the Backspace key sending to prevent the console window to freeze
    Start-Sleep -Milliseconds 500

    Add-Type -AssemblyName System.Windows.Forms

    $SetForegroundWindow = @{
        Namespace        = "WinAPI"
        Name             = "ForegroundWindow"
        Language         = "CSharp"
        MemberDefinition = @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
"@
    }

    if (-not ("WinAPI.ForegroundWindow" -as [type])) {
        Add-Type @SetForegroundWindow
    }

    Get-Process | Where-Object -FilterScript { (($_.ProcessName -eq "powershell") -or ($_.ProcessName -eq "WindowsTerminal")) -and ($_.MainWindowTitle -match "Sophia Script for Windows 11") } | ForEach-Object -Process {
        # Show window, if minimized
        [WinAPI.ForegroundWindow]::ShowWindowAsync($_.MainWindowHandle, 10)

        Start-Sleep -Seconds 1

        # Force move the console window to the foreground
        [WinAPI.ForegroundWindow]::SetForegroundWindow($_.MainWindowHandle)

        Start-Sleep -Seconds 1

        # Emulate the Backspace key sending
        [System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE 1}")
    }
    #endregion Sendkey function

    $Window.Add_Loaded({ $Tasks | Add-TaskControl })
    $Button.Content = $ButtonContent
    $Button.Add_Click({ & $ButtonAdd_Click })

    $Window.Title = $Localization.ScheduledTasks

    # Force move the WPF form to the foreground
    $Window.Add_Loaded({ $Window.Activate() })
    $Form.ShowDialog() | Out-Null
}

<#
	.SYNOPSIS
	The sign-in info to automatically finish setting up device after an update

	.PARAMETER Disable
	Do not use sign-in info to automatically finish setting up device after an update

	.PARAMETER Enable
	Use sign-in info to automatically finish setting up device after an update

	.EXAMPLE
	SigninInfo -Disable

	.EXAMPLE
	SigninInfo -Enable

	.NOTES
	Current user
#>
function SigninInfo {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            $SID = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object -FilterScript { $_.Name -eq $env:USERNAME }).SID
            if (-not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\UserARSO\$SID")) {
                New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\UserARSO\$SID" -Force
            }
            New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\UserARSO\$SID" -Name OptOut -PropertyType DWord -Value 1 -Force
        }
        "Enable" {
            $SID = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object -FilterScript { $_.Name -eq $env:USERNAME }).SID
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\UserARSO\$SID" -Name OptOut -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	The provision to websites a locally relevant content by accessing my language list

	.PARAMETER Disable
	Do not let websites show me locally relevant content by accessing my language list

	.PARAMETER Enable
	Let websites show me locally relevant content by accessing language my list

	.EXAMPLE
	LanguageListAccess -Disable

	.EXAMPLE
	LanguageListAccess -Enable

	.NOTES
	Current user
#>
function LanguageListAccess {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            New-ItemProperty -Path "HKCU:\Control Panel\International\User Profile" -Name HttpAcceptLanguageOptOut -PropertyType DWord -Value 1 -Force
        }
        "Enable" {
            Remove-ItemProperty -Path "HKCU:\Control Panel\International\User Profile" -Name HttpAcceptLanguageOptOut -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	The permission for apps to show me personalized ads by using my advertising ID

	.PARAMETER Disable
	Do not let apps show me personalized ads by using my advertising ID

	.PARAMETER Enable
	Let apps show me personalized ads by using my advertising ID

	.EXAMPLE
	AdvertisingID -Disable

	.EXAMPLE
	AdvertisingID -Enable

	.NOTES
	Current user
#>
function AdvertisingID {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo -Name Enabled -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo -Name Enabled -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	The Windows welcome experiences after updates and occasionally when I sign in to highlight what's new and suggested

	.PARAMETER Hide
	Hide the Windows welcome experiences after updates and occasionally when I sign in to highlight what's new and suggested

	.PARAMETER Show
	Show the Windows welcome experiences after updates and occasionally when I sign in to highlight what's new and suggested

	.EXAMPLE
	WindowsWelcomeExperience -Hide

	.EXAMPLE
	WindowsWelcomeExperience -Show

	.NOTES
	Current user
#>
function WindowsWelcomeExperience {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-310093Enabled -PropertyType DWord -Value 1 -Force
        }
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-310093Enabled -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Getting tip and suggestions when I use Windows

	.PARAMETER Enable
	Get tip and suggestions when I use Windows

	.PARAMETER Disable
	Do not get tip and suggestions when I use Windows

	.EXAMPLE
	WindowsTips -Enable

	.EXAMPLE
	WindowsTips -Disable

	.NOTES
	Current user
#>
function WindowsTips {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338389Enabled -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338389Enabled -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Suggested me content in the Settings app

	.PARAMETER Hide
	Hide from me suggested content in the Settings app

	.PARAMETER Show
	Show me suggested content in the Settings app

	.EXAMPLE
	SettingsSuggestedContent -Hide

	.EXAMPLE
	SettingsSuggestedContent -Show

	.NOTES
	Current user
#>
function SettingsSuggestedContent {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338393Enabled -PropertyType DWord -Value 0 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-353694Enabled -PropertyType DWord -Value 0 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-353696Enabled -PropertyType DWord -Value 0 -Force
        }
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338393Enabled -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-353694Enabled -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-353696Enabled -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Automatic installing suggested apps

	.PARAMETER Disable
	Turn off automatic installing suggested apps

	.PARAMETER Enable
	Turn on automatic installing suggested apps

	.EXAMPLE
	AppsSilentInstalling -Disable

	.EXAMPLE
	AppsSilentInstalling -Enable

	.NOTES
	Current user
#>
function AppsSilentInstalling {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Ways to get the most out of Windows and finish setting up this device

	.PARAMETER Disable
	Do not suggest ways to get the most out of Windows and finish setting up this device

	.PARAMETER Enable
	Suggest ways to get the most out of Windows and finish setting up this device

	.EXAMPLE
	WhatsNewInWindows -Disable

	.EXAMPLE
	WhatsNewInWindows -Enable

	.NOTES
	Current user
#>
function WhatsNewInWindows {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement -Name ScoobeSystemSettingEnabled -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement -Name ScoobeSystemSettingEnabled -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Tailored experiences

	.PARAMETER Disable
	Do not let Microsoft use your diagnostic data for personalized tips, ads, and recommendations

	.PARAMETER Enable
	Let Microsoft use your diagnostic data for personalized tips, ads, and recommendations

	.EXAMPLE
	TailoredExperiences -Disable

	.EXAMPLE
	TailoredExperiences -Enable

	.NOTES
	Current user
#>
function TailoredExperiences {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy -Name TailoredExperiencesWithDiagnosticDataEnabled -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy -Name TailoredExperiencesWithDiagnosticDataEnabled -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Bing search in the Start Menu

	.PARAMETER Disable
	Disable Bing search in the Start Menu

	.PARAMETER Enable
	Enable Bing search in the Start Menu

	.EXAMPLE
	BingSearch -Disable

	.EXAMPLE
	BingSearch -Enable

	.NOTES
	Current user
#>
function BingSearch {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            if (-not (Test-Path -Path HKCU:\Software\Policies\Microsoft\Windows\Explorer)) {
                New-Item -Path HKCU:\Software\Policies\Microsoft\Windows\Explorer -Force
            }
            New-ItemProperty -Path HKCU:\Software\Policies\Microsoft\Windows\Explorer -Name DisableSearchBoxSuggestions -PropertyType DWord -Value 1 -Force
            Set-Policy -Scope User -Path Software\Policies\Microsoft\Windows\Explorer -Name DisableSearchBoxSuggestions -Type DWORD -Value 1
        }
        "Enable" {
            Remove-ItemProperty -Path HKCU:\Software\Policies\Microsoft\Windows\Explorer -Name DisableSearchBoxSuggestions -Force -ErrorAction Ignore
            Set-Policy -Scope User -Path Software\Policies\Microsoft\Windows\Explorer -Name DisableSearchBoxSuggestions -Type CLEAR
        }
    }
}
#endregion Privacy & Telemetry

#region UI & Personalization
<#
	.SYNOPSIS
	The "This PC" icon on Desktop

	.PARAMETER Show
	Show the "This PC" icon on Desktop

	.PARAMETER Hide
	Hide the "This PC" icon on Desktop

	.EXAMPLE
	ThisPC -Show

	.EXAMPLE
	ThisPC -Hide

	.NOTES
	Current user
#>
function ThisPC {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Show" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -PropertyType DWord -Value 0 -Force
        }
        "Hide" {
            Remove-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	Item check boxes

	.PARAMETER Disable
	Do not use item check boxes

	.PARAMETER Enable
	Use check item check boxes

	.EXAMPLE
	CheckBoxes -Disable

	.EXAMPLE
	CheckBoxes -Enable

	.NOTES
	Current user
#>
function CheckBoxes {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name AutoCheckSelect -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name AutoCheckSelect -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Hidden files, folders, and drives

	.PARAMETER Enable
	Show hidden files, folders, and drives

	.PARAMETER Disable
	Do not show hidden files, folders, and drives

	.EXAMPLE
	HiddenItems -Enable

	.EXAMPLE
	HiddenItems -Disable

	.NOTES
	Current user
#>
function HiddenItems {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -PropertyType DWord -Value 2 -Force
        }
    }
}

<#
	.SYNOPSIS
	File name extensions

	.PARAMETER Show
	Show the file name extensions

	.PARAMETER Hide
	Hide the file name extensions

	.EXAMPLE
	FileExtensions -Show

	.EXAMPLE
	FileExtensions -Hide

	.NOTES
	Current user
#>
function FileExtensions {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -PropertyType DWord -Value 0 -Force
        }
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Folder merge conflicts

	.PARAMETER Show
	Show folder merge conflicts

	.PARAMETER Hide
	Hide folder merge conflicts

	.EXAMPLE
	MergeConflicts -Show

	.EXAMPLE
	MergeConflicts -Hide

	.NOTES
	Current user
#>
function MergeConflicts {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideMergeConflicts -PropertyType DWord -Value 0 -Force
        }
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideMergeConflicts -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Configure how to open File Explorer

	.PARAMETER ThisPC
	Open File Explorer to "This PC"

	.PARAMETER QuickAccess
	Open File Explorer to Quick access

	.EXAMPLE
	OpenFileExplorerTo -ThisPC

	.EXAMPLE
	OpenFileExplorerTo -QuickAccess

	.NOTES
	Current user
#>
function OpenFileExplorerTo {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "ThisPC"
        )]
        [switch]
        $ThisPC,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "QuickAccess"
        )]
        [switch]
        $QuickAccess
    )

    switch ($PSCmdlet.ParameterSetName) {
        "ThisPC" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 1 -Force
        }
        "QuickAccess" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 2 -Force
        }
    }
}

<#
	.SYNOPSIS
	File Explorer mode

	.PARAMETER Disable
	Disable the File Explorer compact mode

	.PARAMETER Enable
	Enable the File Explorer compact mode

	.EXAMPLE
	FileExplorerCompactMode -Disable

	.EXAMPLE
	FileExplorerCompactMode -Enable

	.NOTES
	Current user
#>
function FileExplorerCompactMode {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name UseCompactMode -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name UseCompactMode -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Sync provider notification in File Explorer

	.PARAMETER Hide
	Do not show sync provider notification within File Explorer

	.PARAMETER Show
	Show sync provider notification within File Explorer

	.EXAMPLE
	OneDriveFileExplorerAd -Hide

	.EXAMPLE
	OneDriveFileExplorerAd -Show

	.NOTES
	Current user
#>
function OneDriveFileExplorerAd {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowSyncProviderNotifications -PropertyType DWord -Value 0 -Force
        }
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowSyncProviderNotifications -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Windows snapping

	.PARAMETER Disable
	When I snap a window, do not show what I can snap next to it

	.PARAMETER Enable
	When I snap a window, show what I can snap next to it

	.EXAMPLE
	SnapAssist -Disable

	.EXAMPLE
	SnapAssist -Enable

	.NOTES
	Current user
#>
function SnapAssist {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SnapAssist -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SnapAssist -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Snap layouts

	.PARAMETER Enable
	Show snap layouts when I hover over a windows's maximaze button

	.PARAMETER Disable
	Hide snap layouts when I hover over a windows's maximaze button

	.EXAMPLE
	SnapAssistFlyout -Enable

	.EXAMPLE
	SnapAssistFlyout -Disable

	.NOTES
	Current user
#>
function SnapAssistFlyout {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name EnableSnapAssistFlyout -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name EnableSnapAssistFlyout -PropertyType DWord -Value 0 -Force
        }
    }
}


<#
	.SYNOPSIS
	The file transfer dialog box mode

	.PARAMETER Detailed
	Show the file transfer dialog box in the detailed mode

	.PARAMETER Compact
	Show the file transfer dialog box in the compact mode

	.EXAMPLE
	FileTransferDialog -Detailed

	.EXAMPLE
	FileTransferDialog -Compact

	.NOTES
	Current user
#>
function FileTransferDialog {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Detailed"
        )]
        [switch]
        $Detailed,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Compact"
        )]
        [switch]
        $Compact
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Detailed" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager -Name EnthusiastMode -PropertyType DWord -Value 1 -Force
        }
        "Compact" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager -Name EnthusiastMode -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	The recycle bin files delete confirmation dialog

	.PARAMETER Enable
	Display the recycle bin files delete confirmation dialog

	.PARAMETER Disable
	Do not display the recycle bin files delete confirmation dialog

	.EXAMPLE
	RecycleBinDeleteConfirmation -Enable

	.EXAMPLE
	RecycleBinDeleteConfirmation -Disable

	.NOTES
	Current user
#>
function RecycleBinDeleteConfirmation {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable
    )

    $ShellState = Get-ItemPropertyValue -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name ShellState

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            $ShellState[4] = 51
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name ShellState -PropertyType Binary -Value $ShellState -Force
        }
        "Disable" {
            $ShellState[4] = 55
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name ShellState -PropertyType Binary -Value $ShellState -Force
        }
    }
}

<#
	.SYNOPSIS
	Recently used files in Quick access

	.PARAMETER Hide
	Hide recently used files in Quick access

	.PARAMETER Show
	Show recently used files in Quick access

	.EXAMPLE
	QuickAccessRecentFiles -Hide

	.EXAMPLE
	QuickAccessRecentFiles -Show

	.NOTES
	Current user
#>
function QuickAccessRecentFiles {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -PropertyType DWord -Value 0 -Force
        }
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Frequently used folders in Quick access

	.PARAMETER Hide
	Hide frequently used folders in Quick access

	.PARAMETER Show
	Show frequently used folders in Quick access

	.EXAMPLE
	QuickAccessFrequentFolders -Hide

	.EXAMPLE
	QuickAccessFrequentFolders -Show

	.NOTES
	Current user
#>
function QuickAccessFrequentFolders {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -PropertyType DWord -Value 0 -Force
        }
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Taskbar alignment

	.PARAMETER Left
	Set the taskbar alignment to the left

	.PARAMETER Center
	Set the taskbar alignment to the center

	.EXAMPLE
	TaskbarAlignment -Center

	.EXAMPLE
	TaskbarAlignment -Left

	.NOTES
	Current user
#>
function TaskbarAlignment {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Left"
        )]
        [switch]
        $Left,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Center"
        )]
        [switch]
        $Center
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Center" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarAl -PropertyType DWord -Value 1 -Force
        }
        "Left" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarAl -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	The search icon on the taskbar

	.PARAMETER Hide
	Hide the search icon on the taskbar

	.PARAMETER Show
	Show the search icon on the taskbar

	.EXAMPLE
	TaskbarSearch -Hide

	.EXAMPLE
	TaskbarSearch -Show

	.NOTES
	Current user
#>
function TaskbarSearch {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -PropertyType DWord -Value 0 -Force
        }
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Task view button on the taskbar

	.PARAMETER Hide
	Hide the Task view button on the taskbar

	.PARAMETER Show
	Show the Task View button on the taskbar

	.EXAMPLE
	TaskViewButton -Hide

	.EXAMPLE
	TaskViewButton -Show

	.NOTES
	Current user
#>
function TaskViewButton {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 0 -Force
        }
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	The widgets icon on the taskbar

	.PARAMETER Hide
	Hide the widgets icon on the taskbar

	.PARAMETER Show
	Show the widgets icon on the taskbar

	.EXAMPLE
	TaskbarWidgets -Hide

	.EXAMPLE
	TaskbarWidgets -Show

	.NOTES
	Current user
#>
function TaskbarWidgets {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            if (Get-AppxPackage -Name MicrosoftWindows.Client.WebExperience) {
                New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarDa -PropertyType DWord -Value 0 -Force
            }
        }
        "Show" {
            if (Get-AppxPackage -Name MicrosoftWindows.Client.WebExperience) {
                New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarDa -PropertyType DWord -Value 1 -Force
            }
        }
    }
}

<#
	.SYNOPSIS
	The Chat icon (Microsoft Teams) on the taskbar

	.PARAMETER Hide
	Hide the Chat icon (Microsoft Teams) on the taskbar

	.PARAMETER Show
	Show the Chat icon (Microsoft Teams) on the taskbar

	.EXAMPLE
	TaskbarChat -Hide

	.EXAMPLE
	TaskbarChat -Show

	.NOTES
	Current user
#>
function TaskbarChat {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Hide" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarMn -PropertyType DWord -Value 0 -Force
        }
        "Show" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarMn -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Unpin shortcuts from the taskbar

	.PARAMETER Edge
	Unpin the "Microsoft Edge" shortcut from the taskbar

	.PARAMETER Store
	Unpin the "Microsoft Store" shortcut from the taskbar

	.EXAMPLE
	UnpinTaskbarShortcuts -Shortcuts Edge, Store

	.NOTES
	Current user

	.LINK
	https://github.com/Disassembler0/Win10-Initial-Setup-Script/issues/8#issue-227159084
#>
function UnpinTaskbarShortcuts {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Edge", "Store")]
        [string[]]
        $Shortcuts
    )

    # Extract strings from shell32.dll using its' number
    $Signature = @{
        Namespace        = "WinAPI"
        Name             = "GetStr"
        Language         = "CSharp"
        MemberDefinition = @"
[DllImport("kernel32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr GetModuleHandle(string lpModuleName);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
internal static extern int LoadString(IntPtr hInstance, uint uID, StringBuilder lpBuffer, int nBufferMax);

public static string GetString(uint strId)
{
	IntPtr intPtr = GetModuleHandle("shell32.dll");
	StringBuilder sb = new StringBuilder(255);
	LoadString(intPtr, strId, sb, sb.Capacity);
	return sb.ToString();
}
"@
    }
    if (-not ("WinAPI.GetStr" -as [type])) {
        Add-Type @Signature -Using System.Text
    }

    # Extract the localized "Unpin from taskbar" string from shell32.dll
    $LocalizedString = [WinAPI.GetStr]::GetString(5387)

    foreach ($Shortcut in $Shortcuts) {
        switch ($Shortcut) {
            Edge {
                if (Test-Path -Path "$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk") {
                    # Call the shortcut context menu item
                    $Shell = (New-Object -ComObject Shell.Application).NameSpace("$env:AppData\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar")
                    $Shortcut = $Shell.ParseName("Microsoft Edge.lnk")
                    $Shortcut.Verbs() | Where-Object -FilterScript { $_.Name -eq $LocalizedString } | ForEach-Object -Process { $_.DoIt() }
                }
            }
            Store {
                # Start-Job is used due to that the calling this function before UninstallUWPApps breaks the retrieval of the localized UWP apps packages names
                if ((New-Object -ComObject Shell.Application).NameSpace("shell:::{4234d49b-0245-4df3-b780-3893943456e1}").Items() | Where-Object -FilterScript { $_.Path -eq "Microsoft.WindowsStore_8wekyb3d8bbwe!App" }) {
                    Start-Job -ScriptBlock {
                        $Apps = (New-Object -ComObject Shell.Application).NameSpace("shell:::{4234d49b-0245-4df3-b780-3893943456e1}").Items()
						($Apps | Where-Object -FilterScript { $_.Name -eq "Microsoft Store" }).Verbs() | Where-Object -FilterScript { $_.Name -eq $Using:LocalizedString } | ForEach-Object -Process { $_.DoIt() }
                    } | Receive-Job -Wait -AutoRemoveJob
                }
            }
        }
    }
}

<#
	.SYNOPSIS
	The Control Panel icons view

	.PARAMETER Category
	View the Control Panel icons by category

	.PARAMETER LargeIcons
	View the Control Panel icons by large icons

	.PARAMETER SmallIcons
	View the Control Panel icons by Small icons

	.EXAMPLE
	ControlPanelView -Category

	.EXAMPLE
	ControlPanelView -LargeIcons

	.EXAMPLE
	ControlPanelView -SmallIcons

	.NOTES
	Current user
#>
function ControlPanelView {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Category"
        )]
        [switch]
        $Category,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "LargeIcons"
        )]
        [switch]
        $LargeIcons,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "SmallIcons"
        )]
        [switch]
        $SmallIcons
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Category" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 0 -Force
        }
        "LargeIcons" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 1 -Force
        }
        "SmallIcons" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	The default Windows mode

	.PARAMETER Dark
	Set the default Windows mode to dark

	.PARAMETER Light
	Set the default Windows mode to light

	.EXAMPLE
	WindowsColorScheme -Dark

	.EXAMPLE
	WindowsColorScheme -Light

	.NOTES
	Current user
#>
function WindowsColorMode {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Dark"
        )]
        [switch]
        $Dark,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Light"
        )]
        [switch]
        $Light
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Dark" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -PropertyType DWord -Value 0 -Force
        }
        "Light" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	The default app mode

	.PARAMETER Dark
	Set the default app mode to dark

	.PARAMETER Light
	Set the default app mode to light

	.EXAMPLE
	AppColorMode -Dark

	.EXAMPLE
	AppColorMode -Light

	.NOTES
	Current user
#>
function AppColorMode {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Dark"
        )]
        [switch]
        $Dark,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Light"
        )]
        [switch]
        $Light
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Dark" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -PropertyType DWord -Value 0 -Force
        }
        "Light" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	First sign-in animation after the upgrade

	.PARAMETER Disable
	Disable first sign-in animation after the upgrade

	.PARAMETER Enable
	Enable first sign-in animation after the upgrade

	.EXAMPLE
	FirstLogonAnimation -Disable

	.EXAMPLE
	FirstLogonAnimation -Enable

	.NOTES
	Current user
#>
function FirstLogonAnimation {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name EnableFirstLogonAnimation -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name EnableFirstLogonAnimation -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	The quality factor of the JPEG desktop wallpapers

	.PARAMETER Max
	Set the quality factor of the JPEG desktop wallpapers to maximum

	.PARAMETER Default
	Set the quality factor of the JPEG desktop wallpapers to default

	.EXAMPLE
	JPEGWallpapersQuality -Max

	.EXAMPLE
	JPEGWallpapersQuality -Default

	.NOTES
	Current user
#>
function JPEGWallpapersQuality {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Max"
        )]
        [switch]
        $Max,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Max" {
            New-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name JPEGImportQuality -PropertyType DWord -Value 100 -Force
        }
        "Default" {
            Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name JPEGImportQuality -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	Notification when your PC requires a restart to finish updating

	.PARAMETER Show
	Notify me when a restart is required to finish updatingg

	.PARAMETER Hide
	Do not notify me when a restart is required to finish updating

	.EXAMPLE
	RestartNotification -Show

	.EXAMPLE
	RestartNotification -Hide

	.NOTES
	Machine-wide
#>
function RestartNotification {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Show"
        )]
        [switch]
        $Show,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Hide"
        )]
        [switch]
        $Hide
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Show" {
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name RestartNotificationsAllowed2 -PropertyType DWord -Value 1 -Force
        }
        "Hide" {
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name RestartNotificationsAllowed2 -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	The "- Shortcut" suffix adding to the name of the created shortcuts

	.PARAMETER Disable
	Do not add the "- Shortcut" suffix to the file name of created shortcuts

	.PARAMETER Enable
	Add the "- Shortcut" suffix to the file name of created shortcuts

	.EXAMPLE
	ShortcutsSuffix -Disable

	.EXAMPLE
	ShortcutsSuffix -Enable

	.NOTES
	Current user
#>
function ShortcutsSuffix {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates -Name ShortcutNameTemplate -PropertyType String -Value "%s.lnk" -Force
        }
        "Enable" {
            Remove-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\NamingTemplates -Name ShortcutNameTemplate -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	The Print screen button usage

	.PARAMETER Enable
	Use the Print screen button to open screen snipping

	.PARAMETER Disable
	Do not use the Print screen button to open screen snipping

	.EXAMPLE
	PrtScnSnippingTool -Enable

	.EXAMPLE
	PrtScnSnippingTool -Disable

	.NOTES
	Current user
#>
function PrtScnSnippingTool {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            New-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name PrintScreenKeyForSnippingEnabled -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name PrintScreenKeyForSnippingEnabled -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	A different input method for each app window

	.PARAMETER Enable
	Let me use a different input method for each app window

	.PARAMETER Disable
	Do not use a different input method for each app window

	.EXAMPLE
	AppsLanguageSwitch -Enable

	.EXAMPLE
	AppsLanguageSwitch -Disable

	.NOTES
	Current user
#>
function AppsLanguageSwitch {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            Set-WinLanguageBarOption -UseLegacySwitchMode
        }
        "Disable" {
            Set-WinLanguageBarOption
        }
    }
}

<#
	.SYNOPSIS
	Title bar window shake

	.PARAMETER Enable
	When I grab a windows's title bar and shake it, minimize all other windows

	.PARAMETER Disable
	When I grab a windows's title bar and shake it, don't minimize all other windows

	.EXAMPLE
	AeroShaking -Enable

	.EXAMPLE
	AeroShaking -Disable

	.NOTES
	Current user
#>
function AeroShaking {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Enable"
        )]
        [switch]
        $Enable,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Disable"
        )]
        [switch]
        $Disable
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name DisallowShaking -PropertyType DWord -Value 0 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name DisallowShaking -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Free "Windows 11 Cursors Concept v2" cursors from Jepri Creations

	.PARAMETER Dark
	Download and install free dark "Windows 11 Cursors Concept v2" cursors from Jepri Creations

	.PARAMETER Light
	Download and install free light "Windows 11 Cursors Concept v2" cursors from Jepri Creations

	.PARAMETER Default
	Set default cursors

	.EXAMPLE
	Cursors -Dark

	.EXAMPLE
	Cursors -Light

	.EXAMPLE
	Cursors -Default

	.LINK
	https://www.deviantart.com/jepricreations/art/Windows-11-Cursors-Concept-v2-886489356

	.NOTES
	The 09/09/22 version

	.NOTES
	Current user
#>
function Cursors {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Dark"
        )]
        [switch]
        $Dark,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Light"
        )]
        [switch]
        $Light,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Dark" {
            try {
                # Check the internet connection
                $Parameters = @{
                    Uri              = "https://www.google.com"
                    Method           = "Head"
                    DisableKeepAlive = $true
                    UseBasicParsing  = $true
                }
                if (-not (Invoke-WebRequest @Parameters).StatusDescription) {
                    return
                }

                try {
                    # Check whether https://github.com is alive
                    $Parameters = @{
                        Uri              = "https://github.com"
                        Method           = "Head"
                        DisableKeepAlive = $true
                        UseBasicParsing  = $true
                    }
                    if (-not (Invoke-WebRequest @Parameters).StatusDescription) {
                        return
                    }

                    $DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
                    $Parameters = @{
                        Uri             = "https://github.com/farag2/Sophia-Script-for-Windows/raw/master/Misc/Cursors.zip"
                        OutFile         = "$DownloadsFolder\Cursors.zip"
                        UseBasicParsing = $true
                        Verbose         = $true
                    }
                    Invoke-WebRequest @Parameters

                    if (-not (Test-Path -Path "$env:SystemRoot\Cursors\W11_dark_v2.2")) {
                        New-Item -Path "$env:SystemRoot\Cursors\W11_dark_v2.2" -ItemType Directory -Force
                    }

                    Add-Type -Assembly System.IO.Compression.FileSystem
                    $ZIP = [IO.Compression.ZipFile]::OpenRead("$DownloadsFolder\Cursors.zip")
                    $ZIP.Entries | Where-Object -FilterScript { $_.FullName -like "dark/*.*" } | ForEach-Object -Process {
                        [IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$env:SystemRoot\Cursors\W11_dark_v2.2\$($_.Name)", $true)
                    }
                    $ZIP.Dispose()

                    Remove-Item -Path "$DownloadsFolder\Cursors.zip" -Force

                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "(default)" -PropertyType String -Value "W11 Cursors Dark HD v2.2 by Jepri Creations" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name AppStarting -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\working.ani" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Arrow -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\pointer.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name ContactVisualization -PropertyType DWord -Value 1 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Crosshair -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\precision.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name CursorBaseSize -PropertyType DWord -Value 32 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name GestureVisualization -PropertyType DWord -Value 31 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Hand -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\link.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Help -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\help.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name IBeam -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\beam.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name No -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\unavailable.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name NWPen -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\handwriting.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Person -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\person.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Pin -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\pin.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name precisionhair -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\precision.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "Scheme Source" -PropertyType DWord -Value 1 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeAll -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\move.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNESW -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\dgn2.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNS -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\vert.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNWSE -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\dgn1.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeWE -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\horz.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name UpArrow -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\alternate.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Wait -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\busy.ani" -Force
                    if (-not (Test-Path -Path "HKCU:\Control Panel\Cursors\Schemes")) {
                        New-Item -Path "HKCU:\Control Panel\Cursors\Schemes" -Force
                    }
                    [string[]]$Schemes = (
                        "%SystemRoot%\Cursors\W11_dark_v2.2\working.ani",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\pointer.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\precision.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\link.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\help.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\beam.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\unavailable.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\handwriting.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\pin.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\person.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\move.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\dgn2.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\vert.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\dgn1.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\horz.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\alternate.cur",
                        "%SystemRoot%\Cursors\W11_dark_v2.2\busy.ani"
                    ) -join ","
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors\Schemes" -Name "W11 Cursors Dark HD v2.2 by Jepri Creations" -PropertyType String -Value $Schemes -Force
                }
                catch [System.Net.WebException] {
                    Write-Warning -Message ($Localization.NoResponse -f "https://github.com")
                    Write-Error -Message ($Localization.NoResponse -f "https://github.com") -ErrorAction SilentlyContinue

                    Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
                }
            }
            catch [System.Net.WebException] {
                Write-Warning -Message $Localization.NoInternetConnection
                Write-Error -Message $Localization.NoInternetConnection -ErrorAction SilentlyContinue

                Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
            }
        }
        "Light" {
            try {
                # Check the internet connection
                $Parameters = @{
                    Uri              = "https://www.google.com"
                    Method           = "Head"
                    DisableKeepAlive = $true
                    UseBasicParsing  = $true
                }
                if (-not (Invoke-WebRequest @Parameters).StatusDescription) {
                    return
                }

                try {
                    # Check whether https://github.com is alive
                    $Parameters = @{
                        Uri              = "https://github.com"
                        Method           = "Head"
                        DisableKeepAlive = $true
                        UseBasicParsing  = $true
                    }
                    if (-not (Invoke-WebRequest @Parameters).StatusDescription) {
                        return
                    }

                    $DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
                    $Parameters = @{
                        Uri             = "https://github.com/farag2/Sophia-Script-for-Windows/raw/master/Misc/Cursors.zip"
                        OutFile         = "$DownloadsFolder\Cursors.zip"
                        UseBasicParsing = $true
                        Verbose         = $true
                    }
                    Invoke-WebRequest @Parameters

                    if (-not (Test-Path -Path "$env:SystemRoot\Cursors\W11_light_v2.2")) {
                        New-Item -Path "$env:SystemRoot\Cursors\W11_light_v2.2" -ItemType Directory -Force
                    }

                    Add-Type -Assembly System.IO.Compression.FileSystem
                    $ZIP = [IO.Compression.ZipFile]::OpenRead("$DownloadsFolder\Cursors.zip")
                    $ZIP.Entries | Where-Object -FilterScript { $_.FullName -like "light/*.*" } | ForEach-Object -Process {
                        [IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$env:SystemRoot\Cursors\W11_light_v2.2\$($_.Name)", $true)
                    }
                    $ZIP.Dispose()

                    Remove-Item -Path "$DownloadsFolder\Cursors.zip" -Force

                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "(default)" -PropertyType String -Value "W11 Cursor Light HD v2.2 by Jepri Creations" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name AppStarting -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\working.ani" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Arrow -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\pointer.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name ContactVisualization -PropertyType DWord -Value 1 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Crosshair -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\precision.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name CursorBaseSize -PropertyType DWord -Value 32 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name GestureVisualization -PropertyType DWord -Value 31 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Hand -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\link.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Help -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\help.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name IBeam -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\beam.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name No -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\unavailable.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name NWPen -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\handwriting.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Person -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\person.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Pin -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\pin.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name precisionhair -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\precision.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "Scheme Source" -PropertyType DWord -Value 1 -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeAll -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\move.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNESW -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\dgn2.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNS -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\vert.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNWSE -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\dgn1.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeWE -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\horz.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name UpArrow -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\alternate.cur" -Force
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Wait -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_light_v2.2\busy.ani" -Force
                    if (-not (Test-Path -Path "HKCU:\Control Panel\Cursors\Schemes")) {
                        New-Item -Path "HKCU:\Control Panel\Cursors\Schemes" -Force
                    }
                    [string[]]$Schemes = (
                        "%SystemRoot%\Cursors\W11_light_v2.2\working.ani",
                        "%SystemRoot%\Cursors\W11_light_v2.2\pointer.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\precision.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\link.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\help.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\beam.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\unavailable.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\handwriting.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\pin.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\person.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\move.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\dgn2.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\vert.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\dgn1.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\horz.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\alternate.cur",
                        "%SystemRoot%\Cursors\W11_light_v2.2\busy.ani"
                    ) -join ","
                    New-ItemProperty -Path "HKCU:\Control Panel\Cursors\Schemes" -Name "W11 Cursor Light HD v2.2 by Jepri Creations" -PropertyType String -Value $Schemes -Force
                }
                catch [System.Net.WebException] {
                    Write-Warning -Message ($Localization.NoResponse -f "https://github.com")
                    Write-Error -Message ($Localization.NoResponse -f "https://github.com") -ErrorAction SilentlyContinue

                    Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
                }
            }
            catch [System.Net.WebException] {
                Write-Warning -Message $Localization.NoInternetConnection
                Write-Error -Message $Localization.NoInternetConnection -ErrorAction SilentlyContinue

                Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
            }
        }
        "Default" {
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "(default)" -PropertyType String -Value "W11 Cursors Dark HD v2.2 by Jepri Creations" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name AppStarting -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_working.ani" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Arrow -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_arrow.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name ContactVisualization -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Crosshair -PropertyType ExpandString -Value "" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name CursorBaseSize -PropertyType DWord -Value 32 -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name GestureVisualization -PropertyType DWord -Value 31 -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Hand -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_link.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Help -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_helpsel.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name IBeam -PropertyType ExpandString -Value "" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name No -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_unavail.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name NWPen -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_pen.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Person -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_person.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Pin -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_pin.cur" -Force
            Remove-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name precisionhair -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name "Scheme Source" -PropertyType DWord -Value 2 -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeAll -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_move.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNESW -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_nesw.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNS -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_ns.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeNWSE -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_nwse.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name SizeWE -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_ew.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name UpArrow -PropertyType ExpandString -Value "%SystemRoot%\Cursors\W11_dark_v2.2\alternate.cur" -Force
            New-ItemProperty -Path "HKCU:\Control Panel\Cursors" -Name Wait -PropertyType ExpandString -Value "%SystemRoot%\cursors\aero_up.cur" -Force
        }
    }

    # Reload cursor on-the-fly
    $Signature = @{
        Namespace        = "WinAPI"
        Name             = "SystemParamInfo"
        Language         = "CSharp"
        MemberDefinition = @"
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint pvParam, uint fWinIni);
"@
    }
    if (-not ("WinAPI.SystemParamInfo" -as [type])) {
        Add-Type @Signature
    }
    [WinAPI.SystemParamInfo]::SystemParametersInfo(0x0057, 0, $null, 0)
}

<#
	.SYNOPSIS
	Files and folders grouping

	.PARAMETER None
	Do not group files and folder

	.PARAMETER Default
	Group files and folder by date modified (default value)

	.EXAMPLE
	FolderGroupBy -None

	.EXAMPLE
	FolderGroupBy -Default

	.NOTES
	Current user
#>
function FolderGroupBy {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "None"
        )]
        [switch]
        $None,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "None" {
            # Clear any Common Dialog views
            Get-ChildItem -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\*\Shell" -Recurse | Where-Object -FilterScript { $_.PSChildName -eq "{885A186E-A440-4ADA-812B-DB871B942259}" } | Remove-Item -Force

            if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}\TopViews\{00000000-0000-0000-0000-000000000000}")) {
                New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}\TopViews\{00000000-0000-0000-0000-000000000000}" -Force
            }
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}\TopViews\{00000000-0000-0000-0000-000000000000}" -Name ColumnList -PropertyType String -Value "prop:0(34)System.ItemNameDisplay;0System.DateModified;0System.ItemTypeText;0System.Size;1System.DateCreated;1System.Author;1System.Category;1System.Keywords;1System.Title" -Force
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}\TopViews\{00000000-0000-0000-0000-000000000000}" -Name LogicalViewMode -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}\TopViews\{00000000-0000-0000-0000-000000000000}" -Name Name -PropertyType String -Value NoName -Force
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}\TopViews\{00000000-0000-0000-0000-000000000000}" -Name Order -PropertyType DWord -Value 0 -Force
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}\TopViews\{00000000-0000-0000-0000-000000000000}" -Name SortByList -PropertyType String -Value "prop:System.ItemNameDisplay" -Force
        }
        "Default" {
            Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\{885a186e-a440-4ada-812b-db871b942259}" -Recurse -Force -ErrorAction Ignore
        }
    }
}
#endregion UI & Personalization