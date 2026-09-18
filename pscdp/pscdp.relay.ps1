# 20260917

<# https://zenn.dev/mima_ita/articles/f1fc037e6eb134 #>

# $ta = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')

# ungoogled chromium
# start chrome.exe --remote-debugging-port=9223 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=*
# https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub
# --headless=new
# --auto-open-devtools-for-tabs
# --remote-debugging-address=0.0.0.0
# --remote-allow-origins=* 
# --force-devtools-available
# frontend.appspot.com

$script:logger_logmsg_i = 0
function Log-Msg {
    param([string]$Msg)

    $caller = (Get-PSCallStack)[0].FunctionName

    if ( (Get-PSCallStack).length -gt 1 ) {
        $caller = (Get-PSCallStack)[1].FunctionName
    }

    $script:logger_logmsg_i++

    Write-Host "$caller|$script:logger_logmsg_i|$Msg"
}

function Get-Timestamp {
    $ret = Get-Date -Format "HH:mm:ss.fff"
    return $ret
}


$script:msedge_debugport = 9222
$script:chrome_debugport = 9223


class PSCDPCommand {
    [string]$name
    [int32]$id
    [string]$method
    [hashtable]$params
    [object]$response
    [string]$sessionId
    [scriptblock]$callback
    [bool]$isinvoked = $false

    [bool]HasCallback() {
        return ( $null -ne $this.callback )
    }

    [hashtable] GetDict() {

        if ( [string]::IsNullOrWhiteSpace($this.method) ) {
            throw 'method is missing'
        }

        $obj = @{
            id=$this.id
            method=$this.method
        }

        if ( $null -ne $this.params ) {
            $obj.Add('params', $this.params)
        }

        if ( ! [string]::IsNullOrWhiteSpace($this.sessionId) ) {
            $obj.Add('sessionId', $this.sessionId)
        }

        return $obj
    }

    [void] SetID([int32]$id) {
        $this.id = $id
    }

    [void] SetSessionID([string]$sessionId) {
        $this.sessionId = $sessionId
    }

    [void] SetResponse([object]$response) {
        $this.response = $response
    }

    [string] ToJSON() {
        $obj = $this.GetDict() 
        $jsonstr = $obj | ConvertTo-Json -Depth 10 -Compress
        return $jsonstr
    }
}

class PSCDPResponse {

}

class PSCDPTarget {
    [string]$title
    [string]$url
    [string]$id
    [string]$sessionId
    [string]$type
    [string]$description

    static [PSCDPTarget] FindTarget([System.Collections.Generic.List[PSCDPTarget]]$targets, [string]$id=$null, [string]$title=$null, [string]$url=$null) {

        foreach ($target in $targets) {
            if ( $target.url -eq $url ) {
                return $target
            }
        }
        
        return $null
    }

}

$script:init_sessionid_action = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cdpobj.sessionId = $Response['result'].sessionId
}

$script:get_targets_action = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $url = 'orgfarm-bd12a2161b-dev-ed'

    # $_.title.Contains("Yahoo!")
    $targetInfo = $Response.result.targetInfos | Where-Object { $_.type -eq "page" -and ( $_.url.Contains($url) ) } | Select-Object -First 1

    if ( $null -eq $targetInfo ) {
        return $null
    }

    $params = @{ 
        targetId=$targetInfo.targetId 
        flatten=$true 
    }

    $cdpobj.sendQueue.Add( @{ method="Target.attachToTarget"; params=$params; callback=$init_sessionid_action } )

}

class PSCDP {

    $debugport = 9223
    $wsUri = $null
    $websocket = $null

    $sendQueue = [System.Collections.Concurrent.BlockingCollection[object]]::new()
    $responses = [System.Collections.Generic.List[object]]::new()
    $commands = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $results = [System.Collections.Generic.List[object]]::new()

    [int32]$messageId = 1
    $receiveNew = $true
    $byteArray = $true
    $segment = $true
    $task = $true
    $bufferSize = 4096
    $memoryStream
    $totalbytecount = 0
    $result = $null

    $sessionId = $null
    $initpage = $null

