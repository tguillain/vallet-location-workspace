# Feature Specification: Recherche et réservation de machines sur les 7 agences

**Feature Branch**: `001-reservation-multi-agences`
**Created**: 2026-10-09
**Status**: Validée (réponses de Brice intégrées le 2026-10-09)
**Input**: Consignes « Vallet Location — Du besoin au prototype » (9 oct. 2026) + extrait du parc et des réservations (`data/`)
**Prototype (étape 2)**: https://claude.ai/artifact/RqxVXrCi35rcK5dASeB1sP

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

### User Story 4 — Voir les nacelles dont la VGP n’est pas à jour (Priority: P2)

En tant que responsable d’agence ou directeur, je veux voir d’un coup d’œil les nacelles des 7 agences dont la VGP est expirée, afin de les faire contrôler avant qu’un client les demande.

**Acceptance Scenarios**:

1. **Given** on est le 12/10/2026, **When** j’ouvre la vue VGP, **Then** NAC089 (Lyon Est) apparaît en tête comme « VGP expirée depuis le 05/09 », puis les nacelles à jour avec leur date de fin de validité, la plus proche d’abord (NAC118 : jusqu’au 14/10).

### User Story 5 — Voir les réservations à traiter (Priority: P2)

En tant que responsable d’agence ou directeur, je veux voir dans un seul onglet les réservations existantes qui enfreignent une règle, afin de les arbitrer avant que la machine parte chez le client.

**Acceptance Scenarios**:

1. **Given** les réservations reprises des Excel, **When** j’ouvre l’onglet « À traiter », **Then** je vois NAC112 BTP Rhone et NAC112 Maconnerie Duclos (double réservation ; pour Duclos, en plus, jour de transfert du 15/10 occupé) et NAC089 Facades Martin (VGP expirée), chacune avec son ou ses motifs.

### Edge Cases

- Réservation d'un seul jour (du = au) : valide (cf. COMP21 le 12/10).
- Réservation qui touche une autre bout à bout (fin le 18, début le 19) : autorisée — les dates sont **inclusives**.
- Date de fin avant date de début, ou date de début passée : refusée.
- Réservation en cours aujourd'hui (ECH40 du 06 au 24/10) : bloque la machine.

## Requirements *(mandatory)*

### Les règles que l'outil fait respecter

- **FR-001** — Une machine ne peut pas avoir deux réservations dont les périodes se chevauchent (bornes incluses), quelle que soit l'agence qui saisit.
- **FR-002** — Une nacelle ne peut pas être louée si sa VGP expire pendant la location : la VGP doit être valide jusqu'au dernier jour inclus. Validité = 6 mois après `derniere_vgp`. Ex. : NAC089 (VGP 05/03) n'est plus louable ; NAC118 (VGP 15/04, valide jusqu'au 14/10) n'est louable que sur une période finissant au plus tard le 14/10.
- **FR-003** — Une machine à l'atelier n'est pas réservable jusqu'à la date indiquée incluse (MINI07 : jusqu'au 20/10).
- **FR-004** — La date de début est ≥ aujourd’hui et la date de fin ≥ date de début. Si l’utilisateur choisit une date de début postérieure à la date de fin, la date de fin prend automatiquement la valeur de la date de début.
- **FR-005** — Toute réservation porte : machine, client, du, au, agence de saisie. Client obligatoire.
- **FR-006** — La recherche couvre les 7 agences (Lyon Est, Villeurbanne, Grenoble, Saint-Étienne, Clermont-Ferrand, Annecy, Valence), filtre par type **ou par référence** de machine (référence partielle acceptée, majuscules/minuscules indifférentes ; une référence saisie prime sur le type) et par période, et affiche pour chaque machine indisponible son **motif**.
- **FR-007** — Les réservations existantes (Excel) sont importées telles quelles ; celles qui violent FR-001 sont signalées, pas supprimées.
- **FR-008** — Une agence peut réserver une machine rattachée à une autre agence. La machine voyage une demi-journée : elle doit être **libre la veille du départ** (ni réservée, ni à l’atelier), et cette veille ne peut pas être passée — la location commence donc au plus tôt demain. Si l’agence qui réserve est celle de la machine, aucun délai. *(Confirmé par Brice, révélation 1.)*
- **FR-009** — Une vue liste toutes les nacelles des 7 agences avec leur agence, leur dernière VGP, leur date de fin de validité et leur état : **expirée** ou **à jour**. Les expirées sont en tête, puis les autres par date de fin de validité croissante. Le nombre de nacelles expirées est visible depuis l’accueil.
- **FR-010** — Un onglet « À traiter » liste chaque réservation existante qui enfreint au moins une règle, avec ses motifs : double réservation (FR-001), VGP expirée ou qui expire pendant la location (FR-002), machine à l’atelier pendant la location (FR-003), jour de transfert occupé pour une réservation inter-agences qui n’a pas encore commencé (FR-008). Les dates passées (FR-004) ne sont pas un problème pour une réservation déjà en cours. L’outil signale, il ne modifie ni ne supprime rien. Le nombre de réservations à traiter est visible depuis l’accueil.
- **FR-011** — Une nacelle dont la VGP expire **moins de 30 jours après la fin de la location** reste réservable mais est signalée dans la recherche (« VGP à refaire le JJ/MM »). Dans l’onglet VGP, une nacelle dont la VGP expire dans moins de 30 jours à compter d’aujourd’hui est signalée « expire bientôt ».
- **FR-012** — Une réservation pour un **client grand compte** n’est valable qu’avec un **numéro de bon de commande** : sans lui, la réservation est refusée. L’agent indique à la saisie si le client est grand compte. *(Révélation 2.)*
- **FR-013** — Au retour, une machine est nettoyée et contrôlée : **elle ne peut pas être relouée le jour de son retour** (le dernier jour de location). Une location peut commencer au plus tôt le lendemain du retour. *(Révélation 3 — déjà garanti par FR-001, bornes incluses.)*
- **FR-014** — Une réservation peut être saisie comme **option** : le client a **48 h** pour confirmer. Tant qu’elle n’est pas expirée, une option bloque la machine comme une réservation ferme. Confirmée, elle devient ferme ; non confirmée au bout de 48 h, elle **saute** automatiquement et ne bloque plus la machine. Les réservations reprises des Excel sont fermes. *(Révélation 4.)*
- **FR-015** — Une réservation qui n’a pas commencé peut être **annulée** ; elle reste visible comme annulée et ne bloque plus la machine. Un agent peut annuler une réservation saisie par **son** agence ; une réservation saisie par **une autre agence** ne peut être annulée **que par un responsable d’agence**. *(Révélation 5.)*

