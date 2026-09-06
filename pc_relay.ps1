# 1. Define named pipe names
$pipeInName  = "cmd_stdin"
$pipeOutName = "cmd_stdout"
$pipeErrName = "cmd_stderr"

# 2. Create Named Pipe Server Streams
# Direction: In = Parent writes to child's STDIN; Out = Parent reads from child's STDOUT/STDERR
$stdinPipe  = New-Object System.IO.Pipes.NamedPipeServerStream($pipeInName, [System.IO.Pipes.PipeDirection]::In)
$stdoutPipe = New-Object System.IO.Pipes.NamedPipeServerStream($pipeOutName, [System.IO.Pipes.PipeDirection]::Out)
$stderrPipe = New-Object System.IO.Pipes.NamedPipeServerStream($pipeErrName, [System.IO.Pipes.PipeDirection]::Out)

Write-Host "Waiting for clients to connect to the pipes..."
# Wait for a client/reader/writer to connect to each pipe
$stdinPipe.WaitForConnection()
$stdoutPipe.WaitForConnection()
$stderrPipe.WaitForConnection()

# 3. Configure the Process Start Info
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

# 4. Start the Process
$process = [System.Diagnostics.Process]::Start($psi)

# 5. Bridge Named Pipes to Process Streams asynchronously or via copy threads
# (For production, run these copy operations using jobs or asynchronous tasks to prevent blocking)
Start-Job -ScriptBlock {
    param($inPipe, $procIn)
    $inPipe.CopyTo($procIn)
    $procIn.Close()
} -ArgumentList $stdinPipe, $process.StandardInput

Start-Job -ScriptBlock {
    param($procOut, $outPipe)
    $procOut.BaseStream.CopyTo($outPipe)
    $outPipe.Flush()
    $outPipe.Close()
} -ArgumentList $process.StandardOutput, $stdoutPipe

Start-Job -ScriptBlock {
    param($procErr, $errPipe)
    $procErr.BaseStream.CopyTo($errPipe)
    $errPipe.Flush()
    $errPipe.Close()
} -ArgumentList $process.StandardError, $stderrPipe

# Wait for process to exit
$process.WaitForExit()
