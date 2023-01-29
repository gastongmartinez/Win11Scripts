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
        https://github.com/ChrisTitusTech/win10script
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