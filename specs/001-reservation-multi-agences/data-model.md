# Data model — 001 Réservation multi-agences

Base PostgreSQL de `back`. Noms en anglais (constitution III). Pas de suppression en cascade
(convention Xefi `no-cascade-delete`) ; aucune réservation n'est jamais supprimée.

## agencies

| Colonne | Type | Règles |
|---|---|---|
| id | bigint PK | |
| code | string, unique | `lyon-est`, `villeurbanne`, `grenoble`, `saint-etienne`, `clermont-ferrand`, `annecy`, `valence` — envoyé dans `X-Agency` |
| name | string | « Lyon Est »… |

7 lignes fixes, créées par seeder.

## machines

| Colonne | Type | Règles |
|---|---|---|
| id | bigint PK | |
| reference | string, unique | `NAC112` |
| type | string | « Nacelle 12 m » (texte libre, pas d'enum en base — convention `no-db-enums`) |
| agency_id | FK agencies | agence de rattachement |
| last_inspection_on | date, nullable | dernière VGP ; null = machine non soumise à VGP |
| workshop_until | date, nullable | indisponible jusqu'à cette date incluse (FR-003) |
| workshop_note | string, nullable | « vérin cassé » |

**Calculé** : `inspection_valid_until = last_inspection_on + 6 mois − 1 jour` (FR-002).
Une machine est une **nacelle soumise à VGP** ssi `last_inspection_on` n'est pas null.

## reservations

| Colonne | Type | Règles |
|---|---|---|
| id | bigint PK | |
| machine_id | FK machines | |
| client_name | string | requis (FR-005) |
| starts_on | date | ≥ aujourd'hui à la création (FR-004) |
| ends_on | date | ≥ starts_on ; jour du retour (FR-013) |
| agency_id | FK agencies | agence qui a saisi (« saisie par ») |
| status | string | `option` \| `firm` \| `cancelled` — enum PHP `ReservationStatus` avec comportement, stocké en texte |
| option_expires_at | timestamp, nullable | `created_at + 48 h` si `status = option` (FR-014) |
| is_key_account | boolean | client grand compte (FR-012) |
| purchase_order | string, nullable | requis si `is_key_account` (FR-012) |
| cancelled_at | timestamp, nullable | |
| cancelled_by_agency_id | FK agencies, nullable | |
| cancelled_by_role | string, nullable | `agent` \| `manager` |
| created_at / updated_at | timestamps | |

Index : `(machine_id, starts_on, ends_on)`.

### Réservation active

Une réservation **bloque la machine** ssi elle est active :
`status = firm` **ou** (`status = option` **et** `option_expires_at > now`).
`cancelled` et options expirées ne bloquent rien (FR-014, FR-015).

### Transitions de statut

```
           création (is_option)          confirm (avant expiration)
  ───────────────► option ─────────────────────────────► firm
  création ───────────────────────────────────────────► firm
  option ──(now ≥ option_expires_at)──► « expirée » (calculé, pas stocké)
  option | firm ──cancel (si starts_on > aujourd'hui + droits)──► cancelled
```

- `confirm` sur une option expirée, une `firm` ou une `cancelled` → 422 `option_not_active`.
- `cancel` d'une réservation commencée (`starts_on ≤ aujourd'hui`) → 422 `already_started`.
- `cancel` d'une réservation saisie par une autre agence, avec `X-Role: agent` → 403 `cancel_forbidden`.

## Règles → violations (service `ReservationRules`)

Évaluées pour (machine, période, agence qui réserve) contre les réservations **actives**,
`now` = horloge de l'application.

| Code | Règle | FR |
|---|---|---|
| `start_in_past` | `starts_on < aujourd'hui` | FR-004 |
| `end_before_start` | `ends_on < starts_on` | FR-004 |
| `overlap` | une réservation active de la même machine chevauche la période (bornes incluses) | FR-001, FR-013 |
| `workshop` | `workshop_until ≥ starts_on` | FR-003 |
| `inspection_expired` | `inspection_valid_until < aujourd'hui` | FR-002 |
| `inspection_expires_during` | `inspection_valid_until < ends_on` | FR-002 |
| `transfer_too_soon` | machine d'une autre agence et `starts_on − 1 < aujourd'hui` | FR-008 |
| `transfer_day_unavailable` | machine d'une autre agence et la veille est occupée (réservation active ou atelier) | FR-008 |
| `client_required` | `client_name` vide | FR-005 |
| `purchase_order_required` | `is_key_account` et pas de `purchase_order` | FR-012 |

**Avertissement (non bloquant)** : `inspection_due_soon` si `inspection_valid_until − ends_on < 30 jours` (FR-011).

**Contrôle des existantes (« À traiter », FR-010)** : pour chaque réservation active, `overlap`
(contre les autres actives), `inspection_*` (contre `ends_on`), `workshop` si la réservation
n'est pas terminée, `transfer_day_unavailable` si elle n'a pas commencé. `start_in_past`
n'est **pas** un problème pour une réservation existante.
