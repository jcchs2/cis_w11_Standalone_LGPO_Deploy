# CIS Windows 11 Standalone LGPO Deployment

This repository contains all files required to deploy the CIS Level 1 benchmark to Windows 11 standalone/workgroup machines using LGPO.exe.

## Contents

- `LGPO_30/` - Contains LGPO.exe (Microsoft Security Compliance Toolkit 1.0)  
- `Baseline/` - Gold baseline exported from a fully compliant test machine (CIS Level 1, 100% score)

## Deployment

Use the PowerShell deployment script (`Deploy-CIS-LGPO.ps1`) to:

1. Download LGPO.exe and Baseline from GitHub
2. Import the baseline silently
3. Force Group Policy update
4. Tag the machine with baseline version and applied date
5. Optionally reboot

### Deployment Script Example

```powershell
# Example command to run deployment script
.\Deploy-CIS-LGPO.ps1
