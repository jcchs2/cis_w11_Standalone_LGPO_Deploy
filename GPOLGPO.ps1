<#
.SYNOPSIS
    Deploys all CIS Windows 11 GPO backups to a standalone/workgroup machine
.DESCRIPTION
    Applies all CIS benchmark GPO categories to get the machine to 100% compliance
.NOTES
    Run as Administrator
#>

# Configuration
$CISBasePath = "C:\Temp\Windows11Stand-alone4.0.0"
$LogPath = "C:\Temp\CIS_Deployment.log"

# Start logging
Start-Transcript -Path $LogPath -Append
Write-Host "Starting CIS GPO Deployment..." -ForegroundColor Green
Write-Host "CIS Source: $CISBasePath" -ForegroundColor Yellow
Write-Host "Log File: $LogPath" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan

# Verify LGPO.exe is available
$LGPO_PATH = "C:\Temp\LGPO\LGPO_30\LGPO.exe"
if (!(Test-Path $LGPO_PATH)) {
    Write-Host "ERROR: LGPO.exe not found at $LGPO_PATH" -ForegroundColor Red
    exit 1
}

# CIS GPO Categories to apply (only LEVEL1)
$CISCategories = @(
    @{Name = "COMPUTER_LEVEL1"; Path = "COMP-L1"},
    @{Name = "SERVICES_LEVEL1"; Path = "SERVICES-L1"},
    @{Name = "BITLOCKER"; Path = "BITLOCKER"},
    @{Name = "USER_LEVEL1"; Path = "USER-L1"}
)

# Function to apply GPO backup
function Apply-GPOBackup {
    param(
        [string]$CategoryName,
        [string]$GPOPath
    )
    
    Write-Host "Applying $CategoryName GPO..." -ForegroundColor Green
    Write-Host "GPO Path: $GPOPath" -ForegroundColor Gray
    
    if (Test-Path $GPOPath) {
        try {
            # Apply GPO using /g switch ONLY (no backup during import)
            $Arguments = "/g `"$GPOPath`""
            Write-Host "Running: LGPO.exe $Arguments" -ForegroundColor Gray
            
            $Process = Start-Process -FilePath $LGPO_PATH -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
            
            if ($Process.ExitCode -eq 0) {
                Write-Host "SUCCESS: $CategoryName applied successfully" -ForegroundColor Green
                return $true
            } else {
                Write-Host "FAILED: $CategoryName failed with exit code $($Process.ExitCode)" -ForegroundColor Red
                return $false
            }
        }
        catch {
            Write-Host "ERROR applying $CategoryName : $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "GPO path not found: $GPOPath" -ForegroundColor Red
        return $false
    }
}

# Main deployment sequence
Write-Host "Starting GPO deployment sequence..." -ForegroundColor Cyan
$SuccessCount = 0
$TotalCount = $CISCategories.Count

foreach ($Category in $CISCategories) {
    $CategoryPath = Join-Path $CISBasePath $Category.Path
    
    if (Test-Path $CategoryPath) {
        # Find the GPO backup folder (the one with GUID name)
        $GPOFolders = Get-ChildItem -Path $CategoryPath -Directory | Where-Object { $_.Name -match '^{[A-F0-9-]+}$' }
        
        if ($GPOFolders) {
            $GPOFolder = $GPOFolders[0].FullName
            if (Apply-GPOBackup -CategoryName $Category.Name -GPOPath $GPOFolder) {
                $SuccessCount++
            }
        } else {
            Write-Host "No GPO backup folder found in $CategoryPath" -ForegroundColor Red
        }
    } else {
        Write-Host "Category path not found: $CategoryPath" -ForegroundColor Red
    }
}

# Final summary
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Green
Write-Host "Successfully applied: $SuccessCount of $TotalCount categories" -ForegroundColor Yellow

if ($SuccessCount -eq $TotalCount) {
    Write-Host "ALL CIS GPOs applied successfully!" -ForegroundColor Green
} else {
    Write-Host "Some GPOs failed to apply. Check log at $LogPath" -ForegroundColor Yellow
}

# Force group policy update
Write-Host "Forcing Group Policy update..." -ForegroundColor Cyan
gpupdate /force

Write-Host "Deployment completed! Run CIS CAT assessment to verify compliance." -ForegroundColor Green
Write-Host "Log file: $LogPath" -ForegroundColor Gray

Stop-Transcript