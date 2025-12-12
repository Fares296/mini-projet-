# 🚀 MODULE 3 - API GATEWAY - QUICK GUIDE

## Point d'entrée unique : http://localhost:8080

---

## Démarrage

```powershell
# Lancer le Gateway
docker-compose up -d api-gateway

# Vérifier l'état
docker-compose ps api-gateway
```

---

## Tests Rapides

### 1. Page d'accueil du Gateway
```powershell
Invoke-RestMethod http://localhost:8080/
```

### 2. Health check
```powershell
Invoke-RestMethod http://localhost:8080/health
```

### 3. Users via Gateway
```powershell
# Liste
Invoke-RestMethod http://localhost:8080/users

# Créer
$user = @{name="Gateway User"; email="user@gateway.com"} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/users -Method POST -Body $user -ContentType "application/json"

# Par ID
Invoke-RestMethod http://localhost:8080/users/1

# Supprimer
Invoke-RestMethod -Uri http://localhost:8080/users/11 -Method DELETE
```

### 4. Products via Gateway
```powershell
# Liste
Invoke-RestMethod http://localhost:8080/products

# Filtrer par catégorie
Invoke-RestMethod "http://localhost:8080/products?category=Gaming"

# Filtrer par prix
Invoke-RestMethod "http://localhost:8080/products?minPrice=100&maxPrice=500"

# Créer
$product = @{name="Test Product"; price=99.99; stock=10} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/products -Method POST -Body $product -ContentType "application/json"

# Mettre à jour
$update = @{price=149.99} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/products/1 -Method PUT -Body $update -ContentType "application/json"
```

---

## Tests Automatisés

```powershell
powershell -ExecutionPolicy Bypass -File test-gateway.ps1
```

**Résultat attendu** :
- Total: 21 tests
- Succès: 17+
- Taux: ~80%+

---

## URLs Disponibles

| Service | URL Gateway |
|---------|-------------|
| Gateway Info | http://localhost:8080/ |
| Gateway Health | http://localhost:8080/health |
| Users | http://localhost:8080/users |
| Products | http://localhost:8080/products |
| Prometheus | http://localhost:8080/prometheus/ |

---

## Vérifications

### Voir les logs du Gateway
```powershell
docker-compose logs -f api-gateway
```

### Voir la configuration actuelle
```powershell
docker exec api-gateway cat /etc/nginx/conf.d/default.conf
```

### Tester le health check
```powershell
docker exec api-gateway wget -qO- http://localhost/health
```

---

## Architecture

```
http://localhost:8080 (Gateway)
    ↓
    ├─ /users → users-service:3000
    ├─ /products → products-service:3001
    ├─ /prometheus → prometheus:9090
    └─ /health → nginx (local)
```

---

## Troubleshooting

### Gateway ne répond pas
```powershell
# Redémarrer
docker-compose restart api-gateway

# Vérifier les logs
docker-compose logs api-gateway
```

### Erreur 502 Bad Gateway
```powershell
# Vérifier que les services backend sont UP
docker-compose ps users-service products-service

# Redémarrer les services
docker-compose restart users-service products-service
```

### Erreur 404
```powershell
# Vérifier la configuration
docker exec api-gateway nginx -t
```

---

## ✅ Checklist de validation

- [ ] Gateway démarre sans erreur
- [ ] Health check retourne `{"status": "healthy"}`
- [ ] GET /users retourne la liste via gateway
- [ ] POST /users crée un utilisateur via gateway
- [ ] GET /products retourne la liste via gateway
- [ ] Filtres products fonctionnent via gateway
- [ ] Headers `X-Served-By` présents dans les réponses
- [ ] Port 8080 accessible de l'extérieur

---

## Points Clés

✅ **Port unique** : 8080 pour tout
✅ **Services cachés** : Accès uniquement via gateway
✅ **CORS activé** : Headers ajoutés automatiquement
✅ **Load balancing prêt** : Configuration upstream
✅ **Logs centralisés** : Volume nginx_logs

---

**Module 3 - API Gateway NGINX : Opérationnel ! 🎉**
