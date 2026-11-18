#!/usr/bin/env node
// Fills the separate DEMO Firebase project with fictional portfolio data.
//
//   node demo/seed.js seed     # first run, refuses if orders already exist
//   node demo/seed.js reset    # wipes the demo data and accounts, seeds again
//   node demo/seed.js reset --yes   # same, without the confirmation prompt
//   node demo/seed.js reset --keep-accounts   # data only; signed-in browsers
//                                             # stay signed in
//
// Safety: the project comes from demo/demo.env.json (DEMO_FIREBASE_PROJECT_ID)
// and must match the service account (DEMO_SERVICE_ACCOUNT, default
// demo/serviceAccountKey.demo.json). The production project is refused.
//
// Orders are spread over the 30 days before the run, so a reset keeps the
// data "recent". Everything else is deterministic (fixed random seed).

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const readline = require('readline');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const PRODUCTION_PROJECT_ID = 'khazeen-app-14279';
const HERE = __dirname;
const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;
const ORDER_COUNT = 72;
const FIRST_ORDER_NUMBER = 1001;
const MERCHANT_TEST_CODE = '246810';

// ---------------------------------------------------------------------------
// Setup and safety checks
// ---------------------------------------------------------------------------

function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

function readJson(file, what) {
  if (!fs.existsSync(file)) fail(`${what} not found: ${file}`);
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

const command = process.argv[2];
const skipConfirm = process.argv.includes('--yes');
const keepAccounts = process.argv.includes('--keep-accounts');
if (!['seed', 'reset'].includes(command)) {
  fail('Usage: node demo/seed.js seed|reset [--yes] [--keep-accounts]');
}

// With the Firestore and Auth emulators running (FIRESTORE_EMULATOR_HOST),
// the script runs locally on a "demo-*" project and needs no key.
const useEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const envFile = path.join(HERE, 'demo.env.json');
const env = useEmulator && !fs.existsSync(envFile) ? {} : readJson(envFile, 'Demo config (demo/demo.env.json)');
const projectId = process.env.DEMO_FIREBASE_PROJECT_ID || env.DEMO_FIREBASE_PROJECT_ID;

if (!projectId) fail('DEMO_FIREBASE_PROJECT_ID is missing in demo/demo.env.json');
if (projectId === PRODUCTION_PROJECT_ID) {
  fail(`Refusing to touch the production project (${PRODUCTION_PROJECT_ID}).`);
}
if (useEmulator) {
  if (!projectId.startsWith('demo-') || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    fail('Emulator runs need a "demo-*" project id and both Firestore and Auth emulators.');
  }
  initializeApp({ projectId });
} else {
  const keyPath = process.env.DEMO_SERVICE_ACCOUNT || path.join(HERE, 'serviceAccountKey.demo.json');
  const serviceAccount = readJson(keyPath, 'Demo service account key');
  if (serviceAccount.project_id === PRODUCTION_PROJECT_ID) {
    fail(`Refusing to touch the production project (${PRODUCTION_PROJECT_ID}).`);
  }
  if (serviceAccount.project_id !== projectId) {
    fail(`Service account is for "${serviceAccount.project_id}", demo config is "${projectId}".`);
  }
  initializeApp({ credential: cert(serviceAccount), projectId });
}
const db = getFirestore();
const auth = getAuth();
const catalog = readJson(path.join(HERE, 'catalog.json'), 'Catalog');

// Deterministic pseudo-random numbers (mulberry32).
let randomState = 20261013;
function random() {
  randomState |= 0;
  randomState = (randomState + 0x6d2b79f5) | 0;
  let t = Math.imul(randomState ^ (randomState >>> 15), 1 | randomState);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const randomInt = (min, max) => min + Math.floor(random() * (max - min + 1));
const pick = (items) => items[Math.floor(random() * items.length)];
function pickWeighted(items, weightOf) {
  const total = items.reduce((acc, item) => acc + weightOf(item), 0);
  let roll = random() * total;
  for (const item of items) {
    roll -= weightOf(item);
    if (roll <= 0) return item;
  }
  return items[items.length - 1];
}
const round2 = (n) => Math.round(n * 100) / 100;

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(question, (answer) => {
    rl.close();
    resolve(answer.trim());
  }));
}

