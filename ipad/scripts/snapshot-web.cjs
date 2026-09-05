// Build-time snapshot only: never modifies the Windows frontend or backend.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const source = path.resolve(root, '../desktop/ui');
const output = path.join(root, 'Web');
const files = ['index.html', 'app.js', 'exportService.js', 'dateContract.js', 'styles.css', 'document-print.css', 'usability-2026.css'];
const entries = [];
fs.mkdirSync(path.join(output, 'assets'), { recursive: true });
for (const name of [...files, ...fs.readdirSync(path.join(source, 'assets')).filter(n => /\.(png|svg)$/.test(n)).map(n => 'assets/' + n)]) {
  const raw = fs.readFileSync(path.join(source, name));
  const data = /\.png$/.test(name) ? raw : Buffer.from(raw.toString().replace(/\r\n/g, '\n'));
  entries.push({ file: name, sha256: crypto.createHash('sha256').update(data).digest('hex') });
  if (name === 'index.html') {
    const csp = `<meta http-equiv="Content-Security-Policy" content="default-src 'self' file:; script-src 'self' file:; style-src 'self' file: 'unsafe-inline'; img-src 'self' file: data: blob: https://www.houseofpizzagaffney.com; connect-src 'self' file: blob: data:; frame-src 'none'; object-src 'none'; base-uri 'none'">`;
    fs.writeFileSync(path.join(output, name), data.toString().replace('<head>', '<head>\n  ' + csp).replace('</head>', '  <link rel="stylesheet" href="./ipad.css">\n</head>').replace('  <script src="./dateContract.js">', '  <script src="./native.js"></script>\n  <script src="./dateContract.js">'));
  } else fs.writeFileSync(path.join(output, name), data);
}
for (const file of ['native.js', 'ipad.css', 'ipad-print.css']) fs.copyFileSync(path.join(root, 'Bridge', file), path.join(output, file));
fs.writeFileSync(path.join(output, 'source-manifest.json'), JSON.stringify({ base: 'HOP Command Center desktop 1.3.7, current local working copy', files: entries }, null, 2) + '\n');
console.log(`Snapshotted ${entries.length} explicitly selected public UI files; no database, credentials, or employee records included.`);
