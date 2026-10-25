# Architecture et Structure du Projet Bubble

Ce document detaille l'organisation de l'arborescence, les responsabilites de chaque fichier et module, ainsi que les choix d'architecture logicielle retenus.

---

## 1. Vue d'Ensemble de l'Architecture

Le projet repose sur le framework Flutter et le moteur de jeu 2D Flame. L'architecture suit une organisation modulaire orientee fonctionnalites (feature-first) avec un noyau transverse partage (core).

### Couches architecturales
- **Core** : Contrats d'interfaces, physique transverse et composants graphiques generiques.
- **Features** : Modules fonctionnels autonomes (bulles, mascotte Curio, logique de partie, mascotte Edutainer).
- **Audio Generation** : Synthese et lecture des effets sonores proceduraux via SoLoud et audio pre-enregistre via AudioPlayers.
- **Test** : Tests unitaires cibles sur la typographie responsive, le ciblage laser et la dynamique de collision.

---

## 2. Arborescence Detaillee des Fichiers

```text
bubble/
|-- android/                         # Configuration et runner de la plateforme Android
|-- assets/                          # Ressources statiques (audio, images)
|   |-- audio/                       # Fichiers audio WAV/MP3 pour Curio
|   |-- images/                      # Arriere-plans spatiaux et aquatiques
|-- ios/                             # Configuration et runner iOS
|-- lib/                             # Code source Dart de l'application
|   |-- main.dart                    # Point d'entree, configuration plein ecran et liaison Flame
|   |
|   |-- audio_generation/            # Module audio
|   |   |-- README.md                # Documentation des signatures sonores procedurales
|   |   |-- sfx_generate.dart        # Synthese en memoire des ondes sonores (PCM/WAV)
|   |   |-- sound_effect.dart        # Gestionnaire de lecture et chargement des effets via SoLoud
|   |   |-- sound_sfx.dart           # Facade d'export simplifiee
|   |
|   |-- core/                        # Noyau transverse et contrats
|   |   |-- contracts/
|   |   |   |-- knowledge_bubble_host.dart # Contrat de coordination pour les bulles et l'hote
|   |   |   |-- laser_target.dart          # Interface des entites pouvant interagir avec le laser
|   |   |-- physics/
|   |   |   |-- bubble_collision_resolver.dart # Moteur physique de rebond elastique et continuite
|   |   |-- presentation/
|   |       |-- widgets/
|   |           |-- space_background.dart      # Fond spatial etoile optimise avec RepaintBoundary
|   |
|   |-- features/
|   |   |-- ai_buddy/                # Mascotte Edutainer (tireur laser au bas de l'ecran)
|   |   |   |-- edutainer.dart       # Exports du module
|   |   |   |-- models/
|   |   |   |   |-- character_pose.dart # Parametres d'animation, posture et expressions
|   |   |   |   |-- saucePalette.dart   # Palette chromatique de la soucoupe et de la lueur
|   |   |   |-- painter/             # Peintres vectoriels modulaires
|   |   |   |   |-- arms_painter.dart
|   |   |   |   |-- body_painter.dart
|   |   |   |   |-- edutainer_context.dart
|   |   |   |   |-- eye_painter.dart
|   |   |   |   |-- ground_painter.dart
|   |   |   |   |-- laser_painter.dart
|   |   |   |   |-- mouth_painter.dart
|   |   |   |   |-- paint_utils.dart
|   |   |   |   |-- saucer_painter.dart
|   |   |   |-- widgets/
|   |   |       |-- edutainer_painter.dart   # Assemblage CustomPainter du personnage
|   |   |       |-- edutainment_character.dart # Widget Flutter pour rendu autonome
|   |   |
|   |   |-- bubble/                  # Entites et rendu des bulles
|   |   |   |-- models/
|   |   |   |   |-- bubble_config.dart # Configuration cinematique (vitesse, onde, style)
|   |   |   |   |-- bubble_style.dart  # Style graphique (forme, degradé, reflets, anneaux)
|   |   |   |-- presentation/
|   |   |       |-- components/
|   |   |       |   |-- bubble.dart        # Composant Flame principal de bulle flottante
|   |   |       |   |-- bubble_label.dart  # Label textuel avec mise a l'echelle automatique
|   |   |       |-- rendering/
|   |   |       |   |-- bubble_renderer.dart    # Interface abstraite de rendu
|   |   |       |   |-- bubble_text_helper.dart # Calcul responsive et ajustement de boite
|   |   |       |   |-- sphere_renderer.dart    # Rendu vectoriel spherique et iridescence
|   |   |       |-- widgets/
|   |   |           |-- bubble_widget.dart      # Widget Flutter pur pour affichage hors-jeu
|   |   |           |-- knowledge_bubble.dart   # Bulle secondaire de savoir jaillissant a la victoire
|   |   |
|   |   |-- curio/                   # Mascotte Curio et jauge de temps
|   |   |   |-- character_backup_painter.dart # Dessin vectoriel reactif a l'humeur
|   |   |   |-- character_backup_widget.dart  # Animation et synchronisation sonore de l'humeur
|   |   |   |-- presentation/
|   |   |       |-- widgets/
|   |   |           |-- character_time_gauge.dart # Jauge a tube de verre et niveau d'energie
|   |   |           |-- curio_timer.dart          # Overlay Flutter avec alerte neon perimetrique
|   |   |
|   |   |-- game/                    # Logique metier et boucle de jeu
|   |       |-- data/
|   |       |   |-- game_questions.dart       # Catalogue des questions et reponses
|   |       |-- domain/
|   |       |   |-- models/
|   |       |       |-- game_question.dart    # Modele immuable d'une question de jeu
|   |       |-- presentation/
|   |           |-- bubble_game.dart          # Coordonnateur central Flame (FlameGame)
|   |           |-- components/
|   |               |-- laser_beam.dart       # Faisceau laser dynamique et detection d'impact
|   |               |-- laser_label_box.dart  # Panneau d'affichage HUD technologique avec cache
|   |
|   |-- test/
|       |-- bubble_collision_test.dart        # Tests de la physique et des rebonds
|       |-- widget_test.dart                  # Tests de conformite du ciblage laser et du texte
|-- pubspec.yaml                             # Dependances et declarations d'assets
|-- STRUCTURE.md                             # Documentation d'architecture du projet
```