// ---------------------------------------------------------------------------
// Accounts (password created once, kept in demo/accounts.json)
// ---------------------------------------------------------------------------

function loadAccounts() {
  const file = path.join(HERE, 'accounts.json');
  if (fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, 'utf8'));
  const accounts = {
    companyPassword: `Demo-${crypto.randomBytes(5).toString('hex')}`,
    merchantTestCode: MERCHANT_TEST_CODE,
  };
  fs.writeFileSync(file, JSON.stringify(accounts, null, 2) + '\n');
  return accounts;
}

// ---------------------------------------------------------------------------
// Wipe
// ---------------------------------------------------------------------------

const COLLECTIONS = ['orders', 'transactions', 'products', 'users', 'suppliers', 'usernames', 'counters'];

async function wipe() {
  for (const name of COLLECTIONS) {
    await db.recursiveDelete(db.collection(name));
    console.log(`  emptied ${name}`);
  }
  if (keepAccounts) {
    console.log('  kept the Auth accounts (--keep-accounts)');
    return;
  }
  let deleted = 0;
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    if (page.users.length) {
      await auth.deleteUsers(page.users.map((u) => u.uid));
      deleted += page.users.length;
    }
    pageToken = page.pageToken;
  } while (pageToken);
  console.log(`  deleted ${deleted} Auth users`);
}

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

function addressOf(m) {
  return [m.address, m.landmark, m.city, m.governorate].filter(Boolean).join('، ');
}

const NOTES = ['', '', '', 'الاستلام بعد الظهر', 'كلّم صاحب المحل قبل ما توصل', 'الباب الخلفي للمحل', 'يفضّل قبل الساعة 2'];

/** Status for an order created [ageHours] ago, like a real day-to-day flow. */
function statusFor(ageHours) {
  const roll = random();
  if (ageHours < 20) return roll < 0.8 ? 'pending' : 'processing';
  if (ageHours < 72) {
    if (roll < 0.4) return 'processing';
    if (roll < 0.75) return 'out_for_delivery';
    if (roll < 0.9) return 'delivered';
    return 'cancelled';
  }
  return roll < 0.86 ? 'delivered' : 'cancelled';
}

function buildOrders(now, products, merchants) {
  const times = Array.from({ length: ORDER_COUNT }, () => {
    // Business hours over the last 30 days; about a fifth in the last three
    // days so the supplier has open orders to work on.
    const day = random() < 0.2 ? Math.floor(random() * 3) : Math.floor(random() * 30);
    const hour = randomInt(8, 21);
    const t = new Date(now - day * DAY);
    t.setHours(hour, randomInt(0, 59), randomInt(0, 59), 0);
    return Math.min(t.getTime(), now - HOUR - randomInt(0, 50) * 60 * 1000);
  }).sort((a, b) => a - b);

  const orders = times.map((createdMs, index) => {
    const ageHours = (now - createdMs) / HOUR;
    let status = statusFor(ageHours);
    // The newest orders are the supplier's inbox in the video.
    if (index >= ORDER_COUNT - 4) status = index === ORDER_COUNT - 4 ? 'processing' : 'pending';

    const merchant = pickWeighted(merchants, (m) => m.weight);
    const open = status === 'pending' || status === 'processing' || status === 'out_for_delivery';
    // Open orders never contain products that are now out of stock.
    const choices = products.filter((p) => !(open && p.stock === 0));
    const lineCount = randomInt(2, 6);
    const lines = [];
    const used = new Set();
    while (lines.length < lineCount) {
      const product = pickWeighted(choices, (p) => (p.category.includes('Snacks') || p.category.includes('Water') ? 3 : 2));
      if (used.has(product.id)) continue;
      used.add(product.id);
      const qty = product.moq + randomInt(0, 3) * Math.max(1, Math.ceil(product.moq / 2));
      lines.push({
        product_id: product.id,
        product_name: product.name,
        image_url: product.image_url,
        cartons_qty: qty,
        carton_price: product.carton_price,
        units_per_carton: product.units,
        line_total: qty * product.carton_price,
      });
    }
    const subtotal = lines.reduce((acc, l) => acc + l.line_total, 0);
    const number = FIRST_ORDER_NUMBER + index;
    const updatedMs = status === 'pending'
      ? createdMs
      : Math.min(now, createdMs + (status === 'delivered' ? randomInt(18, 30) : randomInt(1, 6)) * HOUR);
    return {
      id: `KZ-${number}-1`,
      number,
      status,
      createdMs,
      updatedMs,
      merchant,
      lines,
      subtotal,
      notes: pick(NOTES),
    };
  });
  return orders;
}

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

