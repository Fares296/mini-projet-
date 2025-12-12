# MODULE 5 - LIVRABLES
## Redis Cache

---

## ✅ RÉSUMÉ DES TRAVAUX RÉALISÉS

### Vue d'ensemble

Le Module 5 implémente un **système de cache Redis** pour améliorer les performances de l'API. Redis est utilisé pour cacher les résultats de la requête `GET /users`, réduisant drastiquement le temps de réponse et la charge sur la base de données PostgreSQL.

---

## 🚀 1. AJOUT DE REDIS AU DOCKER-COMPOSE ✅

### Configuration

**Fichier**: `docker-compose.yml`

```yaml
redis:
  image: redis:7-alpine
  container_name: redis-cache
  ports:
    - "6379:6379"
  command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
  volumes:
    - redis_data:/data
  networks:
    - cloud-network
  restart: unless-stopped
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 3
```

**Paramètres clés** :

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| **Image** | redis:7-alpine | Version 7 légère (~40MB) |
| **Port** | 6379 | Port standard Redis |
| **appendonly** | yes | Persistence AOF activée |
| **maxmemory** | 256mb | Limite mémoire |
| **maxmemory-policy** | allkeys-lru | Éviction LRU (Least Recently Used) |
| **healthcheck** | redis-cli ping | Vérification santé |

### Volume ajouté

```yaml
volumes:
  redis_data:
    driver: local
```

✅ **Persistence** : Les données Redis survivent aux redémarrages

---

## 💻 2. MODIFICATION DU USERS-SERVICE ✅

### 2.1 Dépendance Redis

**Fichier**: `package.json`

```json
"dependencies": {
  "express": "^4.18.2",
  "pg": "^8.11.3",
  "cors": "^2.8.5",
  "dotenv": "^16.3.1",
  "prom-client": "^15.1.0",
  "redis": "^4.6.0"  ← NOUVEAU
}
```

### 2.2 Configuration du client Redis

**Fichier**: `app.js`

```javascript
const redis = require('redis');

// Configuration du client Redis
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  }
});

// Connexion à Redis
redisClient.connect().catch(console.error);

redisClient.on('connect', () => {
  console.log('✅ Connexion à Redis réussie!');
});

redisClient.on('error', (err) => {
  console.error('❌ Erreur Redis:', err);
});
```

### 2.3 Variables d'environnement

**Dans docker-compose.yml** (pour chaque instance) :

```yaml
environment:
  REDIS_HOST: redis
  REDIS_PORT: 6379
```

**Dépendance ajoutée** :

```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy  ← NOUVEAU
```

---

## 🔄 3. LOGIQUE DE CACHE POUR GET /USERS ✅

### 3.1 Implémentation

**Fichier**: `app.js`

```javascript
// 1. GET /users - Lister tous les utilisateurs (AVEC CACHE REDIS)
app.get('/users', async (req, res) => {
  const cacheKey = 'users:all';
  
  try {
    // 1. Essayer de récupérer depuis le cache
    const cachedData = await redisClient.get(cacheKey);
    
    if (cachedData) {
      // CACHE HIT - Données trouvées dans Redis
      console.log('✅ Cache HIT pour /users');
      cacheHitsCounter.inc({ cache_type: 'users_list' });
      
      const parsedData = JSON.parse(cachedData);
      
      return res.json({
        success: true,
        count: parsedData.length,
        data: parsedData,
        cached: true,  ← Indicateur de cache
        instance: process.env.INSTANCE_ID || 'unknown'
      });
    }
    
    // CACHE MISS - Données non trouvées, interroger la BD
    console.log('❌ Cache MISS pour /users - Interrogation de la DB');
    cacheMissesCounter.inc({ cache_type: 'users_list' });
    
    const result = await pool.query(
      'SELECT id, name, email, created_at FROM users ORDER BY id ASC'
    );

    // Stocker dans Redis avec TTL de 60 secondes
    await redisClient.setEx(cacheKey, 60, JSON.stringify(result.rows));
    console.log('💾 Données stockées dans Redis (TTL: 60s)');

    userOperationsCounter.inc({ operation: 'list' });

    res.json({
      success: true,
      count: result.rows.length,
      data: result.rows,
      cached: false,  ← Données fraîches
      instance: process.env.INSTANCE_ID || 'unknown'
    });
  } catch (error) {
    console.error('Erreur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur'
    });
  }
});
```

