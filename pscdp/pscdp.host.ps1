$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $scriptDir

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


class HostServer {

    $listener = $null
    $listenport = 8080
    $request = $null
    $response = $null
    $context = $null
    $contextTask = $null

    HostServer($listenport) {
        $this.listenport = $listenport
        $this.listener = [System.Net.HttpListener]::new()
    }

    [void] Connect() {
        $urlc = "http://localhost:$($this.listenport)/"

        Log-Msg "connecting to $urlc"

        $this.listener.Prefixes.Add($urlc)
        $this.listener.Start()

        Log-Msg "Listener started on $urlc"
        
        $this.contextTask = $this.listener.GetContextAsync()
    }

    [void] Terminate() {
        $this.listener.Stop()
        $this.listener.Close()
    }

    [void] ServeIndex() {

        $htmlPath = Join-Path -Path $script:scriptDir -ChildPath "pscdp.host.html"

        if ( -not ( Test-Path $htmlPath ) ) {
            $this.response.StatusCode = 404
            $this.response.OutputStream.Close()
            return
        }

        $buffer = [System.IO.File]::ReadAllBytes($htmlPath)
        $this.response.ContentLength64 = $buffer.Length
        $this.response.ContentType = "text/html; charset=utf-8"
        
        $output = $this.response.OutputStream
        $output.Write($buffer, 0, $buffer.Length)
        $output.Close()
    }
 
    [void] ProcessRequest() {

        if ( ! $this.contextTask.IsCompleted) {
            return
        }

        # Retrieve the context and immediately start waiting for the next request
        $this.context = $this.contextTask.Result
        $this.contextTask = $this.listener.GetContextAsync()
    
        # Handle the request logic (best done inside a scriptblock or background job if heavy)
        $this.request = $this.context.Request
        $this.response = $this.context.Response
            
        Write-Host "Received request for: $($this.request.Url)"
        $url = $this.request.Url

        # $url.AbsolutePath
        $segments = $url.Segments
        $endpoint = $segments[-1]

        # serve pscdp.host.html
        if ( $endpoint -eq "index.html" -or $endpoint -eq "/" ) {
            $this.ServeIndex()
            return
        } elseif ( $endpoint -eq "GetFrontendUrls" ) {
            Log-Msg "received request for GetFrontendUrls"
        }

        # Send a quick response back
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("Hello from PowerShell!")
        $this.response.ContentLength64 = $buffer.Length
        $this.response.OutputStream.Write($buffer, 0, $buffer.Length)
        $this.response.OutputStream.Close()
    }
}

$webserver = [HostServer]::new(8080)
$webserver.Connect()

$running = $true
while ($running) {

    Log-Msg "new iteration"

    $webserver.ProcessRequest()

    Start-Sleep -Milliseconds 500
}

