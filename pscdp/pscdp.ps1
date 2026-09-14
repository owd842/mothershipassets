<# https://zenn.dev/mima_ita/articles/f1fc037e6eb134 #>

$script:targets = $null
$script:wsUri = $null
$script:messageId = 1
$script:cts = New-Object System.Threading.CancellationTokenSource
$script:webSocket = $null
$script:connectTask = $null
$script:sessionId = $null
$script:logmsgs = [System.Collections.Concurrent.ConcurrentStack[string]]::new()
$script:responses = [System.Collections.Concurrent.ConcurrentStack[object]]::new()
$script:commands = [System.Collections.Concurrent.ConcurrentStack[object]]::new()
$script:sendQueue = [System.Collections.Concurrent.BlockingCollection[object]]::new()

$script:pipeServer = $null
$script:pipeName = "PowerShellPipe"
$script:reader = $null
$script:writer = $null

function Connect-Pipe {
    $script:pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
        $pipeName, 
        [System.IO.Pipes.PipeDirection]::InOut,
        -1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte, 
        [System.IO.Pipes.PipeOptions]::Asynchronous
    )

    Write-Host "Waiting for a client to connect on pipe: $pipeName..."
    $script:pipeServer.WaitForConnection()
    Write-Host "Client connected!"

    # 2. Set up Reader and Writer streams
    $script:reader = New-Object System.IO.StreamReader($pipeServer)
    $script:writer = New-Object System.IO.StreamWriter($pipeServer)
    $script:writer.AutoFlush = $true # Sends data immediately without buffering
}

function Send-Pipe {
    param(
        [hashtable]$Messge
    )

    $jsonResponse = ConvertTo-Json $Messge -Compress
    $writer.WriteLine($jsonResponse)
    Write-host "Sent response to client." -ForegroundColor Green
}

function Receive-Pipe {
    try {
        # 1. Receive JSON string from client
        $jsonReceived = $reader.ReadLine()
        
        # 2. Convert JSON back into a PowerShell Object/Hashtable
        $dataReceived = ConvertFrom-Json $jsonReceived -AsHashtable
        write-host "Received data from client:" -ForegroundColor Cyan
        $dataReceived | Out-String | Write-Host

        $response = @{
            Status    = "Success"
            Message   = "Data processed successfully"
            Timestamp = (Get-Date).ToString("o")
            EchoId    = $dataReceived.Id
        }
    
        Send-Pipe($response)

    } catch {

    }
}

