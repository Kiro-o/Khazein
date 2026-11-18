// Firestore rules tests, run against the local emulator:
//   npm run test:rules
// Each test writes data the same way the merchant app / supplier web app do.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  getDocs,
  collection,
  query,
  where,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const MERCHANT = 'merchant_1';
const OTHER_MERCHANT = 'merchant_2';
const SUPPLIER = 'supplier_1';
const PHONE = '+201000000001';
// OrderRepository.maxItemsPerSupplier in the merchant app.
const MAX_ITEMS = Number(process.env.MAX_ITEMS ?? 25);

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-khazeen',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', MERCHANT), {
      uid: MERCHANT,
      role: 'merchant',
      business_name: 'سوبر ماركت التجربة',
      owner_name: 'تاجر تجربة',
      phone_number: PHONE,
      store_category: 'سوبر ماركت',
      governorate: 'الإسكندرية',
      city: 'العطارين',
      address: 'شارع النبي دانيال رقم 10',
      landmark: null,
      commercial_register: null,
      latitude: 31.19,
      longitude: 29.9,
      created_at: new Date(),
    });
    await setDoc(doc(db, 'suppliers', SUPPLIER), {
      uid: SUPPLIER,
      company_name: 'kiro',
      email: 'kiro@example.com',
      phone: '',
      supplier_code: '20',
      username: 'kiro-20',
      tax_id: '',
      status: 'active',
      created_at: new Date(),
    });
    await setDoc(doc(db, 'counters', 'orders_counter'), {
      last_number: 1001,
      updated_at: new Date(),
    });
    await setDoc(doc(db, 'products', 'milk'), {
      name: 'حليب الخير',
      category: 'ألبان وأجبان',
      carton_price: 500,
      units_per_carton: 20,
      piece_price: 25,
      min_order_qty: 2,
      is_available: true,
      supplier_code: '20',
      supplier_uid: SUPPLIER,
      supplier_name: 'kiro',
      image_url: 'https://example.com/milk.png',
      updated_at: new Date(),
    });
  });
});

function merchantDb(uid = MERCHANT) {
  return env
    .authenticatedContext(uid, {
      phone_number: PHONE,
      firebase: { sign_in_provider: 'phone' },
    })
    .firestore();
}

function supplierDb(uid = SUPPLIER) {
  return env
    .authenticatedContext(uid, {
      email: 'kiro@example.com',
      firebase: { sign_in_provider: 'password' },
    })
    .firestore();
}

// Same payload as SubOrder.toFirestore() in the merchant app.
function orderPayload(overrides = {}) {
  return {
    id: 'KZ-1002-1',
    master_order_id: 'KZ-1002',
    order_number: 1002,
    merchant_id: MERCHANT,
    merchant_name: 'سوبر ماركت التجربة',
    merchant_phone: PHONE,
    delivery_address: 'شارع النبي دانيال رقم 10، العطارين، الإسكندرية',
    delivery_notes: '',
    supplier_uid: SUPPLIER,
    supplier_code: '20',
    supplier_name: 'kiro',
    delivery_sla: 'توصيل خلال 24 ساعة',
    items: [
      {
        product_id: 'milk',
        product_name: 'حليب الخير',
        image_url: 'https://example.com/milk.png',
        cartons_qty: 2,
        carton_price: 500,
        units_per_carton: 20,
        line_total: 1000,
      },
    ],
    cartons_count: 2,
    subtotal: 1000,
    delivery_fee: 0,
    total: 1000,
    status: 'pending',
    payment_method: 'cash_on_delivery',
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
    ...overrides,
  };
}

// Mirrors OrderRepository.placeOrder: read counter + products, then write.
function placeOrder(db, { order = orderPayload(), nextNumber = 1002 } = {}) {
  return runTransaction(db, async (tx) => {
    await tx.get(doc(db, 'counters', 'orders_counter'));
    await tx.get(doc(db, 'products', 'milk'));
    tx.set(doc(db, 'counters', 'orders_counter'), {
      last_number: nextNumber,
      updated_at: serverTimestamp(),
    });
    tx.set(doc(db, 'orders', order.id), order);
  });
}

