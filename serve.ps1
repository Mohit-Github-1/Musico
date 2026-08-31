# Native Windows PowerShell Static HTTP Server
$port = 8080
$root = $PSScriptRoot

$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi" -ErrorAction SilentlyContinue).IPAddress
if (-not $ip) {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
}
if (-not $ip) { $ip = "10.42.51.127" }

$listener = New-Object System.Net.HttpListener

$started = $false
$prefixes = @("http://*:$port/", "http://+:$port/", "http://localhost:$port/")

foreach ($prefix in $prefixes) {
    try {
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add($prefix)
        $listener.Start()
        $started = $true
        break
    } catch {
        if ($listener) { $listener.Close() }
    }
}

if (-not $started) {
    Write-Host "Could not bind listener. Trying port 8085..." -ForegroundColor Red
    $port = 8085
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://*:$port/")
    $listener.Start()
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  MUSICO LIVE SERVER IS NOW RUNNING!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Open this link on your Phone (Wi-Fi):" -ForegroundColor White
Write-Host "  -> http://${ip}:${port}" -ForegroundColor Yellow
Write-Host ""
Write-Host "  PC Local URL:" -ForegroundColor White
Write-Host "  -> http://localhost:${port}" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the server.`n"

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $localPath = $request.Url.LocalPath
        if ($localPath -eq "/" -or [string]::IsNullOrWhiteSpace($localPath)) {
            $localPath = "/index.html"
        }

        $filePath = Join-Path $root ($localPath.TrimStart('/').Replace('/', '\'))

        if ((Test-Path $filePath) -and -not (Test-Path $filePath -PathType Container)) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentLength64 = $bytes.Length
            
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            switch ($ext) {
                ".html" { $response.ContentType = "text/html; charset=utf-8" }
                ".css"  { $response.ContentType = "text/css" }
                ".js"   { $response.ContentType = "application/javascript" }
                ".png"  { $response.ContentType = "image/png" }
                ".jpg"  { $response.ContentType = "image/jpeg" }
                ".jpeg" { $response.ContentType = "image/jpeg" }
                ".svg"  { $response.ContentType = "image/svg+xml" }
                ".json" { $response.ContentType = "application/json" }
                ".mp3"  { $response.ContentType = "audio/mpeg" }
                ".wav"  { $response.ContentType = "audio/wav" }
                ".ogg"  { $response.ContentType = "audio/ogg" }
                ".m4a"  { $response.ContentType = "audio/mp4" }
                default { $response.ContentType = "application/octet-stream" }
            }
            
            $response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $buffer = [System.Text.Encoding]::UTF8.GetBytes("404 File Not Found: $localPath")
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        $response.Close()
    } catch {
        # Catch network disconnects
    }
}
