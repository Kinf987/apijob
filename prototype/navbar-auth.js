// navbar-auth.js — Navigation persistante pour les pages authentifiées API JOB
// Usage : ajouter <script src="navbar-auth.js"></script> après supabase-config.js
(function () {
  const PAGE = window.location.pathname.split('/').pop() || '';

  const ITEMS = [
    { icon: '🏠', label: 'Accueil',    href: 'apijob-dashboard.html',  key: 'dashboard'   },
    { icon: '📋', label: 'Annonces',   href: 'apijob-annonces.html',   key: 'annonces'    },
    { icon: '💬', label: 'Messages',   href: 'apijob-messagerie.html', key: 'messagerie', notif: true },
    { icon: '🪙', label: 'Jetons',     href: 'apijob-jetons.html',     key: 'jetons'      },
    { icon: '👤', label: 'Profil',     href: 'apijob-profil-edit.html',key: 'profil-edit' },
  ];

  /* ── CSS ── */
  const style = document.createElement('style');
  style.textContent = `
    #app-nav {
      position: fixed; bottom: 0; left: 0; right: 0; z-index: 900;
      background: #1A0008;
      border-top: 2px solid #CC0A2B;
      display: flex; justify-content: space-around; align-items: stretch;
      padding: 0 0 env(safe-area-inset-bottom, 6px);
      box-shadow: 0 -4px 24px rgba(26,0,8,0.35);
    }
    .app-nav-item {
      flex: 1; display: flex; flex-direction: column; align-items: center;
      justify-content: center; gap: 0.18rem;
      text-decoration: none; padding: 0.55rem 0.4rem;
      border-radius: 0; position: relative; transition: background 0.15s;
      -webkit-tap-highlight-color: transparent;
    }
    .app-nav-item:hover   { background: rgba(204,10,43,0.15); }
    .app-nav-item.active  { background: rgba(204,10,43,0.22); }
    .app-nav-icon { font-size: 1.25rem; line-height: 1; display: block; }
    .app-nav-label {
      font-size: 0.6rem; font-weight: 500; white-space: nowrap;
      color: rgba(255,255,255,0.45); letter-spacing: 0.02em;
      font-family: 'DM Sans', sans-serif;
    }
    .app-nav-item.active .app-nav-label { color: #CC0A2B; font-weight: 700; }
    .app-nav-badge {
      position: absolute; top: 6px; left: calc(50% + 6px);
      min-width: 8px; height: 8px; border-radius: 50%;
      background: #CC0A2B; border: 2px solid #1A0008;
      display: none;
    }
    body.has-app-nav { padding-bottom: 68px !important; }
  `;
  document.head.appendChild(style);

  /* ── HTML ── */
  const nav = document.createElement('nav');
  nav.id = 'app-nav';
  nav.setAttribute('role', 'navigation');
  nav.setAttribute('aria-label', 'Navigation principale');

  ITEMS.forEach(item => {
    const isActive = PAGE.includes(item.key);
    const a = document.createElement('a');
    a.href = item.href;
    a.className = 'app-nav-item' + (isActive ? ' active' : '');
    a.setAttribute('aria-current', isActive ? 'page' : 'false');
    a.innerHTML = `
      <span class="app-nav-icon" aria-hidden="true">${item.icon}</span>
      <span class="app-nav-label">${item.label}</span>
      ${item.notif ? '<span class="app-nav-badge" id="nav-msg-badge"></span>' : ''}
    `;
    nav.appendChild(a);
  });

  function inject() {
    document.body.appendChild(nav);
    document.body.classList.add('has-app-nav');
    loadNotifBadge();
  }

  if (document.body) {
    inject();
  } else {
    document.addEventListener('DOMContentLoaded', inject);
  }

  /* ── Badge notifications messages ── */
  async function loadNotifBadge() {
    try {
      if (typeof db === 'undefined') return;
      const { data: { session } } = await db.auth.getSession();
      if (!session) return;
      const { count } = await db
        .from('notifications')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', session.user.id)
        .eq('lu', false);
      const badge = document.getElementById('nav-msg-badge');
      if (badge && count > 0) badge.style.display = 'block';
    } catch (_) {}
  }
})();
