-- ============================================
-- OPTIMISATION SQL - MODULE 8
-- Index, Requêtes Optimisées, Performance
-- ============================================

-- ==================== ANALYSE PRÉLIMINAIRE ====================

-- Vérifier les tables existantes et leur taille
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- ==================== INDEX PERTINENTS ====================

-- Note: Plusieurs index ont déjà été créés dans les migrations précédentes
-- Ce script ajoute les index manquants et optimise

-- ========== TABLE: USERS ==========

-- Index sur email (recherche fréquente, LOGIN)
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
COMMENT ON INDEX idx_users_email IS 'Optimise les recherches par email et authentification';

-- Index sur role_id (déjà créé, mais on vérifie)
CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);

-- Index composite pour les recherches filtrées
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);
COMMENT ON INDEX idx_users_created_at IS 'Optimise ORDER BY created_at DESC';

-- Index partiel pour les utilisateurs actifs (exemple si on ajoute une colonne active)
-- CREATE INDEX idx_users_active ON users(id) WHERE active = true;

-- ========== TABLE: ROLES ==========

-- Index sur name (déjà UNIQUE, donc index automatique)
-- Pas d'index supplémentaire nécessaire sur cette petite table

-- ========== TABLE: PRODUCTS ==========

-- Index sur category_id (déjà créé)
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);

-- Index sur price (pour filtres et tri)
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
COMMENT ON INDEX idx_products_price IS 'Optimise les filtres et tris par prix';

-- Index sur stock (pour rechercher produits disponibles)
CREATE INDEX IF NOT EXISTS idx_products_stock ON products(stock);
COMMENT ON INDEX idx_products_stock IS 'Optimise WHERE stock > 0';

-- Index FULL TEXT SEARCH sur le nom (recherche texte)
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING gin(name gin_trgm_ops);
COMMENT ON INDEX idx_products_name_trgm IS 'Optimise les recherches LIKE/ILIKE sur le nom';

-- Index composite pour requêtes courantes
CREATE INDEX IF NOT EXISTS idx_products_category_price ON products(category_id, price);
COMMENT ON INDEX idx_products_category_price IS 'Optimise WHERE category_id = X ORDER BY price';

-- Index sur created_at pour tri chronologique
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at DESC);

-- ========== TABLE: CATEGORIES ==========

-- Index sur parent_id (déjà créé)
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id);

-- Index sur slug (déjà UNIQUE, donc index automatique)

-- ========== TABLE: ORDERS ==========

-- Index sur user_id (déjà créé)
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);

-- Index sur status (pour filtrer par statut)
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
COMMENT ON INDEX idx_orders_status IS 'Optimise WHERE status = pending/confirmed';

-- Index sur created_at (tri chronologique)
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);

-- Index composite pour requêtes courantes
CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders(user_id, status);
COMMENT ON INDEX idx_orders_user_status IS 'Optimise WHERE user_id = X AND status = Y';

-- Index composite pour dashboard
CREATE INDEX IF NOT EXISTS idx_orders_status_created ON orders(status, created_at DESC);
COMMENT ON INDEX idx_orders_status_created IS 'Optimise les commandes récentes par statut';

-- ========== TABLE: ORDER_ITEMS ==========

-- Index sur order_id (déjà créé)
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- Index sur product_id (déjà créé)
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- Index composite pour requêtes courantes
CREATE INDEX IF NOT EXISTS idx_order_items_product_created ON order_items(product_id, created_at DESC);
COMMENT ON INDEX idx_order_items_product_created IS 'Optimise historique d\'achat par produit';

-- ==================== STATISTIQUES ====================

-- Mettre à jour les statistiques pour l'optimiseur
ANALYZE users;
ANALYZE roles;
ANALYZE products;
ANALYZE categories;
ANALYZE orders;
ANALYZE order_items;

-- ==================== REQUÊTES OPTIMISÉES ====================

-- ===== REQUÊTE 1: Liste des utilisateurs avec rôles (AVANT) =====
-- AVANT (non optimisé):
-- SELECT * FROM users u, roles r WHERE u.role_id = r.id;

-- APRÈS (optimisé):
EXPLAIN ANALYZE
SELECT 
    u.id, 
    u.name, 
    u.email, 
    r.name AS role_name
FROM users u
INNER JOIN roles r ON u.role_id = r.id
ORDER BY u.created_at DESC
LIMIT 50;

-- Optimisations appliquées:
-- 1. Projection ciblée (seulement colonnes nécessaires, pas *)
-- 2. INNER JOIN explicite (plus clair que WHERE)
-- 3. ORDER BY sur colonne indexée (created_at)
-- 4. LIMIT pour pagination

-- ===== REQUÊTE 2: Produits d'une catégorie (AVANT) =====
-- AVANT (non optimisé):
-- SELECT * FROM products WHERE category_id = 2;

-- APRÈS (optimisé):
EXPLAIN ANALYZE
SELECT 
    p.id,
    p.name,
    p.price,
    p.stock,
    c.name AS category_name
FROM products p
INNER JOIN categories c ON p.category_id = c.id
WHERE p.category_id = 2 
  AND p.stock > 0
