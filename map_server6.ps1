﻿# Script Directory
$scriptDir = "C:\Users\Eric\Documents\_Map_Offline_Powershell"

# Fichier de journalisation
$logFile = Join-Path -Path $scriptDir -ChildPath "server_log.txt"

# Réinitialiser le fichier de journalisation
"Server log initialized at $(Get-Date)" | Out-File -FilePath $logFile -Force

# Colorify the Write-Output
function Sentinel { process { Write-Host $_ -ForegroundColor white -BackgroundColor DarkBlue } }
function Green { process { Write-Host $_ -ForegroundColor DarkGreen -BackgroundColor White } }
function Done { process { Write-Host $_ -ForegroundColor Green -BackgroundColor DarkCyan } }
function Skipped { process { Write-Host $_ -ForegroundColor white -BackgroundColor DarkGray } }
function Red { process { Write-Host $_ -ForegroundColor Red -BackgroundColor White } }
function DarkRed { process { Write-Host $_ -ForegroundColor DarkRed -BackgroundColor White } }

# Fonction de journalisation
function Log-Message {
    param (
        [string]$message,
        [string]$color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "$timestamp - $message"
    Write-Host $formattedMessage -ForegroundColor $color
    $formattedMessage | Out-File -FilePath $logFile -Append
}

# Configuration du serveur HTTP
$listener = [System.Net.HttpListener]::new()
$port = 8086
$prefix = "http://*:$port/"
$listener.Prefixes.Add($prefix)

# Variables globales
$global:hitCounter = @()
$global:maxHits = 500
$global:greenCounts = @{}
$global:totalHits = 0
$global:zoomLevels = @{}

try {
    $listener.Start()
    write-output "Listening for requests on $prefix"

    $stopServer = $false

    function Update-HitCounter {
        param (
            [string]$color,
            [string]$level
        )

        # Ajouter le hit au compteur
        $global:hitCounter += $color
        $global:totalHits++

        # Initialiser les compteurs pour le niveau s'ils n'existent pas
        if (-not $global:greenCounts.ContainsKey($level)) {
            $global:greenCounts[$level] = 0
            $global:zoomLevels[$level] = 0
        }

        # Mettre à jour les compteurs
        if ($color -eq "Green") {
            $global:greenCounts[$level]++
        }

        # Mettre à jour le compteur total par niveau
        $global:zoomLevels[$level]++

        # Si plus de $global:maxHits hits, retirer le plus ancien
        if ($global:hitCounter.Count -gt $global:maxHits) {
            $global:hitCounter = $global:hitCounter[1..$($global:hitCounter.Count - 1)]
        }

        # Afficher les statistiques tous les 100 hits
        if ($global:totalHits % 100 -eq 0) {
            $stats = "Cache Ratio Statistics (Last $($global:hitCounter.Count) hits):"
            foreach ($level in $global:greenCounts.Keys) {
                $greenCount = $global:greenCounts[$level]
                $totalCount = $global:zoomLevels[$level]
                if ($totalCount -ne 0) {
                    $cacheRatio = [math]::Round(($greenCount / $totalCount) * 100, 2)
                    $stats += " Level ${level}: ${cacheRatio}%;"
                }
            }
            Write-Host $stats
        }
    }

    function Get-Image {
        param (
            [string]$x,
            [string]$y,
            [string]$z
        )

        $zfile = Join-Path -Path $scriptDir -ChildPath "OSM\$x\$y\$z.png"

        if (-Not (Test-Path $zfile)) {
            #write-output "File does not exist locally. Downloading from OpenStreetMap..." | DarkRed
            # Créer les dossiers si nécessaire
            $dir = Split-Path -Path $zfile -Parent
            if (-Not (Test-Path $dir)) {
                write-output "Directory does not exist. Creating: $dir" | DarkRed
                try {
                    New-Item -ItemType Directory -Force -Path $dir | Out-Null
                } catch {
                    write-output "Error creating directory ${dir}: $_" | DarkRed
                    Update-HitCounter -color "DarkRed" -level $x
                    return $null
                }
            }

            # Liste des URLs
            $urls = @(
                "https://tile.openstreetmap.org/$x/$y/$z.png",
                "https://a.tile.openstreetmap.org/$x/$y/$z.png",
                "https://b.tile.openstreetmap.org/$x/$y/$z.png",
                "https://c.tile.openstreetmap.org/$x/$y/$z.png"
            )

            # Sélectionner aléatoirement une URL
            $randomIndex = Get-Random -Minimum 0 -Maximum $urls.Count
            $url = $urls[$randomIndex]

            #write-output "Downloading image from: $url" | DarkRed
            try {
                $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.140 Safari/537.36"
                Invoke-WebRequest -UseBasicParsing -Uri $url `
                    -WebSession $session `
                    -Headers @{
                        "authority"="tile.openstreetmap.org"
                        "method"="GET"
                        "path"="/$x/$y/$z.png"
                        "scheme"="https"
                        "accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
                        "accept-encoding"="gzip, deflate, br"
                        "accept-language"="fr,en-US;q=0.9,en;q=0.8"
                        "cache-control"="no-cache"
                        "dnt"="1"
                        "pragma"="no-cache"
                        "sec-ch-ua"="`"Not)A;Brand`";v=`"24`", `"Chromium`";v=`"116`""
                        "sec-ch-ua-mobile"="?0"
                        "sec-ch-ua-platform"="`"Windows`""
                        "sec-fetch-dest"="document"
                        "sec-fetch-mode"="navigate"
                        "sec-fetch-site"="none"
                        "sec-fetch-user"="?1"
                        "upgrade-insecure-requests"="1"
                    } -OutFile $zfile
                write-output "Downloaded from: ${url}" | DarkRed
                Update-HitCounter -color "DarkRed" -level $x
            } catch {
                write-output "Error downloading file from ${url}: $_" | DarkRed
                Update-HitCounter -color "DarkRed" -level $x
                return $null
            }
        } else {
            write-output "File exists locally: ${zfile}" | Green
            Update-HitCounter -color "Green" -level $x
        }

        return $zfile
    }

    function Handle-Request {
        param (
            [System.Net.HttpListenerContext]$context
        )

        try {
            $request = $context.Request
            $response = $context.Response

            if ($request.Url.Segments.Length -lt 4) {
                write-output  "Invalid URL format: $($request.Url.AbsoluteUri)" | DarkRed
                $response.StatusCode = 400
                $response.StatusDescription = "Bad Request"
                $response.OutputStream.Close()
                return
            }

            # Modifier les paramètres pour correspondre à l'URL de la source XYZ
            $x = $request.Url.Segments[1].Trim('/')
            $y = $request.Url.Segments[2].Trim('/')
            $z = $request.Url.Segments[3].Trim('/')

            #write-output "Received request for tile: x=${x}, y=${y}, z=${z}" | Green

            $imagePath = Get-Image -x $x -y $y -z $z

            if ($null -eq $imagePath) {
                $response.StatusCode = 500
                $response.StatusDescription = "Internal Server Error"
            } elseif (Test-Path $imagePath) {
                #write-output "Serving image from: ${imagePath}" | Green
                $bytes = [System.IO.File]::ReadAllBytes($imagePath)
                $response.ContentType = "image/png"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                #write-output "Image not found: ${imagePath}" | DarkRed
                $response.StatusCode = 404
                $response.StatusDescription = "Not Found"
            }

            $response.OutputStream.Close()
        } catch {
            write-output "Error handling request: $_" | DarkRed
        }
    }

    # Fonction pour démarrer le serveur
    function Start-Listener {
        while (-Not $stopServer) {
            try {
                if ($listener.IsListening) {
                    $context = $listener.GetContext()
                    Handle-Request -context $context
                } else {
                    write-output "Listener stopped or an error occurred: Listener is not listening" | DarkRed
                    $stopServer = $true
                }
            } catch {
                write-output "Listener stopped or an error occurred: $_" | DarkRed
                $stopServer = $true
            }
        }
        write-output "Server stopped." | DarkRed
    }

    # Démarrer le serveur
    Start-Listener
} finally {
    $listener.Stop()
}
