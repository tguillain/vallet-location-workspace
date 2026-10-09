---
description: "Tâches de la feature 001 — recherche et réservation multi-agences"
---

# Tasks: Recherche et réservation de machines sur les 7 agences

**Input**: [plan.md](plan.md), [spec.md](spec.md), [data-model.md](data-model.md), [contracts/api.md](contracts/api.md), [research.md](research.md), [quickstart.md](quickstart.md)

**Tests**: **obligatoires** (constitution II) — chaque scénario « Étant donné / Quand / Alors » de la spec devient un test Feature PHPUnit dans `back/tests/Feature/Reservations/`, nommé `test_spec_NN_…`. Les tests sont écrits avant l'implémentation de leur story et doivent échouer d'abord.

**Organisation** : par user story. Chaque chemin commence par le repo (`back/…`, `web/…`).
Toutes les commandes passent par Docker (constitution V) : `docker compose -f back/compose.yaml exec app …`.

## Format : `[ID] [P?] [Story] Description`

- **[P]** : parallélisable (fichiers différents, pas de dépendance sur une tâche non terminée)
- **[Story]** : US1…US5 (spec.md)

## Répartition à deux

- **Dev A — `back`** : T001–T004, T009–T027, puis les tâches `back/` de chaque story.
- **Dev B — `web`** : T005–T008, T028–T033, puis les tâches `web/` de chaque story, sur des données factices conformes à `contracts/api.md` (T032) tant que l'API n'est pas prête.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: deux projets qui démarrent en Docker, chacun avec son `CLAUDE.md`.

