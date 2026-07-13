# Guide administrateur — Ubuntu RP

> **Document interne (staff).** Ne pas diffuser aux joueurs : il décrit les outils de modération,
> l'attribution des permissions et la boutique premium. Le wiki joueur ([`wiki/`](wiki/)) reste, lui,
> public et sans secret.

Ce guide explique comment utiliser les outils staff d'Ubuntu RP : le **panel de gestion des joueurs**
(`ubuntu-admin`), les **dons Points** et la **boutique premium** (`ubuntu-premium`), y compris comment
**créer de nouveaux packs**.

---

## 1. Devenir administrateur (groupes ESX)

Les outils staff sont protégés par le **groupe ESX** du joueur (colonne `group` de la table `users`,
renvoyée par `xPlayer.getGroup()`). Trois groupes sont reconnus (du plus puissant au moins puissant) :
**`superadmin`**, **`admin`**, **`mod`**.

| Groupe       | Peut ouvrir `/admin` | Peut créditer des Points (`/addpoints`) |
|--------------|:---:|:---:|
| `superadmin` | ✅ | ✅ |
| `admin`      | ✅ | ✅ |
| `mod`        | ✅ | ❌ |

### Attribuer un grade à quelqu'un

Le joueur doit **s'être connecté au moins une fois** (pour exister dans la table `users`). Repérez son
**identifiant** (colonne `identifier`, du type `license:xxxxxxxx…` — visible dans **txAdmin → Players**
ou la console serveur à la connexion).

**A. Via Adminer (recommandé)** — ouvrez **Adminer** (`http://VOTRE_HOTE:8080`, base `fivem`), table
**`users`**, éditez la ligne du joueur et mettez la colonne **`group`** à `admin` (ou `superadmin` /
`mod`). Le joueur doit **se reconnecter** pour que le nouveau groupe soit chargé.

**B. Via SQL** — dans Adminer (onglet SQL) ou en console MariaDB :

```sql
UPDATE users SET `group` = 'admin' WHERE identifier = 'license:VOTRE_LICENCE_ICI';
```

> 💡 ESX synchronise aussi un **principal ace** `group.<groupe>` au chargement du joueur — inutile de
> gérer les ace à la main. Le panel s'appuie sur le **groupe**, pas sur `add_principal`.

### Vérifier

En jeu, appuyez sur **F6** (ou tapez `/admin`). Si le panel s'ouvre, la permission est active. Un
joueur non autorisé qui tape `/admin` reçoit « Accès refusé : réservé au staff » — c'est normal.

---

## 2. Le panel de gestion des joueurs (`/admin`, touche F6)

Ouvrez le panel avec la commande **`/admin`** ou la touche **F6** (réassignable dans les paramètres
FiveM). Le panel est une interface (NUI) ; appuyez sur **Échap** pour fermer.

> 🔒 **Sécurité** : chaque action est **revalidée côté serveur**. Impossible d'agir sans la permission,
> même en trichant côté client. **Toutes les actions sont journalisées sur Discord** (voir §5).

### Onglet « Joueurs »

Liste tous les joueurs connectés (ID, nom, identifiant, métier, argent, ping). Une **barre de recherche**
filtre par nom, ID ou identifiant. Chaque ligne propose des boutons d'action :

| Bouton | Effet |
|--------|-------|
| **Aller** | Vous téléporte **vers** le joueur. |
| **Amener** | Téléporte le joueur **vers vous**. |
| **Observer** | Mode observation (invisible) au-dessus du joueur. Recliquez pour revenir à votre position. |
| **Réanimer** | Relève un joueur à terre / mort, pleine vie. |
| **Soigner** | Remet la vie au maximum. |
| **Geler** | Immobilise / libère le joueur (bascule). |
| **Argent** | Ajoute (montant positif) ou retire (**montant négatif**) `money` (cash), `bank` ou `black_money`. |
| **Job** | Change le métier + grade (liste des métiers = `ESX.GetJobs()`). |
| **Points** | Crédite des **Points** premium (voir §3). |
| **Kick** | Expulse le joueur (raison demandée). |
| **Ban** | Bannit le joueur (raison + durée en jours). |

### Onglet « Serveur »

