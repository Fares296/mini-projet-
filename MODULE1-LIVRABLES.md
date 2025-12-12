# MODULE 1 - LIVRABLES
## Observabilité : Prometheus & Grafana

---

## ✅ RÉSUMÉ DES TRAVAUX RÉALISÉS

### 1. Endpoint /metrics dans users-service ✅

**Fichier**: `app.js` (lignes 10-120)

L'endpoint `/metrics` expose les métriques suivantes au format Prometheus :

#### Métriques personnalisées :
- **http_requests_total** : Compteur des requêtes HTTP par méthode, route et code de statut
- **http_request_duration_seconds** : Histogramme de la durée des requêtes (buckets: 1ms, 5ms, 10ms, 50ms, 100ms, 500ms, 1s, 5s)
- **http_errors_total** : Compteur des erreurs HTTP (codes >= 400)
- **db_connections_active** : Gauge du nombre de connexions actives à PostgreSQL
- **user_operations_total** : Compteur des opérations CRUD sur les utilisateurs

#### Métriques système (automatiques) :
- Utilisation CPU (process_cpu_seconds_total)
- Mémoire heap Node.js (nodejs_heap_size_total_bytes, nodejs_heap_size_used_bytes)
- Garbage collection (nodejs_gc_duration_seconds)
- Version Node.js (nodejs_version_info)

**Test** :
```powershell
Invoke-WebRequest -Uri "http://localhost:3000/metrics"
```

---

### 2. Docker Compose mis à jour ✅

**Fichier**: `docker-compose.yml`

#### Services orchestrés :

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| **postgres** | postgres:15-alpine | 5432 | Base de données PostgreSQL |
| **users-service** | Build local | 3000 | Microservice Users (Node.js) |
| **prometheus** | prom/prometheus:latest | 9090 | Collecteur de métriques |
| **grafana** | grafana/grafana:latest | 3001 | Visualisation et dashboards |

#### Caractéristiques :

- **Réseau partagé** : `cloud-network` (bridge) pour la communication entre services
- **Volumes persistants** :
  - `postgres_data` : Données PostgreSQL
  - `prometheus_data` : Données de time-series Prometheus
  - `grafana_data` : Configuration et dashboards Grafana
- **Health checks** : PostgreSQL avec `pg_isready`
- **Dépendances** : users-service attend que PostgreSQL soit "healthy"
- **Auto-restart** : `restart: unless-stopped` pour tous les services

---

### 3. Configuration Prometheus ✅

**Fichier**: `prometheus.yml`

#### Configuration de scraping :

```yaml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'users-service'
    scrape_interval: 10s
    metrics_path: '/metrics'
    static_configs:
      - targets: ['users-service:3000']
        labels:
          service: 'users-service'
          team: 'cloud'
          version: '1.0.0'
```

**Paramètres** :
- Scraping toutes les 10 secondes
- Monitoring de Prometheus lui-même
- Labels personnalisés pour filtrage et organisation

**Vérification** :
- URL : http://localhost:9090
- Onglet Status → Targets
- État attendu : users-service = UP ✅

---

### 4. Configuration Grafana ✅

**Accès** :
- URL : http://localhost:3001
- Username : `admin`
- Password : `admin123`

#### Provisioning automatique :

**Datasource** (`grafana/provisioning/datasources/prometheus.yml`) :
- Source de données Prometheus configurée automatiquement
- URL : http://prometheus:9090
- Définie comme source par défaut

**Dashboards** (`grafana/provisioning/dashboards/dashboards.yml`) :
- Chargement automatique des dashboards au démarrage
- Modifications persistantes autorisées

---

### 5. Dashboard Grafana créé ✅

**Fichier**: `grafana/dashboards/users-service-dashboard.json`

**Titre**: "Users Service - Monitoring Cloud Native"

#### Panels créés (9 panels) :

| # | Titre | Type | Métrique | Description |
|---|-------|------|----------|-------------|
| 1 | 📊 Requêtes par seconde | Timeseries | `rate(http_requests_total[1m])` | Graphique du nombre de requêtes/s par route et code HTTP |
| 2 | ⚡ Total Requêtes/sec | Gauge | `sum(rate(http_requests_total[1m]))` | Jauge du total de requêtes |
| 3 | 🚨 Erreurs HTTP/sec | Stat | `sum(rate(http_errors_total[5m]))` | Nombre d'erreurs par seconde |
| 4 | ⏱️ Latence des requêtes | Timeseries | P50, P95, P99 percentiles | Graphique de la latence (percentiles) |
| 5 | 💚 Disponibilité | Stat | `up{job="users-service"}` | Indicateur UP/DOWN du service |
| 6 | 🗄️ Connexions DB | Timeseries | `db_connections_active` | Connexions actives à PostgreSQL |
| 7 | 👥 Opérations utilisateurs | Timeseries | `rate(user_operations_total[5m])` | Répartition create/list/get/delete |
| 8 | 📈 Distribution codes HTTP | Piechart | `increase(http_requests_total[1h])` | Camembert des codes de statut |
| 9 | ✅ Taux de succès | Gauge | Calcul du % de requêtes sans erreur | Pourcentage de disponibilité |

