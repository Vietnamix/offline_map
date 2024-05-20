# Déclaration des fonctions d'API Windows
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class User32 {
        [DllImport("user32.dll", CharSet=CharSet.Auto, CallingConvention=CallingConvention.StdCall)]
        public static extern void mouse_event(long dwFlags, long dx, long dy, long cButtons, long dwExtraInfo);
        [DllImport("user32.dll", CharSet=CharSet.Auto, CallingConvention=CallingConvention.StdCall)]
        public static extern bool SetCursorPos(int X, int Y);
        [DllImport("user32.dll", CharSet=CharSet.Auto, CallingConvention=CallingConvention.StdCall)]
        public static extern bool GetCursorPos(out POINT lpPoint);
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT {
            public int X;
            public int Y;
        }
        public const int MOUSEEVENTF_MOVE = 0x0001;
        public const int MOUSEEVENTF_LEFTDOWN = 0x0002;
        public const int MOUSEEVENTF_LEFTUP = 0x0004;
    }
"@

# Variable pour vérifier si Esc est pressé
$script:stopRequested = $false

# Fonction pour surveiller l'entrée clavier dans un thread séparé
$keyboardListener = {
    while (-not $script:stopRequested) {
        if ([System.Console]::KeyAvailable) {
            $key = [System.Console]::ReadKey($true)
            if ($key.Key -eq [System.ConsoleKey]::Escape) {
                $script:stopRequested = $true
            }
        }
        Start-Sleep -Milliseconds 100  # Pause pour réduire l'utilisation du CPU
    }
}

# Démarrer le thread pour surveiller l'entrée clavier
$listenerThread = [System.Threading.Thread]::new([System.Threading.ThreadStart]$keyboardListener)
$listenerThread.Start()

# Fonction pour cliquer et maintenir avec la souris
function Click-HoldMouse {
    [User32]::mouse_event(0x0002, 0, 0, 0, 0)  # Mouse left button down
}

# Fonction pour relâcher le clic de la souris
function Release-Mouse {
    [User32]::mouse_event(0x0004, 0, 0, 0, 0)  # Mouse left button up
}

# Fonction pour déplacer la souris instantanément
function Move-Mouse {
    param (
        [int]$x,
        [int]$y
    )
    [User32]::SetCursorPos($x, $y)
}

# Fonction pour déplacer la souris progressivement
function Move-Mouse-Gradually {
    param (
        [int]$startX,
        [int]$startY,
        [int]$endX,
        [int]$endY,
        [int]$steps = 4,  # Nombre d'étapes pour le déplacement
        [int]$delay = 5    # Délai en millisecondes entre chaque étape
    )

    $deltaX = ($endX - $startX) / $steps
    $deltaY = ($endY - $startY) / $steps

    for ($i = 0; $i -lt $steps; $i++) {
        if ($script:stopRequested) {
            Write-Host "Script stopped by user."
            return
        }
        $currentX = $startX + [math]::Round($deltaX * $i)
        $currentY = $startY + [math]::Round($deltaY * $i)
        [User32]::SetCursorPos($currentX, $currentY)
        Start-Sleep -Milliseconds $delay
    }

    # Assurer que la souris arrive exactement à la destination finale
    [User32]::SetCursorPos($endX, $endY)
}

# Fonction pour obtenir une position aléatoire dans les limites spécifiées
function Get-RandomPosition {
    param (
        [int]$minX,
        [int]$maxX,
        [int]$minY,
        [int]$maxY
    )

    $randomX = Get-Random -Minimum $minX -Maximum ($maxX + 1)  # +1 car la limite supérieure est exclusive
    $randomY = Get-Random -Minimum $minY -Maximum ($maxY + 1)
    return @{ X = $randomX; Y = $randomY }
}

# Limites de la fenêtre de travail
$minX = 2650
$maxX = 5500
$minY = -600
$maxY = 600

# Point de départ
$startPosition = Get-RandomPosition -minX $minX -maxX $maxX -minY $minY -maxY $maxY
$originX = $startPosition.X
$originY = $startPosition.Y

# Déplacer la souris à la position de départ
Move-Mouse -x $originX -y $originY
Start-Sleep -Milliseconds 500  # Pause pour s'assurer que la position est définie

# Boucle pour cliquer, déplacer aléatoirement et relâcher la souris
for ($i = 0; $i -lt 100; $i++) {
    if ($script:stopRequested) {
        Write-Host "Script stopped by user."
        break
    }

    $startPosition = Get-RandomPosition -minX $minX -maxX $maxX -minY $minY -maxY $maxY
    $originX = $startPosition.X
    $originY = $startPosition.Y

    Move-Mouse -x $originX -y $originY  # Définir la position d'origine
    Start-Sleep -Milliseconds 500       # Pause pour s'assurer que la position est définie

    Click-HoldMouse          # Cliquer et maintenir
    Start-Sleep -Milliseconds 500       # Petite pause pour assurer la synchronisation

    $endPosition = Get-RandomPosition -minX $minX -maxX $maxX -minY $minY -maxY $maxY
    $destinationX = $endPosition.X
    $destinationY = $endPosition.Y

    # Déplacer la souris progressivement vers la destination
    Move-Mouse-Gradually -startX $originX -startY $originY -endX $destinationX -endY $destinationY -steps 100 -delay 5

    Release-Mouse            # Relâcher le clic
    Start-Sleep -Seconds 4   # Pause de 4 secondes avant la prochaine itération
}

# Arrêter le thread de surveillance des touches
$script:stopRequested = $true
$listenerThread.Join()
