# Vallet Location Constitution

## Core Principles

### I. Les règles métier vivent dans l'API

Toute règle de réservation (chevauchement, VGP, atelier, transfert, options, bon de
commande, droits d'annulation…) MUST être implémentée et vérifiée dans `back` (Laravel).
`web` (Nuxt) MUST NOT en dupliquer la logique : il affiche les résultats et les motifs
renvoyés par l'API. Une pré-validation d'ergonomie côté web (champ requis, date de fin
recalée) est permise, mais l'API fait foi et revalide tout.

*Pourquoi* : sept agences, une seule vérité. Une règle codée deux fois finit par diverger,
et c'est exactement le problème des fichiers Excel qu'on remplace.

### II. Chaque règle a son test

Chaque exigence `FR-xxx` de la spec MUST être couverte par au moins un test automatisé
(PHPUnit, tier Feature côté `back`). Les tests « Étant donné / Quand / Alors » de `spec.md`
sont les tests d'acceptation et MUST exister sous forme exécutable avant qu'une feature
soit déclarée terminée. Un test rouge bloque la MR.

### III. Conventions Xefi

Le code suit les conventions des plugins Xefi `laravel` et `nuxt` et l'architecture OSDD.
Code, identifiants, noms de tables et de routes MUST être en anglais ; tout texte vu par
l'utilisateur MUST être en français et passer par les traductions, jamais en dur.
Chaque repo enfant MUST avoir son `CLAUDE.md`.

### IV. Le contrat d'API d'abord

Le contrat d'API (endpoints, payloads, codes et messages d'erreur) MUST être figé dans le
`plan.md` de la feature avant toute ligne de code. `back` et `web` développent en parallèle
contre ce contrat. Tout changement de contrat MUST repasser par le plan, jamais être
improvisé dans un seul des deux repos.

### V. Tout en Docker

Chaque repo MUST fournir un `docker-compose` qui permet d'installer, lancer et tester le
projet. Aucun outil autre que Docker et Git MUST être requis sur un poste de développement.

*Pourquoi* : deux développeurs sous Windows, sans PHP ni Node installés ; un environnement
identique pour les deux évite les « ça marche chez moi ».

### VI. La spec est la seule mémoire du projet

Toute nouvelle règle, toute révélation du client MUST d'abord être écrite dans `spec.md`
(règle + test) avant d'atteindre le code. Une correction faite directement dans le code
ou dans une conversation avec l'IA sans passer par la spec est un défaut.

## Stack et environnement

- `back` : Laravel (dernière version stable), PostgreSQL, PHPUnit, Larastan.
- `web` : Nuxt (dernière version stable), consomme uniquement l'API `back`.
- Dates : granularité journée, bornes incluses, fuseau Europe/Paris ; « maintenant » est
  injectable pour que les tests fixent la date (ex. lundi 12/10/2026, 9 h).

## Workflow de développement

- Cycle `feature-cycle` spec-kit : specify → (design) → plan → tasks → implement, avec une
  relecture humaine à chaque étape, puis `/speckit-converge` jusqu'à « Converged ».
- Specs commitées et poussées dans le workspace à la fin de chaque étape.
- Une MR (PR GitHub) par repo, liées par le numéro de feature. `back` est mergé avant `web` ;
  la MR `web` reste ouverte tant que l'endpoint n'est pas sur la branche principale de `back`.

## Governance

Cette constitution prime sur toute autre pratique du projet. Un plan qui la viole MUST le
justifier explicitement dans sa section « Constitution Check », sinon il est refusé.

Amendement : proposition écrite, accord des deux développeurs, mise à jour de ce fichier,
commit dans le workspace. Versionnement sémantique : MAJOR pour un principe retiré ou
redéfini, MINOR pour un principe ou une section ajoutés, PATCH pour une reformulation.

Chaque relecture de plan et de MR vérifie la conformité aux principes I à VI.

**Version**: 1.0.0 | **Ratified**: 2026-10-09 | **Last Amended**: 2026-10-09