#### Fonctionnalités :

- **Auto-refresh** : Toutes les 5 secondes
- **Time range** : Dernières 15 minutes
- **Seuils configurés** : 
  - Latence : Vert < 0.1s, Jaune < 0.5s, Rouge >= 0.5s
  - Requêtes/sec : Vert < 50, Jaune < 100, Rouge >= 100
- **Légendes enrichies** : Moyenne, Max, Min selon le panel

---

## 📸 CAPTURES D'ÉCRAN

### 1. Dashboard Grafana complet

**Fichier** : `grafana_dashboard_full_1764890655950.png`

**Contenu visible** :
- ✅ Tous les 9 panels affichés
- ✅ Données en temps réel après génération de trafic
- ✅ Graphiques avec activité visible
- ✅ Indicateurs de disponibilité verts (service UP)
- ✅ Métriques de latence, requêtes/sec, erreurs

**Métriques observables** :
- Requêtes par seconde : Activité visible sur les routes GET /users, /health, /metrics
- Latence P50/P95/P99 : Temps de réponse < 50ms
- Disponibilité : 100% (UP)
- Connexions DB : 1 connexion active stable
- Taux de succès : ~95-100%

---

### 2. Prometheus Targets

**Fichier** : `prometheus_targets_status_1764890666259.png`

**Contenu visible** :
- ✅ Job "users-service" : État **UP**
- ✅ Endpoint : http://users-service:3000/metrics
- ✅ Last scrape : Récent (< 10s)
- ✅ Labels : service="users-service", team="cloud", version="1.0.0"

Cela confirme que Prometheus scrape correctement le microservice.

---

## 🧪 TESTS RÉALISÉS

### Script de génération de trafic

**Fichier** : `generate-traffic.ps1`

**Opérations effectuées** :
1. ✅ Health check (1 requête)
2. ✅ Listing de tous les utilisateurs (10 requêtes)
3. ✅ Consultation d'utilisateurs individuels (5 requêtes)
4. ✅ Création de nouveaux utilisateurs (5 POST)
5. ✅ Génération d'erreurs 404 (5 requêtes)
6. ✅ Stress test (20 requêtes rapides)

**Résultat** :
```
SUCCESS: Service is healthy
SUCCESS: Created user: Sophie Martin
SUCCESS: Created user: Lucas Dubois
SUCCESS: Created user: Emma Petit
SUCCESS: Created user: Noah Robert
SUCCESS: Created user: Lea Moreau
SUCCESS: Total users now: 10
SUCCESS: Metrics endpoint is working
```

---

## 📂 STRUCTURE DU PROJET

```
mini-projet-/
├── app.js                          # Microservice avec endpoint /metrics
├── package.json                    # Dépendances (prom-client inclus)
├── Dockerfile                      # Image Docker du service
├── docker-compose.yml              # Orchestration complète
├── prometheus.yml                  # Configuration Prometheus
├── init.sql                        # Script d'initialisation PostgreSQL
├── README.md                       # Documentation complète
├── generate-traffic.ps1           # Script de test
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── prometheus.yml     # Auto-config datasource
    │   └── dashboards/
    │       └── dashboards.yml     # Auto-load dashboards
    └── dashboards/
        └── users-service-dashboard.json  # Dashboard principal
```

---

## 🚀 COMMANDES DE DÉMARRAGE

### Démarrer l'infrastructure complète

```powershell
cd "C:\Users\fares\OneDrive\Bureau\mini-projet-"
docker-compose up -d --build
```

### Vérifier que tous les services sont actifs

```powershell
docker-compose ps
```

**Résultat attendu** :
```
NAME             STATUS
grafana          Up
prometheus       Up
users-postgres   Up (healthy)
users-service    Up
```

### Accéder aux interfaces

- **API Users** : http://localhost:3000
- **Prometheus** : http://localhost:9090
- **Grafana** : http://localhost:3001 (admin/admin123)

### Générer du trafic pour tester

```powershell
powershell -ExecutionPolicy Bypass -File generate-traffic.ps1
```

---

## ✅ VALIDATION DES OBJECTIFS

