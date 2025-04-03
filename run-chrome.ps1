Write-Output "Log folder $pwd"

# Retries to connect to an http url, allowing for any valid "response"
# (4xx,5xx,etc also valid)
function Wait-For-HTTP-Response {
  param (
    $RequestURL
  )

  $status = "Failed"
  for (($sleeps=1); $sleeps -le 30; $sleeps++)
  {
    try {
      Invoke-WebRequest -UseBasicParsing -Uri $RequestURL >> $pwd\http-testing-log.txt
      $status = "Success"
      break
    }
    catch {
      $code = $_.Exception.Response.StatusCode.Value__
      if ( $code -gt 99)
      {
        $status = "Success ($code)"
        break
      }
    }
    Start-Sleep -Seconds 1
  }
  Write-Output "$status after $sleeps tries"
}

Write-Output "Starting chromedriver"
$webdriverprocess = Start-Job -Init ([ScriptBlock]::Create("Set-Location '$pwd'")) -ScriptBlock { chromedriver --port=4444 --log-level=INFO --enable-chrome-logs *>&1 >$using:pwd\webdriver-log.txt }
Write-Output "Waiting for localhost:4444 to start from chromedriver"
Wait-For-HTTP-Response -RequestURL http://localhost:4444/

Invoke-WebRequest \
  -UseBasicParsing \
  -Method 'POST' \
  -Body '{"capabilities": {"alwaysMatch": { "browserName": "chrome" } } }' \
  -Uri http://localhost:4444/session >> $pwd\http-testing-log.txt

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$screens = [Windows.Forms.Screen]::AllScreens
$top    = ($screens.Bounds.Top    | Measure-Object -Minimum).Minimum
$left   = ($screens.Bounds.Left   | Measure-Object -Minimum).Minimum
$width  = ($screens.Bounds.Right  | Measure-Object -Maximum).Maximum
$height = ($screens.Bounds.Bottom | Measure-Object -Maximum).Maximum
$bounds   = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
$bmp      = New-Object System.Drawing.Bitmap ([int]$bounds.width), ([int]$bounds.height)
$graphics = [Drawing.Graphics]::FromImage($bmp)

for ($count = 1; $count -le 20; $count++) {
  Write-Output "Capturing screenshot #$count of 20"
  $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
  $bmp.Save("$pwd\test$count.png")
  Start-Sleep -Seconds 1
}

$graphics.Dispose()
$bmp.Dispose()
