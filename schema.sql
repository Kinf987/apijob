-- ============================================================
-- SCHEMA SQL — API JOB
-- À exécuter dans Supabase : SQL Editor > New query > Run
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. TABLE PROFILES (extension de auth.users)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         text NOT NULL,
  role          text NOT NULL DEFAULT 'client' CHECK (role IN ('client', 'prestataire', 'admin')),
  prenom        text NOT NULL DEFAULT '',
  nom           text NOT NULL DEFAULT '',
  telephone     text,
  localisation  text,
  bio           text,
  categorie     text,          -- métier principal du prestataire
  numero_tahiti text,          -- numéro professionnel
  photo_url     text,
  tokens        integer NOT NULL DEFAULT 0,
  is_pro        boolean NOT NULL DEFAULT false,
  pro_expires_at timestamptz,  -- null = pas d'abonnement Pro actif
  is_verified   boolean NOT NULL DEFAULT false,
  is_banned     boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ────────────────────────────────────────────────────────────
-- 2. TABLE ANNONCES
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.annonces (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  titre         text NOT NULL,
  description   text NOT NULL,
  categorie     text NOT NULL,
  ile           text NOT NULL DEFAULT 'Tahiti',
  commune       text,
  urgence       text NOT NULL DEFAULT 'flexible',
  date_souhaitee date,
  budget        integer,       -- en XPF
  statut        text NOT NULL DEFAULT 'active'
                  CHECK (statut IN ('active', 'en_cours', 'terminee', 'annulee')),
  nb_propositions integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ────────────────────────────────────────────────────────────
-- 3. TABLE PROPOSITIONS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.propositions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  annonce_id      uuid NOT NULL REFERENCES public.annonces(id) ON DELETE CASCADE,
  prestataire_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message         text NOT NULL,
  tarif           text,
  disponibilite   text,
  statut          text NOT NULL DEFAULT 'en_attente'
                    CHECK (statut IN ('en_attente', 'acceptee', 'refusee', 'annulee')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (annonce_id, prestataire_id)
);

-- ────────────────────────────────────────────────────────────
-- 4. TABLE MISSIONS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.missions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  annonce_id      uuid NOT NULL REFERENCES public.annonces(id),
  proposition_id  uuid NOT NULL REFERENCES public.propositions(id),
  client_id       uuid NOT NULL REFERENCES public.profiles(id),
  prestataire_id  uuid NOT NULL REFERENCES public.profiles(id),
  statut          text NOT NULL DEFAULT 'en_cours'
                    CHECK (statut IN ('en_cours', 'terminee', 'annulee')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ────────────────────────────────────────────────────────────
-- 5. TABLE MESSAGES
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id  uuid NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES public.profiles(id),
  contenu     text NOT NULL,
  lu          boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ────────────────────────────────────────────────────────────
-- 6. TABLE ÉVALUATIONS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.evaluations (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mission_id          uuid NOT NULL REFERENCES public.missions(id),
  auteur_id           uuid NOT NULL REFERENCES public.profiles(id),
  cible_id            uuid NOT NULL REFERENCES public.profiles(id),
  note_globale        integer CHECK (note_globale BETWEEN 1 AND 5),
  note_ponctualite    integer CHECK (note_ponctualite BETWEEN 1 AND 5),
  note_qualite        integer CHECK (note_qualite BETWEEN 1 AND 5),
  note_communication  integer CHECK (note_communication BETWEEN 1 AND 5),
  note_prix           integer CHECK (note_prix BETWEEN 1 AND 5),
  commentaire         text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (mission_id, auteur_id)
);

-- ────────────────────────────────────────────────────────────
-- 7. TABLE TRANSACTIONS JETONS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.transactions_jetons (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id),
  type        text NOT NULL CHECK (type IN ('credit', 'debit', 'remboursement')),
  quantite    integer NOT NULL,
  description text,
  mission_id  uuid REFERENCES public.missions(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ────────────────────────────────────────────────────────────
-- 8. TABLE NOTIFICATIONS
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type        text NOT NULL,
  titre       text NOT NULL,
  message     text,
  lu          boolean NOT NULL DEFAULT false,
  lien        text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- TRIGGER : Création automatique du profil à l'inscription
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role text;
  v_tokens integer;
BEGIN
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'client');
  -- 3 jetons offerts à l'inscription pour les prestataires
  v_tokens := CASE WHEN v_role = 'prestataire' THEN 3 ELSE 0 END;

  INSERT INTO public.profiles (id, email, role, prenom, nom, telephone, numero_tahiti, tokens)
  VALUES (
    NEW.id,
    NEW.email,
    v_role,
    COALESCE(NEW.raw_user_meta_data->>'prenom', ''),
    COALESCE(NEW.raw_user_meta_data->>'nom', ''),
    NEW.raw_user_meta_data->>'telephone',
    NEW.raw_user_meta_data->>'numero_tahiti',
    v_tokens
  );

  -- Transaction initiale pour les prestataires
  IF v_role = 'prestataire' THEN
    INSERT INTO public.transactions_jetons (user_id, type, quantite, description)
    VALUES (NEW.id, 'credit', 3, 'Jetons offerts à l''inscription');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================
-- FONCTION : Accepter une proposition (débit jeton atomique)
-- ============================================================
CREATE OR REPLACE FUNCTION public.accepter_proposition(p_proposition_id uuid, p_client_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_proposition propositions%ROWTYPE;
  v_annonce     annonces%ROWTYPE;
  v_prestataire profiles%ROWTYPE;
  v_mission_id  uuid;
BEGIN
  -- Récupérer la proposition
  SELECT * INTO v_proposition FROM propositions WHERE id = p_proposition_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Proposition introuvable');
  END IF;

  -- Vérifier que le client est bien le propriétaire de l'annonce
  SELECT * INTO v_annonce FROM annonces WHERE id = v_proposition.annonce_id AND client_id = p_client_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Non autorisé');
  END IF;

  -- Vérifier que la proposition est en attente
  IF v_proposition.statut <> 'en_attente' THEN
    RETURN json_build_object('success', false, 'error', 'Cette proposition n''est plus disponible');
  END IF;

  -- Récupérer le prestataire
  SELECT * INTO v_prestataire FROM profiles WHERE id = v_proposition.prestataire_id;

  -- Vérifier les jetons (sauf si Pro avec abonnement actif)
  IF NOT (v_prestataire.is_pro AND (v_prestataire.pro_expires_at IS NULL OR v_prestataire.pro_expires_at > now())) THEN
    IF v_prestataire.tokens < 1 THEN
      RETURN json_build_object('success', false, 'error', 'Le prestataire n''a plus de jetons');
    END IF;
    -- Débiter 1 jeton
    UPDATE profiles SET tokens = tokens - 1 WHERE id = v_prestataire.id;
    INSERT INTO transactions_jetons (user_id, type, quantite, description)
    VALUES (v_prestataire.id, 'debit', 1, 'Mission acceptée : ' || v_annonce.titre);
  END IF;

  -- Marquer la proposition comme acceptée
  UPDATE propositions SET statut = 'acceptee' WHERE id = p_proposition_id;

  -- Refuser les autres propositions sur la même annonce
  UPDATE propositions SET statut = 'refusee'
  WHERE annonce_id = v_proposition.annonce_id
    AND id <> p_proposition_id
    AND statut = 'en_attente';

  -- Mettre à jour le statut de l'annonce
  UPDATE annonces SET statut = 'en_cours' WHERE id = v_proposition.annonce_id;

  -- Créer la mission
  INSERT INTO missions (annonce_id, proposition_id, client_id, prestataire_id)
  VALUES (v_proposition.annonce_id, p_proposition_id, p_client_id, v_proposition.prestataire_id)
  RETURNING id INTO v_mission_id;

  -- Notification au prestataire
  INSERT INTO notifications (user_id, type, titre, message, lien)
  VALUES (
    v_prestataire.id,
    'proposition_acceptee',
    '🎉 Votre proposition a été acceptée !',
    'Le client a accepté votre proposition pour : ' || v_annonce.titre,
    'apijob-messagerie.html?mission=' || v_mission_id
  );

  RETURN json_build_object('success', true, 'mission_id', v_mission_id);
END;
$$;

-- ============================================================
-- FONCTION : Terminer une mission + rembourser si abandon client
-- ============================================================
CREATE OR REPLACE FUNCTION public.annuler_mission(p_mission_id uuid, p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_mission missions%ROWTYPE;
BEGIN
  SELECT * INTO v_mission FROM missions WHERE id = p_mission_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Mission introuvable');
  END IF;

  -- Seul le client ou le prestataire peut annuler
  IF p_user_id <> v_mission.client_id AND p_user_id <> v_mission.prestataire_id THEN
    RETURN json_build_object('success', false, 'error', 'Non autorisé');
  END IF;

  -- Rembourser 1 jeton au prestataire si c'est le client qui annule
  IF p_user_id = v_mission.client_id THEN
    UPDATE profiles SET tokens = tokens + 1 WHERE id = v_mission.prestataire_id;
    INSERT INTO transactions_jetons (user_id, type, quantite, description, mission_id)
    VALUES (v_mission.prestataire_id, 'remboursement', 1, 'Mission annulée par le client', p_mission_id);

    INSERT INTO notifications (user_id, type, titre, message)
    VALUES (
      v_mission.prestataire_id,
      'mission_annulee',
      '⚠️ Mission annulée',
      'Le client a annulé la mission. Votre jeton a été remboursé.'
    );
  END IF;

  UPDATE missions SET statut = 'annulee' WHERE id = p_mission_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.annonces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.propositions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions_jetons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "Lecture profil propre" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Lecture profils Pro (annuaire)" ON public.profiles
  FOR SELECT USING (is_pro = true AND is_banned = false);

CREATE POLICY "Mise à jour profil propre" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Annonces (toutes les annonces actives sont visibles par les authentifiés)
CREATE POLICY "Lecture annonces actives" ON public.annonces
  FOR SELECT USING (auth.role() = 'authenticated' AND statut = 'active');

CREATE POLICY "Lecture mes annonces" ON public.annonces
  FOR SELECT USING (auth.uid() = client_id);

CREATE POLICY "Création annonce (clients)" ON public.annonces
  FOR INSERT WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Mise à jour mes annonces" ON public.annonces
  FOR UPDATE USING (auth.uid() = client_id);

-- Propositions
CREATE POLICY "Voir mes propositions envoyées" ON public.propositions
  FOR SELECT USING (auth.uid() = prestataire_id);

CREATE POLICY "Voir propositions sur mes annonces" ON public.propositions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.annonces
      WHERE id = annonce_id AND client_id = auth.uid()
    )
  );

CREATE POLICY "Envoyer une proposition" ON public.propositions
  FOR INSERT WITH CHECK (auth.uid() = prestataire_id);

CREATE POLICY "Modifier ma proposition" ON public.propositions
  FOR UPDATE USING (auth.uid() = prestataire_id);

-- Missions
CREATE POLICY "Voir mes missions" ON public.missions
  FOR SELECT USING (auth.uid() = client_id OR auth.uid() = prestataire_id);

-- Messages
CREATE POLICY "Voir messages de mes missions" ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.missions
      WHERE id = mission_id AND (client_id = auth.uid() OR prestataire_id = auth.uid())
    )
  );

