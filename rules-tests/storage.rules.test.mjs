// Cloud Storage rules tests, run against the local emulator:
//   npm run test:rules
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

const MERCHANT = 'merchant_1';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-khazeen-storage',
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
});

after(async () => env.cleanup());
beforeEach(async () => env.clearStorage());

function merchantStorage(uid = MERCHANT) {
  return env
    .authenticatedContext(uid, {
      phone_number: '+201000000001',
      firebase: { sign_in_provider: 'phone' },
    })
    .storage();
}

const jpeg = (size = 1024) => new Uint8Array(size);
const asJpeg = { contentType: 'image/jpeg' };

describe('merchant store photos', () => {
  test('a merchant uploads and reads their own store photo', async () => {
    const storage = merchantStorage();
    const photo = ref(storage, `users/${MERCHANT}/store/exterior.jpg`);
    await assertSucceeds(uploadBytes(photo, jpeg(), asJpeg));
    await assertSucceeds(getBytes(photo));
  });

  test('cannot upload into or read another merchant folder', async () => {
    await assertSucceeds(
      uploadBytes(ref(merchantStorage(), `users/${MERCHANT}/store/exterior.jpg`), jpeg(), asJpeg),
    );
    const other = merchantStorage('merchant_2');
    await assertFails(
      uploadBytes(ref(other, `users/${MERCHANT}/store/exterior.jpg`), jpeg(), asJpeg),
    );
    await assertFails(getBytes(ref(other, `users/${MERCHANT}/store/exterior.jpg`)));
  });

  test('only images under 5 MB with the expected names', async () => {
    const storage = merchantStorage();
    await assertFails(
      uploadBytes(ref(storage, `users/${MERCHANT}/store/exterior.jpg`), jpeg(), {
        contentType: 'application/pdf',
      }),
    );
    await assertFails(
      uploadBytes(ref(storage, `users/${MERCHANT}/store/other.jpg`), jpeg(), asJpeg),
    );
    await assertFails(
      uploadBytes(
        ref(storage, `users/${MERCHANT}/store/interior.jpg`),
        jpeg(5 * 1024 * 1024 + 1),
        asJpeg,
      ),
    );
  });

  test('signed-out users cannot read store photos', async () => {
    await assertSucceeds(
      uploadBytes(ref(merchantStorage(), `users/${MERCHANT}/store/exterior.jpg`), jpeg(), asJpeg),
    );
    const anon = env.unauthenticatedContext().storage();
    await assertFails(getBytes(ref(anon, `users/${MERCHANT}/store/exterior.jpg`)));
  });
});
