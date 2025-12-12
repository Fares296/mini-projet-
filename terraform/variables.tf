# ============================================
# VARIABLES - MODULE 9
# Définition des variables Terraform
# ============================================

variable "project_name" {
  description = "Nom du projet pour préfixer les ressources"
  type        = string
  default     = "mini-projet"
}

variable "postgres_user" {
  description = "Utilisateur PostgreSQL pour users DB"
  type        = string
  default     = "clouduser"
  sensitive   = true
}

variable "postgres_password" {
  description = "Mot de passe PostgreSQL pour users DB"
  type        = string
  default     = "cloudpass123"
  sensitive   = true
}

variable "postgres_products_user" {
  description = "Utilisateur PostgreSQL pour products DB"
  type        = string
  default     = "cloudproductuser"
  sensitive   = true
}

variable "postgres_products_password" {
  description = "Mot de passe PostgreSQL pour products DB"
  type        = string
  default     = "productpass456"
  sensitive   = true
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "L'environnement doit être development, staging ou production."
  }
}

variable "users_service_instances" {
  description = "Nombre d'instances users-service à déployer"
  type        = number
  default     = 3
  
  validation {
    condition     = var.users_service_instances >= 1 && var.users_service_instances <= 5
    error_message = "Le nombre d'instances doit être entre 1 et 5."
  }
}
