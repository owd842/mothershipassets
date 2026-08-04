$workpath = $args[0]

if ( ( [string]::IsNullOrEmpty($workpath) ) -or ( ! (Test-Path -Path $workpath -PathType Container) ) ) {
    $workpath = [System.IO.Path]::GetTempPath()
}

Write-Host "workpath=$workpath"

$logpath = Join-Path $workpath "get_full_screen_capture.log"
Start-Transcript -Path $logpath -Append

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function screenshot_method_a($path) {
    $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

    $name = (( $screen.DeviceName -replace '\\', '' ) -replace '\.', '')

    $width = $screen.Width
    $height = $screen.Height
    $left = $screen.Left
    $top = $screen.Top

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphic.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)

    $filePath = Join-Path $workpath "screenshot_method_a.png"
    $bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
    
    Write-Output "filepath=$filePath"
    
    $graphic.Dispose()
    $bitmap.Dispose()
}

function screenshot_method_b($path) {
    [void] [Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    [void] [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $left = [Int32]::MaxValue
    $top = [Int32]::MaxValue
    $right = [Int32]::MinValue
    $bottom = [Int32]::MinValue

    $index = 0
    foreach ($screen in [Windows.Forms.Screen]::AllScreens)
    {
        $index++;
        
        if ($screen.Bounds.X -lt $left)
        {
            $left = $screen.Bounds.X;
        }
        if ($screen.Bounds.Y -lt $top)
        {
            $top = $screen.Bounds.Y;
        }
        if ($screen.Bounds.X + $screen.Bounds.Width -gt $right)
        {
            $right = $screen.Bounds.X + $screen.Bounds.Width + 1000;
        }
        if ($screen.Bounds.Y + $screen.Bounds.Height -gt $bottom)
        {
            $bottom = $screen.Bounds.Y + $screen.Bounds.Height + 1000;
        }

        $bounds = [Drawing.Rectangle]::FromLTRB($left, $top, $right, $bottom);
        $bmp = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height;
        $graphics = [Drawing.Graphics]::FromImage($bmp);

        $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size);

        $name = (( $screen.DeviceName -replace '\\', '' ) -replace '\.', '')

        $fpath = Join-Path $path ("screenshot_method_b_"+$name + "_" + $index + ".png")
        
        Write-Host "filepath=$fpath"

        $bmp.Save($fpath);
    }
    
    $graphics.Dispose();
    $bmp.Dispose();
}

screenshot_method_a($workpath)
screenshot_method_b($workpath)

Stop-Transcript