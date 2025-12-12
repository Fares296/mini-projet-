# 🚀 Mini-Projet Cloud - Architecture Microservices Cloud-Native

## 📋 Description

Ce projet implémente une **architecture microservices Cloud-native complète** avec observabilité, API Gateway, et gestion de données distribuées. Il couvre les concepts essentiels du développement Cloud moderne.

### Modules complétés

- ✅ **Module 1** : Observabilité (Prometheus & Grafana)
- ✅ **Module 2** : Second Microservice (Products)  
- ✅ **Module 3** : API Gateway (NGINX)

---

## 🏗️ Architecture Complète

```
                     Client
                        ↓
             http://localhost:8080
                        ↓
            ┌─────────────────────┐
            │   NGINX Gateway     │
            │   (API Gateway)     │
            └──────────┬──────────┘
                       │
       ┌───────────────┼───────────────┐
       ▼               ▼               ▼
┌──────────┐    ┌────────────┐    ┌──────────┐
│ Users    │    │ Products   │    │Prometheus│
│ Service  │    │ Service    │    │          │
└────┬─────┘    └─────┬──────┘    └────┬─────┘
     │                │                  │
     ▼                ▼                  │
┌─────────┐    ┌──────────────┐        │
│Users DB │    │Products DB   │        │
│:5432    │    │:5433         │        │
└─────────┘    └──────────────┘        │
                                        ▼
                                  ┌──────────┐
                                  │ Grafana  │
                                  │Dashboard │
                                  └──────────┘
```

---

## 📦 Services Déployés (7 conteneurs)

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| **API Gateway** | api-gateway | 8080 | Point d'entrée unique NGINX |
| **Users Service** | users-service | 3000 | Microservice gestion utilisateurs |
| **Products Service** | products-service | 3002 | Microservice gestion produits |
| **Users DB** | users-postgres | 5432 | PostgreSQL pour users |
| **Products DB** | products-postgres | 5433 | PostgreSQL pour products |
| **Prometheus** | prometheus | 9090 | Collecte de métriques |
| **Grafana** | grafana | 3001 | Visualisation et dashboards |

---

## 🚀 Démarrage Rapide

### Prérequis
- Docker Desktop installé et démarré
- Docker Compose v3.8+
- PowerShell (pour scripts de test)

### 1. Lancer l'infrastructure complète

```powershell
# Construire et démarrer tous les services
docker-compose up -d --build

# Vérifier que tous les services sont actifs
docker-compose ps
```

**Résultat attendu** :
```
7/7 services UP
api-gateway         Up  (healthy)
users-service       Up
products-service    Up
users-postgres      Up  (healthy)
products-postgres   Up  (healthy)
prometheus          Up
grafana             Up
```

### 2. Accéder aux services

#### Via API Gateway (recommandé)

- **Gateway Info** : http://localhost:8080/
- **Users API** : http://localhost:8080/users
- **Products API** : http://localhost:8080/products
- **Prometheus** : http://localhost:8080/prometheus/

#### Accès direct (développement)

- **Users Service** : http://localhost:3000
- **Products Service** : http://localhost:3002
- **Prometheus** : http://localhost:9090
- **Grafana** : http://localhost:3001
  - 👤 Username: `admin`
  - 🔑 Password: `admin123`

---

## 🛒 API Endpoints

### Via API Gateway (Port 8080)

#### Gateway

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/` | Info gateway + liste services |
| GET | `/health` | Health check du gateway |

#### Users Service

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/users` | Lister tous les utilisateurs |
| GET | `/users/:id` | Consulter un utilisateur |
| POST | `/users` | Créer un utilisateur |
| DELETE | `/users/:id` | Supprimer un utilisateur |
| GET | `/users/health` | Health check |
| GET | `/users/metrics` | Métriques Prometheus |

#### Products Service

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/products` | Lister tous les produits |
| GET | `/products/:id` | Consulter un produit |
| GET | `/products?category=X` | Filtrer par catégorie |
| GET | `/products?minPrice=X&maxPrice=Y` | Filtrer par prix |
| GET | `/products?inStock=true` | Produits en stock |
| GET | `/products/category/:cat` | Par catégorie (route) |
| POST | `/products` | Créer un produit |
| PUT | `/products/:id` | Mettre à jour un produit |
| DELETE | `/products/:id` | Supprimer un produit |
| GET | `/products/health` | Health check |
| GET | `/products/metrics` | Métriques Prometheus |

---

## 🧪 Tests

### 1. Tests automatisés Gateway

```powershell
# Tous les services via le Gateway
powershell -ExecutionPolicy Bypass -File test-gateway.ps1
```

**Résultat attendu** : 17+ tests réussis sur 21

### 2. Tests manuels via Gateway

```powershell
# Lister users
Invoke-RestMethod http://localhost:8080/users

# Créer un user
$user = @{name="Test User"; email="test@example.com"} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/users -Method POST -Body $user -ContentType "application/json"