    [void] CheckSocket() {

        if ( $this.IsSocketHealthy() ) {
            return
        }

        if ( $null -eq $this.webSocket ) {
            throw "websocket is null"
        }

        if ( ! $this.webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open ) {
            throw 'websocket is not open'
        }
        
    }

    [bool] IsSocketHealthy() {
        if ( ( ! $null -eq $this.webSocket ) -and ( $this.webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open ) ) {
            return $true
        }

        return $false
    }

    [void] init() {
        $this.memoryStream = New-Object System.IO.MemoryStream
        $this.debugport = 9223
    }

    PSCDP() {
        $this.init()
    }

    PSCDP($debugport) {
        $this.init()
        $this.debugport = $debugport
    }

    PSCDP($debugport, $initpage) {
        $this.init()
        $this.debugport = $debugport
        $this.initpage = $initpage
    }

    [string] GetWSUrI() {

        if (! [string]::IsNullOrWhiteSpace($this.wsUri)) {
            return $this.wsUri
        }

        $targets = $this.GetTargets()

        $this.wsUri = ($targets | Where-Object { $_.type -eq "page" } | Select-Object -First 1).webSocketDebuggerUrl
        
        return $this.wsUri
    }

    # TODO refactor to PSCDPTarget
    [object] GetTargets() {
        $targets = Invoke-RestMethod -Uri "http://localhost:$($this.debugport)/json"

        # $targets | Select-Object title, id, webSocketDebuggerUrl

        return $targets
    }

    [void] ConnectCdp() {
        Log-Msg "new CDP connection at $($this.debugport)"

        $this.wsUri = $this.GetWSURI()

        if ( $null -eq $this.websocket ) {
            Log-Msg "connecting to cdp on [$($this.wsUri)]"
        } else {
            Log-Msg "reconnecting to cdp on [$($this.wsUri)]"
        }
    
        $this.websocket = New-Object System.Net.WebSockets.ClientWebSocket
        $connectTask = $this.websocket.ConnectAsync($this.wsUri, [System.Threading.CancellationToken]::None)

        if ( $null -eq $this.websocket) {
            throw "could not connect"
        }

        $connectTask.Wait()
        
        Log-Msg "Connected! Current WebSocketState: $($this.websocket.State)" -ForegroundColor Green
    }

    [PSCDPCommand] GetCommandByID([string]$id) {
        $cmd = $this.commands | Where-Object { $_.id -eq $id } | Select-Object -First 1
        return $cmd
    }

    [PSCDPCommand] GetCommand([string]$name) {
        $cmd = $this.commands | Where-Object { $_.name -eq $name } | Select-Object -First 1
        return $cmd
    }

    [object] GetResultByID($id) {
        $cmd = $this.GetCommandByID($id)

        if ( $null -eq $cmd ) {
            return $null
        }

        return $this.GetResultByCmd($cmd)
    }

    [object] GetResultByCmd([PSCDPCommand]$cmd) { #TODO refactor to return PSCDPResponse object
        try {
            $id = $cmd.id

            if ( ( $null -eq $this.results ) -or ( $this.results.Count -le 0 ) ) {
                return $null
            }

            $arr = $this.results.ToArray()
            for ($i = 0; $i -lt $arr.Count; $i++) {
                $t = $arr[$i]

                if ( ($t.id).ToString() -eq ($id).ToString() ) {
                    return $t
                }

            }
            
            return $null
        } catch {
            Write-Error $_.Exception.Message
        }

        return $null
    }

    [object] GetResult([string]$cmdname) { #TODO refactor to return PSCDPResponse object

        $cmd = $this.GetCommand($cmdname)

        if ( $null -eq $cmd ) {
            return $null
        }

        return $this.GetResultByCmd($cmd)
    }

    [PSCDPCommand] SendCdpCommand([hashtable]$cmd) {
        return $this.SendCdpCommand($cmd,$null)
    }

