# Implementation Plan: Recherche et réservation de machines sur les 7 agences

**Branch**: `001-reservation-multi-agences` | **Date**: 2026-10-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-reservation-multi-agences/spec.md`

## Summary

Remplacer les 7 fichiers Excel par une API Laravel (`back`) qui porte **toutes** les règles de
réservation (FR-001 à FR-015) et un front Nuxt (`web`) qui les affiche. Un service de domaine
unique, `ReservationRules`, produit des violations codées et traduites, réutilisées par la
recherche, la création et l'onglet « À traiter ». Le contrat d'API est figé dans
[contracts/api.md](contracts/api.md) pour que les deux repos avancent en parallèle.

## Affected Repos

<!-- speckit-multirepo:begin -->
| Repo | Rôle dans la feature |
|---|---|
| `back` | Scaffolding Laravel + Docker, modèle de données, règles, API, seeders, tests Feature des 16 scénarios |
| `web` | Scaffolding Nuxt + Docker, écrans recherche / réservation / planning / à traiter / VGP, sélecteur agence + rôle |
<!-- speckit-multirepo:end -->

Ordre de merge : **`back` d'abord**, puis `web` (le front appelle des endpoints qui doivent exister sur la branche principale de `back`).

## Technical Context

**Language/Version**: PHP 8.4 / Laravel 12 (dernière stable au scaffolding) ; TypeScript / Nuxt 4, Node 22 LTS

**Primary Dependencies**: back — Laravel, Larastan ; web — Nuxt 4, Vuetify, @nuxtjs/i18n, Pinia

**Storage**: PostgreSQL 17 (conteneur Docker)

**Testing**: back — PHPUnit (tier Feature pour les 16 tests de la spec, Unit pour `ReservationRules`) ; web — Vitest pour les composables

**Target Platform**: conteneurs Docker Linux ; navigateur desktop + mobile des agences

**Project Type**: web-service (API REST) + web-app (SPA Nuxt), deux repos

**Performance Goals**: recherche multi-agences < 1 s (SC-002 : réponse en moins de 30 s d'usage) ; volume : une dizaine à quelques centaines de machines, quelques milliers de réservations

**Constraints**: 0 double réservation même en concurrence (SC-001, research R3) ; horloge figable (`APP_FROZEN_NOW`) ; aucune authentification (research R6)

**Scale/Scope**: 7 agences, 5 vues (recherche, planning, à traiter, VGP, formulaire), 15 règles, 16 tests d'acceptation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Statut | Comment le plan le respecte |
|---|---|---|
| I. Règles dans l'API | ✅ | `ReservationRules` dans `back` ; `web` n'affiche que `violations[].message` ; `can_cancel` calculé par l'API, revalidé au `POST /cancel` |
| II. Chaque règle a son test | ✅ | 16 tests Feature nommés d'après la spec + tests Unit des violations ; matrice règle → test dans `tasks.md` |
| III. Conventions Xefi | ✅ | OSDD, plugins laravel/nuxt, code en anglais, messages en français dans `lang/fr` et i18n |
| IV. Contrat d'API d'abord | ✅ | [contracts/api.md](contracts/api.md) figé avant le code |
| V. Tout en Docker | ✅ | `back/compose.yaml` (app + postgres), `web/compose.yaml` (node) ; scaffolding par conteneurs jetables |
| VI. La spec est la mémoire | ✅ | Aucune règle ajoutée par le plan ; les hypothèses (rôle sans auth, 48 h depuis la saisie) viennent de la spec |

Re-check après Phase 1 : ✅ aucun écart. Point de vigilance : l'absence d'authentification (R6) est conforme à la spec mais **interdit toute mise en production** en l'état.

## Project Structure

### Documentation (this feature)

```text
specs/001-reservation-multi-agences/
├── spec.md
├── journal-des-ajouts.md
├── plan.md              # ce fichier
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/api.md
├── data/                # CSV du dossier Vallet
└── tasks.md             # /speckit-tasks
```

### Source Code

```text
back/                                   # Laravel, OSDD
├── compose.yaml                        # app (php 8.4) + db (postgres 17)
├── Dockerfile
├── CLAUDE.md                           # via boost:install
├── app/
│   ├── Enums/ReservationStatus.php     # option | firm | cancelled, avec comportement
│   ├── Enums/Role.php                  # agent | manager
│   ├── Models/{Agency,Machine,Reservation}.php
│   ├── Reservations/                   # domaine
│   │   ├── ReservationRules.php        # violations (R2)
│   │   ├── Violation.php
│   │   ├── ActiveReservations.php      # requêtes « réservations actives » (R4)
│   │   ├── ReserveMachine.php          # création transactionnelle (R3)
│   │   ├── ConfirmOption.php
│   │   ├── CancelReservation.php
│   │   └── ActingUser.php
│   ├── Http/Middleware/ResolveActingUser.php   # X-Agency / X-Role (R6)
│   ├── Http/Controllers/…              # contrôleurs fins, un par ressource
│   ├── Http/Requests/…                 # validation de forme
│   └── Http/Resources/…                # sortie JSON du contrat
├── lang/fr/reservation.php             # messages des violations (R10)
├── database/migrations/ · factories/ · seeders/ (+ seeders/data/*.csv)
├── routes/api.php
└── tests/Feature/Reservations/…        # un test par scénario de la spec

web/                                    # Nuxt 4, OSDD
├── compose.yaml · Dockerfile
├── CLAUDE.md
├── app/
│   ├── pages/{index,planning,a-traiter,vgp}.vue
│   ├── components/…                    # SearchForm, MachineResultCard, ReservationForm, PlanningTable, IssueCard, InspectionTable, ActingUserBar
│   ├── composables/{useApi,useAvailability,useReservations,useIssues,useInspections}.ts
│   └── stores/actingUser.ts            # agence + rôle (cookie)
├── i18n/locales/fr.json
└── tests/
```

**Structure Decision** : deux repos indépendants déclarés dans `repos.yml` (`back`, `web`), conformes au workspace ; aucun code applicatif à la racine.

## Phasage conseillé (pour `/speckit-tasks`)

1. **Socle** (en parallèle) — `back` : scaffolding Laravel + Docker + `CLAUDE.md` ; `web` : scaffolding Nuxt + Docker + `CLAUDE.md`.
2. **Données** — migrations, modèles, seeders depuis les CSV (`back`).
3. **Règles** — `ReservationRules` + tests Unit (`back`) ; en parallèle, `web` construit les écrans sur des données factices conformes au contrat.
4. **API** — endpoints du contrat + tests Feature des 16 scénarios (`back`).
5. **Branchement** — `web` sur la vraie API, recette des 16 tests dans l'interface.

Répartition naturelle à deux : une personne sur `back`, l'autre sur `web`, synchronisées par le contrat.

## Complexity Tracking

Aucune violation de la constitution à justifier.
