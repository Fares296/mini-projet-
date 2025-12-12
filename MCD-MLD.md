# MODÈLE CONCEPTUEL DE DONNÉES (MCD)
# Architecture Cloud-Native - Mini-Projet

## Vue d'ensemble du modèle

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MODÈLE CONCEPTUEL DE DONNÉES                     │
│                         (Normalisé 3NF)                             │
└─────────────────────────────────────────────────────────────────────┘

ENTITÉS PRINCIPALES :
- ROLES : Rôles des utilisateurs (admin, user, guest)
- USERS : Utilisateurs du système
- CATEGORIES : Catégories de produits
- PRODUCTS : Produits disponibles
- ORDERS : Commandes passées
- ORDER_ITEMS : Lignes de commande (association ORDERS ↔ PRODUCTS)


┌──────────────┐                ┌──────────────┐
│    ROLES     │                │  CATEGORIES  │
├──────────────┤                ├──────────────┤
│ PK id        │                │ PK id        │
│    name      │                │    name      │
│    level     │                │    slug      │
└──────┬───────┘                │    parent_id │─┐
       │                        └──────┬───────┘ │
       │ 1                             │         │
       │                               │ 1       │ (auto-référence)
       │ N                             │ N       │
       │                               │         │
┌──────┴───────┐                ┌──────┴───────┐─┘
│    USERS     │                │   PRODUCTS   │
├──────────────┤                ├──────────────┤
│ PK id        │                │ PK id        │
│ FK role_id   │                │ FK category_id│
│    name      │                │    name      │
│    email     │                │    description│
│    created_at│                │    price     │
└──────┬───────┘                │    stock     │
       │                        │    created_at│
       │ 1                      │    updated_at│
       │                        └──────┬───────┘
       │ N                             │
       │                               │ N
       │                               │
┌──────┴───────┐                       │
│    ORDERS    │                       │
├──────────────┤                       │
│ PK id        │                       │
│ FK user_id   │                       │
│    total     │                       │
│    status    │                       │
│    created_at│                       │
└──────┬───────┘                       │
       │ 1                             │
       │                               │
       │ N                             │ 1
       │                               │
┌──────┴───────┐                ┌──────┴───────┐
│ ORDER_ITEMS  │ N ─────────── 1│   PRODUCTS   │
├──────────────┤                └──────────────┘
│ PK id        │
│ FK order_id  │
│ FK product_id│
│    quantity  │
│    unit_price│
│    subtotal  │
└──────────────┘


CARDINALITÉS :

ROLES (1,1) ───────── (0,N) USERS
  Un rôle peut être assigné à plusieurs utilisateurs
  Un utilisateur a exactement un rôle

USERS (1,1) ───────── (0,N) ORDERS
  Un utilisateur peut passer plusieurs commandes
  Une commande appartient à un seul utilisateur

CATEGORIES (0,1) ──── (0,N) CATEGORIES (hiérarchie)
  Une catégorie peut avoir une catégorie parente
  Une catégorie peut avoir plusieurs sous-catégories

CATEGORIES (1,1) ──── (0,N) PRODUCTS
  Une catégorie peut contenir plusieurs produits
  Un produit appartient à une seule catégorie

ORDERS (1,1) ─────── (0,N) ORDER_ITEMS
  Une commande contient plusieurs lignes
  Une ligne appartient à une seule commande

PRODUCTS (1,1) ───── (0,N) ORDER_ITEMS
  Un produit peut être dans plusieurs lignes de commande
  Une ligne de commande référence un seul produit


RÈGLES DE GESTION :

1. Un utilisateur DOIT avoir un rôle
2. Un produit DOIT avoir une catégorie
3. Une commande DOIT avoir au moins 1 ligne (ORDER_ITEMS)
4. Le total d'une commande = SUM(ORDER_ITEMS.subtotal)
5. Le subtotal d'une ligne = quantity * unit_price
6. Le stock d'un produit est décrémenté lors d'une commande
7. Les catégories peuvent être organisées hiérarchiquement
8. Une commande a un statut : pending, confirmed, shipped, delivered, cancelled
```

## Normalisation 3NF - Explication

### 1ère Forme Normale (1NF) ✅
- ✅ Toutes les colonnes contiennent des valeurs atomiques
- ✅ Pas de groupes répétitifs
- ✅ Chaque table a une clé primaire

### 2ème Forme Normale (2NF) ✅
- ✅ Respecte 1NF
- ✅ Toutes les colonnes non-clés dépendent de la TOTALITÉ de la clé primaire
- ✅ Élimination des dépendances partielles

Exemple : ORDER_ITEMS stocke unit_price au moment de l'achat
  → Évite la dépendance partielle sur PRODUCTS.price qui peut changer

### 3ème Forme Normale (3NF) ✅
- ✅ Respecte 2NF
- ✅ Aucune dépendance transitive
- ✅ Toutes les colonnes non-clés dépendent UNIQUEMENT de la clé primaire

Exemple : USERS.role_name serait une dépendance transitive
  → Séparé dans la table ROLES (USERS.role_id → ROLES.name)

Exemple : ORDERS.total est calculé mais pas stocké directement
  → Évite la redondance (peut être recalculé depuis ORDER_ITEMS)

## Contraintes d'intégrité

### Intégrité référentielle (Foreign Keys)
```sql
USERS.role_id → ROLES.id
PRODUCTS.category_id → CATEGORIES.id
CATEGORIES.parent_id → CATEGORIES.id
ORDERS.user_id → USERS.id
ORDER_ITEMS.order_id → ORDERS.id
ORDER_ITEMS.product_id → PRODUCTS.id
```

### Contraintes de domaine
```sql
PRODUCTS.price >= 0
PRODUCTS.stock >= 0
ORDER_ITEMS.quantity > 0
ORDER_ITEMS.unit_price >= 0
ORDERS.total >= 0
ROLES.level IN (1, 2, 3, ...)
ORDERS.status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')
```

### Contraintes métier
```sql
-- Un email doit être unique
UNIQUE(USERS.email)

