# ============================================
# OUTPUTS - MODULE 9
# Sorties Terraform après déploiement
# ============================================

output "summary" {
  description = "Résumé du déploiement"
  value = {
    project     = var.project_name
    environment = var.environment
    timestamp   = local.timestamp
  }
}

output "network" {
  description = "Informations sur le réseau Docker"
  value = {
    name   = docker_network.cloud_network.name
    id     = docker_network.cloud_network.id
    subnet = "172.20.0.0/16"
  }
}

output "volumes" {
  description = "Volumes Docker créés"
  value = {
    postgres_users    = docker_volume.postgres_data.name
    postgres_products = docker_volume.postgres_products_data.name
    redis             = docker_volume.redis_data.name
    prometheus        = docker_volume.prometheus_data.name
  }
}

output "databases" {
  description = "Bases de données déployées"
  value = {
    users = {
      container = docker_container.postgres_users.name
      port      = 5432
      database  = "usersdb"
      url       = "postgresql://${var.postgres_user}:***@localhost:5432/usersdb"
    }
    products = {
      container = docker_container.postgres_products.name
      port      = 5433
      database  = "productsdb"
      url       = "postgresql://${var.postgres_products_user}:***@localhost:5433/productsdb"
    }
  }
  sensitive = true
}

output "services" {
  description = "Microservices déployés"
  value = {
    users_service = {
      instances = [
        {
          name = docker_container.users_service_1.name
          url  = "http://localhost:3000"
          id   = "1"
        },
        {
          name = docker_container.users_service_2.name
          url  = "http://localhost:3004"
          id   = "2"
        },
        {
          name = docker_container.users_service_3.name
          url  = "http://localhost:3003"
          id   = "3"
        }
      ]
      total = 3
    }
    products_service = {
      container = docker_container.products_service.name
      url       = "http://localhost:3002"
    }
    redis = {
      container = docker_container.redis.name
      port      = 6379
    }
  }
}

output "access_urls" {
  description = "URLs d'accès aux services"
  value = {
    users_1  = "http://localhost:3000"
    users_2  = "http://localhost:3004"
    users_3  = "http://localhost:3003"
    products = "http://localhost:3002"
  }
}

output "deployment_info" {
  description = "Informations de déploiement"
  value = <<-EOT
  
  ╔════════════════════════════════════════════════════════════╗
  ║          DÉPLOIEMENT TERRAFORM RÉUSSI ✅                   ║
  ╚════════════════════════════════════════════════════════════╝
  
  📦 INFRASTRUCTURE DÉPLOYÉE:
  
  🌐 Réseau: ${docker_network.cloud_network.name}
  
  💾 Volumes:
     - ${docker_volume.postgres_data.name}
     - ${docker_volume.postgres_products_data.name}
     - ${docker_volume.redis_data.name}
  
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
  
  ═══════════════════════════════════════════════════════════
  Commandes utiles:
  
  • Vérifier l'état  : terraform show
  • Voir les outputs : terraform output
  • Mettre à jour    : terraform apply
  • Détruire        : terraform destroy
  ═══════════════════════════════════════════════════════════
  
  EOT
}

output "postgres_users_url" {
  description = "URL de connexion PostgreSQL Users"
  value       = "postgresql://${var.postgres_user}:***@localhost:5432/usersdb"
  sensitive   = true
}

output "postgres_products_url" {
  description = "URL de connexion PostgreSQL Products"
  value       = "postgresql://${var.postgres_products_user}:***@localhost:5433/productsdb"
  sensitive   = true
}
