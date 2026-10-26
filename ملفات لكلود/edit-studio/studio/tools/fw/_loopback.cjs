// _loopback.cjs — Windows: `node --require _loopback.cjs <remotion-cli.js> …` (blocks.mjs run()) keeps the servers of
// Remotion's render and studio on 127.0.0.1. Remotion binds '::' (every network) and its CLI has no flag for the loopback,
// so node.exe gets a firewall window on the first render and, if allowed, the project is served to the LAN.
// A listen() whose host is '::', '0.0.0.0' or missing gets host 127.0.0.1; '::1', other hosts and pipes are left alone.
// On Windows, 127.0.0.1:<port> can still be bound while another program listens on [::]:<port>, and that program would
// then answer localhost on ::1 (Chrome tries ::1 first). So when something answers on ::1:<port>, the listen fails with
// EADDRINUSE, as the '::' bind would have, and Remotion's port search moves on to the next port.
// The same file as video-edit/scripts/_loopback.cjs: the studio cannot rely on where video-edit is installed.
'use strict';
const net = require('net');
const listen = net.Server.prototype.listen;
const wild = (h) => h == null || h === '' || h === '::' || h === '0.0.0.0';

function answersOnV6(port, cb) {
  const s = net.connect({ port, host: '::1' });
  let done = false;
  const end = (yes) => { if (done) return; done = true; s.destroy(); cb(yes); };
  s.once('connect', () => end(true));
  s.once('error', () => end(false));   // refused, or no IPv6
  s.setTimeout(1000, () => end(false));
}

net.Server.prototype.listen = function (...a) {
  const o = a[0];
  let port;
  if (o && typeof o === 'object' && o.path == null && o.handle == null && o.fd == null && o._handle == null) {
    if (!wild(o.host)) return listen.apply(this, a);
    a[0] = { ...o, host: '127.0.0.1' }; port = Number(o.port) || 0;
  } else if (typeof o === 'number' || (typeof o === 'string' && /^\d+$/.test(o))) {
    if (typeof a[1] === 'string') { if (!wild(a[1])) return listen.apply(this, a); a[1] = '127.0.0.1'; }
    else a.splice(1, 0, '127.0.0.1');
    port = Number(o);
  } else return listen.apply(this, a);
  if (!port) return listen.apply(this, a);
  answersOnV6(port, (busy) => {
    if (!busy) return listen.apply(this, a);
    this.emit('error', Object.assign(new Error(`listen EADDRINUSE: address already in use [::1]:${port}`),
      { code: 'EADDRINUSE', errno: -4091, syscall: 'listen', address: '::1', port }));
  });
  return this;
};
