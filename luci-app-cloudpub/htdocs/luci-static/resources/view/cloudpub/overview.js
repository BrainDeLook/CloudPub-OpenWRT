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

function stripAnsi(s) {
	return String(s).replace(/\u001b\[[0-9;]*m/g, '');
}

function renderPublications(output) {
	var text = stripAnsi(output || '').trim();
	if (!text)
		return [ E('em', {}, [ _('No data (service is not running or no publications are registered).') ]) ];

	return text.split(/\r?\n/).map(function(line) {
		/* Prefer the public HTTPS endpoint after the arrow; fall back to HTTP
		 * for installations that publish without TLS. */
		var match = line.match(/(https:\/\/[^\s]+)/i) || line.match(/(http:\/\/[^\s]+)/i);
		if (!match)
			return E('div', {}, [ line ]);

		var before = line.substring(0, match.index);
		var url = match[1];
		var after = line.substring(match.index + url.length);
		return E('div', {}, [
			before,
			E('a', {
				'href': url,
				'target': '_blank',
				'rel': 'noreferrer noopener',
				'title': _('Open publication')
			}, [ url ]),
			after
		]);
	});
}

function renderStatus(isRunning) {
	if (isRunning)
		return '<em><span style="color:#2ea44f"><strong>' + _('Running') + '</strong></span></em>';
	return '<em><span style="color:#d73a49"><strong>' + _('Not running') + '</strong></span></em>';
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

function callUpdater(action) {
	return fs.exec('/usr/libexec/cloudpub-update', [ action ]).then(function(res) {
		var output = [ res.stdout, res.stderr ].filter(Boolean).join('\n').trim();
		if (res.code !== 0)
			throw new Error(output || _('Update check failed.'));
		return {
			state: parseUpdateState(res.stdout),
			output: output
		};
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
			var updateStatus = E('p', { 'id': 'cloudpub-update-status' }, [
				_('Update status has not been checked yet.')
			]);
			var updateButton = E('button', {
				'class': 'cbi-button cbi-button-positive',
				'style': 'display:none',
				'click': function(ev) {
					ev.preventDefault();
					if (!window.confirm(_('Update CloudPub now? The service will be restarted.')))
						return;

					ui.showModal(_('Updating CloudPub'), [
						E('p', { 'class': 'spinning' }, _('Downloading and installing the latest release ...'))
					]);

					callUpdater('update').then(function(result) {
						ui.hideModal();
						ui.addNotification(null, E('div', {}, [
							E('p', {}, _('CloudPub was updated successfully. The page will reload.')),
							result.output ? E('pre', { 'style': 'white-space:pre-wrap' }, [ result.output ]) : ''
						]), 'info');
						window.setTimeout(function() { window.location.reload(); }, 3000);
					}).catch(function(e) {
						ui.hideModal();
						ui.addNotification(null, E('p', e.message), 'error');
					});
				}
			}, [ _('Update add-on') ]);
			var checkButton = E('button', {
				'class': 'cbi-button cbi-button-action',
				'click': function(ev) {
					ev.preventDefault();
					checkButton.disabled = true;
					checkButton.classList.add('spinning');
					callUpdater('check').then(function(result) {
						renderUpdateState(result.state);
						checkButton.disabled = false;
						checkButton.classList.remove('spinning');
					}).catch(function(e) {
						checkButton.disabled = false;
						checkButton.classList.remove('spinning');
						ui.addNotification(null, E('p', e.message), 'error');
					});
				}
			}, [ _('Check for updates') ]);

			function renderUpdateState(state) {
				var current = state.current || _('unknown');
				var latest = state.latest || current;
				var checked = Number(state.checked || 0);

				if (state.available === '1') {
					updateStatus.textContent = _('Update available: %s → %s').format(current, latest);
					updateStatus.style.color = '#d97706';
					updateButton.style.display = '';
				}
				else {
					updateStatus.textContent = _('The latest add-on version is installed: %s').format(current);
					updateStatus.style.color = '#2ea44f';
					updateButton.style.display = 'none';
				}

				if (checked > 0)
					updateStatus.textContent += ' · ' + _('Last checked: %s').format(new Date(checked * 1000).toLocaleString());
			}

			function refreshUpdateState() {
				return callUpdater('status').then(function(result) {
					renderUpdateState(result.state);
				});
			}

			refreshUpdateState().catch(function(e) {
				updateStatus.textContent = e.message;
				updateStatus.style.color = '#d73a49';
			});

			poll.add(function() {
				return Promise.all([ getServiceStatus(), getPublicationList(), refreshUpdateState() ]).then(function(data) {
					var st = document.getElementById('cloudpub-status');
					if (st)
						st.innerHTML = renderStatus(data[0]);

					var ls = document.getElementById('cloudpub-ls');
					if (ls)
						ls.replaceChildren.apply(ls, renderPublications(data[1]));
				});
			}, 10);

			return E('div', {}, [
				mapEl,
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, _('Add-on updates')),
					E('p', {}, _('Updates are checked automatically every 24 hours.')),
					updateStatus,
					E('div', { 'class': 'cbi-section-node' }, [
						checkButton,
						' ',
						updateButton
					])
				]),
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, _('Active publications')),
					E('pre', {
						'id': 'cloudpub-ls',
						'style': 'overflow-x:auto; padding:.5em; background:#00000010; border-radius:4px;'
					}, [ _('Collecting data ...') ])
				])
			]);
		});
	}
});
