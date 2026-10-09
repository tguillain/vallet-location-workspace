# Feature Specification: Recherche et réservation de machines sur les 7 agences

**Feature Branch**: `001-reservation-multi-agences`
**Created**: 2026-10-09
**Status**: Draft — à valider avec Brice Vallet
**Input**: Consignes « Vallet Location — Du besoin au prototype » (9 oct. 2026) + extrait du parc et des réservations (`data/`)

## Le problème

Les 7 agences tiennent leurs réservations dans des fichiers Excel séparés : la même machine peut être réservée deux fois (NAC112 est réservée par Lyon Est du 14 au 18/10 **et** par Villeurbanne du 16 au 17/10), et des machines non louables (VGP dépassée, à l'atelier) restent réservables.

## Les utilisateurs

- **Personnel d'agence** (Sandrine, Mehdi, Julie, et les autres agences) : cherche une machine disponible dans les 7 agences et la réserve pour un client.
- **Brice Vallet (direction)** : veut une vue unique et sans erreur des réservations du parc.

Hors périmètre : les clients particuliers n'utilisent pas l'outil (pas d'appli grand public).

## User Scenarios & Testing *(mandatory)*

> Date de référence du prototype : **lundi 12 octobre 2026** (« aujourd'hui »).

### User Story 1 — Chercher une machine disponible (Priority: P1)

En tant qu'agent d'agence, je veux chercher un type de machine sur une période dans les 7 agences, afin de savoir immédiatement laquelle est réellement louable et où.

**Independent Test** : saisir un type + des dates, la liste affiche les machines disponibles avec leur agence, et explique pourquoi les autres ne le sont pas.

**Acceptance Scenarios**:

1. **Given** NAC112 réservée du 14 au 18/10, **When** je cherche une « Nacelle 12 m » du 15 au 16/10, **Then** NAC112 est indisponible (motif : déjà réservée) et NAC140 (Grenoble) est proposée.
2. **Given** MINI07 à l'atelier jusqu'au 20/10, **When** je cherche une « Mini-pelle 1.8 t » du 13 au 15/10, **Then** MINI07 est indisponible (motif : atelier) et MINI12 aussi (réservée 13–14/10) → aucun résultat disponible, avec les motifs.

### User Story 2 — Réserver sans erreur (Priority: P1)

En tant qu'agent d'agence, je veux réserver une machine trouvée pour un client, afin que la réservation soit visible de toutes les agences et ne puisse pas être doublée.

**Acceptance Scenarios**:

1. **Given** COMP30 libre, **When** je la réserve pour « BTP Rhone » du 13 au 15/10, **Then** la réservation est enregistrée avec l'agence qui l'a saisie et apparaît dans le planning commun.
2. **Given** NAC140 réservée du 19 au 23/10, **When** une autre agence tente de la réserver du 22 au 25/10, **Then** la réservation est refusée avec le message « déjà réservée du 19/10 au 23/10 par Grenoble (BTP Rhone) ».

### User Story 3 — Voir les conflits existants (Priority: P2)

En tant que directeur, je veux voir les réservations reprises des Excel qui se chevauchent, afin de les arbitrer.

**Acceptance Scenarios**:

1. **Given** les réservations importées, **When** j'ouvre le planning, **Then** les deux réservations de NAC112 (BTP Rhone / Maconnerie Duclos) sont signalées en conflit.

### Edge Cases

- Réservation d'un seul jour (du = au) : valide (cf. COMP21 le 12/10).
- Réservation qui touche une autre bout à bout (fin le 18, début le 19) : autorisée — les dates sont **inclusives**.
- Date de fin avant date de début, ou date de début passée : refusée.
- Réservation en cours aujourd'hui (ECH40 du 06 au 24/10) : bloque la machine.

## Requirements *(mandatory)*

### Les règles que l'outil fait respecter

- **FR-001** — Une machine ne peut pas avoir deux réservations dont les périodes se chevauchent (bornes incluses), quelle que soit l'agence qui saisit.
- **FR-002** — Une nacelle n'est réservable que si sa VGP est valide **sur toute la période** de location ; validité = 6 mois après `derniere_vgp` *(à confirmer, question 1)*. Ex. : NAC089 (VGP 05/03) n'est plus louable ; NAC118 (VGP 15/04) n'est louable que jusqu'au 14/10 inclus.
- **FR-003** — Une machine à l'atelier n'est pas réservable jusqu'à la date indiquée incluse (MINI07 : jusqu'au 20/10).
- **FR-004** — La date de début est ≥ aujourd'hui et la date de fin ≥ date de début.
- **FR-005** — Toute réservation porte : machine, client, du, au, agence de saisie. Client obligatoire.
- **FR-006** — La recherche couvre les 7 agences (Lyon Est, Villeurbanne, Grenoble, Saint-Étienne, Clermont-Ferrand, Annecy, Valence), filtre par type et période, et affiche pour chaque machine indisponible son **motif**.
- **FR-007** — Les réservations existantes (Excel) sont importées telles quelles ; celles qui violent FR-001 sont signalées, pas supprimées.

### Ce que l'outil ne fait pas (cette itération)

Appli pour particuliers, tarifs / devis / facturation, transfert de machines entre agences, gestion de l'atelier et des VGP (saisie), comptes et droits utilisateurs, modification/annulation de réservation *(à confirmer)*.

### Key Entities

- **Agence** : nom (7 valeurs fixes).
- **Machine** : ref, type, agence de rattachement, date de dernière VGP (nacelles), indisponibilité atelier (jusqu'au).
- **Réservation** : machine, client, du, au, agence de saisie.

## Nos 5 tests

1. **Étant donné** NAC112 réservée du 14 au 18/10, **quand** Villeurbanne tente de la réserver du 16 au 17/10, **alors** c'est refusé avec le motif et la réservation existante.
2. **Étant donné** NAC089 (VGP du 05/03/2026), **quand** je cherche une « Nacelle 16 m » du 20 au 31/10, **alors** aucune machine n'est proposée, motif « VGP expirée ».
3. **Étant donné** MINI07 à l'atelier jusqu'au 20/10, **quand** je la réserve du 21 au 23/10, **alors** c'est accepté ; du 19 au 21/10, c'est refusé.
4. **Étant donné** aujourd'hui le 12/10, **quand** je réserve COMP30 du 10 au 11/10 ou du 15 au 13/10, **alors** c'est refusé (dates invalides).
5. **Étant donné** NAC140 réservée du 19 au 23/10, **quand** je réserve NAC140 du 13 au 18/10, **alors** c'est accepté (pas de chevauchement) et visible depuis toutes les agences.

## Success Criteria *(mandatory)*

- **SC-001** — 0 double réservation possible sur une même machine.
- **SC-002** — Une recherche multi-agences donne une réponse en moins de 30 secondes d'utilisation, sans appeler les autres agences.
- **SC-003** — Les 5 tests ci-dessus passent ; Sandrine, Mehdi et Julie réalisent une réservation seuls, sans explication.

## Questions ouvertes pour Brice (2 autorisées)

1. **VGP** : la VGP d'une nacelle est-elle bien valable 6 mois, et doit-elle couvrir toute la durée de location (ou seulement le jour de départ) ?
2. **Réservation inter-agences** : une agence peut-elle réserver une machine rattachée à une autre agence (ex. Lyon Est qui réserve la nacelle de Grenoble), et faut-il prévoir un délai de transfert ?

## Assumptions

- Dates inclusives ; granularité journée.
- `derniere_vgp` vide = machine non soumise à VGP (pas une nacelle).
- Le conflit NAC112 existant est une donnée réelle à arbitrer par l'humain, pas à corriger automatiquement.
