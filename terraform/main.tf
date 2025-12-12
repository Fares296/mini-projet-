# ============================================
# TERRAFORM CONFIGURATION - MODULE 9
# Infrastructure as Code avec Docker Provider
# ============================================

# Configuration Terraform
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Provider Docker
provider "docker" {
  host = "npipe:////./pipe/docker_engine"  # Windows
  # host = "unix:///var/run/docker.sock"   # Linux/Mac
}

# ==================== VARIABLES ====================
# Les variables sont définies dans variables.tf

# ==================== RÉSEAU ====================

# Réseau Docker pour interconnecter les conteneurs
resource "docker_network" "cloud_network" {
  name   = "${var.project_name}-network"
  driver = "bridge"
  
  ipam_config {
    subnet  = "172.25.0.0/16"
    gateway = "172.25.0.1"
  }
}

# ==================== VOLUMES ====================

# Volume pour PostgreSQL Users
resource "docker_volume" "postgres_data" {
  name = "${var.project_name}-postgres-data"
}

# Volume pour PostgreSQL Products
resource "docker_volume" "postgres_products_data" {
  name = "${var.project_name}-postgres-products-data"
}

# Volume pour Redis
resource "docker_volume" "redis_data" {
  name = "${var.project_name}-redis-data"
}

# Volume pour Prometheus
resource "docker_volume" "prometheus_data" {
  name = "${var.project_name}-prometheus-data"
}

# ==================== IMAGES DOCKER ====================

# Image PostgreSQL
resource "docker_image" "postgres" {
  name         = "postgres:15-alpine"
  keep_locally = true
}

# Image Users Service (buildée manuellement)
resource "docker_image" "users_service" {
  name         = "${var.project_name}-users-service:latest"
  keep_locally = true
}

# Image Products Service (buildée manuellement)
resource "docker_image" "products_service" {
  name         = "${var.project_name}-products-service:latest"
  keep_locally = true
}

# Image Redis
resource "docker_image" "redis" {
  name         = "redis:7-alpine"
  keep_locally = true
}

# ==================== POSTGRESQL USERS ====================

resource "docker_container" "postgres_users" {
  name  = "${var.project_name}-users-postgres"
  image = docker_image.postgres.image_id
  
  restart = "unless-stopped"
  
  env = [
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=usersdb"
  ]
  
  ports {
    internal = 5432
    external = 5432
  }
  
  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }
  
  volumes {
    host_path      = abspath("${path.cwd}/../init.sql")
    container_path = "/docker-entrypoint-initdb.d/init.sql"
    read_only      = true
  }
  
  networks_advanced {
    name = docker_network.cloud_network.name
  }
  
  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.postgres_user} -d usersdb"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}

# ==================== POSTGRESQL PRODUCTS ====================

resource "docker_container" "postgres_products" {
  name  = "${var.project_name}-products-postgres"
  image = docker_image.postgres.image_id
  
  restart = "unless-stopped"
  
  env = [
    "POSTGRES_USER=${var.postgres_products_user}",
    "POSTGRES_PASSWORD=${var.postgres_products_password}",
    "POSTGRES_DB=productsdb"
  ]
  
  ports {
    internal = 5432
    external = 5433
  }
  
  volumes {
    volume_name    = docker_volume.postgres_products_data.name
    container_path = "/var/lib/postgresql/data"
  }
  
  volumes {
    host_path      = abspath("${path.cwd}/../products-service/init-products.sql")
    container_path = "/docker-entrypoint-initdb.d/init-products.sql"
    read_only      = true
  }
  
  networks_advanced {
    name = docker_network.cloud_network.name
  }
  
  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U ${var.postgres_products_user} -d productsdb"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}

# ==================== REDIS ====================

resource "docker_container" "redis" {
  name  = "${var.project_name}-redis"
  image = docker_image.redis.image_id
  
  restart = "unless-stopped"
  
  command = [
    "redis-server",
    "--appendonly", "yes",
    "--maxmemory", "256mb",
    "--maxmemory-policy", "allkeys-lru"
  ]
  
  ports {
    internal = 6379
    external = 6379
  }
  
  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }
  
  networks_advanced {
    name = docker_network.cloud_network.name
  }
  
  healthcheck {
    test     = ["CMD", "redis-cli", "ping"]
    interval = "10s"
    timeout  = "5s"
    retries  = 3
  }
}