-- Un nom de rôle doit être unique
UNIQUE(ROLES.name)

-- Un slug de catégorie doit être unique
UNIQUE(CATEGORIES.slug)

-- Une commande ne peut pas être modifiée si status = 'delivered'
-- (trigger ou logique applicative)
```

## MODÈLE LOGIQUE DE DONNÉES (MLD)

### Schéma relationnel complet

```
ROLES (id, name, level, description, created_at)
  PK: id
  UNIQUE: name

USERS (id, role_id, name, email, created_at)
  PK: id
  FK: role_id → ROLES(id)
  UNIQUE: email
  INDEX: role_id

CATEGORIES (id, name, slug, description, parent_id, created_at, updated_at)
  PK: id
  FK: parent_id → CATEGORIES(id) [NULLABLE]
  UNIQUE: slug
  INDEX: parent_id

PRODUCTS (id, category_id, name, description, price, stock, created_at, updated_at)
  PK: id
  FK: category_id → CATEGORIES(id)
  INDEX: category_id, price, name
  CHECK: price >= 0, stock >= 0

ORDERS (id, user_id, total, status, created_at, updated_at)
  PK: id
  FK: user_id → USERS(id)
  INDEX: user_id, status, created_at
  CHECK: total >= 0
  CHECK: status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')

ORDER_ITEMS (id, order_id, product_id, quantity, unit_price, subtotal, created_at)
  PK: id
  FK: order_id → ORDERS(id) ON DELETE CASCADE
  FK: product_id → PRODUCTS(id)
  INDEX: order_id, product_id
  CHECK: quantity > 0, unit_price >= 0, subtotal >= 0
