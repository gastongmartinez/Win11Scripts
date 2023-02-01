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
    
    winget uninstall "Microsoft OneDrive" --silent --accept-package-agreements
    winget uninstall "Cortana" --silent --accept-package-agreements
    winget uninstall "Microsoft 365 (Office)" --silent --accept-package-agreements
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

function UserFolder {
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
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -PropertyType DWord -Value 0 -Force
        }
        "Hide" {
            Remove-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Force -ErrorAction Ignore
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

#region System
#region StorageSense
<#
	.SYNOPSIS
	Storage Sense

	.PARAMETER Enable
	Turn on Storage Sense

	.PARAMETER Disable
	Turn off Storage Sense

	.EXAMPLE
	StorageSense -Enable

	.EXAMPLE
	StorageSense -Disable

	.NOTES
	Current user
#>
function StorageSense {
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
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -ItemType Directory -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 01 -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy)) {
                New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -ItemType Directory -Force
            }
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 01 -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Clean up of temporary files

	.PARAMETER Enable
	Turn on automatic cleaning up temporary system and app files

	.PARAMETER Disable
	Turn off automatic cleaning up temporary system and app files

	.EXAMPLE
	StorageSenseTempFiles -Enable

	.EXAMPLE
	StorageSenseTempFiles -Disable

	.NOTES
	Current user
#>
function StorageSenseTempFiles {
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
            if ((Get-ItemPropertyValue -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 01) -eq "1") {
                New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 04 -PropertyType DWord -Value 1 -Force
            }
        }
        "Disable" {
            if ((Get-ItemPropertyValue -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 01) -eq "1") {
                New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 04 -PropertyType DWord -Value 0 -Force
            }
        }
    }
}

<#
	.SYNOPSIS
	Storage Sense running frequency

	.PARAMETER Month
	Run Storage Sense every month

	.PARAMETER Default
	Run Storage Sense during low free disk space

	.EXAMPLE
	StorageSenseFrequency -Month

	.EXAMPLE
	StorageSenseFrequency -Default

	.NOTES
	Current user
#>
function StorageSenseFrequency {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Month"
        )]
        [switch]
        $Month,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Month" {
            if ((Get-ItemPropertyValue -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 01) -eq "1") {
                New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 2048 -PropertyType DWord -Value 30 -Force
            }
        }
        "Default" {
            if ((Get-ItemPropertyValue -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 01) -eq "1") {
                New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy -Name 2048 -PropertyType DWord -Value 0 -Force
            }
        }
    }
}

#endregion StorageSense

<#
	.SYNOPSIS
	Hibernation

	.PARAMETER Disable
	Disable hibernation

	.PARAMETER Enable
	Enable hibernation

	.EXAMPLE
	Hibernation -Enable

	.EXAMPLE
	Hibernation -Disable

	.NOTES
	Do not recommend turning it off on laptops

	.NOTES
	Current user
#>
function Hibernation {
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
            POWERCFG /HIBERNATE OFF
        }
        "Enable" {
            POWERCFG /HIBERNATE ON
        }
    }
}

<#
	.SYNOPSIS
	The %TEMP% environment variable path

	.PARAMETER SystemDrive
	Change the %TEMP% environment variable path to %SystemDrive%\Temp

	.PARAMETER Default
	Change the %TEMP% environment variable path to %LOCALAPPDATA%\Temp

	.EXAMPLE
	TempFolder -SystemDrive

	.EXAMPLE
	TempFolder -Default

	.NOTES
	Machine-wide
