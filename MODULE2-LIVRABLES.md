# MODULE 2 - LIVRABLES
## Second Microservice : Products

---

## ✅ RÉSUMÉ DES TRAVAUX RÉALISÉS

### Vue d'ensemble

Le Module 2 étend l'architecture Cloud-native avec un **second microservice** dédié à la gestion des produits. Ce microservice suit les mêmes principes que `users-service` pour assurer la cohérence architecturale.

---

## 📋 1. TABLE SQL PRODUCTS ✅

### Fichier: `products-service/init-products.sql`

#### Structure de la table

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Caractéristiques

**Colonnes :**
- `id` : Clé primaire auto-incrémentée
- `name` : Nom du produit (obligatoire, max 200 caractères)
- `description` : Description détaillée (optionnel, texte libre)
- `price` : Prix en décimal (obligatoire, >= 0)
- `stock` : Quantité en stock (défaut: 0, >= 0)
- `category` : Catégorie du produit (optionnel)
- `created_at` : Date de création (automatique)
- `updated_at` : Date de mise à jour (automatique)

**Contraintes :**
- ✅ Prix ne peut pas être négatif (`CHECK (price >= 0)`)
- ✅ Stock ne peut pas être négatif (`CHECK (stock >= 0)`)

#### Index créés (performances)

```sql
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_name ON products(name);
```

**Utilité :**
- Accélération des recherches par catégorie
- Optimisation des filtres par prix
- Amélioration des recherches par nom

#### Trigger automatique

```sql
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

**Fonction :** Met à jour automatiquement `updated_at` lors de chaque modification

#### Données de test (10 produits)

| ID | Nom | Catégorie | Prix | Stock |
|----|-----|-----------|------|-------|
| 1 | Laptop Dell XPS 15 | Informatique | 1299.99€ | 15 |
| 2 | iPhone 15 Pro | Téléphonie | 1199.00€ | 25 |
| 3 | Samsung Galaxy S24 | Téléphonie | 999.00€ | 30 |
| 4 | MacBook Pro M3 | Informatique | 2499.00€ | 10 |
| 5 | AirPods Pro | Audio | 279.00€ | 50 |
| 6 | Sony WH-1000XM5 | Audio | 399.00€ | 20 |
| 7 | iPad Air | Tablettes | 699.00€ | 18 |
| 8 | Logitech MX Master 3 | Accessoires | 99.99€ | 40 |
| 9 | Dell UltraSharp 27" | Moniteurs | 549.00€ | 12 |
| 10 | Samsung SSD 1TB | Stockage | 129.00€ | 60 |

---

## 🚀 2. DÉVELOPPEMENT DE PRODUCTS-SERVICE ✅

### Fichier: `products-service/app.js`

#### Technologies utilisées

- **Runtime** : Node.js 18 Alpine
- **Framework** : Express.js 4.18.2
- **Base de données** : PostgreSQL 15 (`pg` 8.11.3)
- **Métriques** : prom-client 15.1.0
- **CORS** : cors 2.8.5

#### Routes implémentées

##### 📊 Information & Santé

| Méthode | Route | Description | Statut |
|---------|-------|-------------|--------|
| GET | `/` | Info API + liste endpoints | ✅ |
| GET | `/health` | Health check + connexion DB | ✅ |
| GET | `/metrics` | Métriques Prometheus | ✅ |

##### 🛒 Opérations CRUD sur les Produits

| Méthode | Route | Description | Validation | Statut |
|---------|-------|-------------|------------|--------|
| **GET** | `/products` | Lister tous les produits | - | ✅ |
| **GET** | `/products?category=X` | Filtrer par catégorie | - | ✅ |
| **GET** | `/products?minPrice=X&maxPrice=Y` | Filtrer par prix | - | ✅ |
| **GET** | `/products?inStock=true` | Produits en stock uniquement | - | ✅ |
| **GET** | `/products/:id` | Consulter un produit par ID | - | ✅ |
| **GET** | `/products/category/:category` | Lister par catégorie | - | ✅ |
| **POST** | `/products` | Créer un produit | name + price requis | ✅ |
| **PUT** | `/products/:id` | Mettre à jour un produit | Validation prix/stock | ✅ |
| **DELETE** | `/products/:id` | Supprimer un produit | - | ✅ |

#### Validations implémentées

**Création (POST) :**
- ✅ `name` obligatoire
- ✅ `price` obligatoire
- ✅ `price` >= 0
- ✅ `stock` >= 0 (si fourni)

**Mise à jour (PUT) :**
- ✅ `price` >= 0 (si fourni)
- ✅ `stock` >= 0 (si fourni)
- ✅ Au moins un champ à mettre à jour
- ✅ Gestion du produit inexistant (404)

#### Métriques Prometheus exposées

**Métriques HTTP :**
- `http_requests_total` : Total requêtes par méthode/route/code
- `http_request_duration_seconds` : Latence (histogramme)
- `http_errors_total` : Total des erreurs HTTP

**Métriques métier :**
- `product_operations_total` : Opérations CRUD par type
- `products_total_stock` : Stock total (gauge)
- `products_count` : Nombre total de produits (gauge)
- `db_connections_active` : Connexions DB actives

**Métriques système :**
- CPU, mémoire, garbage collection Node.js

#### Gestion des erreurs

| Code | Cas | Réponse |
|------|-----|---------|
| 200 | Succès | `{success: true, data: ...}` |
| 201 | Création réussie | `{success: true, message: ..., data: ...}` |
| 400 | Validation échouée | `{success: false, error: "..."}` |
| 404 | Ressource non trouvée | `{success: false, error: "..."}` |
| 500 | Erreur serveur | `{success: false, error: "..."}` |

---

## 🐳 3. CONTENEURISATION (DOCKERFILE) ✅

### Fichier: `products-service/Dockerfile`

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3001
CMD ["npm", "start"]
```

