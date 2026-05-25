// Wire env BEFORE any firebase-admin / functions imports so secret /
// project-id resolution picks up our test values.
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-elio';

import {describe, it, before, beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import * as admin from 'firebase-admin';

// ─────────────────────────────────────────────────────────────────────────────
// In-memory Firestore fake.
//
// Same rationale as postmarkInbound.test.ts: we can't run the Firestore
// emulator on this Windows dev box (no Java), and `npm test` is plain
// `node --test`. The production code we exercise here uses a tiny slice of
// the Firestore API: collection().doc(), doc.get(), doc.set({}, {merge}).
// We model exactly that and monkey-patch admin.firestore() before importing
// the function-under-test.
// ─────────────────────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Data = Record<string, any>;

interface FakeDocSnap {
  id: string;
  exists: boolean;
  data(): Data | undefined;
  ref: FakeDocRef;
}

class FakeDocRef {
  // eslint-disable-next-line @typescript-eslint/no-use-before-define
  constructor(public coll: FakeCollRef, public id: string) {}
  get path() {
    return `${this.coll.path}/${this.id}`;
  }
  async set(data: Data, opts?: {merge?: boolean}) {
    const existing = STORE.docs.get(this.path);
    const next = opts?.merge && existing ? {...existing, ...data} : {...data};
    STORE.docs.set(this.path, next);
  }
  async get(): Promise<FakeDocSnap> {
    const d = STORE.docs.get(this.path);
    return {
      id: this.id,
      exists: d !== undefined,
      data: () => d,
      ref: this,
    };
  }
}

class FakeCollRef {
  constructor(public path: string) {}
  doc(id?: string): FakeDocRef {
    const docId = id ?? `auto_${++STORE.autoId}`;
    return new FakeDocRef(this, docId);
  }
}

const STORE = {
  colls: new Map<string, FakeCollRef>(),
  docs: new Map<string, Data>(),
  autoId: 0,
};

function fakeFirestoreNamespace() {
  const fn = () => ({
    collection(name: string) {
      if (!STORE.colls.has(name)) STORE.colls.set(name, new FakeCollRef(name));
      return STORE.colls.get(name)!;
    },
  });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (fn as any).FieldValue = {
    serverTimestamp: () => ({__type: 'serverTimestamp'}),
    delete: () => ({__type: 'delete'}),
  };
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (fn as any).Timestamp = {
    fromMillis: (ms: number) => ({__type: 'timestamp', ms}),
    now: () => ({__type: 'timestamp', ms: Date.now()}),
  };
  return fn;
}

const FAKE_FIRESTORE = fakeFirestoreNamespace();
Object.defineProperty(admin, 'firestore', {
  configurable: true,
  get: () => FAKE_FIRESTORE,
});

// ─────────────────────────────────────────────────────────────────────────────
// Test setup
// ─────────────────────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let generateImportAddress: any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let testEnv: any;

before(async () => {
  const ft = (await import('firebase-functions-test')).default;
  testEnv = ft();
  ({generateImportAddress} = await import('../generateImportAddress'));
});

beforeEach(() => {
  STORE.colls.clear();
  STORE.docs.clear();
  STORE.autoId = 0;
});

const ADDRESS_RE = /^u_[a-z2-7]{13}@orders\.elio\.app$/;

describe('generateImportAddress', () => {
  it('rejects unauthenticated calls', async () => {
    const wrapped = testEnv.wrap(generateImportAddress);
    await assert.rejects(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      () => wrapped({auth: null} as any),
      // HttpsError exposes its code on `.code` (e.g. "unauthenticated").
      // The default `Error.message` only carries the human-readable
      // "Sign in required." string, so we assert against the code field.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (err: any) => err?.code === 'unauthenticated',
    );
  });

  it('mints a u_<13chars>@orders.elio.app address on first call', async () => {
    const wrapped = testEnv.wrap(generateImportAddress);
    const res = await wrapped({auth: {uid: 'user-1'}});
    assert.match(res.address, ADDRESS_RE);
  });

  it('is idempotent — second call returns the same address', async () => {
    const wrapped = testEnv.wrap(generateImportAddress);
    const a = await wrapped({auth: {uid: 'user-2'}});
    const b = await wrapped({auth: {uid: 'user-2'}});
    assert.equal(a.address, b.address);
    assert.match(a.address, ADDRESS_RE);
  });
});
