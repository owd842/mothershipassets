$workpath = $args[0]
Write-Host $workpath

if ( ! (Test-Path -Path $workpath -PathType Container) ) {
    $workpath = [System.IO.Path]::GetTempPath()
}

$logpath = Join-Path $workpath "get_full_screen_capture.log"
Start-Transcript -Path $logpath -Append

# Load necessary assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define the screen area to capture
$screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
$width = $screen.Width
$height = $screen.Height
$left = $screen.Left
$top = $screen.Top

Write-Host "width $width height $height left $left top $top"

# Create a Bitmap object to store the screenshot
$bitmap = New-Object System.Drawing.Bitmap $width, $height

# Create a Graphics object from the Bitmap
$graphic = [System.Drawing.Graphics]::FromImage($bitmap)

# Perform the screen capture
# The arguments are: (sourceX, sourceY, destX, destY, size) or (sourcePoint, destPoint, size)
$graphic.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)

# Define the file path for saving
$tmpdir = $workpath 
$filePath = Join-Path $tmpdir "screenshot_1.png"

Write-Host "filePath $filePath"

# Save the screenshot to a file
$bitmap.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up objects
$graphic.Dispose()
$bitmap.Dispose()

Write-Output "Screenshot saved to: $filePath"

function screenshot($path)
{
    [void] [Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    [void] [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $left = [Int32]::MaxValue
    $top = [Int32]::MaxValue
    $right = [Int32]::MinValue
    $bottom = [Int32]::MinValue

    foreach ($screen in [Windows.Forms.Screen]::AllScreens)
    {
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
            $right = $screen.Bounds.X + $screen.Bounds.Width;
        }
        if ($screen.Bounds.Y + $screen.Bounds.Height -gt $bottom)
        {
            $bottom = $screen.Bounds.Y + $screen.Bounds.Height;
        }
    }

    $bounds = [Drawing.Rectangle]::FromLTRB($left, $top, $right, $bottom);
    $bmp = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height;
    $graphics = [Drawing.Graphics]::FromImage($bmp);

    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size);

    $bmp.Save($path);

    $graphics.Dispose();
    $bmp.Dispose();
}

$tmpdir = $workpath
$filePath = Join-Path $tmpdir "screenshot_2.png"
screenshot($filePath)

Write-Output "Screenshot saved to: $filePath"

$filePath = Join-Path $tmpdir "screenshot_3.png"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$File = $filePath

# Get screen bounds and create bitmap
$Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
$Bitmap = New-Object System.Drawing.Bitmap $Screen.Width, $Screen.Height
$Graphic = [System.Drawing.Graphics]::FromImage($Bitmap)

# Capture screen and save
$Graphic.CopyFromScreen($Screen.Left, $Screen.Top, 0, 0, $Bitmap.Size)
$Bitmap.Save($File)

# Clean up
$Graphic.Dispose()
$Bitmap.Dispose()

Write-Output "Screenshot saved to: $filePath"


$tmpdir = $workpath
$filePath = Join-Path $tmpdir "screenshot_4.png"

$outputPath = $filePath 

# Get screen resolution information
$Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
$Width = $Screen.Width
$Height = $Screen.Height
$Left = $Screen.Left
$Top = $Screen.Top

# Create bitmap object and graphic surface
$bitmap = New-Object System.Drawing.Bitmap $Width, $Height
$graphic = [System.Drawing.Graphics]::FromImage($bitmap)

# Copy screen content (including taskbar)
$graphic.CopyFromScreen($Left, $Top, 0, 0, $bitmap.Size)

# Save to file
$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

Write-Output "Screenshot saved to: $filePath"


# Clean up
$graphic.Dispose()
$bitmap.Dispose()


$tmpdir = $workpath
$filePath = Join-Path $tmpdir "screenshot_5.png"


$outputPath = $filePath 

# Get primary screen bounds
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$width = $screen.Bounds.Width
$height = $screen.Bounds.Height
$left = $screen.Bounds.Left
$top = $screen.Bounds.Top

# Create bitmap and graphics objects
$bmp = New-Object System.Drawing.Bitmap($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bmp)

# Copy screen content
$graphics.CopyFromScreen($left, $top, 0, 0, $bmp.Size)


Write-Output "Screenshot saved to: $filePath"

# Save image
$bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Cleanup
$graphics.Dispose()
$bmp.Dispose()


$tmpdir = $workpath
$filePath = Join-Path $tmpdir "screenshot_6.png"

$path = $filePath 

# Get screen resolution
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$width = $screen.Bounds.Width
$height = $screen.Bounds.Height

# Define taskbar area (assuming standard bottom taskbar, roughly 60-100px high)
$taskbarHeight = 60
$top = $height - $taskbarHeight

# Create bitmap and capture
$bitmap = New-Object System.Drawing.Bitmap $width, $taskbarHeight
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen(0, $top, 0, 0, $bitmap.Size)

# Save to file
$bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "Taskbar captured at $path"

Stop-Transcript
