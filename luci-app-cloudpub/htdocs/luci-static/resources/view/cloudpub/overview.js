'use strict';
'require view';
'require form';
'require fs';
'require rpc';
'require poll';
'require ui';

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: [ 'name' ],
	expect: { '': {} }
});

function getServiceStatus() {
	return L.resolveDefault(callServiceList('cloudpub'), {}).then(function(res) {
		var running = false;
		try {
			var instances = res['cloudpub']['instances'];
			for (var name in instances)
				if (instances[name].running)
					running = true;
		} catch (e) { }
		return running;
	});
}

function getPublicationList() {
	return L.resolveDefault(
		fs.exec_direct('/usr/bin/clo', [ '-c', '/etc/cloudpub/client.toml', 'ls' ]),
		null
	);
}

function parseUpdateState(output) {
	var state = {};
	String(output || '').trim().split(/\n/).forEach(function(line) {
		var pos = line.indexOf('=');
		if (pos > 0)
			state[line.substring(0, pos)] = line.substring(pos + 1);
	});
	return state;
}

function callUpdater(action, channel) {
	return fs.exec('/usr/libexec/cloudpub-update', [ action, channel ]).then(function(res) {
		var output = [ res.stdout, res.stderr ].filter(Boolean).join('\n').trim();
		if (res.code !== 0)
			throw new Error(output || _('Update check failed.'));
		return { state: parseUpdateState(res.stdout), output: output };
	});
}

function stripAnsi(s) {
	return String(s).replace(/\u001b\[[0-9;]*m/g, '');
}

function renderStatus(isRunning) {
	if (isRunning)
		return '<em><span style="color:#2ea44f"><strong>' + _('Running') + '</strong></span></em>';
	return '<em><span style="color:#d73a49"><strong>' + _('Not running') + '</strong></span></em>';
}

function renderPublications(output) {
	var text = stripAnsi(output || '').trim();
	if (!text)
		return [ E('em', {}, [ _('No data (service is not running or no publications are registered).') ]) ];

	return text.split(/\r?\n/).map(function(line) {
		var local = line.match(/(https?:\/\/[^\s]+)\s+->/i);
		var publicUrl = line.match(/->\s+(https?:\/\/[^\s]+)/i);
		var url = publicUrl ? publicUrl[1] : (local ? local[1] : null);
		if (!url)
			return E('div', {}, [ line ]);
		var name = line.match(/\[([^\]]+)\]/);
		var attrs = { 'target': '_blank', 'rel': 'noreferrer noopener', 'title': _('Open publication') };
		var nodes = [], pos = 0;
		function addLink(value, href, start) {
			if (start < pos) return;
			if (start > pos) nodes.push(line.substring(pos, start));
			var a = Object.assign({}, attrs, { 'href': href });
			nodes.push(E('a', a, [ value ]));
			pos = start + value.length;
		}
		if (name) addLink('[' + name[1] + ']', url, name.index);
		if (local) addLink(local[1], local[1], local.index);
		if (publicUrl) addLink(publicUrl[1], publicUrl[1], publicUrl.index + 3);
		if (pos < line.length) nodes.push(line.substring(pos));
		return E('div', {}, nodes);
	});
}