#### Caractéristiques

- **Image de base** : `node:18-alpine` (légère)
- **Build multi-étapes** : Non (simple pour ce microservice)
- **Port exposé** : 3001
- **Production mode** : `npm install --production`
- **Optimisation** : `.dockerignore` pour exclure node_modules

#### Fichiers du service

```
products-service/
├── app.js                              # Application Express
├── package.json                        # Dépendances npm
├── Dockerfile                          # Image Docker
├── .dockerignore                       # Exclusions build
├── init-products.sql                   # Init PostgreSQL
├── Products-Service.postman_collection.json  # Tests
└── README.md                           # Documentation
```

---

## 🐳 4. AJOUT AU DOCKER-COMPOSE ✅

### Modifications apportées

#### Nouvelle base de données

```yaml
postgres-products:
  image: postgres:15-alpine
  container_name: products-postgres
  environment:
    POSTGRES_DB: productsdb
    POSTGRES_USER: clouduser
    POSTGRES_PASSWORD: cloudpass123
  ports:
    - "5433:5432"  # Port externe différent
  volumes:
    - postgres_products_data:/var/lib/postgresql/data
    - ./products-service/init-products.sql:/docker-entrypoint-initdb.d/init-products.sql
  networks:
    - cloud-network
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U clouduser -d productsdb"]
    interval: 10s
    timeout: 5s
    retries: 5
```

#### Nouveau microservice

```yaml
products-service:
  build: ./products-service
  container_name: products-service
  environment:
    PORT: 3001
    DB_HOST: postgres-products
    DB_PORT: 5432
    DB_USER: clouduser
    DB_PASSWORD: cloudpass123
    DB_NAME: productsdb
  ports:
    - "3002:3001"  # Hôte:Conteneur
  depends_on:
    postgres-products:
      condition: service_healthy
  networks:
    - cloud-network
  restart: unless-stopped
```

#### Nouveau volume

```yaml
volumes:
  postgres_products_data:
    driver: local
```

#### Scraping Prometheus

Ajout dans `prometheus.yml` :

```yaml
- job_name: 'products-service'
  scrape_interval: 10s
  metrics_path: '/metrics'
  static_configs:
    - targets: ['products-service:3001']
      labels:
        service: 'products-service'
        team: 'cloud'
        version: '1.0.0'
```

### Architecture complète

```
┌─────────────────┐
│   Grafana       │ Port 3001
│   Dashboard     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Prometheus    │ Port 9090
└────┬────────┬───┘
     │        │
     ▼        ▼
┌─────────┐  ┌─────────────┐
│ Users   │  │ Products    │
│ Service │  │ Service     │
│ :3000   │  │ :3002       │
└────┬────┘  └──────┬──────┘
     │              │
     ▼              ▼
┌─────────┐  ┌─────────────┐
│Users DB │  │Products DB  │
│ :5432   │  │ :5433       │
└─────────┘  └─────────────┘
```

**Total des services : 6**
1. users-postgres (PostgreSQL)
2. products-postgres (PostgreSQL)
3. users-service (Node.js)
4. products-service (Node.js)
5. prometheus (Monitoring)
6. grafana (Visualisation)

---

## 🧪 5. TESTS POSTMAN ✅

### Fichier: `products-service/Products-Service.postman_collection.json`

#### Organisation de la collection

La collection Postman contient **20+ requêtes** organisées en **6 dossiers** :

##### 1. Health & Info (3 tests)