#>
function TempFolder {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "SystemDrive"
        )]
        [switch]
        $SystemDrive,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "SystemDrive" {
            # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
            if ((Get-Item -Path $env:TEMP).FullName -eq "$env:SystemDrive\Temp") {
                return
            }

            # Restart the Printer Spooler service (Spooler)
            Restart-Service -Name Spooler -Force

            # Stop OneDrive processes
            Stop-Process -Name OneDrive, FileCoAuth -Force -ErrorAction Ignore

            if (-not (Test-Path -Path $env:SystemDrive\Temp)) {
                New-Item -Path $env:SystemDrive\Temp -ItemType Directory -Force
            }

            # Cleaning up folders
            Remove-Item -Path $env:SystemRoot\Temp -Recurse -Force -ErrorAction Ignore
            Get-Item -Path $env:TEMP -Force | Where-Object -FilterScript { $_.LinkType -ne "SymbolicLink" } | Remove-Item -Recurse -Force -ErrorAction Ignore

            if (-not (Test-Path -Path $env:LOCALAPPDATA\Temp)) {
                New-Item -Path $env:LOCALAPPDATA\Temp -ItemType Directory -Force
            }

            # If there are some files or folders left in %LOCALAPPDATA\Temp%
            if ((Get-ChildItem -Path $env:TEMP -Force -ErrorAction Ignore | Measure-Object).Count -ne 0) {
                # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexa
                # The system does not move the file until the operating system is restarted
                # The system moves the file immediately after AUTOCHK is executed, but before creating any paging files
                $Signature = @{
                    Namespace        = "WinAPI"
                    Name             = "DeleteFiles"
                    Language         = "CSharp"
                    MemberDefinition = @"
public enum MoveFileFlags
{
	MOVEFILE_DELAY_UNTIL_REBOOT = 0x00000004
}

[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, MoveFileFlags dwFlags);

public static bool MarkFileDelete (string sourcefile)
{
	return MoveFileEx(sourcefile, null, MoveFileFlags.MOVEFILE_DELAY_UNTIL_REBOOT);
}
"@
                }

                if (-not ("WinAPI.DeleteFiles" -as [type])) {
                    Add-Type @Signature
                }

                try {
                    Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction Ignore | Remove-Item -Recurse -Force -ErrorAction Stop
                }
                catch {
                    # If files are in use remove them at the next boot
                    Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction Ignore | ForEach-Object -Process { [WinAPI.DeleteFiles]::MarkFileDelete($_.FullName) }
                }

                $SymbolicLinkTask = @"
Get-ChildItem -Path `$env:LOCALAPPDATA\Temp -Recurse -Force | Remove-Item -Recurse -Force

Get-Item -Path `$env:LOCALAPPDATA\Temp -Force | Where-Object -FilterScript {`$_.LinkType -ne """SymbolicLink"""} | Remove-Item -Recurse -Force
New-Item -Path `$env:LOCALAPPDATA\Temp -ItemType SymbolicLink -Value `$env:SystemDrive\Temp -Force

Unregister-ScheduledTask -TaskName SymbolicLink -Confirm:`$false
"@

                # Create a temporary scheduled task to create a symbolic link to the %SystemDrive%\Temp folder
                $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-WindowStyle Hidden -Command $SymbolicLinkTask"
                $Trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
                $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8
                $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
                $Parameters = @{
                    TaskName  = "SymbolicLink"
                    Principal = $Principal
                    Action    = $Action
                    Settings  = $Settings
                    Trigger   = $Trigger
                }
                Register-ScheduledTask @Parameters -Force
            }
            else {
                # Create a symbolic link to the %SystemDrive%\Temp folder
                New-Item -Path $env:LOCALAPPDATA\Temp -ItemType SymbolicLink -Value $env:SystemDrive\Temp -Force
            }

            # Change the %TEMP% environment variable path to %LOCALAPPDATA%\Temp
            # The additional registry key creating are needed to fix the property type of the keys: SetEnvironmentVariable creates them with the "String" type instead of "ExpandString" as by default
            [Environment]::SetEnvironmentVariable("TMP", "$env:SystemDrive\Temp", "User")
            [Environment]::SetEnvironmentVariable("TMP", "$env:SystemDrive\Temp", "Machine")
            [Environment]::SetEnvironmentVariable("TMP", "$env:SystemDrive\Temp", "Process")
            New-ItemProperty -Path HKCU:\Environment -Name TMP -PropertyType ExpandString -Value $env:SystemDrive\Temp -Force

            [Environment]::SetEnvironmentVariable("TEMP", "$env:SystemDrive\Temp", "User")
            [Environment]::SetEnvironmentVariable("TEMP", "$env:SystemDrive\Temp", "Machine")
            [Environment]::SetEnvironmentVariable("TEMP", "$env:SystemDrive\Temp", "Process")
            New-ItemProperty -Path HKCU:\Environment -Name TEMP -PropertyType ExpandString -Value $env:SystemDrive\Temp -Force

            New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name TMP -PropertyType ExpandString -Value $env:SystemDrive\Temp -Force
        }
        "Default" {
            # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
            if ((Get-Item -Path $env:TEMP).FullName -eq "$env:LOCALAPPDATA\Temp") {
                return
            }

            # Restart the Printer Spooler service (Spooler)
            Restart-Service -Name Spooler -Force

            # Stop OneDrive processes
            Stop-Process -Name OneDrive, FileCoAuth -Force -ErrorAction Ignore

            # Remove a symbolic link to the %SystemDrive%\Temp folder
            if (Get-Item -Path $env:LOCALAPPDATA\Temp -Force -ErrorAction Ignore | Where-Object -FilterScript { $_.LinkType -eq "SymbolicLink" }) {
				(Get-Item -Path $env:LOCALAPPDATA\Temp -Force).Delete()
            }

            if (-not (Test-Path -Path $env:SystemRoot\Temp)) {
                New-Item -Path $env:SystemRoot\Temp -ItemType Directory -Force
            }
            if (-not (Test-Path -Path $env:LOCALAPPDATA\Temp)) {
                New-Item -Path $env:LOCALAPPDATA\Temp -ItemType Directory -Force
            }

            # Removing folders
            # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
            Remove-Item -Path $((Get-Item -Path $env:TEMP).FullName) -Recurse -Force -ErrorAction Ignore

            if ((Get-ChildItem -Path $env:TEMP -Force -ErrorAction Ignore | Measure-Object).Count -ne 0) {
                # https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexa
                # The system does not move the file until the operating system is restarted
                # The system moves the file immediately after AUTOCHK is executed, but before creating any paging files
                $Signature = @{
                    Namespace        = "WinAPI"
                    Name             = "DeleteFiles"
                    Language         = "CSharp"
                    MemberDefinition = @"
public enum MoveFileFlags
{
	MOVEFILE_DELAY_UNTIL_REBOOT = 0x00000004
}

[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, MoveFileFlags dwFlags);

public static bool MarkFileDelete (string sourcefile)
{
	return MoveFileEx(sourcefile, null, MoveFileFlags.MOVEFILE_DELAY_UNTIL_REBOOT);
}
"@
                }

                if (-not ("WinAPI.DeleteFiles" -as [type])) {
                    Add-Type @Signature
                }

                try {
                    # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
                    Remove-Item -Path $((Get-Item -Path $env:TEMP).FullName) -Recurse -Force -ErrorAction Stop
                }
                catch {
                    # If files are in use remove them at the next boot
                    Get-ChildItem -Path $env:TEMP -Recurse -Force | ForEach-Object -Process { [WinAPI.DeleteFiles]::MarkFileDelete($_.FullName) }
                }

                # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
                $TempFolder = (Get-Item -Path $env:TEMP).FullName
                $TempFolderCleanupTask = @"
Remove-Item -Path "$TempFolder" -Recurse -Force
Unregister-ScheduledTask -TaskName TemporaryTask -Confirm:`$false
"@

                # Create a temporary scheduled task to clean up the temporary folder
                $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-WindowStyle Hidden -Command $TempFolderCleanupTask"
                $Trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
                $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8
                $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
                $Parameters = @{
                    TaskName  = "TemporaryTask"
                    Principal = $Principal
                    Action    = $Action
                    Settings  = $Settings
                    Trigger   = $Trigger
                }
                Register-ScheduledTask @Parameters -Force
            }

            # Change the %TEMP% environment variable path to %LOCALAPPDATA%\Temp
            [Environment]::SetEnvironmentVariable("TMP", "$env:LOCALAPPDATA\Temp", "User")
            [Environment]::SetEnvironmentVariable("TMP", "$env:SystemRoot\TEMP", "Machine")
            [Environment]::SetEnvironmentVariable("TMP", "$env:LOCALAPPDATA\Temp", "Process")
            New-ItemProperty -Path HKCU:\Environment -Name TMP -PropertyType ExpandString -Value "%USERPROFILE%\AppData\Local\Temp" -Force

            [Environment]::SetEnvironmentVariable("TEMP", "$env:LOCALAPPDATA\Temp", "User")
            [Environment]::SetEnvironmentVariable("TEMP", "$env:SystemRoot\TEMP", "Machine")
            [Environment]::SetEnvironmentVariable("TEMP", "$env:LOCALAPPDATA\Temp", "Process")
            New-ItemProperty -Path HKCU:\Environment -Name TEMP -PropertyType ExpandString -Value "%USERPROFILE%\AppData\Local\Temp" -Force

            New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name TMP -PropertyType ExpandString -Value "%SystemRoot%\TEMP" -Force
            New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name TEMP -PropertyType ExpandString -Value "%SystemRoot%\TEMP" -Force
        }
    }
}

<#
	.SYNOPSIS
	The Windows 260 character path limit

	.PARAMETER Disable
	Disable the Windows 260 character path limit

	.PARAMETER Enable
	Enable the Windows 260 character path limit

	.EXAMPLE
	Win32LongPathLimit -Disable

	.EXAMPLE
	Win32LongPathLimit -Enable

	.NOTES
	Machine-wide
#>
function Win32LongPathLimit {
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
            New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -PropertyType DWord -Value 1 -Force
        }
        "Enable" {
            New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem -Name LongPathsEnabled -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Stop error code when BSoD occurs

	.PARAMETER Enable
	Display Stop error code when BSoD occurs

	.PARAMETER Disable
	Do not Stop error code when BSoD occurs

	.EXAMPLE
	BSoDStopError -Enable

	.EXAMPLE
	BSoDStopError -Disable

	.NOTES
	Machine-wide
#>
function BSoDStopError {
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
            New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name DisplayParameters -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name DisplayParameters -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	The User Account Control (UAC) behavior

	.PARAMETER Never
	Never notify

	.PARAMETER Default
	Notify me only when apps try to make changes to my computer

	.EXAMPLE
	AdminApprovalMode -Never

	.EXAMPLE
	AdminApprovalMode -Default

	.NOTES
	Machine-wide
#>
function AdminApprovalMode {
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
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Never" {
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -PropertyType DWord -Value 0 -Force
        }
        "Default" {
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -PropertyType DWord -Value 5 -Force
        }
    }
}

<#
	.SYNOPSIS
	Access to mapped drives from app running with elevated permissions with Admin Approval Mode enabled

	.PARAMETER Enable
	Turn on access to mapped drives from app running with elevated permissions with Admin Approval Mode enabled

	.PARAMETER Disable
	Turn off access to mapped drives from app running with elevated permissions with Admin Approval Mode enabled

	.EXAMPLE
	MappedDrivesAppElevatedAccess -Enable

	.EXAMPLE
	MappedDrivesAppElevatedAccess -Disable

	.NOTES
	Machine-wide
#>
function MappedDrivesAppElevatedAccess {
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
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLinkedConnections -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableLinkedConnections -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	Delivery Optimization

	.PARAMETER Disable
	Turn off Delivery Optimization

	.PARAMETER Enable
	Turn on Delivery Optimization

	.EXAMPLE
	DeliveryOptimization -Disable

	.EXAMPLE
	DeliveryOptimization -Enable

	.NOTES
	Current user
#>
function DeliveryOptimization {
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
            New-ItemProperty -Path Registry::HKEY_USERS\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings -Name DownloadMode -PropertyType DWord -Value 0 -Force
            Delete-DeliveryOptimizationCache -Force
        }
        "Enable" {
            New-ItemProperty -Path Registry::HKEY_USERS\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings -Name DownloadMode -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	The Group Policy processing

	.PARAMETER Enable
	Always wait for the network at computer startup and logon for workgroup networks

	.PARAMETER Disable
	Never wait for the network at computer startup and logon for workgroup networks

	.EXAMPLE
	WaitNetworkStartup -Enable

	.EXAMPLE
	WaitNetworkStartup -Disable

	.NOTES
	Machine-wide
#>
function WaitNetworkStartup {
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
            if ((Get-CimInstance -ClassName CIM_ComputerSystem).PartOfDomain) {
                if (-not (Test-Path -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon")) {
                    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Force
                }
                New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name SyncForegroundPolicy -PropertyType DWord -Value 1 -Force
                Set-Policy -Scope Computer -Path "SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name SyncForegroundPolicy -Type DWORD -Value 1
            }
        }
        "Disable" {
            if ((Get-CimInstance -ClassName CIM_ComputerSystem).PartOfDomain) {
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name SyncForegroundPolicy -Force -ErrorAction Ignore
                Set-Policy -Scope Computer -Path "SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name SyncForegroundPolicy -Type CLEAR
            }
        }
    }
}

<#
	.SYNOPSIS
	Windows manages my default printer

	.PARAMETER Disable
	Do not let Windows manage my default printer

	.PARAMETER Enable
	Let Windows manage my default printer

	.EXAMPLE
	WindowsManageDefaultPrinter -Disable

	.EXAMPLE
	WindowsManageDefaultPrinter -Enable

	.NOTES
	Current user
#>
function WindowsManageDefaultPrinter {
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
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 1 -Force
        }
        "Enable" {
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Windows features

	.PARAMETER Disable
	Disable Windows features

	.PARAMETER Enable
	Enable Windows features

	.EXAMPLE
	WindowsFeatures -Disable

	.EXAMPLE
	WindowsFeatures -Enable

	.NOTES
	A pop-up dialog box lets a user select features

	.NOTES
	Current user
#>
function WindowsFeatures {
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
    # Initialize an array list to store the selected Windows features
    $SelectedFeatures = New-Object -TypeName System.Collections.ArrayList($null)

    # The following Windows features will have their checkboxes checked
    [string[]]$CheckedFeatures = @(
        # Legacy Components
        "LegacyComponents",

        # PowerShell 2.0
        "MicrosoftWindowsPowerShellV2",
        "MicrosoftWindowsPowershellV2Root",

        # Microsoft XPS Document Writer
        "Printing-XPSServices-Features",

        # Work Folders Client
        "WorkFolders-Client"
    )

    # The following Windows features will have their checkboxes unchecked
    [string[]]$UncheckedFeatures = @(
        # Media Features
        # If you want to leave "Multimedia settings" in the advanced settings of Power Options do not disable this feature
        "MediaPlayback"
    )
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

        $Feature = $Features | Where-Object -FilterScript { $_.DisplayName -eq $CheckBox.Parent.Children[1].Text }

        if ($CheckBox.IsChecked) {
            [void]$SelectedFeatures.Add($Feature)
        }
        else {
            [void]$SelectedFeatures.Remove($Feature)
        }
        if ($SelectedFeatures.Count -gt 0) {
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

        $SelectedFeatures | ForEach-Object -Process { Write-Verbose $_.DisplayName -Verbose }
        $SelectedFeatures | Disable-WindowsOptionalFeature -Online -NoRestart
    }

    function EnableButton {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        [void]$Window.Close()

        $SelectedFeatures | ForEach-Object -Process { Write-Verbose -Message $_.DisplayName -Verbose }
        $SelectedFeatures | Enable-WindowsOptionalFeature -Online -NoRestart
    }

    function Add-FeatureControl {
        [CmdletBinding()]
        param
        (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [ValidateNotNull()]
            $Feature
        )

        process {
            $CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
            $CheckBox.Add_Click({ Get-CheckboxClicked -CheckBox $_.Source })
            $CheckBox.ToolTip = $Feature.Description

            $TextBlock = New-Object -TypeName System.Windows.Controls.TextBlock
            $TextBlock.Text = $Feature.DisplayName
            $TextBlock.ToolTip = $Feature.Description

            $StackPanel = New-Object -TypeName System.Windows.Controls.StackPanel
            [void]$StackPanel.Children.Add($CheckBox)
            [void]$StackPanel.Children.Add($TextBlock)
            [void]$PanelContainer.Children.Add($StackPanel)

            $CheckBox.IsChecked = $true

            # If feature checked add to the array list
            if ($UnCheckedFeatures | Where-Object -FilterScript { $Feature.FeatureName -like $_ }) {
                $CheckBox.IsChecked = $false
                # Exit function if item is not checked
                return
            }

            # If feature checked add to the array list
            [void]$SelectedFeatures.Add($Feature)
        }
    }
    #endregion Functions

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            $State = @("Disabled", "DisablePending")
            $ButtonContent = $Localization.Enable
            $ButtonAdd_Click = { EnableButton }
        }
        "Disable" {
            $State = @("Enabled", "EnablePending")
            $ButtonContent = $Localization.Disable
            $ButtonAdd_Click = { DisableButton }
        }
    }

    Write-Information -MessageData "" -InformationAction Continue
    Write-Verbose -Message $Localization.Patient -Verbose

    # Getting list of all optional features according to the conditions
    $OFS = "|"
    $Features = Get-WindowsOptionalFeature -Online | Where-Object -FilterScript {
		($_.State -in $State) -and (($_.FeatureName -match $UncheckedFeatures) -or ($_.FeatureName -match $CheckedFeatures))
    } | ForEach-Object -Process { Get-WindowsOptionalFeature -FeatureName $_.FeatureName -Online }
    $OFS = " "

    if (-not ($Features)) {
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

    $Window.Add_Loaded({ $Features | Add-FeatureControl })
    $Button.Content = $ButtonContent
    $Button.Add_Click({ & $ButtonAdd_Click })

    $Window.Title = $Localization.WindowsFeaturesTitle

    # Force move the WPF form to the foreground
    $Window.Add_Loaded({ $Window.Activate() })
    $Form.ShowDialog() | Out-Null
}

<#
	.SYNOPSIS
	Optional features

	.PARAMETER Uninstall
	Uninstall optional features

	.PARAMETER Install
	Install optional features

	.EXAMPLE
	WindowsCapabilities -Uninstall

	.EXAMPLE
	WindowsCapabilities -Install

	.NOTES
	A pop-up dialog box lets a user select features

	.NOTES
	Current user
#>
function WindowsCapabilities {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Uninstall"
        )]
        [switch]
        $Uninstall,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Install"
        )]
        [switch]
        $Install
    )

    Add-Type -AssemblyName PresentationCore, PresentationFramework

    #region Variables
    # Initialize an array list to store the selected optional features
    $SelectedCapabilities = New-Object -TypeName System.Collections.ArrayList($null)

    # The following optional features will have their checkboxes checked
    [string[]]$CheckedCapabilities = @(
        # Steps Recorder
        "App.StepsRecorder*",

        # Microsoft Quick Assist
        "App.Support.QuickAssist*",

        # WordPad
        "Microsoft.Windows.WordPad*"
    )

    # The following optional features will have their checkboxes unchecked
    [string[]]$UncheckedCapabilities = @(
        # Internet Explorer mode
        "Browser.InternetExplorer*",

        # Math Recognizer
        "MathRecognizer*",

        # Windows Media Player
        # If you want to leave "Multimedia settings" element in the advanced settings of Power Options do not uninstall this feature
        "Media.WindowsMediaPlayer*",

        # OpenSSH Client
        "OpenSSH.Client*"
    )

    # The following optional features will be excluded from the display
    [string[]]$ExcludedCapabilities = @(
        # The DirectX Database to configure and optimize apps when multiple Graphics Adapters are present
        "DirectX.Configuration.Database*",

        # Language components
        "Language.*",

        # Notepad
        "Microsoft.Windows.Notepad*",

        # Mail, contacts, and calendar sync component
        "OneCoreUAP.OneSync*",

        # Windows PowerShell Intergrated Scripting Enviroment
        "Microsoft.Windows.PowerShell.ISE*",

        # Management of printers, printer drivers, and printer servers
        "Print.Management.Console*",

        # Features critical to Windows functionality
        "Windows.Client.ShellComponents*"
    )
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

        $Capability = $Capabilities | Where-Object -FilterScript { $_.DisplayName -eq $CheckBox.Parent.Children[1].Text }

        if ($CheckBox.IsChecked) {
            [void]$SelectedCapabilities.Add($Capability)
        }
        else {
            [void]$SelectedCapabilities.Remove($Capability)
        }

        if ($SelectedCapabilities.Count -gt 0) {
            $Button.IsEnabled = $true
        }
        else {
            $Button.IsEnabled = $false
        }
    }

    function UninstallButton {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        [void]$Window.Close()

        $SelectedCapabilities | ForEach-Object -Process { Write-Verbose -Message $_.DisplayName -Verbose }
        $SelectedCapabilities | Where-Object -FilterScript { $_.Name -in (Get-WindowsCapability -Online).Name } | Remove-WindowsCapability -Online

        if ([string]$SelectedCapabilities.Name -match "Browser.InternetExplorer") {
            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.RestartWarning
        }
    }

    function InstallButton {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        [void]$Window.Close()

        $SelectedCapabilities | ForEach-Object -Process { Write-Verbose -Message $_.DisplayName -Verbose }
        $SelectedCapabilities | Where-Object -FilterScript { $_.Name -in ((Get-WindowsCapability -Online).Name) } | Add-WindowsCapability -Online

        if ([string]$SelectedCapabilities.Name -match "Browser.InternetExplorer") {
            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.RestartWarning
        }
    }

    function Add-CapabilityControl {
        [CmdletBinding()]
        param
        (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [ValidateNotNull()]
            $Capability
        )

        process {
            $CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
            $CheckBox.Add_Click({ Get-CheckboxClicked -CheckBox $_.Source })
            $CheckBox.ToolTip = $Capability.Description

            $TextBlock = New-Object -TypeName System.Windows.Controls.TextBlock
            $TextBlock.Text = $Capability.DisplayName
            $TextBlock.ToolTip = $Capability.Description

            $StackPanel = New-Object -TypeName System.Windows.Controls.StackPanel
            [void]$StackPanel.Children.Add($CheckBox)
            [void]$StackPanel.Children.Add($TextBlock)
            [void]$PanelContainer.Children.Add($StackPanel)

            # If capability checked add to the array list
            if ($UnCheckedCapabilities | Where-Object -FilterScript { $Capability.Name -like $_ }) {
                $CheckBox.IsChecked = $false
                # Exit function if item is not checked
                return
            }

            # If capability checked add to the array list
            [void]$SelectedCapabilities.Add($Capability)
        }
    }
    #endregion Functions

    switch ($PSCmdlet.ParameterSetName) {
        "Install" {
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

                $State = "NotPresent"
                $ButtonContent = $Localization.Install
                $ButtonAdd_Click = { InstallButton }
            }
            catch [System.Net.WebException] {
                Write-Warning -Message $Localization.NoInternetConnection
                Write-Error -Message $Localization.NoInternetConnection -ErrorAction SilentlyContinue

                Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
            }
        }
        "Uninstall" {
            $State = "Installed"
            $ButtonContent = $Localization.Uninstall
            $ButtonAdd_Click = { UninstallButton }
        }
    }

    Write-Information -MessageData "" -InformationAction Continue
    Write-Verbose -Message $Localization.Patient -Verbose

    # Getting list of all capabilities according to the conditions
    $OFS = "|"
    $Capabilities = Get-WindowsCapability -Online | Where-Object -FilterScript {
		($_.State -eq $State) -and (($_.Name -match $UncheckedCapabilities) -or ($_.Name -match $CheckedCapabilities) -and ($_.Name -notmatch $ExcludedCapabilities))
    } | ForEach-Object -Process { Get-WindowsCapability -Name $_.Name -Online }
    $OFS = " "

    if (-not ($Capabilities)) {
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

    $Window.Add_Loaded({ $Capabilities | Add-CapabilityControl })
    $Button.Content = $ButtonContent
    $Button.Add_Click({ & $ButtonAdd_Click })

    $Window.Title = $Localization.OptionalFeaturesTitle

    # Force move the WPF form to the foreground
    $Window.Add_Loaded({ $Window.Activate() })
    $Form.ShowDialog() | Out-Null
}

<#
	.SYNOPSIS
	Receive updates for other Microsoft products

	.PARAMETER Enable
	Receive updates for other Microsoft products

	.PARAMETER Disable
	Do not receive updates for other Microsoft products

	.EXAMPLE
	UpdateMicrosoftProducts -Enable

	.EXAMPLE
	UpdateMicrosoftProducts -Disable

	.NOTES
	Current user
#>
function UpdateMicrosoftProducts {
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
			(New-Object -ComObject Microsoft.Update.ServiceManager).AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")
        }
        "Disable" {
            if (((New-Object -ComObject Microsoft.Update.ServiceManager).Services | Where-Object -FilterScript { $_.ServiceID -eq "7971f918-a847-4430-9279-4a52d1efe18d" }).IsDefaultAUService) {
				(New-Object -ComObject Microsoft.Update.ServiceManager).RemoveService("7971f918-a847-4430-9279-4a52d1efe18d")
            }
        }
    }
}

<#
	.SYNOPSIS
	Power plan

	.PARAMETER High
	Set power plan on "High performance"

	.PARAMETER Balanced
	Set power plan on "Balanced"

	.EXAMPLE
	PowerPlan -High

	.EXAMPLE
	PowerPlan -Balanced

	.NOTES
	It isn't recommended to turn on the "High performance" power plan on laptops

	.NOTES
	Current user
#>
function PowerPlan {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "High"
        )]
        [switch]
        $High,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Balanced"
        )]
        [switch]
        $Balanced
    )

    switch ($PSCmdlet.ParameterSetName) {
        "High" {
            POWERCFG /SETACTIVE SCHEME_MIN
        }
        "Balanced" {
            POWERCFG /SETACTIVE SCHEME_BALANCED
        }
    }
}

<#
	.SYNOPSIS
	Network adapters power management

	.PARAMETER Disable
	Do not allow the computer to turn off the network adapters to save power

	.PARAMETER Enable
	Allow the computer to turn off the network adapters to save power

	.EXAMPLE
	NetworkAdaptersSavePower -Disable

	.EXAMPLE
	NetworkAdaptersSavePower -Enable

	.NOTES
	Do not recommend turning it on on laptops

	.NOTES
	Current user
#>
function NetworkAdaptersSavePower {
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

    if (Get-NetAdapter -Physical | Where-Object -FilterScript { ($_.Status -eq "Up") -and $_.MacAddress }) {
        $PhysicalAdaptersStatusUp = @((Get-NetAdapter -Physical | Where-Object -FilterScript { ($_.Status -eq "Up") -and $_.MacAddress }).Name)
    }

    $Adapters = Get-NetAdapter -Physical | Where-Object -FilterScript { $_.MacAddress } | Get-NetAdapterPowerManagement | Where-Object -FilterScript { $_.AllowComputerToTurnOffDevice -ne "Unsupported" }

    switch ($PSCmdlet.ParameterSetName) {
        "Disable" {
            foreach ($Adapter in $Adapters) {
                $Adapter.AllowComputerToTurnOffDevice = "Disabled"
                $Adapter | Set-NetAdapterPowerManagement
            }
        }
        "Enable" {
            foreach ($Adapter in $Adapters) {
                $Adapter.AllowComputerToTurnOffDevice = "Enabled"
                $Adapter | Set-NetAdapterPowerManagement
            }
        }
    }

    # All network adapters are turned into "Disconnected" for few seconds, so we need to wait a bit to let them up
    # Otherwise functions below will indicate that there is no the Internet connection
    if ($PhysicalAdaptersStatusUp) {
        while
        (
            Get-NetAdapter -Physical -Name $PhysicalAdaptersStatusUp | Where-Object -FilterScript { ($_.Status -eq "Disconnected") -and $_.MacAddress }
        ) {
            Write-Verbose -Message $Localization.Patient -Verbose
            Start-Sleep -Seconds 2
        }
    }
}

<#
	.SYNOPSIS
	Override for default input method

	.PARAMETER English
	Override for default input method: English

	.PARAMETER Default
	Override for default input method: use language list

	.EXAMPLE
	InputMethod -English

	.EXAMPLE
	InputMethod -Default

	.NOTES
	Current user
#>
function InputMethod {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "English"
        )]
        [switch]
        $English,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "English" {
            Set-WinDefaultInputMethodOverride -InputTip "0409:00000409"
        }
        "Default" {
            Remove-ItemProperty -Path "HKCU:\Control Panel\International\User Profile" -Name InputMethodOverride -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	User folders location

	.PARAMETER Root
	Move user folders location to the root of any drive using the interactive menu

	.PARAMETER Custom
	Select folders for user folders location manually using a folder browser dialog

	.PARAMETER Default
	Change user folders location to the default values

	.EXAMPLE
	SetUserShellFolderLocation -Root

	.EXAMPLE
	SetUserShellFolderLocation -Custom

	.EXAMPLE
	SetUserShellFolderLocation -Default

	.NOTES
	User files or folders won't me moved to a new location

	.NOTES
	Current user
#>
function SetUserShellFolderLocation {

    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Root"
        )]
        [switch]
        $Root,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Custom"
        )]
        [switch]
        $Custom,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    <#
		.SYNOPSIS
		Change the location of the each user folder using SHSetKnownFolderPath function

		.PARAMETER RemoveDesktopINI
		The RemoveDesktopINI argument removes desktop.ini in the old user shell folder

		.EXAMPLE
		UserShellFolder -UserFolder Desktop -FolderPath "$env:SystemDrive:\Desktop" -RemoveDesktopINI

		.LINK
		https://docs.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetknownfolderpath

		.NOTES
		User files or folders won't me moved to a new location
	#>
    function UserShellFolder {
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory = $true)]
            [ValidateSet("Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos")]
            [string]
            $UserFolder,

            [Parameter(Mandatory = $true)]
            [string]
            $FolderPath,

            [Parameter(Mandatory = $false)]
            [switch]
            $RemoveDesktopINI
        )

        <#
			.SYNOPSIS
			Redirect user folders to a new location

			.EXAMPLE
			KnownFolderPath -KnownFolder Desktop -Path "$env:SystemDrive:\Desktop"
		#>
        function KnownFolderPath {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory = $true)]
                [ValidateSet("Desktop", "Documents", "Downloads", "Music", "Pictures", "Videos")]
                [string]
                $KnownFolder,

                [Parameter(Mandatory = $true)]
                [string]
                $Path
            )

            $KnownFolders = @{
                "Desktop"   = @("B4BFCC3A-DB2C-424C-B029-7FE99A87C641");
                "Documents" = @("FDD39AD0-238F-46AF-ADB4-6C85480369C7", "f42ee2d3-909f-4907-8871-4c22fc0bf756");
                "Downloads" = @("374DE290-123F-4565-9164-39C4925E467B", "7d83ee9b-2244-4e70-b1f5-5393042af1e4");
                "Music"     = @("4BD8D571-6D19-48D3-BE97-422220080E43", "a0c69a99-21c8-4671-8703-7934162fcf1d");
                "Pictures"  = @("33E28130-4E1E-4676-835A-98395C3BC3BB", "0ddd015d-b06c-45d5-8c4c-f59713854639");
                "Videos"    = @("18989B1D-99B5-455B-841C-AB7C74E4DDFC", "35286a68-3c57-41a1-bbb1-0eae73d76c95");
            }

            $Signature = @{
                Namespace        = "WinAPI"
                Name             = "KnownFolders"
                Language         = "CSharp"
                MemberDefinition = @"
[DllImport("shell32.dll")]
public extern static int SHSetKnownFolderPath(ref Guid folderId, uint flags, IntPtr token, [MarshalAs(UnmanagedType.LPWStr)] string path);
"@
            }
            if (-not ("WinAPI.KnownFolders" -as [type])) {
                Add-Type @Signature
            }

            foreach ($GUID in $KnownFolders[$KnownFolder]) {
                [WinAPI.KnownFolders]::SHSetKnownFolderPath([ref]$GUID, 0, 0, $Path)
            }
			(Get-Item -Path $Path -Force).Attributes = "ReadOnly"
        }

        $UserShellFoldersRegistryNames = @{
            "Desktop"   = "Desktop"
            "Documents" = "Personal"
            "Downloads" = "{374DE290-123F-4565-9164-39C4925E467B}"
            "Music"     = "My Music"
            "Pictures"  = "My Pictures"
            "Videos"    = "My Video"
        }

        $UserShellFoldersGUIDs = @{
            "Desktop"   = "{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}"
            "Documents" = "{F42EE2D3-909F-4907-8871-4C22FC0BF756}"
            "Downloads" = "{7D83EE9B-2244-4E70-B1F5-5393042AF1E4}"
            "Music"     = "{A0C69A99-21C8-4671-8703-7934162FCF1D}"
            "Pictures"  = "{0DDD015D-B06C-45D5-8C4C-F59713854639}"
            "Videos"    = "{35286A68-3C57-41A1-BBB1-0EAE73D76C95}"
        }

        # Contents of the hidden desktop.ini file for each type of user folders
        $DesktopINI = @{
            "Desktop"   = "",
            "[.ShellClassInfo]",
            "LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21769",
            "IconResource=%SystemRoot%\system32\imageres.dll,-183"
            "Documents" = "",
            "[.ShellClassInfo]",
            "LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21770",
            "IconResource=%SystemRoot%\system32\imageres.dll,-112",
            "IconFile=%SystemRoot%\system32\shell32.dll",
            "IconIndex=-235"
            "Downloads" = "",
            "[.ShellClassInfo]", "LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21798",
            "IconResource=%SystemRoot%\system32\imageres.dll,-184"
            "Music"     = "",
            "[.ShellClassInfo]", "LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21790",
            "InfoTip=@%SystemRoot%\system32\shell32.dll,-12689",
            "IconResource=%SystemRoot%\system32\imageres.dll,-108",
            "IconFile=%SystemRoot%\system32\shell32.dll", "IconIndex=-237"
            "Pictures"  = "",
            "[.ShellClassInfo]",
            "LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21779",
            "InfoTip=@%SystemRoot%\system32\shell32.dll,-12688",
            "IconResource=%SystemRoot%\system32\imageres.dll,-113",
            "IconFile=%SystemRoot%\system32\shell32.dll",
            "IconIndex=-236"
            "Videos"    = "",
            "[.ShellClassInfo]",
            "LocalizedResourceName=@%SystemRoot%\system32\shell32.dll,-21791",
            "InfoTip=@%SystemRoot%\system32\shell32.dll,-12690",
            "IconResource=%SystemRoot%\system32\imageres.dll,-189",
            "IconFile=%SystemRoot%\system32\shell32.dll", "IconIndex=-238"
        }

        # Determining the current user folder path
        $CurrentUserFolderPath = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name $UserShellFoldersRegistryNames[$UserFolder]
        if ($CurrentUserFolder -ne $FolderPath) {
            if ((Get-ChildItem -Path $CurrentUserFolderPath | Measure-Object).Count -ne 0) {
                Write-Error -Message ($Localization.UserShellFolderNotEmpty -f $CurrentUserFolderPath) -ErrorAction SilentlyContinue
            }

            # Creating a new folder if there is no one
            if (-not (Test-Path -Path $FolderPath)) {
                New-Item -Path $FolderPath -ItemType Directory -Force
            }

            # Removing old desktop.ini
            if ($RemoveDesktopINI.IsPresent) {
                Remove-Item -Path "$CurrentUserFolderPath\desktop.ini" -Force
            }

            KnownFolderPath -KnownFolder $UserFolder -Path $FolderPath
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name $UserShellFoldersGUIDs[$UserFolder] -PropertyType ExpandString -Value $FolderPath -Force

            # Save desktop.ini in the UTF-16 LE encoding
            Set-Content -Path "$FolderPath\desktop.ini" -Value $DesktopINI[$UserFolder] -Encoding Unicode -Force
			(Get-Item -Path "$FolderPath\desktop.ini" -Force).Attributes = "Hidden", "System", "Archive"
			(Get-Item -Path "$FolderPath\desktop.ini" -Force).Refresh()
        }
    }

    <#
		.SYNOPSIS
		The "Show menu" function with the up/down arrow keys and enter key to make a selection

		.EXAMPLE
		ShowMenu -Menu $ListOfItems -Default $DefaultChoice

		.LINK
		https://qna.habr.com/answer?answer_id=1522379
	#>
    function ShowMenu {
        [CmdletBinding()]
        param
        (
            [Parameter()]
            [string]
            $Title,

            [Parameter(Mandatory = $true)]
            [array]
            $Menu,

            [Parameter(Mandatory = $true)]
            [int]
            $Default
        )

        Write-Information -MessageData $Title -InformationAction Continue

        $minY = [Console]::CursorTop
        $y = [Math]::Max([Math]::Min($Default, $Menu.Count), 0)
        do {
            [Console]::CursorTop = $minY
            [Console]::CursorLeft = 0
            $i = 0
            foreach ($item in $Menu) {
                if ($i -ne $y) {
                    Write-Information -MessageData ('  {0}. {1}  ' -f ($i + 1), $item) -InformationAction Continue
                }
                else {
                    Write-Information -MessageData ('[ {0}. {1} ]' -f ($i + 1), $item) -InformationAction Continue
                }
                $i++
            }

            $k = [Console]::ReadKey()
            switch ($k.Key) {
                "UpArrow" {
                    if ($y -gt 0) {
                        $y--
                    }
                }
                "DownArrow" {
                    if ($y -lt ($Menu.Count - 1)) {
                        $y++
                    }
                }
                "Enter" {
                    return $Menu[$y]
                }
            }
        }
        while ($k.Key -notin ([ConsoleKey]::Escape, [ConsoleKey]::Enter))
    }

    # Get the localized user folders names
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

    # The localized user folders names
    $DesktopLocalizedString = [WinAPI.GetStr]::GetString(21769)
    $DocumentsLocalizedString = [WinAPI.GetStr]::GetString(21770)
    $DownloadsLocalizedString = [WinAPI.GetStr]::GetString(21798)
    $MusicLocalizedString = [WinAPI.GetStr]::GetString(21790)
    $PicturesLocalizedString = [WinAPI.GetStr]::GetString(21779)
    $VideosLocalizedString = [WinAPI.GetStr]::GetString(21791)

    switch ($PSCmdlet.ParameterSetName) {
        "Root" {
            Write-Information -MessageData "" -InformationAction Continue
            Write-Verbose -Message $Localization.RetrievingDrivesList -Verbose
            Write-Information -MessageData "" -InformationAction Continue

            # Store all drives letters to use them within ShowMenu function
            $DriveLetters = @((Get-Disk | Where-Object -FilterScript { $_.BusType -ne "USB" } | Get-Partition | Get-Volume | Where-Object -FilterScript { $null -ne $_.DriveLetter }).DriveLetter | Sort-Object)

            # If the number of disks is more than one, set the second drive in the list as default drive
            if ($DriveLetters.Count -gt 1) {
                $Script:Default = 1
            }
            else {
                $Script:Default = 0
            }

            # Desktop
            Write-Verbose -Message ($Localization.DriveSelect -f $DesktopLocalizedString) -Verbose

            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Desktop
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DesktopLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderRequest -f $DesktopLocalizedString
            $No = $Localization.No
            $Yes = $Localization.Yes
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    $SelectedDrive = ShowMenu -Title ($Localization.DriveSelect -f $DesktopLocalizedString) -Menu $DriveLetters -Default $Script:Default
                    UserShellFolder -UserFolder Desktop -FolderPath "${SelectedDrive}:\Desktop" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Documents
            Write-Verbose -Message ($Localization.DriveSelect -f $DocumentsLocalizedString) -Verbose

            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Personal
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DocumentsLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderRequest -f $DocumentsLocalizedString
            $No = $Localization.No
            $Yes = $Localization.Yes
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    $SelectedDrive = ShowMenu -Title ($Localization.DriveSelect -f $DocumentsLocalizedString) -Menu $DriveLetters -Default $Script:Default
                    UserShellFolder -UserFolder Documents -FolderPath "${SelectedDrive}:\Documents" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Downloads
            Write-Verbose -Message ($Localization.DriveSelect -f $DownloadsLocalizedString) -Verbose

            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DownloadsLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderRequest -f $DownloadsLocalizedString
            $No = $Localization.No
            $Yes = $Localization.Yes
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    $SelectedDrive = ShowMenu -Title ($Localization.DriveSelect -f $DownloadsLocalizedString) -Menu $DriveLetters -Default $Script:Default
                    UserShellFolder -UserFolder Downloads -FolderPath "${SelectedDrive}:\Downloads" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Music
            Write-Verbose -Message ($Localization.DriveSelect -f $MusicLocalizedString) -Verbose

            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Music"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $MusicLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderRequest -f $MusicLocalizedString
            $No = $Localization.No
            $Yes = $Localization.Yes
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    $SelectedDrive = ShowMenu -Title ($Localization.DriveSelect -f $MusicLocalizedString) -Menu $DriveLetters -Default $Script:Default
                    UserShellFolder -UserFolder Music -FolderPath "${SelectedDrive}:\Music" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Pictures
            Write-Verbose -Message ($Localization.DriveSelect -f $PicturesLocalizedString) -Verbose

            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Pictures"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $PicturesLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderRequest -f $PicturesLocalizedString
            $No = $Localization.No
            $Yes = $Localization.Yes
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    $SelectedDrive = ShowMenu -Title ($Localization.DriveSelect -f $PicturesLocalizedString) -Menu $DriveLetters -Default $Script:Default
                    UserShellFolder -UserFolder Pictures -FolderPath "${SelectedDrive}:\Pictures" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Videos
            Write-Verbose -Message ($Localization.DriveSelect -f $VideosLocalizedString) -Verbose

            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Video"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $VideosLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderRequest -f $VideosLocalizedString
            $No = $Localization.No
            $Yes = $Localization.Yes
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    $SelectedDrive = ShowMenu -Title ($Localization.DriveSelect -f $VideosLocalizedString) -Menu $DriveLetters -Default $Script:Default
                    UserShellFolder -UserFolder Videos -FolderPath "${SelectedDrive}:\Videos" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }
        }
        "Custom" {
            # Desktop
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Desktop
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DesktopLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderSelect -f $DesktopLocalizedString
            $Browse = $Localization.Browse
            $No = $Localization.No
            $Options = "&$Browse", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    Add-Type -AssemblyName System.Windows.Forms
                    $FolderBrowserDialog = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
                    $FolderBrowserDialog.Description = $Localization.FolderSelect
                    $FolderBrowserDialog.RootFolder = "MyComputer"

                    # Force move the open file dialog to the foreground
                    $Focus = New-Object -TypeName System.Windows.Forms.Form -Property @{TopMost = $true }
                    $FolderBrowserDialog.ShowDialog($Focus)

                    if ($FolderBrowserDialog.SelectedPath) {
                        UserShellFolder -UserFolder Desktop -FolderPath $FolderBrowserDialog.SelectedPath -RemoveDesktopINI
                        Write-Verbose -Message ($Localization.NewUserFolderLocation -f $FolderBrowserDialog.SelectedPath) -Verbose
                    }
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Documents
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Personal
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DocumentsLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderSelect -f $DocumentsLocalizedString
            $Browse = $Localization.Browse
            $No = $Localization.No
            $Options = "&$Browse", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    Add-Type -AssemblyName System.Windows.Forms
                    $FolderBrowserDialog = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
                    $FolderBrowserDialog.Description = $Localization.FolderSelect
                    $FolderBrowserDialog.RootFolder = "MyComputer"

                    # Force move the open file dialog to the foreground
                    $Focus = New-Object -TypeName System.Windows.Forms.Form -Property @{TopMost = $true }
                    $FolderBrowserDialog.ShowDialog($Focus)

                    if ($FolderBrowserDialog.SelectedPath) {
                        UserShellFolder -UserFolder Documents -FolderPath $FolderBrowserDialog.SelectedPath -RemoveDesktopINI
                        Write-Verbose -Message ($Localization.NewUserFolderLocation -f $FolderBrowserDialog.SelectedPath) -Verbose
                    }
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Downloads
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DownloadsLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderSelect -f $DownloadsLocalizedString
            $Browse = $Localization.Browse
            $No = $Localization.No
            $Options = "&$Browse", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    Add-Type -AssemblyName System.Windows.Forms
                    $FolderBrowserDialog = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
                    $FolderBrowserDialog.Description = $Localization.FolderSelect
                    $FolderBrowserDialog.RootFolder = "MyComputer"

                    # Force move the open file dialog to the foreground
                    $Focus = New-Object -TypeName System.Windows.Forms.Form -Property @{TopMost = $true }
                    $FolderBrowserDialog.ShowDialog($Focus)

                    if ($FolderBrowserDialog.SelectedPath) {
                        UserShellFolder -UserFolder Downloads -FolderPath $FolderBrowserDialog.SelectedPath -RemoveDesktopINI
                        Write-Verbose -Message ($Localization.NewUserFolderLocation -f $FolderBrowserDialog.SelectedPath) -Verbose
                    }
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Music
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Music"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $MusicLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderSelect -f $MusicLocalizedString
            $Browse = $Localization.Browse
            $No = $Localization.No
            $Options = "&$Browse", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    Add-Type -AssemblyName System.Windows.Forms
                    $FolderBrowserDialog = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
                    $FolderBrowserDialog.Description = $Localization.FolderSelect
                    $FolderBrowserDialog.RootFolder = "MyComputer"

                    # Force move the open file dialog to the foreground
                    $Focus = New-Object -TypeName System.Windows.Forms.Form -Property @{TopMost = $true }
                    $FolderBrowserDialog.ShowDialog($Focus)

                    if ($FolderBrowserDialog.SelectedPath) {
                        UserShellFolder -UserFolder Music -FolderPath $FolderBrowserDialog.SelectedPath -RemoveDesktopINI
                        Write-Verbose -Message ($Localization.NewUserFolderLocation -f $FolderBrowserDialog.SelectedPath) -Verbose
                    }
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Pictures
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Pictures"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $PicturesLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderSelect -f $PicturesLocalizedString
            $Browse = $Localization.Browse
            $No = $Localization.No
            $Options = "&$Browse", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    Add-Type -AssemblyName System.Windows.Forms
                    $FolderBrowserDialog = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
                    $FolderBrowserDialog.Description = $Localization.FolderSelect
                    $FolderBrowserDialog.RootFolder = "MyComputer"

                    # Force move the open file dialog to the foreground
                    $Focus = New-Object -TypeName System.Windows.Forms.Form -Property @{TopMost = $true }
                    $FolderBrowserDialog.ShowDialog($Focus)

                    if ($FolderBrowserDialog.SelectedPath) {
                        UserShellFolder -UserFolder Pictures -FolderPath $FolderBrowserDialog.SelectedPath -RemoveDesktopINI
                        Write-Verbose -Message ($Localization.NewUserFolderLocation -f $FolderBrowserDialog.SelectedPath) -Verbose
                    }
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Videos
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Video"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $VideosLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserFolderSelect -f $VideosLocalizedString
            $Browse = $Localization.Browse
            $No = $Localization.No
            $Options = "&$Browse", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    Add-Type -AssemblyName System.Windows.Forms
                    $FolderBrowserDialog = New-Object -TypeName System.Windows.Forms.FolderBrowserDialog
                    $FolderBrowserDialog.Description = $Localization.FolderSelect
                    $FolderBrowserDialog.RootFolder = "MyComputer"

                    # Force move the open file dialog to the foreground
                    $Focus = New-Object -TypeName System.Windows.Forms.Form -Property @{TopMost = $true }
                    $FolderBrowserDialog.ShowDialog($Focus)

                    if ($FolderBrowserDialog.SelectedPath) {
                        UserShellFolder -UserFolder Videos -FolderPath $FolderBrowserDialog.SelectedPath -RemoveDesktopINI
                        Write-Verbose -Message ($Localization.NewUserFolderLocation -f $FolderBrowserDialog.SelectedPath) -Verbose
                    }
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }
        }
        "Default" {
            # Desktop
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Desktop
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DesktopLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserDefaultFolder -f $DesktopLocalizedString
            $Yes = $Localization.Yes
            $No = $Localization.No
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    UserShellFolder -UserFolder Desktop -FolderPath "$env:USERPROFILE\Desktop" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Documents
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Personal
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DocumentsLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserDefaultFolder -f $DocumentsLocalizedString
            $Yes = $Localization.Yes
            $No = $Localization.No
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    UserShellFolder -UserFolder Documents -FolderPath "$env:USERPROFILE\Documents" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Downloads
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $DownloadsLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserDefaultFolder -f $DownloadsLocalizedString
            $Yes = $Localization.Yes
            $No = $Localization.No
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    UserShellFolder -UserFolder Downloads -FolderPath "$env:USERPROFILE\Downloads" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Music
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Music"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $MusicLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserDefaultFolder -f $MusicLocalizedString
            $Yes = $Localization.Yes
            $No = $Localization.No
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    UserShellFolder -UserFolder Music -FolderPath "$env:USERPROFILE\Music" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Pictures
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Pictures"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $PicturesLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserDefaultFolder -f $PicturesLocalizedString
            $Yes = $Localization.Yes
            $No = $Localization.No
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    UserShellFolder -UserFolder Pictures -FolderPath "$env:USERPROFILE\Pictures" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }

            # Videos
            $CurrentUserFolderLocation = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Video"
            Write-Verbose -Message ($Localization.CurrentUserFolderLocation -f $VideosLocalizedString, $CurrentUserFolderLocation) -Verbose

            Write-Information -MessageData "" -InformationAction Continue
            Write-Warning -Message $Localization.FilesWontBeMoved

            Write-Information -MessageData "" -InformationAction Continue

            $Title = ""
            $Message = $Localization.UserDefaultFolder -f $VideosLocalizedString
            $Yes = $Localization.Yes
            $No = $Localization.No
            $Options = "&$Yes", "&$No"
            $DefaultChoice = 1
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)

            switch ($Result) {
                "0" {
                    UserShellFolder -UserFolder Videos -FolderPath "$env:USERPROFILE\Videos" -RemoveDesktopINI
                }
                "1" {
                    Write-Verbose -Message $Localization.Skipped -Verbose
                    Write-Information -MessageData "" -InformationAction Continue
                }
            }
        }
    }
}

<#
	.SYNOPSIS
	The the latest installed .NET runtime for all apps usage

	.PARAMETER Enable
	Use the latest installed .NET runtime for all apps

	.PARAMETER Disable
	Do not use the latest installed .NET runtime for all apps

	.EXAMPLE
	LatestInstalled.NET -Enable

	.EXAMPLE
	LatestInstalled.NET -Disable

	.NOTES
	Machine-wide
#>
function LatestInstalled.NET {
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
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\.NETFramework -Name OnlyUseLatestCLR -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework -Name OnlyUseLatestCLR -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\.NETFramework -Name OnlyUseLatestCLR -Force -ErrorAction Ignore
            Remove-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework -Name OnlyUseLatestCLR -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	The location to save screenshots by pressing Win+PrtScr

	.PARAMETER Desktop
	Save screenshots by pressing Win+PrtScr on the Desktop

	.PARAMETER Default
	Save screenshots by pressing Win+PrtScr in the Pictures folder

	.EXAMPLE
	WinPrtScrFolder -Desktop

	.EXAMPLE
	WinPrtScrFolder -Default

	.NOTES
	The function will be applied only if the preset is configured to remove the OneDrive application, or the app was already uninstalled
	otherwise the backup functionality for the "Desktop" and "Pictures" folders in OneDrive breaks

	.NOTES
	Current user
#>
function WinPrtScrFolder {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Desktop"
        )]
        [switch]
        $Desktop,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Desktop" {
            # Check how the script was invoked: via a preset or Function.ps1
            $PresetName = (Get-PSCallStack).Position | Where-Object -FilterScript {
				(($_.File -match ".ps1") -and ($_.File -notmatch "Functions.ps1")) -and (($_.Text -eq "WinPrtScrFolder -Desktop") -or ($_.Text -match "Invoke-Expression"))
            }
            if ($null -ne $PresetName) {
                # Get the name of a preset (e.g Sophia.ps1) regardless it was named
                $PresetName = Split-Path -Path $PresetName.File -Leaf
                # Check whether a preset contains the "OneDrive -Uninstall" string uncommented out
                $OneDriveUninstallFunctionUncommented = (Get-Content -Path $PSScriptRoot\..\$PresetName -Encoding UTF8 -Force | Select-String -SimpleMatch "OneDrive -Uninstall").Line.StartsWith("#") -eq $false
                $OneDriveInstalled = Get-Package -Name "Microsoft OneDrive" -ProviderName Programs -Force -ErrorAction Ignore
                if ($OneDriveUninstallFunctionUncommented -or (-not $OneDriveInstalled)) {
                    $DesktopFolder = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Desktop
                    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}" -PropertyType ExpandString -Value $DesktopFolder -Force
                }
                else {
                    Write-Warning -Message ($Localization.OneDriveWarning -f $MyInvocation.Line)
                    Write-Error -Message ($Localization.OneDriveWarning -f $MyInvocation.Line) -ErrorAction SilentlyContinue
                }
            }
            else {
                # A preset file isn't taking a part so we ignore it and check only whether OneDrive was already uninstalled
                if (-not (Get-Package -Name "Microsoft OneDrive" -ProviderName Programs -Force -ErrorAction Ignore)) {
                    $DesktopFolder = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Desktop
                    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}" -PropertyType ExpandString -Value $DesktopFolder -Force
                }
                else {
                    Write-Warning -Message ($Localization.OneDriveWarning -f $MyInvocation.Line)
                    Write-Error -Message ($Localization.OneDriveWarning -f $MyInvocation.Line) -ErrorAction SilentlyContinue
                }
            }
        }
        "Default" {
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{B7BEDE81-DF94-4682-A7D8-57A52620B86F}" -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	Recommended troubleshooter preferences

	.PARAMETER Automatically
	Run troubleshooter automatically, then notify me

	.PARAMETER Default
	Ask me before running troubleshooter

	.EXAMPLE
	RecommendedTroubleshooting -Automatically

	.EXAMPLE
	RecommendedTroubleshooting -Default

	.NOTES
	In order this feature to work the OS level of diagnostic data gathering will be set to "Optional diagnostic data" and the error reporting feature will be turned on

	.NOTES
	Machine-wide
#>
function RecommendedTroubleshooting {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Automatically"
        )]
        [switch]
        $Automatically,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Automatically" {
            if (-not (Test-Path -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation)) {
                New-Item -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Force
            }
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Name UserPreference -PropertyType DWord -Value 3 -Force
        }
        "Default" {
            if (-not (Test-Path -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation)) {
                New-Item -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Force
            }
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Name UserPreference -PropertyType DWord -Value 2 -Force
        }
    }

    # Set the OS level of diagnostic data gathering to "Optional diagnostic data"
    if (-not (Test-Path -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack)) {
        New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Force
    }
    New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -PropertyType DWord -Value 3 -Force
    New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection -Name MaxTelemetryAllowed -PropertyType DWord -Value 3 -Force
    New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Name ShowedToastAtLevel -PropertyType DWord -Value 3 -Force
    Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Type DWORD -Value 1

    # Turn on Windows Error Reporting
    Get-ScheduledTask -TaskName QueueReporting | Enable-ScheduledTask
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Force -ErrorAction Ignore

    Get-Service -Name WerSvc | Set-Service -StartupType Manual
    Get-Service -Name WerSvc | Start-Service
}

<#
	.SYNOPSIS
	Folder windows launching in a separate process

	.PARAMETER Enable
	Launch folder windows in a separate process

	.PARAMETER Disable
	Do not launch folder windows in a separate process

	.EXAMPLE
	FoldersLaunchSeparateProcess -Enable

	.EXAMPLE
	FoldersLaunchSeparateProcess -Disable

	.NOTES
	Current user
#>
function FoldersLaunchSeparateProcess {
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
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Reserved storage

	.PARAMETER Disable
	Disable and delete reserved storage after the next update installation

	.PARAMETER Enable
	Enable reserved storage after the next update installation

	.EXAMPLE
	ReservedStorage -Disable

	.EXAMPLE
	ReservedStorage -Enable

	.NOTES
	Current user
#>
function ReservedStorage {
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
            try {
                Set-WindowsReservedStorageState -State Disabled
            }
            catch [System.Runtime.InteropServices.COMException] {
                Write-Error -Message ($Localization.ReservedStorageIsInUse -f $MyInvocation.Line) -ErrorAction SilentlyContinue
            }
        }
        "Enable" {
            Set-WindowsReservedStorageState -State Enabled
        }
    }
}

<#
	.SYNOPSIS
	Help look up via F1

	.PARAMETER Disable
	Disable help lookup via F1

	.PARAMETER Enable
	Enable help lookup via F1

	.EXAMPLE
	F1HelpPage -Disable

	.EXAMPLE
	F1HelpPage -Enable

	.NOTES
	Current user
#>
function F1HelpPage {
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
            if (-not (Test-Path -Path "HKCU:\Software\Classes\Typelib\{8cec5860-07a1-11d9-b15e-000d56bfe6ee}\1.0\0\win64")) {
                New-Item -Path "HKCU:\Software\Classes\Typelib\{8cec5860-07a1-11d9-b15e-000d56bfe6ee}\1.0\0\win64" -Force
            }
            New-ItemProperty -Path "HKCU:\Software\Classes\Typelib\{8cec5860-07a1-11d9-b15e-000d56bfe6ee}\1.0\0\win64" -Name "(default)" -PropertyType String -Value "" -Force
        }
        "Enable" {
            Remove-Item -Path "HKCU:\Software\Classes\Typelib\{8cec5860-07a1-11d9-b15e-000d56bfe6ee}" -Recurse -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	Num Lock at startup

	.PARAMETER Enable
	Enable Num Lock at startup

	.PARAMETER Disable
	Disable Num Lock at startup

	.EXAMPLE
	NumLock -Enable

	.EXAMPLE
	NumLock -Disable

	.NOTES
	Current user
#>
function NumLock {
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
            New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483650 -Force
        }
        "Disable" {
            New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483648 -Force
        }
    }
}

<#
	.SYNOPSIS
	Caps Lock

	.PARAMETER Disable
	Disable Caps Lock

	.PARAMETER Enable
	Enable Caps Lock

	.EXAMPLE
	CapsLock -Disable

	.EXAMPLE
	CapsLock -Enable

	.NOTES
	Machine-wide
#>
function CapsLock {
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
            New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -PropertyType Binary -Value ([byte[]](0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 58, 0, 0, 0, 0, 0)) -Force
        }
        "Enable" {
            Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -Force -ErrorAction Ignore
        }
    }
}

<#
	.SYNOPSIS
	The shortcut to start Sticky Keys

	.PARAMETER Disable
	Turn off Sticky keys by pressing the Shift key 5 times

	.PARAMETER Enable
	Turn on Sticky keys by pressing the Shift key 5 times

	.EXAMPLE
	StickyShift -Disable

	.EXAMPLE
	StickyShift -Enable

	.NOTES
	Current user
#>
function StickyShift {
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
            New-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name Flags -PropertyType String -Value 506 -Force
        }
        "Enable" {
            New-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name Flags -PropertyType String -Value 510 -Force
        }
    }
}

<#
	.SYNOPSIS
	AutoPlay for all media and devices

	.PARAMETER Disable
	Don't use AutoPlay for all media and devices

	.PARAMETER Enable
	Use AutoPlay for all media and devices

	.EXAMPLE
	Autoplay -Disable

	.EXAMPLE
	Autoplay -Enable

	.NOTES
	Current user
#>
function Autoplay {
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
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers -Name DisableAutoplay -PropertyType DWord -Value 1 -Force
        }
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers -Name DisableAutoplay -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Thumbnail cache removal

	.PARAMETER Disable
	Disable thumbnail cache removal

	.PARAMETER Enable
	Enable thumbnail cache removal

	.EXAMPLE
	ThumbnailCacheRemoval -Disable

	.EXAMPLE
	ThumbnailCacheRemoval -Enable

	.NOTES
	Machine-wide
#>
function ThumbnailCacheRemoval {
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
            New-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache" -Name Autorun -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            New-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache" -Name Autorun -PropertyType DWord -Value 3 -Force
        }
    }
}

<#
	.SYNOPSIS
	Restart apps after signing in

	.PARAMETER Enable
	Automatically saving my restartable apps and restart them when I sign back in

	.PARAMETER Disable
	Turn off automatically saving my restartable apps and restart them when I sign back in

	.EXAMPLE
	SaveRestartableApps -Enable

	.EXAMPLE
	SaveRestartableApps -Disable

	.NOTES
	Current user
#>
function SaveRestartableApps {
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
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name RestartApps -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name RestartApps -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Network Discovery File and Printers Sharing

	.PARAMETER Enable
	Enable "Network Discovery" and "File and Printers Sharing" for workgroup networks

	.PARAMETER Disable
	Disable "Network Discovery" and "File and Printers Sharing" for workgroup networks

	.EXAMPLE
	NetworkDiscovery -Enable

	.EXAMPLE
	NetworkDiscovery -Disable

	.NOTES
	Current user
#>
function NetworkDiscovery {
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

    $FirewallRules = @(
        # File and printer sharing
        "@FirewallAPI.dll,-32752",

        # Network discovery
        "@FirewallAPI.dll,-28502"
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Enable" {
            if (-not (Get-CimInstance -ClassName CIM_ComputerSystem).PartOfDomain) {
                Set-NetFirewallRule -Group $FirewallRules -Profile Private -Enabled True

                Set-NetFirewallRule -Profile Public, Private -Name FPS-SMB-In-TCP -Enabled True
                Set-NetConnectionProfile -NetworkCategory Private
            }
        }
        "Disable" {
            if (-not (Get-CimInstance -ClassName CIM_ComputerSystem).PartOfDomain) {
                Set-NetFirewallRule -Group $FirewallRules -Profile Private -Enabled False
            }
        }
    }
}

<#
	.SYNOPSIS
	Active hours

	.PARAMETER Automatically
	Automatically adjust active hours for me based on daily usage

	.PARAMETER Manually
	Manually adjust active hours for me based on daily usage

	.EXAMPLE
	ActiveHours -Automatically

	.EXAMPLE
	ActiveHours -Manually

	.NOTES
	Machine-wide
#>
function ActiveHours {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Automatically"
        )]
        [switch]
        $Automatically,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Manually"
        )]
        [switch]
        $Manually
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Automatically" {
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name SmartActiveHoursState -PropertyType DWord -Value 1 -Force
        }
        "Manually" {
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name SmartActiveHoursState -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Restart as soon as possible to finish updating

	.PARAMETER Enable
	Restart as soon as possible to finish updating

	.PARAMETER Disable
	Don't restart as soon as possible to finish updating

	.EXAMPLE
	DeviceRestartAfterUpdate -Enable

	.EXAMPLE
	DeviceRestartAfterUpdate -Disable

	.NOTES
	Machine-wide
#>
function RestartDeviceAfterUpdate {
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
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name IsExpedited -PropertyType DWord -Value 1 -Force
        }
        "Disable" {
            New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name IsExpedited -PropertyType DWord -Value 0 -Force
        }
    }
}

<#
	.SYNOPSIS
	Register app, calculate hash, and associate with an extension with the "How do you want to open this" pop-up hidden

	.PARAMETER ProgramPath
	Set a path to a program to associate an extension with

	.PARAMETER Extension
	Set the extension type

	.PARAMETER Icon
	Set a path to an icon

	.EXAMPLE
	Set-Association -ProgramPath "C:\SumatraPDF.exe" -Extension .pdf -Icon "shell32.dll,100"

	.EXAMPLE
	Set-Association -ProgramPath "%ProgramFiles%\Notepad++\notepad++.exe" -Extension .txt -Icon "%ProgramFiles%\Notepad++\notepad++.exe,0"

	.LINK
	https://github.com/DanysysTeam/PS-SFTA
	https://github.com/default-username-was-already-taken/set-fileassoc
	https://forum.ru-board.com/profile.cgi?action=show&member=westlife

	.NOTES
	Machine-wide
#>
function Set-Association {
    [CmdletBinding()]
    Param
    (
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [string]
        $ProgramPath,

        [Parameter(
            Mandatory = $true,
            Position = 1
        )]
        [string]
        $Extension,

        [Parameter(Mandatory = $false)]
        [string]
        $Icon
    )

    $ProgramPath = [System.Environment]::ExpandEnvironmentVariables($ProgramPath)

    if ($Icon) {
        $Icon = [System.Environment]::ExpandEnvironmentVariables($Icon)
    }

    if (Test-Path -Path $ProgramPath) {
        # Generate ProgId
        $ProgId = (Get-Item -Path $ProgramPath).BaseName + $Extension.ToUpper()
    }
    else {
        $ProgId = $ProgramPath
    }

    #region functions
    $RegistryUtils = @'
using System;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Text;
using Microsoft.Win32;
using FILETIME = System.Runtime.InteropServices.ComTypes.FILETIME;

namespace RegistryUtils
{
	public static class Action
	{
		[DllImport("advapi32.dll", CharSet = CharSet.Auto)]
		private static extern int RegOpenKeyEx(UIntPtr hKey, string subKey, int ulOptions, int samDesired, out UIntPtr hkResult);

		[DllImport("advapi32.dll", SetLastError = true)]
		private static extern int RegCloseKey(UIntPtr hKey);

		[DllImport("advapi32.dll", SetLastError=true, CharSet = CharSet.Unicode)]
		private static extern uint RegDeleteKey(UIntPtr hKey, string subKey);

		[DllImport("advapi32.dll", EntryPoint = "RegQueryInfoKey", CallingConvention = CallingConvention.Winapi, SetLastError = true)]
		private static extern int RegQueryInfoKey(UIntPtr hkey, out StringBuilder lpClass, ref uint lpcbClass, IntPtr lpReserved,
			out uint lpcSubKeys, out uint lpcbMaxSubKeyLen, out uint lpcbMaxClassLen, out uint lpcValues, out uint lpcbMaxValueNameLen,
			out uint lpcbMaxValueLen, out uint lpcbSecurityDescriptor, ref FILETIME lpftLastWriteTime);

		[DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
		internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);

		[DllImport("kernel32.dll", ExactSpelling = true)]
		internal static extern IntPtr GetCurrentProcess();

		[DllImport("advapi32.dll", SetLastError = true)]
		internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

		[DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
		internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

		[DllImport("advapi32.dll", CharSet = CharSet.Auto, SetLastError = true)]
		private static extern int RegLoadKey(uint hKey, string lpSubKey, string lpFile);

		[DllImport("advapi32.dll", CharSet = CharSet.Auto, SetLastError = true)]
		private static extern int RegUnLoadKey(uint hKey, string lpSubKey);

		[StructLayout(LayoutKind.Sequential, Pack = 1)]
		internal struct TokPriv1Luid
		{
			public int Count;
			public long Luid;
			public int Attr;
		}

		public static void DeleteKey(RegistryHive registryHive, string subkey)
		{
			UIntPtr hKey = UIntPtr.Zero;

			try
			{
				var hive = new UIntPtr(unchecked((uint)registryHive));
				RegOpenKeyEx(hive, subkey, 0, 0x20019, out hKey);
				RegDeleteKey(hive, subkey);
			}
			finally
			{
				if (hKey != UIntPtr.Zero)
				{
					RegCloseKey(hKey);
				}
			}
		}

		private static DateTime ToDateTime(FILETIME ft)
		{
			IntPtr buf = IntPtr.Zero;
			try
			{
				long[] longArray = new long[1];
				int cb = Marshal.SizeOf(ft);
				buf = Marshal.AllocHGlobal(cb);
				Marshal.StructureToPtr(ft, buf, false);
				Marshal.Copy(buf, longArray, 0, 1);
				return DateTime.FromFileTime(longArray[0]);
			}
			finally
			{
				if (buf != IntPtr.Zero) Marshal.FreeHGlobal(buf);
			}
		}

		public static DateTime? GetLastModified(RegistryHive registryHive, string subKey)
		{
			var lastModified = new FILETIME();
			var lpcbClass = new uint();
			var lpReserved = new IntPtr();
			UIntPtr hKey = UIntPtr.Zero;

			try
			{
				try
				{
					var hive = new UIntPtr(unchecked((uint)registryHive));
					if (RegOpenKeyEx(hive, subKey, 0, (int)RegistryRights.ReadKey, out hKey) != 0)
					{
						return null;
					}

					uint lpcbSubKeys;
					uint lpcbMaxKeyLen;
					uint lpcbMaxClassLen;
					uint lpcValues;
					uint maxValueName;
					uint maxValueLen;
					uint securityDescriptor;
					StringBuilder sb;

					if (RegQueryInfoKey(hKey, out sb, ref lpcbClass, lpReserved, out lpcbSubKeys, out lpcbMaxKeyLen, out lpcbMaxClassLen,
						out lpcValues, out maxValueName, out maxValueLen, out securityDescriptor, ref lastModified) != 0)
					{
						return null;
					}

					var result = ToDateTime(lastModified);
					return result;
				}
				finally
				{
					if (hKey != UIntPtr.Zero)
					{
						RegCloseKey(hKey);
					}
				}
			}
			catch (Exception)
			{
				return null;
			}
		}

		internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
		internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
		internal const int TOKEN_QUERY = 0x00000008;
		internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;

		public enum RegistryHives : uint
		{
			HKEY_USERS = 0x80000003,
			HKEY_LOCAL_MACHINE = 0x80000002
		}

		public static void AddPrivilege(string privilege)
		{
			bool retVal;
			TokPriv1Luid tp;
			IntPtr hproc = GetCurrentProcess();
			IntPtr htok = IntPtr.Zero;
			retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
			tp.Count = 1;
			tp.Luid = 0;
			tp.Attr = SE_PRIVILEGE_ENABLED;
			retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
			retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
			///return retVal;
		}

		public static int LoadHive(RegistryHives hive, string subKey, string filePath)
		{
			AddPrivilege("SeRestorePrivilege");
			AddPrivilege("SeBackupPrivilege");

			uint regHive = (uint)hive;
			int result = RegLoadKey(regHive, subKey, filePath);

			return result;
		}

		public static int UnloadHive(RegistryHives hive, string subKey)
		{
			AddPrivilege("SeRestorePrivilege");
			AddPrivilege("SeBackupPrivilege");

			uint regHive = (uint)hive;
			int result = RegUnLoadKey(regHive, subKey);

			return result;
		}
	}
}
'@

    if (-not('RegistryUtils.Action' -as [type])) {
        Add-Type -TypeDefinition $RegistryUtils
    }

    function Set-Icon {
        Param
        (
            [Parameter(
                Mandatory = $true,
                Position = 0

            )]
            [string]
            $ProgId,

            [Parameter(
                Mandatory = $true,
                Position = 1
            )]
            [string]
            $Icon
        )

        if (-not (Test-Path -Path "HKCU:\Software\Classes\$ProgId\DefaultIcon")) {
            New-Item -Path "HKCU:\Software\Classes\$ProgId\DefaultIcon" -Force
        }
        New-ItemProperty -Path "HKCU:\Software\Classes\$ProgId\DefaultIcon" -Name "(default)" -PropertyType String -Value $Icon -Force
    }

    function Remove-UserChoiceKey {
        Param
        (
            [Parameter(
                Mandatory = $true,
                Position = 0
            )]
            [string]
            $SubKey
        )

        [RegistryUtils.Action]::DeleteKey([Microsoft.Win32.RegistryHive]::CurrentUser, $SubKey)
    }

    function Set-UserAccessKey {
        Param
        (
            [Parameter(
                Mandatory = $true,
                Position = 0
            )]
            [string]
            $SubKey
        )

        $OpenSubKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($SubKey, 'ReadWriteSubTree', 'TakeOwnership')
        if ($OpenSubKey) {
            $Acl = [System.Security.AccessControl.RegistrySecurity]::new()
            # Get current user SID
            $UserSID = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object -FilterScript { $_.Name -eq $env:USERNAME }).SID
            $Acl.SetSecurityDescriptorSddlForm("O:$UserSID`G:$UserSID`D:AI(D;;DC;;;$UserSID)")
            $OpenSubKey.SetAccessControl($Acl)
            $OpenSubKey.Close()
        }
    }

    function Write-ExtensionKeys {
        Param
        (
            [Parameter(
                Mandatory = $true,
                Position = 0
            )]
            [string]
            $ProgId,

            [Parameter(
                Mandatory = $true,
                Position = 1
            )]
            [string]
            $Extension
        )

        $OrigProgID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$Extension" -Name "(default)" -ErrorAction Ignore)."(default)"
        if ($OrigProgID) {
            # Save possible ProgIds history with extension
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name "$ProgID_$Extension" -PropertyType DWord -Value 0 -Force
        }

        $Name = "{0}_$Extension" -f (Split-Path -Path $ProgId -Leaf)
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name $Name -PropertyType DWord -Value 0 -Force

        if ("$ProgId_$Extension" -ne $Name) {
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name "$ProgId_$Extension" -PropertyType DWord -Value 0 -Force
        }

        # If ProgId doesn't exist set the specified ProgId for the extensions
        if (-not $OrigProgID) {
            if (-not (Test-Path -Path "HKCU:\Software\Classes\$Extension")) {
                New-Item -Path "HKCU:\Software\Classes\$Extension" -Force
            }
            New-ItemProperty -Path "HKCU:\Software\Classes\$Extension" -Name "(default)" -PropertyType String -Value $ProgId -Force
        }

        # Set the specified ProgId in the possible options for the assignment
        if (-not (Test-Path -Path "HKCU:\Software\Classes\$Extension\OpenWithProgids")) {
            New-Item -Path "HKCU:\Software\Classes\$Extension\OpenWithProgids" -Force
        }
        New-ItemProperty -Path "HKCU:\Software\Classes\$Extension\OpenWithProgids" -Name $ProgId -PropertyType None -Value ([byte[]]@()) -Force

        # Set the system ProgId to the extension parameters for the File Explorer to the possible options for the assignment, and if absent set the specified ProgId
        if ($OrigProgID) {
            if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids")) {
                New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids" -Force
            }
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids" -Name $OrigProgID -PropertyType None -Value ([byte[]]@()) -Force
        }

        if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids")) {
            New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids" -Force
        }
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids" -Name $ProgID -PropertyType None -Value ([byte[]]@()) -Force

        # Removing the UserChoice key
        Remove-UserChoiceKey -SubKey "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"

        # Setting parameters in UserChoice. The key is being autocreated
        if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice")) {
            New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice" -Force
        }
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice" -Name ProgId -PropertyType String -Value $ProgID -Force

        # Getting a hash based on the time of the section's last modification. After creating and setting the first parameter
        $ProgHash = Get-Hash -ProgId $ProgId -Extension $Extension -SubKey "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"

        if (-not (Test-Path -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice")) {
            New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice" -Force
        }
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice" -Name Hash -PropertyType String -Value $ProgHash -Force

        # Setting a ban on changing the UserChoice section
        Set-UserAccessKey -SubKey "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"
    }

    function Write-AdditionalKeys {
        Param
        (
            [Parameter(
                Mandatory = $true,
                Position = 0
            )]
            [string]
            $ProgId,

            [Parameter(
                Mandatory = $true,
                Position = 1
            )]
            [string]
            $Extension
        )

        # If there is the system extension ProgId, write it to the already configured by default
        if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$Extension" -Name "(default)" -ErrorAction Ignore)."(default)") {
            if (-not (Test-Path -Path Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\FileAssociations\ProgIds)) {
                New-Item -Path Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\FileAssociations\ProgIds -Force
            }
            New-ItemProperty -Path Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\FileAssociations\ProgIds -Name "_$Extension" -PropertyType DWord -Value 1 -Force
        }

        # Setting 'NoOpenWith' for all registered the extension ProgIDs
        [psobject]$OpenSubkey = Get-Item -Path "Registry::HKEY_CLASSES_ROOT\$Extension\OpenWithProgids" -ErrorAction Ignore | Select-Object -ExpandProperty Property

        if ($OpenSubkey) {
            foreach ($AppxProgID in ($OpenSubkey | Where-Object -FilterScript { $_ -match "AppX" })) {
                # If an app is installed
                if (Get-ItemPropertyValue -Path "HKCU:\Software\Classes\$AppxProgID\Shell\open" -Name PackageId) {
                    # If the specified ProgId is equal to UWP installed ProgId
                    if ($ProgId -eq $AppxProgID) {
                        # Remove association limitations for this UWP apps
                        Remove-ItemProperty -Path "HKCU:\Software\Classes\$AppxProgID" -Name NoOpenWith -Force -ErrorAction Ignore
                        Remove-ItemProperty -Path "HKCU:\Software\Classes\$AppxProgID" -Name NoStaticDefaultVerb -Force -ErrorAction Ignore
                    }
                    else {
                        New-ItemProperty -Path "HKCU:\Software\Classes\$AppxProgID" -Name NoOpenWith -PropertyType String -Value "" -Force
                    }
                }
            }
        }

        $picture = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\KindMap" -Name $Extension -ErrorAction Ignore).$Extension
        $PBrush = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\PBrush\CLSID" -Name "(default)" -ErrorAction Ignore)."(default)"

        if (($picture -eq "picture") -and $PBrush) {
            New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name "PBrush_$Extension" -PropertyType DWord -Value 0 -Force
        }
    }

    function Get-Hash {
        [CmdletBinding()]
        [OutputType([string])]
        Param
        (
            [Parameter(
                Mandatory = $true,
                Position = 0
            )]
            [string]
            $ProgId,

            [Parameter(
                Mandatory = $true,
                Position = 1
            )]
            [string]
            $Extension,

            [Parameter(
                Mandatory = $true,
                Position = 2
            )]
            [string]
            $SubKey
        )

        $PatentHash = @'
using System;

namespace FileAssoc
{
	public static class PatentHash
	{
		public static uint[] WordSwap(byte[] a, int sz, byte[] md5)
		{
			if (sz < 2 || (sz & 1) == 1) {
				throw new ArgumentException(String.Format("Invalid input size: {0}", sz), "sz");
			}

			unchecked {
				uint o1 = 0;
				uint o2 = 0;
				int ta = 0;
				int ts = sz;
				int ti = ((sz - 2) >> 1) + 1;

				uint c0 = (BitConverter.ToUInt32(md5, 0) | 1) + 0x69FB0000;
				uint c1 = (BitConverter.ToUInt32(md5, 4) | 1) + 0x13DB0000;

				for (uint i = (uint)ti; i > 0; i--) {
					uint n = BitConverter.ToUInt32(a, ta) + o1;
					ta += 8;
					ts -= 2;

					uint v1 = 0x79F8A395 * (n * c0 - 0x10FA9605 * (n >> 16)) + 0x689B6B9F * ((n * c0 - 0x10FA9605 * (n >> 16)) >> 16);
					uint v2 = 0xEA970001 * v1 - 0x3C101569 * (v1 >> 16);
					uint v3 = BitConverter.ToUInt32(a, ta - 4) + v2;
					uint v4 = v3 * c1 - 0x3CE8EC25 * (v3 >> 16);
					uint v5 = 0x59C3AF2D * v4 - 0x2232E0F1 * (v4 >> 16);

					o1 = 0x1EC90001 * v5 + 0x35BD1EC9 * (v5 >> 16);
					o2 += o1 + v2;
				}

				if (ts == 1) {
					uint n = BitConverter.ToUInt32(a, ta) + o1;

					uint v1 = n * c0 - 0x10FA9605 * (n >> 16);
					uint v2 = 0xEA970001 * (0x79F8A395 * v1 + 0x689B6B9F * (v1 >> 16)) - 0x3C101569 * ((0x79F8A395 * v1 + 0x689B6B9F * (v1 >> 16)) >> 16);
					uint v3 = v2 * c1 - 0x3CE8EC25 * (v2 >> 16);

					o1 = 0x1EC90001 * (0x59C3AF2D * v3 - 0x2232E0F1 * (v3 >> 16)) + 0x35BD1EC9 * ((0x59C3AF2D * v3 - 0x2232E0F1 * (v3 >> 16)) >> 16);
					o2 += o1 + v2;
				}

				uint[] ret = new uint[2];
				ret[0] = o1;
				ret[1] = o2;
				return ret;
			}
		}

		public static uint[] Reversible(byte[] a, int sz, byte[] md5)
		{
			if (sz < 2 || (sz & 1) == 1) {
				throw new ArgumentException(String.Format("Invalid input size: {0}", sz), "sz");
			}

			unchecked {
				uint o1 = 0;
				uint o2 = 0;
				int ta = 0;
				int ts = sz;
				int ti = ((sz - 2) >> 1) + 1;

				uint c0 = BitConverter.ToUInt32(md5, 0) | 1;
				uint c1 = BitConverter.ToUInt32(md5, 4) | 1;

				for (uint i = (uint)ti; i > 0; i--) {
					uint n = (BitConverter.ToUInt32(a, ta) + o1) * c0;
					n = 0xB1110000 * n - 0x30674EEF * (n >> 16);
					ta += 8;
					ts -= 2;

					uint v1 = 0x5B9F0000 * n - 0x78F7A461 * (n >> 16);
					uint v2 = 0x1D830000 * (0x12CEB96D * (v1 >> 16) - 0x46930000 * v1) + 0x257E1D83 * ((0x12CEB96D * (v1 >> 16) - 0x46930000 * v1) >> 16);
					uint v3 = BitConverter.ToUInt32(a, ta - 4) + v2;

					uint v4 = 0x16F50000 * c1 * v3 - 0x5D8BE90B * (c1 * v3 >> 16);
					uint v5 = 0x2B890000 * (0x96FF0000 * v4 - 0x2C7C6901 * (v4 >> 16)) + 0x7C932B89 * ((0x96FF0000 * v4 - 0x2C7C6901 * (v4 >> 16)) >> 16);

					o1 = 0x9F690000 * v5 - 0x405B6097 * (v5 >> 16);
					o2 += o1 + v2;
				}

				if (ts == 1) {
					uint n = BitConverter.ToUInt32(a, ta) + o1;

					uint v1 = 0xB1110000 * c0 * n - 0x30674EEF * ((c0 * n) >> 16);
					uint v2 = 0x5B9F0000 * v1 - 0x78F7A461 * (v1 >> 16);
					uint v3 = 0x1D830000 * (0x12CEB96D * (v2 >> 16) - 0x46930000 * v2) + 0x257E1D83 * ((0x12CEB96D * (v2 >> 16) - 0x46930000 * v2) >> 16);
					uint v4 = 0x16F50000 * c1 * v3 - 0x5D8BE90B * ((c1 * v3) >> 16);
					uint v5 = 0x96FF0000 * v4 - 0x2C7C6901 * (v4 >> 16);
					o1 = 0x9F690000 * (0x2B890000 * v5 + 0x7C932B89 * (v5 >> 16)) - 0x405B6097 * ((0x2B890000 * v5 + 0x7C932B89 * (v5 >> 16)) >> 16);
					o2 += o1 + v2;
				}

				uint[] ret = new uint[2];
				ret[0] = o1;
				ret[1] = o2;
				return ret;
			}
		}

		public static long MakeLong(uint left, uint right) {
			return (long)left << 32 | (long)right;
		}
	}
}
'@

        if ( -not ('FileAssoc.PatentHash' -as [type])) {
            Add-Type -TypeDefinition $PatentHash
        }

        function Get-KeyLastWriteTime ($SubKey) {
            $LM = [RegistryUtils.Action]::GetLastModified([Microsoft.Win32.RegistryHive]::CurrentUser, $SubKey)
            $FT = ([DateTime]::New($LM.Year, $LM.Month, $LM.Day, $LM.Hour, $LM.Minute, 0, $LM.Kind)).ToFileTime()

            return [string]::Format("{0:x8}{1:x8}", $FT -shr 32, $FT -band [uint32]::MaxValue)
        }

        function Get-DataArray {
            [OutputType([array])]

            # Secret static string stored in %SystemRoot%\SysWOW64\shell32.dll
            $userExperience = "User Choice set via Windows User Experience {D18B6DD5-6124-4341-9318-804003BAFA0B}"
            # Get user SID
            $userSid = (Get-CimInstance -ClassName Win32_UserAccount | Where-Object -FilterScript { $_.Name -eq $env:USERNAME }).SID
            $KeyLastWriteTime = Get-KeyLastWriteTime -SubKey $SubKey
            $baseInfo = ("{0}{1}{2}{3}{4}" -f $Extension, $userSid, $ProgId, $KeyLastWriteTime, $userExperience).ToLowerInvariant()
            $StringToUTF16LEArray = [System.Collections.ArrayList]@([System.Text.Encoding]::Unicode.GetBytes($baseInfo))
            $StringToUTF16LEArray += (0, 0)

            return $StringToUTF16LEArray
        }

        function Get-PatentHash {
            [OutputType([string])]
            param
            (
                [Parameter(Mandatory = $true)]
                [byte[]]
                $A,

                [Parameter(Mandatory = $true)]
                [byte[]]
                $MD5
            )

            $Size = $A.Count
            $ShiftedSize = ($Size -shr 2) - ($Size -shr 2 -band 1) * 1

            [uint32[]]$A1 = [FileAssoc.PatentHash]::WordSwap($A, [int]$ShiftedSize, $MD5)
            [uint32[]]$A2 = [FileAssoc.PatentHash]::Reversible($A, [int]$ShiftedSize, $MD5)

            $Ret = [FileAssoc.PatentHash]::MakeLong($A1[1] -bxor $A2[1], $A1[0] -bxor $A2[0])

            return [System.Convert]::ToBase64String([System.BitConverter]::GetBytes([Int64]$Ret))
        }

        $DataArray = Get-DataArray
        $DataMD5 = [System.Security.Cryptography.HashAlgorithm]::Create("MD5").ComputeHash($DataArray)
        $Hash = Get-PatentHash -A $DataArray -MD5 $DataMD5

        return $Hash
    }
    #endregion functions

    if ($ProgramPath) {
        if (-not (Test-Path -Path "HKCU:\Software\Classes\$ProgId\shell\open\command")) {
            New-Item -Path "HKCU:\Software\Classes\$ProgId\shell\open\command" -Force
        }
        New-ItemProperty -Path "HKCU:\Software\Classes\$ProgId\shell\open\command" -Name "(Default)" -PropertyType String -Value "`"$ProgramPath`" `"%1`"" -Force

        $FileNameEXE = Split-Path -Path $ProgramPath -Leaf
        if (-not (Test-Path -Path "HKCU:\Software\Classes\Applications\$FileNameEXE\shell\open\command")) {
            New-Item -Path "HKCU:\Software\Classes\Applications\$FileNameEXE\shell\open\command" -Force
        }
        New-ItemProperty -Path "HKCU:\Software\Classes\Applications\$FileNameEXE\shell\open\command" -Name "(Default)" -PropertyType String -Value "`"$ProgramPath`" `"%1`"" -Force
    }

    if ($Icon) {
        Set-Icon -ProgId $ProgId -Icon $Icon
    }

    Write-Information -MessageData "" -InformationAction Continue
    Write-Verbose -Message $Localization.Patient -Verbose

    # If the file extension specified configure the extension
    Write-ExtensionKeys -ProgId $ProgId -Extension $Extension

    # Setting additional parameters to comply with the requirements before configuring the extension
    Write-AdditionalKeys -ProgId $ProgId -Extension $Extension

    # Refresh the desktop icons
    $UpdateExplorer = @{
        Namespace        = "WinAPI"
        Name             = "UpdateExplorer"
        Language         = "CSharp"
        MemberDefinition = @"
[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = false)]
private static extern int SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
public static void Refresh()
{
	// Update desktop icons
	SHChangeNotify(0x8000000, 0x1000, IntPtr.Zero, IntPtr.Zero);
}
"@
    }
    if (-not ("WinAPI.UpdateExplorer" -as [type])) {
        Add-Type @UpdateExplorer
    }

    [WinAPI.UpdateExplorer]::Refresh()
}

