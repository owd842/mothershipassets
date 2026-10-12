$cert = New-SelfSignedCertificate -DnsName "localhost", "127.0.0.1" -CertStoreLocation "Cert:\LocalMachine\My" -KeyExportPolicy Exportable -Provider "Microsoft Software Key Storage Provider" -KeyAlgorithm RSA -KeyLength 2048
$guid = [Guid]::NewGuid().ToString("B")
netsh http add sslcert ipport=0.0.0.0:4443 certhash=$($cert.Thumbprint) appid="$guid"

$port = 4433
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("https://+:$port/")

try {
    $listener.Start()
    Write-Host "🚀 HTTPS Server successfully started on https://localhost:$port/" -ForegroundColor Green
    Write-Host "Press CTRL+C in this window to stop the server." -ForegroundColor Yellow

    # Continuous loop to handle incoming browser requests
    while ($listener.IsListening) {
        # Wait for a request
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        Write-Host "📥 Received request: $($request.HttpMethod) $($request.Url)" -ForegroundColor Cyan

        # Define the HTML content to serve
        $html = @"
<!DOCTYPE html>
<html>
<head><title>PowerShell HTTPS Server</title></head>
<body>
    <h1>Hello from PowerShell!</h1>
    <p>Secure connection successfully established.</p>
    <p>Server Time: $(Get-Date)</p>
</body>
</html>
"@

        # Convert the string to UTF8 bytes and send it
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $response.ContentLength64 = $buffer.Length
        $response.ContentType = "text/html; charset=utf-8"
        
        $output = $response.OutputStream
        $output.Write($buffer, 0, $buffer.Length)
        $output.Close()
    }
}
catch {
    Write-Error $_.Exception.Message
}
finally {
    # Always close the listener on exit to free up the port
    $listener.Stop()
    $listener.Close()
    Write-Host "🛑 Server stopped." -ForegroundColor Red
}
