-- Script d'initialisation de la base de données pour le microservice Products

-- Créer la table products
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Créer des index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger pour mettre à jour updated_at automatiquement
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insérer des données de test
INSERT INTO products (name, description, price, stock, category) VALUES
    ('Laptop Dell XPS 15', 'Ordinateur portable haute performance avec écran 15 pouces', 1299.99, 15, 'Informatique'),
    ('iPhone 15 Pro', 'Smartphone Apple dernière génération', 1199.00, 25, 'Téléphonie'),
    ('Samsung Galaxy S24', 'Smartphone Android haut de gamme', 999.00, 30, 'Téléphonie'),
    ('MacBook Pro M3', 'Ordinateur portable Apple avec processeur M3', 2499.00, 10, 'Informatique'),
    ('AirPods Pro', 'Écouteurs sans fil avec réduction de bruit', 279.00, 50, 'Audio'),
    ('Sony WH-1000XM5', 'Casque sans fil avec réduction de bruit active', 399.00, 20, 'Audio'),
    ('iPad Air', 'Tablette Apple 10.9 pouces', 699.00, 18, 'Tablettes'),
    ('Logitech MX Master 3', 'Souris sans fil ergonomique pour productivité', 99.99, 40, 'Accessoires'),
    ('Dell UltraSharp 27"', 'Écran 4K professionnel 27 pouces', 549.00, 12, 'Moniteurs'),
    ('Samsung SSD 1TB', 'Disque SSD NVMe haute vitesse 1TB', 129.00, 60, 'Stockage')
ON CONFLICT DO NOTHING;

-- Afficher un message de confirmation
DO $$
BEGIN
    RAISE NOTICE 'Base de données Products initialisée avec succès!';
END $$;