<#
	.SYNOPSIS
	Default terminal app

	.PARAMETER WindowsTerminal
	Set Windows Terminal as default terminal app to host the user interface for command-line applications

	.PARAMETER ConsoleHost
	Set Windows Console Host as default terminal app to host the user interface for command-line applications

	.EXAMPLE
	DefaultTerminalApp -WindowsTerminal

	.EXAMPLE
	DefaultTerminalApp -ConsoleHost

	.NOTES
	Current user
#>
function DefaultTerminalApp {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "WindowsTerminal"
        )]
        [switch]
        $WindowsTerminal,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "ConsoleHost"
        )]
        [switch]
        $ConsoleHost
    )

    switch ($PSCmdlet.ParameterSetName) {
        "WindowsTerminal" {
            if (Get-AppxPackage -Name Microsoft.WindowsTerminal) {
                # Checking if the Terminal version supports such feature
                $TerminalVersion = (Get-AppxPackage -Name Microsoft.WindowsTerminal).Version
                if ([System.Version]$TerminalVersion -ge [System.Version]"1.11") {
                    if (-not (Test-Path -Path "HKCU:\Console\%%Startup")) {
                        New-Item -Path "HKCU:\Console\%%Startup" -Force
                    }

                    # Find the current GUID of Windows Terminal
                    $PackageFullName = (Get-AppxPackage -Name Microsoft.WindowsTerminal).PackageFullName
                    Get-ChildItem -Path "HKLM:\SOFTWARE\Classes\PackagedCom\Package\$PackageFullName\Class" | ForEach-Object -Process {
                        if ((Get-ItemPropertyValue -Path $_.PSPath -Name ServerId) -eq 0) {
                            New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationConsole -PropertyType String -Value $_.PSChildName -Force
                        }

                        if ((Get-ItemPropertyValue -Path $_.PSPath -Name ServerId) -eq 1) {
                            New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationTerminal -PropertyType String -Value $_.PSChildName -Force
                        }
                    }
                }
            }
        }
        "ConsoleHost" {
            New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationConsole -PropertyType String -Value "{00000000-0000-0000-0000-000000000000}" -Force
            New-ItemProperty -Path "HKCU:\Console\%%Startup" -Name DelegationTerminal -PropertyType String -Value "{00000000-0000-0000-0000-000000000000}" -Force
        }
    }
}