### Ce que l'outil ne fait pas (cette itération)

Appli pour particuliers, tarifs / devis / facturation, organisation logistique du transfert (camion, chauffeur), gestion de l’atelier et des VGP (saisie), authentification (le prototype choisit l’agence et le rôle dans l’en-tête), modification d’une réservation (seule l’annulation est possible).

### Key Entities

- **Agence** : nom (7 valeurs fixes).
- **Machine** : ref, type, agence de rattachement, date de dernière VGP (nacelles), indisponibilité atelier (jusqu'au).
- **Réservation** : machine, client, du, au, agence de saisie, statut (option / ferme / annulée), échéance de l’option, client grand compte (oui/non), numéro de bon de commande.
- **Utilisateur** : agence, rôle (agent / responsable d’agence).

## Nos tests

1. **Étant donné** NAC112 réservée du 14 au 18/10, **quand** Villeurbanne tente de la réserver du 16 au 17/10, **alors** c'est refusé avec le motif et la réservation existante.
2. **Étant donné** NAC089 (VGP du 05/03/2026), **quand** je cherche une « Nacelle 16 m » du 20 au 31/10, **alors** aucune machine n'est proposée, motif « VGP expirée ».
3. **Étant donné** MINI07 à l'atelier jusqu'au 20/10, **quand** je la réserve du 21 au 23/10, **alors** c'est accepté ; du 19 au 21/10, c'est refusé.
4. **Étant donné** aujourd’hui le 12/10, **quand** je réserve COMP30 du 10 au 11/10, **alors** c’est refusé (date passée) ; **quand** la fin est au 15/10 et que je choisis un début au 18/10, **alors** la fin passe automatiquement au 18/10.
5. **Étant donné** NAC140 réservée du 19 au 23/10, **quand** je réserve NAC140 du 13 au 18/10, **alors** c'est accepté (pas de chevauchement) et visible depuis toutes les agences.
6. **Étant donné** NAC140 (rattachée à Grenoble) réservée du 19 au 23/10, **quand** Lyon Est la réserve du 24 au 26/10, **alors** c'est refusé (le 23/10, jour de transfert, est occupé) ; du 13 au 17/10, c'est accepté ; à partir du 12/10 (aujourd'hui), c'est refusé (pas le temps de transférer).
7. **Étant donné** NAC118 (VGP valide jusqu'au 14/10), **quand** Annecy la réserve du 13 au 16/10, **alors** c'est refusé (VGP expirée pendant la location) ; du 13 au 14/10, c'est accepté.
8. **Étant donné** aujourd’hui le 12/10, **quand** j’ouvre la vue VGP, **alors** NAC089 est la seule nacelle expirée et apparaît en premier ; NAC118 suit, à jour jusqu’au 14/10.
9. **Étant donné** les réservations reprises des Excel, **quand** j’ouvre « À traiter », **alors** 3 réservations apparaissent : NAC112 BTP Rhone (double réservation), NAC112 Maconnerie Duclos (double réservation + jour de transfert 15/10 occupé), NAC089 Facades Martin (VGP expirée depuis le 05/09) ; COMP21, ECH40, NAC140 et MINI12 n’y sont pas.
10. **Étant donné** la recherche, **quand** je saisis « nac1 » du 13 au 14/10, **alors** NAC112, NAC140 et NAC118 sont listées (quel que soit le type choisi) avec leur disponibilité.
11. **Étant donné** NAC118 (VGP valable jusqu’au 14/10), **quand** je cherche une Nacelle 12 m du 13 au 14/10, **alors** NAC118 est disponible mais signalée « VGP à refaire le 14/10 » ; dans l’onglet VGP elle est « expire bientôt ».
12. **Étant donné** un client grand compte, **quand** je réserve COMP30 du 13 au 15/10 sans numéro de bon de commande, **alors** c’est refusé ; avec le numéro « BC-2026-118 », c’est accepté et le numéro est affiché dans le planning.
13. **Étant donné** NAC140 réservée du 19 au 23/10 (retour le 23), **quand** Grenoble la réserve à partir du 23/10, **alors** c’est refusé ; à partir du 24/10, c’est accepté.
14. **Étant donné** le 12/10 à 9 h, **quand** je réserve COMP30 du 13 au 15/10 en option, **alors** elle apparaît « Option — à confirmer avant le 14/10 9 h » et COMP30 n’est plus proposée sur ces dates ; quand je la confirme, elle devient ferme ; une option non confirmée après le 14/10 9 h ne bloque plus la machine.
15. **Étant donné** Lyon Est connecté en agent, **quand** j’annule la réservation NAC140 de BTP Rhone (saisie par Grenoble), **alors** c’est refusé (« réservée au responsable d’agence ») ; en responsable d’agence, c’est accepté et NAC140 redevient disponible du 19 au 23/10.
16. **Étant donné** Lyon Est connecté en agent, **quand** j’annule la réservation NAC089 de Facades Martin (saisie par Lyon Est), **alors** c’est accepté et elle disparaît de « À traiter ».

## Success Criteria *(mandatory)*

- **SC-001** — 0 double réservation possible sur une même machine.
- **SC-002** — Une recherche multi-agences donne une réponse en moins de 30 secondes d'utilisation, sans appeler les autres agences.
- **SC-003** — Les 16 tests ci-dessus passent ; Sandrine, Mehdi et Julie réalisent une réservation seuls, sans explication.

## Révélations de Brice (recette du 2026-10-12)

1. Une machine d’une autre agence voyage une demi-journée : libre la veille du départ → FR-008 (déjà couvert), test 6.
2. Grand compte = numéro de bon de commande obligatoire → FR-012, test 12.
3. Pas de relocation le jour du retour (nettoyage, contrôle) → FR-013, test 13.
4. Options : 48 h pour confirmer, sinon elles sautent → FR-014, test 14.
5. Seul le responsable d’agence annule une réservation saisie par une autre agence → FR-015, tests 15-16.

### Questions ouvertes

- Comment sait-on qu’un client est grand compte (liste fournie, ou case cochée à la saisie comme dans le prototype) ?
- Les 48 h d’une option courent-elles depuis la saisie (hypothèse retenue) ?
- « Responsable d’agence » : n’importe quel responsable, ou celui de l’agence de la machine (hypothèse retenue : n’importe quel responsable) ?

## Réponses de Brice (2026-10-09)

1. **VGP** : une nacelle ne peut pas être louée si sa VGP se termine pendant la location → FR-002, test 7.
2. **Inter-agences** : autorisé, avec 1 journée de délai de transfert → FR-008, test 6.

## Assumptions

- Dates inclusives ; granularité journée.
- `derniere_vgp` vide = machine non soumise à VGP (pas une nacelle).
- La VGP des nacelles est valable 6 mois (périodicité réglementaire des appareils de levage de personnes) ; Brice a confirmé la règle, pas la durée.
- Le conflit NAC112 existant est une donnée réelle à arbitrer par l'humain, pas à corriger automatiquement.
