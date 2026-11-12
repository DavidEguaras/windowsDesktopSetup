<#
.SYNOPSIS
    Restores my Windows 11 desktop: YASB, Windhawk (mods + settings),
    macOS Tahoe cursors, fonts and wallpapers.

.DESCRIPTION
    Run from the repository root in PowerShell:
        Set-ExecutionPolicy -Scope Process Bypass -Force
        .\install.ps1

    Relaunches itself as administrator if needed (Windhawk stores its mods
    in HKLM and ProgramData). Everything it overwrites is first copied to
    %USERPROFILE%\windowsDesktopSetup-backup\<date>.

.PARAMETER Skip
    Steps to skip: apps, fonts, yasb, windhawk, cursors, wallpapers, theme
    E.g.: .\install.ps1 -Skip apps,wallpapers
#>
[CmdletBinding()]
param(
    [ValidateSet('apps', 'fonts', 'yasb', 'windhawk', 'cursors', 'wallpapers', 'theme')]
    [string[]]$Skip = @()
)

$ErrorActionPreference = 'Stop'
$Repo = $PSScriptRoot
$WallpapersRepo = 'https://github.com/DavidEguaras/wallpapers.git'
$WallpaperFile = 'a_colorful_mask_on_a_black_background.jpg'
$Backup = Join-Path $env:USERPROFILE ("windowsDesktopSetup-backup\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))

# --- Elevation ---------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Relaunching as administrator...' -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Skip) { $argList += @('-Skip', ($Skip -join ',')) }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit
}

New-Item -ItemType Directory -Force -Path $Backup | Out-Null
function Reg-Run([string[]]$regArgs) {
    $p = Start-Process reg.exe -ArgumentList $regArgs -Wait -PassThru -WindowStyle Hidden
    return $p.ExitCode
}

function Step($name) { Write-Host "`n==> $name" -ForegroundColor Cyan }
function Info($msg) { Write-Host "    $msg" }
function Backup-Path($path, $label) {
    if (Test-Path $path) {
        $dest = Join-Path $Backup $label
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item $path $dest -Recurse -Force
        Info "Backup: $path -> $dest"
    }
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class DesktopNative {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SystemParametersInfo(uint action, uint uParam, string vParam, uint winIni);
}
'@

# --- 1. Apps ----------------------------------------------------------------
if ('apps' -notin $Skip) {
    Step 'Installing apps (winget)'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget is not available. Install "App Installer" from the Microsoft Store.'
    }
    foreach ($id in 'AmN.yasb', 'RamenSoftware.Windhawk', 'Git.Git') {
        Info "winget install $id"
        winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
    }
    Refresh-Path
}

# --- 2. Fonts ----------------------------------------------------------------
if ('fonts' -notin $Skip) {
    Step 'Installing fonts (Figtree + JetBrainsMono Nerd Font)'
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    if (-not (Test-Path $fontReg)) { New-Item -Path $fontReg -Force | Out-Null }

    function Install-Font($file) {
        $dest = Join-Path $fontDir $file.Name
        Copy-Item $file.FullName $dest -Force
        $name = [IO.Path]::GetFileNameWithoutExtension($file.Name) + ' (TrueType)'
        Set-ItemProperty -Path $fontReg -Name $name -Value $dest
    }

    Get-ChildItem (Join-Path $Repo 'fonts\figtree') -Filter *.ttf | ForEach-Object { Install-Font $_ }
    Info 'Figtree installed'

    $tmp = Join-Path $env:TEMP 'jbmono-nf'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'JetBrainsMono.zip'
    Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $tmp -Force
    Get-ChildItem $tmp -Filter 'JetBrainsMono*NerdFont*.ttf' | ForEach-Object { Install-Font $_ }
    Remove-Item $tmp -Recurse -Force
    Info 'JetBrainsMono Nerd Font installed'
}

# --- 3. YASB -----------------------------------------------------------------
if ('yasb' -notin $Skip) {
    Step 'Configuring YASB'
    $yasbDir = Join-Path $env:USERPROFILE '.config\yasb'
    Backup-Path $yasbDir 'yasb'
    Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
    New-Item -ItemType Directory -Force -Path $yasbDir | Out-Null
    Copy-Item (Join-Path $Repo 'yasb\config.yaml'), (Join-Path $Repo 'yasb\styles.css') $yasbDir -Force
    Info "Config copied to $yasbDir"

    $yasbExe = 'C:\Program Files\YASB\yasb.exe'
    if (Test-Path $yasbExe) {
        Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'YASB' -Value $yasbExe
        Info 'YASB will start with Windows'
    }
}

