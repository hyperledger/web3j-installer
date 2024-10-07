Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

# Pre-calculated SHA-256 checksum
$PreCalculatedChecksum = ""

# Function to calculate the current checksum excluding the checksum line
function Calculate-Checksum {
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptContent = Get-Content $scriptPath | Where-Object {$_ -notmatch '^\$PreCalculatedChecksum\s*='}
    $hash = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($scriptContent -join "`n"))
    $checksumBytes = $hash.ComputeHash($stream)
    return ($checksumBytes | ForEach-Object { $_.ToString("x2") }) -join ""
}

# Verify the integrity of the script
function Verify-Checksum {
    $currentChecksum = Calculate-Checksum
    if ($currentChecksum -eq $PreCalculatedChecksum) {
        Write-Output "Checksum verification passed."
    } else {
        Write-Output "Checksum verification failed. Script may have been altered."
        exit 1
    }
}

# Run checksum verification
Verify-Checksum

$web3j_version = (Invoke-WebRequest -Uri "https://api.github.com/repos/web3j/web3j-cli/releases/latest").Content | ConvertFrom-Json | Select-Object -ExpandProperty tag_name | ForEach-Object { $_.Substring(1) }

New-Item -Force -ItemType directory -Path "${env:USERPROFILE}\.web3j" | Out-Null
$url = "https://github.com/web3j/web3j-cli/releases/download/v${web3j_version}/web3j-cli-shadow-${web3j_version}.zip"
$output = "${env:USERPROFILE}\.web3j\web3j.zip"
Write-Output "Downloading Web3j version ${web3j_version}..."
Invoke-WebRequest -Uri $url -OutFile $output
Write-Output "Extracting Web3j..."
Expand-Archive -Path "${env:USERPROFILE}\.web3j\web3j.zip" -DestinationPath "${env:USERPROFILE}\.web3j\" -Force
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)

if (!($CurrentPath -match $web3j_version)) {
    [Environment]::SetEnvironmentVariable(
            "Path",
            $CurrentPath + ";${env:USERPROFILE}\.web3j\web3j-cli-shadow-${web3j_version}\bin",
            [EnvironmentVariableTarget]::User)
    Write-Output "Web3j has been added to your PATH variable. You will need to open a new CMD/PowerShell instance to use it."
}

Write-Output "Web3j has been successfully installed (assuming errors were printed to your console)."