### 3.2 Flux de cache

```
Client Request → GET /users
         ↓
    Check Redis
         ↓
    ┌────────┐
    │ Found? │
    └───┬────┘
        │
    YES │ NO
     ↓      ↓
  CACHE   Query
   HIT    PostgreSQL
     ↓      ↓
 Return  Store in
  Data   Redis (TTL:60s)
     ↓      ↓
    Client Response
```

### 3.3 Invalidation du cache

**POST /users - Créer un utilisateur**

```javascript
// Invalider le cache car la liste a changé
await redisClient.del('users:all');
console.log('🗑️  Cache invalidé après création d\'utilisateur');
```

**DELETE /users/:id - Supprimer un utilisateur**

```javascript
// Invalider le cache car la liste a changé
await redisClient.del('users:all');
console.log('🗑️  Cache invalidé après suppression d\'utilisateur');
```

**Pourquoi invalider ?**
- ✅ Assure la **cohérence** des données
- ✅ Le prochain GET récupérera les données à jour
- ✅ Évite de servir des données obsolètes

---

## 📊 4. MÉTRIQUES PROMETHEUS ✅

### Nouveaux compteurs ajoutés

```javascript
// Compteur de cache hits
const cacheHitsCounter = new promClient.Counter({
  name: 'cache_hits_total',
  help: 'Total des cache hits',
  labelNames: ['cache_type']
});

// Compteur de cache misses
const cacheMissesCounter = new promClient.Counter({
  name: 'cache_misses_total',
  help: 'Total des cache misses',
  labelNames: ['cache_type']
});
```

**Requêtes PromQL utiles** :

```promql
# Taux de cache hits
rate(cache_hits_total[1m])

# Taux de cache misses
rate(cache_misses_total[1m])

# Taux de succès du cache (hit rate)
sum(rate(cache_hits_total[5m])) / 
(sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m])))

# Latence avec et sans cache
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket{route="/users"}[5m])
)
```

---

## 📈 5. COMPARAISON DES PERFORMANCES ✅

### 5.1 Script de benchmark

**Fichier**: `test-redis-cache.ps1`

**Méthodologie** :
1. Premier appel → CACHE MISS (interroge la BD)
2. Appels suivants → CACHE HIT (depuis Redis)
3. Mesure du temps de réponse pour chaque requête
4. Calcul des moyennes et amélioration

### 5.2 Résultats du benchmark

**Test effectué** : 10 requêtes GET /users via le gateway

#### Résultats bruts

```
Phase 1: Premier appel (CACHE MISS)
Requête #1: 111ms | Cached: False | Instance: 3 | Users: 11

Phase 2: Appels suivants (CACHE HIT)
Requête # 2: 3ms  | Cached: True | Instance: 3
Requête # 3: 6ms  | Cached: True | Instance: 2
Requête # 4: 4ms  | Cached: True | Instance: 3
Requête # 5: 5ms  | Cached: True | Instance: 2
Requête # 6: 4ms  | Cached: True | Instance: 3
Requête # 7: 3ms  | Cached: True | Instance: 2
Requête # 8: 3ms  | Cached: True | Instance: 3
Requête # 9: 4ms  | Cached: True | Instance: 2
Requête #10: 4ms  | Cached: True | Instance: 3
```

#### Analyse statistique

| Métrique | Sans Cache (DB) | Avec Cache (Redis) |
|----------|-----------------|---------------------|
| **Temps moyen** | 111 ms | 4 ms |
| **Temps minimum** | 111 ms | 3 ms |
| **Temps maximum** | 111 ms | 6 ms |
| **Nombre de requêtes** | 1 | 9 |