describe('merchant checkout', () => {
  test('places an order with the counter bump', async () => {
    await assertSucceeds(placeOrder(merchantDb()));
  });

  test('cannot create an order without bumping the counter', async () => {
    const db = merchantDb();
    await assertFails(setDoc(doc(db, 'orders', 'KZ-1002-1'), orderPayload()));
  });

  test('cannot bump the counter without an order', async () => {
    const db = merchantDb();
    await assertFails(
      setDoc(doc(db, 'counters', 'orders_counter'), {
        last_number: 1002,
        updated_at: serverTimestamp(),
      }),
    );
  });

  test('cannot place an order for another merchant', async () => {
    await assertFails(
      placeOrder(merchantDb(), { order: orderPayload({ merchant_id: OTHER_MERCHANT }) }),
    );
  });

  test('cannot create an order that is already processing', async () => {
    await assertFails(placeOrder(merchantDb(), { order: orderPayload({ status: 'processing' }) }));
  });

  test('cannot add extra fields to an order', async () => {
    await assertFails(placeOrder(merchantDb(), { order: orderPayload({ hacked: true }) }));
  });

  test(`places an order with the maximum ${MAX_ITEMS} items`, async () => {
    const order = orderPayload();
    order.items = Array.from({ length: MAX_ITEMS }, (_, i) => ({
      ...order.items[0],
      product_id: `product_${i}`,
      product_name: `منتج تجريبي رقم ${i} بإسم طويل شوية زي أسماء المنتجات الحقيقية`,
      image_url: `https://cdn.example.com/cdn-cgi/image/fit=scale-down,width=900/products/${i}-1000x1000.png`,
      cartons_qty: 3,
      carton_price: 12.35,
      line_total: 3 * 12.35,
    }));
    order.cartons_count = 3 * MAX_ITEMS;
    order.subtotal = order.items.reduce((acc, item) => acc + item.line_total, 0);
    order.total = order.subtotal;
    await assertSucceeds(placeOrder(merchantDb(), { order }));
  });

  test(`cannot place an order with more than ${MAX_ITEMS} items`, async () => {
    const order = orderPayload();
    order.items = Array.from({ length: MAX_ITEMS + 1 }, () => order.items[0]);
    await assertFails(placeOrder(merchantDb(), { order }));
  });

  test('cannot put someone else’s phone on the order', async () => {
    await assertFails(
      placeOrder(merchantDb(), { order: orderPayload({ merchant_phone: '+201111111111' }) }),
    );
  });

  test('cannot place an order without items', async () => {
    await assertFails(placeOrder(merchantDb(), { order: orderPayload({ items: [] }) }));
  });

  test('cannot fake the order total', async () => {
    await assertFails(placeOrder(merchantDb(), { order: orderPayload({ total: 1 }) }));
  });
});