function Connect-Cdp {
    # $targets | Select-Object title, id, webSocketDebuggerUrl
    $script:targets = Invoke-RestMethod -Uri "http://localhost:9223/json"
    $script:wsUri = ($targets | Where-Object { $_.type -eq "page" } | Select-Object -First 1).webSocketDebuggerUrl

    if ( $null -eq $webSocket ) {
        # Write-Host "connecting to cdp on [$wsUri]"
    } else {
        Write-Host "reconnecting to cdp on [$wsUri]"
    }

    $script:webSocket = New-Object System.Net.WebSockets.ClientWebSocket
    $script:connectTask = $webSocket.ConnectAsync($wsUri, $cts.Token)
    $script:connectTask.Wait()
    
    Write-Host "Connected! Current WebSocketState: $($webSocket.State)" -ForegroundColor Green
}
function Get-Timestamp {
    $ret = Get-Date -Format "HH:mm:ss.fff"
    return $ret
}
function Send-CdpCommand {
    param(
        [object]$WebSocket = $script:webSocket,
        [string]$Method,
        [hashtable]$Params = @{},
        [string]$SessionID = $null
    )
    
    if ($WebSocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        $logmsgs.Push("Cannot send command. WebSocket is not Open (State: $($WebSocket.State))")
        return $null
    }

    $id = $script:messageId++
    $obj = @{
        id     = $id
        method = $Method
        params = $Params
    }

    if (! [string]::IsNullOrEmpty($SessionID)) {
        $obj.Add("sessionId", $SessionID)
    }

    $payload = $obj | ConvertTo-Json -Depth 10 -Compress

    $commands.Push($obj)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $buffer = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)

    if (! $WebSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
        throw "web socket is not open"
    }

    try {
        $sendTask = $WebSocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $script:cts.Token)
        
        if ( $null -ne $sendTask ) {
            $result = $sendTask.GetAwaiter().GetResult()
        } else {
            throw "fatal error -- task is null"
        }
    } catch {
        Write-Error $_.Exception.Message
        return $null
    } 

    Write-Host "Sent Command [$id]: $Method" -ForegroundColor Cyan

    return $id
}
function Receive-CdpMessage {
    param(
        [int]$Timeout = 1000,
        [bool]$LogOut = $true
    )
   
    Write-Host "waiting for message... $(Get-Timestamp)"

    $bufferSize = 4096
    $byteArray = [byte[]]::new($bufferSize)
    $memoryStream = New-Object System.IO.MemoryStream
    
    if ( ! $webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open ) {
        $logmsgs.Push('websocket is not open')
        return $null
    }

    $totalbytecount = 0
    do {

        $segment = [ArraySegment[byte]]::new($byteArray)
        $task = $webSocket.ReceiveAsync($segment, [System.Threading.CancellationToken]::None)

        $result = $task.GetAwaiter().GetResult()
        
        if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
            throw "WebSocket connection closed by the remote host."
        }
        
        if (-not $task.IsCompleted) {
            throw "fatal error -- should always be IsCompleted"
        }

        if ($task.IsFaulted) {
            throw "[X2H2] Receive failed: $($task.Exception.InnerException.Message)"
        }
        elseif ($task.IsCanceled) {
            throw "[A2O9] Receive operation was cancelled."
        }
        else {

            if ( ! ( $task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion ) ) {
                throw "task Status != RanToCompletion"
            }

            $result = $task.Result

            $bytesReceived = $result.Count
            
            $logmsgs.Push("...received $bytesReceived bytes")
            
            if ($result.Count -gt 0) {
                $memoryStream.Write($byteArray, 0, $result.Count)

                $totalbytecount = $totalbytecount + $result.Count
                $logmsgs.Push("...total bytes $totalbytecount")
            }

        }

    } while (-not $result.EndOfMessage)

    $completeBytes = $memoryStream.ToArray()
    $json = [System.Text.Encoding]::UTF8.GetString($completeBytes)
    
    if ( $LogOut ) {
        $logmsgs.Push($json)
    }

    try {
        $msg = $json | ConvertFrom-Json
        $script:responses.Push($msg)
        return $msg
    } catch {
        $logmsgs.Push("ConvertFrom-Json Exception: $($_.Exception.Message)")
    }

    return $null
}
function Load-Queue {
    # $sendQueue.Add( @{ method="Log.enable"; params=@{ enabled = $true } } )
    $sendQueue.Add( @{ method="Page.enable"; params=@{ enabled = $true } } )
    $sendQueue.Add( @{ method="Page.setLifecycleEventsEnabled"; params=@{ enabled = $true } } )
    $sendQueue.Add( @{ method="DOM.enable"; params=@{ enabled = $true } } )
    $sendQueue.Add( @{ method="Runtime.enable"; params=@{ enabled = $true } } )
    $sendQueue.Add( @{ method="Overlay.enable"; params=@{ enabled = $true } } )

    $params = @{
        autoAttach = $true
        waitForDebuggerOnStart = $false
        flatten = $true
    }
    $sendQueue.Add( @{ method="Target.setAutoAttach"; params=$params } )


    $params = @{
        url = "https://www.yahoo.com"
        newWindow = $false
        # browserContextId = $null
        # "width": 10,
        # "height": 10,
        # // "left": 2000,
        # "top": 2000
        # #"windowState": "minimized"
        # #"hidden": True --> has problems/issues
    }
    $sendQueue.Add( @{ method="Target.createTarget"; params=$params } )

    $sendQueue.Add( @{ method="Target.getTargets" } )
}

function Get-Response {
    param($CmdID)

    $id = $CmdID

    $response = $script:responses | Where-Object { $_.id -eq $id }
    
    if ( $null -eq $response ) {
        return $null
    }

    return $response
}

Load-Queue

Connect-Cdp

$bufferSize = 4096
$receiveNew = $true
$memoryStream = New-Object System.IO.MemoryStream