<#
	.SYNOPSIS
	Install the latest Microsoft Visual C++ Redistributable Packages 2015–2022 (x86/x64)

	.EXAMPLE
	InstallVCRedist

	.LINK
	https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist

	.NOTES
	Machine-wide
#>
function InstallVCRedist {
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

        if ([System.Version](Get-AppxPackage -Name Microsoft.DesktopAppInstaller).Version -ge [System.Version]"1.17") {
            winget install --id=Microsoft.VCRedist.2015+.x86 --exact --accept-source-agreements
            winget install --id=Microsoft.VCRedist.2015+.x64 --exact --accept-source-agreements
        }
        else {
            $DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
            $Parameters = @{
                Uri             = "https://aka.ms/vs/17/release/VC_redist.x86.exe"
                OutFile         = "$DownloadsFolder\VC_redist.x86.exe"
                UseBasicParsing = $true
                Verbose         = $true
            }
            Invoke-WebRequest @Parameters

            Start-Process -FilePath "$DownloadsFolder\VC_redist.x86.exe" -ArgumentList "/install /passive /norestart" -Wait

            $Parameters = @{
                Uri             = "https://aka.ms/vs/17/release/VC_redist.x64.exe"
                OutFile         = "$DownloadsFolder\VC_redist.x64.exe"
                UseBasicParsing = $true
                Verbose         = $true
            }
            Invoke-WebRequest @Parameters

            Start-Process -FilePath "$DownloadsFolder\VC_redist.x64.exe" -ArgumentList "/install /passive /norestart" -Wait

            # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
            Get-ChildItem -Path "$DownloadsFolder\VC_redist.x86.exe", "$DownloadsFolder\VC_redist.x64.exe", "$env:TEMP\dd_vcredist_amdx86_*.log", "$env:TEMP\dd_vcredist_amd64_*.log" -Force | Remove-Item -Recurse -Force -ErrorAction Ignore
        }
    }
    catch [System.Net.WebException] {
        Write-Warning -Message $Localization.NoInternetConnection
        Write-Error -Message $Localization.NoInternetConnection -ErrorAction SilentlyContinue

        Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
    }
}

