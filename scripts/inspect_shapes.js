// Prints the field names and types of existing docs (no values), so the
// Firestore rules can be checked against real data.
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

initializeApp({ credential: cert(require('../serviceAccountKey.json')) });
const db = getFirestore();

function typeOf(v) {
  if (v === null) return 'null';
  if (v instanceof Timestamp) return 'timestamp';
  if (Array.isArray(v)) return `list[${v.length}]`;
  return typeof v;
}

function shape(data) {
  return Object.keys(data).sort().map((k) => `${k}:${typeOf(data[k])}`).join(', ');
}

(async () => {
  for (const name of ['counters', 'suppliers', 'usernames', 'users', 'products', 'orders', 'transactions', 'settings', 'categories']) {
    const snap = await db.collection(name).get();
    console.log(`\n=== ${name} (${snap.size} docs)`);
    const seen = new Set();
    for (const doc of snap.docs) {
      const s = shape(doc.data());
      if (seen.has(s)) continue;
      seen.add(s);
      const extra = name === 'suppliers' ? ` status=${doc.data().status}` : '';
      console.log(`- id=${name === 'counters' || name === 'orders' ? doc.id : '<id>'}${extra}\n  ${s}`);
      if (name === 'orders' && doc.data().items?.[0]) console.log(`  item: ${shape(doc.data().items[0])}`);
      if (name === 'counters') console.log(`  values: ${JSON.stringify(doc.data(), (k, v) => (k === 'updated_at' ? undefined : v))}`);
    }
    if (name === 'suppliers') {
      for (const doc of snap.docs) {
        const subs = await doc.ref.listCollections();
        for (const c of subs) {
          const s = await c.get();
          s.docs.forEach((d) => console.log(`  sub ${c.id}/${d.id}: ${shape(d.data())}`));
        }
      }
    }
  }
})();