describe('reading orders', () => {
  beforeEach(async () => {
    await placeOrder(merchantDb());
  });

  test('merchant lists own orders', async () => {
    const db = merchantDb();
    await assertSucceeds(
      getDocs(query(collection(db, 'orders'), where('merchant_id', '==', MERCHANT))),
    );
  });

  test('merchant cannot list all orders', async () => {
    await assertFails(getDocs(collection(merchantDb(), 'orders')));
  });

  test('another merchant cannot read the order', async () => {
    await assertFails(getDoc(doc(merchantDb(OTHER_MERCHANT), 'orders', 'KZ-1002-1')));
  });

  test('supplier lists its orders', async () => {
    const db = supplierDb();
    await assertSucceeds(
      getDocs(query(collection(db, 'orders'), where('supplier_uid', '==', SUPPLIER))),
    );
  });

  test('supplier moves the order forward', async () => {
    const db = supplierDb();
    await assertSucceeds(
      updateDoc(doc(db, 'orders', 'KZ-1002-1'), {
        status: 'processing',
        updated_at: serverTimestamp(),
      }),
    );
  });

  test('supplier accepts an order and takes its cartons out of stock', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'products', 'milk'), { stock_quantity: 50 });
    });
    const db = supplierDb();
    // Same writes as OrderStatusService.updateStatus in the web dashboard.
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const order = await tx.get(doc(db, 'orders', 'KZ-1002-1'));
        await tx.get(doc(db, 'products', 'milk'));
        tx.update(doc(db, 'products', 'milk'), {
          stock_quantity: 48,
          updated_at: serverTimestamp(),
        });
        tx.update(doc(db, 'orders', 'KZ-1002-1'), {
          status: 'processing',
          updated_at: serverTimestamp(),
        });
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'products', 'milk'), { stock_quantity: -1, updated_at: serverTimestamp() }),
    );
  });

  test('supplier cannot reopen as pending or change the total', async () => {
    const db = supplierDb();
    await assertFails(
      updateDoc(doc(db, 'orders', 'KZ-1002-1'), { status: 'pending', updated_at: serverTimestamp() }),
    );
    await assertFails(
      updateDoc(doc(db, 'orders', 'KZ-1002-1'), { total: 1, updated_at: serverTimestamp() }),
    );
  });

  test('merchant cannot change the status', async () => {
    await assertFails(
      updateDoc(doc(merchantDb(), 'orders', 'KZ-1002-1'), {
        status: 'cancelled',
        updated_at: serverTimestamp(),
      }),
    );
  });
});