# Lister products
Invoke-RestMethod http://localhost:8080/products

# Filtrer products
Invoke-RestMethod "http://localhost:8080/products?category=Gaming"

# Créer un product
$product = @{name="Test Product"; price=99.99; stock=10} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8080/products -Method POST -Body $product -ContentType "application/json"
```

### 3. Tests avec Postman

1. Importer `products-service/Products-Service.postman_collection.json`
2. Modifier l'URL de base vers `http://localhost:8080`
3. Exécuter la collection

---

## 📊 Monitoring & Observabilité

### Grafana Dashboard

1. Accès : http://localhost:3001
2. Login : `admin` / `admin123`
3. Dashboard : "Users Service - Monitoring Cloud Native"

**Métriques disponibles** :
- ✅ Requêtes par seconde (tous services)
- ✅ Latence P50/P95/P99
- ✅ Erreurs HTTP
- ✅ Disponibilité des services
- ✅ Connexions DB actives
- ✅ Opérations par type (users, products)
- ✅ Stock total produits

### Prometheus

1. Accès : http://localhost:9090
2. Targets : http://localhost:9090/targets

**Vérifier que tous les jobs sont UP** :
- ✅ users-service
- ✅ products-service
- ✅ prometheus

**Requêtes PromQL utiles** :
```promql
# Requêtes totales
sum(rate(http_requests_total[1m]))

# Par service
sum(rate(http_requests_total{service="users-service"}[1m]))
sum(rate(http_requests_total{service="products-service"}[1m]))

# Latence
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Taux d'erreurs
rate(http_errors_total[1m])

# Stock produits
products_total_stock
```

---

## 📝 Exemples d'Utilisation

### Créer un utilisateur via Gateway

```powershell
$newUser = @{
    name = "Alice Dupont"
    email = "alice.dupont@company.com"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/users" `
                  -Method POST `
                  -Body $newUser `
                  -ContentType "application/json"
