const assert = require('node:assert/strict');
const fs = require('node:fs');

const source = fs.readFileSync('luci-app-cloudpub/htdocs/luci-static/resources/view/cloudpub/overview.js', 'utf8');
let map;

class Section {
	constructor(parent, type) {
		this.map = parent;
		this.type = type;
		this.children = [];
	}
	option(type, name) {
		const option = { option: name, value() {}, depends() {} };
		this.children.push(option);
		return option;
	}
}

class Map {
	constructor() {
		map = this;
		this.sections = [];
	}
	section(type, name) {
		const section = new Section(this, name);
		this.sections.push(section);
		return section;
	}
	render() { return new Promise(() => {}); }
}

const form = { Map };
const view = { extend: (definition) => definition };
const rpc = { declare: () => () => ({}) };
const createView = new Function('view', 'form', 'fs', 'rpc', 'poll', 'ui', 'L', 'E', '_', 'uci', source);
createView(view, form, {}, rpc, {}, {}, {}, () => {}, (value) => value, {}).render();

const publications = map.sections.find((section) => section.type === 'publish');
assert.ok(publications, 'publication section exists');
assert.equal(publications.children.find((option) => option.option === 'auth').modalonly, true);

const fields = () => ({ children: publications.children.map((option) => ({ option: option.option })) });
map.addedSection = 'new-publication';
const creation = fields();
publications.addModalOptions(creation, 'new-publication');
assert.ok(creation.children.some((option) => option.option === 'auth'));
assert.ok(creation.children.some((option) => option.option === 'acl'));

map.addedSection = undefined;
const editing = fields();
publications.addModalOptions(editing, 'existing-publication');
assert.ok(!editing.children.some((option) => option.option === 'auth'));
assert.ok(!editing.children.some((option) => option.option === 'acl'));
assert.ok(editing.children.some((option) => option.option === 'target'));

console.log('LuCI creation-only authentication tests passed');