    [PSCDPCommand] SendCdpCommand([hashtable]$cmd, [string]$sessionID) {
        
        if ( $null -eq $this.websocket ) {
            throw "websocket is null"
        }

        if ($this.websocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            throw "Cannot send command. WebSocket is not Open (State: $($this.websocket.State))"
        }

        $id = $this.messageId++

        $cmd.Add('id', $id)

        if (! [string]::IsNullOrEmpty($sessionID)) {
            $cmd.Add("sessionId", $SessionID)
        }
        
        $obj = [PSCDPCommand]$cmd
        
        $this.commands.Add($obj)

        $payload = $obj.ToJson() 
    
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $buffer = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
    
        if (! $this.websocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            throw "web socket is not open"
        }
    
        try {
            $sendTask = $this.websocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
            
            if ( $null -ne $sendTask ) {
                $tresult = $sendTask.GetAwaiter().GetResult()
            } else {
                throw "fatal error -- task is null"
            }
        } catch {
            Write-Error "[J7E3]: $($_.Exception.Message)"
            return $null
        } 
    
        $method = ""
        if ( $cmd.ContainsKey('method') ) {
            $method = $cmd['method']
        }

        Log-Msg "Sent Command [$id]: $method" -ForegroundColor Cyan
    
        return $obj
    }
    
    [void] InitReceive() {
        if ( ! $this.receiveNew ) {
            Log-Msg "... existing receive in progress"
            return
        }

        Log-Msg "...kicking off new receive"
        $this.byteArray = [byte[]]::new($this.bufferSize)
        $this.segment = [ArraySegment[byte]]::new($this.byteArray)                

        $this.task = $this.webSocket.ReceiveAsync($this.segment, [System.Threading.CancellationToken]::None)
        $this.receiveNew = $false
    }

    [void] ReadMessage() {
        if ( ! $this.task.IsCompleted ) {
            Log-Msg "... receive not completed -- skipping"
            return
        }

        Log-Msg "...waiting for result"

        $this.result = $this.task.GetAwaiter().GetResult()

        $this.receiveNew = $true

        if ($this.result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
            throw "WebSocket connection closed by the remote host."
        }
        elseif ($this.task.IsFaulted) {
            throw "[X2H2] Receive failed: $($this.task.Exception.InnerException.Message)"
        }
        elseif ($this.task.IsCanceled) {
            throw "[A2O9] Receive operation was cancelled."
        }
        elseif ( ! ( $this.task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion ) ) {
            throw "task Status != RanToCompletion"
        } else {

            $bytesReceived = $this.result.Count
            
            Log-Msg "...received $bytesReceived bytes"
            
            if ($bytesReceived -gt 0) {
                $this.memoryStream.Write($this.byteArray, 0, $bytesReceived)

                $this.totalbytecount = $this.totalbytecount + $bytesReceived
                Log-Msg "...total bytes $($this.totalbytecount)"
            }

        }
    }

