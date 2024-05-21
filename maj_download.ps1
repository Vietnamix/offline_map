# Configuration du script
$scriptDir = "C:\Users\Eric\Documents\_Map_Offline_Powershell"
$logFile = Join-Path -Path $scriptDir -ChildPath "server_log.txt"
$sourceUrl = "https://tile.openstreetmap.org"  # URL de la source des fichiers manquants
$tempDelay = 250  # Temporisation en millisecondes
$zoomLevel = 8  # Niveau de zoom défini en dur
$downloadDir = Join-Path -Path $scriptDir -ChildPath "OSM\$zoomLevel"  # Chemin du répertoire cible

# Réinitialiser le fichier de journalisation
"Server log initialized at $(Get-Date)" | Out-File -FilePath $logFile -Force

# Fonctions de coloration de la sortie
function Sentinel { process { Write-Host $_ -ForegroundColor White -BackgroundColor DarkBlue } }
function Green { process { Write-Host $_ -ForegroundColor DarkGreen -BackgroundColor White } }
function Done { process { Write-Host $_ -ForegroundColor Green -BackgroundColor DarkCyan } }
function Skipped { process { Write-Host $_ -ForegroundColor White -BackgroundColor DarkGray } }
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
    if ($color -in [System.Enum]::GetValues([System.ConsoleColor])) {
        Write-Host $formattedMessage -ForegroundColor $color
    } else {
        Write-Host $formattedMessage -ForegroundColor White
    }
    $formattedMessage | Out-File -FilePath $logFile -Append
}

# Fonction pour télécharger un fichier avec User-Agent et en-têtes personnalisés
function Download-File {
    param (
        [string]$url,
        [string]$destination,
        [string]$x,
        [string]$y,
        [string]$z
    )
    try {
        $headers = @{
            "authority" = "tile.openstreetmap.org"
            "method" = "GET"
            "path" = "/$x/$y/$z.png"
            "scheme" = "https"
            "accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
            "accept-encoding" = "gzip, deflate, br"
            "accept-language" = "fr,en-US;q=0.9,en;q=0.8"
            "cache-control" = "no-cache"
            "dnt" = "1"
            "pragma" = "no-cache"
            "sec-ch-ua" = "`"Not)A;Brand`";v=`"24`", `"Chromium`";v=`"116`""
            "sec-ch-ua-mobile" = "?0"
            "sec-ch-ua-platform" = "`"Windows`""
            "sec-fetch-dest" = "document"
            "sec-fetch-mode" = "navigate"
            "sec-fetch-site" = "none"
            "sec-fetch-user" = "?1"
            "upgrade-insecure-requests" = "1"
        }
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.140 Safari/537.36"
        
        Invoke-WebRequest -Uri $url -OutFile $destination -Headers $headers -WebSession $session -UseBasicParsing
        Log-Message -message "Downloaded file from $url to $destination" -color "Green"
    } catch {
        Log-Message -message ("Error downloading file from {0}: {1}" -f $url, $_.Exception.Message) -color "Red"
    }
}

# Vérifier si le répertoire de niveau de zoom existe
if (-Not (Test-Path -Path $downloadDir)) {
    Log-Message -message "Le répertoire pour le niveau de zoom $zoomLevel n'existe pas. Création du répertoire." -color "Yellow"
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
}

# Récupérer les sous-répertoires dans le répertoire de niveau de zoom
$subDirs = Get-ChildItem -Path $downloadDir -Directory

foreach ($subDir in $subDirs) {
    # Récupérer les noms de fichiers correspondant au motif *.png
    $files = Get-ChildItem -Path $subDir.FullName -Filter *.png | Select-Object -ExpandProperty Name

    if ($files.Count -gt 2) {
        # Filtrer les fichiers avec des noms numériques et extraire les numéros
        $fileNumbers = $files | Where-Object { $_ -match '^\d+\.png$' } | ForEach-Object { $_ -replace '\.png', '' } | ForEach-Object { [int]$_ }

        # Trouver le premier et le dernier numéro
        $firstNumber = $fileNumbers | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
        $lastNumber = $fileNumbers | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

        # Générer la liste complète des numéros attendus
        $expectedNumbers = $firstNumber..$lastNumber

        # Trouver les numéros manquants
        $missingNumbers = $expectedNumbers | Where-Object { $_ -notin $fileNumbers }

        # Afficher et télécharger les fichiers manquants
        if ($missingNumbers) {
            $missingNumbers | ForEach-Object {
                $x = $zoomLevel
                $y = $subDir.Name
                $z = $_
                $missingFileName = "$z.png"
                $missingFilePath = Join-Path -Path $subDir.FullName -ChildPath $missingFileName
                $sourceFileUrl = "$sourceUrl/$x/$y/$z.png"

                Log-Message -message "Missing file: $missingFileName. Attempting to download from $sourceFileUrl" -color "Yellow"

                # Télécharger le fichier manquant
                Download-File -url $sourceFileUrl -destination $missingFilePath -x $x -y $y -z $z

                # Temporisation de 500ms
                Start-Sleep -Milliseconds $tempDelay
            }
        } else {
            Log-Message -message "Aucun fichier manquant dans le répertoire $($subDir.FullName)." -color "Green"
        }
    } else {
        Log-Message -message "Le répertoire $($subDir.FullName) contient moins de 3 fichiers, ignoré." -color "DarkGray"
    }
}