async function seed() {
  const accounts = loadAccounts();
  const now = Date.now();
  const company = catalog.company;
  const imageBase = `https://${projectId}.web.app/products`;
  const products = catalog.products.map((p) => ({ ...p, image_url: `${imageBase}/${p.id}.png` }));
  const merchants = catalog.merchants;

  // Auth accounts (existing ones are kept as they are, see --keep-accounts).
  const users = [
    {
      uid: company.uid,
      email: company.email,
      password: accounts.companyPassword,
      displayName: company.company_name,
      emailVerified: true,
    },
    ...merchants.map((m) => ({ uid: m.uid, phoneNumber: m.phone, displayName: m.business_name })),
  ];
  let createdUsers = 0;
  for (const user of users) {
    const exists = await auth.getUser(user.uid).then(() => true, () => false);
    if (exists) continue;
    await auth.createUser(user);
    createdUsers++;
  }
  console.log(`  created ${createdUsers} Auth accounts, kept ${users.length - createdUsers}`);

  const writer = db.bulkWriter();
  const created = (ms) => Timestamp.fromMillis(ms);

  // Company (supplier), username, settings, counters.
  writer.set(db.doc(`suppliers/${company.uid}`), {
    uid: company.uid,
    company_name: company.company_name,
    email: company.email,
    phone: company.phone,
    supplier_code: company.supplier_code,
    username: company.username,
    tax_id: company.tax_id,
    status: 'active',
    created_at: created(now - 60 * DAY),
  });
  writer.set(db.doc(`usernames/${company.username}`), { uid: company.uid, email: company.email });
  writer.set(db.doc(`suppliers/${company.uid}/settings/store_config`), {
    store_name: company.company_name,
    tax_id: company.tax_id,
    contact_phone: company.phone,
    support_email: company.email,
    warehouse_address: 'المنطقة الصناعية الثالثة - العاشر من رمضان (عنوان وهمي)',
    currency: 'EGP',
    low_stock_threshold: 15,
    default_min_order_qty: 1,
    auto_low_stock_alerts: true,
    auto_hide_out_of_stock: false,
    allow_backorders: false,
    is_dark_mode: true,
    language: 'English',
    compact_table_rows: false,
    refresh_rate: 'Real-time (Stream)',
    updated_at: created(now),
    updated_by: company.email,
  });
  writer.set(db.doc('counters/suppliers_counter'), { last_code: Number(company.supplier_code), updated_at: created(now) });

  // Merchants.
  merchants.forEach((m, i) => {
    writer.set(db.doc(`users/${m.uid}`), {
      uid: m.uid,
      role: 'merchant',
      business_name: m.business_name,
      owner_name: m.owner_name,
      phone_number: m.phone,
      store_category: m.store_category,
      governorate: m.governorate,
      city: m.city,
      address: m.address,
      landmark: m.landmark,
      commercial_register: null,
      latitude: m.lat,
      longitude: m.lng,
      created_at: created(now - (50 - i * 3) * DAY),
    });
  });

  // Products: `stock` in the catalog is the stock left after these orders.
  products.forEach((p, i) => {
    writer.set(db.doc(`products/${p.id}`), {
      name: p.name,
      category: p.category,
      carton_price: p.carton_price,
      units_per_carton: p.units,
      piece_price: round2(p.carton_price / p.units),
      min_order_qty: p.moq,
      is_available: p.stock > 0,
      stock_quantity: p.stock,
      supplier_code: company.supplier_code,
      supplier_uid: company.uid,
      supplier_name: company.company_name,
      image_url: p.image_url,
      created_at: created(now - (45 - (i % 10)) * DAY),
      updated_at: created(now - randomInt(0, 72) * HOUR),
    });
  });

  // Orders and the cash collected for delivered ones.
  const orders = buildOrders(now, products, merchants);
  let transactionNumber = 10000;
  for (const o of orders) {
    const m = o.merchant;
    writer.set(db.doc(`orders/${o.id}`), {
      id: o.id,
      master_order_id: `KZ-${o.number}`,
      order_number: o.number,
      merchant_id: m.uid,
      merchant_name: m.business_name,
      merchant_phone: m.phone,
      delivery_address: addressOf(m),
      delivery_notes: o.notes,
      supplier_uid: company.uid,
      supplier_code: company.supplier_code,
      supplier_name: company.company_name,
      delivery_sla: company.delivery_sla,
      items: o.lines,
      cartons_count: o.lines.reduce((acc, l) => acc + l.cartons_qty, 0),
      subtotal: o.subtotal,
      delivery_fee: 0,
      total: o.subtotal,
      status: o.status,
      payment_method: 'cash_on_delivery',
      created_at: created(o.createdMs),
      updated_at: created(o.updatedMs),
    });
    if (o.status === 'delivered') {
      transactionNumber += randomInt(1, 7);
      writer.set(db.collection('transactions').doc(), {
        id: `TRX-${transactionNumber}`,
        supplier_uid: company.uid,
        order_ref: o.id,
        client: m.business_name,
        method: 'Cash on Delivery',
        amount: o.subtotal,
        is_inflow: true,
        status: 'Completed',
        created_at: new Date(o.updatedMs).toISOString(),
        updated_at: created(o.updatedMs),
      });
    }
  }
  writer.set(db.doc('counters/orders_counter'), {
    last_number: orders[orders.length - 1].number,
    updated_at: created(now),
  });
  await writer.close();

  return { accounts, orders, products };
}

