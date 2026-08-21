# Recommandation — note de conception

Écrit le 2026-08-14, **rien n'est construit**. Ce document existe pour que le
raisonnement soit là quand le moment viendra, au lieu d'être refait de zéro.

## Le déclencheur

Aujourd'hui un utilisateur voit à peu près tout ce qui existe en un défilement.
Classer n'a donc aucun effet : un moteur de recommandation résout un problème
d'**abondance**, et HAPPYN est dans un problème de **rareté**. Chaque heure
passée sur le classement serait une heure non passée à recruter des
organisateurs.

**Le signal qu'il est temps d'y revenir :** quelqu'un ne peut plus voir tout ce
qui l'intéresse en une seule page. Avant ça, non.

## L'approche retenue : des rangées, pas un score

Une Home modulaire, chaque rangée avec sa propre logique et son explication
visible :

| Rangée | Logique |
|---|---|
| Bientôt | temps + distance |
| Chez tes connexions | graphe social |
| Près de toi | distance |
| Tendance | popularité, vélocité des ventes |
| Parce que tu es allé à X | comportement |
| Organisateurs que tu suis | follow |

Les explications font le gros du travail perçu : « 👥 3 amis y vont »,
« 📍 1,8 km », « Parce que tu es allé à X ». Aucune intelligence artificielle
n'est nécessaire, et un utilisateur pardonne une mauvaise suggestion dont il
comprend la raison — alors qu'une bonne suggestion inexpliquée ne construit
aucune confiance.

**Un score pondéré unique (`interest × 30% + behavior × 25%…`) est
explicitement écarté pour l'instant.** Sans données réelles, les poids ne sont
pas un modèle simplifié : ce sont des chiffres inventés, impossibles à régler ou
à évaluer, et ils rendent le classement opaque au moment où on a le plus besoin
de comprendre ce qui se passe. Il ne devient utile que quand il y a plus
d'événements pertinents que de place à l'écran.

## Les signaux, par ordre de solidité

1. **Le billet acheté** — incorruptible, parce qu'il coûte de l'argent.
2. **La présence confirmée** (`attended`, via le scan).
3. **Le graphe social** — le signal différenciateur : un événement moyennement
   compatible mais où vont quatre connexions devient très pertinent.
4. **Les intérêts déclarés** — le seul signal disponible pour un compte neuf.
5. **Le contexte** — distance et date pèsent énormément pour de l'événementiel :
   une soirée à Vancouver demain ne sert à rien à quelqu'un à Ottawa.
6. **Le comportement de consultation** — le plus riche à terme, le plus coûteux
   en vie privée (voir plus bas).

**« Interested » n'est pas réintroduit.** Il a été retiré le 2026-08-09 parce
qu'il créait un troisième état flou entre « je regarde » et « j'y vais ». Ne pas
le ramener seulement pour nourrir un algorithme.

## Trois pièges identifiés

**Popularité ≠ personnalisation.** Sans garde-fou, les cinq plus gros événements
d'Ottawa sont montrés à tout le monde et les petits organisateurs deviennent
invisibles — c'est-à-dire exactement les organisateurs dont HAPPYN a besoin pour
exister.

**Le co-attendance trahit les gens quand N est petit.** « Ceux qui sont allés à
X vont aussi à Y » : si quatre personnes sont allées aux deux, la corrélation
*est* ces quatre personnes, et quelqu'un qui connaît le milieu remonte à
l'individu. Deux règles non négociables :
- jamais moins d'une vingtaine de personnes derrière un motif publié ;
- ne jamais construire un motif à partir de présences non rendues visibles.

Sinon on reconstruit indirectement ce que la visibilité explicite protégeait.

**Suivre le comportement, c'est collecter de la donnée personnelle.** Le temps
passé sur une fiche exige, sous Loi 25, une finalité déclarée, une durée de
conservation et une mention dans la politique de confidentialité. Concrètement :
- ne pas écrire la première ligne de journalisation avant que le texte la couvre ;
- stocker des agrégats par catégorie, pas un journal détaillé par événement.

La donnée qu'on n'a pas ne fuite pas, ne se demande pas et ne se supprime pas.

## Le seul élément qui ne se rattrape pas

**Les intérêts déclarés à l'inscription.** Les gens inscrits au lancement ne
rempliront jamais un formulaire de préférences plus tard : chaque semaine sans
ce champ est une cohorte définitivement sans signal, et aucun rattrapage n'est
possible ensuite.

C'est une colonne et trois écrans, et ça sert dès le premier jour à filtrer
Discover, même sans aucune recommandation derrière. À décider indépendamment du
reste de ce document.