```

### Créer un produit via Gateway

```powershell
$newProduct = @{
    name = "iPhone 16 Pro"
    description = "Dernier smartphone Apple"
    price = 1299.99
    stock = 50
    category = "Téléphonie"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8080/products" `
                  -Method POST `
                  -Body $newProduct `
                  -ContentType "application/json"
```

### Filtrer produits par prix

```powershell
Invoke-RestMethod "http://localhost:8080/products?minPrice=500&maxPrice=1500"
```

---

## 🗺️ Modules - Progression

### ✅ Module 1 : Observabilité (Prometheus & Grafana)

**Objectifs** :
- [x] Endpoint `/metrics` dans users-service
- [x] Prometheus configuré et scraping
- [x] Grafana avec dashboards
- [x] Métriques : requêtes/sec, latence, erreurs, disponibilité

📄 **Documentation** : `MODULE1-LIVRABLES.md`

### ✅ Module 2 : Second Microservice (Products)

**Objectifs** :
- [x] Table SQL products avec index
- [x] Microservice products (CRUD complet)
- [x] Routes GET, POST, PUT, DELETE
- [x] Filtres avancés (catégorie, prix, stock)
- [x] Dockerfile et conteneurisation
- [x] Tests Postman (20+ tests)

📄 **Documentation** : `MODULE2-LIVRABLES.md`

### ✅ Module 3 : API Gateway (NGINX)

**Objectifs** :
- [x] Déploiement conteneur NGINX
- [x] Configuration gateway.conf
- [x] Routage vers microservices
- [x] Exposition sur port 8080
- [x] Tests via gateway uniquement
- [x] CORS, headers, load balancing

📄 **Documentation** : `MODULE3-LIVRABLES.md`

### 🔜 Modules Suivants

- [ ] **Module 4** : Scaling Horizontal (scale=3)
- [ ] **Module 5** : Cache Redis
- [ ] **Module 6** : Sécurité API (JWT, API Keys)
- [ ] **Module 7** : Enrichissement DB (roles, orders)
- [ ] **Module 8** : Optimisation SQL (indexation, EXPLAIN)
- [ ] **Module 9** : Terraform (optionnel)

---

## 🛠️ Commandes Utiles

### Gestion des services

```powershell
# Démarrer tout
docker-compose up -d

# Démarrer un service spécifique
docker-compose up -d api-gateway

# Arrêter tout
docker-compose down

# Arrêter et supprimer volumes
docker-compose down -v

# Voir les logs
docker-compose logs -f
docker-compose logs -f api-gateway
docker-compose logs -f users-service

# Redémarrer un service
docker-compose restart users-service

# Reconstruire
docker-compose up -d --build
```

### Vérifications

```powershell
# État des services
docker-compose ps

# Consommation ressources
docker stats

# Logs en direct
docker-compose logs -f --tail=100

# Entrer dans un conteneur
docker exec -it api-gateway sh
docker exec -it users-postgres psql -U clouduser -d usersdb
```

### Tests rapides

```powershell
# Gateway health
Invoke-RestMethod http://localhost:8080/health

# Users health (direct)
Invoke-RestMethod http://localhost:3000/health

# Products health (direct)
Invoke-RestMethod http://localhost:3002/health

# Prometheus targets
Start-Process http://localhost:9090/targets

# Grafana
Start-Process http://localhost:3001
```

---

## 📂 Structure du Projet

```
mini-projet-/
├── 📁 nginx/                           # Configuration API Gateway
│   ├── nginx.conf                      # Config globale NGINX
│   └── gateway.conf                    # Routage et upstreams
├── 📁 products-service/                # Microservice Products
│   ├── app.js                          # Application Node.js
│   ├── package.json
│   ├── Dockerfile
│   ├── init-products.sql               # Schéma PostgreSQL
│   ├── Products-Service.postman_collection.json
│   └── README.md
├── 📁 grafana/                         # Configuration Grafana
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── prometheus.yml
│   │   └── dashboards/
│   │       └── dashboards.yml
│   └── dashboards/
│       └── users-service-dashboard.json
├── app.js                              # Microservice Users
├── package.json
├── Dockerfile                          # Users service Dockerfile
├── init.sql                            # Schéma PostgreSQL Users
├── docker-compose.yml                  # Orchestration complète
├── prometheus.yml                      # Config Prometheus
├── test-gateway.ps1                    # Tests automatisés
├── generate-traffic.ps1                # Génération trafic
├── README.md                           # Ce fichier
├── MODULE1-LIVRABLES.md                # Livrables Module 1
├── MODULE2-LIVRABLES.md                # Livrables Module 2
├── MODULE3-LIVRABLES.md                # Livrables Module 3
├── MODULE3-QUICK-GUIDE.md              # Guide rapide Module 3
└── QUICK-START.md                      # Guide démarrage rapide
```

---

## 🔒 Sécurité

**Configuration actuelle (développement)** :
- ⚠️ Credentials en clair dans docker-compose
- ⚠️ Pas d'authentification sur les APIs
- ⚠️ CORS ouvert (`*`)
- ⚠️ Pas de rate limiting activé

**Pour la production** :
- ✅ Utiliser Docker Secrets
- ✅ Ajouter JWT/API Keys
- ✅ Configurer CORS spécifique
- ✅ Activer rate limiting NGINX
- ✅ HTTPS/TLS avec certificats
- ✅ Network policies

---

## 📚 Technologies Utilisées

| Catégorie | Technologies |
|-----------|--------------|
| **Backend** | Node.js 18, Express.js |
| **Bases de données** | PostgreSQL 15 |
| **API Gateway** | NGINX Alpine |
| **Monitoring** | Prometheus, Grafana |
| **Conteneurisation** | Docker, Docker Compose |
| **Métriques** | prom-client |
| **Tests** | Postman, PowerShell |

---

## 🐛 Dépannage

### Services ne démarrent pas

```powershell
# Voir les logs
docker-compose logs

# Vérifier les ports occupés
netstat -ano | findstr "8080"
netstat -ano | findstr "3000"

# Reconstruire tout
docker-compose down -v
docker-compose up -d --build
```

### Gateway retourne 502

```powershell
# Vérifier que les backends sont UP
docker-compose ps users-service products-service

# Redémarrer les services
docker-compose restart users-service products-service api-gateway
```

### Prometheus ne collecte pas

```powershell
# Vérifier les endpoints metrics
Invoke-WebRequest http://localhost:3000/metrics
Invoke-WebRequest http://localhost:3002/metrics

# Vérifier la config
docker exec prometheus cat /etc/prometheus/prometheus.yml

# Voir les targets
Start-Process http://localhost:9090/targets
```

### Grafana n'affiche pas de données

1. Vérifier datasource : Configuration → Data Sources
2. Tester requête PromQL : `up{job="users-service"}`
3. Vérifier que Prometheus scrape les services

---

## 📈 Statistiques du Projet

- **7 services** orchestrés
- **2 microservices** REST API
- **2 bases de données** PostgreSQL
- **16+ endpoints** API
- **20+ tests** Postman automatisés
- **9 panels** Grafana dashboard
- **15+ métriques** Prometheus
- **1 API Gateway** NGINX

---

## 👨‍💻 Auteur

Projet réalisé dans le cadre du module :  
**"Technologies de développement et SGBD pour les applications Cloud"**

---

## 🎓 Apprentissages Clés

✅ Architecture microservices  
✅ Containerisation avec Docker  
✅ Orchestration Docker Compose  
✅ API Gateway pattern  
✅ Observabilité (métriques, logs)  
✅ Bases de données distribuées  
✅ NGINX reverse proxy  
✅ REST API design  
✅ Health checks & monitoring  
✅ Load balancing  

---

**🚀 Architecture Cloud-Native Complète et Opérationnelle !**
