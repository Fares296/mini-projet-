-- ============================================
-- Script de sécurisation PostgreSQL
-- Création d'utilisateurs avec droits limités
-- ============================================

-- ==================== UTILISATEUR USERS DB ====================

-- Créer un utilisateur avec droits limités pour users-service
CREATE USER clouduser_limited WITH PASSWORD 'limited_pass_123';

-- Accorder uniquement les privilèges nécessaires
GRANT CONNECT ON DATABASE usersdb TO clouduser_limited;
GRANT USAGE ON SCHEMA public TO clouduser_limited;

-- Droits sur la table users uniquement
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO clouduser_limited;

-- Autoriser l'utilisation des séquences (pour les ID auto-incrémentés)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO clouduser_limited;

-- Définir les privilèges par défaut pour les futurs objets
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO clouduser_limited;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
  GRANT USAGE, SELECT ON SEQUENCES TO clouduser_limited;

-- REFUSER les privilèges dangereux
REVOKE CREATE ON SCHEMA public FROM clouduser_limited;
REVOKE ALL ON DATABASE usersdb FROM PUBLIC;

-- ==================== COMMENTAIRES ====================

COMMENT ON ROLE clouduser_limited IS 'Utilisateur avec droits limités pour users-service - SELECT, INSERT, UPDATE, DELETE uniquement';

-- ==================== VÉRIFICATION ====================

-- Lister les privilèges de l'utilisateur
\dp users

-- Voir les rôles
\du

-- ==================== BONNES PRATIQUES ====================

-- 1. Principe du moindre privilège (Least Privilege)
--    L'utilisateur ne peut que faire des opérations CRUD de base

-- 2. Pas de privilèges DDL (Data Definition Language)
--    L'utilisateur NE PEUT PAS :
--    - Créer/Supprimer des tables (CREATE TABLE, DROP TABLE)
--    - Modifier le schéma (ALTER TABLE)
--    - Créer des fonctions/triggers
--    - Modifier les privilèges (GRANT/REVOKE)

-- 3. Pas de privilèges système
--    L'utilisateur NE PEUT PAS :
--    - Créer des bases de données
--    - Créer des rôles
--    - Modifier la configuration du serveur

-- 4. Isolation
--    L'utilisateur est limité à la base usersdb uniquement

-- ==================== ROLLBACK EN CAS DE PROBLÈME ====================

-- Pour supprimer l'utilisateur :
-- REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM clouduser_limited;
-- REVOKE ALL PRIVILEGES ON DATABASE usersdb FROM clouduser_limited;
-- DROP USER clouduser_limited;

-- ==================== AUDIT ====================

-- Activer le logging des connexions
-- Dans postgresql.conf :
-- log_connections = on
-- log_disconnections = on
-- log_statement = 'mod'  # Log INSERT, UPDATE, DELETE

-- Créer une table d'audit (optionnel)
-- CREATE TABLE audit_log (
--   id SERIAL PRIMARY KEY,
--   table_name VARCHAR(50),
--   action VARCHAR(10),
--   user_name VARCHAR(50),
--   timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   old_data JSONB,
--   new_data JSONB
-- );
