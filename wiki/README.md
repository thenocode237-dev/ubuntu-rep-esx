# Wiki des joueurs — Ubuntu RP

Site statique (HTML/CSS/JS, sans dépendance ni build) à destination des **nouveaux joueurs** du
serveur : règles, fonctionnement du serveur, guide pour bien démarrer, économie, métiers, commandes
et FAQ.

## Pages

| Fichier | Contenu |
|---------|---------|
| [`index.html`](index.html) | Accueil, présentation du serveur, sommaire |
| [`demarrer.html`](demarrer.html) | Rejoindre le serveur, créer son personnage, premiers pas |
| [`reglement.html`](reglement.html) | Règles RP (RDM, VDM, MetaGaming…), sanctions |
| [`economie.html`](economie.html) | Monnaie ($), banque, commerces |
| [`metiers.html`](metiers.html) | Métiers civils, services publics (police, SAMU…) |
| [`commandes.html`](commandes.html) | Commandes utiles, voix de proximité, interactions |
| [`faq.html`](faq.html) | Foire aux questions des débutants |
| [`assets/style.css`](assets/style.css) | Feuille de style partagée |
| [`assets/script.js`](assets/script.js) | Menu de navigation mobile |

## Consulter le wiki

- **En local** : ouvre simplement [`index.html`](index.html) dans un navigateur (double-clic).
- **Hébergé** : dépose le dossier `wiki/` sur n'importe quel hébergement statique
  (GitHub Pages, Netlify, un dossier servi par Nginx…). Aucun serveur applicatif requis.

### L'exposer via le Nginx du projet (optionnel)

Le projet embarque déjà un reverse proxy Nginx (profil `proxy`). Pour publier le wiki, ajoute un
`server { … }` dans [`../config/nginx/default.conf`](../config/nginx/default.conf) qui sert ce
dossier (monté en lecture seule dans le conteneur `nginx`), par exemple sur `wiki.local`.

## Personnaliser

- **Adresse de connexion, lien Discord** : les pages renvoient au « Discord du serveur » et à
  `adresse-du-serveur:30120` — remplace-les par tes vraies valeurs (recherche `adresse-du-serveur`
  et « Discord » dans les fichiers).
- **Couleurs / thème** : tout est centralisé dans les variables CSS en tête de
  [`assets/style.css`](assets/style.css) (`--primary`, `--accent`, `--bg`…).
- **Contenu** : les montants ($), métiers et commerces reflètent la configuration RP actuelle du
  serveur (couche **ESX** + `resources/[custom]/`). Mets-les à jour si tu modifies la config.

> Ce wiki est **orienté joueur** (aucun secret ni détail d'infrastructure). La documentation
> technique/admin vit à la racine : [`../DEPLOIEMENT.md`](../DEPLOIEMENT.md) et [`../README.md`](../README.md).
