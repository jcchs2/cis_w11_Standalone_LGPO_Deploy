<#
.SYNOPSIS
    Deploys CIS Windows 11 Standalone GPOs to client machines
.DESCRIPTION
    Supports both local/network share (default) and GitHub download/unzip.
    Applies CIS LGPO baseline silently and tags version in registry.
.NOTES
    Run as Administrator
#>

# -----------------------------
# CONFIGURATION – Version 0.5
# -----------------------------

# =============================
# Option 1 – Local / Network Share (default)
# =============================
$LGPO_Source = "\\SERVER\Share\LGPO_30\LGPO.exe"      # Update to your network share
$Baseline_Source = "\\SERVER\Share\Baseline"          # Update to your network share

# =============================
# Option 2 – GitHub Download (commented out by default)
# =============================
<#
# If you plan to use GitHub download, do the following:
# 1. Uncomment this entire block
# 2. Comment out the network share copy section in Step 2 (below)
# 3. Update $GitHubUser and repository name in the URLs
$GitHubUser = "USER"  # Update to your GitHub username
$RepoName = "cis_w11_Standalone_LGPO_Deploy"

$LGPO_RawURL = "https://raw.githubusercontent.com/$GitHubUser/$RepoName/main/LGPO_30/LGPO.exe"
$Baseline_RawURL = "https://github.com/$GitHubUser/$RepoName/raw/main/Baseline.zip"

# Local paths on target machine for downloaded files
$LGPO_TargetFolder = "C:\Temp\LGPO\LGPO_30"
$Baseline_TargetFolder = "C:\Temp\LGPO\Baseline"
$BaselineZipPath = "C:\Temp\LGPO\Baseline.zip"
# Notes: Script will automatically download LGPO.exe and Baseline.zip, unzip Baseline, then apply GPOs
#>

# =============================
# Local target paths on client (used for both options)
# =============================
$LGPO_TargetFolder = "C:\Temp\LGPO\LGPO_30"
$Baseline_TargetFolder = "C:\Temp\LGPO\Baseline"

# Logging and deployment settings
$LogFile = "C:\Temp\LGPO\LGPO_Deploy.log"
$RebootAfter = $true
$BaselineVersion = "0.5"

# -----------------------------
# Prepare folders
# -----------------------------
New-Item -Path $LGPO_TargetFolder -ItemType Directory -Force | Out-Null
New-Item -Path $Baseline_TargetFolder -ItemType Directory -Force | Out-Null

# Logging function
function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Output "$timestamp - $Message"
}

Log "==============================="
Log "Starting CIS LGPO Deployment v$BaselineVersion"
Log "==============================="

# -----------------------------
# Step 1 – Clean up temp artifacts
# -----------------------------
Log "Cleaning temporary CIS/LGPO files..."
Remove-Item "C:\Windows\Temp\CIS*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Temp\CIS*" -Recurse -Force -ErrorAction SilentlyContinue
Log "Cleanup completed."

# -----------------------------
# Step 2 – Retrieve LGPO.exe and Baseline
# -----------------------------

# =============================
# Option 2 – GitHub Download (uncomment to use)
# =============================
# Notes: 
# 1. Uncomment this section if you plan to pull files from GitHub instead of \\SERVER\Share
# 2. Make sure to comment out Option 1 (network share copy) if using this method
# 3. The script will automatically download LGPO.exe and Baseline.zip, unzip the Baseline folder, and then apply the GPOs

# URL to raw LGPO.exe on GitHub
$LGPO_RawURL = "https://github.com/jcchs2/cis_w11_Standalone_LGPO_Deploy/raw/ecb4a73688a4edaaf041638aca9d53f0a7b17655/LGPO_30/LGPO.exe"

# URL to zip of Baseline folder on GitHub
$Baseline_RawURL = "https://github.com/jcchs2/cis_w11_Standalone_LGPO_Deploy/raw/ecb4a73688a4edaaf041638aca9d53f0a7b17655/Baseline.zip"

# Local target paths on the client machine
$LGPO_TargetFolder = "C:\Temp\LGPO\LGPO_30"
$Baseline_TargetFolder = "C:\Temp\LGPO\Baseline"
$BaselineZipPath = "C:\Temp\LGPO\Baseline.zip"

# Download LGPO.exe
Invoke-WebRequest -Uri $LGPO_RawURL -OutFile "$LGPO_TargetFolder\LGPO.exe" -UseBasicParsing
# Download Baseline.zip
Invoke-WebRequest -Uri $Baseline_RawURL -OutFile $BaselineZipPath -UseBasicParsing

# Unzip Baseline.zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($BaselineZipPath, $Baseline_TargetFolder)

# Remove the zip file after extraction
Remove-Item $BaselineZipPath -Force


# -----------------------------
# Option 1 – Network share (default)
# Keep this block active if you are using a local or network share
# Comment out this block if using GitHub download
# -----------------------------
Log "Copying LGPO.exe from network share..."
Copy-Item -Path $LGPO_Source -Destination $LGPO_TargetFolder -Recurse -Force
if (-not (Test-Path "$LGPO_TargetFolder\LGPO.exe")) {
    Log "ERROR: LGPO.exe not found after copy. Exiting."
    exit 1
}
Log "LGPO.exe copied successfully."

Log "Copying Baseline from network share..."
Copy-Item -Path $Baseline_Source -Destination $Baseline_TargetFolder -Recurse -Force
if (-not (Test-Path $Baseline_TargetFolder)) {
    Log "ERROR: Baseline folder not found after copy. Exiting."
    exit 1
}
Log "Baseline copied successfully."

# -----------------------------
# Step 3 – Import baseline silently
# -----------------------------
Log "Running LGPO import..."
Start-Process -FilePath "$LGPO_TargetFolder\LGPO.exe" `
    -ArgumentList "/g $Baseline_TargetFolder" `
    -WindowStyle Hidden -Wait
$LGPO_ExitCode = $LASTEXITCODE
Log "LGPO import completed with exit code $LGPO_ExitCode"

# -----------------------------
# Step 4 – Force Group Policy update
# -----------------------------
Log "Running gpupdate /force..."
Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -WindowStyle Hidden -Wait
Log "gpupdate completed."

# -----------------------------
# Step 5 – Tag baseline version in registry
# -----------------------------
Log "Tagging baseline version in registry..."
New-Item -Path "HKLM:\Software\CISBaseline" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\Software\CISBaseline" -Name "Version" -Value $BaselineVersion
Set-ItemProperty -Path "HKLM:\Software\CISBaseline" -Name "AppliedDate" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Log "Baseline version $BaselineVersion tagged successfully."

# -----------------------------
# Step 6 – Optional reboot
# -----------------------------
if ($RebootAfter) {
    Log "Rebooting machine to apply CIS policies..."
    Restart-Computer -Force
} else {
    Log "Deployment complete. Reboot skipped."
}

Log "==============================="
Log "CIS LGPO Deployment v$BaselineVersion Finished"
Log "==============================="
