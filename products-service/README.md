# 🛒 Products Service - Microservice Cloud-Native

Microservice REST API pour la gestion des produits dans une architecture Cloud-native.

## 📋 Description

Ce microservice gère les opérations CRUD (Create, Read, Update, Delete) sur les produits. Il fait partie d'une architecture multi-microservices avec observabilité complète via Prometheus et Grafana.

## 🎯 Fonctionnalités

- ✅ Création de produits
- ✅ Lecture de produits (avec filtres)
- ✅ Mise à jour de produits (complète ou partielle)
- ✅ Suppression de produits
- ✅ Filtrage par catégorie, prix, stock
- ✅ Métriques Prometheus
- ✅ Health check
- ✅ Validation des données

## 🔌 API Endpoints

### Information & Santé

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/` | Information sur l'API |
| GET | `/health` | Health check + statut DB |
| GET | `/metrics` | Métriques Prometheus |

### Produits

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/products` | Lister tous les produits |
| GET | `/products?category=X` | Filtrer par catégorie |
| GET | `/products?minPrice=X&maxPrice=Y` | Filtrer par prix |
| GET | `/products?inStock=true` | Produits en stock uniquement |
| GET | `/products/:id` | Consulter un produit par ID |
| GET | `/products/category/:category` | Lister par catégorie |
| POST | `/products` | Créer un nouveau produit |
| PUT | `/products/:id` | Mettre à jour un produit |
| DELETE | `/products/:id` | Supprimer un produit |

## 📊 Schéma de Données

### Table `products`

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

**Index créés :**
- `idx_products_category` sur `category`
- `idx_products_price` sur `price`
- `idx_products_name` sur `name`

**Trigger :** Mise à jour automatique de `updated_at`

## 🚀 Démarrage

### Avec Docker Compose (recommandé)

```bash
# Depuis la racine du projet
docker-compose up -d products-service
```

### En mode développement local

```bash
cd products-service
npm install
npm run dev
```

**Variables d'environnement :**
- `PORT` : Port d'écoute (défaut: 3001)
- `DB_HOST` : Hôte PostgreSQL (défaut: localhost)
- `DB_PORT` : Port PostgreSQL (défaut: 5432)
- `DB_USER` : Utilisateur DB (défaut: clouduser)
- `DB_PASSWORD` : Mot de passe DB
- `DB_NAME` : Nom de la base (défaut: productsdb)

## 🧪 Tests avec Postman

### Importer la collection

1. Ouvrir Postman
2. Import → Upload Files
3. Sélectionner `Products-Service.postman_collection.json`

### Catégories de tests

La collection contient **20+ tests** organisés en :

1. **Health & Info** (3 tests)
   - API Info
   - Health Check
   - Prometheus Metrics

2. **Products - GET** (6 tests)
   - Lister tous les produits
   - Filtrer par catégorie
   - Filtrer par prix
   - Produits en stock
   - Produit par ID
   - Produits par catégorie (route dédiée)

3. **Products - POST** (4 tests)
   - Créer un produit complet
   - Créer un produit minimal
   - Validation : sans prix
   - Validation : prix négatif

4. **Products - PUT** (4 tests)
   - Mise à jour complète
   - MAJ prix uniquement
   - MAJ stock uniquement
   - Produit inexistant

5. **Products - DELETE** (2 tests)
   - Supprimer un produit
   - Produit inexistant

6. **Error Cases** (1 test)
   - Route non trouvée

## 📝 Exemples de Requêtes

### Créer un produit

```bash
POST http://localhost:3002/products
Content-Type: application/json

{
  "name": "Nintendo Switch OLED",
  "description": "Console de jeu portable",
  "price": 349.99,
  "stock": 25,
  "category": "Gaming"
}
```

### Lister les produits avec filtres

```bash
# Par catégorie
GET http://localhost:3002/products?category=Informatique

# Par plage de prix
GET http://localhost:3002/products?minPrice=100&maxPrice=500

# En stock uniquement
GET http://localhost:3002/products?inStock=true

# Combinaison de filtres
GET http://localhost:3002/products?category=Audio&minPrice=200&inStock=true
```

### Mettre à jour un produit

```bash
PUT http://localhost:3002/products/1
Content-Type: application/json

{
  "price": 1199.99,
  "stock": 15
}
```

### Supprimer un produit

```bash
DELETE http://localhost:3002/products/10
```

## 📊 Métriques Prometheus

Le service expose les métriques suivantes :

### Métriques personnalisées

- `http_requests_total` : Total des requêtes HTTP
- `http_request_duration_seconds` : Durée des requêtes (histogramme)
- `http_errors_total` : Total des erreurs HTTP
- `db_connections_active` : Connexions DB actives
- `product_operations_total` : Opérations CRUD
- `products_total_stock` : Stock total de tous les produits
- `products_count` : Nombre total de produits

### Métriques système

- CPU (`process_cpu_seconds_total`)
- Mémoire (`nodejs_heap_size_*`)
- Garbage Collection (`nodejs_gc_duration_seconds`)

## 🗂️ Structure du Service

```
products-service/
├── app.js                              # Application principale
├── package.json                        # Dépendances Node.js
├── Dockerfile                          # Image Docker
├── .dockerignore                       # Exclusions build Docker
├── init-products.sql                   # Script init PostgreSQL
├── Products-Service.postman_collection.json  # Tests Postman
└── README.md                           # Cette documentation
```

## 🔧 Technologies

- **Runtime** : Node.js 18
- **Framework** : Express.js
- **Base de données** : PostgreSQL 15
- **Métriques** : prom-client
- **Conteneurisation** : Docker

## 🔒 Validation des Données

### Champs requis

- `name` : Obligatoire
- `price` : Obligatoire, >= 0

### Champs optionnels

- `description` : Texte libre
- `stock` : Entier >= 0 (défaut: 0)
- `category` : Chaîne de caractères

### Contraintes

- Prix ne peut pas être négatif
- Stock ne peut pas être négatif
- Les timestamps sont gérés automatiquement

## 📈 Monitoring

### Vérifier la santé du service

```bash
curl http://localhost:3002/health
```

**Réponse attendue :**
```json
{
  "status": "healthy",
  "database": "connected"
}
```

### Consulter les métriques

```bash
curl http://localhost:3002/metrics
```

## 🐳 Docker

### Build de l'image

```bash
docker build -t products-service .
```

### Exécution standalone

```bash
docker run -p 3002:3001 \
  -e DB_HOST=postgres-products \
  -e DB_NAME=productsdb \
  -e DB_USER=clouduser \
  -e DB_PASSWORD=cloudpass123 \
  products-service
```

## 🔗 Intégration

Ce microservice s'intègre dans l'architecture complète :

- **Port** : 3002 (hôte) → 3001 (conteneur)
- **Base de données** : postgres-products (port 5433)
- **Réseau** : cloud-network
- **Monitoring** : Prometheus scrape toutes les 10s

## 🎓 Prochaines Étapes

- [ ] Module 3 : API Gateway NGINX
- [ ] Module 4 : Scaling horizontal
- [ ] Module 5 : Cache Redis
- [ ] Module 6 : Sécurité API

## 📄 Licence

MIT