| Objectif | Statut | Détails |
|----------|--------|---------|
| Endpoint /metrics | ✅ Réalisé | Ligne 113 dans app.js, expose toutes les métriques |
| Prometheus dans docker-compose | ✅ Réalisé | Service prometheus configuré avec scraping |
| Grafana dans docker-compose | ✅ Réalisé | Service grafana avec provisioning automatique |
| Configuration Prometheus scraping | ✅ Réalisé | prometheus.yml avec job users-service |
| Dashboard - Requêtes/sec | ✅ Réalisé | Panel #1 avec `rate(http_requests_total)` |
| Dashboard - Latence moyenne | ✅ Réalisé | Panel #4 avec P50/P95/P99 |
| Dashboard - Erreurs HTTP | ✅ Réalisé | Panel #3 avec `http_errors_total` |
| Dashboard - Disponibilité | ✅ Réalisé | Panel #5 avec métrique `up` |

**RÉSULTAT** : Tous les objectifs du Module 1 sont atteints ✅

---

## 🎯 MÉTRIQUES CLÉS DU DASHBOARD

### 1. Requêtes par seconde
- **Requête PromQL** : `rate(http_requests_total{job="users-service"}[1m])`
- **Visualisation** : Graphique linéaire avec légendes par route
- **Utilité** : Identifier les endpoints les plus sollicités

### 2. Latence (Percentiles)
- **Requêtes PromQL** :
  - P50 : `histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, route))`
  - P95 : `histogram_quantile(0.95, ...)`
  - P99 : `histogram_quantile(0.99, ...)`
- **Visualisation** : Graphique avec 3 courbes (P50, P95, P99)
- **Utilité** : Détecter les dégradations de performance

### 3. Erreurs HTTP
- **Requête PromQL** : `sum(rate(http_errors_total{job="users-service"}[5m]))`
- **Visualisation** : Stat avec couleur d'alerte (rouge si > 1)
- **Utilité** : Alerter sur les erreurs serveur

### 4. Disponibilité
- **Requête PromQL** : `up{job="users-service"}`
- **Visualisation** : Stat avec mapping 0=DOWN (rouge), 1=UP (vert)
- **Utilité** : Monitoring de l'état du service

---

## 📚 DOCUMENTATION SUPPLÉMENTAIRE

### Accéder aux métriques brutes

```powershell
Invoke-WebRequest -Uri "http://localhost:3000/metrics"
```

### Requêtes PromQL utiles

```promql
# Taux de requêtes total
sum(rate(http_requests_total[1m]))

# Latence moyenne par route
avg(rate(http_request_duration_seconds_sum[5m])) by (route) 
/ avg(rate(http_request_duration_seconds_count[5m])) by (route)

# Taux d'erreurs 4xx et 5xx
sum(rate(http_requests_total{status_code=~"4..|5.."}[5m]))

# Disponibilité (uptime)
avg_over_time(up{job="users-service"}[24h])
```

### Logs des services

```powershell
# Logs du microservice
docker-compose logs -f users-service

# Logs de Prometheus
docker-compose logs -f prometheus

# Logs de Grafana
docker-compose logs -f grafana
```

---

## 🔒 SÉCURITÉ

- ⚠️ Credentials Grafana par défaut (admin/admin123) - À changer en production
- ⚠️ PostgreSQL credentials en clair dans docker-compose - Utiliser Docker secrets en prod
- ✅ Réseau isolé (bridge) pour communication inter-conteneurs
- ✅ Exposition limitée aux ports nécessaires uniquement

---

## 📦 PROCHAINES ÉTAPES (Modules suivants)

Module 2 et au-delà :
- [ ] Concevoir et déployer plusieurs microservices
- [ ] Mettre en place un API Gateway NGINX
- [ ] Scaler horizontalement (scale=3)
- [ ] Intégrer un cache Redis
- [ ] Renforcer la sécurité (authentification API)
- [ ] Enrichir la base de données (rôles, catégories, commandes)
- [ ] Optimiser les requêtes SQL (indexation, EXPLAIN)
- [ ] Automatiser avec Terraform

---

## ✨ CONCLUSION

Le Module 1 a été complété avec succès. L'infrastructure de monitoring est maintenant opérationnelle avec :

- ✅ Un microservice exposant des métriques Prometheus
- ✅ Une collecte automatique des métriques toutes les 10 secondes
- ✅ Un dashboard Grafana complet avec 9 visualisations
- ✅ Une stack complètement dockerisée et orchestrée
- ✅ Un provisioning automatique (datasource + dashboard)
- ✅ Des tests validant le bon fonctionnement

**L'observabilité de l'architecture Cloud-native est maintenant assurée** 🚀

---

**Date de réalisation** : 4-5 décembre 2025  
**Technologies utilisées** : Node.js, Express, PostgreSQL, Docker, Prometheus, Grafana, prom-client  
**Status** : ✅ COMPLET