# --- 4. Windhawk -------------------------------------------------------------
if ('windhawk' -notin $Skip) {
    Step 'Restoring Windhawk mods'
    $whData = 'C:\ProgramData\Windhawk'
    $whExe = 'C:\Program Files\Windhawk\windhawk.exe'
    if (-not (Test-Path $whExe)) { throw 'Windhawk is not installed (run without -Skip apps).' }

    Backup-Path (Join-Path $whData 'ModsSource') 'windhawk\ModsSource'
    Reg-Run @('export', 'HKLM\SOFTWARE\Windhawk\Engine\Mods', "`"$(Join-Path $Backup 'windhawk-mods-before.reg')`"", '/y') | Out-Null

    Get-Process windhawk -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2

    $srcDir = Join-Path $whData 'ModsSource'
    New-Item -ItemType Directory -Force -Path $srcDir | Out-Null
    Copy-Item (Join-Path $Repo 'windhawk\mods-source\*.wh.cpp') $srcDir -Force

    foreach ($arch in '32', '64') {
        $dst = Join-Path $whData "Engine\Mods\$arch"
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item (Join-Path $Repo "windhawk\compiled\$arch\*") $dst -Force
    }

    if ((Reg-Run @('import', "`"$(Join-Path $Repo 'windhawk\mods.reg')`"")) -ne 0) { throw 'Could not import windhawk\mods.reg' }
    Info 'Mods, settings and compiled binaries restored'

    Start-Process $whExe
    Info 'Windhawk restarted (if a mod does not load, open Windhawk and click "Compile")'
}

# --- 5. Cursors --------------------------------------------------------------
if ('cursors' -notin $Skip) {
    Step 'Applying macOS Tahoe cursors'
    $curDir = Join-Path $env:LOCALAPPDATA 'Cursors\macOS-Tahoe'
    New-Item -ItemType Directory -Force -Path $curDir | Out-Null
    Copy-Item (Join-Path $Repo 'cursors\macos-tahoe\*') $curDir -Force

    $map = [ordered]@{
        AppStarting = 'WaitS.ani';   Arrow    = 'arrowS.cur';  Crosshair = 'crossS.cur'
        Hand        = 'linkSI.cur';  Help     = 'helpS.cur';   IBeam     = 'beamS.cur'
        No          = 'noS.cur';     NWPen    = 'penS.cur';    SizeAll   = 'moveS.cur'
        SizeNESW    = 'D1sizeS.cur'; SizeNS   = 'HsizeS.cur';  SizeNWSE  = 'D2sizeS.cur'
        SizeWE      = 'VsizeS.cur';  UpArrow  = 'upS.cur';     Wait      = 'BusyS.ani'
        Pin         = 'locationS.cur'; Person = 'personS.cur'
    }
    $curReg = 'HKCU:\Control Panel\Cursors'
    Reg-Run @('export', '"HKCU\Control Panel\Cursors"', "`"$(Join-Path $Backup 'cursors-before.reg')`"", '/y') | Out-Null
    foreach ($k in $map.Keys) { Set-ItemProperty $curReg -Name $k -Value (Join-Path $curDir $map[$k]) }
    Set-ItemProperty $curReg -Name '(default)' -Value 'macOS Tahoe'
    Set-ItemProperty $curReg -Name 'Scheme Source' -Value 1 -Type DWord

    $schemes = 'HKCU:\Control Panel\Cursors\Schemes'
    if (-not (Test-Path $schemes)) { New-Item $schemes -Force | Out-Null }
    $order = 'Arrow', 'Help', 'AppStarting', 'Wait', 'Crosshair', 'IBeam', 'NWPen', 'No', 'SizeNS', 'SizeWE',
             'SizeNWSE', 'SizeNESW', 'SizeAll', 'UpArrow', 'Hand', 'Pin', 'Person'
    Set-ItemProperty $schemes -Name 'macOS Tahoe' -Value (($order | ForEach-Object { Join-Path $curDir $map[$_] }) -join ',')

    [DesktopNative]::SystemParametersInfo(0x0057, 0, $null, 0x03) | Out-Null   # SPI_SETCURSORS
    Info 'Cursors applied'
}

# --- 6. Wallpapers -----------------------------------------------------------
if ('wallpapers' -notin $Skip) {
    $resp = Read-Host "`nDo you want to download the wallpapers folder into Pictures\wallpapers? [Y/n]"
    if ($resp -match '^\s*(n|no)\s*$') {
        $Skip += 'wallpapers'
        Info 'Wallpapers skipped'
    }
}
if ('wallpapers' -notin $Skip) {
    Step 'Downloading wallpapers'
    Refresh-Path
    $wpDir = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'wallpapers'
    if (Test-Path (Join-Path $wpDir '.git')) {
        git -C $wpDir pull --ff-only
    } elseif (Test-Path $wpDir) {
        Info "$wpDir already exists and is not a git repo; leaving it as is"
    } else {
        git clone --depth 1 $WallpapersRepo $wpDir
    }

    $wp = Join-Path $wpDir $WallpaperFile
    if (Test-Path $wp) {
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'   # Fill
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
        [DesktopNative]::SystemParametersInfo(0x0014, 0, $wp, 0x03) | Out-Null    # SPI_SETDESKWALLPAPER
        Info "Wallpaper applied: $WallpaperFile"
    } else {
        Info "$WallpaperFile not found in the wallpapers repo"
    }
}

# --- 7. Theme ----------------------------------------------------------------
if ('theme' -notin $Skip) {
    Step 'Dark mode + transparency'
    $p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-ItemProperty $p -Name AppsUseLightTheme -Value 0 -Type DWord
    Set-ItemProperty $p -Name SystemUsesLightTheme -Value 0 -Type DWord
    Set-ItemProperty $p -Name EnableTransparency -Value 1 -Type DWord
}

# --- Startup -----------------------------------------------------------------
if ('yasb' -notin $Skip -and (Test-Path 'C:\Program Files\YASB\yasb.exe')) {
    Step 'Starting YASB'
    # Launched through explorer so it does not inherit this script's elevation
    Start-Process explorer.exe 'C:\Program Files\YASB\yasb.exe'
}

Write-Host "`nDone. Backups in: $Backup" -ForegroundColor Green
Write-Host 'Sign out and back in if some changes (cursors, theme) do not fully show up.'