#### Amélioration des performances

```
Temps de réponse : 111ms → 4ms

AMÉLIORATION: 96.4% plus rapide
FACTEUR: 27.75x plus rapide avec cache
```

**Graphique comparatif** :

```
Sans cache (DB):  ███████████████████████████████████ 111ms
Avec cache:       █                                   4ms

Speed-up: 27.75x
```

### 5.3 Métriques Redis

**Statistiques du serveur Redis** :

```
Cache Hits: 9
Cache Misses: 1  
Hit Rate: 90%
```

✅ **Taux de succès excellent** (90%) dès les premiers tests

---

## 🎯 6. VALIDATION DES OBJECTIFS

| Objectif | Livrable | Statut | Preuve |
|----------|----------|--------|--------|
| **Redis au docker-compose** | Service redis | ✅ | docker-compose.yml |
| **Vérifier cache GET /users** | Logique cache | ✅ | app.js (cache hit/miss) |
| **Stocker si non trouvé** | setEx avec TTL | ✅ | app.js (60s TTL) |
| **Code du cache** | Implémentation | ✅ | app.js complet |
| **Comparaison performances** | Benchmark | ✅ | test-redis-cache.ps1 |
| **Amélioration mesurable** | 96.4% plus rapide | ✅ | 111ms vs 4ms |

**TOUS LES OBJECTIFS SONT ATTEINTS** ✅

---

## 📝 7. CODE DU CACHE - DÉTAILS

### Clé de cache

```javascript
const cacheKey = 'users:all';
```

**Format** : `resource:identifier`
- ✅ Permet de gérer plusieurs types de cache
- ✅ Facile à identifier et invalider

### TTL (Time To Live)

```javascript
await redisClient.setEx(cacheKey, 60, JSON.stringify(result.rows));
```

**TTL = 60 secondes**

**Pourquoi 60s ?**
- ✅ Équilibre entre **performance** et **fraîcheur** des données
- ✅ Évite de servir des données trop anciennes
- ✅ Adapté pour une API avec modifications occasionnelles

**Alternatives** :
- Données peu changeantes : TTL 300s (5 min) ou plus
- Données très volatiles : TTL 10-30s
- Cache infini : Invalidation manuelle uniquement

### Stratégie d'invalidation

**Cache-Aside (Lazy Loading)** :
1. Ne pas remplir le cache à l'avance
2. Remplir uniquement lors d'un MISS
3. Invalider lors de modifications

**Avantages** :
- ✅ Pas de données inutilisées en cache
- ✅ Cache toujours "chaud" (données populaires)
- ✅ Simple à implémenter

---

## 🏗️ ARCHITECTURE AVEC REDIS

### Avant Redis

```
Client → API Gateway → Users Service → PostgreSQL
                         (111ms)
```

### Après Redis

```
Client → API Gateway → Users Service → Redis (4ms) ✅
                             ↓
                         PostgreSQL (111ms)
                      (Si cache miss uniquement)
```

### Flux complet

```
┌────────┐
│ Client │
└───┬────┘
    │ GET /users
    ▼
┌─────────────┐
│   Gateway   │
└──────┬──────┘
       │
       ▼
┌──────────────┐      ┌────────┐
│ Users-Svc-1  │──────│ Redis  │ CACHE HIT (4ms)
│ Users-Svc-2  │      └────────┘
│ Users-Svc-3  │          │
└──────┬───────┘          │ CACHE MISS
       │                  ▼
       │            ┌───────────┐
       └────────────│PostgreSQL │ (111ms)
                    └───────────┘
```

---

## 📂 8. FICHIERS MODIFIÉS

### Configuration

✅ `docker-compose.yml` - Service Redis + volumes  
✅ `package.json` - Dépendance redis  

### Code

✅ `app.js` - Client Redis + logique cache + invalidation  

### Tests

✅ `test-redis-cache.ps1` - Benchmark performances  
✅ `redis-cache-benchmark.csv` - Résultats détaillés  