<#
	.SYNOPSIS
	Install the latest .NET Desktop Runtime 6, 7 (x86/x64)

	.EXAMPLE
	InstallDotNetRuntimes

	.LINK
	https://dotnet.microsoft.com/en-us/download/dotnet

	.NOTES
	Machine-wide
#>
function InstallDotNetRuntimes {
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

        if ([System.Version](Get-AppxPackage -Name Microsoft.DesktopAppInstaller).Version -ge [System.Version]"1.17") {
            # .NET Desktop Runtime 6 x86
            winget install --id=Microsoft.DotNet.DesktopRuntime.6 --architecture x86 --exact --accept-source-agreements
            # .NET Desktop Runtime 7 x64
            winget install --id=Microsoft.DotNet.DesktopRuntime.6 --architecture x64 --exact --accept-source-agreements

            # .NET Desktop Runtime 7 x86
            winget install --id=Microsoft.DotNet.DesktopRuntime.7 --architecture x86 --exact --accept-source-agreements
            # .NET Desktop Runtime 7 x64
            winget install --id=Microsoft.DotNet.DesktopRuntime.7 --architecture x64 --exact --accept-source-agreements
        }
        else {
            # Install .NET Desktop Runtime 6
            # https://github.com/dotnet/core/blob/main/release-notes/releases-index.json
            $Parameters = @{
                Uri             = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/6.0/releases.json"
                UseBasicParsing = $true
            }
            $LatestRelease = (Invoke-RestMethod @Parameters)."latest-release"
            $DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"

            # .NET Desktop Runtime 6 x86
            $Parameters = @{
                Uri             = "https://dotnetcli.azureedge.net/dotnet/Runtime/$LatestRelease/dotnet-runtime-$LatestRelease-win-x86.exe"
                OutFile         = "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x86.exe"
                UseBasicParsing = $true
                Verbose         = $true
            }
            Invoke-WebRequest @Parameters

            Start-Process -FilePath "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x86.exe" -ArgumentList "/install /passive /norestart" -Wait

            # .NET Desktop Runtime 6 x64
            $Parameters = @{
                Uri             = "https://dotnetcli.azureedge.net/dotnet/Runtime/$LatestRelease/dotnet-runtime-$LatestRelease-win-x64.exe"
                OutFile         = "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x64.exe"
                UseBasicParsing = $true
                Verbose         = $true
            }
            Invoke-WebRequest @Parameters

            Start-Process -FilePath "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x64.exe" -ArgumentList "/install /passive /norestart" -Wait

            # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
            $Paths = @(
                "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x86.exe",
                "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x64.exe",
                "$env:TEMP\Microsoft_.NET_Runtime*.log"
            )
            Get-ChildItem -Path $Paths -Force -ErrorAction Ignore | Remove-Item -Recurse -Force -ErrorAction Ignore

            # .NET Desktop Runtime 7
            # https://github.com/dotnet/core/blob/main/release-notes/releases-index.json
            $Parameters = @{
                Uri             = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/7.0/releases.json"
                UseBasicParsing = $true
            }
            $LatestRelease = (Invoke-RestMethod @Parameters)."latest-release"
            $DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"

            # .NET Desktop Runtime 7 x86
            $Parameters = @{
                Uri             = "https://dotnetcli.azureedge.net/dotnet/Runtime/$LatestRelease/dotnet-runtime-$LatestRelease-win-x86.exe"
                OutFile         = "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x86.exe"
                UseBasicParsing = $true
                Verbose         = $true
            }
            Invoke-WebRequest @Parameters

            Start-Process -FilePath "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x86.exe" -ArgumentList "/install /passive /norestart" -Wait

            # .NET Desktop Runtime 7 x64
            $Parameters = @{
                Uri             = "https://dotnetcli.azureedge.net/dotnet/Runtime/$LatestRelease/dotnet-runtime-$LatestRelease-win-x64.exe"
                OutFile         = "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x64.exe"
                UseBasicParsing = $true
                Verbose         = $true
            }
            Invoke-WebRequest @Parameters

            Start-Process -FilePath "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x64.exe" -ArgumentList "/install /passive /norestart" -Wait

            # PowerShell 5.1 (7.3 too) interprets 8.3 file name literally, if an environment variable contains a non-latin word
            $Paths = @(
                "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x86.exe",
                "$DownloadsFolder\dotnet-runtime-$LatestRelease-win-x64.exe",
                "$env:TEMP\Microsoft_.NET_Runtime*.log"
            )
            Get-ChildItem -Path $Paths -Force -ErrorAction Ignore | Remove-Item -Recurse -Force -ErrorAction Ignore
        }
    }
    catch [System.Net.WebException] {
        Write-Warning -Message $Localization.NoInternetConnection
        Write-Error -Message $Localization.NoInternetConnection -ErrorAction SilentlyContinue

        Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
    }
}