CREATE POLICY "Envoyer message dans mes missions" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM public.missions
      WHERE id = mission_id AND (client_id = auth.uid() OR prestataire_id = auth.uid())
    )
  );

CREATE POLICY "Marquer message lu" ON public.messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.missions
      WHERE id = mission_id AND (client_id = auth.uid() OR prestataire_id = auth.uid())
    )
  );

-- Évaluations
CREATE POLICY "Évaluations publiques" ON public.evaluations
  FOR SELECT USING (true);

CREATE POLICY "Créer une évaluation" ON public.evaluations
  FOR INSERT WITH CHECK (
    auth.uid() = auteur_id AND
    EXISTS (
      SELECT 1 FROM public.missions
      WHERE id = mission_id AND statut = 'terminee'
        AND (client_id = auth.uid() OR prestataire_id = auth.uid())
    )
  );

-- Transactions jetons
CREATE POLICY "Voir mes transactions" ON public.transactions_jetons
  FOR SELECT USING (auth.uid() = user_id);

-- Notifications
CREATE POLICY "Voir mes notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Marquer notification lue" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- STORAGE BUCKET pour pièces d'identité
-- (À créer dans l'interface Supabase > Storage > New bucket)
-- Nom : "identites" — privé (non public)
-- ============================================================

-- ============================================================
-- FONCTION : Incrémenter le compteur de propositions
-- ============================================================
CREATE OR REPLACE FUNCTION public.increment_propositions(annonce_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.annonces SET nb_propositions = nb_propositions + 1 WHERE id = annonce_uuid;
END;
$$;

-- Trigger automatique à l'insertion d'une proposition
CREATE OR REPLACE FUNCTION public.update_nb_propositions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.annonces SET nb_propositions = nb_propositions + 1 WHERE id = NEW.annonce_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.annonces SET nb_propositions = GREATEST(nb_propositions - 1, 0) WHERE id = OLD.annonce_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_nb_propositions ON public.propositions;
CREATE TRIGGER trg_nb_propositions
  AFTER INSERT OR DELETE ON public.propositions
  FOR EACH ROW EXECUTE PROCEDURE public.update_nb_propositions();

-- ============================================================
-- INDEX pour les performances
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_annonces_statut ON public.annonces(statut);
CREATE INDEX IF NOT EXISTS idx_annonces_categorie ON public.annonces(categorie);
CREATE INDEX IF NOT EXISTS idx_annonces_client ON public.annonces(client_id);
CREATE INDEX IF NOT EXISTS idx_propositions_annonce ON public.propositions(annonce_id);
CREATE INDEX IF NOT EXISTS idx_propositions_presta ON public.propositions(prestataire_id);
CREATE INDEX IF NOT EXISTS idx_missions_client ON public.missions(client_id);
CREATE INDEX IF NOT EXISTS idx_missions_presta ON public.missions(prestataire_id);
CREATE INDEX IF NOT EXISTS idx_messages_mission ON public.messages(mission_id);
CREATE INDEX IF NOT EXISTS idx_notifs_user ON public.notifications(user_id, lu);
CREATE INDEX IF NOT EXISTS idx_profiles_pro ON public.profiles(is_pro) WHERE is_pro = true;