---

## 🧪 9. COMMANDES DE VÉRIFICATION

### Vérifier Redis

```powershell
# Status du conteneur
docker-compose ps redis

# Ping Redis
docker exec redis-cache redis-cli ping
# Attendu: PONG

# Statistiques
docker exec redis-cache redis-cli INFO stats

# Voir les clés
docker exec redis-cache redis-cli KEYS '*'
# Attendu: "users:all" (si cache actif)

# Voir le contenu
docker exec redis-cache redis-cli GET users:all
```

### Tester le cache

```powershell
# 1ère requête (MISS)
Invoke-RestMethod http://localhost:8080/users
# cached: false

# 2ème requête (HIT)
Invoke-RestMethod http://localhost:8080/users
# cached: true
```

### Benchmark

```powershell
powershell -ExecutionPolicy Bypass -File test-redis-cache.ps1
```

### Voir les logs

```powershell
docker-compose logs -f users-service-1 | Select-String "cache"
```

**Output attendu** :
```
✅ Cache HIT pour /users
❌ Cache MISS pour /users
💾 Données stockées dans Redis
🗑️  Cache invalidé
```

---

## 💡 10. BÉNÉFICES DU CACHE REDIS

### Performance

- ✅ **27.75x plus rapide** (111ms → 4ms)
- ✅ **96.4% de réduction** du temps de réponse
- ✅ **Latence ultra-faible** grâce à Redis in-memory

### Scalabilité

- ✅ **Réduction de la charge DB** : Moins de requêtes PostgreSQL
- ✅ **Support plus d'utilisateurs** avec les mêmes ressources
- ✅ **Économie de connexions DB**

### Expérience utilisateur

- ✅ **Réponses quasi-instantanées** (< 5ms)
- ✅ **Interface plus réactive**
- ✅ **Satisfaction utilisateur améliorée**

### Coûts

- ✅ **Moins de CPU** sur PostgreSQL
- ✅ **Moins I/O disque**
- ✅ **Optimisation des ressources cloud**

---

## 🔮 11. ÉVOLUTIONS POSSIBLES

### Cache avancé

```javascript
// Cache par utilisateur
const cacheKey = `user:${id}`;

// Cache de requêtes avec filtres
const cacheKey = `products:category:${category}`;

// Cache multi-niveaux (L1: mémoire, L2: Redis)
const cachedData = inMemoryCache.get(key) || 
                   await redisClient.get(key);
```

### Patterns avancés

**Write-Through Cache** :
```javascript
// Écrire en DB ET cache en même temps
await pool.query(...);
await redisClient.set(cacheKey, data);
```

**Cache Stampede Prevention** :
```javascript
// Éviter que 1000 requêtes simultanées frappent la DB
const lock = await redisClient.setNX('lock:users', '1', 'EX', 5);
if (lock) {
  // Seul ce thread interroge la DB
}
```

### Monitoring

- Dashboard Grafana pour Hit Rate
- Alertes si Hit Rate < 50%
- Métriques de mémoire Redis
- Suivi des évictions

---

## ✨ CONCLUSION

Le Module 5 démontre l'**impact majeur du caching** sur les performances d'une API.

**Points forts** :
- ✅ **Redis déployé** et configuré
- ✅ **Cache fonctionnel** avec hit/miss tracking
- ✅ **Amélioration spectaculaire** : 96.4% plus rapide
- ✅ **Invalidation automatique** pour cohérence des données
- ✅ **Métriques Prometheus** pour monitoring

**Résultats** :
- Temps de réponse : **111ms → 4ms**
- Facteur d'amélioration : **27.75x**
- Hit Rate : **90%**
- Load database réduite de **90%**

**Date de réalisation** : 5 décembre 2025  
**Technologies** : Redis 7, Node.js redis client, Docker  
**Status** : ✅ **MODULE 5 COMPLÉTÉ**

---

**🎉 SYSTÈME DE CACHE REDIS OPÉRATIONNEL !**
