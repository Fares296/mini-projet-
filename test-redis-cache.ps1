# Script de benchmark Redis Cache - Module 5

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test de Performance - Redis Cache" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$gateway = "http://localhost:8080"
$endpoint = "$gateway/users"
$iterations = 10

Write-Host "Configuration du test:" -ForegroundColor Yellow
Write-Host "  Endpoint: $endpoint" -ForegroundColor Gray
Write-Host "  Iterations: $iterations" -ForegroundColor Gray
Write-Host ""

# Fonction pour mesurer le temps de réponse
function Measure-Request {
    param([int]$RequestNumber)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method GET -ErrorAction Stop
        $stopwatch.Stop()
        
        return @{
            Success = $true
            Duration = $stopwatch.ElapsedMilliseconds
            Cached = $response.cached
            Count = $response.count
            Instance = $response.instance
        }
    } catch {
        $stopwatch.Stop()
        return @{
            Success = $false
            Duration = $stopwatch.ElapsedMilliseconds
            Error = $_.Exception.Message
        }
    }
}

# Tableau pour stocker les résultats
$results = @()

Write-Host "Phase 1: Premier appel (CACHE MISS attendu)" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$firstCall = Measure-Request -RequestNumber 1
if ($firstCall.Success) {
    Write-Host "Requête #1:" -ForegroundColor White -NoNewline
    Write-Host " $($firstCall.Duration)ms" -ForegroundColor $(if ($firstCall.Cached) { "Green" } else { "Yellow" }) -NoNewline
    Write-Host " | Cached: $($firstCall.Cached) | Instance: $($firstCall.Instance) | Users: $($firstCall.Count)" -ForegroundColor Gray
    $results += $firstCall
} else {
    Write-Host "Erreur: $($firstCall.Error)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Phase 2: Appels suivants (CACHE HIT attendu)" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Pause pour s'assurer que le cache est écrit
Start-Sleep -Milliseconds 500

for ($i = 2; $i -le $iterations; $i++) {
    $result = Measure-Request -RequestNumber $i
    
    if ($result.Success) {
        $color = if ($result.Cached) { "Green" } else { "Yellow" }
        Write-Host "Requête #$($i.ToString().PadLeft(2)):" -ForegroundColor White -NoNewline
        Write-Host " $($result.Duration)ms" -ForegroundColor $color -NoNewline
        Write-Host " | Cached: $($result.Cached) | Instance: $($result.Instance)" -ForegroundColor Gray
        $results += $result
    } else {
        Write-Host "Erreur: $($result.Error)" -ForegroundColor Red
    }
    
    Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ANALYSE DES PERFORMANCES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Séparer les résultats cachés et non cachés
$uncachedResults = $results | Where-Object { -not $_.Cached }
$cachedResults = $results | Where-Object { $_.Cached }

if ($uncachedResults.Count -gt 0) {
    $avgUncached = ($uncachedResults | Measure-Object -Property Duration -Average).Average
    $minUncached = ($uncachedResults | Measure-Object -Property Duration -Minimum).Minimum
    $maxUncached = ($uncachedResults | Measure-Object -Property Duration -Maximum).Maximum
    
    Write-Host "SANS CACHE (Database):" -ForegroundColor Yellow
    Write-Host "  Requêtes: $($uncachedResults.Count)" -ForegroundColor Gray
    Write-Host "  Temps moyen: $([math]::Round($avgUncached, 2))ms" -ForegroundColor Gray
    Write-Host "  Min: $minUncached ms | Max: $maxUncached ms" -ForegroundColor Gray
} else {
    Write-Host "SANS CACHE: Aucune requête" -ForegroundColor Red
}

Write-Host ""

if ($cachedResults.Count -gt 0) {
    $avgCached = ($cachedResults | Measure-Object -Property Duration -Average).Average
    $minCached = ($cachedResults | Measure-Object -Property Duration -Minimum).Minimum
    $maxCached = ($cachedResults | Measure-Object -Property Duration -Maximum).Maximum
    
    Write-Host "AVEC CACHE (Redis):" -ForegroundColor Green
    Write-Host "  Requêtes: $($cachedResults.Count)" -ForegroundColor Gray
    Write-Host "  Temps moyen: $([math]::Round($avgCached, 2))ms" -ForegroundColor Gray
    Write-Host "  Min: $minCached ms | Max: $maxCached ms" -ForegroundColor Gray
} else {
    Write-Host "AVEC CACHE: Aucune requête" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPARAISON AVANT/APRÈS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($uncachedResults.Count -gt 0 -and $cachedResults.Count -gt 0) {
    $improvement = [math]::Round((($avgUncached - $avgCached) / $avgUncached) * 100, 2)
    $speedup = [math]::Round($avgUncached / $avgCached, 2)
    
    Write-Host "Temps moyen sans cache: " -NoNewline
    Write-Host "$([math]::Round($avgUncached, 2))ms" -ForegroundColor Yellow
    
    Write-Host "Temps moyen avec cache: " -NoNewline
    Write-Host "$([math]::Round($avgCached, 2))ms" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "AMÉLIORATION: " -NoNewline -ForegroundColor White
    Write-Host "$improvement%" -ForegroundColor Green -NoNewline
    Write-Host " plus rapide" -ForegroundColor White
    
    Write-Host "FACTEUR: " -NoNewline -ForegroundColor White
    Write-Host "${speedup}x" -ForegroundColor Green -NoNewline
    Write-Host " plus rapide avec cache" -ForegroundColor White
    
    Write-Host ""
    
    # Barre de comparaison visuelle
    Write-Host "Comparaison visuelle:" -ForegroundColor Yellow
    $maxBar = 50
    $uncachedBar = [math]::Min([math]::Floor(($avgUncached / $avgUncached) * $maxBar), $maxBar)
    $cachedBar = [math]::Min([math]::Floor(($avgCached / $avgUncached) * $maxBar), $maxBar)
    
    Write-Host "  Sans cache: " -NoNewline
    Write-Host ("█" * $uncachedBar) -ForegroundColor Yellow -NoNewline
    Write-Host " $([math]::Round($avgUncached, 2))ms"
    
    Write-Host "  Avec cache: " -NoNewline
    Write-Host ("█" * $cachedBar) -ForegroundColor Green -NoNewline
    Write-Host " $([math]::Round($avgCached, 2))ms"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MÉTRIQUES REDIS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Tester si on peut accéder directement à Redis
Write-Host "Vérification du cache Redis..." -ForegroundColor Yellow
try {
    # Via docker exec
    $redisInfo = docker exec redis-cache redis-cli INFO stats 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Redis accessible" -ForegroundColor Green
        
        # Parser les hits et misses si disponibles
        $hits = ($redisInfo | Select-String "keyspace_hits:(\d+)").Matches.Groups[1].Value
        $misses = ($redisInfo | Select-String "keyspace_misses:(\d+)").Matches.Groups[1].Value
        
        if ($hits -and $misses) {
            $total = [int]$hits + [int]$misses
            if ($total -gt 0) {
                $hitRate = [math]::Round(([int]$hits / $total) * 100, 2)
                Write-Host "  Cache Hits: $hits" -ForegroundColor Gray
                Write-Host "  Cache Misses: $misses" -ForegroundColor Gray
                Write-Host "  Hit Rate: $hitRate%" -ForegroundColor $(if ($hitRate -gt 50) { "Green" } else { "Yellow" })
            }
        }
    }
} catch {
    Write-Host "Impossible d'accéder aux statistiques Redis" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FIN DU BENCHMARK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Sauvegarder les résultats
$csvPath = "redis-cache-benchmark.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "Résultats sauvegardés dans: $csvPath" -ForegroundColor Cyan
Write-Host ""

if ($cachedResults.Count -gt 0 -and $improvement -gt 20) {
    Write-Host "REDIS CACHE: PERFORMANCE AMÉLIORÉE ! ✅" -ForegroundColor Green
} elseif ($cachedResults.Count -gt 0) {
    Write-Host "REDIS CACHE: FONCTIONNEL ✅" -ForegroundColor Yellow
} else {
    Write-Host "REDIS CACHE: PROBLÈME ❌" -ForegroundColor Red
}

Write-Host ""
