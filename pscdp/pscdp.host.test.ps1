Add-Type -AssemblyName System.Net.Http

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


Write-Host "Subscribing to channel '$Channel' on PubNub..." -ForegroundColor Cyan

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [System.TimeSpan]::FromSeconds(310)

$receiveNewTask = $true


$listenJob = Start-ThreadJob -ScriptBlock {

    while ($runlisten) {
        Invoke-RestMethod -Uri $receiveUrl -Method Get -TimeoutSec 310
    }

}


while ($true) {
    Write-Host "new iteration..."

    if ( $receiveNewTask ) {
        Write-Host "receiving on $receiveUrl"
        
        $task = [System.Threading.Tasks.Task]::Run([Action]{
            return Invoke-RestMethod -Uri $receiveUrl -Method Get -TimeoutSec 310
        })

        $receiveNewTask = $false
    }

    if ($task.IsCompleted) {
        Write-Host "...receive complete"

        $receiveNewTask = $true
    
        $responseMessage = $task.Result
        if ( $null -eq $responseMessage ) {
            Write-Host "null response"
        } elseif ( $null -eq $responseMessage.Content ) {
            Write-Host "null response"
        } else {
            $jsonContent = $responseMessage.Content.ReadAsStringAsync().Result
        }

        $ret = $jsonContent | Out-String

        if ( [String]::IsNullOrEmpty($ret ) ) {
            Write-Host "empty response"
        }
    }

    Start-Sleep -Milliseconds 1000
}
