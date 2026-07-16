// Panel admin — NUI logic. Le serveur revérifie chaque action (autorité).
(function () {
    const resourceName = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName() : 'ubuntu-admin';

    const app = document.getElementById('app');
    const body = document.getElementById('players-body');
    const countEl = document.getElementById('count');
    const searchEl = document.getElementById('search');
    const modal = document.getElementById('modal');

    let players = [];
    let jobs = {};
    let moneyTypes = ['money', 'bank', 'black_money'];

    function post(name, data) {
        return fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json().catch(() => ({}))).catch(() => ({}));
    }

    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, (c) => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
        ));
    }
    function money(n) { return String(Math.floor(n || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, ' '); }

    // --- Rendu de la table -------------------------------------------------
    function render() {
        const q = searchEl.value.trim().toLowerCase();
        const list = players.filter((p) => !q
            || String(p.id).includes(q)
            || p.name.toLowerCase().includes(q)
            || (p.citizenid || '').toLowerCase().includes(q));
        countEl.textContent = list.length;
        body.innerHTML = '';
        list.forEach((p) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="mono">${p.id}</td>
                <td>${esc(p.name)}<br><small style="color:var(--text-2)">${esc(p.citizenid)}</small></td>
                <td>${esc(p.job)}</td>
                <td class="mono">${money(p.cash)}</td>
                <td class="mono">${money(p.bank)}</td>
                <td class="mono">${money(p.black)}</td>
                <td class="mono">${p.ping}</td>
                <td><div class="row-actions">
                    <button class="chip" data-a="goto">Aller</button>
                    <button class="chip" data-a="bring">Amener</button>
                    <button class="chip" data-a="spectate">Observer</button>
                    <button class="chip" data-a="revive">Réanimer</button>
                    <button class="chip" data-a="heal">Soigner</button>
                    <button class="chip" data-a="freeze">Geler</button>
                    <button class="chip" data-a="money">Argent</button>
                    <button class="chip" data-a="setjob">Job</button>
                    <button class="chip" data-a="addpoints">Points</button>
                    <button class="chip" data-a="weaponlicense">Permis arme</button>
                    <button class="chip danger" data-a="kick">Kick</button>
                    <button class="chip danger" data-a="ban">Ban</button>
                </div></td>`;
            tr.querySelectorAll('.chip').forEach((btn) => {
                btn.onclick = () => onAction(btn.getAttribute('data-a'), p);
            });
            body.appendChild(tr);
        });
    }

    // --- Actions (directes ou via modale) ----------------------------------
    function sendAction(action, targetId, args) {
        post('action', { action, targetId, args: args || {} });
    }

    function onAction(action, p) {
        switch (action) {
            case 'goto': case 'bring': case 'spectate':
            case 'revive': case 'heal':
                sendAction(action, p.id); break;
            case 'freeze':
                p._frozen = !p._frozen; sendAction('freeze', p.id, { state: p._frozen }); break;
            case 'kick':
                openModal('Expulser ' + p.name, [
                    { key: 'reason', label: 'Raison', type: 'text', value: 'Comportement inapproprié' },
                ], (v) => sendAction('kick', p.id, { reason: v.reason })); break;
            case 'ban':
                openModal('Bannir ' + p.name, [
                    { key: 'reason', label: 'Raison', type: 'text', value: 'Non-respect du règlement' },
                    { key: 'days', label: 'Durée (jours)', type: 'number', value: '1' },
                ], (v) => sendAction('ban', p.id, { reason: v.reason, days: Number(v.days) })); break;
            case 'money':
                openModal('Argent — ' + p.name, [
                    { key: 'moneyType', label: 'Type', type: 'select', options: moneyTypes },
                    { key: 'amount', label: 'Montant (négatif = retirer)', type: 'number', value: '0' },
                ], (v) => sendAction('money', p.id, { moneyType: v.moneyType, amount: Number(v.amount) })); break;
            case 'addpoints':
                openModal('Créditer des Points — ' + p.name, [
                    { key: 'amount', label: 'Montant (Points)', type: 'number', value: '1000' },
                ], (v) => sendAction('addpoints', p.id, { amount: Number(v.amount) })); break;
            case 'weaponlicense':
                openModal('Permis d\'arme — ' + p.name, [
                    { key: 'grant', label: 'Action', type: 'select', options: ['Accorder', 'Retirer'] },
                ], (v) => sendAction('weaponlicense', p.id, { grant: v.grant === 'Accorder' })); break;
            case 'setjob':
                openModal('Métier — ' + p.name, [
                    { key: 'jobName', label: 'Métier', type: 'select', options: Object.keys(jobs).sort() },
                    { key: 'grade', label: 'Grade', type: 'number', value: '0' },
                ], (v) => sendAction('setjob', p.id, { jobName: v.jobName, grade: Number(v.grade) })); break;
        }
    }

    // --- Modale générique --------------------------------------------------
    let modalConfirm = null;
    function openModal(title, fields, onConfirm) {
        document.getElementById('modal-title').textContent = title;
        const bodyEl = document.getElementById('modal-body');
        bodyEl.innerHTML = '';
        fields.forEach((f) => {
            const label = document.createElement('label');
            label.textContent = f.label; bodyEl.appendChild(label);
            let input;
            if (f.type === 'select') {
                input = document.createElement('select');
                (f.options || []).forEach((o) => {
                    const opt = document.createElement('option');
                    opt.value = o; opt.textContent = o; input.appendChild(opt);
                });
            } else {
                input = document.createElement('input');
                input.type = f.type || 'text';
                if (f.value != null) input.value = f.value;
            }
            input.id = 'f-' + f.key;
            bodyEl.appendChild(input);
        });
        modalConfirm = () => {
            const v = {};
            fields.forEach((f) => { v[f.key] = document.getElementById('f-' + f.key).value; });
            onConfirm(v);
            closeModal();
        };
        modal.classList.remove('hidden');
    }
    function closeModal() { modal.classList.add('hidden'); modalConfirm = null; }

    document.getElementById('modal-confirm').onclick = () => { if (modalConfirm) modalConfirm(); };
    document.getElementById('modal-cancel').onclick = closeModal;

    // --- Navigation & contrôles -------------------------------------------
    document.querySelectorAll('.nav').forEach((n) => {
        n.onclick = () => {
            document.querySelectorAll('.nav').forEach((x) => x.classList.remove('active'));
            n.classList.add('active');
            const view = n.getAttribute('data-view');
            document.getElementById('view-players').classList.toggle('hidden', view !== 'players');
            document.getElementById('view-server').classList.toggle('hidden', view !== 'server');
        };
    });
    searchEl.oninput = render;
    document.getElementById('refresh').onclick = refresh;
    document.getElementById('close').onclick = () => post('close');
    document.getElementById('announce-send').onclick = () => {
        const msg = document.getElementById('announce-msg').value.trim();
        if (msg) { sendAction('announce', null, { message: msg }); document.getElementById('announce-msg').value = ''; }
    };

    function refresh() {
        post('refresh').then((res) => {
            if (res && res.players) { players = res.players; jobs = res.jobs || {}; moneyTypes = res.moneyTypes || moneyTypes; render(); }
        });
    }

    // --- Messages du client ------------------------------------------------
    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'open') {
            players = m.players || []; jobs = m.jobs || {}; moneyTypes = m.moneyTypes || moneyTypes;
            render(); app.classList.remove('hidden');
        } else if (m.action === 'close') {
            app.classList.add('hidden'); closeModal();
        }
    });
    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape') {
            if (!modal.classList.contains('hidden')) closeModal();
            else post('close');
        }
    });
})();