// ---------------------------------------------------------------------------
// Checks and README
// ---------------------------------------------------------------------------

async function verify() {
  const [orders, products, counter, transactions] = await Promise.all([
    db.collection('orders').get(),
    db.collection('products').get(),
    db.doc('counters/orders_counter').get(),
    db.collection('transactions').get(),
  ]);
  const problems = [];
  let maxNumber = 0;
  const byStatus = {};
  let delivered = 0;
  for (const doc of orders.docs) {
    const o = doc.data();
    const lines = o.items.reduce((acc, l) => acc + l.line_total, 0);
    if (o.items.some((l) => l.line_total !== l.cartons_qty * l.carton_price)) problems.push(`${doc.id}: line total`);
    if (lines !== o.subtotal || o.total !== o.subtotal) problems.push(`${doc.id}: total`);
    if (o.cartons_count !== o.items.reduce((acc, l) => acc + l.cartons_qty, 0)) problems.push(`${doc.id}: cartons`);
    maxNumber = Math.max(maxNumber, o.order_number);
    byStatus[o.status] = (byStatus[o.status] || 0) + 1;
    if (o.status === 'delivered') delivered += o.total;
  }
  if (counter.data().last_number !== maxNumber) problems.push('orders counter');
  const collected = transactions.docs.reduce((acc, d) => acc + d.data().amount, 0);
  if (collected !== delivered) problems.push('transactions vs delivered orders');
  const low = products.docs.filter((d) => d.data().stock_quantity > 0 && d.data().stock_quantity <= 15).length;
  const out = products.docs.filter((d) => d.data().stock_quantity === 0).length;
  return { problems, byStatus, delivered, orders: orders.size, products: products.size, low, out };
}

