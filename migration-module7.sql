-- ============================================
-- MIGRATION DATABASE - MODULE 7
-- Enrichissement et Normalisation 3NF
-- ============================================

-- ==================== CRÉATION TABLE ROLES ====================

CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    level INTEGER NOT NULL DEFAULT 1,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index
CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name);

-- Données initiales
INSERT INTO roles (name, level, description) VALUES
    ('admin', 3, 'Administrateur système avec tous les privilèges'),
    ('user', 2, 'Utilisateur standard avec accès limité'),
    ('guest', 1, 'Invité avec accès en lecture seule')
ON CONFLICT (name) DO NOTHING;

-- ==================== MIGRATION TABLE USERS ====================

-- Ajouter la colonne role_id
ALTER TABLE users ADD COLUMN IF NOT EXISTS role_id INTEGER;

-- Définir la valeur par défaut (2 = user)
UPDATE users SET role_id = 2 WHERE role_id IS NULL;

-- Ajouter la contrainte NOT NULL
ALTER TABLE users ALTER COLUMN role_id SET NOT NULL;

-- Ajouter la contrainte de clé étrangère
ALTER TABLE users 
    ADD CONSTRAINT fk_users_role_id 
    FOREIGN KEY (role_id) REFERENCES roles(id)
    ON DELETE RESTRICT;

-- Index
CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);

-- ==================== CRÉATION TABLE CATEGORIES ====================

CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_id INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_categories_parent_id 
        FOREIGN KEY (parent_id) REFERENCES categories(id)
        ON DELETE SET NULL
);

-- Index
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_slug ON categories(slug);

-- Fonction pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour categories
DROP TRIGGER IF EXISTS update_categories_updated_at ON categories;
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Données initiales (catégories hiérarchiques)
INSERT INTO categories (name, slug, description, parent_id) VALUES
    ('Électronique', 'electronique', 'Tous les produits électroniques', NULL),
    ('Ordinateurs', 'ordinateurs', 'Ordinateurs de bureau et portables', 1),
    ('Smartphones', 'smartphones', 'Téléphones intelligents', 1),
    ('Accessoires', 'accessoires', 'Accessoires électroniques', 1),
    ('Vêtements', 'vetements', 'Tous les vêtements', NULL),
    ('Homme', 'homme', 'Vêtements pour homme', 5),
    ('Femme', 'femme', 'Vêtements pour femme', 5),
    ('Maison', 'maison', 'Articles pour la maison', NULL),
    ('Cuisine', 'cuisine', 'Ustensiles et appareils de cuisine', 8),
    ('Décoration', 'decoration', 'Objets décoratifs', 8)
ON CONFLICT (slug) DO NOTHING;

-- ==================== MIGRATION TABLE PRODUCTS ====================

-- Ajouter la colonne category_id
ALTER TABLE products ADD COLUMN IF NOT EXISTS category_id INTEGER;

-- Assigner une catégorie par défaut aux produits existants
UPDATE products SET category_id = 1 WHERE category_id IS NULL;  -- Électronique par défaut

-- Ajouter la contrainte NOT NULL
ALTER TABLE products ALTER COLUMN category_id SET NOT NULL;

-- Ajouter la contrainte de clé étrangère
ALTER TABLE products 
    ADD CONSTRAINT fk_products_category_id 
    FOREIGN KEY (category_id) REFERENCES categories(id)
    ON DELETE RESTRICT;

-- Ajouter des index pour les recherches courantes
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

-- Ajouter le trigger updated_at si pas déjà présent
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================== CRÉATION TABLE ORDERS ====================

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    total DECIMAL(10, 2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user_id 
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE RESTRICT
);

-- Index
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

-- Trigger pour orders
DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================== CRÉATION TABLE ORDER_ITEMS ====================

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_order_items_order_id 
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product_id 
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT
);

-- Index
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- ==================== TRIGGERS ET FONCTIONS ====================

-- Fonction pour calculer le subtotal automatiquement
CREATE OR REPLACE FUNCTION calculate_order_item_subtotal()
RETURNS TRIGGER AS $$
BEGIN
    NEW.subtotal = NEW.quantity * NEW.unit_price;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour calculer subtotal
