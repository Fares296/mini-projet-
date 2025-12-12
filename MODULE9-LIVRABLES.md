# MODULE 9 - LIVRABLES
## Infrastructure as Code avec Terraform

---

## ✅ RÉSUMÉ DES TRAVAUX RÉALISÉS

### Vue d'ensemble

Le Module 9 a consisté à migrer le déploiement de l'infrastructure de Docker Compose vers **Terraform**. Cela permet une gestion de l'état, une reproductibilité accrue et une meilleure modularité.

---

## 🏗️ 1. DESCRIPTION DE L'INFRASTRUCTURE (main.tf) ✅

L'infrastructure complète a été décrite en HCL (HashiCorp Configuration Language) :

### Composants déployés

| Ressource | Type | Nom Terraform | Détails |
|-----------|------|---------------|---------|
| **Réseau** | docker_network | `cloud_network` | Bridge, Subnet 172.25.0.0/16 |
| **Volumes** | docker_volume | `postgres_data` | Persistance Users DB |
| | | `postgres_products_data` | Persistance Products DB |
| | | `redis_data` | Persistance Redis |
| **Base de données** | docker_container | `postgres_users` | PostgreSQL 15, Port 5432 |
| | | `postgres_products` | PostgreSQL 15, Port 5433 |
| **Cache** | docker_container | `redis` | Redis 7, Port 6379 |
| **Services** | docker_container | `users_service` | 3 réplicas (Ports 3000, 3004, 3003) |
| | | `products_service` | 1 instance (Port 3002) |

### Gestion des images

- Utilisation du provider `kreuzwerker/docker`
- Images `users-service` et `products-service` buildées localement et référencées par Terraform
- Images `postgres` et `redis` pullées depuis Docker Hub

---

## 🚀 2. DÉPLOIEMENT EFFECTUÉ ✅

### Commandes exécutées

```powershell
# 1. Initialisation
terraform init

# 2. Build manuel des images (contournement problème contexte Windows)
docker build -t mini-projet-users-service:latest ..
docker build -t mini-projet-products-service:latest ../products-service

# 3. Déploiement
terraform apply -auto-approve
```

### Résultat du déploiement (Capture)

```
Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:

access_urls = {
  "products" = "http://localhost:3002"
  "users_1" = "http://localhost:3000"
  "users_2" = "http://localhost:3004"
  "users_3" = "http://localhost:3003"
}
databases = <sensitive>
deployment_info = <<EOT
  
  ╔════════════════════════════════════════════════════════════╗
  ║          DÉPLOIEMENT TERRAFORM RÉUSSI ✅                   ║
  ╚════════════════════════════════════════════════════════════╝
  
  📦 INFRASTRUCTURE DÉPLOYÉE:
  
  🌐 Réseau: mini-projet-network
  
  💾 Volumes:
     - mini-projet-postgres-data
     - mini-projet-postgres-products-data
     - mini-projet-redis-data
  
  🗄️ Bases de données:
     - PostgreSQL Users:    localhost:5432
     - PostgreSQL Products: localhost:5433
  
  🚀 Microservices:
     - Users Service (×3):
       • Instance 1: http://localhost:3000
       • Instance 2: http://localhost:3004
       • Instance 3: http://localhost:3003
     - Products Service: http://localhost:3002
  
  📊 Cache:
     - Redis: localhost:6379
  
EOT
network = {
  "id" = "..."
  "name" = "mini-projet-network"
  "subnet" = "172.25.0.0/16"
}
```

---

## 📂 3. FICHIERS LIVRÉS

### Configuration Terraform

✅ `terraform/main.tf` : Définition des ressources
✅ `terraform/variables.tf` : Variables paramétrables
✅ `terraform/outputs.tf` : Sorties et résumé
✅ `terraform/.gitignore` : Exclusion des fichiers sensibles/temporaires

### Preuves

✅ `terraform/terraform_state.txt` : État complet de l'infrastructure (généré par `terraform show`)

---

## 🎯 4. VALIDATION DES OBJECTIFS

| Objectif | Livrable | Statut | Preuve |
|----------|----------|--------|--------|
| Décrire infra via Terraform | main.tf | ✅ | Fichier main.tf complet |
| Déployer réseau | docker_network | ✅ | Output `network` |
| Déployer volumes | docker_volume | ✅ | Output `volumes` |
| Déployer PostgreSQL | docker_container | ✅ | Containers postgres running |
| Déployer users-service | docker_container | ✅ | 3 instances running |
| Déployer products-service | docker_container | ✅ | 1 instance running |

**TOUS LES OBJECTIFS SONT ATTEINTS** ✅

---

## ✨ CONCLUSION

Le Module 9 a permis de passer à une approche **Infrastructure as Code** robuste.

**Avantages acquis** :
- ✅ **Reproductibilité** : L'infrastructure est définie dans le code.
- ✅ **État géré** : Terraform connait l'état exact des ressources (`terraform.tfstate`).
- ✅ **Modularité** : Utilisation de variables pour configurer l'environnement.
- ✅ **Sécurité** : Gestion des secrets (marqués `sensitive`).

**Date de réalisation** : 5 décembre 2025  
**Outil** : Terraform v1.x + Docker Provider  
**Status** : ✅ **MODULE 9 COMPLÉTÉ**

---

**🏗️ INFRASTRUCTURE DÉPLOYÉE AVEC SUCCÈS VIA TERRAFORM !**
