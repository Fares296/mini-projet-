# MODULE 4 - LIVRABLES
## Scalabilité Horizontale & Load Balancing

---

## ✅ RÉSUMÉ DES TRAVAUX RÉALISÉS

### Vue d'ensemble

Le Module 4 implémente la **scalabilité horizontale** en déployant **3 instances** du microservice `users-service` avec un **load balancing** automatique via NGINX. Cela démontre la capacité de l'architecture à gérer une charge accrue en ajoutant des instances supplémentaires.

---

## 🚀 1. LANCEMENT DE 3 INSTANCES USERS-SERVICE ✅

### Configuration Docker Compose

**Fichier**: `docker-compose.yml`

#### Instances déployées

```yaml
users-service-1:
  container_name: users-service-1
  hostname: users-service-1
  ports: "3000:3000"
  INSTANCE_ID: "1"

users-service-2:
  container_name: users-service-2
  hostname: users-service-2
  ports: "3004:3000"  
  INSTANCE_ID: "2"

users-service-3:
  container_name: users-service-3
  hostname: users-service-3
  ports: "3003:3000"
  INSTANCE_ID: "3"
```

**Caractéristiques** :
- ✅ **3 conteneurs indépendants** basés sur la même image
- ✅ **Noms d'hôte distincts** pour identification réseau
- ✅ **IDs uniques** via variable d'environnement `INSTANCE_ID`
- ✅ **Ports différents** exposés pour accès direct (3000, 3004, 3003)
- ✅ **Même base de données** PostgreSQL partagée
- ✅ **Démarrage coordonné** avec health checks

### Modifications du code applicatif

**Fichier**: `app.js`

#### Identification des instances

```javascript
// Route racine
app.get('/', (req, res) => {
  res.json({
    message: '🚀 API Users - Microservice Cloud-Native',
    version: '1.0.0',
    instance: process.env.INSTANCE_ID || 'unknown',
    hostname: require('os').hostname(),
    endpoints: { ... }
  });
});

// Health check
app.get('/health', async (req, res) => {
  res.json({ 
    status: 'healthy',
    database: 'connected',
    instance: process.env.INSTANCE_ID || 'unknown',
    hostname: require('os').hostname()
  });
});
```

**Bénéfices** :
- ✅ Chaque réponse identifie l'instance qui l'a traitée
- ✅ Facilite le debugging et le monitoring
- ✅ Permet de vérifier la distribution de charge

---

## ⚖️ 2. CONFIGURATION NGINX LOAD BALANCING ✅

### Fichier: `nginx/gateway.conf`

#### Upstream avec 3 backends

```nginx
upstream users-backend {
    # Stratégie: round-robin (par défaut)
    
    # Instance 1
    server users-service-1:3000 max_fails=3 fail_timeout=30s;
    
    # Instance 2
    server users-service-2:3000 max_fails=3 fail_timeout=30s;
    
    # Instance 3
    server users-service-3:3000 max_fails=3 fail_timeout=30s;
    
    # Connexions persistantes
    keepalive 32;
}
```

**Paramètres de load balancing** :

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| **Algorithme** | round-robin | Distribution séquentielle (défaut) |
| **max_fails** | 3 | Échecs avant de marquer le serveur down |
| **fail_timeout** | 30s | Temps avant de retester un serveur failed |
| **keepalive** | 32 | Connexions persistantes maintenues |

#### Header de tracking

```nginx
location /users {
    proxy_pass http://users-backend;
    
    add_header X-Upstream-Server $upstream_addr;  # IP:PORT du serveur
    add_header X-Served-By "API-Gateway-NGINX";
    add_header X-Service "users-service";
    
    # ... autres configurations
}
```

**Informations trackées** :
- ✅ `X-Upstream-Server` : Adresse IP et port de l'instance backend
- ✅ Permet de vérifier quelle instance a traité chaque requête

### Stratégies de load balancing disponibles

NGINX supporte plusieurs algorithmes (commentés dans le fichier) :

```nginx
# round-robin (défaut) : distribution séquentielle
# Requête 1 → Instance 1
# Requête 2 → Instance 2
# Requête 3 → Instance 3
# Requête 4 → Instance 1...

# least_conn : vers l'instance avec le moins de connexions actives
# ip_hash : même client toujours vers la même instance (sticky sessions)
```

---

## 🧪 3. TESTS DE RÉPARTITION DE CHARGE ✅

### Script automatisé

**Fichier**: `test-load-balancing.ps1`

#### Méthodologie

1. **Envoi de 20 requêtes** via le Gateway (`http://localhost:8080/users`)
2. **Extraction du header** `X-Upstream-Server` de chaque réponse
3. **Mapping IP → Instance** automatique
4. **Comptage des requêtes** par instance
5. **Analyse de la distribution**
6. **Vérification directe** de chaque instance

#### Résultats des tests

**Exécution** :
```powershell
powershell -ExecutionPolicy Bypass -File test-load-balancing.ps1
```

