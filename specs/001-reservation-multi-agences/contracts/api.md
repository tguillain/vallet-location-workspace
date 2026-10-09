# Contrat d'API — 001 Réservation multi-agences

**Figé** (constitution IV). `back` l'implémente, `web` le consomme. Tout changement repasse par le plan.

Base : `/api`. JSON uniquement. Dates `YYYY-MM-DD`, horodatages ISO 8601 (Europe/Paris).

## En-têtes communs

| En-tête | Valeurs | Obligatoire |
|---|---|---|
| `X-Agency` | code d'agence (`lyon-est`…) | oui, sauf `GET /agencies` |
| `X-Role` | `agent` \| `manager` | non, défaut `agent` |

Agence absente ou inconnue → `422 {"message": "...", "code": "unknown_agency"}`.

## Format d'une violation

```json
{ "code": "overlap", "message": "Déjà réservée du 14/10 au 18/10 par Lyon Est (BTP Rhone).", "params": { "reservation_id": 1 } }
```

Erreur métier sur une écriture → **422** :
```json
{ "message": "Réservation refusée.", "violations": [ { "code": "...", "message": "...", "params": {} } ] }
```
Erreur de forme (FormRequest Laravel) → 422 standard `{"message", "errors": {champ: [..]}}`.

---

## GET /agencies

`200` → `{ "data": [ { "code": "lyon-est", "name": "Lyon Est" } ] }` (7 éléments)

## GET /machine-types

`200` → `{ "data": ["Compacteur", "Echafaudage 40 m2", "Mini-pelle 1.8 t", ...] }`

## GET /context

`200` → `{ "data": { "now": "2026-10-12T09:00:00+02:00", "today": "2026-10-12" } }` — pour afficher « Aujourd'hui ».

## GET /availability — recherche (US1, FR-006, FR-011)

Query : `from` (requis), `to` (requis), `type` (optionnel), `reference` (optionnel, partielle, insensible à la casse ; si présente, `type` est ignoré).

`422` si `from < aujourd'hui` ou `to < from` → `{ "message", "violations": [start_in_past | end_before_start] }`.

`200` :
```json
{
  "data": [
    {
      "reference": "NAC140", "type": "Nacelle 12 m",
      "agency": { "code": "grenoble", "name": "Grenoble" },
      "available": true,
      "transfer_on": "2026-10-12",
      "violations": [],
      "warnings": [ { "code": "inspection_due_soon", "message": "VGP à refaire le 14/10 : moins de 30 jours après la fin de la location." } ]
    }
  ],
  "meta": { "available_count": 1, "total": 3, "from": "2026-10-13", "to": "2026-10-15" }
}
```
Tri : disponibles d'abord, puis par référence. `transfer_on` = veille du départ si la machine est d'une autre agence, sinon `null`.

## POST /reservations — réserver (US2, FR-001…FR-005, FR-008, FR-012, FR-014)

```json
{ "machine_reference": "COMP30", "client_name": "BTP Rhone", "starts_on": "2026-10-13", "ends_on": "2026-10-15",
  "is_option": false, "is_key_account": true, "purchase_order": "BC-2026-118" }
```
`201` → `{ "data": Reservation }` · `422` → violations · `404` machine inconnue.
Création transactionnelle avec verrou sur la machine (research R3).

## POST /reservations/{id}/confirm — confirmer une option (FR-014)

`200` → `{ "data": Reservation }` (statut `firm`) · `422` `option_not_active` · `404`.

## POST /reservations/{id}/cancel — annuler (FR-015)

`200` → `{ "data": Reservation }` (statut `cancelled`)
`403` → `{ "message": "Seul un responsable d'agence peut annuler une réservation saisie par Grenoble.", "code": "cancel_forbidden" }`
`422` `already_started` · `404`.

## GET /reservations — planning commun (US3, FR-007)

Query optionnelle : `include_cancelled` (défaut `true`).
`200` → `{ "data": [Reservation], "meta": { "conflict_count": 2 } }`, trié par référence puis `starts_on`.

## GET /reservations/issues — à traiter (US5, FR-010)

`200` → `{ "data": [ { "reservation": Reservation, "violations": [Violation] } ], "meta": { "count": 3 } }`

## GET /machines/inspections — VGP nacelles (US4, FR-009, FR-011)

`200` :
```json
{ "data": [ { "reference": "NAC089", "type": "Nacelle 16 m", "agency": {...}, "last_inspection_on": "2026-03-05",
              "valid_until": "2026-09-04", "state": "expired", "days_left": -38 } ],
  "meta": { "expired_count": 1, "due_soon_count": 1 } }
```
`state` : `expired` | `due_soon` (< 30 jours) | `valid`. Tri : expirées, puis `valid_until` croissant.

---

## Objet Reservation

```json
{
  "id": 7, "machine": { "reference": "NAC140", "type": "Nacelle 12 m", "agency": { "code": "grenoble", "name": "Grenoble" } },
  "client_name": "BTP Rhone", "starts_on": "2026-10-19", "ends_on": "2026-10-23",
  "agency": { "code": "grenoble", "name": "Grenoble" },
  "status": "option", "is_active": true, "option_expires_at": "2026-10-14T09:00:00+02:00",
  "is_key_account": false, "purchase_order": null,
  "has_conflict": false,
  "cancelled_at": null, "cancelled_by": null,
  "can_confirm": true, "can_cancel": true
}
```
`status` : `option` | `firm` | `cancelled` | `option_expired` (calculé). `can_cancel` tient compte de
`X-Agency` / `X-Role` : le front masque ou désactive, l'API refuse quand même (constitution I).