<#
	.SYNOPSIS
	Bypass RKN restrictins using antizapret.prostovpn.org proxies

	.PARAMETER Enable
	Enable proxying only blocked sites from the unified registry of Roskomnadzor using antizapret.prostovpn.org servers

	.PARAMETER Disable
	Disable proxying only blocked sites from the unified registry of Roskomnadzor using antizapret.prostovpn.org servers

	.EXAMPLE
	RKNBypass -Enable

	.EXAMPLE
	RKNBypass -Disable

	.LINK
	https://antizapret.prostovpn.org

	.NOTES
	Current user
#>
function RKNBypass {
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
            # If current region is Russia
            if (((Get-WinHomeLocation).GeoId -eq "203")) {
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name AutoConfigURL -PropertyType String -Value "https://antizapret.prostovpn.org/proxy.pac" -Force
            }
        }
        "Disable" {
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name AutoConfigURL -Force
        }
    }
}

<#
	.SYNOPSIS
	Enable the latest Windows Subsystem for Android™ with Amazon Appstore

	.EXAMPLE Enable all necessary dependencies (reboot may require) and open Microsoft Store WSA page to install it manually
	WSA -Enable

	.EXAMPLE Disable all necessary dependencies (reboot may require) and uninstall Windows Subsystem for Android™ with Amazon Appstore
	WSA -Disable

	.LINK
	https://support.microsoft.com/en-us/windows/install-mobile-apps-and-the-amazon-appstore-f8d0abb5-44ad-47d8-b9fb-ad6b1459ff6c

	.LINK
	https://docs.microsoft.com/en-us/windows/android/wsa/

	.LINK
	https://www.microsoft.com/store/productId/9P3395VX91NR

	.NOTES
	Machine-wide
#>
function WSA {
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
            # Check if Windows 11 is installed on an SSD
            $DiskNumber = (Get-Disk | Where-Object -FilterScript { $_.Isboot -and $_.IsSystem -and ($_.OperationalStatus -eq "Online") }).Number
            if (Get-PhysicalDisk -DeviceNumber $DiskNumber | Where-Object -FilterScript { $_.MediaType -ne "SSD" }) {
                Write-Warning -Message $Localization.SSDRequired

                return
            }

            # Enable Windows Subsystem for Android (WSA)
            if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Disabled") {
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

                Write-Warning -Message $Localization.RestartWarning
                Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue

                return
            }

            # Enable Virtual Machine Platform
            if ((Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -eq "Disabled") {
                Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

                Write-Warning -Message $Localization.RestartWarning
                Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue

                return
            }

            if (Get-AppxPackage -Name MicrosoftCorporationII.WindowsSubsystemForAndroid) {
                return
            }

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

                if (((Get-WinHomeLocation).GeoId -ne "244")) {
                    # Set Windows region to USA
                    $Script:Region = (Get-WinHomeLocation).GeoId
                    Set-WinHomeLocation -GeoId 244

                    $Script:RegionChanged = $true
                }

                # Open Misrosoft Store WSA page to install it manually
                Start-Process -FilePath ms-windows-store://pdp/?ProductId=9P3395VX91NR
            }
            catch [System.Net.WebException] {
                Write-Warning -Message $Localization.NoInternetConnection
                Write-Error -Message $Localization.NoInternetConnection -ErrorAction SilentlyContinue

                Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
            }
        }
        "Disable" {
            Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
            Get-AppxPackage -Name MicrosoftCorporationII.WindowsSubsystemForAndroid | Remove-AppxPackage
        }
    }
}
#endregion System

#region Start menu
<#
	.SYNOPSIS
	Unpin all Start apps

	.EXAMPLE
	UnpinAllStartApps

	.NOTES
	Current user
#>
function UnpinAllStartApps {
    Remove-Item "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start*.bin" -Force -ErrorAction Ignore

    # https://gist.github.com/radtkedev
    $HexString = "E27AE14B01FC4D1B9C00810BDE6E51854E5A5F47005BB1498A5C92AF9084F95E9BDB91E2EEDDD701300B000067DEFA31529529B3D32D8092A6EB66C8D5EADB19CF9B13518AAB9
3275D9CEEF37E62C3574C036F327D1110AB0977996D67A2F8FA897D7207BEE85586B8CE6AD4F9736AA2154E3DCC9D082996984B76F1C73067F124F92A41F2B2CA83EF35436670979556FAE85AB10EA1
6C932C3AECE1D45DA06D64BC42F4565AD0FCB8C63CDE7F6BB97ACE300198C3EACA3E1C974F547B1A7CF5B9C6A912448AB38A3BE2D6F0230A4A9AACC710C3E75088754CC2FB054B55B1D6ED7AD41EB8B
0C9D4C274E87A525582F6CFBEAE5A904A1B0A3BA07939B79CAB4F1C3DF35BF88DE846E64555F0AEB47562C329206A9975664558849E0C251E8832D52B4FD7560347E5606AC882B9FC1F43C96922C0EA
1927DF004A062BAD5AC5A4BE6BF2DB23158B2BAEEF8DE9E3A777910E82E5488A83E4D64B0D84440B98B35BC4A3438596145669904AB392CFD5F7E22F616747B84851481FE1FF41CA9A2534CCE7AFC45
584370B4940DF30555536344249690F00C3A7E2552E352FE733C7ED2F80A29AD16937810AF805A444A344188C0CBDA51E5466BF45F2587508A69581CC2BCDAE06CB363658D94CD60569352FDA17AE7C
DD785810F369B41F2D15930430A809567CC6C643FE7986CAD545EF3DB40CA6FA9220BFC7F65610AECB22799838B80DE73AF549923F8219FFAAD64780E2DB53133D73890294E77F9B0970484E86A0507
37724FF15281C1726D334D3C9A67A85A78AE33F55DB675DAA31C47A156C0F8212DCEE228537668F4BF898C0CB869B74C98DF7EFBE0130859E5156417A85CC634B86314FAB47FB9A8DFEAFA1AEFC5E59
9A3F744BA51E8E6823F80E1529187FA5A78420B1EC091FD93134A71A0A0F478341D9ABD2CEABD5444160023C9CAB0A5C2BAC97F55F1E98FD21F2CFF03D2D24E0C4642F4A8A6E7627BD143AFC1A6DAE6
97B286C941B5EAAF57D34D598317C97F7CA23544B219196661B73E9DD27EBFE204B43C98C241AB02D2AA3A4EE7B2B477FC5E31642AF613BF356DFBE8AD666CE93267A3D45FD40F83CABAA2F0AE2601C
470D98AC4ABBCFA968882986297D06D81C1BE1EE8A0E64FB7543981B8E632809FBA7606BF518E8792EF4FBDC5CFC55690D8DF60812ECB2A39EB24B6F941C966DEF89E61E000D3F28CB6B260B17A53CE
8EEFC371C98BBEE72DE915BA9023DC74EEE7895D60AC2D13B51E73EB37E0FB714BB259614F3F7CBECD66EBDAE52FCB01D778C413DE0ED739DEA7AE48543614B93D46F63D1076E3C7696863D8F64EAC7
CAA7224FEB1A15E114358F379CA686AD7F09E75E2350F38A3B27F38D2DEFFB008B007371BD32E65B39FF6661DA237F277AC4A9C4DA5A1753250BBD3FA7ECD07E594C2014B5E26E06414B6588211CE43
9DAA2A352B017C196B4F20049DDBF2E4514E2CD7545E5AE22E877D5B6975D7FCDC61D49958258A093B05DB6D7C6457B9C260A420B1A15C6010B9C4AE68078E1B9592C97B47BFFE2C2F10A10129CC3B0
87041840091D2A6F5FDA1561E2F0315F8F0BF46204AA4E7C12DC819A1ABCDEB02400AA2FD46ECE2B8698C19F61ECA68232536A712BC858029D40FED5C20A051BCE6D316B03A97FE7051EE0C952A7EB9
FD2F77D9FBE75022FF5D13B168BD0B004D9C803E8F8C5D8F25CB22ACC97D8EDE169E5D50FCD87444C2029F021D87807B4A04EF148EF1C814E2827FABBCDE9E042140E0D890CEDE88B21F9824956D8F1
8EF3A8AC85194248915F53AF26F70BC5FDC26E415936EAB0DD78398B725F5419E8DDFD46EE9A17A37087507F9D20358208A65366C4824518E75413FDE5F27FC5DD8132EFB4414A5BDDDA1D64593D863
60062373FEE36F51ED56CA419FAD69751F76588995F9E2BE75ED13D2DED91EC1DED011752089716DD9C89DE21B8E52AD08CF1C463B0D79111200DF5269C646FBF0E3091A413CA70F6CA8F75BE257DB0
28329F7224023603C743AB204F8DAB5C273975FA93FBAAD84D0E4D72ABAC3A4E23D7236C848AD317E73E114C5B7438B8248C75B528E19E26D9BF908001A3214A137F24C74BC7D9910F858E47789FDFE
52AB712AE758AE15C4D86ED3C23D4EB78C5ED94D8A5AB8AA93C43E18FC0CE418AC79DF945E81A58B70332A2C03C445436E8013E0B82AC59AF856C6A00812BCD3B6209449B6D008CA37D8A9210A61049
350AD07F4E88FC7FBEC9FC64BC60C318912E36DBEA6D4058AF35CACD6E790C96B66EAE5966C47D3E1C4ACF42BF04D58FF363D20DBA61C9D32EBE433A45AFE02B41FD6FC91AE7157CCD7FACEC294623F
825DE576F72A8245D2BC5D1D7C71B183166C8F0DAF9CF8ED6F1DAEBB0349D82E57BB81DB946128A5440235AD6222A294B27E97738D49F52170DE1B1B922C8C548215FD0D2980D7BA9B8F3133D9415BA
B29670A5EDEC4858EB9D1A7E8FBD0296CB6D610BDD44A1A450EDEC61983152C237225F7AABABD482EB08328BC338D87BA1FE30864D9A97C20FA42CAEDF6359457C8BB26032A9728E819FFF9BF4F7154
69A0A4506A4CA1625E79CAE215683CDAADFB1E68ADC4987FF3FD7E9859CB40291478A4D2B281AEFEB97DC45C7F991311A68C2F173E2377709C355C6870DC4C14E5534120539C1DB0AD0D6E331D67058
1F6E352DCB3E34D61E6742F957FE9F39854A324E07C68A17BE9CB19446583EDDAAFD0E433A54F4E0854709BD47B24AC76DF75849B9D917FF2B0F4228C94EA01CF658430B2C18F6EEAB104B9A935C6FB
FEA494190BF3446DCC8C8AAF62BA01F0BFB18E15503C27558DB70C48EFB0AEA0B600F985C904E9F244E2A08464AE980E1A8CC05F22C9D4C23D753FD5250D0E190CB0CAC71404CF52A8CCEC988DBA22F
2164E203FB52064F38D8277764FECB0E2D811C307E4687CF6A245B2B89389D188E1F115EF2B36BA1BE63222A2C7E886A279B08ADF70109903F70EA1068137E72E894758614FE4BBAF333B8FC3EA98B1
49B3403FF8655FAAE1DF4877B5CDABC434B7336AB24C25A85246ADAA24DECB5A39F8FD7A5549F23F112244B7EE9E447D3226F2259428FDC0C3D6CD3A47B39092532B803FEBB6FFCC1ADF26C7857F04F
294F16A9DA7DD851D4EC99BBCF853FD3435A256F47DD3CB9480365C2896A1D0E2314940968E4E3714723B4C1CDD368581FED307C8B279AE6FB8BB72EC0A093733E2D9CC6B43320766D3B43D3C554CA8
2EEEF7B09850D29B2F412DEF3D0BD9194CAE8113B3B38085C77C238CB8D15BF6D6AB42C193F4E2F27F8BEDABB2D6ADE9E486B6AFAFD8D5DBE3B7D7305790F96ECDCC2DD016C5B9B200CB72E6CF54D71
F69A01CDE4E3A0A4C5A03627DECD491F215C1420EB07AB8FD2763FCFF5211EB964C82E69DA208BDFA76306D54642B117DCB9A92927CE2E633338D4EEA63B571349B8DA1D4B5523C4CA10308769E4F46
1ADD16DD5DFDB0E705187593DEF5CCCF659E48366462CC21D7930E1064234157A7A08E9C90927A37C5CF23D54C755002E4E657BB6E70D9B4BE7C468C19D6969FAE138EBF2C20DD3F5A0BC4C0E97D5BF
DB8744A21396C44549242817BEAD5AE14FF602E69E75B87784DE5F30BE14106E8D8A081DC8CCCFBF93896E622F755F27E82A596DDCA3469A93ECB9E2E897BF0FCC063426DACDC3B1D81E1EFE6B63932
6CA43526CFAEDF9922EAC3204FEB84AAED781EE5516FA5B4DCAB85DB5FF33CEC454DAA375BDA5EEA7C871C310AEDC5BD6B220B59B901D377E22FFFE95FEDA28CE2CE33CAEB8541EE05E1B5650D776C4
B2A246DB4613E2CC5D96A44D24AE662D848A7C9E3E922AFF0632B7B40505402956FABC5C3AAB55EEE29085046C127E8776CEFC1690B76EE99371AF9B1D7EF6F79E78325DD3BD8377E9B73B936C6F261
1D0A1223A4D7C6CF3037922DD0686A701FF86761993F294D26E13A7BB8B1C61ACAF38D50334A88DABB3FA412B4FC79F6FBFD0D0A92301484FF1BD1CF3DC67780E4562E05CCA329CABA7CB2B77D9A707
BDEE24B1E5E4ED6CC9D5A337908BE5303E477736C8A75051A8FBD4E3CB6360D8F0A992A48F333434D4AE712EC830BCB5EAA98788B6C76C"

    $HexString = $HexString.Replace("`n", "").Replace("`r", "")
    $Bytes = [byte[]]::new($HexString.Length / 2)
    for
    (
        $i = 0
        $i -lt $HexString.Length
        $i += 2
    ) {
        $Bytes[$i / 2] = [System.Convert]::ToByte($HexString.Substring($i, 2), 16)
    }

    Set-Content "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start.bin" -Value $Bytes -Encoding Byte -Force
}

