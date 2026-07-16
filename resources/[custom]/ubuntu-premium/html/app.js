// Boutique Premium — NUI logic. Le serveur reste la source de vérité :
// on n'envoie que l'id de l'article à l'achat.
(function () {
    const resourceName = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName() : 'ubuntu-premium';

    const app = document.getElementById('app');
    const tabsEl = document.getElementById('tabs');
    const gridEl = document.getElementById('grid');
    const balanceEl = document.getElementById('balance');
    const currencyEl = document.getElementById('currency');

    let state = { catalog: [], categories: [], owned: {}, balance: 0, active: null };

    // Icônes SVG inline par catégorie (aucune image externe — CSP FiveM).
    const ICONS = {
        starter:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 7h-3V6a3 3 0 0 0-3-3h-4a3 3 0 0 0-3 3v1H4a1 1 0 0 0-1 1v11a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8a1 1 0 0 0-1-1Z"/></svg>',
        cosmetic: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 3 12 6 8 3 3 8l3 3v10h12V11l3-3-5-5Z"/></svg>',
        vehicle:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 13 6.5 8h11L19 13m-14 0h14m-14 0v4h2m12-4v4h-2M7 17h10"/><circle cx="7.5" cy="16.5" r="1.5"/><circle cx="16.5" cy="16.5" r="1.5"/></svg>',
        rank:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m12 2 3 6 6 .9-4.5 4.3L18 20l-6-3.2L6 20l1.5-6.8L3 8.9 9 8l3-6Z"/></svg>',
        item:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 8 12 3 3 8v8l9 5 9-5V8Z"/><path d="M3 8l9 5 9-5M12 13v8"/></svg>',
        perk:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20M2 12h20"/></svg>',
    };
    const CHECK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m5 12 5 5 9-11"/></svg>';

    function formatMoney(n) {
        return String(Math.floor(n || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    }

    function post(name, body) {
        return fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => {});
    }

    function renderTabs() {
        tabsEl.innerHTML = '';
        state.categories.forEach((cat) => {
            const b = document.createElement('button');
            b.className = 'tab' + (cat.id === state.active ? ' active' : '');
            b.textContent = cat.label;
            b.onclick = () => { state.active = cat.id; renderTabs(); renderGrid(); };
            tabsEl.appendChild(b);
        });
    }

    function renderGrid() {
        gridEl.innerHTML = '';
        const items = state.catalog.filter((i) => i.category === state.active);
        if (!items.length) {
            gridEl.innerHTML = '<div class="empty">Aucun article dans cette catégorie.</div>';
            return;
        }
        items.forEach((item) => {
            const owned = item.oneTime && state.owned[item.id];
            const card = document.createElement('div');
            card.className = 'card';
            card.innerHTML = `
                <div class="card__icon">${ICONS[item.category] || ICONS.perk}</div>
                <div class="card__label">${escapeHtml(item.label)}</div>
                <div class="card__desc">${escapeHtml(item.description || '')}</div>
                <div class="card__footer">
                    <div class="card__price">${formatMoney(item.cost)} <small>${escapeHtml(state.currency)}</small></div>
                    ${owned
                        ? `<span class="btn-owned">${CHECK} Possédé</span>`
                        : `<button class="btn-buy">Acheter</button>`}
                </div>`;
            if (!owned) {
                card.querySelector('.btn-buy').onclick = () => post('buy', { id: item.id });
            }
            gridEl.appendChild(card);
        });
    }

    function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, (c) => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
        ));
    }

    function setBalance(v) { balanceEl.textContent = formatMoney(v); }

    function open(msg) {
        state.catalog = msg.data.catalog || [];
        state.categories = msg.data.categories || [];
        state.currency = msg.data.currency || 'Points';
        state.owned = msg.owned || {};
        state.balance = msg.balance || 0;
        state.active = state.categories[0] ? state.categories[0].id : null;
        currencyEl.textContent = state.currency;
        setBalance(state.balance);
        renderTabs();
        renderGrid();
        app.classList.remove('hidden');
    }

    function close() { app.classList.add('hidden'); }

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'open') open(msg);
        else if (msg.action === 'close') close();
        else if (msg.action === 'refresh') {
            state.owned = msg.owned || state.owned;
            state.balance = msg.balance != null ? msg.balance : state.balance;
            setBalance(state.balance);
            renderGrid();
        }
    });

    document.getElementById('close').onclick = () => post('close');
    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape') post('close');
    });
})();
