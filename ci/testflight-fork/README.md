# TestFlight pour le fork (rugbymeeee)

Pipeline **propre au fork** : il compile MeshCore One (iPhone + Apple Watch) avec ton compte
Apple Developer et l'envoie sur TestFlight. Il n'est jamais proposé à l'auteur
(ne pas inclure `ci/testflight-fork/` ni `.github/workflows/testflight-fork.yml` dans une PR).

L'app de test a ses propres identifiants (`com.rugbymeeee.meshcoreone…`) et s'appelle
**MC1 Beta** sur l'écran d'accueil : elle cohabite avec la version App Store.

> ⚠️ Ne colle jamais ces clés, mots de passe ou tokens dans une conversation (ni avec Claude) :
> saisis-les uniquement dans les formulaires d'Apple et de GitHub.

## 1. Apple Developer : ton Team ID

<https://developer.apple.com/account> → **Membership details** → note le **Team ID** (10 caractères).

## 2. App Store Connect : une clé API

<https://appstoreconnect.apple.com> → **Utilisateurs et accès** → **Intégrations** →
**App Store Connect API** → **Clés d'équipe** → **+**

- Nom : `GitHub CI`
- Accès : **Admin** (nécessaire pour créer les identifiants et les certificats)

Note l'**Issuer ID** (en haut de la page) et le **Key ID**, puis **télécharge le fichier `.p8`**
(il n'est téléchargeable qu'une seule fois, garde-le en lieu sûr).

## 3. GitHub : un dépôt privé pour les certificats

1. <https://github.com/new> → nom **`meshcore-certificates`** → **Private** → sans README → **Create**.
2. Un token d'accès à ce dépôt : <https://github.com/settings/personal-access-tokens/new>
   - Nom : `meshcore match`, expiration au choix
   - **Repository access** → *Only select repositories* → `meshcore-certificates`
   - **Permissions** → *Repository permissions* → **Contents : Read and write**
   - **Generate token** et copie-le.

Les certificats y sont stockés chiffrés avec le mot de passe `MATCH_PASSWORD` (étape 4).

## 4. GitHub : les secrets du fork

<https://github.com/rugbymeeee/MeshCoreOneWatch/settings/secrets/actions> → **New repository secret**,
un par ligne :

| Nom | Valeur |
|---|---|
| `TEAM_ID` | ton Team ID (étape 1) |
| `ASC_ISSUER_ID` | l'Issuer ID (étape 2) |
| `ASC_KEY_ID` | le Key ID (étape 2) |
| `ASC_KEY` | le contenu complet du fichier `.p8` (ouvre-le avec le Bloc-notes, copie tout, lignes `BEGIN`/`END` comprises) |
| `MATCH_GIT_TOKEN` | le token de l'étape 3 |
| `MATCH_PASSWORD` | une phrase de passe longue que tu inventes ; **note-la**, elle sert à déchiffrer les certificats |

Facultatif, onglet **Variables** : `BUNDLE_ID_BASE` (défaut `com.rugbymeeee.meshcoreone`),
`APP_DISPLAY_NAME` (défaut `MC1 Beta`), `MATCH_GIT_URL`
(défaut `https://github.com/rugbymeeee/meshcore-certificates.git`).

## 5. Premier lancement

Pousser sur la branche `testflight` lance le workflow **TestFlight (fork)** :

```bash
git push origin feature/apple-watch:testflight --force
```

Le premier run enregistre les 3 identifiants d'app, crée le certificat et les profils, puis
**s'arrête volontairement** en rouge : l'app n'existe pas encore dans App Store Connect.

## 6. App Store Connect : créer l'app

**Apps** → **+** → **Nouvelle app**

- Plateforme : iOS
- Nom : un nom unique sur l'App Store, par ex. `MeshCore One Watch Beta`
- Langue principale : au choix
- Identifiant de lot : **`com.rugbymeeee.meshcoreone`**
- SKU : par ex. `meshcoreone-watch-beta`

Puis relance le push de l'étape 5. Le build est envoyé sur TestFlight (traitement : 10 à 30 min).

## 7. Installer sur l'iPhone et la montre

1. App Store Connect → ton app → **TestFlight** → **Test interne** → **+** → crée un groupe,
   ajoute-toi comme testeur et active la **distribution automatique**.
2. Sur l'iPhone, installe **TestFlight** depuis l'App Store, accepte l'invitation et installe **MC1 Beta**.
3. L'app montre s'installe depuis TestFlight, ou depuis l'app **Watch** de l'iPhone
   (section *Apps disponibles*).

Une radio ne se connecte qu'à une seule app à la fois : n'utilise pas la version App Store et
MC1 Beta en même temps avec la même radio.