**Output** :
```
========================================
Test de Load Balancing - Users Service
========================================

Envoi de 20 requêtes vers le Gateway...

Request # 1: Instance 1 | Server: 172.19.0.8:3000
Request # 2: Instance 2 | Server: 172.19.0.9:3000
Request # 3: Instance 3 | Server: 172.19.0.7:3000
Request # 4: Instance 1 | Server: 172.19.0.8:3000
Request # 5: Instance 2 | Server: 172.19.0.9:3000
...

========================================
RÉSULTATS DU LOAD BALANCING
========================================

Distribution des requêtes par instance:

Instance 1 | ████████████████████████████ | 7 requêtes (35%)
Instance 2 | ████████████████████████████ | 7 requêtes (35%)
Instance 3 | ████████████████████████   | 6 requêtes (30%)
Instance unknown |  | 0 requêtes (0%)

========================================
ANALYSE
========================================

Total requêtes: 20
Requêtes distribuées: 20
Requêtes non distribuées: 0

Distribution attendue (round-robin):
  ~6.67 requêtes par instance

✅ LOAD BALANCING : OPTIMAL
Les requêtes sont bien réparties entre les 3 instances
```

### Preuves de distribution

#### 1. Pattern Round-Robin visible

```
Instance 1 → Instance 2 → Instance 3 → Instance 1 → Instance 2 → Instance 3...
```

✅ **Schéma répétitif** parfaitement identifiable

#### 2. Distribution équilibrée

| Instance | Requêtes | Pourcentage | Attendu |
|----------|----------|-------------|---------|
| Instance 1 | 7 | 35% | ~33.3% |
| Instance 2 | 7 | 35% | ~33.3% |
| Instance 3 | 6 | 30% | ~33.3% |

✅ **Écart minimal** (< 5% de variation)

#### 3. Toutes les instances actives

```
Instance 1 (port 3000): ✅ HEALTHY | Hostname: users-service-1
Instance 2 (port 3004): ✅ HEALTHY | Hostname: users-service-2
Instance 3 (port 3003): ✅ HEALTHY | Hostname: users-service-3
```

✅ **100% des instances** participent au load balancing

#### 4. Adresses IPs distinctes

```
Instance 1: 172.19.0.8:3000
Instance 2: 172.19.0.9:3000
Instance 3: 172.19.0.7:3000
```

✅ Chaque instance a sa **propre adresse IP** dans le réseau Docker

### Fichier CSV généré

**Fichier**: `load-balancing-results.csv`

Contient pour chaque requête :
- Numéro de requête
- ID de l'instance
- Adresse du serveur upstream
- Code de statut HTTP

**Utilité** : Analyse détaillée, graphiques, reporting

---

## 📊 4. MONITORING PROMETHEUS ✅

### Configuration des targets

**Fichier**: `prometheus.yml`

```yaml
- job_name: 'users-service'
  scrape_interval: 10s
  static_configs:
    # Instance 1
    - targets: ['users-service-1:3000']
      labels:
        service: 'users-service'
        instance_id: '1'
    
    # Instance 2
    - targets: ['users-service-2:3000']
      labels:
        service: 'users-service'
        instance_id: '2'
    
    # Instance 3
    - targets: ['users-service-3:3000']
      labels:
        service: 'users-service'
        instance_id: '3'
```

**Bénéfices** :
- ✅ **Métriques séparées** pour chaque instance
- ✅ **Label `instance_id`** pour filtrage
- ✅ **Monitoring individuel** des performances
- ✅ **Détection de problèmes** sur une instance spécifique

### Requêtes PromQL utiles

```promql
# Requêtes totales par instance
sum(rate(http_requests_total[1m])) by (instance_id)

# Latence par instance
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m])
) by (instance_id)

# Instances UP
up{job="users-service"}

# Compter les instances actives
count(up{job="users-service"} == 1)
```

---

## 🏗️ ARCHITECTURE FINALE

### Schéma CompletNGINX Load Balancer (8080)
            │
    ┌───────┼───────┬───────────┬
    ▼       ▼       ▼           ▼
┌─────┐ ┌─────┐ ┌─────┐   ┌──────────┐
│User │ │User │ │User │   │Products  │
│Svc 1│ │Svc 2│ │Svc 3│   │Service   │
└──┬──┘ └──┬──┘ └──┬──┘   └────┬─────┘
   │       │       │            │
   └───────┴───────┴────────────┘
              ▼
         ┌─────────┐
         │Users DB │
         └─────────┘
