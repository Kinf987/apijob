# PROJET : API JOB — Ajout du backend

Tu travailles sur API JOB, une marketplace de services pour Tahiti et Moorea (Polynésie française).

## RÈGLE ABSOLUE
Ne touche JAMAIS au HTML/CSS existant.
Ne modifie aucun design, aucune couleur, aucune animation.
Tu connectes uniquement un backend aux pages existantes.

## Ce qui existe déjà (ne pas toucher)
29 pages HTML complètes dans ce dossier :
apijob-v4.html (homepage), apijob-auth.html, apijob-dashboard.html,
apijob-annonce.html, apijob-annonces.html, apijob-annonce-detail.html,
apijob-proposition.html, apijob-messagerie.html, apijob-missions.html,
apijob-evaluation.html, apijob-jetons.html, apijob-devenir-pro.html,
apijob-pros.html, apijob-pro.html, apijob-profil-edit.html,
apijob-profil-public.html, apijob-profil-client.html,
apijob-notifications.html, apijob-parametres.html,
apijob-bienvenue.html, apijob-confirmation-email.html,
apijob-motdepasse.html, apijob-admin.html, apijob-admin-login.html,
apijob-cgu.html, apijob-mentions.html, apijob-confidentialite.html,
apijob-contact.html, apijob-404.html

## Stack technique
- Supabase (auth + base de données PostgreSQL)
- JavaScript vanilla
- Supabase JS client (CDN, pas de build)
- Hébergement : Netlify (apijob.netlify.app)
- Repo GitHub : github.com/Kinf987/apijob
- Push toujours via GitHub Desktop (pas depuis le terminal)

## Modèle économique
- Clients : accès gratuit, aucun paiement
- Prestataires : système de jetons (tokens)
  - Inscription : 3 jetons offerts
  - Starter : 3 jetons · 900 XPF (achat unique)
  - Pro : jetons illimités · 2 900 XPF/mois (abonnement)
- Débit du jeton : uniquement quand le client ACCEPTE une proposition
- Paiement : Stripe (carte) + virement + cash relais (Stripe différé)
- Jetons non remboursables

## Tables Supabase (déjà créées)
- profiles (id, email, role, prenom, nom, photo text [URL bucket identites], localisation, bio, tokens, is_pro, metadata jsonb [titre, experience, services, zones, disponibilites, numero_tahiti, type_structure, raison_sociale, forme_juridique, representant_legal], identity_doc_path text [STAND-BY], identity_verified_at timestamptz [STAND-BY], created_at)
- annonces (id, client_id, titre, description, categorie, localisation, statut, created_at)
- propositions (id, annonce_id, prestataire_id, message, tarif, disponibilite, statut, created_at)
- missions (id, annonce_id, proposition_id, client_id, prestataire_id, statut, created_at)
- messages (id, mission_id, sender_id, contenu, created_at)
- evaluations (id, mission_id, auteur_id, cible_id, note_globale, note_ponctualite, note_qualite, note_communication, note_prix, commentaire, created_at)
- transactions_jetons (id, user_id, type, quantite, mission_id, created_at)
- notifications (id, user_id, type, titre, message, lu, created_at)

## Règles métier
- Profils prestataires non-Pro : visibles UNIQUEMENT par les clients ayant reçu leur proposition
- Seuls les Pro apparaissent dans l'annuaire (apijob-pros.html)
- Partage de coordonnées avant acceptation = avertissement puis bannissement
- Admin credentials : à changer avant mise en ligne
- Déclaration CPS cochée à l'inscription

## Pages connectées au backend — TOUTES FAITES ✅
- apijob-auth.html — inscription + connexion + emailRedirectTo bienvenue
- apijob-dashboard.html — stats réelles, vrai prénom, déconnexion
- apijob-annonce.html — publication d'annonce en base
- apijob-annonces.html — liste dynamique + filtres + envoi de propositions
- apijob-confirmation-email.html — vrai email, renvoi Supabase
- apijob-bienvenue.html — token après confirmation, vrai prénom, rôle réel
- apijob-profil-edit.html — édition profil + photo (bucket identites)
- apijob-messagerie.html — messagerie temps réel
- apijob-missions.html — suivi des missions
- apijob-notifications.html — centre de notifications
- apijob-evaluation.html — système d'avis
- apijob-jetons.html — affichage jetons + forfaits
- apijob-pros.html — annuaire des Pro
- apijob-annonce-detail.html — détail annonce
- apijob-profil-public.html — profil public prestataire
- apijob-proposition.html — envoi proposition + accepter → crée mission + débite jeton + notifie
- apijob-parametres.html — paramètres compte
- apijob-motdepasse.html — réinitialisation mot de passe (détecte PASSWORD_RECOVERY)
- apijob-profil-client.html — profil client
- apijob-pro.html — page prestataire
- apijob-admin.html — tableau de bord admin
- apijob-admin-login.html — connexion admin (credentials hardcodés — à changer avant prod)
- apijob-devenir-pro.html — upgrade Pro

## Pages statiques (rien à faire)
- apijob-cgu.html, apijob-mentions.html, apijob-confidentialite.html, apijob-contact.html, apijob-404.html

## Ce qui reste avant mise en prod
1. **Tests flux complet** — créer compte client + prestataire, publier annonce → proposition → mission → évaluation → vérifier notifications, messagerie, jetons débités
2. **Stripe** — intégration paiement jetons (différé volontairement)
3. **Changer credentials admin** — dans apijob-admin-login.html avant mise en ligne
4. **Nom de domaine** — pointer apijob.pf vers Netlify

## Supabase
- Project ID : douncwfmczjpnwcpfsah
- Project URL : https://douncwfmczjpnwcpfsah.supabase.co
- Dashboard : https://supabase.com/dashboard/project/douncwfmczjpnwcpfsah
- Clés dans : sauvegarde-terminal/cles-supabase.md (exclu GitHub)

## Notes techniques importantes
- `metadata` JSONB dans `profiles` : titre, experience, services, zones, disponibilites, numero_tahiti, type_structure, raison_sociale, forme_juridique, representant_legal
- `identity_doc_path` et `identity_verified_at` dans `profiles` : colonnes créées, **STAND-BY** — pièce d'identité non collectée pour l'instant, à activer si besoin futur
- bucket `verifications` dans Supabase Storage : **STAND-BY** — créé mais non utilisé
- `photo text` dans `profiles` : URL publique du bucket Storage `identites`
- FK disambiguation Supabase : `profiles!prestataire_id(...)` pour tables avec deux FK vers profiles
- `apijob-proposition.html` accepter() → crée mission + débite jeton prestataire + notifie
- `apijob-motdepasse.html` détecte `onAuthStateChange('PASSWORD_RECOVERY')` pour sauter à l'étape 3
- Admin login : credentials hardcodés dans apijob-admin-login.html (à changer avant prod)
- Déconnexion : lien logout → `onclick="seDeconnecter(event)"`, signOut() dans supabase-config.js avec `?logout=1`, auth page appelle `db.auth.signOut()` côté client au retour

## Règles de travail
- Ne jamais toucher au HTML/CSS
- Tester en fenêtre privée (Cmd+Maj+N) pour éviter les sessions bloquées
- Demander confirmation avant toute action irréversible
- Dire ce qui est fait, ce qui fonctionne, ce qui reste à faire