<#
	.SYNOPSIS
	How to run the Windows PowerShell shortcut

	.PARAMETER Elevated
	Run the Windows PowerShell shortcut from the Start menu as Administrator

	.PARAMETER NonElevated
	Run the Windows PowerShell shortcut from the Start menu as user

	.EXAMPLE
	RunPowerShellShortcut -Elevated

	.EXAMPLE
	RunPowerShellShortcut -NonElevated

	.NOTES
	Current user
#>
function RunPowerShellShortcut {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Elevated"
        )]
        [switch]
        $Elevated,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "NonElevated"
        )]
        [switch]
        $NonElevated
    )

    switch ($PSCmdlet.ParameterSetName) {
        "Elevated" {
            [byte[]]$bytes = Get-Content -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" -Encoding Byte -Raw
            $bytes[0x15] = $bytes[0x15] -bor 0x20
            Set-Content -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" -Value $bytes -Encoding Byte -Force
        }
        "NonElevated" {
            [byte[]]$bytes = Get-Content -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" -Encoding Byte -Raw
            $bytes[0x15] = $bytes[0x15] -bxor 0x20
            Set-Content -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" -Value $bytes -Encoding Byte -Force
        }
    }
}

<#
	.SYNOPSIS
	Configure Start layout

	.PARAMETER Default
	Show default Start layout

	.PARAMETER ShowMorePins
	Show more pins on Start

	.PARAMETER ShowMoreRecommendations
	Show more recommendations on Start

	.EXAMPLE
	StartLayout -Default

	.EXAMPLE
	StartLayout -ShowMorePins

	.EXAMPLE
	StartLayout -ShowMoreRecommendations

	.NOTES
	For Windows 11 22H2+

	.NOTES
	Current user
#>
function StartLayout {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Default"
        )]
        [switch]
        $Default,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "ShowMorePins"
        )]
        [switch]
        $ShowMorePins,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "ShowMoreRecommendations"
        )]
        [switch]
        $ShowMoreRecommendations
    )

    if ((Get-CimInstance -ClassName CIM_OperatingSystem).BuildNumber -ge 22621) {
        switch ($PSCmdlet.ParameterSetName) {
            "Default" {
                # Default
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_Layout -PropertyType DWord -Value 0 -Force
            }
            "ShowMorePins" {
                # Show More Pins
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_Layout -PropertyType DWord -Value 1 -Force
            }
            "ShowMoreRecommendations" {
                # Show More Recommendations
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Start_Layout -PropertyType DWord -Value 2 -Force
            }
        }
    }
}
#endregion Start menu

#region Universal Apps
<#
	.SYNOPSIS
	Uninstall UWP apps

	.PARAMETER ForAllUsers
	The "ForAllUsers" argument sets a checkbox to unistall packages for all users

	.EXAMPLE
	UninstallUWPApps

	.EXAMPLE
	UninstallUWPApps -ForAllUsers

	.NOTES
	Current user
#>
function UninstallUWPApps {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [switch]
        $ForAllUsers
    )

    Add-Type -AssemblyName PresentationCore, PresentationFramework

    #region Variables
    # The following UWP apps will have their checkboxes unchecked
    $UncheckedAppxPackages = @(
        # AMD Radeon Software
        "AdvancedMicroDevicesInc-2.AMDRadeonSoftware",

        # Intel Graphics Control Center
        "AppUp.IntelGraphicsControlPanel",
        "AppUp.IntelGraphicsExperience",

        # Sticky Notes
        "Microsoft.MicrosoftStickyNotes",

        # Screen Sketch
        "Microsoft.ScreenSketch",

        # Photos (and Video Editor)
        "Microsoft.Windows.Photos",
        "Microsoft.Photos.MediaEngineDLC",

        # Calculator
        "Microsoft.WindowsCalculator",

        # Windows Camera
        "Microsoft.WindowsCamera",

        # Xbox Identity Provider
        "Microsoft.XboxIdentityProvider",

        # Xbox Console Companion
        "Microsoft.XboxApp",

        # Xbox
        "Microsoft.GamingApp",
        "Microsoft.GamingServices",

        # Paint
        "Microsoft.Paint",

        # Xbox TCUI
        "Microsoft.Xbox.TCUI",

        # Xbox Speech To Text Overlay
        "Microsoft.XboxSpeechToTextOverlay",

        # Xbox Game Bar
        "Microsoft.XboxGamingOverlay",

        # Xbox Game Bar Plugin
        "Microsoft.XboxGameOverlay",

        # NVIDIA Control Panel
        "NVIDIACorp.NVIDIAControlPanel",

        # Realtek Audio Console
        "RealtekSemiconductorCorp.RealtekAudioControl"
    )

    # The following UWP apps will be excluded from the display
    $ExcludedAppxPackages = @(
        # Microsoft Desktop App Installer
        "Microsoft.DesktopAppInstaller",

        # Store Experience Host
        "Microsoft.StorePurchaseApp",

        # Notepad
        "Microsoft.WindowsNotepad",

        # Microsoft Store
        "Microsoft.WindowsStore",

        # Windows Terminal
        "Microsoft.WindowsTerminal",
        "Microsoft.WindowsTerminalPreview",

        # Web Media Extensions
        "Microsoft.WebMediaExtensions",

        # AV1 Video Extension
        "Microsoft.AV1VideoExtension",

        # HEVC Video Extensions from Device Manufacturer
        "Microsoft.HEVCVideoExtension",

        # Raw Image Extension
        "Microsoft.RawImageExtension",

        # HEIF Image Extensions
        "Microsoft.HEIFImageExtension",

        # MPEG-2 Video Extension
        "Microsoft.MPEG2VideoExtension"
    )

    #region Variables
    #region XAML Markup
    # The section defines the design of the upcoming dialog box
    [xml]$XAML = '
	<Window
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Name="Window"
		MinHeight="400" MinWidth="415"
		SizeToContent="Width" WindowStartupLocation="CenterScreen"
		TextOptions.TextFormattingMode="Display" SnapsToDevicePixels="True"
		FontFamily="Candara" FontSize="16" ShowInTaskbar="True"
		Background="#F1F1F1" Foreground="#262626">
		<Window.Resources>
			<Style TargetType="StackPanel">
				<Setter Property="Orientation" Value="Horizontal"/>
				<Setter Property="VerticalAlignment" Value="Top"/>
			</Style>
			<Style TargetType="CheckBox">
				<Setter Property="Margin" Value="10, 13, 10, 10"/>
				<Setter Property="IsChecked" Value="True"/>
			</Style>
			<Style TargetType="TextBlock">
				<Setter Property="Margin" Value="0, 10, 10, 10"/>
			</Style>
			<Style TargetType="Button">
				<Setter Property="Margin" Value="20"/>
				<Setter Property="Padding" Value="10"/>
				<Setter Property="IsEnabled" Value="False"/>
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
			<Grid Grid.Row="0">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>
				<StackPanel Name="PanelSelectAll" Grid.Column="0" HorizontalAlignment="Left">
					<CheckBox Name="CheckBoxSelectAll" IsChecked="False"/>
					<TextBlock Name="TextBlockSelectAll" Margin="10,10, 0, 10"/>
				</StackPanel>
				<StackPanel Name="PanelRemoveForAll" Grid.Column="1" HorizontalAlignment="Right">
					<TextBlock Name="TextBlockRemoveForAll" Margin="10,10, 0, 10"/>
					<CheckBox Name="CheckBoxForAllUsers" IsChecked="False"/>
				</StackPanel>
			</Grid>
			<Border>
				<ScrollViewer>
					<StackPanel Name="PanelContainer" Orientation="Vertical"/>
				</ScrollViewer>
			</Border>
			<Button Name="ButtonUninstall" Grid.Row="2"/>
		</Grid>
	</Window>
	'
    #endregion XAML Markup

    $Reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $XAML)
    $Form = [Windows.Markup.XamlReader]::Load($Reader)
    $XAML.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
        Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)
    }

    $Window.Title = $Localization.UWPAppsTitle
    $ButtonUninstall.Content = $Localization.Uninstall
    $TextBlockRemoveForAll.Text = $Localization.UninstallUWPForAll
    $TextBlockSelectAll.Text = $Localization.SelectAll

    $ButtonUninstall.Add_Click({ ButtonUninstallClick })
    $CheckBoxForAllUsers.Add_Click({ CheckBoxForAllUsersClick })
    $CheckBoxSelectAll.Add_Click({ CheckBoxSelectAllClick })
    #endregion Variables

    #region Functions
    function Get-AppxBundle {
        [CmdletBinding()]
        param
        (
            [string[]]
            $Exclude,

            [switch]
            $AllUsers
        )

        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        $AppxPackages = @(Get-AppxPackage -PackageTypeFilter Bundle -AllUsers:$AllUsers | Where-Object -FilterScript { $_.Name -notin $ExcludedAppxPackages })

        # The Bundle packages contains no Microsoft Teams
        if (Get-AppxPackage -Name MicrosoftTeams -AllUsers:$AllUsers) {
            # Temporarily hack: due to the fact that there are actually two Microsoft Teams packages, we need to choose the first one to display
            $AppxPackages += Get-AppxPackage -Name MicrosoftTeams -AllUsers:$AllUsers | Select-Object -Index 0
        }

        # The Bundle packages contains no Spotify
        if (Get-AppxPackage -Name SpotifyAB.SpotifyMusic -AllUsers:$AllUsers) {
            # Temporarily hack: due to the fact that there are actually two Microsoft Teams packages, we need to choose the first one to display
            $AppxPackages += Get-AppxPackage -Name SpotifyAB.SpotifyMusic -AllUsers:$AllUsers | Select-Object -Index 0
        }

        $PackagesIds = [Windows.Management.Deployment.PackageManager, Windows.Web, ContentType = WindowsRuntime]::new().FindPackages() | Select-Object -Property DisplayName -ExpandProperty Id | Select-Object -Property Name, DisplayName

        foreach ($AppxPackage in $AppxPackages) {
            $PackageId = $PackagesIds | Where-Object -FilterScript { $_.Name -eq $AppxPackage.Name }

            if (-not $PackageId) {
                continue
            }

            [PSCustomObject]@{
                Name            = $AppxPackage.Name
                PackageFullName = $AppxPackage.PackageFullName
                DisplayName     = $PackageId.DisplayName
            }
        }
    }

    function Add-Control {
        [CmdletBinding()]
        param
        (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [ValidateNotNull()]
            [PSCustomObject[]]
            $Packages
        )

        process {
            foreach ($Package in $Packages) {
                $CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
                $CheckBox.Tag = $Package.PackageFullName

                $TextBlock = New-Object -TypeName System.Windows.Controls.TextBlock

                if ($Package.DisplayName) {
                    $TextBlock.Text = $Package.DisplayName
                }
                else {
                    $TextBlock.Text = $Package.Name
                }

                $StackPanel = New-Object -TypeName System.Windows.Controls.StackPanel
                $StackPanel.Children.Add($CheckBox) | Out-Null
                $StackPanel.Children.Add($TextBlock) | Out-Null

                $PanelContainer.Children.Add($StackPanel) | Out-Null

                if ($UncheckedAppxPackages.Contains($Package.Name)) {
                    $CheckBox.IsChecked = $false
                }
                else {
                    $CheckBox.IsChecked = $true
                    $PackagesToRemove.Add($Package.PackageFullName)
                }

                $CheckBox.Add_Click({ CheckBoxClick })
            }
        }
    }

    function CheckBoxForAllUsersClick {
        $PanelContainer.Children.RemoveRange(0, $PanelContainer.Children.Count)
        $PackagesToRemove.Clear()
        $AppXPackages = Get-AppxBundle -Exclude $ExcludedAppxPackages -AllUsers:$CheckBoxForAllUsers.IsChecked
        $AppXPackages | Add-Control

        ButtonUninstallSetIsEnabled
    }

    function ButtonUninstallClick {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        $Window.Close() | Out-Null

        # If Xbox Game Bar is selected to uninstall stop its' processes
        if ($PackagesToRemove -match "Microsoft.XboxGamingOverlay") {
            Get-Process -Name GameBar, GameBarFTServer -ErrorAction Ignore | Stop-Process -Force
        }

        $PackagesToRemove | Remove-AppxPackage -AllUsers:$CheckBoxForAllUsers.IsChecked -Verbose
    }

    function CheckBoxClick {
        $CheckBox = $_.Source

        if ($CheckBox.IsChecked) {
            $PackagesToRemove.Add($CheckBox.Tag) | Out-Null
        }
        else {
            $PackagesToRemove.Remove($CheckBox.Tag)
        }

        ButtonUninstallSetIsEnabled
    }

    function CheckBoxSelectAllClick {
        $CheckBox = $_.Source

        if ($CheckBox.IsChecked) {
            $PackagesToRemove.Clear()

            foreach ($Item in $PanelContainer.Children.Children) {
                if ($Item -is [System.Windows.Controls.CheckBox]) {
                    $Item.IsChecked = $true
                    $PackagesToRemove.Add($Item.Tag)
                }
            }
        }
        else {
            $PackagesToRemove.Clear()

            foreach ($Item in $PanelContainer.Children.Children) {
                if ($Item -is [System.Windows.Controls.CheckBox]) {
                    $Item.IsChecked = $false
                }
            }
        }

        ButtonUninstallSetIsEnabled
    }

    function ButtonUninstallSetIsEnabled {
        if ($PackagesToRemove.Count -gt 0) {
            $ButtonUninstall.IsEnabled = $true
        }
        else {
            $ButtonUninstall.IsEnabled = $false
        }
    }
    #endregion Functions

    # Check "For all users" checkbox to uninstall packages from all accounts
    if ($ForAllUsers) {
        $CheckBoxForAllUsers.IsChecked = $true
    }

    $PackagesToRemove = [Collections.Generic.List[string]]::new()
    $AppXPackages = Get-AppxBundle -Exclude $ExcludedAppxPackages -AllUsers:$ForAllUsers
    $AppXPackages | Add-Control

    if ($AppxPackages.Count -eq 0) {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.NoData -Verbose
    }
    else {
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

            # Emulate the Backspace key sending to prevent the console window to freeze
            [System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE 1}")
        }
        #endregion Sendkey function

        if ($PackagesToRemove.Count -gt 0) {
            $ButtonUninstall.IsEnabled = $true
        }

        # Force move the WPF form to the foreground
        $Window.Add_Loaded({ $Window.Activate() })
        $Form.ShowDialog() | Out-Null
    }
}

<#
	.SYNOPSIS
	Restore the default UWP apps

	.EXAMPLE
	RestoreUWPAppsUWPApps

	.NOTES
	UWP apps can be restored only if they were uninstalled for the current user

	.NOTES
	Current user