- [ ] T001 Créer le projet Laravel (dernière stable) dans `back/` via un conteneur jetable (`docker run --rm -v "$PWD/back:/app" -w /app composer create-project laravel/laravel .`), sans écraser `back/README.md` ni `back/.git`
- [ ] T002 Écrire `back/Dockerfile` (php 8.4-cli + extensions pdo_pgsql, intl, zip, composer) et `back/compose.yaml` (service `app` sur le port 8000 lancé par `php artisan serve --host=0.0.0.0`, service `db` postgres 17 avec volume, healthcheck), puis configurer `back/.env.example` et `back/.env` (`DB_CONNECTION=pgsql`, `DB_HOST=db`, `APP_TIMEZONE=Europe/Paris`, `APP_LOCALE=fr`, `APP_FROZEN_NOW="2026-10-12 09:00:00"`)
- [ ] T003 Installer l'API Laravel (`php artisan install:api`), Larastan (`back/phpstan.neon`, niveau défini par `laravel:phpstan-xefi-rules`) et Laravel Boost ; lancer `boost:install` pour générer `back/CLAUDE.md` (stack, commandes Docker d'installation, de lancement et de test)
- [ ] T004 Vérifier que `docker compose -f back/compose.yaml up -d` puis `exec app php artisan test` passent sur le projet vierge ; commit « chore: scaffold Laravel + Docker » dans `back`
- [ ] T005 [P] Créer le projet Nuxt 4 dans `web/` via un conteneur jetable (`docker run --rm -v "$PWD/web:/app" -w /app node:22 npx nuxi@latest init . --packageManager npm --force`), sans écraser `web/README.md` ni `web/.git`
- [ ] T006 [P] Écrire `web/Dockerfile` (node 22) et `web/compose.yaml` (service `web` sur le port 3000, `npm run dev -- --host 0.0.0.0`, volume du code, `NUXT_PUBLIC_API_BASE=http://localhost:8000/api`)
- [ ] T007 [P] Ajouter Vuetify, `@nuxtjs/i18n` (locale unique `fr`, fichier `web/i18n/locales/fr.json`), Pinia et Vitest dans `web/package.json` et `web/nuxt.config.ts` ; `runtimeConfig.public.apiBase`
- [ ] T008 [P] Écrire `web/CLAUDE.md` (stack, commandes Docker d'installation, de lancement et de test, convention de commit) ; vérifier `docker compose -f web/compose.yaml up -d` → page d'accueil sur http://localhost:3000 ; commit « chore: scaffold Nuxt + Docker » dans `web`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: données, horloge, identité et moteur de règles, nécessaires à toutes les stories.

**⚠️ CRITICAL**: aucune story ne commence avant la fin de cette phase.

### Données (back)

- [ ] T009 Migration `back/database/migrations/…_create_agencies_table.php` : `id`, `code` string unique, `name` string, timestamps
- [ ] T010 Migration `back/database/migrations/…_create_machines_table.php` : `reference` string unique, `type` string (texte libre, pas d'enum en base), `agency_id` FK agencies sans cascade, `last_inspection_on` date nullable (« null = machine non soumise à VGP »), `workshop_until` date nullable (« indisponible jusqu'à cette date incluse »), `workshop_note` string nullable
- [ ] T011 Migration `back/database/migrations/…_create_reservations_table.php` : `machine_id` FK, `client_name` string, `starts_on` date, `ends_on` date, `agency_id` FK (agence de saisie), `status` string (`option` | `firm` | `cancelled`), `option_expires_at` timestamp nullable, `is_key_account` boolean défaut false, `purchase_order` string nullable, `cancelled_at` timestamp nullable, `cancelled_by_agency_id` FK nullable, `cancelled_by_role` string nullable, timestamps ; index `(machine_id, starts_on, ends_on)` ; aucune cascade
- [ ] T012 [P] Enum `back/app/Enums/ReservationStatus.php` (`Option = 'option'`, `Firm = 'firm'`, `Cancelled = 'cancelled'`) avec comportement (libellé traduit) et enum `back/app/Enums/Role.php` (`Agent = 'agent'`, `Manager = 'manager'`)
- [ ] T013 [P] Modèles `back/app/Models/Agency.php`, `back/app/Models/Machine.php` (relation `agency`, accesseur `inspectionValidUntil` = `last_inspection_on + 6 mois − 1 jour`, `requiresInspection()`), `back/app/Models/Reservation.php` (relations `machine`, `agency`, `cancelledByAgency` ; casts dates, `status` → `ReservationStatus`)
- [ ] T014 [P] Factories `back/database/factories/{Agency,Machine,Reservation}Factory.php`
- [ ] T015 Copier `specs/001-reservation-multi-agences/data/machines.csv` et `reservations.csv` dans `back/database/seeders/data/` ; écrire `AgencySeeder` (7 agences, codes `lyon-est`, `villeurbanne`, `grenoble`, `saint-etienne`, `clermont-ferrand`, `annecy`, `valence`), `MachineSeeder` (remarque « a l'atelier (verin casse) jusqu'au 2026-10-20 » → `workshop_until = 2026-10-20`, `workshop_note = "vérin cassé"`), `ReservationSeeder` (importées telles quelles, `status = firm`, conflits compris — FR-007) dans `back/database/seeders/` ; branchés dans `DatabaseSeeder`
- [ ] T016 Test Feature `back/tests/Feature/SeedersTest.php` : après seed, 7 agences, 12 machines, 7 réservations, MINI07 a `workshop_until = 2026-10-20`

### Horloge et identité (back)

- [ ] T017 [P] Service provider `back/app/Providers/ClockServiceProvider.php` : si `config('app.frozen_now')` (env `APP_FROZEN_NOW`) est défini, `Carbon::setTestNow()` ; config dans `back/config/app.php`
- [ ] T018 [P] `back/app/Reservations/ActingUser.php` (agence + `Role`) et middleware `back/app/Http/Middleware/ResolveActingUser.php` : lit `X-Agency` (obligatoire, 422 `unknown_agency` si absente ou inconnue) et `X-Role` (défaut `agent`) ; appliqué à toutes les routes `api` sauf `GET /agencies`
- [ ] T019 [P] Test Feature `back/tests/Feature/ActingUserTest.php` : sans `X-Agency` → 422 `unknown_agency` ; `X-Role` absent → agent

### Moteur de règles (back)

- [ ] T020 `back/app/Reservations/Violation.php` (code, params, message traduit) et `back/lang/fr/reservation.php` avec un message par code : `start_in_past`, `end_before_start`, `overlap`, `workshop`, `inspection_expired`, `inspection_expires_during`, `transfer_too_soon`, `transfer_day_unavailable`, `client_required`, `purchase_order_required`, `option_not_active`, `already_started`, `cancel_forbidden`, `unknown_agency`, et l'avertissement `inspection_due_soon` (formulations reprises du prototype)
- [ ] T021 `back/app/Reservations/ActiveReservations.php` : requêtes des réservations **actives** (« `status = firm` ou (`status = option` et `option_expires_at > now`) ») — pas de scope Eloquent
- [ ] T022 `back/app/Reservations/ReservationRules.php` : `forBooking(Machine, from, to, Agency)` → `Violation[]` (`start_in_past`, `end_before_start`, `overlap` bornes incluses, `workshop`, `inspection_expired`, `inspection_expires_during`, `transfer_too_soon`, `transfer_day_unavailable`) ; `warnings(Machine, to)` → `inspection_due_soon` si fin de validité VGP − `to` < 30 jours ; `forExisting(Reservation)` → règles de FR-010
- [ ] T023 Tests Unit `back/tests/Unit/Reservations/ReservationRulesTest.php` : un test par code de violation, horloge à 2026-10-12 09:00, données de factory

### Routing commun (back)

- [ ] T024 `back/routes/api.php` avec le groupe middleware `ResolveActingUser` ; `GET /agencies`, `GET /machine-types`, `GET /context` (contrôleurs `back/app/Http/Controllers/{Agency,MachineType,Context}Controller.php`) conformes à `contracts/api.md`
- [ ] T025 [P] API Resources `back/app/Http/Resources/{AgencyResource,MachineResource,ReservationResource,ViolationResource}.php` au format du contrat (`ReservationResource` : `status` calculé `option_expired`, `is_active`, `has_conflict`, `can_confirm`, `can_cancel` selon l'`ActingUser`)
- [ ] T026 Gestion des erreurs métier : exception `back/app/Reservations/ReservationRefused.php` (porte les violations) rendue en 422 `{message, violations}` dans `back/bootstrap/app.php` ; 403 `cancel_forbidden`
- [ ] T027 Test Feature `back/tests/Feature/ReferenceEndpointsTest.php` : `/agencies` (7), `/machine-types`, `/context` (`today = 2026-10-12`)

### Socle front (web)

- [ ] T028 [P] Store `web/app/stores/actingUser.ts` (agence + rôle, persistés en cookie, défaut Lyon Est / agent)
- [ ] T029 [P] Composable `web/app/composables/useApi.ts` : `$fetch` sur `runtimeConfig.public.apiBase`, ajoute `X-Agency` et `X-Role`, transforme un 422/403 en `{ message, violations }`
- [ ] T030 [P] Types TypeScript du contrat `web/app/types/api.ts` (Agency, Machine, Reservation, Violation, AvailabilityItem, InspectionItem, IssueItem)
- [ ] T031 Layout `web/app/layouts/default.vue` + composant `web/app/components/ActingUserBar.vue` (sélecteurs agence et rôle, « Aujourd'hui » depuis `GET /context`) et navigation : Chercher, Planning commun, À traiter, VGP nacelles
- [ ] T032 [P] Données factices `web/app/mocks/` conformes à `contracts/api.md` (jeu du dossier au 12/10) et bascule `NUXT_PUBLIC_USE_MOCKS` dans `useApi.ts`, pour avancer avant l'API
- [ ] T033 [P] Libellés de l'interface dans `web/i18n/locales/fr.json` (aucun texte en dur)

**Checkpoint**: `php artisan test` vert (seeders, identité, règles) ; le front affiche la barre agence/rôle et la navigation.

---

## Phase 3: User Story 1 — Chercher une machine disponible (Priority: P1) 🎯 MVP

**Goal**: chercher par type ou référence sur une période dans les 7 agences, avec motifs et avertissements.

**Independent Test**: `GET /availability` et l'écran de recherche rendent les machines disponibles et les motifs des autres (tests spec 2, 4, 10, 11).

### Tests (back) ⚠️ écrits avant l'implémentation

- [ ] T034 [P] [US1] `back/tests/Feature/Reservations/SearchAvailabilityTest.php` : `test_spec_us1_1` (NAC112 `overlap` 15–16/10, NAC140 proposée), `test_spec_us1_2` (Mini-pelle 1.8 t 13–15/10 : MINI07 `workshop`, MINI12 `overlap`), `test_spec_02` (Nacelle 16 m 20–31/10 : NAC089 `inspection_expired`), `test_spec_04_search` (`from` passé → 422 `start_in_past` ; `to < from` → 422 `end_before_start`), `test_spec_10` (`reference=nac1` → NAC112, NAC140, NAC118, type ignoré), `test_spec_11_search` (NAC118 13–14/10 disponible avec avertissement `inspection_due_soon` « VGP à refaire le 14/10 »)

### Implémentation (back)

- [ ] T035 [US1] FormRequest `back/app/Http/Requests/SearchAvailabilityRequest.php` (`from`, `to` dates requises, `type` et `reference` optionnels)
- [ ] T036 [US1] `back/app/Http/Controllers/AvailabilityController.php` : `GET /availability` — filtre référence (partielle, insensible à la casse, prioritaire sur le type) ou type, applique `ReservationRules::forBooking` et `warnings`, calcule `transfer_on`, trie disponibles d'abord puis par référence, `meta` du contrat ; route dans `back/routes/api.php`

### Implémentation (web)

- [ ] T037 [P] [US1] Composable `web/app/composables/useAvailability.ts`
- [ ] T038 [P] [US1] Composant `web/app/components/SearchForm.vue` : type, référence, du, au ; si la date de début choisie est après la date de fin, la date de fin prend la date de début (FR-004, pré-validation d'ergonomie)
- [ ] T039 [P] [US1] Composant `web/app/components/MachineResultCard.vue` : badge disponible/indisponible, agence, transfert (`transfer_on`), liste des `violations[].message`, encart pour `warnings`
- [ ] T040 [US1] Page `web/app/pages/index.vue` : formulaire, résumé (« N disponibles sur M — du … au … »), liste triée telle que renvoyée, erreur 422 affichée

**Checkpoint**: recherche fonctionnelle de bout en bout ; tests spec 2, 4 (recherche), 10, 11 (recherche) verts.

---

## Phase 4: User Story 2 — Réserver sans erreur (Priority: P1)

**Goal**: réserver (ferme ou en option, grand compte avec bon de commande) sans double réservation possible.

**Independent Test**: `POST /reservations` accepte ou refuse selon les règles ; la réservation apparaît partout (tests spec 1, 3, 4, 5, 6, 7, 12, 13, 14).

### Tests (back) ⚠️

- [ ] T041 [P] [US2] `back/tests/Feature/Reservations/CreateReservationTest.php` : `test_spec_us2_1` (COMP30 BTP Rhone 13–15/10 → 201, agence de saisie enregistrée), `test_spec_us2_2` et `test_spec_01` (`overlap` avec message « déjà réservée du … au … par … (…) »), `test_spec_03` (MINI07 21–23/10 accepté, 19–21/10 `workshop`), `test_spec_04_create` (COMP30 10–11/10 `start_in_past`), `test_spec_05` (NAC140 13–18/10 accepté), `test_spec_06` (Lyon Est sur NAC140 : 24–26/10 `transfer_day_unavailable`, 13–17/10 accepté, départ le 12/10 `transfer_too_soon`), `test_spec_07` (NAC118 13–16/10 `inspection_expires_during`, 13–14/10 accepté), `test_spec_12` (grand compte sans bon → `purchase_order_required` ; avec « BC-2026-118 » → 201, numéro renvoyé), `test_spec_13` (Grenoble sur NAC140 dès le 23/10 → `overlap`, dès le 24/10 → 201), `test_spec_14_create` (option COMP30 13–15/10 : `status = option`, `option_expires_at = 2026-10-14 09:00`, COMP30 indisponible en recherche ; avec horloge au 14/10 09:00 l'option ne bloque plus)
- [ ] T042 [P] [US2] `back/tests/Feature/Reservations/ConcurrentBookingTest.php` : deux créations successives sur la même machine et la même période → une seule acceptée (SC-001)

### Implémentation (back)

- [ ] T043 [US2] FormRequest `back/app/Http/Requests/StoreReservationRequest.php` (`machine_reference`, `client_name`, `starts_on`, `ends_on`, `is_option`, `is_key_account`, `purchase_order`)
- [ ] T044 [US2] Action `back/app/Reservations/ReserveMachine.php` : transaction + `lockForUpdate()` sur la machine, `client_required` et `purchase_order_required`, `ReservationRules::forBooking`, sinon `ReservationRefused` ; crée `firm` ou `option` (`option_expires_at = now + 48 h`)
- [ ] T045 [US2] `back/app/Http/Controllers/ReservationController.php@store` : `POST /reservations` → 201 `ReservationResource`, 404 machine inconnue ; route

### Implémentation (web)

- [ ] T046 [P] [US2] Composable `web/app/composables/useReservations.ts` (`create`, `list`, `confirm`, `cancel`)
- [ ] T047 [US2] Composant `web/app/components/ReservationForm.vue` (dans `MachineResultCard`) : client, case « Option (le client confirme sous 48 h) », case « Client grand compte » qui affiche « N° de bon de commande (obligatoire) » ; violations de l'API affichées ; message de succès avec transfert éventuel ; relance la recherche

**Checkpoint**: on réserve depuis la recherche ; tests spec 1, 3–7, 12, 13, 14 (création) verts.

---

## Phase 5: User Story 3 — Planning commun, conflits, confirmation et annulation (Priority: P2)

**Goal**: voir toutes les réservations, les conflits, confirmer une option, annuler selon les droits.

**Independent Test**: `GET /reservations`, `POST /confirm`, `POST /cancel` (tests spec US3, 14, 15, 16).

### Tests (back) ⚠️

- [ ] T048 [P] [US3] `back/tests/Feature/Reservations/PlanningTest.php` : `test_spec_us3_1` (NAC112 BTP Rhone et Maconnerie Duclos `has_conflict`, `meta.conflict_count = 2`), statuts calculés (`option_expired`)
- [ ] T049 [P] [US3] `back/tests/Feature/Reservations/ConfirmOptionTest.php` : `test_spec_14_confirm` (option confirmée → `firm`) ; option expirée ou réservation ferme → 422 `option_not_active`
- [ ] T050 [P] [US3] `back/tests/Feature/Reservations/CancelReservationTest.php` : `test_spec_15` (Lyon Est agent : `can_cancel = false` sur NAC140 BTP Rhone saisie par Grenoble dans `GET /reservations`, et `POST cancel` → 403 `cancel_forbidden` ; en `manager` → 200, NAC140 disponible du 19 au 23/10), `test_spec_16` (Lyon Est agent annule NAC089 Facades Martin → 200), réservation commencée (ECH40) → 422 `already_started`

### Implémentation (back)

- [ ] T051 [US3] `ReservationController@index` : `GET /reservations` (tri référence puis `starts_on`, `include_cancelled`, `meta.conflict_count` calculé sur les actives)
- [ ] T052 [P] [US3] Action `back/app/Reservations/ConfirmOption.php` + `POST /reservations/{id}/confirm`
- [ ] T053 [P] [US3] Action `back/app/Reservations/CancelReservation.php` : « seule une réservation pas encore commencée » ; « un agent annule celles de son agence, une réservation saisie par une autre agence ne peut être annulée que par un responsable d'agence » ; enregistre `cancelled_at`, `cancelled_by_agency_id`, `cancelled_by_role` ; `POST /reservations/{id}/cancel`

### Implémentation (web)

- [ ] T054 [US3] Composant `web/app/components/PlanningTable.vue` et page `web/app/pages/planning.vue` : colonnes machine, agence de la machine, client, du, au, saisie par, statut (+ BC), état (conflit, nouvelle), actions Confirmer / Annuler affichées **uniquement** si `can_confirm` / `can_cancel` est vrai (un agent ne voit pas « Annuler » sur une réservation d’une autre agence — FR-015) ; alerte conflits ; erreur 403 affichée

**Checkpoint**: tests spec US3, 14, 15, 16 verts ; planning utilisable.

---

## Phase 6: User Story 4 — Nacelles dont la VGP n'est pas à jour (Priority: P2)

**Goal**: vue VGP des nacelles des 7 agences, expirées et bientôt expirées.

**Independent Test**: `GET /machines/inspections` (tests spec 8, 11).

- [ ] T055 [P] [US4] Test `back/tests/Feature/Reservations/InspectionsTest.php` : `test_spec_08` (NAC089 seule `expired`, en tête), `test_spec_11_tab` (NAC118 `due_soon`, `days_left = 2`), `meta`
- [ ] T056 [US4] `back/app/Http/Controllers/InspectionController.php` : `GET /machines/inspections` (`state` `expired` | `due_soon` < 30 jours | `valid`, tri expirées puis `valid_until` croissant) ; route
- [ ] T057 [P] [US4] Composable `web/app/composables/useInspections.ts`, composant `web/app/components/InspectionTable.vue`, page `web/app/pages/vgp.vue` ; badge du nombre d'expirées dans la navigation et bandeau d'alerte sur les autres pages

**Checkpoint**: tests spec 8 et 11 verts.

---

## Phase 7: User Story 5 — Réservations à traiter (Priority: P2)

**Goal**: lister les réservations existantes qui enfreignent une règle.

**Independent Test**: `GET /reservations/issues` (tests spec 9, 16).

- [ ] T058 [P] [US5] Test `back/tests/Feature/Reservations/IssuesTest.php` : `test_spec_09` (3 réservations : NAC112 BTP Rhone `overlap`, NAC112 Maconnerie Duclos `overlap` + `transfer_day_unavailable` (15/10), NAC089 Facades Martin `inspection_expired` ; COMP21, ECH40, NAC140, MINI12 absentes), `test_spec_16_issues` (après annulation de NAC089 Facades Martin, elle n'apparaît plus)
- [ ] T059 [US5] `back/app/Http/Controllers/IssueController.php` : `GET /reservations/issues` via `ReservationRules::forExisting` sur les réservations actives ; route
- [ ] T060 [P] [US5] Composable `web/app/composables/useIssues.ts`, composant `web/app/components/IssueCard.vue`, page `web/app/pages/a-traiter.vue` ; badge dans la navigation et bandeau d'alerte

**Checkpoint**: les 16 tests de la spec sont verts côté `back`.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T061 [P] Larastan sans erreur sur `back/` (`vendor/bin/phpstan analyse`), sans baseline ajoutée
- [ ] T062 [P] Tests Vitest des composables `web/tests/composables/` (en-têtes `X-Agency` / `X-Role`, mapping des erreurs 422/403)
- [ ] T063 Basculer `web` des mocks vers la vraie API (`NUXT_PUBLIC_USE_MOCKS=false`), CORS autorisé pour `http://localhost:3000` dans `back/config/cors.php`
- [ ] T064 Recette manuelle des 16 tests de la spec dans l'interface en suivant `specs/001-reservation-multi-agences/quickstart.md` ; noter tout écart dans la spec, pas dans le code
- [ ] T065 [P] Vérifier l'interface à 375 px de large (navigation qui passe à la ligne, tableaux défilants)

---

## Dependencies & Execution Order

- **Setup (Phase 1)** : T001→T004 (`back`) et T005→T008 (`web`) en parallèle.
- **Foundational (Phase 2)** : dépend du Setup de son repo. Côté `back` : T009–T011 → T012–T016 → T020–T023 ; T017–T019 et T024–T027 en parallèle des règles. Côté `web` : T028–T033 dès T008.
- **US1 et US2 (P1)** : après la Phase 2. US2 réutilise la recherche (relance après réservation) mais son API est indépendante.
- **US3, US4, US5 (P2)** : après la Phase 2 ; US3 et US5 partagent le test 16 (annulation puis « À traiter »).
- **Polish** : après les stories visées.
- **Côté `web`** : chaque page dépend de son endpoint uniquement à T063 (bascule mocks → API).

## Parallel Example: User Story 1

```text
Dev A : T034 (tests) → T035 → T036
Dev B : T037, T038, T039 en parallèle → T040 (sur mocks)
```

## Implementation Strategy

### MVP (US1 + US2)

1. Phase 1 + Phase 2.
2. US1 (chercher) puis US2 (réserver) — c'est la demande de Brice : « chercher une machine dans les 7 agences et la réserver sans erreur ».
3. **STOP et valider** : tests spec 1 à 7, 10, 12 à 14 verts, démo.

### Livraison incrémentale

US3 (planning, annulation) → US4 (VGP) → US5 (à traiter), chacune testable seule.

### Merge

Une PR par repo, liées par « 001 ». `back` mergé avant `web` ; la PR `web` reste ouverte tant que l'API n'est pas sur `main` de `back`.
