// Creates `usernames/{username}` -> {uid, email} for suppliers registered
// before the supplier web app started writing it, so login by username keeps
// working without public read access to `suppliers`.
// Usage (from the project root): node scripts/backfill_usernames.js
//
// Only creates missing docs; existing `usernames` docs are left untouched.
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({ credential: cert(require(path.join(__dirname, '..', 'serviceAccountKey.json'))) });
const db = getFirestore();

async function main() {
  const suppliers = await db.collection('suppliers').get();
  let created = 0;
  for (const doc of suppliers.docs) {
    const { username, email } = doc.data();
    if (!username || !email) {
      console.log(`SKIP ${doc.id}: missing username or email`);
      continue;
    }
    const ref = db.collection('usernames').doc(String(username).toLowerCase());
    const existing = await ref.get();
    if (existing.exists) {
      console.log(`EXISTS ${ref.id}`);
      continue;
    }
    await ref.create({ uid: doc.id, email });
    created++;
    console.log(`CREATED ${ref.id}`);
  }
  console.log(`\n${created} created, ${suppliers.size} suppliers checked.`);
}

main().catch((err) => {
  console.error('Backfill failed:', err.message);
  process.exit(1);
});
