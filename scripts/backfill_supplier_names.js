// Copies suppliers/{uid}.company_name onto every product as `supplier_name`
// (merchants can no longer read `suppliers` once firestore.rules is deployed).
// Run once before deploying the rules:  node scripts/backfill_supplier_names.js
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({ credential: cert(require('../serviceAccountKey.json')) });
const db = getFirestore();

(async () => {
  const products = await db.collection('products').get();
  const names = {};
  let updated = 0;

  for (const doc of products.docs) {
    const uid = doc.data().supplier_uid;
    if (!uid) {
      console.log(`skip ${doc.id}: no supplier_uid`);
      continue;
    }
    if (!(uid in names)) {
      const supplier = await db.collection('suppliers').doc(uid).get();
      names[uid] = supplier.exists ? supplier.data().company_name : null;
    }
    if (!names[uid]) {
      console.log(`skip ${doc.id}: supplier ${uid} has no company_name`);
      continue;
    }
    if (doc.data().supplier_name === names[uid]) continue;
    await doc.ref.update({ supplier_name: names[uid] });
    updated++;
    console.log(`${doc.id} -> ${names[uid]}`);
  }
  console.log(`Done: ${updated} of ${products.size} products updated.`);
})();