- **Annonce globale** : diffuse un message à **tous** les joueurs (notification + chat).

### Bannir / débannir

- **Bannir** : bouton **Ban** → saisissez la **raison** et la **durée (jours)**. Le joueur est
  expulsé immédiatement et ne pourra plus se reconnecter avant l'expiration. Le bannissement est
  enregistré dans la table `bans` ; **`ubuntu-admin` refuse automatiquement** la reconnexion d'un
  joueur banni (vérification à la connexion).
- **Débannir** : le panel ne gère pas encore le débannissement dans l'interface. Pour lever un ban,
  supprimez la ligne concernée dans la table `bans` via **Adminer** (`http://<serveur>:8080`) ou en SQL :

  ```sql
  -- Lister les bans actifs
  SELECT id, name, reason, FROM_UNIXTIME(expire) AS fin, bannedby FROM bans;
  -- Lever un ban précis
  DELETE FROM bans WHERE id = <ID_DU_BAN>;
  ```

---

## 3. Les dons — créditer des **Points**

Les **Points** sont la **monnaie premium** du serveur : des **points de don**, **hors de l'économie RP**
(ils ne se gagnent pas en jouant, ne s'échangent pas contre du $). Les joueurs les dépensent dans la
**boutique** (`/boutique`).

### Créditer un joueur après un don

Deux façons, réservées à **`superadmin`/`admin`** :

- **Depuis le panel** : onglet Joueurs → bouton **Points** → saisissez le montant.
- **Par commande** (console ou en jeu) :

  ```
  /addpoints <ID_joueur> <montant>
  ```

  Exemple : `/addpoints 3 5000` crédite 5 000 Points au joueur d'ID 3. Le joueur reçoit une notification.

> **Barème conseillé** : fixez un taux clair (ex. *1 € donné = 1 000 Points*) et communiquez-le sur
> Discord. Gardez une trace des dons : chaque **achat** en boutique est journalisé dans la table
> `ubuntu_premium_purchases` (identifier, article, coût, date). Le **solde de points** vit dans la table `ubuntu_premium_data`.

### Politique anti pay-to-win

La boutique **ne doit vendre que du cosmétique et du confort**. **N'ajoutez jamais** d'objet qui donne
un avantage de jeu (arme, argent RP, véhicule plus performant, etc.). C'est la règle du serveur et un
argument de confiance auprès des joueurs.

---

## 4. Créer et modifier des packs de la boutique premium

Tout le catalogue est défini dans un seul fichier :
[`resources/[custom]/ubuntu-premium/config.lua`](resources/) → table **`Config.Catalog`**.

**Le serveur est la source de vérité** : les prix et effets vivent ici, jamais côté client. Pour
ajouter un article, il suffit d'**ajouter une entrée** dans `Config.Catalog`, puis de recharger la
ressource.

### Structure d'un article

```lua
{
    id = 'mon_pack_unique',      -- identifiant UNIQUE (ne jamais réutiliser)
    category = 'starter',        -- onglet : starter | cosmetic | vehicle | rank | perk
    type = 'bundle',             -- effet : bundle | cosmetic | vehicle | rank | perk
    oneTime = true,              -- true = achat unique (anti-rachat automatique)
    label = 'Nom affiché',       -- titre de la carte
    cost = 1500,                 -- prix en Points
    description = 'Texte affiché sur la carte.',
    payload = { ... },           -- contenu (dépend du type, voir ci-dessous)
},
```

### Les types d'effet et leur `payload`

**`bundle`** — un moyen de transport **et** une tenue (les starter packs) :

```lua
payload = {
    vehicle = { model = 'faggio', garage = 'motelgarage' },
    outfit  = { name = 'Urban', skin = outfit({
        ['torso2'] = { item = 245, texture = 2 },  -- haut
        ['pants']  = { item = 24,  texture = 0 },  -- bas
        ['shoes']  = { item = 21,  texture = 0 },
    }) },
},
```

**`vehicle`** — un véhicule cosmétique (ajouté au garage du joueur, **sans** bonus de performance) :

```lua
payload = { vehicle = { model = 'btype', garage = 'motelgarage' } },
```

**`cosmetic`** — une tenue exclusive (apparaît dans la **garde-robe** du joueur) :

```lua
payload = { outfit = { name = 'Savane', skin = outfit({
    ['torso2'] = { item = 6, texture = 1 },
    ['pants']  = { item = 6, texture = 1 },
}) } },
```

**`rank`** — un grade donateur (badge + principal ace optionnel) :

```lua
payload = { rankId = 'vip', aceGroup = 'vip' },
```

**`perk`** — un confort (stocké en métadonnée du joueur) :

```lua
payload = { key = 'extra_char_slots', value = 1 },
```

### Où trouver les valeurs

- **`model` de véhicule** : le nom de spawn (« spawn code ») d'un véhicule GTA/ESX. La liste des
  véhicules du serveur est dans `data/resources/[core]/es_extended/shared/vehicles.lua`.
- **`garage`** : le garage où le véhicule sera récupérable. `motelgarage` est un garage public sûr par
  défaut.
- **Composants de tenue** (`item` = *drawable*, `texture` = *variante de couleur*) : ce sont les
  numéros de vêtements freemode. Le plus simple : **habillez un personnage en jeu** via le magasin de
  vêtements, notez les numéros, puis reportez-les. Composants disponibles dans le helper `outfit(...)` :
  `mask, hair, arms, t-shirt, torso2, vest, decals, bag, pants, shoes, accessory`.

### Exemple complet — ajouter un pack « Business+ »

Dans `Config.Catalog`, ajoutez une entrée (avant l'accolade fermante `}` de la table) :

```lua
{
    id = 'starter_business_plus', category = 'starter', type = 'bundle', oneTime = true,
    label = 'Starter Pack — Business+', cost = 4000,
    description = 'Berline haut de gamme + costume trois-pièces.',
    payload = {
        vehicle = { model = 'schafter2', garage = 'motelgarage' },
        outfit = { name = 'Business+', skin = outfit({
            ['torso2'] = { item = 26, texture = 0 },
            ['pants']  = { item = 10, texture = 0 },
            ['shoes']  = { item = 10, texture = 0 },
        }) },
    },
},
```

### Appliquer les changements

Après avoir édité `config.lua`, rechargez la ressource **sans redémarrer tout le serveur**, depuis la
console :

```
refresh
ensure ubuntu-premium
```

(ou `restart ubuntu-premium`). Testez ensuite avec `/boutique`.

> Si vous ajoutez plus tard une **table SQL** à une ressource custom, relancez `make resources` : le
> script importe automatiquement les `.sql` de `resources/[custom]/` (idempotent).

---

## 5. Logs Discord des actions staff

Chaque action du panel admin (kick, ban, argent, job, annonce, Points…) est envoyée à un **webhook
Discord** pour la traçabilité.

- **Activer** : renseignez la variable **`DISCORD_WEBHOOK`** dans le fichier **`.env`** (URL du webhook
  du salon de logs), puis `make restart`. Vide = logs désactivés.
- Le webhook est exposé au serveur via la convar `discord_webhook` (déjà câblée dans le template).

---

## 6. Bonnes pratiques staff

- **N'abusez jamais** des outils (argent, téléportation, ban) : ils sont journalisés et audités.
- **Motivez** systématiquement kicks et bans (la raison est visible par le joueur et dans les logs).
- **Réservez `god`** à la direction technique ; utilisez `admin`/`mod` pour l'équipe de modération.
- **Bannissements** : privilégiez une durée proportionnée ; documentez les récidives sur Discord.
- **Dons/Points** : tenez un registre (montant ↔ joueur ↔ date) en complément de la table d'audit.
- **Confidentialité** : ne partagez ni licences joueurs, ni ce guide, ni les accès (Adminer, txAdmin).

---

## Références

- [`CLAUDE.md`](CLAUDE.md) — architecture technique des ressources `ubuntu-premium` / `ubuntu-admin`.
- [`DEPLOIEMENT.md`](DEPLOIEMENT.md) — installation & configuration serveur (opérateur).
- [`CHANGELOG.md`](CHANGELOG.md) — historique des fonctionnalités.
- [`resources/[custom]/ubuntu-premium/config.lua`](resources/) — catalogue de la boutique.
- [`resources/[custom]/ubuntu-admin/config.lua`](resources/) — groupes autorisés, webhook, keybind.
