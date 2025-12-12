-- Script d'initialisation de la base de données pour le microservice Users

-- Créer la table users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Créer un index sur l'email pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Insérer des données de test
INSERT INTO users (name, email) VALUES
    ('Alice Dupont', 'alice.dupont@example.com'),
    ('Bob Martin', 'bob.martin@example.com'),
    ('Charlie Bernard', 'charlie.bernard@example.com'),
    ('Diana Prince', 'diana.prince@example.com'),
    ('Ethan Hunt', 'ethan.hunt@example.com')
ON CONFLICT (email) DO NOTHING;

-- Afficher un message de confirmation
DO $$
BEGIN
    RAISE NOTICE 'Base de données initialisée avec succès!';
END $$;