describe('supplier web app', () => {
  const NEW_SUPPLIER = 'supplier_new';
  const NEW_EMAIL = 'new@example.com';

  function newSupplierDb() {
    return env
      .authenticatedContext(NEW_SUPPLIER, {
        email: NEW_EMAIL,
        firebase: { sign_in_provider: 'password' },
      })
      .firestore();
  }

  // Mirrors SupplierAuthService.registerSupplier.
  function registerSupplier(db, { code = '21', username = 'almarai-21', status = 'pending' } = {}) {
    return runTransaction(db, async (tx) => {
      const counterRef = doc(db, 'counters', 'suppliers_counter');
      await tx.get(counterRef);
      tx.set(counterRef, { last_code: Number(code), updated_at: serverTimestamp() }, { merge: true });
      tx.set(doc(db, 'usernames', username), { uid: NEW_SUPPLIER, email: NEW_EMAIL });
      tx.set(
        doc(db, 'suppliers', NEW_SUPPLIER),
        {
          uid: NEW_SUPPLIER,
          company_name: 'المراعي',
          email: NEW_EMAIL,
          phone: '01000000000',
          supplier_code: code,
          username,
          tax_id: '',
          status,
          created_at: serverTimestamp(),
        },
        { merge: true },
      );
    });
  }

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'counters', 'suppliers_counter'), {
        last_code: 20,
        updated_at: new Date(),
      });
      await setDoc(doc(ctx.firestore(), 'usernames', 'kiro-20'), {
        uid: SUPPLIER,
        email: 'kiro@example.com',
      });
    });
  });

  test('a new supplier registers as pending with the next code', async () => {
    await assertSucceeds(registerSupplier(newSupplierDb()));
  });

  test('a new supplier cannot register as active', async () => {
    await assertFails(registerSupplier(newSupplierDb(), { status: 'active' }));
  });

  test('a new supplier cannot skip or reuse a code', async () => {
    await assertFails(registerSupplier(newSupplierDb(), { code: '25', username: 'almarai-25' }));
    await assertFails(registerSupplier(newSupplierDb(), { code: '20', username: 'almarai-20' }));
  });

  test('a phone (merchant) account cannot register as supplier', async () => {
    const db = env
      .authenticatedContext(NEW_SUPPLIER, {
        phone_number: PHONE,
        email: NEW_EMAIL,
        firebase: { sign_in_provider: 'phone' },
      })
      .firestore();
    await assertFails(registerSupplier(db));
  });

  test('anyone can look up one username before sign-in, but not list them', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(db, 'usernames', 'kiro-20')));
    await assertFails(getDocs(collection(db, 'usernames')));
  });

  test('a username cannot be taken over', async () => {
    await assertFails(
      setDoc(doc(newSupplierDb(), 'usernames', 'kiro-20'), { uid: NEW_SUPPLIER, email: NEW_EMAIL }),
    );
  });

  test('supplier reads its own profile only', async () => {
    await assertSucceeds(getDoc(doc(supplierDb(), 'suppliers', SUPPLIER)));
    await assertFails(getDoc(doc(supplierDb(), 'suppliers', 'someone_else')));
  });

  test('supplier cannot approve itself', async () => {
    await assertFails(updateDoc(doc(supplierDb(), 'suppliers', SUPPLIER), { status: 'active' }));
  });

  // Same payload as the product dialog in product_management_screen.dart.
  const productPayload = (overrides = {}) => ({
    name: 'جبنة بيضاء',
    category: 'ألبان وأجبان (Dairy & Cheese)',
    carton_price: 450.5,
    units_per_carton: 12,
    piece_price: 37.54,
    min_order_qty: 1,
    is_available: true,
    supplier_code: '20',
    supplier_uid: SUPPLIER,
    supplier_name: 'kiro',
    image_url: '',
    updated_at: serverTimestamp(),
    ...overrides,
  });

  test('active supplier adds a product under its own name', async () => {
    const db = supplierDb();
    await assertSucceeds(setDoc(doc(db, 'products', 'cheese'), productPayload()));
  });

  test('supplier cannot add a product for another supplier or name', async () => {
    const db = supplierDb();
    await assertFails(setDoc(doc(db, 'products', 'p1'), productPayload({ supplier_uid: 'x' })));
    await assertFails(setDoc(doc(db, 'products', 'p2'), productPayload({ supplier_name: 'جهينة' })));
    await assertFails(setDoc(doc(db, 'products', 'p3'), productPayload({ supplier_code: '99' })));
    await assertFails(
      setDoc(doc(db, 'products', 'p5'), productPayload({ created_at: new Date('2020-01-01') })),
    );
  });

  test('a pending supplier cannot add products', async () => {
    await registerSupplier(newSupplierDb());
    await assertFails(
      setDoc(
        doc(newSupplierDb(), 'products', 'p4'),
        productPayload({ supplier_uid: NEW_SUPPLIER, supplier_code: '21', supplier_name: 'المراعي' }),
      ),
    );
  });

  test('supplier edits and deletes its product, not others', async () => {
    const db = supplierDb();
    await assertSucceeds(updateDoc(doc(db, 'products', 'milk'), productPayload({ name: 'حليب الخير 1 لتر' })));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'products', 'other'), {
        ...productPayload({ supplier_uid: 'someone_else' }),
        updated_at: new Date(),
      });
    });
    await assertFails(updateDoc(doc(db, 'products', 'other'), { is_available: false, updated_at: serverTimestamp() }));
  });

  test('supplier saves its store settings', async () => {
    const db = supplierDb();
    await assertSucceeds(
      setDoc(
        doc(db, 'suppliers', SUPPLIER, 'settings', 'store_config'),
        {
          store_name: 'kiro',
          tax_id: '',
          contact_phone: '01000000000',
          support_email: 'kiro@example.com',
          warehouse_address: 'الإسكندرية',
          currency: 'EGP',
          low_stock_threshold: 15,
          default_min_order_qty: 10,
          auto_low_stock_alerts: true,
          auto_hide_out_of_stock: false,
          allow_backorders: false,
          is_dark_mode: true,
          language: 'English',
          compact_table_rows: false,
          refresh_rate: 'Real-time (Stream)',
          updated_at: serverTimestamp(),
          updated_by: 'kiro@example.com',
        },
        { merge: true },
      ),
    );
  });

  test('supplier records and lists its transactions', async () => {
    const db = supplierDb();
    await assertSucceeds(
      setDoc(doc(db, 'transactions', 't1'), {
        id: 'TRX-12345',
        supplier_uid: SUPPLIER,
        order_ref: 'KZ-1002-1',
        client: 'سوبر ماركت التجربة',
        method: 'Cash on Delivery',
        amount: 1000,
        is_inflow: true,
        status: 'Completed',
        created_at: new Date().toISOString(),
        updated_at: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      getDocs(query(collection(db, 'transactions'), where('supplier_uid', '==', SUPPLIER))),
    );
    await assertFails(getDocs(collection(db, 'transactions')));
  });
});

