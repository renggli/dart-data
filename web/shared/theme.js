(() => {
  const THEME_KEY = 'data_theme';
  const SIDEBAR_KEY = 'data_sidebar_collapsed';
  const root = document.documentElement;
  const sunSvg =
    '<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="3"/><path d="M8 1.5v1.5M8 13v1.5M1.5 8H3M13 8h1.5M3.4 3.4l1 1M11.6 11.6l1 1M12.6 3.4l-1 1M4.4 11.6l-1 1"/></svg>';
  const moonSvg =
    '<svg viewBox="0 0 16 16"><path d="M13 9.5A5.5 5.5 0 0 1 6.5 3a5.5 5.5 0 1 0 6.5 6.5z"/></svg>';

  root.classList.add('no-transition');

  const savedTheme = localStorage.getItem(THEME_KEY);
  const initialTheme =
    savedTheme === 'light' || savedTheme === 'dark' ? savedTheme : 'dark';
  root.setAttribute('data-theme', initialTheme);

  function syncButtons(theme) {
    document.querySelectorAll('[data-theme-toggle]').forEach((btn) => {
      btn.innerHTML = theme === 'light' ? moonSvg : sunSvg;
      btn.title =
        theme === 'light' ? 'Switch to dark theme' : 'Switch to light theme';
    });
  }

  window.addEventListener('DOMContentLoaded', () => {
    const savedSidebar = localStorage.getItem(SIDEBAR_KEY);
    const shouldCollapse =
      savedSidebar !== null
        ? savedSidebar === 'true'
        : window.innerWidth < 768;
    document.body.classList.toggle('sidebar-collapsed', shouldCollapse);

    syncButtons(root.getAttribute('data-theme') || 'dark');
    document.querySelectorAll('[data-theme-toggle]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const cur = root.getAttribute('data-theme') || 'dark';
        const next = cur === 'light' ? 'dark' : 'light';
        root.setAttribute('data-theme', next);
        localStorage.setItem(THEME_KEY, next);
        syncButtons(next);
      });
    });

    document.querySelectorAll('[data-sidebar-toggle]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const collapsed = document.body.classList.toggle('sidebar-collapsed');
        localStorage.setItem(SIDEBAR_KEY, String(collapsed));
      });
    });

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        root.classList.remove('no-transition');
      });
    });
  });
})();
