# Feature Specification: Gestion des comptes utilisateurs

**Feature Branch**: `002-gestion-comptes`
**Created**: 2026-10-09
**Status**: Draft
**Input**: « Gestion des comptes : connexion email + mot de passe, un compte = une agence + un rôle (agent, responsable d'agence, administrateur), l'administrateur crée, modifie et désactive les comptes ; l'agence et le rôle du compte remplacent le sélecteur de l'en-tête. »
**Dépend de**: [001-reservation-multi-agences](../001-reservation-multi-agences/spec.md)

## Le problème

Dans la feature 001, n'importe qui choisit son agence et son rôle dans l'en-tête : un agent peut se déclarer « responsable » et annuler la réservation d'une autre agence. La règle FR-015 n'est donc pas réellement protégée, et on ne sait pas qui a fait quoi.

## User Scenarios & Testing *(mandatory)*

> Date de référence : lundi 12 octobre 2026.

### User Story 1 — Se connecter et travailler avec son agence (Priority: P1)

En tant qu'utilisateur d'une agence, je veux me connecter avec mon email et mon mot de passe, afin que l'outil connaisse mon agence et mon rôle sans que je puisse les changer.

**Independent Test** : se connecter avec un compte agent de Lyon Est ; l'en-tête affiche son nom, « Lyon Est » et « Agent », sans sélecteur ; les réservations sont saisies au nom de Lyon Est.

**Acceptance Scenarios**:

1. **Given** le compte agent de Sandrine (Lyon Est), **When** elle se connecte avec le bon mot de passe, **Then** elle arrive sur la recherche, l'en-tête indique « Sandrine — Lyon Est — Agent » et aucun sélecteur d'agence ni de rôle n'existe.
2. **Given** un mauvais mot de passe, **When** elle tente de se connecter, **Then** l'accès est refusé avec un message qui ne dit pas si c'est l'email ou le mot de passe qui est faux.
3. **Given** un visiteur non connecté, **When** il ouvre n'importe quelle page de l'outil, **Then** il est renvoyé vers la page de connexion et ne voit aucune donnée.
4. **Given** Sandrine connectée, **When** elle se déconnecte, **Then** elle revient à la page de connexion et le bouton « Précédent » du navigateur ne réaffiche aucune donnée.

### User Story 2 — Les droits suivent le compte (Priority: P1)

En tant que responsable de Vallet, je veux que les règles de réservation s'appliquent avec l'agence et le rôle du compte connecté, afin qu'un agent ne puisse plus se faire passer pour un responsable.

**Acceptance Scenarios**:

1. **Given** Sandrine connectée (agent, Lyon Est), **When** elle ouvre le planning, **Then** la réservation NAC140 de BTP Rhone (saisie par Grenoble) n'a pas d'action « Annuler », et toute tentative d'annulation est refusée (FR-015 de 001).
2. **Given** Mehdi connecté (responsable d'agence, Villeurbanne), **When** il annule la réservation NAC140 de BTP Rhone (saisie par Grenoble), **Then** l'annulation est acceptée et l'historique indique « annulée par Mehdi (Villeurbanne, responsable) ».
3. **Given** Sandrine connectée, **When** elle réserve COMP30, **Then** la réservation est enregistrée comme saisie par Lyon Est et par Sandrine.

### User Story 3 — L'administrateur gère les comptes (Priority: P1)

En tant qu'administrateur (Brice), je veux créer, modifier et désactiver les comptes, afin de contrôler qui utilise l'outil et avec quels droits.

**Acceptance Scenarios**:

1. **Given** Brice connecté (administrateur), **When** il crée le compte de Julie (email julie@vallet-location.fr, agence Grenoble, rôle agent), **Then** le compte apparaît dans la liste des comptes et Brice obtient un mot de passe provisoire à transmettre à Julie.
2. **Given** Julie qui se connecte pour la première fois avec son mot de passe provisoire, **When** la connexion réussit, **Then** elle doit choisir un nouveau mot de passe avant d'accéder à l'outil.
3. **Given** le compte de Julie, **When** Brice change son agence pour Annecy et son rôle pour responsable d'agence, **Then** à sa prochaine action Julie travaille avec Annecy et les droits de responsable.
4. **Given** le compte de Julie, **When** Brice le désactive, **Then** Julie ne peut plus se connecter, sa session en cours est coupée, et ses réservations passées restent visibles avec son nom.
5. **Given** Sandrine connectée (agent), **When** elle tente d'ouvrir la gestion des comptes, **Then** l'accès lui est refusé et le menu n'apparaît pas.
6. **Given** un email déjà utilisé par un autre compte, **When** Brice crée un compte avec cet email, **Then** la création est refusée.

### Edge Cases

- Le dernier administrateur actif ne peut pas être désactivé ni perdre son rôle d'administrateur.
- Un administrateur ne peut pas se désactiver lui-même.
- Mot de passe oublié : l'administrateur réinitialise le compte et obtient un nouveau mot de passe provisoire.
- Après 5 échecs de connexion consécutifs sur un même compte, les tentatives sont bloquées 15 minutes.
- Un compte désactivé puis réactivé retrouve son agence et son rôle.

## Requirements *(mandatory)*

- **FR-101** — Toute page et toute donnée de l'outil exigent d'être connecté ; un visiteur non connecté est renvoyé vers la page de connexion.
- **FR-102** — La connexion se fait par **email + mot de passe**. Un échec ne précise pas lequel des deux est faux.
- **FR-103** — Chaque compte a : nom, email (unique), **une seule agence** parmi les 7, **un rôle** parmi agent, responsable d'agence, administrateur, et un état actif / désactivé.
- **FR-104** — L'agence et le rôle utilisés par toutes les règles de 001 (saisie, transfert, annulation FR-015…) sont **ceux du compte connecté**. Le sélecteur d'agence et de rôle de l'en-tête disparaît ; l'en-tête affiche le nom, l'agence et le rôle.
- **FR-105** — Un administrateur a, sur les réservations, les mêmes droits qu'un responsable d'agence.
- **FR-106** — Toute réservation garde le compte qui l'a saisie, et toute annulation le compte qui l'a faite, en plus de l'agence.
- **FR-107** — Seul un administrateur voit et utilise la gestion des comptes : lister, créer, modifier (nom, email, agence, rôle), désactiver, réactiver, réinitialiser le mot de passe.
- **FR-108** — La création et la réinitialisation produisent un **mot de passe provisoire** affiché une seule fois à l'administrateur ; à la connexion suivante, l'utilisateur doit en choisir un nouveau avant toute autre action.
- **FR-109** — Un mot de passe fait au moins 12 caractères.
- **FR-110** — Un compte désactivé ne peut plus se connecter et ses sessions ouvertes sont coupées immédiatement ; ses données (réservations saisies, annulations) restent intactes et lisibles.
- **FR-111** — Le dernier administrateur actif ne peut être ni désactivé ni rétrogradé ; un administrateur ne peut pas se désactiver lui-même.
- **FR-112** — Après 5 échecs de connexion consécutifs pour un même email, les tentatives sont bloquées 15 minutes.
- **FR-113** — Un utilisateur connecté peut se déconnecter ; après déconnexion, aucune donnée n'est accessible sans nouvelle connexion.
- **FR-114** — Un premier compte administrateur est créé à l'installation de l'outil (pour Brice Vallet).

### Ce que la feature ne fait pas

Connexion par SSO, envoi d'emails (invitation, mot de passe oublié en libre-service), double authentification, un compte rattaché à plusieurs agences, journal d'audit complet au-delà de FR-106.

### Key Entities

- **Compte utilisateur** : nom, email, mot de passe, agence (une), rôle (agent / responsable d'agence / administrateur), actif ou désactivé, mot de passe provisoire à changer (oui/non).
- **Réservation** (001) : gagne le compte qui l'a saisie et le compte qui l'a annulée.

## Nos tests

1. **Étant donné** le compte agent de Sandrine (Lyon Est), **quand** elle se connecte, **alors** l'en-tête affiche « Sandrine — Lyon Est — Agent » sans sélecteur.
2. **Étant donné** un mauvais mot de passe, **quand** on se connecte, **alors** c'est refusé avec « Email ou mot de passe incorrect ».
3. **Étant donné** un visiteur non connecté, **quand** il ouvre le planning, **alors** il est renvoyé à la connexion sans voir de donnée.
4. **Étant donné** Sandrine connectée (agent, Lyon Est), **quand** elle tente d'annuler NAC140 BTP Rhone (Grenoble), **alors** c'est refusé et l'action n'est pas proposée.
5. **Étant donné** Mehdi (responsable, Villeurbanne), **quand** il annule NAC140 BTP Rhone, **alors** c'est accepté et l'annulation porte son nom.
6. **Étant donné** Brice (administrateur), **quand** il crée Julie (Grenoble, agent), **alors** un mot de passe provisoire s'affiche une fois, et Julie doit le changer à sa première connexion.
7. **Étant donné** Julie connectée, **quand** Brice désactive son compte, **alors** sa prochaine action la renvoie à la connexion et elle ne peut plus se connecter.
8. **Étant donné** Brice seul administrateur, **quand** il tente de se rétrograder ou de se désactiver, **alors** c'est refusé.
9. **Étant donné** Sandrine (agent), **quand** elle ouvre la gestion des comptes, **alors** l'accès est refusé.
10. **Étant donné** 5 mauvais mots de passe d'affilée pour Sandrine, **quand** elle tente une 6e fois avec le bon, **alors** c'est bloqué pendant 15 minutes.

## Success Criteria *(mandatory)*

- **SC-101** — 0 action possible sur l'outil sans être connecté.
- **SC-102** — 0 annulation d'une réservation d'une autre agence par un compte agent.
- **SC-103** — Un administrateur crée un compte prêt à l'emploi en moins de 1 minute.
- **SC-104** — Un utilisateur se connecte en moins de 15 secondes.
- **SC-105** — Pour toute réservation et toute annulation, on sait quel compte l'a faite.

## Assumptions

- L'administrateur appartient lui aussi à une agence (Brice : Lyon Est), qui sert d'agence de saisie s'il réserve.
- Les réservations reprises des Excel (001) n'ont pas de compte de saisie, seulement l'agence.
- Les comptes de démo (Sandrine, Mehdi, Julie, Brice) sont créés par les données initiales ; leurs agences et rôles sont à confirmer avec Brice.
- Pas d'email envoyé : l'administrateur transmet lui-même le mot de passe provisoire.
