# Backup Script: Auto-backup NAS share to external drive
# Customize these variables:
$source       = "\\NAS\SharedFolder"    # Path to your shared NAS drive
$destDrive    = "E:"                    # External drive letter

$backupFolder = "$destDrive\backup"     # Backup folder on the external drive
$logFile      = "$destDrive\backup_log.txt"    # Log file at the drive root
$manifestFile = "$destDrive\manifest.txt"      # Manifest file at the drive root

# Get current date/time for logs/metadata
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Function to write messages to the log file
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Output $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "Backup process started."

# Remove existing backup folder if it exists
if (Test-Path $backupFolder) {
    Write-Log "Existing backup folder found. Removing $backupFolder."
    Remove-Item -Path $backupFolder -Recurse -Force
}

# Create a new backup folder
New-Item -ItemType Directory -Path $backupFolder | Out-Null
Write-Log "Created new backup folder at $backupFolder."

# Use Robocopy to mirror the source to the backup folder
$robocopyLog = "$destDrive\robocopy_log.txt"
Write-Log "Starting file copy with Robocopy."
$rc = robocopy $source $backupFolder /MIR /NP /LOG:$robocopyLog /NFL /NDL /NJH /NJS
Write-Log "Robocopy completed with exit code $rc."

# Generate a manifest file with backup metadata
Write-Log "Generating manifest file."
$files = Get-ChildItem -Path $backupFolder -Recurse -File
$fileCount = $files.Count
$totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [Math]::Round($totalSizeBytes / 1MB, 2)

$manifestContent = @"
Backup Manifest
---------------------
Backup Date: $date
Source: $source
Destination: $backupFolder
Number of Files: $fileCount
Total Size: $totalSizeMB MB

Backup completed successfully.
"@

Set-Content -Path $manifestFile -Value $manifestContent
Write-Log "Manifest file created at $manifestFile."

Write-Log "Backup process completed."
