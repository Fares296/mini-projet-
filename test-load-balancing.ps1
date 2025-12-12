# Script de test de Load Balancing - Module 4

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test de Load Balancing - Users Service" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$gateway = "http://localhost:8080"
$iterations = 20  # Nombre de requêtes à envoyer

# Compteurs pour chaque instance
$instanceCounts = @{
    "1" = 0
    "2" = 0
    "3" = 0
    "unknown" = 0
}

# Mapping des IPs vers les instances (sera construit dynamiquement)
$ipToInstance = @{}

# Tableau pour stocker les résultats
$results = @()

Write-Host "Envoi de $iterations requêtes vers le Gateway..." -ForegroundColor Yellow
Write-Host "Gateway: $gateway/users" -ForegroundColor Gray
Write-Host ""

for ($i = 1; $i -le $iterations; $i++) {
    try {
        # Envoyer la requête via le Gateway
        $response = Invoke-WebRequest -Uri "$gateway/users" -Method GET -ErrorAction Stop
        
        # Extraire le serveur upstream (format: IP:PORT)
        $upstreamServer = $response.Headers['X-Upstream-Server']
        
        # Extraire l'IP
        $instanceId = "unknown"
        if ($upstreamServer -and $upstreamServer -match '(\d+\.\d+\.\d+\.\d+):3000') {
            $ipAddress = $matches[1]
            
            # Si on ne connaît pas encore cette IP, essayer de la mapper
            if (-not $ipToInstance.ContainsKey($ipAddress)) {
                # Mapper de manière séquentielle
                $nextInstanceId = ($ipToInstance.Values | Measure-Object -Maximum).Maximum
                if ($null -eq $nextInstanceId) {
                    $nextInstanceId = 0
                }
                $nextInstanceId++
                $ipToInstance[$ipAddress] = $nextInstanceId.ToString()
            }
            
            $instanceId = $ipToInstance[$ipAddress]
        }
        
        # Incrémenter le compteur
        $instanceCounts[$instanceId]++
        
        # Enregistrer le résultat
        $result = @{
            Request = $i
            Instance = $instanceId
            UpstreamServer = $upstreamServer
            StatusCode = $response.StatusCode
        }
        $results += New-Object PSObject -Property $result
        
        # Afficher le résultat
        $color = switch ($instanceId) {
            "1" { "Green" }
            "2" { "Yellow" }
            "3" { "Magenta" }
            default { "Red" }
        }
        
        Write-Host "Request #$($i.ToString().PadLeft(2)): Instance $instanceId" -ForegroundColor $color -NoNewline
        Write-Host " | Server: $upstreamServer" -ForegroundColor Gray
        
        # Petite pause pour éviter de surcharger
        Start-Sleep -Milliseconds 100
        
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host "Request #$i`: ERREUR - $errorMsg" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RÉSULTATS DU LOAD BALANCING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Afficher les statistiques
Write-Host "Distribution des requêtes par instance:" -ForegroundColor Yellow
Write-Host ""

$maxCount = ($instanceCounts.Values | Measure-Object -Maximum).Maximum

foreach ($instance in $instanceCounts.Keys | Sort-Object) {
    $count = $instanceCounts[$instance]
    $percentage = if ($iterations -gt 0) { [math]::Round(($count / $iterations) * 100, 2) } else { 0 }
  
  # Barre de progression visuelle
    $barLength = if ($maxCount -gt 0) { [math]::Floor(($count / $maxCount) * 40) } else { 0 }
    $bar = "█" * $barLength
    
    $color = switch ($instance) {
        "1" { "Green" }
        "2" { "Yellow" }
        "3" { "Magenta" }
        default { "Red" }
    }
    
    Write-Host "Instance $instance | " -ForegroundColor $color -NoNewline
    Write-Host "$bar " -ForegroundColor $color -NoNewline
    Write-Host "| $count requêtes ($percentage%)" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ANALYSE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier la distribution
$totalDistributed = $instanceCounts["1"] + $instanceCounts["2"] + $instanceCounts["3"]
$expectedPerInstance = $iterations / 3
$tolerance = $iterations * 0.2  # 20% de tolérance

Write-Host "Total requêtes: $iterations" -ForegroundColor White
Write-Host "Requêtes distribuées: $totalDistributed" -ForegroundColor White
Write-Host "Requêtes non distribuées: $($instanceCounts['unknown'])" -ForegroundColor $(if ($instanceCounts['unknown'] -gt 0) { "Red" } else { "Green" })
Write-Host ""

Write-Host "Distribution attendue (round-robin):" -ForegroundColor White
Write-Host "  ~$([math]::Round($expectedPerInstance, 2)) requêtes par instance" -ForegroundColor Gray
Write-Host ""

# Évaluer la qualité du load balancing
$isBalanced = $true
foreach ($instance in @("1", "2", "3")) {
    $count = $instanceCounts[$instance]
    $deviation = [math]::Abs($count - $expectedPerInstance)
    
    if ($deviation -gt $tolerance) {
        $isBalanced = $false
    }
}

if ($isBalanced -and $instanceCounts['unknown'] -eq 0) {
    Write-Host "LOAD BALANCING : OPTIMAL" -ForegroundColor Green
    Write-Host "Les requêtes sont bien réparties entre les 3 instances" -ForegroundColor Green
} elseif ($totalDistributed -eq $iterations) {
    Write-Host "LOAD BALANCING : BON" -ForegroundColor Yellow
    Write-Host "Toutes les requêtes sont distribuées mais la répartition n'est pas parfaite" -ForegroundColor Yellow
} else {
    Write-Host "LOAD BALANCING : PROBLÈME" -ForegroundColor Red
    Write-Host "Certaines requêtes ne sont pas distribuées correctement" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VÉRIFICATION DES INSTANCES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Tester chaque instance directement
Write-Host "Test direct des instances individuelles:" -ForegroundColor Yellow
Write-Host ""

foreach ($inst in @("1", "2", "3")) {
    $port = switch ($inst) {
        "1" { "3000" }
        "2" { "3004" }
        "3" { "3003" }
    }
    
    try {
        $directResponse = Invoke-RestMethod -Uri "http://localhost:$port/health" -ErrorAction Stop
        Write-Host "Instance $inst (port $port): " -ForegroundColor White -NoNewline
        Write-Host "HEALTHY" -ForegroundColor Green -NoNewline
        Write-Host " | Hostname: $($directResponse.hostname)" -ForegroundColor Gray
    } catch {
        Write-Host "Instance $inst (port $port): " -ForegroundColor White -NoNewline
        Write-Host "ERREUR" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FIN DES TESTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Sauvegarder les résultats dans un fichier CSV
$csvPath = "load-balancing-results.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Résultats sauvegardés dans: $csvPath" -ForegroundColor Cyan
Write-Host ""
