# Script file to create tmp directory in windows nodes

param (
    [ValidateSet("docker","containerd")][string]$runtime = "docker"
)

mkdir c:\tmp

$pullCmd = "docker pull"
if ( $runtime -eq "containerd") {
    $pullCmd = "c:\k\ctr.exe --namespace k8s.io image pull"
}

Write-Host "Disable monitoring"
Set-MpPreference -DisableRealtimeMonitoring $true

Write-Host "Prepulling all test images"

iex "$pullCmd docker.io/e2eteam/busybox:1.29"

[System.Environment]::SetEnvironmentVariable('DOCKER_API_VERSION', "1.39", [System.EnvironmentVariableTarget]::Machine)