function decoratePublicationNames(root, output) {
	var links = {};
	stripAnsi(output || '').split(/\r?\n/).forEach(function(line) {
		var name = line.match(/\[([^\]]+)\]/);
		var url = line.match(/->\s+(https?:\/\/[^\s]+)/i) || line.match(/(https?:\/\/[^\s]+)/i);
		if (name && url) links[name[1]] = url[1];
	});
	root.querySelectorAll('tr.cbi-section-table-row').forEach(function(row) {
		var cells = row.querySelectorAll('td');
		if (cells.length < 2) return;
		var cell = cells[1], name = (cell.textContent || '').trim(), url = links[name];
		if (!url || cell.querySelector('a')) return;
		cell.textContent = '';
		cell.appendChild(E('a', { 'href': url, 'target': '_blank', 'rel': 'noreferrer noopener', 'title': _('Open publication') }, [ name ]));
	});
}

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('cloudpub', _('CloudPub'),
			_('CloudPub client publishes local services to the Internet through a secure tunnel.') + ' ' +
			_('Get your API token in the personal dashboard:') +
			' <a href="https://cloudpub.ru/dashboard" target="_blank" rel="noreferrer">https://cloudpub.ru/dashboard</a>');

		s = m.section(form.NamedSection, 'main', 'cloudpub', _('Settings'));

		o = s.option(form.DummyValue, '_status', _('Service status'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			return '<em id="cloudpub-status">' + _('Collecting data ...') + '</em>';
		};

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;

		o = s.option(form.Value, 'token', _('API token'),
			_('Personal API token from the CloudPub dashboard.'));
		o.password = true;

		o = s.option(form.ListValue, 'log_level', _('Log level'));
		o.value('error', _('Error'));
		o.value('warn', _('Warning'));
		o.value('info', _('Info'));
		o.value('debug', _('Debug'));
		o.default = 'info';

		o = s.option(form.Flag, 'unsafe_tls', _('Skip TLS verification'),
			_('Do not verify the server TLS certificate. Only needed for self-hosted servers with a self-signed certificate.'));
		o.default = '0';

		o = s.option(form.Button, '_restart', _('Restart service'),
			_('Apply the token and re-register all publications.'));
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/etc/init.d/cloudpub', [ 'restart' ]).then(function() {
				ui.addNotification(null, E('p', _('CloudPub service restarted.')), 'info');
			}).catch(function(e) {
				ui.addNotification(null, E('p', e.message), 'error');
			});
		};

		s = m.section(form.GridSection, 'publish', _('Publications'),
			_('Local services that will be published to the Internet. After saving, the service is restarted and the publications are registered automatically.') + ' ' +
			_('Authentication can be selected when adding a publication. To change it later, edit the publication in the CloudPub dashboard.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;
		s.addModalOptions = function(modalSection, section_id) {
			if (this.map.addedSection === section_id)
				return;
			modalSection.children = modalSection.children.filter(function(option) {
				return option.option !== 'auth' && option.option !== 'acl';
			});
		};

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'));
		o.placeholder = _('optional');
		o.editable = false;

		o = s.option(form.ListValue, 'proto', _('Protocol'));
		o.value('http', 'HTTP');
		o.value('https', 'HTTPS');
		o.value('tcp', 'TCP');
		o.value('udp', 'UDP');
		o.value('webdav', 'WebDAV');
		o.value('minecraft', 'Minecraft');
		o.value('rtsp', 'RTSP');
		o.value('1c', '1C');
		o.default = 'http';

		o = s.option(form.Value, 'target', _('Local address'),
			_('Port (8080), host and port (192.168.1.10:8080) or path, depending on the protocol.'));
		o.rmempty = false;
		o.placeholder = '192.168.1.10:8080';

		o = s.option(form.ListValue, 'auth', _('Authentication'));
		o.value('none', _('None'));
		o.value('basic', _('Basic Auth'));
		o.value('form', _('Form Auth'));
		o.default = 'none';
		o.modalonly = true;
		o.validate = function(section_id, value) {
			var field = this.map.lookupOption('proto', section_id);
			var proto = field ? field[0].formvalue(field[1]) : (uci.get('cloudpub', section_id, 'proto') || 'http');
			if (value === 'form' && [ 'http', 'https', 'webdav', '1c' ].indexOf(proto) < 0)
				return _('Form Auth is available only for HTTP, HTTPS, WebDAV and 1C.');
			return true;
		};

		o = s.option(form.DynamicList, 'acl', _('Access rules (ACL)'),
			_('Access rules in the form email:role. Roles: admin, reader, writer.'));
		o.modalonly = true;
		o.placeholder = 'user@example.com:reader';
		o.depends('auth', 'basic');
		o.depends('auth', 'form');
		o.validate = function(section_id, value) {
			var field = this.map.lookupOption('proto', section_id);
			var proto = field ? field[0].formvalue(field[1]) : (uci.get('cloudpub', section_id, 'proto') || 'http');
			if (typeof(value) === 'string' && /:writer$/.test(value) && proto !== 'webdav')
				return _('The writer role is available only for WebDAV.');
			return true;
		};

		o = s.option(form.DynamicList, 'header', _('Extra HTTP headers'),
			_('Headers added to requests sent to the local server, in the form Name:Value.'));
		o.modalonly = true;
		o.placeholder = 'Host:localhost';
		o.depends('proto', 'http');
		o.depends('proto', 'https');

		return m.render().then(function(mapEl) {
			function makeUpdateRow(channel, title) {
				var status = E('span', {}, _('Update status has not been checked yet.'));
				var check = E('button', { 'class': 'cbi-button cbi-button-action', 'type': 'button' }, _('Check for updates'));
				var install = E('button', { 'class': 'cbi-button cbi-button-positive', 'type': 'button', 'style': 'display:none; margin-left:.5em' }, _('Update add-on'));
				function render(state) {
					var current = state.current || _('unknown'), latest = state.latest || current, checked = Number(state.checked || 0);
					if (state.available === '1') { status.textContent = _('Update available: %s → %s').format(current, latest); status.style.color = '#d97706'; install.style.display = ''; }
					else { status.textContent = _('The latest add-on version is installed: %s').format(current); status.style.color = '#2ea44f'; install.style.display = 'none'; }
					if (checked > 0) status.textContent += ' · ' + _('Last checked: %s').format(new Date(checked * 1000).toLocaleString());
				}
			function checkState(action) { return callUpdater(action, channel).then(function(result) { render(result.state); return result; }); }
			check.addEventListener('click', function() { check.disabled = true; check.classList.add('spinning'); checkState('check').catch(function(e) { status.textContent = e.message; status.style.color = '#d73a49'; }).then(function() { check.disabled = false; check.classList.remove('spinning'); }); });
			install.addEventListener('click', function() {
				if (!window.confirm(_('Update CloudPub now? The service will be restarted.'))) return;
				check.disabled = true; install.disabled = true; status.textContent = _('Downloading and installing the latest release ...');
				checkState('update').then(function() { ui.addNotification(null, E('p', _('CloudPub was updated successfully. The page will reload.')), 'info'); window.setTimeout(function() { window.location.reload(); }, 3000); }).catch(function(e) { status.textContent = e.message; status.style.color = '#d73a49'; }).then(function() { check.disabled = false; install.disabled = false; });
			});
			checkState('status').catch(function(e) { status.textContent = e.message; status.style.color = '#d73a49'; });
			return E('div', { 'class': 'cbi-section-node', 'style': 'margin:.5em 0' }, [ E('strong', {}, title), E('p', {}, status), check, ' ', install ]);
			}

			var updateSection = E('div', { 'class': 'cbi-section' }, [ E('h3', {}, _('Add-on updates')), E('p', {}, _('Updates are checked automatically every 24 hours.')), makeUpdateRow('stable', _('Stable release')) ]);
			var linksSection = E('div', { 'class': 'cbi-section cloudpub-links' }, [
				E('strong', {}, _('CloudPub links')),
				E('span', {}, ' · '),
				E('a', { 'href': 'https://cloudpub.ru/dashboard', 'target': '_blank', 'rel': 'noreferrer' }, _('Dashboard')),
				E('span', {}, ' · '),
				E('a', { 'href': 'https://cloudpub.ru/docs', 'target': '_blank', 'rel': 'noreferrer' }, _('Documentation')),
				E('span', {}, ' · '),
				E('a', { 'href': 'https://github.com/BrainDeLook/CloudPub-OpenWRT', 'target': '_blank', 'rel': 'noreferrer' }, _('OpenWrt project')),
				E('span', {}, ' · '),
				E('a', { 'href': 'https://cloudpub.ru/dashboard/support', 'target': '_blank', 'rel': 'noreferrer' }, _('Support'))
			]);

			poll.add(function() {
				return Promise.all([ getServiceStatus(), getPublicationList() ]).then(function(data) {
					var st = document.getElementById('cloudpub-status');
					if (st)
						st.innerHTML = renderStatus(data[0]);

					var ls = document.getElementById('cloudpub-ls');
					if (ls)
						ls.replaceChildren.apply(ls, renderPublications(data[1]));
					decoratePublicationNames(mapEl, data[1]);
				});
			}, 10);

			getPublicationList().then(function(output) { decoratePublicationNames(mapEl, output); });

			return E('div', {}, [
				mapEl,
				updateSection,
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, _('Active publications')),
					E('pre', {
						'id': 'cloudpub-ls',
						'style': 'overflow-x:auto; padding:.5em; background:#00000010; border-radius:4px;'
					}, [ _('Collecting data ...') ])
				]),
				linksSection
			]);
		});
	}
});