function writeReadme(accounts, summary) {
  if (useEmulator) return; // Don't overwrite the real demo README.
  const c = catalog.company;
  const m = catalog.merchants[0];
  const readme = `# خزين - نسخة الديمو

> بيانات وهمية بالكامل لفيديو البورتفوليو، على مشروع Firebase منفصل: \`${projectId}\`.
> الملف ده متولّد من \`node demo/seed.js\` ومستثنى من git لأن فيه باسورد الديمو.

## حسابات الديمو

### الشركة (لوحة الموردين على الويب)
| | |
|---|---|
| الشركة | ${c.company_name} |
| الإيميل | \`${c.email}\` |
| أو اسم المستخدم | \`${c.username}\` |
| الباسورد | \`${accounts.companyPassword}\` |

### التاجر (تطبيق التاجر)
| | |
|---|---|
| المحل | ${m.business_name} (${m.owner_name}) |
| رقم الموبايل | \`${m.phone.replace('+20', '0')}\` |
| كود التحقق | \`${accounts.merchantTestCode}\` |

الرقم ده لازم يكون مضاف في Firebase Console ← Authentication ← Sign-in method ← Phone ← **Phone numbers for testing**: \`${m.phone}\` بالكود \`${accounts.merchantTestCode}\`.

## منتج الفيديو (الشركة بتضيفه وهي بتصوّر)
| الحقل | القيمة |
|---|---|
| الاسم | ${catalog.video_product.name} |
| القسم | ${catalog.video_product.category} |
| سعر الكرتونة | ${catalog.video_product.carton_price} |
| عدد القطع | ${catalog.video_product.units} |
| أقل طلب | ${catalog.video_product.moq} |
| المخزون | ${catalog.video_product.stock} |
| رابط الصورة | \`https://${projectId}.web.app/products/${catalog.video_product.id}.png\` |

## الداتا الحالية
- ${summary.products} منتج: ${summary.low} قرب يخلص، و${summary.out} خلص.
- ${catalog.merchants.length} تجار، و${summary.orders} طلب في آخر 30 يوم: ${Object.entries(summary.byStatus).map(([s, n]) => `${s} ${n}`).join('، ')}.
- إجمالي المحصّل من الطلبات المسلّمة: ${summary.delivered.toLocaleString('en-US')} ج.م.

## التشغيل
\`\`\`bash
# تطبيق التاجر (من فولدر khazeen_app)
flutter run -d chrome --dart-define-from-file=demo/demo.env.json

# لوحة الموردين (من فولدر "Khazeen Web")
flutter run -d chrome --dart-define-from-file=../khazeen_app/demo/demo.env.json

# رجّع الداتا من الأول بعد التصوير (الحسابات والدخول زي ما هم)
node demo/seed.js reset --keep-accounts

# مسح كامل للداتا والحسابات (لازم تسجّل دخول تاني بعده)
node demo/seed.js reset
\`\`\`
`;
  fs.writeFileSync(path.join(HERE, 'README.md'), readme);
}

// ---------------------------------------------------------------------------

(async () => {
  console.log(`Demo project: ${projectId}`);
  if (command === 'reset') {
    if (!skipConfirm) {
      const typed = await ask(`This deletes ALL data and accounts in "${projectId}". Type the project id to continue: `);
      if (typed !== projectId) fail('Not confirmed, nothing deleted.');
    }
    console.log('Wiping demo data...');
    await wipe();
  } else {
    const existing = await db.collection('orders').limit(1).get();
    if (!existing.empty) fail('The demo project already has data. Use: node demo/seed.js reset');
  }

  console.log('Seeding...');
  const { accounts } = await seed();
  const summary = await verify();
  writeReadme(accounts, summary);

  console.log(`\n✔ ${summary.products} products, ${catalog.merchants.length} merchants, ${summary.orders} orders`);
  console.log(`  statuses: ${JSON.stringify(summary.byStatus)}`);
  console.log(`  low stock: ${summary.low}, out of stock: ${summary.out}`);
  if (summary.problems.length) fail(`Consistency problems: ${summary.problems.join(', ')}`);
  console.log('  totals, counter and transactions are consistent');
  if (!useEmulator) console.log('  accounts written to demo/README.md');
})().catch((e) => fail(e.stack || e.message));