---

## 3. Description des Modules et Responsabilites

### 3.1 Point d'Entree (`lib/main.dart`)
- Initialise les liaisons du framework Flutter (`WidgetsFlutterBinding.ensureInitialized`).
- Active le plein ecran immersif sans barre systeme (`SystemChrome.setEnabledSystemUIMode`).
- Charge en memoire la synthese audio procedurale (`SoundEffects.init`).
- Instancie le jeu Flame `BubbleGame` et le monte au sein du composant Flutter `GameWidget` avec l'overlay Curio.
- Encapsule le tout dans un fond spatial etoile `SpaceBackground`.

### 3.2 Noyau Transverse (`lib/core/`)
- **`contracts/laser_target.dart`** :
  Definit le contrat `LaserTarget` que toute entite ciblable par le faisceau laser doit implementer (`containsLaserPoint`, `onLaserHit`, `canReceiveLaserHit`).
- **`contracts/knowledge_bubble_host.dart`** :
  Permet aux composants bulles d'acceder aux informations d'etat global du jeu (etat de freeze, temps ecoule, position de respawn).
- **`physics/bubble_collision_resolver.dart`** :
  Module de calcul physique applique aux instances de `BubblePhysicsBody`. Resout les chevauchements en proportion des masses (rayon au carre), effectue un transfert d'impulsion elastique (restitution = 1.0) et preserve la continuite spatiale de la trajectoire oscillatoire pour eviter toute saccade visuelle.
- **`presentation/widgets/space_background.dart`** :
  Affiche un ciel spatial etoile fixe genere par graine pseudo-aleatoire, protege par un `RepaintBoundary` afin de ne jamais redessiner le fond lors des animations du jeu.

