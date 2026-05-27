// Wire env BEFORE any firebase-admin / functions imports so secret resolution
// picks up our test value.
process.env.POSTMARK_INBOUND_SECRET = 'right-secret';
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-elio';

import {describe, it, before, after, beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import * as admin from 'firebase-admin';

// ─────────────────────────────────────────────────────────────────────────────
// In-memory Firestore fake.
//
// We can't rely on the Firestore emulator here — this dev box doesn't have
// Java installed, and our `npm test` script is plain `node --test`, not
// `firebase emulators:exec`. The production code under test only uses a
// narrow Firestore surface: collection().doc(), collection().where().limit()
// .get(), collection().add(), serverTimestamp / Timestamp / FieldValue.
// We model exactly that and monkey-patch admin.firestore() before importing
// postmarkInbound. The function-under-test is exercised verbatim.
// ─────────────────────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Data = Record<string, any>;

interface FakeDocSnap {
  id: string;
  exists: boolean;
  data(): Data;
  ref: FakeDocRef;
}
interface FakeQuerySnap {
  empty: boolean;
  size: number;
  docs: FakeDocSnap[];
}

class FakeDocRef {
  // eslint-disable-next-line @typescript-eslint/no-use-before-define
  constructor(public coll: FakeCollRef, public id: string) {}
  get path() {
    return `${this.coll.path}/${this.id}`;
  }
  collection(name: string): FakeCollRef {
    const key = `${this.path}/${name}`;
    if (!STORE.colls.has(key)) STORE.colls.set(key, new FakeCollRef(key));
    return STORE.colls.get(key)!;
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
      data: () => d ?? {},
      ref: this,
    };
  }
  async update(data: Data) {
    const existing = STORE.docs.get(this.path) ?? {};
    const next: Data = {...existing};
    for (const [k, v] of Object.entries(data)) {
      // Honour the FieldValue.delete() sentinel from the fake firestore
      // namespace below — production code uses this to drop privacy-sensitive
      // raw email bodies after parsing.
      if (v && typeof v === 'object' && (v as Data).__type === 'delete') {
        delete next[k];
      } else {
        next[k] = v;
      }
    }
    STORE.docs.set(this.path, next);
  }
  async delete() {
    STORE.docs.delete(this.path);
  }
}

class FakeCollRef {
  // Chained query state.
  private _where: Array<{field: string; op: string; value: unknown}> = [];
  private _limit: number | null = null;

  constructor(public path: string) {}

  doc(id?: string): FakeDocRef {
    const docId = id ?? `auto_${++STORE.autoId}`;
    return new FakeDocRef(this, docId);
  }

  where(field: string, op: string, value: unknown): FakeCollRef {
    const next = new FakeCollRef(this.path);
    next._where = [...this._where, {field, op, value}];
    next._limit = this._limit;
    return next;
  }

  limit(n: number): FakeCollRef {
    const next = new FakeCollRef(this.path);
    next._where = [...this._where];
    next._limit = n;
    return next;
  }

