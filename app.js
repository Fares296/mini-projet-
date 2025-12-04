const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const promClient = require('prom-client');

// Configuration de l'application Express
const app = express();
const PORT = process.env.PORT || 3000;

// ==================== PROMETHEUS METRICS ====================

// Utiliser le registre par défaut de prom-client
const register = promClient.register;

// Activer la collecte des métriques par défaut (CPU, mémoire, etc.)
promClient.collectDefaultMetrics({ register });

// Compteur de requêtes HTTP
const httpRequestCounter = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total des requêtes HTTP',
  labelNames: ['method', 'route', 'status_code']
});

// Histogramme de latence des requêtes
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Durée des requêtes HTTP en secondes',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5]
});

// Compteur d'erreurs
const httpErrorCounter = new promClient.Counter({
  name: 'http_errors_total',
  help: 'Total des erreurs HTTP',
  labelNames: ['method', 'route', 'status_code']
});

// Gauge pour les connexions DB actives
const dbConnectionsGauge = new promClient.Gauge({
  name: 'db_connections_active',
  help: 'Nombre de connexions actives à la base de données'
});

// Compteur d'opérations sur les utilisateurs
const userOperationsCounter = new promClient.Counter({
  name: 'user_operations_total',
  help: 'Total des opérations sur les utilisateurs',
  labelNames: ['operation']
});

// Middleware de collecte des métriques
app.use((req, res, next) => {
  const start = Date.now();

  // Intercepter la fin de la réponse
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    const labels = {
      method: req.method,
      route: route,
      status_code: res.statusCode
    };

    // Incrémenter le compteur de requêtes
    httpRequestCounter.inc(labels);

    // Enregistrer la durée
    httpRequestDuration.observe(labels, duration);

    // Incrémenter les erreurs si code >= 400
    if (res.statusCode >= 400) {
      httpErrorCounter.inc(labels);
    }
  });

  next();
});

// Middlewares
app.use(cors());
app.use(express.json());

// Configuration de la connexion PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'clouduser',
  password: process.env.DB_PASSWORD || 'cloudpass123',
  database: process.env.DB_NAME || 'usersdb',
});

// Test de connexion à la base de données
pool.connect((err, client, release) => {
  if (err) {
    console.error('❌ Erreur de connexion à PostgreSQL:', err.stack);
  } else {
    console.log('✅ Connexion à PostgreSQL réussie!');
    release();
  }
});

// Mettre à jour le gauge des connexions DB périodiquement
setInterval(() => {
  dbConnectionsGauge.set(pool.totalCount);
}, 5000);

// ==================== PROMETHEUS ENDPOINT ====================

// Endpoint pour exposer les métriques
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error);
  }
});

// ==================== ROUTES API ====================

// Route racine - Information sur l'API
app.get('/', (req, res) => {
  res.json({
    message: '🚀 API Users - Microservice Cloud-Native',
    version: '1.0.0',
    endpoints: {
      'GET /users': 'Lister tous les utilisateurs',
      'GET /users/:id': 'Consulter un utilisateur par ID',
      'POST /users': 'Ajouter un nouvel utilisateur (body: {name, email})',
      'DELETE /users/:id': 'Supprimer un utilisateur',
      'GET /metrics': 'Métriques Prometheus',
      'GET /health': 'Health check'
    }
  });
});

// Route de santé (health check)
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (error) {
    res.status(500).json({ status: 'unhealthy', database: 'disconnected', error: error.message });
  }
});

// 1. GET /users - Lister tous les utilisateurs
app.get('/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, email, created_at FROM users ORDER BY id ASC'
    );

    // Incrémenter le compteur d'opérations
    userOperationsCounter.inc({ operation: 'list' });

    res.json({
      success: true,
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des utilisateurs:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la récupération des utilisateurs'
    });
  }
});

// 2. GET /users/:id - Consulter un utilisateur par ID
app.get('/users/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'SELECT id, name, email, created_at FROM users WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Utilisateur avec l'ID ${id} non trouvé`
      });
    }

    // Incrémenter le compteur d'opérations
    userOperationsCounter.inc({ operation: 'get' });

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur lors de la récupération de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la récupération de l\'utilisateur'
    });
  }
});

// 3. POST /users - Ajouter un nouvel utilisateur
app.post('/users', async (req, res) => {
  const { name, email } = req.body;

  // Validation des données
  if (!name || !email) {
    return res.status(400).json({
      success: false,
      error: 'Les champs "name" et "email" sont requis'
    });
  }

  // Validation basique de l'email
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({
      success: false,
      error: 'Format d\'email invalide'
    });
  }

  try {
    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at',
      [name, email]
    );

    // Incrémenter le compteur d'opérations
    userOperationsCounter.inc({ operation: 'create' });

    res.status(201).json({
      success: true,
      message: 'Utilisateur créé avec succès',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur lors de la création de l\'utilisateur:', error);

    // Gestion de l'erreur de contrainte unique (email déjà existant)
    if (error.code === '23505') {
      return res.status(409).json({
        success: false,
        error: 'Cet email est déjà utilisé'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la création de l\'utilisateur'
    });
  }
});

// 4. DELETE /users/:id - Supprimer un utilisateur
app.delete('/users/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM users WHERE id = $1 RETURNING id, name, email',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Utilisateur avec l'ID ${id} non trouvé`
      });
    }

    // Incrémenter le compteur d'opérations
    userOperationsCounter.inc({ operation: 'delete' });

    res.json({
      success: true,
      message: 'Utilisateur supprimé avec succès',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur lors de la suppression de l\'utilisateur:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la suppression de l\'utilisateur'
    });
  }
});

// Gestion des routes non trouvées (404)
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route non trouvée'
  });
});

// Démarrage du serveur
app.listen(PORT, () => {
  console.log(`🚀 Microservice Users démarré sur le port ${PORT}`);
  console.log(`📍 URL: http://localhost:${PORT}`);
  console.log(`📊 Métriques: http://localhost:${PORT}/metrics`);
  console.log(`💚 Health: http://localhost:${PORT}/health`);
});

// Gestion de l'arrêt propre
process.on('SIGTERM', () => {
  console.log('🛑 SIGTERM reçu, fermeture du serveur...');
  pool.end(() => {
    console.log('✅ Pool PostgreSQL fermé');
    process.exit(0);
  });
});
