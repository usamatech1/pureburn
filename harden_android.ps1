# Run once after:  flutter create . --platforms=android
# Turns off Android auto-backup so the weight and health data is not copied to cloud backups.
$m = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
if (-not (Test-Path $m)) {
  Write-Output 'AndroidManifest.xml nahi mila. Pehle chalayein: flutter create . --platforms=android'
  exit 1
}
$x = [System.IO.File]::ReadAllText($m)
if ($x -match 'android:allowBackup\s*=') {
  $x = $x -replace 'android:allowBackup\s*=\s*"[^"]*"', 'android:allowBackup="false"'
} else {
  $x = $x -replace '<application', '<application android:allowBackup="false"'
}
[System.IO.File]::WriteAllText($m, $x, (New-Object System.Text.UTF8Encoding $false))
Write-Output 'allowBackup=false set ho gaya.'