### 3.3 Module Bulle (`lib/features/bubble/`)
- **`models/bubble_config.dart` & `bubble_style.dart`** :
  Modeles definissant les proprietes physiques (vitesse, vecteur directeur, amplitude et frequence de l'onde) et esthetiques (couleur de base, anneau, reflets en arc `ArcStyle`, points de brillance `SpotStyle`).
- **`presentation/components/bubble.dart`** :
  Composant Flame principal. Implemente `LaserTarget` et `BubblePhysicsBody`. Gere la trajectoire ondulatoire, l'echauffement sous le laser, l'explosion particulaire et le respawn sur les bords de l'ecran.
- **`presentation/widgets/knowledge_bubble.dart`** :
  Composant Flame secondaire pour les bulles de notions emises apres une bonne reponse. Partage le meme solveur de collision et le meme moteur de rendu que la bulle principale.
- **`presentation/rendering/bubble_renderer.dart` & `sphere_renderer.dart`** :
  Rendu vectoriel du corps translucide de la bulle et de ses reflets superieurs, optimise pour eviter les allocations dans la boucle de rendu.
- **`presentation/rendering/bubble_text_helper.dart` & `components/bubble_label.dart`** :
  Calcul de dimensions et calibrage typographique garantissant que le texte tient toujours dans la zone visible sans depasser.

### 3.4 Module Mascotte Curio (`lib/features/curio/`)
- **`character_backup_painter.dart` & `character_backup_widget.dart`** :
  Dessin vectoriel anime et widget du personnage Curio. Adapte ses expressions (joie, colere, tristesse) et joue les sons correspondants selon la progression du temps.
- **`presentation/widgets/character_time_gauge.dart`** :
  Jauge temporelle verticale a tube de verre avec degrade d'alerte, pulsations et alerte sonore sous 30 pourcent du temps.
- **`presentation/widgets/curio_timer.dart`** :
  Overlay Flutter superpose au jeu affichant Curio, la jauge de temps et un cadre neon clignotant sur le perimetre de l'ecran lors des moments critiques.

### 3.5 Module Logique de Jeu (`lib/features/game/`)
- **`data/game_questions.dart` & `domain/models/game_question.dart`** :
  Catalogue et modele des questions/reponses et des notions de savoir associees.
- **`presentation/bubble_game.dart`** :
  Moteur Flame orchestrant le demarrage des manches, la selection des questions, le spawn aleatoire des bulles, le tir au toucher et la gestion des freezes victorieux.
- **`presentation/components/laser_beam.dart`** :
  Rendu du personnage tireur Edutainer et du faisceau laser avec detection d'intersections geometriques par lancer de rayon.
- **`presentation/components/laser_label_box.dart`** :
  Boitier d'affichage de texte HUD technologique, avec mise en cache dans un `ui.Picture` pour eviter tout re-rendu inutile.

---

## 4. Physique des Rebonds et Optimisations

1. **Elimination de la discontinuite d'onde** :
   Le deplacement combine une translation `centerBase` et une oscillation `wave = perp * sin(t * freq) * amp`. Lors d'un rebond, `perp` change d'orientation. La fonction `_preserveWaveContinuity` recalcule la phase temporelle `t` pour que la nouvelle composante ondulatoire corresponde exactement a l'ancienne, eliminant tout soubresaut visuel.

2. **Resolution elastique proportionnelle aux masses** :
   La repulsion entre deux bulles en contact est ponderee par le carre de leur rayon respectif. Les deux vitesses le long de la normale d'impact sont echangees selon la loi de conservation de quantite de mouvement.

3. **Mise en cache et reduction des allocations** :
   - Les objets `Paint`, `Path`, `Shader`, matrices de couleur et peintres de texte sont alloues une seule fois et reutilises a chaque trame.
   - Le fond spatial est isole dans un `RepaintBoundary`.
   - Les dependances inutiles (`flame_audio`, `floating_bubbles`, sous-package duplique) ont ete retirees pour un poids binaire et un temps de compilation reduits.