```

### 9 conteneurs actifs

| Conteneur | Rôle | Port | Statut |
|-----------|------|------|--------|
| **api-gateway** | NGINX Load Balancer | 8080 | ✅ UP |
| **users-service-1** | Instance 1 | 3000 | ✅ UP |
| **users-service-2** | Instance 2 | 3004 | ✅ UP |
| **users-service-3** | Instance 3 | 3003 | ✅ UP |
| **products-service** | Products API | 3002 | ✅ UP |
| **users-postgres** | PostgreSQL Users | 5432 | ✅ HEALTHY |
| **products-postgres** | PostgreSQL Products | 5433 | ✅ HEALTHY |
| **prometheus** | Métriques | 9090 | ✅ UP |
| **grafana** | Dashboards | 3001 | ✅ UP |

---

## 🎯 VALIDATION DES OBJECTIFS

| Objectif | Livrable | Statut | Preuve |
|----------|----------|--------|--------|
| **Lancer 3 instances** | users-service-1,2,3 | ✅ | `docker-compose ps` |
| **Config NGINX LB** | gateway.conf upstream | ✅ | 3 servers configurés |
| **Test répartition** | Script PowerShell | ✅ | Distribution 35/35/30% |
| **Preuve distribution** | CSV + logs | ✅ | 20 requêtes analysées |
| **Round-robin** | Pattern visible | ✅ | Séquence 1-2-3-1-2-3 |
| **Toutes instances actives** | Health checks | ✅ | 3/3 healthy |

**TOUS LES OBJECTIFS SONT ATTEINTS** ✅

---

## 📝 COMMANDES DE VÉRIFICATION

### Voir les conteneurs

```powershell
docker-compose ps
```

**Attendu** : 9 services UP (dont 3 users-service)

### Tester le load balancing

```powershell
powershell -ExecutionPolicy Bypass -File test-load-balancing.ps1
```

**Attendu** : Distribution ~33% par instance

### Accès direct aux instances

```powershell
# Instance 1
Invoke-RestMethod http://localhost:3000/health

# Instance 2
Invoke-RestMethod http://localhost:3004/health

# Instance 3
Invoke-RestMethod http://localhost:3003/health
```

**Attendu** : Chaque instance retourne son hostname

### Via le Gateway (load balanced)

```powershell
# 10 requêtes pour voir la rotation
for ($i=1; $i -le 10; $i++) {
    $response = Invoke-WebRequest http://localhost:8080/users
    Write-Host "Request $i : " -NoNewline
    Write-Host $response.Headers['X-Upstream-Server']
}
```

**Attendu** : Rotation visible des adresses IP

---

## 🔍 TESTS DE DÉFAILLANCE

### Simuler une panne d'instance

```powershell
# Arrêter instance 2
docker stop users-service-2

# Tester (devrait répartir sur instances 1 et 3 uniquement)
powershell -ExecutionPolicy Bypass -File test-load-balancing.ps1

# Redémarrer
docker start users-service-2
```

**Résultat attendu** :
- NGINX détecte l'instance down
- Répartit sur les 2 instances restantes
- Récupération automatique au redémarrage

---

## 📈 BÉNÉFICES DE LA SCALABILITÉ HORIZONTALE

### 1. Performance

- ✅ **3x plus de capacité** de traitement
- ✅ **Réduction de la latence** (charge distribuée)
- ✅ **Parallélisation** des requêtes

### 2. Disponibilité

- ✅ **High Availability** : Une instance peut tomber sans interruption
- ✅ **Zero Downtime Deployment** possible
- ✅ **Failover automatique** via NGINX

### 3. Scalabilité

- ✅ **Scale OUT facile** : Ajouter des instances à la demande
- ✅ **Scale IN** : Réduire si charge faible
- ✅ **Auto-scaling** possible (Kubernetes, Docker Swarm)

### 4. Coût

- ✅ **Pay-per-use** : Adapter les ressources à la charge
- ✅ **Optimisation** : Pas de sur-provisioning

---

## 🔄 ÉVOLUTION FUTURE

### Scaling dynamique

```yaml
users-service:
  deploy:
    replicas: 3
    update_config:
      parallelism: 1
      delay: 10s
    restart_policy:
      condition: on-failure
```

### Health checks avancés

```nginx
upstream users-backend {
    server users-service-1:3000 max_fails=2 fail_timeout=10s;
    server users-service-2:3000 max_fails=2 fail_timeout=10s;
    server users-service-3:3000 max_fails=2 fail_timeout=10s backup;  # Backup
    
    # Active health checks (NGINX Plus)
    # health_check interval=5s fails=3 passes=2;
}
```

### Load balancing avancé

```nginx
# Weighted round-robin
server users-service-1:3000 weight=3;  # 3x plus de requêtes
server users-service-2:3000 weight=2;
server users-service-3:3000 weight=1;

# Least connections
least_conn;

# IP Hash (sticky sessions)
ip_hash;
```

---

## ✨ CONCLUSION

Le Module 4 démontre avec succès la **scalabilité horizontale** de l'architecture microservices.

**Points forts** :
- ✅ **3 instances** déployées et fonctionnelles
- ✅ **Load balancing NGINX** configuré et testé
- ✅ **Distribution optimale** des requêtes (round-robin)
- ✅ **Monitoring** de chaque instance via Prometheus
- ✅ **Preuves tangibles** via script de test et CSV

**Métriques** :
- 9 conteneurs orchestrés
- 3 instances users-service en load balancing
- Distribution: 35% / 35% / 30% (optimal)
- 100% des requêtes distribuées correctement

**Date de réalisation** : 5 décembre 2025  
**Technologies** : Docker Compose, NGINX, PowerShell  
**Status** : ✅ **MODULE 4 COMPLÉTÉ**

---

**🎉 SCALABILITÉ HORIZONTALE OPÉRATIONNELLE !**