$create_target_callback = {
    param([object]$Response)

    $targetInfo = $Response.result.targetInfos | Where-Object { $_.type -eq "page" -and ( $_.title.Contains("Yahoo!") -or $_.url.Contains("yahoo") ) } | Select-Object -First 1

    if ( $null -eq $targetInfo ) {
        return $null
    }

    $params = @{ 
        targetId=$targetInfo.targetId 
        flatten=$true 
    }

    $sendQueue.Add( @{ method="Target.attachToTarget"; params=$params } )
}

$process_create_target = $true
$init_session_id = $true

while ( $true ) {

    Write-Host "new iteration"

    if ( ! $webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open ) {
        throw 'websocket is not open'
    }

    if ( $receiveNew ) {
        $byteArray = [byte[]]::new($bufferSize)
        $segment = [ArraySegment[byte]]::new($byteArray)                

        $task = $webSocket.ReceiveAsync($segment, [System.Threading.CancellationToken]::None)
        $receiveNew = $false
    }

    if ( $task.IsCompleted ) {

        Write-Host "...waiting for result"

        $result = $task.GetAwaiter().GetResult()

        $receiveNew = $true

        if ($result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
            throw "WebSocket connection closed by the remote host."
        }
        elseif ($task.IsFaulted) {
            throw "[X2H2] Receive failed: $($task.Exception.InnerException.Message)"
        }
        elseif ($task.IsCanceled) {
            throw "[A2O9] Receive operation was cancelled."
        }
        elseif ( ! ( $task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion ) ) {
            throw "task Status != RanToCompletion"
        } else {

            $bytesReceived = $result.Count
            
            Write-Host "...received $bytesReceived bytes"
            
            if ($bytesReceived -gt 0) {
                $memoryStream.Write($byteArray, 0, $bytesReceived)

                $totalbytecount = $totalbytecount + $bytesReceived
                Write-Host "...total bytes $totalbytecount"
            }

        }
    }

    if ( $result.EndOfMessage) {

        $completeBytes = $memoryStream.ToArray()
        
        if ( $completeBytes -gt 0 ) {
            $json = [System.Text.Encoding]::UTF8.GetString($completeBytes)
            $memoryStream = New-Object System.IO.MemoryStream
            $totalbytecount = 0

            try {
                $msg = $json | ConvertFrom-Json
                $script:responses.Push($msg)
            } catch {
                Write-Error "ConvertFrom-Json Exception: $($_.Exception.Message)"
            }
        }

    }

    if ( ( ! $sendQueue.IsCompleted ) -and ( $sendQueue.Count -gt 0 ) ) {

        Write-Host ( "sending cmd -- cmds: " + $sendQueue.Count )

        $cmd = $sendQueue.Take()

        $jsonString = $cmd | ConvertTo-Json
        Write-Host "new cmd: $($jsonString) $(Get-Timestamp)"
        
        $tparams = @{ Method=$cmd.method }

        if ( $cmd.ContainsKey("params") ) {
            $tparams['Params'] = $cmd.params
        }

        if ( $cmd.ContainsKey("SessionID") ) {
            $tparams['SessionID'] = $cmd['SessionID']
        }

        Send-CdpCommand @tparams
    } 
    
    if ( $process_create_target ) {
        $response = Get-Response(8)

        if ( $null -ne $response ) {
            & $create_target_callback -Response $response
            $process_create_target = $false
        }
    }

    if ( $init_session_id ) {
        $response = Get-Response(9)

        if ( $null -ne $response ) {
            $script:sessionId = $response.result.sessionId

            $init_session_id = $false

            if ( $null -ne $script:sessionId ) {
                Write-Host $script:sessionId

                $sendQueue.Add( @{ method="Page.navigate"; params=@{ url = "https://www.investing.com" }; SessionID=$sessionId } )
            }
        }
    }

    Write-Host "...sleeping"

    Start-Sleep -Milliseconds 50
}



exit


<#
if ( $null -eq $readtask ) {
    $readbuf = [byte[]]::new($bufferSize)
    $readtask = $reader.ReadAsync($readbuf, 0, $bufferSize, [System.Threading.CancellationToken]::None)
}

if ( $null -ne $readtask -and $readtask.IsCompleted ) {
    $bytesRead = $readTask.GetAwaiter().GetResult()
    $message = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)
    $hashobj = ConvertFrom-Json -InputObject $message -AsHashtable
    $sendQueue.Add($hashobj)
    $readtask = $null
}
#>