# Effacer l'écran
Clear-Host

# Configuration du script
$scriptDir = "C:\Users\Eric\Documents\_Map_Offline_Powershell"
$zoomLevels = 0..19  # Plage de niveaux de zoom à évaluer

# Fonction pour calculer les statistiques pour un niveau de zoom
function Calculate-Statistics {
    param (
        [int]$zoomLevel
    )

    $zoomDir = Join-Path -Path $scriptDir -ChildPath "OSM\$zoomLevel"
    
    if (-Not (Test-Path -Path $zoomDir)) {
        return $null
    }

    $subDirs = Get-ChildItem -Path $zoomDir -Directory
    $totalFiles = 0
    $missingFiles = 0

    foreach ($subDir in $subDirs) {
        $files = Get-ChildItem -Path $subDir.FullName -Filter *.png | Select-Object -ExpandProperty Name
        if ($files.Count -gt 2) {
            $fileNumbers = $files | Where-Object { $_ -match '^\d+\.png$' } | ForEach-Object { $_ -replace '\.png', '' } | ForEach-Object { [int]$_ }
            $firstNumber = $fileNumbers | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum
            $lastNumber = $fileNumbers | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
            $expectedNumbers = $firstNumber..$lastNumber
            $missingNumbers = $expectedNumbers | Where-Object { $_ -notin $fileNumbers }
            $totalFiles += $fileNumbers.Count
            $missingFiles += $missingNumbers.Count
        }
    }

    $totalFilesExpected = $totalFiles + $missingFiles
    $completionPercentage = if ($totalFilesExpected -eq 0) { 0 } else { [math]::Round(($totalFiles / $totalFilesExpected) * 100, 2) }

    $statistics = @{
        "ZoomLevel" = $zoomLevel
        "TotalFilesPresent" = $totalFiles
        "TotalFilesMissing" = $missingFiles
        "TotalFilesExpected" = $totalFilesExpected
        "CompletionPercentage" = $completionPercentage
    }

    return $statistics
}

# Fonction pour afficher une barre de progression avec des caractères verts et rouges
function Show-ProgressBar {
    param (
        [string]$label,
        [int]$percentage,
        [int]$missingFiles,
        [int]$totalFiles
    )
    $greenBarLength = [math]::Round($percentage / 2)
    $redBarLength = 50 - $greenBarLength
    $greenBar = "=" * $greenBarLength
    $redBar = "-" * $redBarLength

    # Formater le label pour qu'il ait une longueur fixe
    $formattedLabel = $label.PadRight(20)

    Write-Host "$formattedLabel [" -NoNewline
    Write-Host $greenBar -ForegroundColor Green -NoNewline
    Write-Host $redBar -ForegroundColor Red -NoNewline
    Write-Host "] $percentage% (Manquants:$missingFiles, Total:$totalFiles)"
}

# Variables globales pour les totaux
$totalGlobalFiles = 0
$totalGlobalMissingFiles = 0
$totalGlobalFilesExpected = 0

# Générer des statistiques pour chaque niveau de zoom
$allStatistics = @()

foreach ($zoomLevel in $zoomLevels) {
    $stats = Calculate-Statistics -zoomLevel $zoomLevel
    if ($stats) {
        $allStatistics += $stats
        $totalGlobalFiles += $stats.TotalFilesPresent
        $totalGlobalMissingFiles += $stats.TotalFilesMissing
        $totalGlobalFilesExpected += $stats.TotalFilesExpected
        $completionPercentage = $stats.CompletionPercentage
        Show-ProgressBar -label "Zoom Level ${zoomLevel}" -percentage $completionPercentage -missingFiles $stats.TotalFilesMissing -totalFiles $stats.TotalFilesExpected
    }
}

# Calculer le pourcentage global de complétion
$totalGlobalCompletionPercentage = if ($totalGlobalFilesExpected -eq 0) { 0 } else { [math]::Round(($totalGlobalFiles / $totalGlobalFilesExpected) * 100, 2) }

# Afficher la barre de progression globale
Show-ProgressBar -label "Global Completion" -percentage $totalGlobalCompletionPercentage -missingFiles $totalGlobalMissingFiles -totalFiles $totalGlobalFilesExpected
