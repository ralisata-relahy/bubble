# Audit technique de Bubble

**Date :** 26 octobre 2026

**Périmètre :** état du worktree observé à cette date, application Flutter/Flame, configuration Android, assets, tests et documentation. Cet audit décrit l'état existant ; il ne modifie ni le code applicatif ni les assets.

## Synthèse

L'application est organisée par fonctionnalités et possède déjà des composants isolés pour la physique, la trajectoire laser et la sélection de questions. L'analyse statique, les 35 tests automatisés et le build Android debug réussissent.

Les principaux risques identifiés sont la configuration Android non publiable en l'état (identifiant générique et signature debug), les fichiers audio de prononciation référencés mais absents, et une invalidation incomplète du rendu d'un widget de bulle. Plusieurs fichiers concentrent aussi beaucoup de responsabilités. Aucun audit de sécurité dédié, profilage de performance ou build iOS n'a été réalisé.

## État et éléments vérifiés

- 49 fichiers Dart sous `lib/` et 5 fichiers de test sous `test/`.
- `flutter analyze` : aucun problème signalé.
- `flutter test` : 35 tests réussis.
- `flutter build apk --debug` : réussi (`build/app/outputs/flutter-apk/app-debug.apk`).
- La permission Android `VIBRATE`, absente du manifeste de l'application, est ajoutée par le manifeste fusionné du plugin `vibration` et figure dans le manifeste APK debug.
- Les 16 entrées de ressources déclarées dans `pubspec.yaml` existent.
- Le worktree n'était pas propre lors de l'audit. Six suppressions de fichiers texte à la racine (`bubble_agent.txt`, `bubble_base.txt`, `bubble_game_agent.txt`, `bubble_game_base.txt`, `bubble_game_win.txt`, `bubble_win.txt`) étaient déjà présentes ; elles ont été préservées et ne sont pas traitées comme du code applicatif.

## Constats priorisés

### P1 — Préparation à la publication Android

**Fichiers :** [android/app/build.gradle.kts](android/app/build.gradle.kts)

`applicationId` est toujours `com.example.bubble`, et la configuration `release` signe avec la clé debug. Le build debug ne valide donc pas la possibilité de publier une version release sûre et identifiable. Avant publication, définir l'identifiant Android final et configurer une clé de signature release gérée hors du dépôt. Ne pas enregistrer de secrets de signature dans les sources.

### P1 — Prononciations absentes pour la majorité des questions

**Fichiers :** [lib/features/game/data/game_questions.dart](lib/features/game/data/game_questions.dart), [lib/features/game/presentation/bubble_game.dart](lib/features/game/presentation/bubble_game.dart), [pubspec.yaml](pubspec.yaml)

Le catalogue contient 22 références `nameAudio`. Trois fichiers sont présents au chemin attendu et déclarés (`bonjour.mp3`, `aurevoir.mp3`, `french/thank_you_fr.mp3`) ; les 19 autres n'existent pas dans les assets et ne sont pas déclarés. La lecture échoue alors pour ces questions ; l'erreur est interceptée et écrite via `debugPrint`, sans interrompre la partie. Les références sont conservées dans le catalogue, conformément à la décision de ne pas fabriquer les fichiers manquants.

**Action recommandée :** fournir les fichiers audio manquants ou définir une stratégie de contenu explicitement optionnelle, puis automatiser la vérification des chemins référencés par le catalogue.

### P2 — `BubblePainter.shouldRepaint` ignore deux propriétés visuelles

**Fichier :** [lib/features/bubble/presentation/widgets/bubble_widget.dart](lib/features/bubble/presentation/widgets/bubble_widget.dart)

`BubblePainter` reçoit `maxLines` et `autoFit`, mais `shouldRepaint` ne compare que `style`, `text` et `textColor`. Si seules les options de mise en page changent, Flutter peut réutiliser le rendu précédent au lieu de repeindre le texte selon les nouvelles options.

**Action recommandée :** inclure `maxLines` et `autoFit` dans la comparaison et ajouter un test ciblant leur modification isolée.

### P2 — Responsabilités concentrées dans de grands fichiers

**Fichiers :** [lib/features/game/presentation/bubble_game.dart](lib/features/game/presentation/bubble_game.dart), [lib/features/bubble/presentation/components/bubble.dart](lib/features/bubble/presentation/components/bubble.dart), [lib/features/curio/character_backup_painter.dart](lib/features/curio/character_backup_painter.dart)

Dans le worktree mesuré, ces fichiers font respectivement 684, 830 et 1 178 lignes. `BubbleGame` coordonne notamment la boucle Flame, les manches, les entrées, les collisions, l'audio et le cycle de vie ; `Bubble` cumule déplacement, états, interaction laser, collision et rendu. Cette concentration augmente le coût des changements et rend les tests isolés plus difficiles.

**Action recommandée :** poursuivre les extractions incrémentales déjà amorcées — par exemple, séparer les services de cycle de manche et les comportements de bulle — en conservant les contrats existants et en ajoutant des tests aux frontières extraites. Éviter une réécriture globale.

### P2 — Coût d'initialisation audio à mesurer

**Fichiers :** [lib/main.dart](lib/main.dart), [lib/core/services/audio/sound_effect.dart](lib/core/services/audio/sound_effect.dart), [lib/core/services/audio/game_audio.dart](lib/core/services/audio/game_audio.dart)

