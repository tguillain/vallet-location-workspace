# Journal des ajouts — 001 Réservation multi-agences

Tout ce qui est dans le prototype ou proposé **sans avoir été demandé par Brice**.
Pour chaque ligne, on lui demande : « L'aviez-vous demandé ? Le voulez-vous ? »
Un ajout validé passe dans `spec.md` (règle + test) avant de toucher au prototype.

## A. Ajouts déjà dans le prototype

| # | Ajout | Pourquoi (source) | Spec | Question à Brice |
|---|---|---|---|---|
| A1 | Onglet **VGP nacelles** : liste des nacelles des 7 agences, expirées en tête, compteur + bandeau d'alerte | Le dossier contient une nacelle à VGP expirée (NAC089, depuis le 05/09) et une qui expire le 14/10 (NAC118) | US4, FR-009, test 8 | Voulez-vous cette vue ? Faut-il une alerte « expire bientôt », et à combien de jours ? |
| A2 | Onglet **À traiter** : réservations existantes qui enfreignent une règle, avec leurs motifs, compteur + bandeau | Les Excel contiennent 3 réservations irrégulières : NAC112 en double (BTP Rhone / Maconnerie Duclos, + jour de transfert occupé pour Duclos) et NAC089 réservée par Facades Martin avec une VGP expirée | US5, FR-010, test 9 | Voulez-vous voir ces cas dans l'outil, ou préférez-vous les régler une fois pour toutes à l'import ? |

## B. Ajouts proposés — régler les cas irréguliers

Aujourd'hui l'outil **signale** les cas irréguliers mais ne permet pas de les **régler** (modification et annulation sont hors périmètre). Propositions, de la plus simple à la plus ambitieuse :

| # | Proposition | Cas réglé dans le dossier | Règle à écrire si validée | Test à écrire si validée |
|---|---|---|---|---|
| B1 | **Annuler une réservation** depuis « À traiter » ou le planning, avec un motif obligatoire (« doublon », « VGP expirée »…) et l'agence qui annule. La réservation est conservée comme annulée, pas supprimée. | Doublon NAC112 : on annule l'une des deux | Seule une réservation pas encore commencée peut être annulée ; le motif est obligatoire ; une réservation annulée ne bloque plus la machine | Étant donné le doublon NAC112, quand Lyon Est annule Maconnerie Duclos avec le motif « doublon », alors NAC112 n'apparaît plus dans « À traiter » et reste réservée pour BTP Rhone |
| B2 | **Proposer une machine de remplacement** : pour une réservation à traiter, l'outil cherche une machine du même type libre sur la période (règles VGP, atelier et transfert comprises) | Facades Martin (NAC089, Nacelle 16 m, VGP expirée) → l'outil indique qu'il n'y a aucune autre Nacelle 16 m ; Duclos (NAC112, Nacelle 12 m) → NAC140 (Grenoble) libre le 16-17/10 | La proposition respecte FR-001 à FR-008 ; si aucune machine n'est libre, l'outil le dit | Étant donné Duclos à traiter, quand je demande un remplacement, alors NAC140 est proposée avec un transfert depuis Grenoble le 15/10 |
| B3 | **Réaffecter la réservation** à la machine proposée en un clic, l'ancienne étant libérée | Duclos passe de NAC112 à NAC140 | La réaffectation est refusée si une règle n'est plus respectée au moment du clic | Étant donné NAC140 proposée pour Duclos, quand je réaffecte, alors le doublon NAC112 disparaît et NAC140 est réservée du 16 au 17/10 |
| B4 | **Bloquer automatiquement** une nacelle dont la VGP expire, et marquer « à traiter » toute réservation future qui la concerne | NAC089 : la réservation Facades Martin apparaît d'office | Déjà couvert par FR-002 + FR-010 : rien à ajouter | (test 9 existant) |
| B5 | **Contrôle à l'import des Excel** : rapport des lignes irrégulières au moment de la reprise, avant qu'elles entrent dans l'outil | Les 3 cas ci-dessus, vus dès l'import | L'import ne rejette rien (FR-007) mais produit la liste des lignes irrégulières | Étant donné les 7 réservations Excel, quand on les importe, alors un rapport liste les 3 lignes irrégulières |

## C. Ce qu'on ne propose pas

- **Arbitrer automatiquement un doublon** (garder la première saisie, par exemple) : c'est une décision commerciale, elle reste à l'agence.
- **Supprimer** une réservation : on annule avec un motif, pour garder la trace.
- **Prévenir le client** (mail, SMS) : hors périmètre de cette matinée.

## Ordre conseillé pour Brice

1. Valider ou retirer **A1** et **A2**.
2. Proposer **B1 (annuler)** : c'est le minimum pour régler un doublon, et la spec le note déjà « à confirmer ».
3. Si B1 est validé, proposer **B2 + B3** comme suite logique.
