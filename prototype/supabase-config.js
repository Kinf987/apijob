// ============================================================
// supabase-config.js — Configuration Supabase pour API JOB
// ============================================================
// ÉTAPE 1 : Créez votre projet sur https://supabase.com
// ÉTAPE 2 : Allez dans Settings > API et copiez vos clés
// ÉTAPE 3 : Remplacez les valeurs ci-dessous

const SUPABASE_URL  = 'https://douncwfmczjpnwcpfsah.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRvdW5jd2ZtY3pqcG53Y3Bmc2FoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0OTYyOTgsImV4cCI6MjA5MjA3MjI5OH0.UGOwjNd1oGD563dkOnTXQiAYNQr3dSb4lJjXB0OR97o';

// Client Supabase (nécessite le CDN chargé avant ce fichier)
const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true
  }
});

// ============================================================
// AUTH — UTILITAIRES
// ============================================================

async function getSession() {
  const { data: { session } } = await db.auth.getSession();
  return session;
}

async function getCurrentUser() {
  const session = await getSession();
  if (!session) return null;
  const { data: profile, error } = await db
    .from('profiles')
    .select('*')
    .eq('id', session.user.id)
    .single();
  if (error) { console.error('Profil introuvable:', error); return null; }
  return profile;
}

// Redirige vers apijob-auth.html si non connecté, retourne le profil sinon
async function requireAuth() {
  const user = await getCurrentUser();
  if (!user) { window.location.href = 'apijob-auth.html'; return null; }
  if (user.is_banned) { await db.auth.signOut(); window.location.href = 'apijob-auth.html'; return null; }
  return user;
}

async function signOut() {
  await db.auth.signOut();
  window.location.href = 'apijob-auth.html?logout=1';
}

// ============================================================
// NOTIFICATIONS
// ============================================================

async function createNotification(userId, type, titre, message, lien = null) {
  await db.from('notifications').insert({ user_id: userId, type, titre, message, lien });
}

async function getNbNotifNonLues(userId) {
  const { count } = await db
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('lu', false);
  return count || 0;
}

// ============================================================
// JETONS
// ============================================================

async function getTokens(userId) {
  const { data } = await db.from('profiles').select('tokens, is_pro, pro_expires_at').eq('id', userId).single();
  return data;
}

// ============================================================
// UTILITAIRES UI
// ============================================================

function showMsg(elementId, message, isError = true) {
  const el = document.getElementById(elementId);
  if (!el) return;
  el.textContent = message;
  el.style.display = 'block';
  el.style.color = isError ? 'var(--rouge)' : 'var(--vert, #1A7A4A)';
}

function hideMsg(elementId) {
  const el = document.getElementById(elementId);
  if (el) el.style.display = 'none';
}

function setLoading(btnId, loading, texteOriginal) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  btn.disabled = loading;
  btn.textContent = loading ? 'Chargement...' : texteOriginal;
}

function formatDate(dateStr) {
  const date = new Date(dateStr);
  const now  = new Date();
  const diff = now - date;
  const mins = Math.floor(diff / 60000);
  const hrs  = Math.floor(mins / 60);
  const days = Math.floor(hrs / 24);
  if (mins  <  1) return 'À l\'instant';
  if (mins  < 60) return `Il y a ${mins} min`;
  if (hrs   < 24) return `Il y a ${hrs}h`;
  if (days  ==  1) return 'Hier';
  if (days  <  7) return `Il y a ${days} jours`;
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
}

function catEmoji(cat) {
  const map = {
    'Jardinage': '🌿', 'Ménage': '🏠', 'Plomberie': '🔧', 'Électricité': '⚡',
    'Bricolage': '🛠️', 'Déménagement': '📦', 'Baby-sitting': '👶',
    'Gardiennage': '🏡', 'Animaux': '🐾', 'Peinture': '🎨',
    'Transports': '🚗', 'Mécanique': '🔩', 'Aide à la personne': '🤝',
    'Informatique': '💻', 'Cours particuliers': '🎓', 'Enseignement': '📚',
    'Démarches & administratif': '📋', 'Aménagement & déco': '🛋️',
    'Événementiel': '🎉', 'Bureautique & administratif': '💼',
    'Bien-être': '🧘', 'Pisciniste': '🏊', 'Climatisation': '❄️', 'Artisanat': '🗿',
    'Maçonnerie': '🧱', 'Menuiserie': '🪵', 'Carrelage & faïence': '🪟', 'Toiture': '🏗️',
    'Entretien de bateau': '⛵', 'Services nautiques': '🎣', 'Coiffure à domicile': '✂️',
    'Traiteur & chef à domicile': '👨‍🍳', 'Massage à domicile': '💆', 'Photographie': '📷',
    'Graphisme & design': '🖌️', 'Création de contenu': '📱', 'Couture & retouches': '🧵',
    'Sécurité & surveillance': '🔐', 'Autre': '✨'
  };
  return map[cat] || '✨';
}

function urgenceBadge(urgence) {
  const map = {
    'Dès que possible': { cls: 'badge-urgent',   label: '⚡ Urgent'      },
    'Cette semaine':    { cls: 'badge-semaine',   label: '📅 Cette semaine'},
    'Ce weekend':       { cls: 'badge-weekend',   label: '🌴 Ce weekend'  },
    'Date précise':     { cls: 'badge-flexible',  label: '🗓️ Date précise' },
    'flexible':         { cls: 'badge-flexible',  label: '🕐 Flexible'    }
  };
  return map[urgence] || { cls: 'badge-flexible', label: urgence };
}

// Met à jour le badge de notifications dans la nav si l'élément existe
async function updateNotifBadge(userId) {
  const nb = await getNbNotifNonLues(userId);
  const dot = document.querySelector('.notif-dot');
  if (dot) dot.style.display = nb > 0 ? 'block' : 'none';
  const badge = document.getElementById('notif-count');
  if (badge) badge.textContent = nb > 0 ? nb : '';
}

// Met à jour le compteur de jetons dans la nav si l'élément existe
async function updateTokensBadge(userId) {
  const data = await getTokens(userId);
  if (!data) return;
  const el = document.getElementById('jetons-count');
  if (el) el.textContent = data.is_pro ? '∞' : data.tokens;
}
