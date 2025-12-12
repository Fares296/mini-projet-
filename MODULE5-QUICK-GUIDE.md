# 🚀 MODULE 5 - REDIS CACHE - QUICK GUIDE

## Cache ultra-rapide pour GET /users

---

## Démarrage

```powershell
# Lancer avec Redis
docker-compose up -d redis users-service-1 users-service-2 users-service-3

# Vérifier l'état
docker-compose ps redis
```

**Attendu** : `redis-cache  Up  (healthy)`

---

## Test du Cache

### Test manuel

```powershell
# 1ère requête (CACHE MISS - lent)
Measure-Command { Invoke-RestMethod http://localhost:8080/users }
```
**Attendu** : ~100-150ms, `cached: false`

```powershell
# 2ème requête (CACHE HIT - rapide)
Measure-Command { Invoke-RestMethod http://localhost:8080/users }
```
**Attendu** : ~3-10ms, `cached: true`

### Benchmark automatisé (recommandé)

```powershell
powershell -ExecutionPolicy Bypass -File test-redis-cache.ps1
```

**Résultat attendu** :
```
Requête #1: 111ms | Cached: False  ← CACHE MISS
Requête #2: 4ms   | Cached: True   ← CACHE HIT
Requête #3: 4ms   | Cached: True   
...

AMÉLIORATION: 96.4% plus rapide
FACTEUR: 27.75x plus rapide
Hit Rate: 90%
```

---

## Vérifications Redis

### Accès direct Redis

```powershell
# Ping pong
docker exec redis-cache redis-cli ping
```
**Attendu** : `PONG`

### Voir les clés en cache

```powershell
docker exec redis-cache redis-cli KEYS '*'
```
**Attendu** : `"users:all"` (après au moins 1 requête)

### Voir le contenu du cache

```powershell
docker exec redis-cache redis-cli GET users:all
```
**Attendu** : JSON avec liste des utilisateurs

### Statistiques

```powershell
docker exec redis-cache redis-cli INFO stats
```

Chercher :
- `keyspace_hits` : Nombre de cache hits
- `keyspace_misses` : Nombre de cache misses

---

## Test d'invalidation

```powershell
# 1. Cache hit
Invoke-RestMethod http://localhost:8080/users
# cached: true

# 2. Créer un utilisateur (invalide le cache)
$user = @{name="Cache Test"; email="cache@test.com"} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/users -Method POST -Body $user -ContentType "application/json"

# 3. Cache miss (données rafraîchies)
Invoke-RestMethod http://localhost:8080/users
# cached: false, nouveau user présent

# 4. Cache hit à nouveau
Invoke-RestMethod http://localhost:8080/users
# cached: true
```

---

## Voir les logs

```powershell
# Logs instance 1
docker-compose logs -f users-service-1 | Select-String "cache"
```

**Output attendu** :
```
✅ Cache HIT pour /users
❌ Cache MISS pour /users
💾 Données stockées dans Redis (TTL: 60s)
🗑️  Cache invalidé après création d'utilisateur
```

---

## Métriques Prometheus

### URL : http://localhost:9090

```promql
# Taux de cache hits
rate(cache_hits_total[1m])

# Taux de cache misses
rate(cache_misses_total[1m])

# Hit rate (%)
sum(rate(cache_hits_total[5m])) / (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m]))) * 100

# Latence /users
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{route="/users"}[5m]))
```

---

## ✅ Checklist de validation

- [ ] Redis démarre sans erreur  
- [ ] Health check Redis retourne "healthy"  
- [ ] 1ère requête `cached: false` (~100ms)  
- [ ] 2ème requête `cached: true` (~5ms)  
- [ ] Amélioration > 90% observée  
- [ ] Invalidation fonctionne (POST/DELETE)  
- [ ] Hit Rate Prometheus > 50%  
- [ ] Logs montrent "Cache HIT/MISS"  

---

## Résultats attendus

**Performance** :
```
Sans cache (DB):     111ms
Avec cache (Redis):  4ms

Amélioration: 96.4% (27.75x plus rapide)
```

**Redis Stats** :
```
Cache Hits: 9
Cache Misses: 1
Hit Rate: 90%
```

---

## Troubleshooting

### Redis ne démarre pas

```powershell
# Voir les logs
docker-compose logs redis

# Redémarrer
docker-compose restart redis
```

### Toujours "cached: false"

```powershell
# Vérifier la connexion Redis dans les logs
docker-compose logs users-service-1 | Select-String "Redis"
```

**Attendu** : `✅ Connexion à Redis réussie!`

### Cache ne s'invalide pas

```powershell
# Supprimer manuellement
docker exec redis-cache redis-cli DEL users:all

# Vérifier
docker exec redis-cache redis-cli EXISTS users:all
```

**Attendu** : `0` (clé n'existe plus)

---

**Module 5 - Redis Cache : Opérationnel ! ⚡**

**Amélioration de performance : ~97% !**