| Test | Endpoint | Attendu |
|------|----------|---------|
| API Info | GET / | Liste des endpoints |
| Health Check | GET /health | `{status: "healthy"}` |
| Prometheus Metrics | GET /metrics | Métriques texte |

##### 2. Products - GET (6 tests)

| Test | Endpoint | Description |
|------|----------|-------------|
| Get All Products | GET /products | Liste complète |
| By Category (query) | GET /products?category=X | Filtrage |
| By Price Range | GET /products?minPrice=X&maxPrice=Y | Fourchette |
| In Stock Only | GET /products?inStock=true | Stock > 0 |
| By ID | GET /products/:id | Produit unique |
| By Category (route) | GET /products/category/:cat | Route dédiée |

##### 3. Products - POST (4 tests)

| Test | Body | Attendu | Code |
|------|------|---------|------|
| Create Complete | name, desc, price, stock, cat | Succès | 201 |
| Create Minimal | name, price | Succès | 201 |
| Invalid - No Price | name only | Erreur | 400 |
| Invalid - Negative Price | price: -50 | Erreur | 400 |

##### 4. Products - PUT (4 tests)

| Test | Body | Attendu | Code |
|------|------|---------|------|
| Update Full | All fields | Succès | 200 |
| Update Price Only | price | Succès | 200 |
| Update Stock Only | stock | Succès | 200 |
| Not Found | ID 9999 | Erreur | 404 |

##### 5. Products - DELETE (2 tests)

| Test | Endpoint | Attendu | Code |
|------|----------|---------|------|
| Delete Product | DELETE /products/10 | Succès | 200 |
| Delete Not Found | DELETE /products/9999 | Erreur | 404 |

##### 6. Error Cases (1 test)

| Test | Endpoint | Attendu | Code |
|------|----------|---------|------|
| 404 Route | GET /invalid | Erreur | 404 |

#### Importer dans Postman

1. Ouvrir Postman Desktop
2. Import → Upload Files
3. Sélectionner `products-service/Products-Service.postman_collection.json`
4. Exécuter les tests

#### Variables de collection

```json
{
  "base_url": "http://localhost:3002"
}
```

---

## ✅ TESTS DE VALIDATION

### Tests fonctionnels exécutés

#### 1. Health Check

```bash
GET http://localhost:3002/health
```

**Résultat :**
```json
{
  "status": "healthy",
  "database": "connected"
}
```
✅ **SUCCÈS**

#### 2. Lister les produits

```bash
GET http://localhost:3002/products
```

**Résultat :**
```json
{
  "success": true,
  "count": 10,
  "data": [...]
}
```
✅ **SUCCÈS** - 10 produits retournés

#### 3. Créer un produit

```bash
POST http://localhost:3002/products
Content-Type: application/json

{
  "name": "PlayStation 5",
  "description": "Console de jeu nouvelle génération",
  "price": 499.99,
  "stock": 20,
  "category": "Gaming"
}
```

**Résultat :**
```json
{
  "success": true,
  "message": "Produit créé avec succès",
  "data": {
    "id": 11,
    "name": "PlayStation 5",
    "price": "499.99",
    "stock": 20,
    ...
  }
}
```
✅ **SUCCÈS** - ID 11 créé

#### 4. Mettre à jour un produit

```bash
PUT http://localhost:3002/products/11
Content-Type: application/json

{
  "price": 549.99,
  "stock": 25
}
```

**Résultat :**
```json
{
  "success": true,
  "message": "Produit mis à jour avec succès",
  "data": {
    "id": 11,
    "price": "549.99",
    "stock": 25,
    "updated_at": "2025-12-04T23:56:45.176Z"
  }
}
```
✅ **SUCCÈS** - Prix et stock mis à jour, `updated_at` changé

#### 5. Filtrer par catégorie

```bash
GET http://localhost:3002/products?category=Gaming
```

**Résultat :**
```json
{
  "success": true,
  "count": 1,
  "data": [
    {
      "id": 11,
      "name": "PlayStation 5",
      "category": "Gaming",
      ...
    }
  ]
}
```
✅ **SUCCÈS** - Filtrage fonctionnel

#### 6. Supprimer un produit

```bash
DELETE http://localhost:3002/products/11
```

**Résultat :**
```json
{
  "success": true,
  "message": "Produit supprimé avec succès",
  "data": { "id": 11, ... }
}
```
✅ **SUCCÈS** - Produit supprimé

---

## 📊 VÉRIFICATION PROMETHEUS

### Targets Prometheus

Accéder à : http://localhost:9090/targets

**État attendu :**
```
✅ products-service (1/1 up)
   Endpoint: http://products-service:3001/metrics
   State: UP
   Last Scrape: < 10s ago
```

### Requêtes PromQL de test

