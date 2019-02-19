# Script file to create tmp directory in windows nodes

Write-Host "Prepulling all test images"


wget https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/images/Utils.ps1 -UseBasicParsing -OutFile Utils.ps1
wget https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/images/PullImages.ps1 -UseBasicParsing -OutFile PullImages.ps1

./PullImages.ps1