  async get(): Promise<FakeQuerySnap> {
    const prefix = `${this.path}/`;
    const matches: FakeDocSnap[] = [];
    for (const [path, data] of STORE.docs.entries()) {
      if (!path.startsWith(prefix)) continue;
      const rest = path.slice(prefix.length);
      if (rest.includes('/')) continue; // only immediate children
      let ok = true;
      for (const w of this._where) {
        if (w.op !== '==') {
          throw new Error(`fake: unsupported op ${w.op}`);
        }
        if ((data as Data)[w.field] !== w.value) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      const docRef = new FakeDocRef(this, rest);
      matches.push({
        id: rest,
        exists: true,
        data: () => data as Data,
        ref: docRef,
      });
      if (this._limit && matches.length >= this._limit) break;
    }
    return {empty: matches.length === 0, size: matches.length, docs: matches};
  }

  async add(data: Data): Promise<FakeDocRef> {
    const ref = this.doc();
    STORE.docs.set(ref.path, {...data});
    return ref;
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
  // Static helpers used by production code.
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

// Replace admin.firestore with our fake BEFORE the function-under-test loads.
// firebase-admin exposes `firestore` as a getter, so we have to use
// defineProperty to override it.
const FAKE_FIRESTORE = fakeFirestoreNamespace();
Object.defineProperty(admin, 'firestore', {
  configurable: true,
  get: () => FAKE_FIRESTORE,
});

// ─────────────────────────────────────────────────────────────────────────────
// Test setup
// ─────────────────────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let handleInbound: any;
const FIXTURE = JSON.parse(
  readFileSync(join(__dirname, 'fixtures/postmark-kroger.json'), 'utf8'),
);

// A canned Gemini response used by the parser-integration cases. The default
// shape parses cleanly (1 item, confidence == 1.0).
const DEFAULT_CANNED = {
  items: [
    {
      rawName: 'KRO BRAND MILK 1G',
      normalizedName: 'whole milk',
      quantity: 1,
      unit: 'gal',
      category: 'dairy',
      classification: 'food',
    },
  ],
  orderType: 'confirmation',
  totalDetected: 1,
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function fakeClient(canned: any) {
  return {
    async generateStructured() {
      return canned;
    },
  };
}

const SECRET = 'right-secret';
const AUTH = 'Basic ' + Buffer.from(SECRET).toString('base64');

before(async () => {
  ({handleInbound} = await import('../postmarkInbound'));
});

beforeEach(async () => {
  // Reset store and re-seed the user doc.
  STORE.colls.clear();
  STORE.docs.clear();
  STORE.autoId = 0;
  await admin.firestore().collection('users').doc('user-1').set({
    importAddress: 'u_abc123xyz4567@orders.eliochef.com',
  });
});

after(() => {
  // Nothing to tear down — no real firebase app was initialised.
});

describe('postmarkInbound (handleInbound)', () => {
  it('401s without the right credentials', async () => {
    const wrong = 'Basic ' + Buffer.from('wrong:creds').toString('base64');
    const r = await handleInbound(
      FIXTURE, wrong, SECRET, {client: fakeClient(DEFAULT_CANNED)});
    assert.equal(r.status, 401);
  });

  it('401s when Authorization header missing entirely', async () => {
    const r = await handleInbound(
      FIXTURE, undefined, SECRET, {client: fakeClient(DEFAULT_CANNED)});
    assert.equal(r.status, 401);
  });

  it('ignores unknown To addresses with 200', async () => {
    const r = await handleInbound(
      {...FIXTURE, To: 'u_unknown@orders.eliochef.com'},
      AUTH, SECRET, {client: fakeClient(DEFAULT_CANNED)});
    assert.equal(r.status, 200);
    assert.deepEqual(r.body, {ignored: true});
  });

  it('writes a stub and finalises retailer for valid inbound', async () => {
    const r = await handleInbound(
      FIXTURE, AUTH, SECRET, {client: fakeClient(DEFAULT_CANNED)});
    assert.equal(r.status, 200);
    const docs = await admin.firestore()
      .collection('users').doc('user-1')
      .collection('pending_imports').get();
    assert.equal(docs.size, 1);
    const data = docs.docs[0].data();
    assert.equal(data.retailer, 'kroger');
  });

  it('deduplicates on Message-Id', async () => {
    const r1 = await handleInbound(
      FIXTURE, AUTH, SECRET, {client: fakeClient(DEFAULT_CANNED)});
    const r2 = await handleInbound(
      FIXTURE, AUTH, SECRET, {client: fakeClient(DEFAULT_CANNED)});
    assert.equal(r1.status, 200);
    assert.deepEqual(r2.body, {duplicate: true});
    const docs = await admin.firestore()
      .collection('users').doc('user-1')
      .collection('pending_imports').get();
    assert.equal(docs.size, 1);
  });

  it('finalises status: pending_review when confidence >= 0.4 '
    + 'and drops both raw bodies', async () => {
    const r = await handleInbound(
      FIXTURE, AUTH, SECRET, {client: fakeClient(DEFAULT_CANNED)});
    assert.equal(r.status, 200);
    const docs = await admin.firestore()
      .collection('users').doc('user-1')
      .collection('pending_imports').get();
    assert.equal(docs.size, 1);
    const d = docs.docs[0].data();
    assert.equal(d.status, 'pending_review');
    assert.equal(d.items.length, 1);
    assert.equal(d.items[0].normalizedName, 'whole milk');
    assert.equal(d.orderType, 'confirmation');
    assert.ok(d.parseConfidence >= 0.4);
    // Privacy: both raw bodies dropped on success.
    assert.equal(d.rawHtmlBody, undefined);
    assert.equal(d.rawTextBody, undefined);
  });

  it('finalises status: parse_failed when no items parsed '
    + 'and retains rawTextBody', async () => {
    const empty = {items: [], orderType: 'unknown', totalDetected: 0};
    const r = await handleInbound(
      FIXTURE, AUTH, SECRET, {client: fakeClient(empty)});
    assert.equal(r.status, 200);
    const docs = await admin.firestore()
      .collection('users').doc('user-1')
      .collection('pending_imports').get();
    assert.equal(docs.size, 1);
    const d = docs.docs[0].data();
    assert.equal(d.status, 'parse_failed');
    assert.deepEqual(d.items, []);
    // Privacy: html dropped on every parse; text retained on failure.
    assert.equal(d.rawHtmlBody, undefined);
    assert.equal(d.rawTextBody, FIXTURE.TextBody);
  });
});
