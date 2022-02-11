[CmdletBinding()]
param (
    <#
    filename to launch.
    this file must be present in the app root.
    #>
    [Parameter()]
    [string]
    $LaunchTarget,

    <#
    disable automatic updating of the installed app.
    If enabled, the app is forced to use the currently used version, even if it is out of date
    #>
    [Parameter()]
    [switch]
    $DoNotUpdate,

    <#
    disable showing message boxes in case of (launch) errors
    #>
    [Parameter()]
    [switch]
    $NonInteractive,

    <#
    enable debug output
    #>
    [Parameter()]
    [switch]
    $EnableDebug
)

<#
name of the app
#>
[string] $AppName = "MyApp"

<#
The directory the app will be installed to. 
Expects a full path to the directory
#>
[string] $AppInstallDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, $AppName)

<#
The zip file containing the app binary to deploy
The archive will be extracted to $AppInstallDir on installation
Expects a full path to a .zip archive. 
#>
[string] $DeployZipPath = "$PSScriptRoot\res\app.zip"

<#
The version of the app present in the $DeployZipPath
This version is compared to the version currently installed. If the versions do not match, a update is performed automatically.

Format is Major.Minor.Build.Revision. Unused version parts should be set to 0
#>
[System.Version] $DeployVersion = [System.Version]::Parse("1.0.0.0")

<#
path to the version info file of the installed app
#>
[string] $AppVersionInfoPath = [System.IO.Path]::Combine($AppInstallDir, "app-version.info")

<#
path to the installation lock file for this app
#>
[string] $AppInstallLockPath = [System.IO.Path]::Combine($env:LOCALAPPDATA, "$($AppName).install-lock")

<#
.SYNOPSIS
check if the app needs to be updated

.OUTPUTS
boolean: should the app be updated?
#>
function ShouldUpdateApp() {
    # if the app is currently not installed, we should always update (= install)
    if (!(Test-Path -Path $AppVersionInfoPath -PathType Leaf)) {
        Write-Debug "app not installed, updating app"
        return $true
    }

    # if updates are disabled, we should not update
    if ($DoNotUpdate) {
        Write-Debug "not updating because -DoNotUpdate is set"
        return $false
    }

    # read and parse version info file
    # version info file is guranteed to exist by above check
    try {
        $installedVerStr = Get-Content -Path $AppVersionInfoPath -First 1
        $installedVer = [System.Version]::Parse($installedVerStr)
        Write-Debug "installed version is $($installedVer.ToString())"
    }
    catch {
        # if parsing fails for ANY reason, assume the app is out of date
        Write-Warning "reading installed version info failed, updating app"
        Write-Warning "error details: $($_)"
        return $true
    }

    # update if installed version < deployment version
    Write-Debug "deployment version is $($DeployVersion.ToString())"
    return ($DeployVersion.CompareTo($installedVer) -ne 0)
}

<#
.SYNOPSIS
update the app to the deployment version
#>
function UpdateApp() {
    # check lockfile
    Write-Debug "lockfile is $AppInstallLockPath"
    if (Test-Path -Path $AppInstallLockPath -PathType Leaf) {
        throw "lockfile found in $AppInstallLockPath, stopping update"
        return
    }

    # create lock
    New-Item -Path $AppInstallLockPath -ItemType File -ErrorAction Continue | Out-Null

    # delete current app install directory
    Write-Debug "removing previous installation"
    Remove-Item -Path $AppInstallDir -Force -Recurse -ErrorAction SilentlyContinue

    # create install directory
    Write-Debug "installing to $AppInstallDir"
    New-Item -Path $AppInstallDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    # extract deployment zip to app install directory
    Expand-Archive -Path $DeployZipPath -DestinationPath $AppInstallDir -ErrorAction SilentlyContinue | Out-Null

    # write deployment version to version info file
    Write-Debug "write version info to $AppVersionInfoPath"
    $DeployVersion.ToString() | Out-File -FilePath $AppVersionInfoPath

    # remove lock
    Remove-Item -Path $AppInstallLockPath -ErrorAction Continue
}

<#
.SYNOPSIS
launch the app target
#>
function LaunchApp() {
    # build target path
    $target = [System.IO.Path]::Combine($AppInstallDir, $LaunchTarget)
    Write-Debug "target path is $target"

    # check command target exists
    if (!(Test-Path -Path $target -PathType Leaf)) {
        Write-Warning "target does not exist"
        TryShowMessageBox -Title "Launch Error" -Message "could not find $LaunchTarget in $target"
        return
    }

    # launch the target
    Write-Debug "attempting to launch target"
    try {
        $process = Start-Process -FilePath $target -WorkingDirectory $AppInstallDir -NoNewWindow -PassThru -Wait
        Write-Debug "app exited with RC $($process.ExitCode)"        
    }
    catch {
        Write-Warning "launch failed: $($_)"
        TryShowMessageBox -Title "Launch Error" -Message "failed to launch $($LaunchTarget): $($_)"
    }
}

<#
.SYNOPSIS
try to show a message box

.PARAMETER Title
the title of the message box

.PARAMETER Message
the message shown in the message box
#>
function TryShowMessageBox([string] $Title, [string] $Message) {
    # skip if non- interactive
    if ($NonInteractive) {
        return
    }

    # show the message box
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Message, $Title) | Out-Null
    }
    catch {
        Write-Debug "failed to show message box: $($_)"
        return;
    }
}

<#
.SYNOPSIS
main entry point
#>
function Main() {
    # enable debug mode
    if ($EnableDebug) {
        $DebugPreference = "Continue"
    }

    # update app if needed
    Write-Debug "checking for app update"
    if (ShouldUpdateApp) {
        Write-Debug "app is out of date, updating"
        UpdateApp
    }

    # launch
    Write-Debug "launching app"
    LaunchApp
}
Main
