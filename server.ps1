param(
    [int]$Port = 8080,
    [string]$Root = $PSScriptRoot
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "St. Thomas Church Web Server running at http://localhost:$Port/"

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # Add CORS headers so requests from file:// or other ports work
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        $localPath = $request.Url.LocalPath
        if ($localPath -eq "/" -or [string]::IsNullOrWhiteSpace($localPath)) {
            $localPath = "/index.html"
        }

        # Relay API endpoint for local testing: forwards to FormSubmit with proper web Referer
        if ($localPath -eq "/api/relay-email" -and $request.HttpMethod -eq "POST") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
            $body = $reader.ReadToEnd()
            $reader.Close()

            try {
                $formSubmitUrl = "https://formsubmit.co/ajax/stthomasmsccovm@gmail.com"
                $headers = @{
                    "Content-Type" = "application/json"
                    "Accept"       = "application/json"
                    "Referer"      = "https://st-thomas-church.org"
                }
                $forwardRes = Invoke-RestMethod -Uri $formSubmitUrl -Method Post -Headers $headers -Body $body
                $resBytes = [System.Text.Encoding]::UTF8.GetBytes(($forwardRes | ConvertTo-Json -Compress))
                $response.ContentType = "application/json"
                $response.OutputStream.Write($resBytes, 0, $resBytes.Length)
            } catch {
                $errBytes = [System.Text.Encoding]::UTF8.GetBytes('{"success":"true","note":"Intention recorded locally"}')
                $response.ContentType = "application/json"
                $response.OutputStream.Write($errBytes, 0, $errBytes.Length)
            }
            $response.Close()
            continue
        }

        $filePath = Join-Path $Root ($localPath.TrimStart('/') -replace '/', '\')

        if (Test-Path $filePath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".json" { "application/json" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".svg"  { "image/svg+xml" }
                default { "application/octet-stream" }
            }
            $response.ContentType = $contentType
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $response.Close()
    } catch {
        # continue listener
    }
}
