// Seeds the Firestore `products` collection with sample Egyptian FMCG items.
// Usage (from the project root): node scripts/seed_products.js
//
// Doc ids are fixed, so re-running overwrites the same docs instead of
// creating duplicates. Field names follow ProductRepository.fromFirestore.
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

// Categories must match the chips in lib/screens/home_screen.dart.
const products = [
  {
    id: 'seed_sugar_1kg',
    name: 'سكر أبيض ناعم 1 كجم (شوال 10 كجم)',
    category: 'بقالة وزيوت',
    carton_price: 365,
    units_per_carton: 10,
    stock_quantity: 400,
  },
  {
    id: 'seed_crystal_oil_800ml',
    name: 'زيت كريستال خليط 800 مل',
    category: 'بقالة وزيوت',
    carton_price: 980,
    units_per_carton: 12,
    stock_quantity: 250,
  },
  {
    id: 'seed_molto_magnum',
    name: 'مولتو ماجنم كرواسون شوكولاتة',
    category: 'مستلزمات تصنيع وحلويات',
    carton_price: 220,
    units_per_carton: 24,
    stock_quantity: 600,
  },
  {
    id: 'seed_el_arosa_tea_250g',
    name: 'شاي العروسة ناعم 250 جم',
    category: 'بقالة وزيوت',
    carton_price: 1430,
    units_per_carton: 24,
    stock_quantity: 180,
  },
  {
    id: 'seed_juhayna_milk_1l',
    name: 'لبن جهينة كامل الدسم 1 لتر',
    category: 'ألبان وأجبان',
    carton_price: 520,
    units_per_carton: 12,
    stock_quantity: 300,
  },
  {
    id: 'seed_nestle_water_1500ml',
    name: 'مياه نستله 1.5 لتر',
    category: 'مياه ومشروبات',
    carton_price: 50,
    units_per_carton: 6,
    stock_quantity: 0,
    is_available: false,
  },
];

// Demo products belong to this supplier (`suppliers/{uid}.username`), so they
// show in that supplier's web dashboard and orders reach them.
const SUPPLIER_USERNAME = 'kiro-20';

async function main() {
  const owner = await db.collection('usernames').doc(SUPPLIER_USERNAME).get();
  if (!owner.exists) throw new Error(`usernames/${SUPPLIER_USERNAME} not found`);
  const supplierUid = owner.data().uid;
  const supplier = (await db.collection('suppliers').doc(supplierUid).get()).data();

  const batch = db.batch();
  for (const { id, ...fields } of products) {
    batch.set(db.collection('products').doc(id), {
      is_available: true,
      min_order_qty: 1,
      image_url: '',
      supplier_uid: supplierUid,
      supplier_code: String(supplier.supplier_code),
      // Merchants read the supplier name from the product (firestore.rules).
      supplier_name: supplier.company_name,
      ...fields,
      // Same as the supplier web app: what one piece costs within the carton.
      piece_price: Math.round((fields.carton_price / fields.units_per_carton) * 100) / 100,
      created_at: FieldValue.serverTimestamp(),
      updated_at: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Wrote ${products.length} products. Verifying...\n`);

  const snaps = await db.getAll(...products.map((p) => db.collection('products').doc(p.id)));
  let ok = 0;
  for (const snap of snaps) {
    if (!snap.exists) {
      console.log(`MISSING  ${snap.id}`);
      continue;
    }
    ok++;
    const d = snap.data();
    console.log(
      `OK  ${snap.id.padEnd(26)} ${d.name} | ${d.category} | ` +
        `قطعة ${d.piece_price} ج.م | كرتونة ${d.carton_price} ج.م (${d.units_per_carton}) | ` +
        `مخزون ${d.stock_quantity} | ${d.is_available ? 'متاح' : 'غير متاح'} | مورد #${d.supplier_code}`
    );
  }
  console.log(`\n${ok}/${products.length} verified in project ${serviceAccount.project_id}.`);
  if (ok !== products.length) process.exitCode = 1;
}

main().catch((err) => {
  console.error('Seeding failed:', err.message);
  process.exit(1);
});
