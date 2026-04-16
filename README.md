# API JOB — Guide de déploiement

Marketplace de services à Tahiti & Moorea · Polynésie française

---

## Stack technique

- **Frontend** : 29 pages HTML + CSS + JS vanilla
- **Backend** : Supabase (Auth + PostgreSQL + Storage)
- **Hébergement** : Netlify (déjà configuré) ou Vercel

---

## ÉTAPE 1 — Créer le projet Supabase

1. Aller sur [supabase.com](https://supabase.com) → **New project**
2. Choisir un nom (ex : `apijob-prod`) et une région (Singapore est la plus proche)
3. Noter le **Project URL** et l'**anon public key** (dans Settings > API)

---

## ÉTAPE 2 — Configurer les clés

Ouvrir `prototype/supabase-config.js` et remplacer :

```js
const SUPABASE_URL  = 'https://VOTRE_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'VOTRE_ANON_KEY_ICI';
```

---

## ÉTAPE 3 — Créer les tables (SQL)

Dans Supabase > **SQL Editor** > **New query** :

1. Copier-coller **tout le contenu** de `schema.sql`
2. Cliquer **Run**
3. Vérifier qu'il n'y a pas d'erreur en rouge

---

## ÉTAPE 4 — Créer le bucket Storage

Dans Supabase > **Storage** > **New bucket** :

- Nom : `identites`
- Accès : **Privé** (non public)
- Taille max fichier : 5 MB

---

## ÉTAPE 5 — Configurer l'authentification Supabase

Dans Supabase > **Authentication** > **Settings** :

- **Site URL** : `https://votre-domaine.netlify.app` (ou votre domaine final)
- **Redirect URLs** : Ajouter `https://votre-domaine.netlify.app/prototype/apijob-confirmation-email.html`
- **Email confirmations** : Activé (recommandé)

Optionnel — Personnaliser l'email de confirmation dans Authentication > **Email Templates**.

---

## ÉTAPE 6 — Déployer sur Netlify

```bash
# Dans le dossier /Desktop/apijob
netlify login
netlify init
netlify deploy --prod
```

**Configuration Netlify** :
- Base directory : `/` (racine du projet)
- Publish directory : `/` (toutes les pages sont statiques)
- Build command : *(laisser vide)*

---

## ÉTAPE 7 — Configuration Admin

⚠️ **AVANT la mise en ligne** :
1. Ouvrir `prototype/apijob-admin-login.html` et changer les credentials admin
2. Ou mieux : utiliser Supabase RLS avec le rôle `admin` dans la table `profiles`

---

## Pages connectées au backend

| Page | Fonctionnalité | Statut |
|------|----------------|--------|
| `apijob-auth.html` | Inscription + Connexion Supabase | ✅ Connecté |
| `apijob-dashboard.html` | Stats réelles, missions, annonces | ✅ Connecté |
| `apijob-annonce.html` | Publication d'annonce en base | ✅ Connecté |
| `apijob-annonces.html` | Liste dynamique + filtres + propositions | ✅ Connecté |
| `apijob-messagerie.html` | Messagerie temps réel | 🔄 À connecter |
| `apijob-missions.html` | Suivi missions | 🔄 À connecter |
| `apijob-evaluation.html` | Système d'évaluation | 🔄 À connecter |
| `apijob-notifications.html` | Notifications | 🔄 À connecter |
| `apijob-jetons.html` | Achat de jetons | 🔄 À connecter |
| `apijob-profil-edit.html` | Édition profil | 🔄 À connecter |
| `apijob-pros.html` | Annuaire prestataires Pro | 🔄 À connecter |

---

## Modèle économique — Jetons

| Formule | Prix | Jetons | Notes |
|---------|------|--------|-------|
| Découverte | Gratuit | 3 à l'inscription | Non rechargeable automatiquement |
| Starter | 900 XPF | 3 jetons | Sans expiration |
| Standard | 2 000 XPF | 9 jetons | -25% par jeton |
| Pro | 5 900 XPF/mois | Illimités | + Annuaire + Badge |

**Débit** : 1 jeton débité uniquement quand le client **accepte** une proposition.

---

## Structure des fichiers backend

```
apijob/
├── schema.sql                    # Tables + RLS + Triggers Supabase
├── prototype/
│   ├── supabase-config.js        # Client Supabase + utilitaires partagés
│   ├── apijob-auth.html          # Auth connectée
│   ├── apijob-dashboard.html     # Dashboard connecté
│   ├── apijob-annonce.html       # Publication annonce connectée
│   ├── apijob-annonces.html      # Liste annonces connectée
│   └── ... (autres pages)
└── README.md
```

---

## Variables d'environnement (optionnel pour Stripe)

Pour les paiements Stripe (à implémenter via Netlify Functions) :

```
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
```

---

## Contact & Support

Projet API JOB · Tahiti & Moorea 🌺