    [void] EndMessage() {
        if ( ! $this.result.EndOfMessage) {
            Log-Msg "... messge is not complete -- skipping"
            return
        }

        $completeBytes = $this.memoryStream.ToArray()

        Log-Msg "...message is complete"

        if ( $completeBytes.count -le 0 ) {
            Log-Msg "empty message -- skipping"
            return
        }

        $json = [System.Text.Encoding]::UTF8.GetString($completeBytes)
        $this.memoryStream = New-Object System.IO.MemoryStream
        $this.totalbytecount = 0

        if ( [string]::IsNullOrWhiteSpace($json) ) {
            return
        }

        try {
            $msg = $json | ConvertFrom-Json # TODO refactor to use PSCDPResponse
            
            $isresult = $false
            $newtarget = $false

            $msght = @{}
            $msg.psobject.Properties | ForEach-Object {
                
                if ( $_.Name -eq "result" ) {
                    $isresult = $true
                } elseif ( $_.Name -eq "method" )  {
                    if ( $_.Value -eq 'Target.attachedToTarget' ) {
                        $newtarget = $true
                    }
                }

                $msght[$_.Name] = $_.Value
            }

            <#
                "method": "Target.attachedToTarget",
                "params": {
                    "sessionId": "A4B7D2E9F83C1D062E5F4A7B890C12D3",
                    "targetInfo": {
                        "targetId": "8FA2C3E4D5B6A7F8E90123456789ABCD",
                        "type": "page",
            #>
            $this.responses.Add($msght)

            # check if new target attached, get sessionid
            if ( $newtarget ) {
                if ( $msght['params'].Value.targetInfo.type -eq "page" ) {
                    $this.sessionId = $msght['params']['sessionId']
                }
            }

            # check if msg is a response to an issued cmd
            if ( $isresult ) {
                $cmd = $this.GetCommandByID($msg.id) # $this.commands | Where-Object { $id -eq $msg.result.id } | Select-Object -First 1 # anchor
            
                if ( $null -ne $cmd ) {
                    $cmd.response = $msght
                }

                $this.results.Add($msght)
            }

        } catch {
            Write-Error "ConvertFrom-Json Exception: $($_.Exception.Message)"
        }
    
    }
    
    [void] NextCmd() {

        if ( $this.sendQueue.IsCompleted -or ( $this.sendQueue.Count -le 0 ) ) {
            return
        }

        Log-Msg ( "sending cmd -- cmds count: " + $this.sendQueue.Count )

        $cmd = $this.sendQueue.Take()
        $cmd = $this.SendCdpCommand($cmd)
    }

    [void] ExecCallbacks() {

        for ( $i = 0; $i -lt $this.commands.Count; $i++) {
            $cmd = $this.commands[$i]

            if ( $cmd.HasCallback() -and ( ! $cmd.isinvoked ) -and ( $null -ne $cmd.response) ) {
                $cmd.callback.Invoke($cmd.response,$this)
                $cmd.isinvoked = $true
            }

        }

    }

    # Runtime.addBinding
    #   "params": {
    # "name": "pubnub_binding"

    # Runtime.bindingCalled
    <#
    {
    "method": "Runtime.bindingCalled",
    "params": {
        "name": "pubnub_binding",
        "payload": "{\"channel\":\"chat-room\",\"message\":\"Hello from the webpage!\"}",
        "executionContextId": 1
    }
    }
    #>

    [void] LoadQueue() {
        $this.sendQueue.Add( @{ method="Page.enable"; params=@{ enabled = $true } } )
        $this.sendQueue.Add( @{ method="Page.setLifecycleEventsEnabled"; params=@{ enabled = $true } } )
        $this.sendQueue.Add( @{ method="DOM.enable"; params=@{ enabled = $true } } )
        $this.sendQueue.Add( @{ method="Runtime.enable"; params=@{ enabled = $true } } )
        $this.sendQueue.Add( @{ method="Overlay.enable"; params=@{ enabled = $true } } )
    
        $params = @{
            autoAttach = $true
            waitForDebuggerOnStart = $false
            flatten = $true
        }
        $this.sendQueue.Add( @{ method="Target.setAutoAttach"; params=$params } )
    
        if ( [string]::IsNullOrWhiteSpace($this.initpage) ) {

            $params = @{
                url = $this.initpage
                newWindow = $false
                # browserContextId = $null
                # "width": 10,
                # "height": 10,
                # // "left": 2000,
                # "top": 2000
                # #"windowState": "minimized"
                # #"hidden": True --> has problems/issues
            }

            $this.sendQueue.Add( @{ name="navigate_init_page"; method="Target.createTarget"; params=$params } )
        }

        $this.sendQueue.Add( @{ method="Target.getTargets"; callback=$script:get_targets_action })

        $this.sendQueue.Add( @{ method="Runtime.addBinding"; params=@{ name="pubnub_binding" }; addsessionid=$true } )
 }

$script:pubnubws = [PSCDP]::new($script:msedge_debugport)
$script:pubnubws.initpage = "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub"
$script:pubnubws.LoadQueue()
$script:pubnubws.ConnectCdp()

#$script:pubnubws = [PSCDP]::new()
#$script:pubnubws.ConnectCdp()


while ( $true ) {

    Log-Msg "new iteration"

    $script:pubnubws.CheckSocket()

    $script:pubnubws.InitReceive()
    $script:pubnubws.ReadMessage()
    $script:pubnubws.EndMessage()

    $script:pubnubws.ExecCallbacks()
    $script:pubnubws.NextCmd()

    Log-Msg "...sleeping"

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