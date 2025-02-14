param(
    [Parameter(Mandatory=$true)]
    [string]$SerialNumber,
    
    [Parameter(Mandatory=$true)]
    [string]$Source
)

# Controleer of de bronlocatie bestaat
if (-not (Test-Path $Source)) {
    Write-Output "Bronlocatie '$Source' bestaat niet. Stoppen."
    exit 1
}

# Zoek het externe station op basis van het volume-serialnummer
$drive = Get-WmiObject -Class Win32_Volume | Where-Object { $_.SerialNumber -eq $SerialNumber -and $_.DriveLetter -ne $null }
if (-not $drive) {
    Write-Output "Externe drive met serial '$SerialNumber' niet gevonden. Stoppen."
    exit 1
}

$destDrive = $drive.DriveLetter  # Bijvoorbeeld "E:"
Write-Output "Gevonden externe drive: $destDrive"

# Definieer backup- en logpaden op het externe station
$backupFolder = Join-Path $destDrive "backup"
$logFile      = Join-Path $destDrive "backup_log.txt"
$manifestFile = Join-Path $destDrive "manifest.txt"
$robocopyLog  = Join-Path $destDrive "robocopy_log.txt"

# Functie om berichten naar het logbestand te schrijven
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Output $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "Backup gestart."
Write-Log "Bron: $Source"
Write-Log "Doel: $backupFolder"

# Verwijder de bestaande backup (indien aanwezig)
if (Test-Path $backupFolder) {
    Write-Log "Bestaande backup gevonden. Verwijderen van $backupFolder."
    Remove-Item -Path $backupFolder -Recurse -Force
}

# Maak de nieuwe backupfolder aan
New-Item -ItemType Directory -Path $backupFolder | Out-Null
Write-Log "Nieuwe backupfolder aangemaakt op $backupFolder."

# Start de backup met Robocopy (MIR: spiegelt de bron)
Write-Log "Start Robocopy van $Source naar $backupFolder."
$rc = robocopy $Source $backupFolder /MIR /NP /LOG:$robocopyLog /NFL /NDL /NJH /NJS
Write-Log "Robocopy voltooid (exitcode: $rc)."

# Genereer een manifest met metadata
Write-Log "Genereer manifestbestand."
$files = Get-ChildItem -Path $backupFolder -Recurse -File
$fileCount = $files.Count
$totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = if ($totalSizeBytes) { [Math]::Round($totalSizeBytes / 1MB, 2) } else { 0 }
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$manifestContent = @"
Backup Manifest
-------------------------
Backup Datum   : $date
Bron           : $Source
Doel           : $backupFolder
Externe Drive  : $destDrive (Serial: $SerialNumber)
Aantal Bestanden: $fileCount
Totale Grootte : $totalSizeMB MB

Backup succesvol afgerond.
"@

Set-Content -Path $manifestFile -Value $manifestContent
Write-Log "Manifestbestand aangemaakt op $manifestFile."

Write-Log "Backup proces voltooid."
