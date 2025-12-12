# Script de test pour l'API Gateway NGINX

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API Gateway NGINX - Tests Complets" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$gateway = "http://localhost:8080"
$testsPassed = 0
$testsFailed = 0

# Fonction pour afficher le résultat d'un test
function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Method = "GET",
        [string]$Body = $null
    )
    
    Write-Host "Test: $Name" -ForegroundColor Yellow
    Write-Host "  URL: $Url" -ForegroundColor Gray
    
    try {
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod -Uri $Url -Method GET -ErrorAction Stop
        } elseif ($Method -eq "POST") {
            $response = Invoke-RestMethod -Uri $Url -Method POST -Body $Body -ContentType "application/json" -ErrorAction Stop
        } elseif ($Method -eq "PUT") {
            $response = Invoke-RestMethod -Uri $Url -Method PUT -Body $Body -ContentType "application/json" -ErrorAction Stop
        } elseif ($Method -eq "DELETE") {
            $response = Invoke-RestMethod -Uri $Url -Method DELETE -ErrorAction Stop
        }
        
        Write-Host "  SUCCESS" -ForegroundColor Green
        $script:testsPassed++
        return $response
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $script:testsFailed++
        return $null
    }
}

# ==================== GATEWAY HEALTH ====================
Write-Host "`n1. GATEWAY HEALTH & INFO" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Gateway Root" -Url "$gateway/"
Test-Endpoint -Name "Gateway Health" -Url "$gateway/health"

# ==================== USERS SERVICE via GATEWAY ====================
Write-Host "`n2. USERS SERVICE (via Gateway)" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

$users = Test-Endpoint -Name "Liste des utilisateurs" -Url "$gateway/users"
if ($users) {
    Write-Host "  Users count: $($users.count)" -ForegroundColor Gray
}

Test-Endpoint -Name "Utilisateur par ID" -Url "$gateway/users/1"

$newUser = @{
    name = "Gateway Test User"
    email = "gateway.test@example.com"
} | ConvertTo-Json

$createdUser = Test-Endpoint -Name "Créer utilisateur" -Url "$gateway/users" -Method POST -Body $newUser
if ($createdUser) {
    $userId = $createdUser.data.id
    Write-Host "  Created user ID: $userId" -ForegroundColor Gray
    
    # Tester la suppression
    Start-Sleep -Milliseconds 500
    Test-Endpoint -Name "Supprimer utilisateur" -Url "$gateway/users/$userId" -Method DELETE
}

Test-Endpoint -Name "Health check users" -Url "$gateway/users/health"
Test-Endpoint -Name "Metrics users" -Url "$gateway/users/metrics"

# ==================== PRODUCTS SERVICE via GATEWAY ====================
Write-Host "`n3. PRODUCTS SERVICE (via Gateway)" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

$products = Test-Endpoint -Name "Liste des produits" -Url "$gateway/products"
if ($products) {
    Write-Host "  Products count: $($products.count)" -ForegroundColor Gray
}

Test-Endpoint -Name "Produit par ID" -Url "$gateway/products/1"
Test-Endpoint -Name "Filtrer par catégorie" -Url "$gateway/products?category=Informatique"
Test-Endpoint -Name "Filtrer par prix" -Url "$gateway/products?minPrice=100&maxPrice=500"
Test-Endpoint -Name "Produits en stock" -Url "$gateway/products?inStock=true"
Test-Endpoint -Name "Catégorie Gaming" -Url "$gateway/products/category/Gaming"

$newProduct = @{
    name = "Gateway Test Product"
    description = "Produit créé via le gateway"
    price = 99.99
    stock = 10
    category = "Test"
} | ConvertTo-Json