ORDER BY p.price ASC
LIMIT 20;

-- Optimisations appliquées:
-- 1. Projection ciblée
-- 2. WHERE avec index (category_id indexé)
-- 3. Filtre stock > 0 (index)
-- 4. ORDER BY sur colonne indexée (price)
-- 5. LIMIT pour pagination

-- ===== REQUÊTE 3: Commandes récentes d'un utilisateur (AVANT) =====
-- AVANT (non optimisé):
-- SELECT * FROM orders WHERE user_id = 1 ORDER BY created_at;

-- APRÈS (optimisé):
EXPLAIN ANALYZE
SELECT 
    o.id,
    o.total,
    o.status,
    o.created_at,
    COUNT(oi.id) AS items_count
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE o.user_id = 1
GROUP BY o.id, o.total, o.status, o.created_at
ORDER BY o.created_at DESC
LIMIT 10;

-- Optimisations appliquées:
-- 1. Projection ciblée + agrégation
-- 2. WHERE avec index (user_id)
-- 3. ORDER BY DESC sur index
-- 4. LIMIT 10 (pagination)
-- 5. GROUP BY pour compter items

-- ===== REQUÊTE 4: Recherche produits par nom (OPTIMISÉE) =====
EXPLAIN ANALYZE
SELECT 
    p.id,
    p.name,
    p.price,
    c.name AS category_name
FROM products p
INNER JOIN categories c ON p.category_id = c.id
WHERE p.name ILIKE '%laptop%'
  AND p.stock > 0
ORDER BY p.price ASC
LIMIT 20;

-- Optimisations:
-- 1. Index GIN trigram sur name (recherche ILIKE rapide)
-- 2. Filtre stock indexé
-- 3. Projection ciblée
-- 4. LIMIT strict

-- ===== REQUÊTE 5: Dashboard commandes (OPTIMISÉE) =====
EXPLAIN ANALYZE
SELECT 
    status,
    COUNT(*) AS total_orders,
    SUM(total) AS total_amount,
    AVG(total) AS avg_amount
FROM orders
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY status
ORDER BY total_orders DESC;

-- Optimisations:
-- 1. Index sur status
-- 2. Index sur created_at
-- 3. Agrégations ciblées
-- 4. Pas de LIMIT (résultat groupé petit)

-- ==================== VUES MATÉRIALISÉES (CACHE SQL) ====================

-- Vue matérialisée pour dashboard (rafraîchie périodiquement)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_sales_summary AS
SELECT 
    DATE_TRUNC('day', o.created_at) AS order_date,
    COUNT(DISTINCT o.id) AS total_orders,
    COUNT(oi.id) AS total_items,
    SUM(oi.subtotal) AS total_revenue,
    AVG(o.total) AS avg_order_value
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE o.status != 'cancelled'
GROUP BY DATE_TRUNC('day', o.created_at)
ORDER BY order_date DESC;

-- Index sur la vue matérialisée
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_sales_date ON mv_sales_summary(order_date);

-- Pour rafraîchir : REFRESH MATERIALIZED VIEW CONCURRENTLY mv_sales_summary;

-- ==================== VACUUM ET MAINTENANCE ====================

-- Nettoyer les tables (récupérer espace, mettre à jour stats)
VACUUM ANALYZE users;
VACUUM ANALYZE products;
VACUUM ANALYZE orders;
VACUUM ANALYZE order_items;

-- Configuration auto-vacuum (déjà activé par défaut dans PostgreSQL)
-- Pour vérifier: SHOW autovacuum;

-- ==================== MONITORING DES INDEX ====================

-- Vérifier l'utilisation des index
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Identifier les index non utilisés
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND idx_scan = 0
  AND indexname NOT LIKE 'pg_toast%';

-- Taille des index
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexname::regclass) DESC;

-- ==================== RAPPORTS DE PERFORMANCE ====================

-- Requêtes lentes (nécessite pg_stat_statements)
-- SELECT query, calls, mean_exec_time, max_exec_time 
-- FROM pg_stat_statements 
-- ORDER BY mean_exec_time DESC 
-- LIMIT 10;

-- Cache hit ratio (devrait être > 99%)
SELECT 
    'Cache Hit Ratio' AS metric,
    ROUND(
        100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0),
        2
    ) AS percentage
FROM pg_stat_database
WHERE datname = current_database();

-- ==================== RECOMMANDATIONS ====================

-- 1. Activer pg_stat_statements pour monitorer requêtes lentes
-- 2. Monitorer cache hit ratio (target > 99%)
-- 3. Rafraîchir les vues matérialisées régulièrement (cron)
-- 4. VACUUM ANALYZE régulier (hebdomadaire)
-- 5. Monitorer la taille des index (pas trop gros)
-- 6. Supprimer les index non utilisés
-- 7. Utiliser connection pooling (PgBouncer)
-- 8. Partitionner les grandes tables (si > 10M lignes)

COMMENT ON MATERIALIZED VIEW mv_sales_summary IS 
    'Vue matérialisée pour dashboard - Rafraîchir toutes les heures';
