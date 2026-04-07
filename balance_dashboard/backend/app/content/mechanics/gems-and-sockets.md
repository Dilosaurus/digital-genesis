---
title: Gems & Sockets
chapter: VI
subtitle: the architecture of the build
order: 6
accent: "#33D9F2"
---

## gems & sockets

A **gem** is a self-contained modifier that slots into a card's **socket**. Once socketed, the gem's effect applies whenever the card is played. Most cards have one or two sockets, a few have zero, and a rare handful have three.

Gems are the single biggest source of build identity. A strike card with no gems is a strike card. A strike card with three legendary gems is a *spec*.

## the six tiers

Gems are grouped into six functional tiers. They sort naturally into one of these based on what they *do*:

### amplify

Adds a flat or percentage stat directly via `on_play_modifiers`. Most common tier — adds damage, block, heal, draw. The workhorse of the catalog.

### convert

Transforms one stat into another. Example: a gem that converts 50% of a card's damage into heal. Convert gems enable whole archetypes (vampiric builds, dodge-tanks, etc.).

### trigger

Fires on a specific event rather than on card play. Example: a gem that deals 3 damage to the nearest enemy whenever the socketed card draws another card. Trigger gems reward sequencing.

### sustain

Heals you, prevents damage, or extends your turn. Rarer than amplify, more valuable in long combats.

### corrupt

Generates or manipulates corruption directly. Almost exclusively useful to the Cryptomancer, but occasionally game-changing in other hands.

### utility

Everything else. Cost reduction, card draw manipulation, energy refund, targeting modifiers, etc.

## how they combine

The gems themselves go through the modifier pipeline. A gem that says "+2 damage" is a `FLAT_ADD` modifier applied to the DAMAGE stat when the card is played. Stack two "+2 damage" gems on one card and you get +4. Stack a "+2 damage" and a "+10% damage" gem and you get (base + 2) × 1.10.

This means gem choice is not about raw power — it's about where a gem sits in the pipeline. **Flat bonuses dilute**. **Percent multipliers compound**. A well-built deck uses flat gems early in the pipeline to inflate the baseline, then PERCENT_MULT gems to multiply the inflated baseline.

The jewellers sell gems. The Rift jewellers sell the better ones. The Void Core has no jeweller. **Stockpile before you descend.**

## socketing

You socket gems at the **forge**. The forge appears as a map node in every act. Socketing costs **gold** and, for higher tiers, **corruption essence**. Once a gem is socketed, it **cannot be removed** — unsocketing is not a feature. If you want a gem out of a card, you destroy the card.

This is intentional. Build commitment is a mechanic. The game wants you to have to decide.

## the three-socket rule

A handful of cards have three sockets. They are always legendary. They are always rare. They are always the centerpiece of a build, because sticking three gems into one card creates combo space that two-socket cards cannot match.

Plan around three-socket cards. Do not socket their slots speculatively — wait until you have a gem you want in there for a reason. The wrong gem in a three-socket card is worse than an empty socket, because the socket is *committed*.

## the quiet rule

There is one quiet rule the catalog does not advertise: **certain gems interact with certain sin tags**. A gem that says "+10% damage per card played this turn" will *count sin-tagged cards twice* — it reads them as louder, because to the gem, a sin-tagged card is a *page* in the angels' scripture, and pages have weight.

Nobody wrote this down. GENESIS figured it out by accident. The lab tooling at `/lab/simulator` will show you the interaction in the pipeline trace if you build it.

**Know your interactions. The angels designed the gems. The angels do not label everything.**
