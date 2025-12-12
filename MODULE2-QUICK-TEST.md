# 🚀 MODULE 2 - QUICK TEST GUIDE

## Démarrage rapide

### 1. Lancer les services Products

```powershell
# Depuis la racine du projet
docker-compose up -d --build products-service postgres-products
```

### 2. Vérifier que tout fonctionne

```powershell
docker-compose ps
```

**Résultat attendu :**
```
✅ products-postgres   Up (healthy)   Port 5433
✅ products-service    Up             Port 3002
```

---

## Tests manuels rapides

### Health Check
```powershell
Invoke-RestMethod http://localhost:3002/health
```

### Lister tous les produits
```powershell
Invoke-RestMethod http://localhost:3002/products | ConvertTo-Json -Depth 2
```

### Créer un produit
```powershell
$newProduct = @{
    name = "Xbox Series X"
    description = "Console de jeu Microsoft nouvelle génération"
    price = 499.99
    stock = 15
    category = "Gaming"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3002/products" -Method POST -Body $newProduct -ContentType "application/json" | ConvertTo-Json
```

### Filtrer par catégorie
```powershell
Invoke-RestMethod "http://localhost:3002/products?category=Informatique" | ConvertTo-Json -Depth 2
```

### Filtrer par prix
```powershell
Invoke-RestMethod "http://localhost:3002/products?minPrice=100&maxPrice=500" | ConvertTo-Json -Depth 2
```

### Obtenir un produit par ID
```powershell
Invoke-RestMethod http://localhost:3002/products/1 | ConvertTo-Json
```

### Mettre à jour un produit
```powershell
$update = @{
    price = 1399.99
    stock = 20
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:3002/products/1" -Method PUT -Body $update -ContentType "application/json" | ConvertTo-Json
```

### Supprimer un produit
```powershell
Invoke-RestMethod -Uri "http://localhost:3002/products/10" -Method DELETE | ConvertTo-Json
```

---

## Tests avec Postman

### Importer la collection

1. Ouvrir Postman
2. Cliquer sur **Import**
3. Sélectionner `products-service/Products-Service.postman_collection.json`
4. Cliquer sur **Import**

### Exécuter les tests

La collection contient 20+ requêtes organisées :

- **Health & Info** : 3 tests
- **Products - GET** : 6 tests
- **Products - POST** : 4 tests
- **Products - PUT** : 4 tests
- **Products - DELETE** : 2 tests
- **Error Cases** : 1 test

**Exécution automatique :**
1. Cliquer sur "Products Service" (le nom de la collection)
2. Cliquer sur **Run**
3. Sélectionner toutes les requêtes
4. Cliquer sur **Run Products Service**

---

## Vérifier Prometheus

### Voir les targets
```powershell
Start-Process "http://localhost:9090/targets"
```

**Vérifier que `products-service` est UP**

### Tester une requête PromQL
```powershell
Start-Process "http://localhost:9090/graph"
```

**Requêtes à tester :**
```promql
# Total des requêtes products
sum(rate(http_requests_total{service="products-service"}[1m]))

# Opérations par type
sum(rate(product_operations_total[5m])) by (operation)

# Stock total
products_total_stock

# Nombre de produits
products_count
```

---

## Voir les métriques brutes

```powershell
Invoke-WebRequest http://localhost:3002/metrics
```

**Métriques à chercher :**
- `http_requests_total{service="products-service"}`
- `product_operations_total{operation="create"}`
- `products_total_stock`
- `products_count`

---

## Architecture complète

```
Services actifs (6) :
┌──────────────────┬──────────┬─────────┐
│ Service          │ Port     │ Status  │
├──────────────────┼──────────┼─────────┤
│ users-postgres   │ 5432     │ UP      │
│ users-service    │ 3000     │ UP      │
│ products-postgres│ 5433     │ UP      │
│ products-service │ 3002     │ UP      │
│ prometheus       │ 9090     │ UP      │
│ grafana          │ 3001     │ UP      │
└──────────────────┴──────────┴─────────┘
```

---

## Cas de test recommandés

### 1. CRUD complet
```powershell
# Create
$product = @{name="Test"; price=99.99} | ConvertTo-Json
$created = Invoke-RestMethod -Uri "http://localhost:3002/products" -Method POST -Body $product -ContentType "application/json"
$id = $created.data.id

# Read
Invoke-RestMethod "http://localhost:3002/products/$id"

# Update
$update = @{price=149.99} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3002/products/$id" -Method PUT -Body $update -ContentType "application/json"

# Delete
Invoke-RestMethod -Uri "http://localhost:3002/products/$id" -Method DELETE
```

### 2. Validation des erreurs
```powershell
# Prix manquant (devrait échouer)
$invalid = @{name="Sans prix"} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3002/products" -Method POST -Body $invalid -ContentType "application/json"

# Prix négatif (devrait échouer)
$negative = @{name="Prix négatif"; price=-50} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3002/products" -Method POST -Body $negative -ContentType "application/json"
```

### 3. Filtres combinés
```powershell
# Catégorie Audio, prix entre 200 et 400, en stock
Invoke-RestMethod "http://localhost:3002/products?category=Audio&minPrice=200&maxPrice=400&inStock=true"
```

---

## Logs en temps réel

```powershell
# Tous les services
docker-compose logs -f

# Products seulement
docker-compose logs -f products-service

# Base de données Products
docker-compose logs -f postgres-products
```

---

## Arrêter proprement

```powershell
# Arrêter tous les services
docker-compose down

# Arrêter et supprimer les données
docker-compose down -v
```

---

## Troubleshooting

### Service ne démarre pas
```powershell
docker-compose logs products-service
```

### Base de données non accessible
```powershell
docker-compose logs postgres-products
docker exec -it products-postgres psql -U clouduser -d productsdb
```

### Redémarrer un service
```powershell
docker-compose restart products-service
```

### Tout reconstruire
```powershell
docker-compose down
docker-compose up -d --build
```

---

## ✅ Checklist de validation

- [ ] `docker-compose ps` montre tous les services UP
- [ ] Health check retourne `{"status": "healthy"}`
- [ ] GET /products retourne 10 produits
- [ ] POST /products crée un nouveau produit
- [ ] PUT /products/:id met à jour un produit
- [ ] DELETE /products/:id supprime un produit
- [ ] Filtres fonctionnent (category, price, stock)
- [ ] Prometheus scrape products-service (targets UP)
- [ ] Métriques visibles dans /metrics
- [ ] Collection Postman s'importe sans erreur

---

**Module 2 - Products Service : Opérationnel ! 🚀**
