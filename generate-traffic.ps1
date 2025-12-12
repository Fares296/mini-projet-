# Script pour générer du trafic vers l'API Users
Write-Host "Generating traffic to Users API..." -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3000"

# Health check
Write-Host "Health check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health"
    Write-Host "SUCCESS: Service is healthy" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Health check failed" -ForegroundColor Red
}

Start-Sleep -Milliseconds 500

# Lister les utilisateurs plusieurs fois
Write-Host "`nListing users (10 times)..." -ForegroundColor Yellow
1..10 | ForEach-Object {
    try {
        $users = Invoke-RestMethod -Uri "$baseUrl/users"
        Write-Host "  Request $_/10 - Found $($users.count) users" -ForegroundColor Gray
    } catch {
        Write-Host "ERROR: Failed to list users" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 200
}

# Consulter des utilisateurs individuels
Write-Host "`nGetting individual users..." -ForegroundColor Yellow
1..5 | ForEach-Object {
    try {
        $user = Invoke-RestMethod -Uri "$baseUrl/users/$_"
        Write-Host "  User ${_}: $($user.data.name)" -ForegroundColor Gray
    } catch {
        Write-Host "ERROR: Failed to get user $_" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 300
}

# Créer de nouveaux utilisateurs
Write-Host "`nCreating new users..." -ForegroundColor Yellow
$newUsers = @(
    @{name="Sophie Martin"; email="sophie.martin@example.com"},
    @{name="Lucas Dubois"; email="lucas.dubois@example.com"},
    @{name="Emma Petit"; email="emma.petit@example.com"},
    @{name="Noah Robert"; email="noah.robert@example.com"},
    @{name="Lea Moreau"; email="lea.moreau@example.com"}
)

foreach ($userData in $newUsers) {
    try {
        $body = $userData | ConvertTo-Json
        $result = Invoke-RestMethod -Uri "$baseUrl/users" -Method POST -Body $body -ContentType "application/json"
        Write-Host "SUCCESS: Created user: $($result.data.name)" -ForegroundColor Green
    } catch {
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Host "  WARNING: User $($userData.email) already exists" -ForegroundColor Yellow
        } else {
            Write-Host "ERROR: Failed to create user: $($userData.name)" -ForegroundColor Red
        }
    }
    Start-Sleep -Milliseconds 400
}

# Générer des erreurs 404
Write-Host "`nTesting 404 errors..." -ForegroundColor Yellow
1..5 | ForEach-Object {
    $randomId = Get-Random -Minimum 1000 -Maximum 9999
    try {
        Invoke-RestMethod -Uri "$baseUrl/users/$randomId"
    } catch {
        Write-Host "  Expected 404 for user ID $randomId" -ForegroundColor Gray
    }
    Start-Sleep -Milliseconds 200
}

# Lister à nouveau
Write-Host "`nFinal user list..." -ForegroundColor Yellow
try {
    $finalUsers = Invoke-RestMethod -Uri "$baseUrl/users"
    Write-Host "SUCCESS: Total users now: $($finalUsers.count)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to get final user list" -ForegroundColor Red
}

# Rafale de requêtes
Write-Host "`nStress test (20 rapid requests)..." -ForegroundColor Yellow
1..20 | ForEach-Object {
    try {
        $null = Invoke-RestMethod -Uri "$baseUrl/health" -ErrorAction SilentlyContinue
        Write-Host "  ." -NoNewline -ForegroundColor Gray
    } catch {
        Write-Host "  x" -NoNewline -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 100
}
Write-Host ""

# Vérifier les métriques
Write-Host "`nChecking metrics endpoint..." -ForegroundColor Yellow
try {
    $metrics = Invoke-WebRequest -Uri "$baseUrl/metrics"
    Write-Host "SUCCESS: Metrics endpoint is working" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to get metrics" -ForegroundColor Red
}

Write-Host "`nTraffic generation complete!" -ForegroundColor Cyan
Write-Host "Check Grafana: http://localhost:3001 (admin/admin123)" -ForegroundColor Green
Write-Host "Check Prometheus: http://localhost:9090" -ForegroundColor Green
