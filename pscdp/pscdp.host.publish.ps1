$PublishKey = "pub-c-a00eaad9-c35e-4a41-bd62-cdc619a6f2cc"
$SubscribeKey = "sub-c-94ed1e1c-a765-4fd9-ba9e-f8ebbb47f5bd"
$Channel = "clientid_88992233_JS_client"
$UUID     = "powershell_client_" + (New-Guid).Guid.Substring(0,8) # Required uniquely generated ID
$BaseUrl  = "ps.pndsn.com"

$PayloadData = @{
    sender = "PowerShell_Script"
    message = "Hello from PowerShell!"
    timestamp = (Get-Date -UFormat %s)
} | ConvertTo-Json -Compress

$BodyJson = $PayloadData | ConvertTo-Json -Compress

$Uri = "https://${BaseUrl}/publish/${PublishKey}/${SubscribeKey}/0/${Channel}/0"

$Response = Invoke-RestMethod -Uri $Uri -Method Post -Body $BodyJson -ContentType "application/json; charset=UTF-8"

$Response | Out-String | Write-Host

