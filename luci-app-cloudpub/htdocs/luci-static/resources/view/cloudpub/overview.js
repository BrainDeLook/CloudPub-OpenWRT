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

function checkForUpdate(channel) {
	return L.resolveDefault(
		fs.exec_direct('/usr/libexec/cloudpub-update-check', [ channel ]),
		''
	).then(function(output) {
		var parts = String(output || '').trim().split('\t');
		return {
			status: parts[0] || '',
			channel: parts[1] || channel,
			tag: parts[2] || '',
			name: parts[3] || parts[2] || '',
			current: parts[4] || ''
		};
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

function renderPublications(container, output) {
	var text = stripAnsi(output || '').trim();
	while (container.firstChild)
		container.removeChild(container.firstChild);

	if (!text) {
		container.appendChild(document.createTextNode(_('No data (service is not running or no publications are registered).')));
		return;
	}

	text.split(/\r?\n/).forEach(function(line) {
		var match = line.match(/^(\S+\s+[0-9a-f-]{36})\s+(?:\[([^\]]+)\]\s+)?(https?:\/\/\S+)\s+->\s+(https?:\/\/\S+)$/i);
		var row = E('div', {});
		if (!match) {
			row.textContent = line;
		} else {
			row.appendChild(document.createTextNode(match[1] + ' '));
			if (match[2]) {
				row.appendChild(E('a', {
					'href': match[4], 'target': '_blank', 'rel': 'noreferrer'
				}, '[' + match[2] + ']'));
				row.appendChild(document.createTextNode(' '));
			}
			row.appendChild(E('a', {
				'href': match[3], 'target': '_blank', 'rel': 'noreferrer'
			}, match[3]));
			row.appendChild(document.createTextNode(' -> '));
			row.appendChild(E('a', {
				'href': match[4], 'target': '_blank', 'rel': 'noreferrer'
			}, match[4]));
		}
		container.appendChild(row);
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
			_('Local services that will be published to the Internet. After saving, the service is restarted and the publications are registered automatically.'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'));
		o.placeholder = _('optional');

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

		o = s.option(form.DynamicList, 'acl', _('Access rules (ACL)'),
			_('Access rules in the form email:role. Roles: admin, reader, writer.'));
		o.modalonly = true;
		o.placeholder = 'user@example.com:reader';
		o.depends('auth', 'basic');
		o.depends('auth', 'form');

		o = s.option(form.DynamicList, 'header', _('Extra HTTP headers'),
			_('Headers added to requests sent to the local server, in the form Name:Value.'));
		o.modalonly = true;
		o.placeholder = 'Host:localhost';
		o.depends('proto', 'http');
		o.depends('proto', 'https');

		return m.render().then(function(mapEl) {
			function makeUpdateRow(channel, title) {
				var selectedTag = '';
				var status = E('span', {}, _('Not checked'));
				var checkButton = E('button', {
					'class': 'cbi-button', 'type': 'button'
				}, _('Check'));
				var installButton = E('button', {
					'class': 'cbi-button cbi-button-action', 'type': 'button',
					'style': 'display:none; margin-left:.5em'
				}, _('Install update'));

				checkButton.addEventListener('click', function() {
					checkButton.disabled = true;
					installButton.style.display = 'none';
					status.textContent = _('Checking ...');
					checkForUpdate(channel).then(function(info) {
						selectedTag = info.tag;
						if (!info.tag)
							throw new Error(_('Update check failed'));
						if (info.status === 'update') {
							status.textContent = _('New release available: ') + info.tag;
							installButton.textContent = _('Install ') + info.tag;
							installButton.style.display = '';
						} else {
							status.textContent = _('No new releases. Latest: ') + info.tag;
						}
					}).catch(function() {
						status.textContent = _('Update check failed');
					}).then(function() {
						checkButton.disabled = false;
					});
				});

				installButton.addEventListener('click', function() {
					if (!selectedTag)
						return;
					checkButton.disabled = true;
					installButton.disabled = true;
					status.textContent = _('Installing update ...');
					fs.exec('/usr/libexec/cloudpub-update', [ selectedTag ]).then(function() {
						installButton.style.display = 'none';
						status.textContent = _('Update installed: reload LuCI if needed.');
						ui.addNotification(null, E('p', _('CloudPub update installed.')), 'info');
					}).catch(function(e) {
						status.textContent = _('Update failed');
						ui.addNotification(null, E('p', e.message || _('Update failed')), 'error');
					}).then(function() {
						checkButton.disabled = false;
						installButton.disabled = false;
					});
				});

				return E('div', { 'style': 'display:flex; gap:.75em; align-items:center; flex-wrap:wrap; margin:.5em 0' }, [
					E('strong', { 'style': 'min-width:10em' }, title), checkButton, status, installButton
				]);
			}

			var updateSection = E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Updates')),
				makeUpdateRow('stable', _('Stable release')),
				makeUpdateRow('beta', _('Beta release'))
			]);
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
						renderPublications(ls, data[1]);
				});
			}, 10);

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