```

### Détail des tables

#### TABLE: ROLES
```
┌──────────────┬──────────────┬──────────┬─────────────┐
│ Column       │ Type         │ Nullable │ Default     │
├──────────────┼──────────────┼──────────┼─────────────┤
│ id           │ SERIAL       │ NOT NULL │ AUTO        │
│ name         │ VARCHAR(50)  │ NOT NULL │             │
│ level        │ INTEGER      │ NOT NULL │ 1           │
│ description  │ TEXT         │ NULL     │             │
│ created_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
└──────────────┴──────────────┴──────────┴─────────────┘
Clé primaire: id
Contraintes: UNIQUE(name)
```

#### TABLE: USERS
```
┌──────────────┬──────────────┬──────────┬─────────────┐
│ Column       │ Type         │ Nullable │ Default     │
├──────────────┼──────────────┼──────────┼─────────────┤
│ id           │ SERIAL       │ NOT NULL │ AUTO        │
│ role_id      │ INTEGER      │ NOT NULL │ 2 (user)    │
│ name         │ VARCHAR(100) │ NOT NULL │             │
│ email        │ VARCHAR(255) │ NOT NULL │             │
│ created_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
└──────────────┴──────────────┴──────────┴─────────────┘
Clé primaire: id
Clés étrangères: role_id → ROLES(id)
Contraintes: UNIQUE(email)
Index: idx_users_role_id(role_id)
```

#### TABLE: CATEGORIES
```
┌──────────────┬──────────────┬──────────┬─────────────┐
│ Column       │ Type         │ Nullable │ Default     │
├──────────────┼──────────────┼──────────┼─────────────┤
│ id           │ SERIAL       │ NOT NULL │ AUTO        │
│ name         │ VARCHAR(100) │ NOT NULL │             │
│ slug         │ VARCHAR(100) │ NOT NULL │             │
│ description  │ TEXT         │ NULL     │             │
│ parent_id    │ INTEGER      │ NULL     │             │
│ created_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
│ updated_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
└──────────────┴──────────────┴──────────┴─────────────┘
Clé primaire: id
Clés étrangères: parent_id → CATEGORIES(id) [ON DELETE SET NULL]
Contraintes: UNIQUE(slug)
Index: idx_categories_parent_id(parent_id)
Trigger: update_updated_at_column
```

#### TABLE: PRODUCTS
```
┌──────────────┬──────────────┬──────────┬─────────────┐
│ Column       │ Type         │ Nullable │ Default     │
├──────────────┼──────────────┼──────────┼─────────────┤
│ id           │ SERIAL       │ NOT NULL │ AUTO        │
│ category_id  │ INTEGER      │ NOT NULL │             │
│ name         │ VARCHAR(200) │ NOT NULL │             │
│ description  │ TEXT         │ NULL     │             │
│ price        │ DECIMAL(10,2)│ NOT NULL │             │
│ stock        │ INTEGER      │ NOT NULL │ 0           │
│ created_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
│ updated_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
└──────────────┴──────────────┴──────────┴─────────────┘
Clé primaire: id
Clés étrangères: category_id → CATEGORIES(id)
Contraintes: CHECK(price >= 0), CHECK(stock >= 0)
Index: idx_products_category_id(category_id), idx_products_price(price), idx_products_name(name)
Trigger: update_updated_at_column
```

#### TABLE: ORDERS
```
┌──────────────┬──────────────┬──────────┬─────────────┐
│ Column       │ Type         │ Nullable │ Default     │
├──────────────┼──────────────┼──────────┼─────────────┤
│ id           │ SERIAL       │ NOT NULL │ AUTO        │
│ user_id      │ INTEGER      │ NOT NULL │             │
│ total        │ DECIMAL(10,2)│ NOT NULL │ 0           │
│ status       │ VARCHAR(20)  │ NOT NULL │ 'pending'   │
│ created_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
│ updated_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
└──────────────┴──────────────┴──────────┴─────────────┘
Clé primaire: id
Clés étrangères: user_id → USERS(id)
Contraintes: CHECK(total >= 0), CHECK(status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled'))
Index: idx_orders_user_id(user_id), idx_orders_status(status), idx_orders_created_at(created_at)
Trigger: update_updated_at_column
```

#### TABLE: ORDER_ITEMS
```
┌──────────────┬──────────────┬──────────┬─────────────┐
│ Column       │ Type         │ Nullable │ Default     │
├──────────────┼──────────────┼──────────┼─────────────┤
│ id           │ SERIAL       │ NOT NULL │ AUTO        │
│ order_id     │ INTEGER      │ NOT NULL │             │
│ product_id   │ INTEGER      │ NOT NULL │             │
│ quantity     │ INTEGER      │ NOT NULL │             │
│ unit_price   │ DECIMAL(10,2)│ NOT NULL │             │
│ subtotal     │ DECIMAL(10,2)│ NOT NULL │             │
│ created_at   │ TIMESTAMP    │ NOT NULL │ NOW()       │
└──────────────┴──────────────┴──────────┴─────────────┘
Clé primaire: id
Clés étrangères: 
  - order_id → ORDERS(id) ON DELETE CASCADE
  - product_id → PRODUCTS(id)
Contraintes: CHECK(quantity > 0), CHECK(unit_price >= 0), CHECK(subtotal >= 0)
Index: idx_order_items_order_id(order_id), idx_order_items_product_id(product_id)
```

### Diagramme des dépendances fonctionnelles

```
USERS:
  id → (role_id, name, email, created_at)
  email → (id, role_id, name, created_at)

ROLES:
  id → (name, level, description, created_at)
  name → (id, level, description, created_at)

CATEGORIES:
  id → (name, slug, description, parent_id, created_at, updated_at)
  slug → (id, name, description, parent_id, created_at, updated_at)

PRODUCTS:
  id → (category_id, name, description, price, stock, created_at, updated_at)

ORDERS:
  id → (user_id, total, status, created_at, updated_at)

ORDER_ITEMS:
  id → (order_id, product_id, quantity, unit_price, subtotal, created_at)
  (order_id, product_id) → (id, quantity, unit_price, subtotal, created_at)
```

### Justification 3NF

**1NF** : ✅ Valeurs atomiques uniquement, pas de groupes répétitifs

**2NF** : ✅ Pas de dépendances partielles
- ORDER_ITEMS stocke unit_price au lieu de référencer PRODUCTS.price
- Cela capture le prix AU MOMENT de l'achat (historique)

**3NF** : ✅ Pas de dépendances transitives
- USERS ne stocke pas role_name, seulement role_id
- PRODUCTS ne stocke pas category_name, seulement category_id
- ORDERS.total est calculé dynamiquement (optionnel pour performance)

