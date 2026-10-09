# Research — 001 Réservation multi-agences

## R1. Versions et environnement

- **Decision** : `back` = Laravel 12 (ou la dernière stable au moment du scaffolding), PHP 8.4, PostgreSQL 17. `web` = Nuxt 4, Node 22 LTS. Tout tourne en Docker (constitution V) : chaque repo a son `compose.yaml`. Les projets sont créés via des conteneurs jetables (`docker run composer create-project`, `docker run node npx nuxi init`), aucun PHP/Node sur les postes.
- **Rationale** : les deux postes n'ont que Docker et Git.
- **Alternatives** : Laravel Sail (exige Composer pour l'installer — même amorçage en conteneur, mais ajoute une couche) ; installation locale (refusée par l'équipe).

## R2. Où vivent les règles

- **Decision** : un service de domaine unique `ReservationRules` dans `back`, qui reçoit (machine, période, agence qui réserve, réservations actives, maintenant) et renvoie une liste de `Violation` (code + paramètres + message traduit). Il sert à **trois** endroits : la recherche (motifs), la création (refus 422), l'onglet « À traiter » (contrôle des réservations existantes).
- **Rationale** : constitution I — une règle, un endroit, réutilisée partout ; c'est ce que le prototype faisait déjà avec `motifs()`.
- **Alternatives** : règles de validation Laravel (FormRequest) seules — rejeté : elles valident un payload, pas l'état du planning, et ne servent pas à la recherche ni à « À traiter ». Les FormRequest gardent la validation de forme (champs requis, format de date).

## R3. Empêcher la double réservation en concurrence

- **Decision** : création dans une transaction, avec `SELECT … FOR UPDATE` sur la ligne `machines` concernée, puis contrôle des règles, puis insertion.
- **Rationale** : deux agences qui cliquent en même temps sur la même machine ; le verrou sérialise les deux créations, la seconde voit la première et échoue en 422 `overlap`. SC-001 (0 double réservation).
- **Alternatives** : contrainte d'exclusion PostgreSQL (`EXCLUDE USING gist` sur daterange) — très solide mais ne couvre pas le jour de transfert ni les options expirées ; gardée comme amélioration possible.

## R4. Options qui « sautent » après 48 h

- **Decision** : pas de job planifié. Une réservation `option` porte `option_expires_at = created_at + 48 h`. Elle est **active** tant que `option_expires_at > now`. Toutes les requêtes ne considèrent que les réservations actives (scope de requête dans une classe dédiée, pas un scope Eloquent — convention `no-model-scopes`). Le statut affiché « Option expirée » est calculé.
- **Rationale** : l'expiration est exacte à la seconde sans dépendre d'un cron ; testable avec une horloge figée.
- **Alternatives** : commande planifiée qui passe les options en `expired` — ajoute un cron, un décalage, et un état stocké qui peut diverger.

## R5. « Maintenant » injectable

- **Decision** : la variable d'environnement `APP_FROZEN_NOW` (ex. `2026-10-12 09:00:00`), lue dans un service provider qui appelle `Carbon::setTestNow()` si elle est définie. Les tests utilisent `$this->travelTo()`. Le fuseau de l'application est `Europe/Paris`.
- **Rationale** : la démo et les 16 tests de la spec sont écrits au lundi 12/10/2026 9 h.

## R6. Identité de l'utilisateur (sans authentification)

- **Decision** : en-têtes `X-Agency` (code de l'agence) et `X-Role` (`agent` | `manager`) sur chaque requête, résolus par un middleware en un objet `ActingUser` ; 422 si l'agence est inconnue. Le front les stocke dans un cookie, choisis dans l'en-tête comme dans le prototype.
- **Rationale** : l'authentification est hors périmètre (spec) ; FR-015 a quand même besoin de l'agence et du rôle.
- **Risque assumé** : n'importe qui peut se déclarer responsable. À remplacer par une vraie authentification avant toute mise en production.

## R7. Style d'API

- **Decision** : routes Laravel dédiées (`routes/api.php`), contrôleurs fins, API Resources pour la sortie — pas `lomkit/laravel-rest-api`.
- **Rationale** : les endpoints sont des actions métier (rechercher une disponibilité, poser une option, confirmer, annuler), pas du CRUD générique ; la convention Xefi « CRUD via REST API » ne s'applique pas à ces cas.

## R8. Données initiales

- **Decision** : les deux CSV de la spec sont copiés dans `back/database/seeders/data/` et chargés par `AgencySeeder`, `MachineSeeder`, `ReservationSeeder`. La remarque « a l'atelier (verin casse) jusqu'au 2026-10-20 » est lue en `workshop_until = 2026-10-20` + `workshop_note`. Les réservations importées sont `firm`, sans grand compte. Les Excel sont importés tels quels, conflits compris (FR-007).

## R9. Front

- **Decision** : Nuxt 4 + Vuetify (convention Xefi), `@nuxtjs/i18n` en `fr`, Pinia pour l'utilisateur courant (agence, rôle), un composable par ressource d'API (`useAvailability`, `useReservations`, `useIssues`, `useVgp`). Aucune règle métier côté web : il affiche `violations[].message` tels que renvoyés.
- **Rationale** : constitution I et III.

## R10. Libellés des messages

- **Decision** : les messages des violations sont produits par `back` en français via `lang/fr/reservation.php`, avec le `code` stable à côté. `web` affiche le message, et peut se baser sur le `code` pour l'icône ou la couleur.
- **Rationale** : un seul endroit pour la règle *et* sa formulation ; les messages du prototype sont repris.
