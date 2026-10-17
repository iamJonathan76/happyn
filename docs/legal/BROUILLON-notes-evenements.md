# Brouillon — mise à jour des textes légaux pour les notes d'événement

> **Statut : publié le 2026-10-17** (option 1, publication immédiate, entre
> testeurs), en anglais et en français — migration
> `20261017020000_legal_ratings.sql`. Les ajouts sont en **gras**. Le préavis
> de 30 jours reste à faire confirmer par l'avocat.

## Ce qui change, et pourquoi

Les notes créent de nouvelles données personnelles : la note, les tags, le
commentaire, et le fait d'avoir noté. La loi demande de dire ce qu'on en fait,
qui les voit et combien de temps on les garde.

| Document | Version actuelle | Nouvelle | Acceptation redemandée ? |
|---|---|---|---|
| Politique de confidentialité | 1.2 | 1.3 | **Oui** |
| Règles de la communauté | 1.0 | 1.1 | **Oui** |
| Politique de conservation | 1.0 | 1.1 | Non (référencée) |
| Normes pour les organisateurs | 1.0 | 1.1 | Non (référencée) |
| Suppression de compte | 1.0 | 1.1 | Non (référencée) |
| Politique de paiement | 1.0 | 1.1 *(facultatif)* | Non |

## ⚠️ Le préavis de 30 jours

Les conditions (§ 18) et la politique de confidentialité (§ 21) promettent
d'avertir **au moins 30 jours avant** l'entrée en vigueur d'une modification
importante. Deux lectures possibles :

1. **Ce n'est pas une modification importante** : rien ne change pour les
   données déjà traitées. Les notes sont une nouvelle fonction, facultative —
   une personne qui ne note jamais ne donne rien de nouveau. Publication
   immédiate.
2. **Prudence** : publier la version avec une date d'entrée en vigueur à
   30 jours, et n'activer les demandes de note qu'à cette date.

Ma lecture : la 1 se défend, d'autant qu'avant le lancement les seuls comptes
sont des testeurs. **C'est précisément le genre de point à faire confirmer par
l'avocat lors de la relecture.**

---

## 1. Politique de confidentialité — 1.2 → 1.3

**En bref** — ajouter une puce :

> - **Après un événement où votre billet a été scanné à l'entrée, vous pouvez
>   le noter. L'organisateur voit votre note sans savoir qu'elle vient de
>   vous ; le public ne voit que la moyenne d'un organisateur, à partir de
>   5 notes.**

**§ 5. Ce qui est créé quand vous utilisez HAPPYN** — ajouter :

> - **Les notes que vous donnez à un événement : le nombre d'étoiles, les tags
>   que vous choisissez, votre commentaire facultatif et la date — pour aider
>   l'organisateur à s'améliorer et les autres membres à choisir. Seule une
>   personne dont le billet a été scanné à l'entrée peut noter, pendant une
>   période limitée après l'événement.**
> - **La demande de note que nous vous envoyons, une seule fois, 24 heures après
>   la fin d'un événement auquel vous étiez.**

**§ 10. Ce que voient les autres membres** —

> Visible par les membres : […] **la note moyenne d'un organisateur et le
> nombre de notes, à partir de 5 notes — jamais une note individuelle.**
>
> Jamais visible par les autres membres : […] **vos notes et vos commentaires
> sur les événements.**

**§ 11. Ce que voient les organisateurs** — ajouter :

> **Les organisateurs voient les notes, les tags et les commentaires laissés sur
> leurs événements, sans le nom, la photo ni aucun autre moyen d'identifier
> leurs auteurs.**

---

## 2. Règles de la communauté — 1.0 → 1.1

**Nouvelle section : Les notes**

> **Une note sert à dire comment s'est passé l'événement, pour l'organisateur et
> pour ceux qui hésitent.**
>
> - **Notez ce que vous avez vécu, honnêtement.**
> - **Pas d'insultes, de harcèlement, de propos haineux ni de renseignements
>   personnels sur quelqu'un dans un commentaire.**
> - **Un organisateur ne doit rien offrir en échange d'une note (billet gratuit,
>   rabais, cadeau), ni faire pression sur qui que ce soit pour en obtenir une
>   bonne ou en faire retirer une mauvaise.**
> - **Pas de faux comptes pour noter.**
>
> **Les commentaires qui enfreignent ces règles peuvent être signalés et
> retirés, comme tout autre contenu.**

---

## 3. Politique de conservation — 1.0 → 1.1

**Durées de conservation** — ajouter :

> - **Notes d'événement : tant que l'événement existe. Si vous supprimez votre
>   compte, votre note reste comptée dans la moyenne, sans aucun lien avec
>   vous.**

## 4. Suppression de compte — 1.0 → 1.1

**§ 5. Ce qui est conservé, sans votre identité** — ajouter :

> - **Vos notes d'événement, qui restent comptées dans la moyenne de
>   l'organisateur sans aucun lien avec vous.**

---

## 5. Normes pour les organisateurs — 1.0 → 1.1

**§ 5. Vos participants** — ajouter :

> **Après l'événement, les participants dont le billet a été scanné peuvent le
> noter. Vous voyez leurs notes, leurs tags et leurs commentaires, sans savoir
> qui les a écrits. Vous ne pouvez pas les supprimer — seulement les signaler
> s'ils enfreignent les règles de la communauté. Offrir quoi que ce soit en
> échange d'une note est interdit.**

**§ 6. Les versements** — préciser le délai *(facultatif, mais l'écran
« Être payé » dit déjà 7 jours)* :

> Votre part est versée sur votre compte Stripe **7 jours** après la fin de
> l'événement. […] **Votre premier versement passe par une vérification de
> notre part.**

## 6. Politique de paiement — 1.0 → 1.1 *(facultatif)*

**§ 5. Comment les organisateurs sont payés** — même précision :

> La part de l'organisateur lui est versée **7 jours** après la fin de
> l'événement […]

---

## Après validation

1. Traduction en anglais (version de référence) et mise à jour de
   `legal_documents` + `legal_document_translations`, testée comme les
   migrations précédentes.
2. L'écran de consentement redemande l'accord une fois, pour la
   confidentialité et les règles de la communauté.
3. Activation de la demande de note (`happyn-rating-requests`, toutes les
   heures).