# ==================== USERS SERVICE - INSTANCE 1 ====================

resource "docker_container" "users_service_1" {
  name  = "${var.project_name}-users-service-1"
  image = docker_image.users_service.image_id
  
  restart = "unless-stopped"
  
  env = [
    "PORT=3000",
    "DB_HOST=${docker_container.postgres_users.name}",
    "DB_PORT=5432",
    "DB_USER=${var.postgres_user}",
    "DB_PASSWORD=${var.postgres_password}",
    "DB_NAME=usersdb",
    "REDIS_HOST=${docker_container.redis.name}",
    "REDIS_PORT=6379",
    "INSTANCE_ID=1",
    "NODE_ENV=production"
  ]
  
  ports {
    internal = 3000
    external = 3000
  }
  
  networks_advanced {
    name = docker_network.cloud_network.name
  }
  
  # Dépendances
  depends_on = [
    docker_container.postgres_users,
    docker_container.redis
  ]
}

# ==================== USERS SERVICE - INSTANCE 2 ====================

resource "docker_container" "users_service_2" {
  name  = "${var.project_name}-users-service-2"
  image = docker_image.users_service.image_id
  
  restart = "unless-stopped"
  
  env = [
    "PORT=3000",
    "DB_HOST=${docker_container.postgres_users.name}",
    "DB_PORT=5432",
    "DB_USER=${var.postgres_user}",
    "DB_PASSWORD=${var.postgres_password}",
    "DB_NAME=usersdb",
    "REDIS_HOST=${docker_container.redis.name}",
    "REDIS_PORT=6379",
    "INSTANCE_ID=2",
    "NODE_ENV=production"
  ]
  
  ports {
    internal = 3000
    external = 3004
  }
  
  networks_advanced {
    name = docker_network.cloud_network.name
  }
  
  depends_on = [
    docker_container.postgres_users,
    docker_container.redis
  ]
}

# ==================== USERS SERVICE - INSTANCE 3 ====================

resource "docker_container" "users_service_3" {
  name  = "${var.project_name}-users-service-3"
  image = docker_image.users_service.image_id
  
  restart = "unless-stopped"
  
  env = [
    "PORT=3000",
    "DB_HOST=${docker_container.postgres_users.name}",
    "DB_PORT=5432",
    "DB_USER=${var.postgres_user}",
    "DB_PASSWORD=${var.postgres_password}",
    "DB_NAME=usersdb",
    "REDIS_HOST=${docker_container.redis.name}",
    "REDIS_PORT=6379",
    "INSTANCE_ID=3",
    "NODE_ENV=production"
  ]
  
  ports {
    internal = 3000
    external = 3003
  }
  
  networks_advanced {
    name = docker_network.cloud_network.name
  }
  
  depends_on = [
    docker_container.postgres_users,
    docker_container.redis
  ]
}

# ==================== PRODUCTS SERVICE ====================

resource "docker_container" "products_service" {
  name  = "${var.project_name}-products-service"
  image = docker_image.products_service.image_id
  
  restart = "unless-stopped"
  
  env = [
    "PORT=3001",
    "DB_HOST=${docker_container.postgres_products.name}",
    "DB_PORT=5432",
    "DB_USER=${var.postgres_products_user}",
    "DB_PASSWORD=${var.postgres_products_password}",
    "DB_NAME=productsdb",
    "NODE_ENV=production"
  ]
  
  ports {
    internal = 3001
    external = 3002
  }
  
  networks_advanced {
    name = docker_network.cloud_network.name
  }
  
  depends_on = [
    docker_container.postgres_products
  ]
}

# ==================== OUTPUTS ====================
# Les outputs sont définis dans outputs.tf

# ==================== LOCALS ====================

locals {
  common_labels = {
    project     = var.project_name
    managed_by  = "terraform"
    environment = "development"
  }
  
  timestamp = timestamp()
}

# ==================== DATA SOURCES ====================

# Informations sur le provider Docker
data "docker_registry_image" "postgres" {
  name = "postgres:15-alpine"
}

data "docker_registry_image" "redis" {
  name = "redis:7-alpine"
}