#>
function RestoreUWPApps {
    Add-Type -AssemblyName PresentationCore, PresentationFramework

    #region Variables
    #region XAML Markup
    # The section defines the design of the upcoming dialog box
    [xml]$XAML = '
	<Window
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Name="Window"
		MinHeight="400" MinWidth="410"
		SizeToContent="Width" WindowStartupLocation="CenterScreen"
		TextOptions.TextFormattingMode="Display" SnapsToDevicePixels="True"
		FontFamily="Candara" FontSize="16" ShowInTaskbar="True"
		Background="#F1F1F1" Foreground="#262626">
		<Window.Resources>
			<Style TargetType="StackPanel">
				<Setter Property="Orientation" Value="Horizontal"/>
				<Setter Property="VerticalAlignment" Value="Top"/>
			</Style>
			<Style TargetType="CheckBox">
				<Setter Property="Margin" Value="10, 13, 10, 10"/>
				<Setter Property="IsChecked" Value="True"/>
			</Style>
			<Style TargetType="TextBlock">
				<Setter Property="Margin" Value="0, 10, 10, 10"/>
			</Style>
			<Style TargetType="Button">
				<Setter Property="Margin" Value="20"/>
				<Setter Property="Padding" Value="10"/>
				<Setter Property="IsEnabled" Value="False"/>
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
			<Grid Grid.Row="0">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="*"/>
				</Grid.ColumnDefinitions>
				<StackPanel Name="PanelSelectAll" Grid.Column="0" HorizontalAlignment="Left">
					<CheckBox Name="CheckBoxSelectAll" IsChecked="False"/>
					<TextBlock Name="TextBlockSelectAll" Margin="10,10, 0, 10"/>
				</StackPanel>
			</Grid>
			<Border>
				<ScrollViewer>
					<StackPanel Name="PanelContainer" Orientation="Vertical"/>
				</ScrollViewer>
			</Border>
			<Button Name="ButtonRestore" Grid.Row="2"/>
		</Grid>
	</Window>
	'
    #endregion XAML Markup

    $Reader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $XAML)
    $Form = [Windows.Markup.XamlReader]::Load($Reader)
    $XAML.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
        Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)
    }

    $Window.Title = $Localization.UWPAppsTitle
    $ButtonRestore.Content = $Localization.Restore
    $TextBlockSelectAll.Text = $Localization.SelectAll

    $ButtonRestore.Add_Click({ ButtonRestoreClick })
    $CheckBoxSelectAll.Add_Click({ CheckBoxSelectAllClick })
    #endregion Variables

    #region Functions
    function Get-AppxManifest {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        # You cannot retrieve packages using -PackageTypeFilter Bundle, otherwise you won't get the InstallLocation attribute. It can be retrieved only by comparing with $Bundles
        $Bundles = (Get-AppXPackage -PackageTypeFilter Bundle -AllUsers).Name
        $AppxPackages = @(Get-AppxPackage -AllUsers | Where-Object -FilterScript { $_.PackageUserInformation -match "Staged" } | Where-Object -FilterScript { $_.Name -in $Bundles })

        # The Bundle packages contains no Microsoft Teams
        if (Get-AppxPackage -Name MicrosoftTeams -AllUsers) {
            # Temporarily hack: due to the fact that there are actually two Microsoft Teams packages, we need to choose the first one to display
            $AppxPackages += Get-AppxPackage -Name MicrosoftTeams -AllUsers | Where-Object -FilterScript { $_.PackageUserInformation -match "Staged" } | Select-Object -Index 0
        }

        # The Bundle packages contains no Microsoft Teams
        if (Get-AppxPackage -Name SpotifyAB.SpotifyMusic -AllUsers) {
            # Temporarily hack: due to the fact that there are actually two Spotify packages, we need to choose the first one to display
            $AppxPackages += Get-AppxPackage -Name SpotifyAB.SpotifyMusic -AllUsers | Where-Object -FilterScript { $_.PackageUserInformation -match "Staged" } | Select-Object -Index 0
        }

        $PackagesIds = [Windows.Management.Deployment.PackageManager, Windows.Web, ContentType = WindowsRuntime]::new().FindPackages() | Select-Object -Property DisplayName -ExpandProperty Id | Select-Object -Property Name, DisplayName

        foreach ($AppxPackage in $AppxPackages) {
            $PackageId = $PackagesIds | Where-Object -FilterScript { $_.Name -eq $AppxPackage.Name }

            if (-not $PackageId) {
                continue
            }

            [PSCustomObject]@{
                Name            = $AppxPackage.Name
                PackageFullName = $AppxPackage.PackageFullName
                DisplayName     = $PackageId.DisplayName
                AppxManifest    = "$($AppxPackage.InstallLocation)\AppxManifest.xml"
            }
        }
    }

    function Add-Control {
        [CmdletBinding()]
        param
        (
            [Parameter(
                Mandatory = $true,
                ValueFromPipeline = $true
            )]
            [ValidateNotNull()]
            [PSCustomObject[]]
            $Packages
        )

        process {
            foreach ($Package in $Packages) {
                $CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
                $CheckBox.Tag = $Package.AppxManifest

                $TextBlock = New-Object -TypeName System.Windows.Controls.TextBlock

                if ($Package.DisplayName) {
                    $TextBlock.Text = $Package.DisplayName
                }
                else {
                    $TextBlock.Text = $Package.Name
                }

                $StackPanel = New-Object -TypeName System.Windows.Controls.StackPanel
                $StackPanel.Children.Add($CheckBox) | Out-Null
                $StackPanel.Children.Add($TextBlock) | Out-Null

                $PanelContainer.Children.Add($StackPanel) | Out-Null

                $CheckBox.IsChecked = $true
                $PackagesToRestore.Add($Package.AppxManifest)

                $CheckBox.Add_Click({ CheckBoxClick })
            }
        }
    }

    function ButtonRestoreClick {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.Patient -Verbose

        $Window.Close() | Out-Null

        $Parameters = @{
            Register                  = $true
            ForceApplicationShutdown  = $true
            ForceUpdateFromAnyVersion = $true
            DisableDevelopmentMode    = $true
            Verbose                   = $true
        }
        $PackagesToRestore | Add-AppxPackage @Parameters
    }

    function CheckBoxClick {
        $CheckBox = $_.Source

        if ($CheckBox.IsChecked) {
            $PackagesToRestore.Add($CheckBox.Tag) | Out-Null
        }
        else {
            $PackagesToRestore.Remove($CheckBox.Tag)
        }

        ButtonRestoreSetIsEnabled
    }

    function CheckBoxSelectAllClick {
        $CheckBox = $_.Source

        if ($CheckBox.IsChecked) {
            $PackagesToRestore.Clear()

            foreach ($Item in $PanelContainer.Children.Children) {
                if ($Item -is [System.Windows.Controls.CheckBox]) {
                    $Item.IsChecked = $true
                    $PackagesToRestore.Add($Item.Tag)
                }
            }
        }
        else {
            $PackagesToRestore.Clear()

            foreach ($Item in $PanelContainer.Children.Children) {
                if ($Item -is [System.Windows.Controls.CheckBox]) {
                    $Item.IsChecked = $false
                }
            }
        }

        ButtonRestoreSetIsEnabled
    }

    function ButtonRestoreSetIsEnabled {
        if ($PackagesToRestore.Count -gt 0) {
            $ButtonRestore.IsEnabled = $true
        }
        else {
            $ButtonRestore.IsEnabled = $false
        }
    }
    #endregion Functions

    $PackagesToRestore = [Collections.Generic.List[string]]::new()
    $AppXPackages = Get-AppxManifest
    $AppXPackages | Add-Control

    if ($AppxPackages.Count -eq 0) {
        Write-Information -MessageData "" -InformationAction Continue
        Write-Verbose -Message $Localization.NoData -Verbose
    }
    else {
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

            # Emulate the Backspace key sending to prevent the console window to freeze
            [System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE 1}")
        }
        #endregion Sendkey function

        if ($PackagesToRestore.Count -gt 0) {
            $ButtonRestore.IsEnabled = $true
        }

        # Force move the WPF form to the foreground
        $Window.Add_Loaded({ $Window.Activate() })
        $Form.ShowDialog() | Out-Null
    }
}

<#
	.SYNOPSIS
	"HEVC Video Extensions from Device Manufacturer" extension

	.PARAMETER Install
	Download and install the "HEVC Video Extensions from Device Manufacturer" extension

	.PARAMETER Manually
	Open Microsoft Store "HEVC Video Extensions from Device Manufacturer" page to install the extension manually

	.EXAMPLE
	HEIF -Install

	.EXAMPLE
	HEIF -Manually

	.LINK
	https://www.microsoft.com/store/productId/9n4wgh0z6vhq

	.NOTES
	The extension can be installed without Microsoft account

	.NOTES
	HEVC Video Extension is already installed in Windows 11 22H2 by default

	.NOTES
	Current user
#>
function HEIF {
    param
    (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Install"
        )]
        [switch]
        $Install,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = "Manually"
        )]
        [switch]
        $Manually
    )

    # Check whether the extension is already installed
    if (-not (Get-AppxPackage -Name Microsoft.Windows.Photos)) {
        return
    }

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
    }
    catch [System.Net.WebException] {
        Write-Warning -Message $Localization.NoInternetConnection
        Write-Error -Message $Localization.NoInternetConnection -ErrorAction SilentlyContinue
        Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue

        return
    }

    switch ($PSCmdlet.ParameterSetName) {
        "Install" {
            try {
                # Check whether https://store.rg-adguard.net is alive
                $Parameters = @{
                    Uri              = "https://store.rg-adguard.net/api/GetFiles"
                    Method           = "Head"
                    DisableKeepAlive = $true
                    UseBasicParsing  = $true
                }
                if (-not (Invoke-WebRequest @Parameters).StatusDescription) {
                    return
                }

                $Body = @{
                    type = "url"
                    url  = "https://www.microsoft.com/store/productId/9n4wgh0z6vhq"
                    ring = "Retail"
                    lang = "en-US"
                }
                $Parameters = @{
                    Uri             = "https://store.rg-adguard.net/api/GetFiles"
                    Method          = "Post"
                    ContentType     = "application/x-www-form-urlencoded"
                    Body            = $Body
                    UseBasicParsing = $true
                    Verbose         = $true
                }
                $Raw = Invoke-WebRequest @Parameters

                # Parsing the page
                $Raw | Select-String -Pattern '<tr style.*<a href=\"(?<url>.*)"\s.*>(?<text>.*)<\/a>' -AllMatches | ForEach-Object -Process { $_.Matches } | Where-Object -FilterScript { $_.Value -like "*x64*.appx*" } | ForEach-Object -Process {
                    $TempURL = ($_.Groups | Select-Object -Index 1).Value
                    $HEVCPackageName = ($_.Groups | Select-Object -Index 2).Value.Split("_") | Select-Object -Index 1

                    # Installing "HEVC Video Extensions from Device Manufacturer"
                    if ([System.Version]$HEVCPackageName -gt [System.Version](Get-AppxPackage -Name Microsoft.HEVCVideoExtension).Version) {
                        Write-Verbose -Message $Localization.Patient -Verbose
                        Write-Verbose -Message $Localization.HEVCDownloading -Verbose

                        $DownloadsFolder = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}"
                        $Parameters = @{
                            Uri             = $TempURL
                            OutFile         = "$DownloadsFolder\Microsoft.HEVCVideoExtension_8wekyb3d8bbwe.appx"
                            UseBasicParsing = $true
                            Verbose         = $true
                        }
                        Invoke-WebRequest @Parameters

                        Add-AppxPackage -Path "$DownloadsFolder\Microsoft.HEVCVideoExtension_8wekyb3d8bbwe.appx" -Verbose
                        Remove-Item -Path "$DownloadsFolder\Microsoft.HEVCVideoExtension_8wekyb3d8bbwe.appx" -Force
                    }
                }
            }
            catch [System.Net.WebException] {
                Write-Warning -Message ($Localization.NoResponse -f "https://store.rg-adguard.net/api/GetFiles")
                Write-Error -Message ($Localization.NoResponse -f "https://store.rg-adguard.net/api/GetFiles") -ErrorAction SilentlyContinue

                Write-Error -Message ($Localization.RestartFunction -f $MyInvocation.Line) -ErrorAction SilentlyContinue
            }
        }
        "Manually" {
            Start-Process -FilePath ms-windows-store://pdp/?ProductId=9n4wgh0z6vhq
        }
    }
}

<#
	.SYNOPSIS
	Cortana autostarting

	.PARAMETER Disable
	Disable Cortana autostarting

	.PARAMETER Enable
	Enable Cortana autostarting

	.EXAMPLE
	CortanaAutostart -Disable

	.EXAMPLE
	CortanaAutostart -Enable

	.NOTES
	Current user
#>
function CortanaAutostart {
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
            if (Get-AppxPackage -Name Microsoft.549981C3F5F10) {
                if (-not (Test-Path -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId")) {
                    New-Item -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -Force
                }
                New-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -Name State -PropertyType DWord -Value 1 -Force
            }
        }
        "Enable" {
            if (Get-AppxPackage -Name Microsoft.549981C3F5F10) {
                if (-not (Test-Path -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId")) {
                    New-Item -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -Force
                }
                New-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -Name State -PropertyType DWord -Value 2 -Force
            }
        }
    }
}

<#
	.SYNOPSIS
	Microsoft Teams autostarting

	.PARAMETER Disable
	Enable Teams autostarting

	.PARAMETER Enable
	Disable Teams autostarting

	.EXAMPLE
	TeamsAutostart -Disable

	.EXAMPLE
	TeamsAutostart -Enable

	.NOTES
	Current user
#>
function TeamsAutostart {
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

    if (Get-AppxPackage -Name MicrosoftTeams) {
        switch ($PSCmdlet.ParameterSetName) {
            "Disable" {
                if (-not (Test-Path -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask")) {
                    New-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask" -Force
                }
                New-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask" -Name State -PropertyType DWord -Value 1 -Force
            }
            "Enable" {
                if (-not (Test-Path -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask")) {
                    New-Item -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask" -Force
                }
                New-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask" -Name State -PropertyType DWord -Value 2 -Force
            }
        }
    }
}

# Check for UWP apps updates
function CheckUWPAppsUpdates {
    Write-Information -MessageData "" -InformationAction Continue
    Write-Verbose -Message $Localization.Patient -Verbose
    Get-CimInstance -Namespace root\cimv2\mdm\dmmap -ClassName MDM_EnterpriseModernAppManagement_AppManagement01 | Invoke-CimMethod -MethodName UpdateScanMethod
}
#endregion Universal Apps

#region Gaming
<#
	.SYNOPSIS
	Xbox Game Bar

	.PARAMETER Disable
	Disable Xbox Game Bar

	.PARAMETER Enable
	Enable Xbox Game Bar

	.EXAMPLE
	XboxGameBar -Disable

	.EXAMPLE
	XboxGameBar -Enable

	.NOTES
	To prevent popping up the "You'll need a new app to open this ms-gamingoverlay" warning, you need to disable the Xbox Game Bar app, even if you uninstalled it before

	.NOTES
	Current user
#>
function XboxGameBar {
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
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR -Name AppCaptureEnabled -PropertyType DWord -Value 0 -Force
            New-ItemProperty -Path HKCU:\System\GameConfigStore -Name GameDVR_Enabled -PropertyType DWord -Value 0 -Force
        }
        "Enable" {
            New-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR -Name AppCaptureEnabled -PropertyType DWord -Value 1 -Force
            New-ItemProperty -Path HKCU:\System\GameConfigStore -Name GameDVR_Enabled -PropertyType DWord -Value 1 -Force
        }
    }
}

<#
	.SYNOPSIS
	Xbox Game Bar tips

	.PARAMETER Disable
	Disable Xbox Game Bar tips

	.PARAMETER Enable
	Enable Xbox Game Bar tips

	.EXAMPLE
	XboxGameTips -Disable

	.EXAMPLE
	XboxGameTips -Enable

	.NOTES
	Current user
#>
function XboxGameTips {
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
            if ((Get-AppxPackage -Name Microsoft.XboxGamingOverlay) -or (Get-AppxPackage -Name Microsoft.GamingApp)) {
                New-ItemProperty -Path HKCU:\Software\Microsoft\GameBar -Name ShowStartupPanel -PropertyType DWord -Value 0 -Force
            }
        }
        "Enable" {
            if ((Get-AppxPackage -Name Microsoft.XboxGamingOverlay) -or (Get-AppxPackage -Name Microsoft.GamingApp)) {
                New-ItemProperty -Path HKCU:\Software\Microsoft\GameBar -Name ShowStartupPanel -PropertyType DWord -Value 1 -Force
            }
        }
    }
}

<#
	.SYNOPSIS
	Choose an app and set the "High performance" graphics performance for it

	.EXAMPLE
	SetAppGraphicsPerformance

	.NOTES
	Works only with a dedicated GPU

	.NOTES
	Current user
#>
function SetAppGraphicsPerformance {
    if (Get-CimInstance -ClassName Win32_VideoController | Where-Object -FilterScript { ($_.AdapterDACType -ne "Internal") -and ($null -ne $_.AdapterDACType) }) {
        $Title = $Localization.GraphicsPerformanceTitle
        $Message = $Localization.GraphicsPerformanceRequest
        $Yes = $Localization.Yes
        $No = $Localization.No
        $Options = "&$Yes", "&$No"
        $DefaultChoice = 1

        do {
            $Result = $Host.UI.PromptForChoice($Title, $Message, $Options, $DefaultChoice)
            switch ($Result) {
                "0" {
                    Add-Type -AssemblyName System.Windows.Forms
                    $OpenFileDialog = New-Object -TypeName System.Windows.Forms.OpenFileDialog
                    $OpenFileDialog.Filter = $Localization.EXEFilesFilter
                    $OpenFileDialog.InitialDirectory = "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
                    $OpenFileDialog.Multiselect = $false

                    # Force move the open file dialog to the foreground
                    $Focus = New-Object -TypeName System.Windows.Forms.Form -Property @{TopMost = $true }
                    $OpenFileDialog.ShowDialog($Focus)

                    if ($OpenFileDialog.FileName) {
                        if (-not (Test-Path -Path HKCU:\Software\Microsoft\DirectX\UserGpuPreferences)) {
                            New-Item -Path HKCU:\Software\Microsoft\DirectX\UserGpuPreferences -Force
                        }
                        New-ItemProperty -Path HKCU:\Software\Microsoft\DirectX\UserGpuPreferences -Name $OpenFileDialog.FileName -PropertyType String -Value "GpuPreference=2;" -Force
                        Write-Verbose -Message $OpenFileDialog.FileName -Verbose
                    }
                }
                "1" {
                    Write-Information -MessageData "" -InformationAction Continue
                    Write-Verbose -Message $Localization.Skipped -Verbose
                }
            }
        }
        until ($Result -eq 1)
    }
}

<#
	.SYNOPSIS
	Hardware-accelerated GPU scheduling

	.PARAMETER Enable
	Enable hardware-accelerated GPU scheduling

	.PARAMETER Disable
	Disable hardware-accelerated GPU scheduling

	.EXAMPLE
	GPUScheduling -Enable

	.EXAMPLE
	GPUScheduling -Disable

	.NOTES
	Only with a dedicated GPU and WDDM verion is 2.7 or higher. Restart needed

	.NOTES
	Current user
#>
function GPUScheduling {
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
            if (Get-CimInstance -ClassName CIM_VideoController | Where-Object -FilterScript { ($_.AdapterDACType -ne "Internal") -and ($null -ne $_.AdapterDACType) }) {
                # Determining whether an OS is not installed on a virtual machine
                if ((Get-CimInstance -ClassName CIM_ComputerSystem).Model -notmatch "Virtual") {
                    # Checking whether a WDDM verion is 2.7 or higher
                    $WddmVersion_Min = Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\FeatureSetUsage -Name WddmVersion_Min
                    if ($WddmVersion_Min -ge 2700) {
                        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name HwSchMode -PropertyType DWord -Value 2 -Force
                    }
                }
            }
        }
        "Disable" {
            New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name HwSchMode -PropertyType DWord -Value 1 -Force
        }
    }
}
#endregion Gaming

function Windows10ContextMenu {
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
            Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction Ignore
        }
        "Enable" {
            if (-not (Test-Path -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32")) {
                New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -ItemType Directory -Force
            }
            New-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(default)" -PropertyType String -Value "" -Force
        }
    }
}