`main()` attend `SoundEffects.init()` avant `runApp()`. Sans paramètre `only`, le service construit les données de tous les 23 effets de `Sfx` avant de créer la fenêtre de l'application. Le registre contient aussi une boucle procédurale de huit mesures à 132 BPM, soit environ 14,5 secondes de contenu audio. Ce travail synchrone de génération avant le premier affichage est un risque de démarrage ; aucun profilage n'a établi son impact réel sur les appareils cibles.

**Action recommandée :** mesurer le temps jusqu'au premier affichage et le coût mémoire sur appareil. Si le coût est significatif, envisager un chargement différé ou une génération hors du chemin critique de démarrage, avec mesure avant/après.

### P2 — Couverture automatisée centrée sur des unités

**Fichiers :** [test/](test/)

Les 35 tests couvrent notamment les collisions, les trajectoires, les bulles et la jauge, le tirage des questions et la disposition de 1 à 21 bulles sur trois formats d'écran. Ils ne constituent pas un test de parcours complet du jeu : les interactions entre progression, redémarrage, lecture réelle des assets audio et cycle de vie des overlays ne sont pas couvertes de bout en bout.

**Action recommandée :** ajouter des tests d'intégration ciblés sur le parcours d'une manche, le redémarrage et la résolution des assets audio, sans remplacer les tests unitaires rapides existants.

### P3 — Documentation d'architecture en décalage

**Fichiers :** [STRUCTURE.md](STRUCTURE.md), [PROJECT_STRUCTURE.txt](PROJECT_STRUCTURE.txt), [lib/core/services/audio/README.md](lib/core/services/audio/README.md)

La documentation `STRUCTURE.md` présente encore `sound_effect.dart` comme reposant sur SoLoud, alors que l'implémentation active utilise `audioplayers` ; SoLoud est limité à `sound_effect_old.dart`, décrit comme historique et inutilisé dans le README audio. Les arbres de fichiers ne mentionnent pas non plus les composants récents `GameQuestionDeck` et `KnowledgeBubbleScatter`, ni les tests qui leur correspondent.

**Action recommandée :** mettre à jour les arbres et descriptions lors de la prochaine évolution documentaire afin qu'ils reflètent le code actif, en distinguant clairement l'implémentation historique.

### P3 — Dépendances candidates au nettoyage

**Fichier :** [pubspec.yaml](pubspec.yaml)

`flutter_soloud` n'est importé que par `sound_effect_old.dart`, que la documentation identifie comme inutilisé par l'application. Aucun usage de `cupertino_icons`/`CupertinoIcons` n'a été trouvé dans `lib/` ou `test/`. Ce sont des candidates, pas des suppressions effectuées dans le cadre de cet audit.

**Action recommandée :** confirmer les usages dans les plateformes et outils du projet avant toute suppression, puis retirer ces dépendances et leur code historique dans un changement dédié si elles sont effectivement inutiles.

## Observations à surveiller

- Le calcul de collisions parcourt les paires de bulles actives, en O(n²), dans [lib/features/game/presentation/bubble_game.dart](lib/features/game/presentation/bubble_game.dart). Le nombre courant de bulles n'a pas été associé à un problème mesuré ; réévaluer si le volume augmente ou si un profilage révèle un coût.
- Les chemins des prononciations échouées sont consignés avec `debugPrint`. Les références restent présentes et aucun fichier audio n'a été créé artificiellement.
- La permission de vibration fonctionne dans l'artefact Android debug grâce à la fusion de manifestes ; une déclaration explicite dans le manifeste applicatif n'est pas nécessaire pour le résultat vérifié.

## Limites de l'audit

- Pas d'audit de sécurité formel ni d'analyse dédiée des menaces ou des dépendances.
- Pas de profilage CPU, mémoire, temps de démarrage ou fluidité sur appareils représentatifs.
- Pas de build ou de validation d'exécution iOS.
- Le build Android réalisé est un build debug ; aucune publication release n'a été tentée.
- L'audit porte sur le worktree local, qui contenait des changements et suppressions préexistants ; il ne constitue pas une comparaison exhaustive avec une version de production.

## Ordre de traitement recommandé

1. Configurer l'identifiant et la signature Android destinés à la publication.
2. Décider de la disponibilité attendue des 19 prononciations manquantes et ajouter un contrôle automatisé des assets.
3. Corriger l'invalidation du peintre et tester les changements de `maxLines` et `autoFit`.
4. Ajouter des tests d'intégration du parcours d'une manche et du redémarrage.
5. Mesurer le démarrage audio, puis refactoriser uniquement si les mesures le justifient.
6. Actualiser la documentation d'architecture et examiner les dépendances candidates.

## Architecture follow-up (2026-10-26)

This follow-up records the module changes made after the audit snapshot:

- Gameplay tuning values now live in `lib/features/game/configuration/game_configuration.dart`.
- Question selection has a module in `features/game/domain`; collision handling is a presentation system, and knowledge scatter is a Flame component.
- Question pronunciation playback lives in `features/game/services/game_audio_service.dart`.
- Shared generated audio and optional vibration adapters live under `core/services`; Curio mood voices are isolated in `features/curio/services`.
- Bubble presentation delegates device vibration to the haptics service; the game coordinator delegates question audio and collision passes.
- `STRUCTURE.md` and `PROJECT_STRUCTURE.txt` now match the current source layout.

Static analysis, tests, and builds were not rerun for this follow-up. The Android publishing configuration, missing pronunciation assets, painter invalidation issue, and integration coverage findings remain open.
