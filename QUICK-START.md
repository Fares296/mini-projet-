# 🚀 QUICK START GUIDE - Module 1

## Démarrage rapide (5 minutes)

### 1. Lancer tous les services
```powershell
docker-compose up -d --build
```

### 2. Vérifier que tout est UP
```powershell
docker-compose ps
```

### 3. Accéder aux interfaces

| Service | URL | Credentials |
|---------|-----|-------------|
| API Users | http://localhost:3000 | - |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3001 | admin / admin123 |

### 4. Générer du trafic
```powershell
powershell -ExecutionPolicy Bypass -File generate-traffic.ps1
```

### 5. Voir le dashboard Grafana
1. Ouvrir http://localhost:3001
2. Login avec `admin` / `admin123`
3. Aller dans Dashboards → "Users Service - Monitoring Cloud Native"

## Test rapide de l'API

```powershell
# Health check
Invoke-RestMethod -Uri "http://localhost:3000/health"

# Lister les utilisateurs
Invoke-RestMethod -Uri "http://localhost:3000/users"

# Créer un utilisateur
$body = @{name="Test User"; email="test@example.com"} | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:3000/users" -Method POST -Body $body -ContentType "application/json"

# Voir les métriques brutes
Invoke-WebRequest -Uri "http://localhost:3000/metrics"
```

## Vérifier Prometheus

1. Ouvrir http://localhost:9090
2. Status → Targets
3. Vérifier que `users-service` est **UP**

Ou en ligne de commande :
```powershell
Invoke-WebRequest -Uri "http://localhost:9090/api/v1/targets" | ConvertFrom-Json | Select-Object -ExpandProperty data | ConvertTo-Json
```

## Arrêter proprement

```powershell
docker-compose down
```

## Tout supprimer (y compris les données)

```powershell
docker-compose down -v
```

## Logs en temps réel

```powershell
# Tous les services
docker-compose logs -f

# Un service spécifique
docker-compose logs -f users-service
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

## 🎯 Objectifs Module 1 - Checklist

- [x] ✅ Endpoint /metrics fonctionnel
- [x] ✅ Prometheus collecte les métriques
- [x] ✅ Grafana affiche le dashboard
- [x] ✅ Métriques: requêtes/sec
- [x] ✅ Métriques: latence
- [x] ✅ Métriques: erreurs HTTP
- [x] ✅ Métriques: disponibilité

## 📸 Screenshots pour les livrables

Les screenshots sont sauvegardés ici :
- `grafana_dashboard_full_1764890655950.png` - Dashboard Grafana complet
- `prometheus_targets_status_1764890666259.png` - Targets Prometheus

## Troubleshooting

### Service ne démarre pas
```powershell
docker-compose logs users-service
```

### Prometheus ne scrape pas
1. Vérifier que users-service répond: `Invoke-WebRequest http://localhost:3000/metrics`
2. Vérifier la config: `type prometheus.yml`
3. Redémarrer: `docker-compose restart prometheus`

### Grafana n'affiche pas de données
1. Vérifier la datasource: Configuration → Data Sources → Prometheus
2. Vérifier que Prometheus a des données: http://localhost:9090/graph
3. Tester une requête PromQL simple: `up{job="users-service"}`

### Tout reconstruire
```powershell
docker-compose down -v
docker-compose up -d --build --force-recreate
```

## 🎓 Pour aller plus loin

### Ajouter des alertes Prometheus
Créer un fichier `alerts.yml` et configurer Alertmanager

### Personnaliser le dashboard
1. Modifier dans Grafana UI
2. Exporter le JSON
3. Remplacer dans `grafana/dashboards/`

### Scaler le service
```powershell
docker-compose up -d --scale users-service=3
```
*Note: Nécessitera un load balancer (Module suivant)*
