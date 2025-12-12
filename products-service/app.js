const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const promClient = require('prom-client');

// Configuration de l'application Express
const app = express();
const PORT = process.env.PORT || 3001;

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

// Compteur d'opérations sur les produits
const productOperationsCounter = new promClient.Counter({
  name: 'product_operations_total',
  help: 'Total des opérations sur les produits',
  labelNames: ['operation']
});

// Gauge pour le stock total
const totalStockGauge = new promClient.Gauge({
  name: 'products_total_stock',
  help: 'Stock total de tous les produits'
});

// Gauge pour le nombre de produits
const totalProductsGauge = new promClient.Gauge({
  name: 'products_count',
  help: 'Nombre total de produits en base'
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
  database: process.env.DB_NAME || 'productsdb',
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

// Mettre à jour les gauges périodiquement
const updateGauges = async () => {
  try {
    // Connexions DB
    dbConnectionsGauge.set(pool.totalCount);

    // Stock total et nombre de produits
    const result = await pool.query('SELECT COUNT(*) as count, COALESCE(SUM(stock), 0) as total_stock FROM products');
    if (result.rows.length > 0) {
      totalProductsGauge.set(parseInt(result.rows[0].count));
      totalStockGauge.set(parseInt(result.rows[0].total_stock));
    }
  } catch (error) {
    console.error('Erreur lors de la mise à jour des gauges:', error);
  }
};

// Démarrer la mise à jour des gauges toutes les 5 secondes
setInterval(updateGauges, 5000);
updateGauges(); // Exécuter immédiatement

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
    message: '🛒 API Products - Microservice Cloud-Native',
    version: '1.0.0',
    endpoints: {
      'GET /products': 'Lister tous les produits',
      'GET /products/:id': 'Consulter un produit par ID',
      'GET /products/category/:category': 'Lister les produits par catégorie',
      'POST /products': 'Ajouter un nouveau produit',
      'PUT /products/:id': 'Mettre à jour un produit',
      'DELETE /products/:id': 'Supprimer un produit',
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

// 1. GET /products - Lister tous les produits
app.get('/products', async (req, res) => {
  try {
    const { category, minPrice, maxPrice, inStock } = req.query;
    
    let query = 'SELECT * FROM products WHERE 1=1';
    const params = [];
    let paramCount = 0;

    // Filtres optionnels
    if (category) {
      paramCount++;
      query += ` AND category = $${paramCount}`;
      params.push(category);
    }

    if (minPrice) {
      paramCount++;
      query += ` AND price >= $${paramCount}`;
      params.push(parseFloat(minPrice));
    }

    if (maxPrice) {
      paramCount++;
      query += ` AND price <= $${paramCount}`;
      params.push(parseFloat(maxPrice));
    }

    if (inStock === 'true') {
      query += ' AND stock > 0';
    }

    query += ' ORDER BY id ASC';

    const result = await pool.query(query, params);

    // Incrémenter le compteur d'opérations
    productOperationsCounter.inc({ operation: 'list' });

    res.json({
      success: true,
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Erreur lors de la récupération des produits:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la récupération des produits'
    });
  }
});

// 2. GET /products/:id - Consulter un produit par ID
app.get('/products/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM products WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Produit avec l'ID ${id} non trouvé`
      });
    }

    // Incrémenter le compteur d'opérations
    productOperationsCounter.inc({ operation: 'get' });

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur lors de la récupération du produit:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la récupération du produit'
    });
  }
});

// 3. GET /products/category/:category - Lister par catégorie
app.get('/products/category/:category', async (req, res) => {
  const { category } = req.params;

  try {
    const result = await pool.query(
      'SELECT * FROM products WHERE category = $1 ORDER BY name ASC',
      [category]
    );

    // Incrémenter le compteur d'opérations
    productOperationsCounter.inc({ operation: 'list_by_category' });

    res.json({
      success: true,
      category: category,
      count: result.rows.length,
      data: result.rows
    });
  } catch (error) {
    console.error('Erreur lors de la récupération par catégorie:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la récupération par catégorie'
    });
  }
});

// 4. POST /products - Ajouter un nouveau produit
app.post('/products', async (req, res) => {
  const { name, description, price, stock, category } = req.body;

  // Validation des données
  if (!name || price === undefined) {
    return res.status(400).json({
      success: false,
      error: 'Les champs "name" et "price" sont requis'
    });
  }

  if (price < 0) {
    return res.status(400).json({
      success: false,
      error: 'Le prix ne peut pas être négatif'
    });
  }

  if (stock !== undefined && stock < 0) {
    return res.status(400).json({
      success: false,
      error: 'Le stock ne peut pas être négatif'
    });
  }

  try {
    const result = await pool.query(
      'INSERT INTO products (name, description, price, stock, category) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [name, description || null, price, stock || 0, category || null]
    );

    // Incrémenter le compteur d'opérations
    productOperationsCounter.inc({ operation: 'create' });

    res.status(201).json({
      success: true,
      message: 'Produit créé avec succès',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur lors de la création du produit:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la création du produit'
    });
  }
});

// 5. PUT /products/:id - Mettre à jour un produit
app.put('/products/:id', async (req, res) => {
  const { id } = req.params;
  const { name, description, price, stock, category } = req.body;

  // Validation
  if (price !== undefined && price < 0) {
    return res.status(400).json({
      success: false,
      error: 'Le prix ne peut pas être négatif'
    });
  }

  if (stock !== undefined && stock < 0) {
    return res.status(400).json({
      success: false,
      error: 'Le stock ne peut pas être négatif'
    });
  }

  try {
    // Construire la requête dynamiquement selon les champs fournis
    const updates = [];
    const values = [];
    let paramCount = 0;

    if (name !== undefined) {
      paramCount++;
      updates.push(`name = $${paramCount}`);
      values.push(name);
    }
    if (description !== undefined) {
      paramCount++;
      updates.push(`description = $${paramCount}`);
      values.push(description);
    }
    if (price !== undefined) {
      paramCount++;
      updates.push(`price = $${paramCount}`);
      values.push(price);
    }
    if (stock !== undefined) {
      paramCount++;
      updates.push(`stock = $${paramCount}`);
      values.push(stock);
    }
    if (category !== undefined) {
      paramCount++;
      updates.push(`category = $${paramCount}`);
      values.push(category);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Aucun champ à mettre à jour'
      });
    }

    paramCount++;
    values.push(id);

    const query = `UPDATE products SET ${updates.join(', ')} WHERE id = $${paramCount} RETURNING *`;
    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Produit avec l'ID ${id} non trouvé`
      });
    }

    // Incrémenter le compteur d'opérations
    productOperationsCounter.inc({ operation: 'update' });

    res.json({
      success: true,
      message: 'Produit mis à jour avec succès',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur lors de la mise à jour du produit:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la mise à jour du produit'
    });
  }
});

// 6. DELETE /products/:id - Supprimer un produit
app.delete('/products/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      'DELETE FROM products WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Produit avec l'ID ${id} non trouvé`
      });
    }

    // Incrémenter le compteur d'opérations
    productOperationsCounter.inc({ operation: 'delete' });

    res.json({
      success: true,
      message: 'Produit supprimé avec succès',
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Erreur lors de la suppression du produit:', error);
    res.status(500).json({
      success: false,
      error: 'Erreur serveur lors de la suppression du produit'
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
  console.log(`🛒 Microservice Products démarré sur le port ${PORT}`);
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
