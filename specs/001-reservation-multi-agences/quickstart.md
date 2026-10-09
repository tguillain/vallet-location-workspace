# Quickstart — 001 Réservation multi-agences

Prérequis : Docker et Git uniquement (constitution V). Toutes les commandes se lancent dans Git Bash,
depuis la racine du workspace.

## Lancer

```bash
docker compose -f back/compose.yaml up -d
docker compose -f back/compose.yaml exec app php artisan migrate:fresh --seed
docker compose -f web/compose.yaml up -d
```

- API : http://localhost:8000/api
- Front : http://localhost:3000
- Horloge figée au lundi 12/10/2026 9 h via `APP_FROZEN_NOW` dans `back/.env` (research R5).

## Tester

```bash
docker compose -f back/compose.yaml exec app php artisan test
```

Un test Feature par scénario « Étant donné / Quand / Alors » de [spec.md](spec.md) (tests 1 à 16),
nommés d'après le test de la spec (constitution II).

## Vérifications rapides de l'API

| Appel | Attendu |
|---|---|
| `GET /api/agencies` | 7 agences |
| `GET /api/availability?type=Nacelle%2012%20m&from=2026-10-15&to=2026-10-16` avec `X-Agency: lyon-est` | NAC112 indisponible (`overlap`), NAC140 disponible avec `transfer_on: 2026-10-14`, NAC118 indisponible (`inspection_expires_during`) |
| `GET /api/reservations/issues` | 3 réservations (NAC112 ×2, NAC089) — test 9 |
| `GET /api/machines/inspections` | NAC089 `expired` en tête, NAC118 `due_soon` — tests 8, 11 |
| `POST /api/reservations/6/cancel` avec `X-Agency: lyon-est`, `X-Role: agent` | 403 `cancel_forbidden` — test 15 |

## Recette dans le front

Jouer les 16 tests de la spec dans l'interface, en choisissant l'agence et le rôle dans l'en-tête.
Le prototype de l'étape 2 sert de référence visuelle : https://claude.ai/artifact/RqxVXrCi35rcK5dASeB1sP