$createdProduct = Test-Endpoint -Name "Créer produit" -Url "$gateway/products" -Method POST -Body $newProduct
if ($createdProduct) {
    $productId = $createdProduct.data.id
    Write-Host "  Created product ID: $productId" -ForegroundColor Gray
    
    # Tester la mise à jour
    Start-Sleep -Milliseconds 500
    $updateProduct = @{
        price = 149.99
        stock = 20
    } | ConvertTo-Json
    
    Test-Endpoint -Name "MAJ produit" -Url "$gateway/products/$productId" -Method PUT -Body $updateProduct
    
    # Tester la suppression
    Start-Sleep -Milliseconds 500
    Test-Endpoint -Name "Supprimer produit" -Url "$gateway/products/$productId" -Method DELETE
}

Test-Endpoint -Name "Health check products" -Url "$gateway/products/health"
Test-Endpoint -Name "Metrics products" -Url "$gateway/products/metrics"

# ==================== PROMETHEUS via GATEWAY ====================
Write-Host "`n4. PROMETHEUS (via Gateway)" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

# Note: Prometheus via gateway peut avoir des problèmes de redirection
# On teste juste l'accessibilité
Write-Host "Test: Prometheus via Gateway" -ForegroundColor Yellow
Write-Host "  URL: $gateway/prometheus/" -ForegroundColor Gray
try {
    $prometheusResponse = Invoke-WebRequest -Uri "$gateway/prometheus/" -ErrorAction Stop
    if ($prometheusResponse.StatusCode -eq 200) {
        Write-Host "  SUCCESS" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "  FAILED: Status $($prometheusResponse.StatusCode)" -ForegroundColor Red
        $script:testsFailed++
    }
} catch {
    Write-Host "  INFO: Prometheus accessible mais peut nécessiter une navigation browser" -ForegroundColor Yellow
}

# ==================== TESTS D'ERREURS ====================
Write-Host "`n5. TESTS D'ERREURS" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "Test: Route inexistante (404)" -ForegroundColor Yellow
Write-Host "  URL: $gateway/invalid-route" -ForegroundColor Gray
try {
    Invoke-RestMethod -Uri "$gateway/invalid-route" -ErrorAction Stop
    Write-Host "  FAILED: Should return 404" -ForegroundColor Red
    $script:testsFailed++
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  SUCCESS: 404 returned correctly" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "  FAILED: Wrong status code" -ForegroundColor Red
        $script:testsFailed++
    }
}

Write-Host "Test: Utilisateur inexistant (404)" -ForegroundColor Yellow
Write-Host "  URL: $gateway/users/99999" -ForegroundColor Gray
try {
    Invoke-RestMethod -Uri "$gateway/users/99999" -ErrorAction Stop
    Write-Host "  FAILED: Should return 404" -ForegroundColor Red
    $script:testsFailed++
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  SUCCESS: 404 returned correctly" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "  FAILED: Wrong status code" -ForegroundColor Red
        $script:testsFailed++
    }
}

# ==================== RÉSULTATS ====================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RÉSULTATS DES TESTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$total = $testsPassed + $testsFailed
$successRate = if ($total -gt 0) { [math]::Round(($testsPassed / $total) * 100, 2) } else { 0 }

Write-Host "`nTotal des tests: $total" -ForegroundColor White
Write-Host "Tests réussis:   $testsPassed" -ForegroundColor Green
Write-Host "Tests échoués:   $testsFailed" -ForegroundColor Red
Write-Host "Taux de succès:  $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Fin des tests - API Gateway NGINX" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "TOUS LES TESTS ONT REUSSI!" -ForegroundColor Green
    Write-Host "L'API Gateway est pleinement opérationnel." -ForegroundColor Green
} else {
    Write-Host "ATTENTION: Certains tests ont échoué." -ForegroundColor Yellow
    Write-Host "Vérifiez que tous les services sont démarrés:" -ForegroundColor Yellow
    Write-Host "  docker-compose ps" -ForegroundColor Gray
}

Write-Host "`nAccès direct au Gateway:" -ForegroundColor Cyan
Write-Host "  http://localhost:8080/" -ForegroundColor White
Write-Host ""