DROP TRIGGER IF EXISTS calculate_subtotal ON order_items;
CREATE TRIGGER calculate_subtotal
    BEFORE INSERT OR UPDATE OF quantity, unit_price ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION calculate_order_item_subtotal();

-- Fonction pour mettre à jour le total de la commande
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE orders
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM order_items
        WHERE order_id = NEW.order_id
    )
    WHERE id = NEW.order_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour le total après insert/update/delete
DROP TRIGGER IF EXISTS update_total_on_insert ON order_items;
CREATE TRIGGER update_total_on_insert
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

DROP TRIGGER IF EXISTS update_total_on_update ON order_items;
CREATE TRIGGER update_total_on_update
    AFTER UPDATE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

DROP TRIGGER IF EXISTS update_total_on_delete ON order_items;
CREATE TRIGGER update_total_on_delete
    AFTER DELETE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

-- ==================== DONNÉES DE TEST ====================

-- Créer quelques commandes de test
DO $$
DECLARE
    user1_id INTEGER;
    user2_id INTEGER;
    order1_id INTEGER;
    order2_id INTEGER;BEGIN
    -- Récupérer des utilisateurs existants
    SELECT id INTO user1_id FROM users ORDER BY id LIMIT 1;
    SELECT id INTO user2_id FROM users ORDER BY id LIMIT 1 OFFSET 1;
    
    -- Si on a au moins un utilisateur
    IF user1_id IS NOT NULL THEN
        -- Commande 1
        INSERT INTO orders (user_id, status) 
        VALUES (user1_id, 'pending')
        RETURNING id INTO order1_id;
        
        -- Ajouter des produits à la commande 1
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        SELECT order1_id, id, 2, price
        FROM products
        ORDER BY id
        LIMIT 2;
    END IF;
    
    -- Si on a un deuxième utilisateur
    IF user2_id IS NOT NULL THEN
        -- Commande 2
        INSERT INTO orders (user_id, status) 
        VALUES (user2_id, 'confirmed')
        RETURNING id INTO order2_id;
        
        -- Ajouter des produits à la commande 2
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        SELECT order2_id, id, 1, price
        FROM products
        ORDER BY id DESC
        LIMIT 3;
    END IF;
END $$;

-- ==================== VUES UTILES ====================

-- Vue pour afficher les utilisateurs avec leur rôle
CREATE OR REPLACE VIEW users_with_roles AS
SELECT 
    u.id,
    u.name,
    u.email,
    r.name AS role_name,
    r.level AS role_level,
    u.created_at
FROM users u
JOIN roles r ON u.role_id = r.id;

-- Vue pour afficher les produits avec leur catégorie
CREATE OR REPLACE VIEW products_with_categories AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.price,
    p.stock,
    c.name AS category_name,
    c.slug AS category_slug,
    p.created_at,
    p.updated_at
FROM products p
JOIN categories c ON p.category_id = c.id;

-- Vue pour afficher les commandes complètes
CREATE OR REPLACE VIEW orders_detailed AS
SELECT 
    o.id,
    o.user_id,
    u.name AS user_name,
    u.email AS user_email,
    o.total,
    o.status,
    o.created_at,
    o.updated_at
FROM orders o
JOIN users u ON o.user_id = u.id;

-- Vue pour afficher les lignes de commande avec détails
CREATE OR REPLACE VIEW order_items_detailed AS
SELECT 
    oi.id,
    oi.order_id,
    o.user_id,
    u.name AS user_name,
    oi.product_id,
    p.name AS product_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal,
    oi.created_at
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
JOIN users u ON o.user_id = u.id
JOIN products p ON oi.product_id = p.id;

-- ==================== VÉRIFICATIONS ====================

-- Afficher le nombre d'enregistrements par table
SELECT 'roles' AS table_name, COUNT(*) AS count FROM roles
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'categories', COUNT(*) FROM categories
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

-- Afficher la structure complète
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name IN ('roles', 'users', 'categories', 'products', 'orders', 'order_items')
ORDER BY table_name, ordinal_position;

COMMENT ON TABLE roles IS 'Rôles des utilisateurs (admin, user, guest)';
COMMENT ON TABLE categories IS 'Catégories de produits avec hiérarchie';
COMMENT ON TABLE orders IS 'Commandes passées par les utilisateurs';
COMMENT ON TABLE order_items IS 'Lignes de commande (association orders-products)';