describe('catalog and profiles', () => {
  test('merchant reads available products', async () => {
    const db = merchantDb();
    await assertSucceeds(
      getDocs(query(collection(db, 'products'), where('is_available', '==', true))),
    );
  });

  test('merchant cannot read supplier or other merchant profiles', async () => {
    const db = merchantDb();
    await assertFails(getDoc(doc(db, 'suppliers', SUPPLIER)));
    await assertFails(getDoc(doc(db, 'users', OTHER_MERCHANT)));
    await assertSucceeds(getDoc(doc(db, 'users', MERCHANT)));
  });

  test('merchant cannot write products', async () => {
    await assertFails(updateDoc(doc(merchantDb(), 'products', 'milk'), { carton_price: 1 }));
  });

  test('supplier toggles availability of its product', async () => {
    await assertSucceeds(
      updateDoc(doc(supplierDb(), 'products', 'milk'), {
        is_available: false,
        updated_at: serverTimestamp(),
      }),
    );
  });

  test('a new phone user registers as merchant, not as admin', async () => {
    const db = env
      .authenticatedContext('new_merchant', {
        phone_number: '+201000000002',
        firebase: { sign_in_provider: 'phone' },
      })
      .firestore();
    const profile = {
      uid: 'new_merchant',
      role: 'merchant',
      business_name: 'محل جديد',
      owner_name: 'صاحب المحل',
      phone_number: '+201000000002',
      store_category: 'سوبر ماركت',
      governorate: 'القاهرة',
      city: 'مدينة نصر',
      address: 'شارع عباس العقاد',
      landmark: null,
      commercial_register: null,
      latitude: null,
      longitude: null,
      created_at: serverTimestamp(),
    };
    await assertFails(setDoc(doc(db, 'users', 'new_merchant'), { ...profile, role: 'admin' }));
    await assertFails(
      setDoc(doc(db, 'users', 'new_merchant'), { ...profile, phone_number: '+201111111111' }),
    );
    await assertFails(setDoc(doc(db, 'users', 'new_merchant'), { ...profile, latitude: 500 }));

    // Store photo links must point into the merchant's own Storage folder.
    const photo = (uid) =>
      `https://firebasestorage.googleapis.com/v0/b/khazeen.firebasestorage.app/o/users%2F${uid}%2Fstore%2Fexterior.jpg?alt=media&token=abc`;
    await assertFails(
      setDoc(doc(db, 'users', 'new_merchant'), {
        ...profile,
        exterior_photo_url: photo('someone_else'),
      }),
    );
    await assertFails(
      setDoc(doc(db, 'users', 'new_merchant'), {
        ...profile,
        exterior_photo_url: 'https://evil.example.com/x.jpg',
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, 'users', 'new_merchant'), {
        ...profile,
        exterior_photo_url: photo('new_merchant'),
      }),
    );
  });
});
