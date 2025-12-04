# Utiliser l'image officielle Node.js LTS (Long Term Support)
FROM node:18-alpine

# Définir le répertoire de travail dans le conteneur
WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer les dépendances de production uniquement
RUN npm install --production

# Copier tout le code source de l'application
COPY . .

# Exposer le port sur lequel l'application écoute
EXPOSE 3000

# Définir la commande de démarrage
CMD ["npm", "start"]
