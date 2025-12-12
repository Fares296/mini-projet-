-- ============================================
-- MIGRATION PRODUCTS DATABASE - MODULE 7
-- Enrichissement et Normalisation 3NF
-- ============================================

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
    ('Tablettes', 'tablettes', 'Tablettes tactiles', 1),
    ('Audio', 'audio', 'Équipement audio', 1),
    ('Vêtements', 'vetements', 'Tous les vêtements', NULL),
    ('Homme', 'homme', 'Vêtements pour homme', 7),
    ('Femme', 'femme', 'Vêtements pour femme', 7),
    ('Enfant', 'enfant', 'Vêtements pour enfant', 7),
    ('Maison', 'maison', 'Articles pour la maison', NULL),
    ('Cuisine', 'cuisine', 'Ustensiles et appareils de cuisine', 11),
    ('Décoration', 'decoration', 'Objets décoratifs', 11),
    ('Meubles', 'meubles', 'Meubles pour la maison', 11),
    ('Jardin', 'jardin', 'Articles de jardinage', NULL),
    ('Outils', 'outils', 'Outils de jardinage', 15),
    ('Plantes', 'plantes', 'Plantes et graines', 15)
ON CONFLICT (slug) DO NOTHING;

-- ==================== MIGRATION TABLE PRODUCTS ====================

-- Ajouter la colonne category_id si elle n'existe pas
ALTER TABLE products ADD COLUMN IF NOT EXISTS category_id INTEGER;

-- Assigner une catégorie par défaut basée sur le nom du produit existant
UPDATE products 
SET category_id = CASE
    WHEN name ILIKE '%laptop%' OR name ILIKE '%ordinateur%' THEN 2  -- Ordinateurs
    WHEN name ILIKE '%phone%' OR name ILIKE '%smartphone%' THEN 3  -- Smartphones
    WHEN name ILIKE '%headphone%' OR name ILIKE '%casque%' THEN 6  -- Audio
    WHEN name ILIKE '%mouse%' OR name ILIKE '%keyboard%' OR name ILIKE '%clavier%' THEN 4  -- Accessoires
    WHEN name ILIKE '%tablet%' OR name ILIKE '%tablette%' THEN 5  -- Tablettes
    ELSE 1  -- Électronique par défaut
END
WHERE category_id IS NULL;

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
CREATE INDEX IF NOT EXISTS idx_products_stock ON products(stock);

-- Ajouter le trigger updated_at
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================== VUES UTILES ====================

-- Vue pour afficher les produits avec leur catégorie complète
CREATE OR REPLACE VIEW products_with_categories AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.price,
    p.stock,
    c.name AS category_name,
    c.slug AS category_slug,
    pc.name AS parent_category_name,
    pc.slug AS parent_category_slug,
    p.created_at,
    p.updated_at
FROM products p
JOIN categories c ON p.category_id = c.id
LEFT JOIN categories pc ON c.parent_id = pc.id;

-- Vue pour afficher les catégories avec le nombre de produits
CREATE OR REPLACE VIEW categories_with_product_count AS
SELECT 
    c.id,
    c.name,
    c.slug,
    c.description,
    c.parent_id,
    pc.name AS parent_category_name,
    COUNT(p.id) AS product_count,
    c.created_at,
    c.updated_at
FROM categories c
LEFT JOIN categories pc ON c.parent_id = pc.id
LEFT JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name, c.slug, c.description, c.parent_id, pc.name, c.created_at, c.updated_at;

-- Vue pour afficher l'arborescence des catégories
CREATE OR REPLACE VIEW categories_hierarchy AS
WITH RECURSIVE category_tree AS (
    -- Catégories racines
    SELECT 
        id,
        name,
        slug,
        parent_id,
        0 AS level,
        ARRAY[id] AS path,
        name AS full_path
    FROM categories
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Sous-catégories
    SELECT 
        c.id,
        c.name,
        c.slug,
        c.parent_id,
        ct.level + 1,
        ct.path || c.id,
        ct.full_path || ' > ' || c.name
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT 
    id,
    name,
    slug,
    parent_id,
    level,
    full_path,
    REPEAT('  ', level) || name AS indented_name
FROM category_tree
ORDER BY path;

-- ==================== DONNÉES DE TEST SUPPLÉMENTAIRES ====================

-- Mettre à jour les produits existants avec des catégories plus précises
DO $$
BEGIN
    -- Ajuster les catégories des produits existants si nécessaire
    UPDATE products SET category_id = 2 WHERE name ILIKE '%laptop%';
    UPDATE products SET category_id = 3 WHERE name ILIKE '%phone%';
    UPDATE products SET category_id = 5 WHERE name ILIKE '%tablet%';
    UPDATE products SET category_id = 6 WHERE name ILIKE '%headphone%' OR name ILIKE '%speaker%';
END $$;

-- ==================== VÉRIFICATIONS ====================

-- Afficher le nombre d'enregistrements par table
SELECT 'categories' AS table_name, COUNT(*) AS count FROM categories
UNION ALL
SELECT 'products', COUNT(*) FROM products;

-- Afficher la distribution des produits par catégorie
SELECT 
    c.name AS category,
    COUNT(p.id) AS product_count
FROM categories c
LEFT JOIN products p ON c.id = p.category_id
GROUP BY c.id, c.name
ORDER BY product_count DESC, c.name;

-- Afficher l'arborescence des catégories
SELECT * FROM categories_hierarchy;

-- ==================== COMMENTAIRES ====================

COMMENT ON TABLE categories IS 'Catégories de produits avec support hiérarchique';
COMMENT ON COLUMN categories.parent_id IS 'Référence à la catégorie parente pour créer une hiérarchie';
COMMENT ON COLUMN categories.slug IS 'Identifiant URL-friendly unique pour la catégorie';
COMMENT ON VIEW products_with_categories IS 'Vue dénormalisée des produits avec informations de catégorie';
COMMENT ON VIEW categories_with_product_count IS 'Vue des catégories avec le nombre de produits associés';
COMMENT ON VIEW categories_hierarchy IS 'Vue récursive montrant la hiérarchie complète des catégories';
