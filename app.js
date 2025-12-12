// Charger les variables d'environnement EN PREMIER
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const promClient = require('prom-client');
const redis = require('redis');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const { body, validationResult, param } = require('express-validator');

// Configuration de l'application Express
const app = express();
const PORT = process.env.PORT || 3000;

// ==================== SÉCURITÉ - HELMET ====================

// Helmet ajoute des headers de sécurité HTTP
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// ==================== SÉCURITÉ - RATE LIMITING ====================

// Limiter le nombre de requêtes pour prévenir les attaques par force brute
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 60000, // 1 minute
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // 100 requêtes max
  message: {
    success: false,
    error: 'Trop de requêtes depuis cette IP, veuillez réessayer dans 1 minute'
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

// Appliquer le rate limiter sur toutes les routes
app.use(limiter);

// Rate limiter plus strict pour les routes sensibles (authentification)
const strictLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 tentatives max
  message: {
    success: false,
    error: 'Trop de tentatives. Compte temporairement verrouillé. Réessayez dans 15 minutes.'
  }
});

// ==================== SÉCURITÉ - CORS RESTRICTIF ====================

// Configuration CORS sécurisée
const corsOptions = {
  origin: function (origin, callback) {
    // Liste des origines autorisées (depuis .env)
    const allowedOrigins = (process.env.CORS_ORIGIN || 'http://localhost:3000').split(',');

    // Autoriser les requêtes sans origin (comme Postman) en développement
    if (!origin && process.env.NODE_ENV === 'development') {
      return callback(null, true);
    }

    if (allowedOrigins.indexOf(origin) !== -1 || !origin) {
      callback(null, true);
    } else {
      callback(new Error('Non autorisé par CORS'));
    }
  },
  methods: (process.env.CORS_ALLOWED_METHODS || 'GET,POST,PUT,DELETE').split(','),
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With'
  ],
  credentials: true,
  maxAge: 86400 // 24 heures
};

app.use(cors(corsOptions));

// Middleware pour parser le JSON (avec limite de taille)
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ==================== SÉCURITÉ - MIDDLEWARE DE LOGS ====================

// Middleware de logging des requêtes (sécurité & audit)
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
  const method = req.method;
  const url = req.url;
  const userAgent = req.headers['user-agent'];

  // Log toutes les requêtes entrantes
  console.log(`[${timestamp}] ${method} ${url} - IP: ${ip} - User-Agent: ${userAgent}`);

  // Log les tentatives de requêtes suspectes
  if (url.includes('..') || url.includes('<script>') || url.includes('SELECT')) {
    console.warn(`⚠️  [SECURITY] Requête suspecte détectée - IP: ${ip} - URL: ${url}`);
  }

  next();
});

// ==================== REDIS CLIENT ====================

// Configuration du client Redis
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  }
});

// Connexion à Redis
redisClient.connect().catch(console.error);

redisClient.on('connect', () => {
  console.log('✅ Connexion à Redis réussie!');
});

redisClient.on('error', (err) => {
  console.error('❌ Erreur Redis:', err);
});

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

// Compteur de cache hits/misses
const cacheHitsCounter = new promClient.Counter({
  name: 'cache_hits_total',
  help: 'Total des cache hits',
  labelNames: ['cache_type']
});

const cacheMissesCounter = new promClient.Counter({
  name: 'cache_misses_total',
  help: 'Total des cache misses',
  labelNames: ['cache_type']
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
    instance: process.env.INSTANCE_ID || 'unknown',
    hostname: require('os').hostname(),
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
    res.json({
      status: 'healthy',
      database: 'connected',
      instance: process.env.INSTANCE_ID || 'unknown',
      hostname: require('os').hostname()
    });
  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message,
      instance: process.env.INSTANCE_ID || 'unknown',
      hostname: require('os').hostname()
    });
  }
});

// 1. GET /users - Lister tous les utilisateurs (AVEC CACHE REDIS)
app.get('/users', async (req, res) => {
  const cacheKey = 'users:all';

  try {
    // 1. Essayer de récupérer depuis le cache
    const cachedData = await redisClient.get(cacheKey);

    if (cachedData) {
      // CACHE HIT - Données trouvées dans Redis
      console.log('✅ Cache HIT pour /users');
      cacheHitsCounter.inc({ cache_type: 'users_list' });

      const parsedData = JSON.parse(cachedData);

      return res.json({
        success: true,
        count: parsedData.length,
        data: parsedData,
        cached: true,
        instance: process.env.INSTANCE_ID || 'unknown'
      });
    }

    // CACHE MISS - Données non trouvées, interroger la base de données
    console.log('❌ Cache MISS pour /users - Interrogation de la DB');
    cacheMissesCounter.inc({ cache_type: 'users_list' });

    const result = await pool.query(
      'SELECT id, name, email, created_at FROM users ORDER BY id ASC'
    );

    // Stocker dans Redis avec TTL de 60 secondes
    await redisClient.setEx(cacheKey, 60, JSON.stringify(result.rows));
    console.log('💾 Données stockées dans Redis (TTL: 60s)');

    // Incrémenter le compteur d'opérations
    userOperationsCounter.inc({ operation: 'list' });

    res.json({
      success: true,
      count: result.rows.length,
      data: result.rows,
      cached: false,
      instance: process.env.INSTANCE_ID || 'unknown'
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

// 3. POST /users - Ajouter un nouvel utilisateur (AVEC VALIDATION & INVALIDATION CACHE)
app.post('/users',
  strictLimiter, // Rate limiting strict sur la création
  [
    // Validation des données entrantes
    body('name')
      .trim()
      .isLength({ min: 2, max: 100 })
      .withMessage('Le nom doit contenir entre 2 et 100 caractères')
      .matches(/^[a-zA-ZÀ-ÿ\s'-]+$/)
      .withMessage('Le nom ne peut contenir que des lettres, espaces, apostrophes et tirets'),
    body('email')
      .trim()
      .isEmail()
      .withMessage('Email invalide')
      .normalizeEmail()
      .isLength({ max: 255 })
      .withMessage('Email trop long')
  ],
  async (req, res) => {
    // Vérifier les erreurs de validation
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array()
      });
    }

    const { name, email } = req.body;

    try {
      const result = await pool.query(
        'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at',
        [name, email]
      );

      // Invalider le cache car la liste des utilisateurs a changé
      await redisClient.del('users:all');
      console.log('🗑️  Cache invalidé après création d\'utilisateur');

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

    // Invalider le cache car la liste des utilisateurs a changé
    await redisClient.del('users:all');
    console.log('🗑️  Cache invalidé après suppression d\'utilisateur');

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