```promql
# Requêtes sur products-service
sum(rate(http_requests_total{service="products-service"}[1m]))

# Opérations produits par type
sum(rate(product_operations_total[5m])) by (operation)

# Stock total
products_total_stock

# Nombre de produits
products_count
```

---

## 🎯 VALIDATION DES OBJECTIFS MODULE 2

| Objectif | Livrable | Statut | Fichier |
|----------|----------|--------|---------|
| Table SQL products | init-products.sql | ✅ | products-service/init-products.sql |
| Routes GET | app.js | ✅ | GET /products, /products/:id, etc. |
| Routes POST | app.js | ✅ | POST /products |
| Routes DELETE | app.js | ✅ | DELETE /products/:id |
| Dockerfile | Dockerfile | ✅ | products-service/Dockerfile |
| Ajout docker-compose | docker-compose.yml | ✅ | Services + DB + volumes |
| Tests Postman | Collection JSON | ✅ | 20+ tests organisés |
| Code complet | app.js + package.json | ✅ | Service fonctionnel |

**TOUS LES OBJECTIFS SONT ATTEINTS** ✅

---

## 📂 STRUCTURE DU PROJET (MISE À JOUR)

```
mini-projet-/
├── 📁 products-service/                # ← NOUVEAU
│   ├── app.js                          # Microservice Products
│   ├── package.json                    # Dépendances
│   ├── Dockerfile                      # Image Docker
│   ├── .dockerignore                   # Exclusions
│   ├── init-products.sql               # Init PostgreSQL
│   ├── Products-Service.postman_collection.json
│   └── README.md                       # Doc du service
├── 📁 grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── prometheus.yml
│   │   └── dashboards/
│   │       └── dashboards.yml
│   └── dashboards/
│       └── users-service-dashboard.json
├── app.js                              # Users service
├── package.json                        
├── Dockerfile                          # Users Dockerfile
├── docker-compose.yml                  # ← MODIFIÉ (6 services)
├── prometheus.yml                      # ← MODIFIÉ (2 jobs)
├── init.sql                            # Init Users DB
├── README.md
├── MODULE1-LIVRABLES.md
├── MODULE2-LIVRABLES.md                # ← NOUVEAU
└── QUICK-START.md
```

---

## 🚀 COMMANDES DE TEST

### Démarrer les nouveaux services

```powershell
docker-compose up -d --build products-service postgres-products
```

### Vérifier l'état

```powershell
docker-compose ps
```

**Résultat :**
```
products-postgres   Up (healthy)   :5433
products-service    Up             :3002
```

### Tester l'API

```powershell
# Health check
Invoke-RestMethod http://localhost:3002/health

# Lister les produits
Invoke-RestMethod http://localhost:3002/products

# Créer un produit
$body = @{
    name = "Test Product"
    price = 99.99
} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:3002/products -Method POST -Body $body -ContentType "application/json"
```

---

## 📈 COMPARAISON USERS vs PRODUCTS

| Aspect | Users Service | Products Service |
|--------|---------------|------------------|
| **Port** | 3000 → 3000 | 3002 → 3001 |
| **DB** | usersdb (5432) | productsdb (5433) |
| **Routes** | 4 (CRUD basique) | 9 (CRUD + filtres) |
| **Colonnes** | 4 (id, name, email, created_at) | 8 (+ description, price, stock, category, updated_at) |
| **Index** | 1 (email) | 3 (category, price, name) |
| **Triggers** | 0 | 1 (updated_at) |
| **Métriques** | 5 | 7 (+stock, +count) |
| **Filtres** | 0 | 3 (category, price, stock) |

**Améliorations apportées :**
- ✅ Plus de fonctionnalités (filtres, triggers)
- ✅ Métriques métier enrichies
- ✅ Validation renforcée
- ✅ Documentation Postman

---

## 🎓 PROCHAINES ÉTAPES (MODULE 3)

- [ ] API Gateway NGINX
- [ ] Load balancing entre services
- [ ] Reverse proxy
- [ ] Routing intelligent
- [ ] Centralisation des logs

---

## ✨ CONCLUSION

Le Module 2 a été complété avec succès. L'architecture compte maintenant **2 microservices indépendants** avec leurs bases de données dédiées, tous monitorés par Prometheus et visualisables dans Grafana.

**Points forts :**
- Architecture découplée (separation of concerns)
- Scalabilité horizontale possible
- Observabilité complète
- Tests automatisés avec Postman
- Documentation exhaustive

**Date de réalisation** : 5 décembre 2025  
**Technologies** : Node.js, Express, PostgreSQL, Docker, Prometheus  
**Status** : ✅ **COMPLET**

---

**🎉 MODULE 2 RÉUSSI !**
