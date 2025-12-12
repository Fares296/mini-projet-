# 🚀 MODULE 4 - SCALABILITÉ HORIZONTALE - QUICK GUIDE

## 3 instances users-service avec load balancing NGINX

---

## Démarrage

```powershell
# Lancer toute l'infrastructure avec les 3 instances
docker-compose up -d

# Vérifier l'état
docker-compose ps
```

**Attendu** : 9 services UP

```
users-service-1    Up    Port 3000
users-service-2    Up    Port 3004
users-service-3    Up    Port 3003
api-gateway        Up    Port 8080
```

---

## Test du Load Balancing

### Script automatisé (recommandé)

```powershell
powershell -ExecutionPolicy Bypass -File test-load-balancing.ps1
```

**Résultat** :
- 20 requêtes envoyées
- Distribution affichée par instance
- Vérification automatique

### Tests manuels

#### Voir la rotation des instances

```powershell
# 10 requêtes pour observer le round-robin
for ($i=1; $i -le 10; $i++) {
    $response = Invoke-WebRequest http://localhost:8080/users
    Write-Host "Request $i`: " -NoNewline
    Write-Host $response.Headers['X-Upstream-Server']
}
```
**Pattern attendu** : Rotation entre 3 IPs différentes

#### Tester chaque instance directement

```powershell
# Instance 1
$r1 = Invoke-RestMethod http://localhost:3000/health
Write-Host "Instance 1: $($r1.hostname) - $($r1.instance)"

# Instance 2
$r2 = Invoke-RestMethod http://localhost:3004/health
Write-Host "Instance 2: $($r2.hostname) - $($r2.instance)"

# Instance 3
$r3 = Invoke-RestMethod http://localhost:3003/health
Write-Host "Instance 3: $($r3.hostname) - $($r3.instance)"
```

---

## Preuves de Distribution

### 1. Header X-Upstream-Server

```powershell
$response = Invoke-WebRequest http://localhost:8080/users
$response.Headers['X-Upstream-Server']
```

**Output** : `172.19.0.X:3000` (IP change à chaque requête)

### 2. Fichier CSV

Après exécution du script :
- Fichier : `load-balancing-results.csv`
- Contient : Toutes les requêtes avec l'instance qui a répondu

### 3. Logs NGINX

```powershell
docker-compose logs api-gateway | Select-String "upstream"
```

---

## Monitoring Prometheus

### Vérifier les 3 targets

1. Ouvrir : http://localhost:9090/targets
2. Chercher : `users-service`
3. Vérifier : 3 instances UP

**Requêtes PromQL** :

```promql
# Nombre d'instances actives
count(up{job="users-service"} == 1)

# Requêtes par instance
sum(rate(http_requests_total[1m])) by (instance_id)

# Latence par instance
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m])
) by (instance_id)
```

---

## Test de Panne (Failover)

### Simuler une défaillance

```powershell
# Arrêter instance 2
docker stop users-service-2

# Tester (devrait répartir sur 1 et 3)
for ($i=1; $i -le 6; $i++) {
    $r = Invoke-WebRequest http://localhost:8080/users
    Write-Host $r.Headers['X-Upstream-Server']
}

# Redémarrer
docker start users-service-2
```

**Résultat attendu** : Pas d'erreur, distribution sur 2 instances

---

## Configuration NGINX

### Voir la config upstream

```powershell
docker exec api-gateway cat /etc/nginx/conf.d/default.conf | Select-String -Context 2,2 "users-service"
```

**Attendu** :
```nginx
server users-service-1:3000 max_fails=3 fail_timeout=30s;
server users-service-2:3000 max_fails=3 fail_timeout=30s;
server users-service-3:3000 max_fails=3 fail_timeout=30s;
```

---

## ✅ Checklist de validation

- [ ] 9 conteneurs UP (dont 3 users-service)
- [ ] Script test-load-balancing.ps1 retourne "OPTIMAL"
- [ ] Distribution ~33% par instance
- [ ] Header X-Upstream-Server présent
- [ ] 3 IPs différentes visibles
- [ ] Prometheus affiche 3 targets users-service
- [ ] Chaque instance répond à son port direct
- [ ] Failover fonctionne (arrêt 1 instance)

---

## Résultats attendus

```
Distribution des requêtes par instance:

Instance 1 | ████████████████████ | 7 requêtes (35%)
Instance 2 | ████████████████████ | 7 requêtes (35%)
Instance 3 | ██████████████████   | 6 requêtes (30%)

✅ LOAD BALANCING : OPTIMAL
```

---

## Troubleshooting

### Instances ne démarrent pas

```powershell
# Voir les logs
docker-compose logs users-service-1
docker-compose logs users-service-2
docker-compose logs users-service-3
```

### Distribution déséquilibrée

```powershell
# Redémarrer le gateway
docker-compose restart api-gateway

# Vérifier la config
docker exec api-gateway nginx -t
```

### Port déjà utilisé

```powershell
# Trouver le process
netstat -ano | findstr "3000"
netstat -ano | findstr "3004"
netstat -ano | findstr "3003"
```

---

**Module 4 - Scalabilité Horizontale : Opérationnel ! 🎯**
