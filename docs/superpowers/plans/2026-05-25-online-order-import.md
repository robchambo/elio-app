# Online Order → Pantry Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pro users forward an order-confirmation email to a per-user `@orders.elio.app` address. A Cloud Function parses it with Gemini, writes a `pending_imports` doc, and a Flutter review sheet lets the user approve items into the pantry via the existing `InventoryWriter`.

**Architecture:** Postmark Inbound → Cloud Function `postmarkInbound` (validates + idempotency + persists stub) → Cloud Function `parseOrderEmail` (Gemini structured-output, normalised items) → Firestore `users/{uid}/pending_imports/{id}` → Flutter stream → review sheet → `InventoryWriter.addItem` per checked item → mark applied. Matcher lives client-side only (no Dart→TS port).

**Tech Stack:** Flutter (Dart), Firebase Cloud Functions v2 (TypeScript, Node 22), Postmark Inbound, Gemini via `@google/generative-ai` Node SDK, Firestore.

**Source spec:** `docs/superpowers/specs/2026-05-25-online-order-import-design.md`

**Known v1 gap (deliberate):** Server-side Pro enforcement at address-generation time is deferred. Client-side gate at apply-time is the v1 trust boundary. RevenueCat→Firestore webhook sync is parked for v1.1. Documented in §11 of the spec.

---

## File Structure

**New files:**

```
functions/src/orderImport/
  index.ts                          # Exports the 2 functions
  generateImportAddress.ts          # Callable function — mints per-user address
  postmarkInbound.ts                # HTTPS webhook handler
  orderParser.ts                    # Pure Gemini parsing logic (testable)
  forwardWrapperStripper.ts         # Strips Gmail/Apple/Outlook forward chrome
  schema.ts                         # Shared types + Gemini JSON schema
  __tests__/
    orderParser.test.ts
    postmarkInbound.test.ts
    forwardWrapperStripper.test.ts
    fixtures/
      kroger-confirmation.eml
      tesco-confirmation.eml
      woolworths-confirmation.eml

lib/services/order_import_service.dart   # Streams pending_imports + apply action
lib/models/pending_import.dart            # Dart model for pending_imports doc
lib/widgets/order_import_review_sheet.dart  # Review UI
lib/screens/account/order_import_screen.dart  # Settings sub-screen (address + copy)

test/services/order_import_service_test.dart
test/widgets/order_import_review_sheet_test.dart
test/models/pending_import_test.dart
integration_test/order_import_e2e_test.dart
```

**Modified files:**

```
firestore.rules                            # Add pending_imports subcollection + importAddress field rules
firestore.indexes.json                     # Compound index for pending_imports queries
functions/package.json                     # Add @google/generative-ai
functions/src/index.ts                     # Re-export the new functions
lib/screens/account/account_screen.dart    # Add Pro-feature row → order_import_screen
lib/widgets/elio/elio_bottom_nav.dart      # Pantry-tab badge for pending imports
pubspec.yaml                                # No new deps expected (uses existing cloud_firestore, share_plus)
```

---

## Task 1: Branch + Firestore rules + indexes for `pending_imports`

**Goal:** Create the feature branch and lock down the data-model boundary in Firestore rules before any code is written. Server can write `pending_imports`; client can read its own and update `status` to `applied` / `discarded` only. The `importAddress` field on the user doc becomes server-only.

**Files:**
- Modify: `firestore.rules`
- Modify: `firestore.indexes.json`

**Acceptance Criteria:**
- [ ] Branch `feat/online-order-import` exists, off latest `main`
- [ ] Owner can read `users/{uid}/pending_imports/{id}`
- [ ] Owner can update only the `status` field of an existing `pending_imports` doc, and only to `applied` or `discarded`
- [ ] Owner CANNOT create or delete `pending_imports` docs from the client (server writes only)
- [ ] Owner CANNOT write `users/{uid}.importAddress` from the client
- [ ] Compound index on `(status ASC, receivedAt DESC)` exists for the inbox query
- [ ] `firebase emulators:exec --only firestore "echo ok"` boots cleanly

**Verify:**
```bash
cd C:/src/elio-app && firebase emulators:start --only firestore --import=.emulator-seed --export-on-exit=.emulator-seed
```
→ rules compile without errors; manual probe via emulator UI confirms owner can't write `importAddress`.

**Steps:**

- [ ] **Step 1: Create branch off latest main**

```bash
cd C:/src/elio-app
git checkout main && git pull origin main
git checkout -b feat/online-order-import
```

- [ ] **Step 2: Add `pending_imports` rules + `importAddress` lock**

Add inside the `match /users/{uid} { ... }` block in `firestore.rules`, after the existing sub-collection matches:

```firestore
      // ── pending_imports — server-written, owner-readable, owner can
      // only flip status to applied|discarded. Created and deleted only
      // by Admin SDK (Postmark webhook → Cloud Function).
      match /pending_imports/{id} {
        allow read: if isOwner(uid);
        allow create, delete: if false;  // server-only via Admin SDK
        allow update: if isOwner(uid)
          && request.resource.data.diff(resource.data).affectedKeys()
               .hasOnly(['status'])
          && request.resource.data.status in ['applied', 'discarded'];
      }
```

Add an `importAddressUnchanged()` helper to the existing user-doc rule. Update the `users/{uid}` `allow update` line to include it:

```firestore
    function importAddressUnchanged() {
      return request.resource.data.get('importAddress', '')
          == resource.data.get('importAddress', '');
    }
    // ...
    match /users/{uid} {
      allow update: if isOwner(uid)
        && protectedSubKeysUnchanged()
        && importAddressUnchanged();
      // ...
    }
```

- [ ] **Step 3: Add compound index**

Append to `firestore.indexes.json`:

```json
{
  "collectionGroup": "pending_imports",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "receivedAt", "order": "DESCENDING" }
  ]
}
```

- [ ] **Step 4: Smoke-test rules in emulator**

```bash
firebase emulators:start --only firestore
```

Open emulator UI at `http://localhost:4000/firestore`, sign in as a test user, try writing to `users/{uid}/pending_imports/x` — must fail. Try writing `users/{uid}.importAddress` from client — must fail. Try updating an existing pending_import's `status` field to `"applied"` — must succeed.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firestore.indexes.json
git commit -m "feat(rules): lock pending_imports + importAddress for server-only writes

Server (Admin SDK) is the sole writer of pending_imports docs and the
importAddress field. Clients can only read pending_imports and flip
status from pending_review to applied|discarded. Compound index on
(status, receivedAt) added for the inbox stream."
```

---

## Task 2: Cloud Function — `generateImportAddress` (callable)

**Goal:** A Flutter client calls this once; it mints a 64-bit token (base32, lowercase), writes `users/{uid}.importAddress = "u_<token>@orders.elio.app"` via Admin SDK, returns the address. Idempotent — re-calls return the existing address.

**Files:**
- Create: `functions/src/orderImport/generateImportAddress.ts`
- Create: `functions/src/orderImport/index.ts`
- Modify: `functions/src/index.ts`

**Acceptance Criteria:**
- [ ] Authenticated callable; rejects unauthenticated calls with `unauthenticated`
- [ ] First call writes `importAddress` to the user doc and returns it
- [ ] Second call from same user returns the SAME address (no second mint)
- [ ] Token is exactly 13 base32 chars (~65 bits entropy), prefix `u_`
- [ ] Function unit-tested with `firebase-functions-test`

**Verify:**
```bash
cd C:/src/elio-app/functions && npm run build && npm test
```
→ orderImport.generateImportAddress tests pass.

**Steps:**

- [ ] **Step 1: Add test infrastructure to `functions/`**

Update `functions/package.json` devDependencies + add a test script:

```json
"scripts": {
  "test": "tsc && node --test lib/**/__tests__/*.test.js",
  ...
},
"devDependencies": {
  "@types/node": "^22.0.0",
  "firebase-functions-test": "^3.4.0",
  ...
}
```

Run:
```bash
cd functions && npm install
```

- [ ] **Step 2: Write the failing test**

Create `functions/src/orderImport/__tests__/generateImportAddress.test.ts`:

```typescript
import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import functionsTest from 'firebase-functions-test';
import * as admin from 'firebase-admin';

const test = functionsTest();
admin.initializeApp({projectId: 'demo-elio'});

import {generateImportAddress} from '../generateImportAddress';

describe('generateImportAddress', () => {
  it('rejects unauthenticated calls', async () => {
    const wrapped = test.wrap(generateImportAddress);
    await assert.rejects(
      () => wrapped({auth: null} as never),
      /unauthenticated/i,
    );
  });

  it('mints a u_<13chars>@orders.elio.app address on first call', async () => {
    const wrapped = test.wrap(generateImportAddress);
    const res = await wrapped({auth: {uid: 'user-1'}} as never);
    assert.match(res.address, /^u_[a-z0-9]{13}@orders\.elio\.app$/);
  });

  it('is idempotent — second call returns the same address', async () => {
    const wrapped = test.wrap(generateImportAddress);
    const a = await wrapped({auth: {uid: 'user-2'}} as never);
    const b = await wrapped({auth: {uid: 'user-2'}} as never);
    assert.equal(a.address, b.address);
  });
});
```

- [ ] **Step 3: Run test, confirm fail**

```bash
npm test
```
Expected: FAIL (file not found / function undefined).

- [ ] **Step 4: Implement**

Create `functions/src/orderImport/generateImportAddress.ts`:

```typescript
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {randomBytes} from 'node:crypto';

const BASE32 = 'abcdefghijklmnopqrstuvwxyz234567';

function mintToken(): string {
  // 65 bits → 13 base32 chars
  const bytes = randomBytes(9);
  let bits = 0n;
  for (const b of bytes) bits = (bits << 8n) | BigInt(b);
  let out = '';
  for (let i = 0; i < 13; i++) {
    out = BASE32[Number(bits & 31n)] + out;
    bits >>= 5n;
  }
  return out;
}

export const generateImportAddress = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const uid = req.auth.uid;
  const db = admin.firestore();
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();
  const existing = snap.get('importAddress') as string | undefined;
  if (existing) return {address: existing};
  const address = `u_${mintToken()}@orders.elio.app`;
  await ref.set({importAddress: address}, {merge: true});
  return {address};
});
```

Create `functions/src/orderImport/index.ts`:

```typescript
export {generateImportAddress} from './generateImportAddress';
```

Add to `functions/src/index.ts` (alongside the Crashlytics exports):

```typescript
export * from './orderImport';
```

- [ ] **Step 5: Run test, confirm pass**

```bash
npm test
```
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add functions/
git commit -m "feat(functions): generateImportAddress callable

Mints a 65-bit base32 token per Pro user (u_<13chars>@orders.elio.app),
stores it on users/{uid}.importAddress via Admin SDK, idempotent on
re-call. This is the auth boundary for inbound order emails — clients
can only read this field (Firestore rules from Task 1)."
```

---

## Task 3: Cloud Function — Postmark inbound webhook (stub-write only)

**Goal:** HTTPS endpoint that accepts Postmark Inbound JSON, validates the user (from the To: address), checks idempotency on Message-Id, writes a stub `pending_imports` doc with `status: parsing`. **Parsing is intentionally deferred to Task 5** — this task lands the receive + persist boundary alone.

**Files:**
- Create: `functions/src/orderImport/postmarkInbound.ts`
- Create: `functions/src/orderImport/__tests__/postmarkInbound.test.ts`
- Create: `functions/src/orderImport/__tests__/fixtures/postmark-kroger.json`
- Modify: `functions/src/orderImport/index.ts`

**Acceptance Criteria:**
- [ ] Rejects requests missing the Postmark webhook secret header → 401
- [ ] Rejects To: addresses not matching `u_<token>@orders.elio.app` → 200 with `{ignored: true}` (we accept the email so Postmark stops retrying, but no-op)
- [ ] Writes one `pending_imports` doc with `status: parsing`, `retailer: detected-or-unknown`, `receivedAt: serverTimestamp()`, `idempotencyKey: sha256(Message-Id)`
- [ ] Duplicate Message-Id → no second write; returns `{duplicate: true}`
- [ ] Postmark webhook secret pulled from `POSTMARK_INBOUND_SECRET` via `defineSecret`

**Verify:**
```bash
cd functions && npm test -- --test-name-pattern=postmarkInbound
```

**Steps:**

- [ ] **Step 1: Add Postmark fixture**

Create `functions/src/orderImport/__tests__/fixtures/postmark-kroger.json` from Postmark's documented Inbound JSON schema. Realistic abbreviated payload:

```json
{
  "FromName": "Kroger",
  "From": "donotreply@kroger.com",
  "To": "u_abc123xyz4567@orders.elio.app",
  "Subject": "Your Kroger order — receipt",
  "MessageID": "abc-message-id-001",
  "Date": "2026-05-25T14:32:00Z",
  "HtmlBody": "<html><body>Your order summary...</body></html>",
  "TextBody": "Your order summary..."
}
```

- [ ] **Step 2: Failing test for the validate-and-stub-write behaviour**

Create `functions/src/orderImport/__tests__/postmarkInbound.test.ts`:

```typescript
import {describe, it, before, after} from 'node:test';
import assert from 'node:assert/strict';
import * as admin from 'firebase-admin';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

let postmarkInbound: any;
const FIXTURE = JSON.parse(
  readFileSync(join(__dirname, 'fixtures/postmark-kroger.json'), 'utf8'),
);

before(async () => {
  admin.initializeApp({projectId: 'demo-elio'});
  // Seed a user doc with the address from the fixture
  await admin.firestore().collection('users').doc('user-1').set({
    importAddress: 'u_abc123xyz4567@orders.elio.app',
  });
  ({postmarkInbound} = await import('../postmarkInbound'));
});

after(() => admin.app().delete());

function mockReq(body: any, secret = 'right-secret') {
  return {
    headers: {'x-postmark-secret': secret},
    body,
    method: 'POST',
  } as any;
}
function mockRes() {
  const r: any = {status: 0, body: null};
  r.status = (c: number) => ((r.status = c), r);
  r.json = (b: any) => ((r.body = b), r);
  r.send = r.json;
  return r;
}

describe('postmarkInbound', () => {
  it('401s without the right secret', async () => {
    const res = mockRes();
    await postmarkInbound(mockReq(FIXTURE, 'wrong'), res);
    assert.equal(res.status, 401);
  });

  it('ignores unknown To addresses with 200', async () => {
    const res = mockRes();
    await postmarkInbound(
      mockReq({...FIXTURE, To: 'u_unknown@orders.elio.app'}),
      res,
    );
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, {ignored: true});
  });

  it('writes a parsing stub for valid inbound', async () => {
    const res = mockRes();
    await postmarkInbound(mockReq(FIXTURE), res);
    assert.equal(res.status, 200);
    const docs = await admin.firestore()
      .collection('users').doc('user-1')
      .collection('pending_imports').get();
    assert.equal(docs.size, 1);
    const data = docs.docs[0].data();
    assert.equal(data.status, 'parsing');
    assert.equal(data.retailer, 'kroger');
  });

  it('deduplicates on Message-Id', async () => {
    const res1 = mockRes();
    const res2 = mockRes();
    await postmarkInbound(mockReq(FIXTURE), res1);
    await postmarkInbound(mockReq(FIXTURE), res2);
    assert.deepEqual(res2.body, {duplicate: true});
    const docs = await admin.firestore()
      .collection('users').doc('user-1')
      .collection('pending_imports').get();
    assert.equal(docs.size, 1);
  });
});
```

- [ ] **Step 3: Run, confirm fail**

```bash
npm test
```

- [ ] **Step 4: Implement `postmarkInbound`**

Create `functions/src/orderImport/postmarkInbound.ts`:

```typescript
import {onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import {createHash} from 'node:crypto';

const postmarkSecret = defineSecret('POSTMARK_INBOUND_SECRET');

const RETAILERS: {match: RegExp; key: string}[] = [
  {match: /@kroger\.com/i, key: 'kroger'},
  {match: /@fredmeyer\.com/i, key: 'kroger'},
  {match: /@(tesco|tescos)\.com/i, key: 'tesco'},
  {match: /@sainsburys\.co\.uk/i, key: 'sainsburys'},
  {match: /@ocado\.com/i, key: 'ocado'},
  {match: /@woolworths\.com\.au/i, key: 'woolworths'},
  {match: /@coles\.com\.au/i, key: 'coles'},
  {match: /@loblaws\.ca/i, key: 'loblaws'},
  {match: /@walmart\.com/i, key: 'walmart'},
  {match: /@instacart\.com/i, key: 'instacart'},
  {match: /@amazon\.com/i, key: 'amazon'},
];

function detectRetailer(from: string): string {
  for (const r of RETAILERS) if (r.match.test(from)) return r.key;
  return 'unknown';
}

export const postmarkInbound = onRequest(
  {secrets: [postmarkSecret], cors: false},
  async (req, res) => {
    if (req.headers['x-postmark-secret'] !== postmarkSecret.value()) {
      res.status(401).send({error: 'invalid secret'});
      return;
    }
    const {To, From, MessageID, Subject, HtmlBody, TextBody} = req.body ?? {};
    if (!To || !MessageID) {
      res.status(200).send({ignored: true});
      return;
    }
    const db = admin.firestore();
    const usersSnap = await db.collection('users')
      .where('importAddress', '==', To).limit(1).get();
    if (usersSnap.empty) {
      res.status(200).send({ignored: true});
      return;
    }
    const userRef = usersSnap.docs[0].ref;
    const idempotencyKey = createHash('sha256').update(MessageID).digest('hex');

    // Idempotency check
    const dup = await userRef.collection('pending_imports')
      .where('idempotencyKey', '==', idempotencyKey).limit(1).get();
    if (!dup.empty) {
      res.status(200).send({duplicate: true});
      return;
    }

    await userRef.collection('pending_imports').add({
      status: 'parsing',
      retailer: detectRetailer(String(From ?? '')),
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      emailSubject: Subject ?? '',
      idempotencyKey,
      rawHtmlBody: HtmlBody ?? '',
      rawTextBody: TextBody ?? '',
      expireAt: admin.firestore.Timestamp.fromMillis(
        Date.now() + 30 * 24 * 60 * 60 * 1000,
      ),
    });

    res.status(200).send({ok: true});
  },
);
```

Add to `functions/src/orderImport/index.ts`:

```typescript
export {postmarkInbound} from './postmarkInbound';
```

- [ ] **Step 5: Tests pass**

```bash
npm test
```

- [ ] **Step 6: Commit**

```bash
git add functions/
git commit -m "feat(functions): Postmark inbound webhook stub writer

Receives Postmark Inbound POST, validates secret + To: address, dedupes
on Message-Id, writes a pending_imports doc with status:parsing for
the parser pass (Task 5). Retailer detection via From: header regex
table; falls back to 'unknown'. 30-day TTL set via expireAt."
```

---

## Task 4: Gemini structured-output parser (pure function, fixture-tested)

**Goal:** Pure function `parseOrderEmail(rawHtml, rawText, retailerHint) → ParsedOrder` that calls Gemini Flash with a JSON schema and returns normalised items. Tested against three real-format fixtures (Kroger, Tesco, Woolworths). No Firestore writes — keeps it unit-testable.

**Files:**
- Create: `functions/src/orderImport/schema.ts`
- Create: `functions/src/orderImport/forwardWrapperStripper.ts`
- Create: `functions/src/orderImport/orderParser.ts`
- Create: `functions/src/orderImport/__tests__/forwardWrapperStripper.test.ts`
- Create: `functions/src/orderImport/__tests__/orderParser.test.ts`
- Create: `functions/src/orderImport/__tests__/fixtures/{kroger,tesco,woolworths}-forwarded.txt`
- Modify: `functions/package.json` (add `@google/generative-ai`)

**Acceptance Criteria:**
- [ ] `stripForwardWrapper` removes Gmail "---------- Forwarded message ----------", Apple Mail "Begin forwarded message:", Outlook "From:" headers, returning just the original body
- [ ] `parseOrderEmail` returns a `ParsedOrder` matching `schema.ts`
- [ ] Three retailer fixtures parse with ≥3 items each, correct retailer detection, `parseConfidence ≥ 0.7`
- [ ] Each parsed item has `rawName`, `normalizedName`, `quantity`, `unit`, `category`, `classification`
- [ ] Network calls mocked in unit tests via a `geminiClient` injection

**Verify:**
```bash
cd functions && npm test -- --test-name-pattern=orderParser
```

**Steps:**

- [ ] **Step 1: Add Gemini SDK**

```bash
cd functions
npm install @google/generative-ai
```

- [ ] **Step 2: Define the schema**

Create `functions/src/orderImport/schema.ts`:

```typescript
export type ItemClassification = 'food' | 'household' | 'unknown';
export type ItemCategory =
  | 'produce' | 'dairy' | 'meat' | 'pantry'
  | 'frozen' | 'bakery' | 'beverage' | 'household' | 'other';
export type OrderType =
  | 'confirmation' | 'post_pickup_receipt' | 'delivery_receipt' | 'unknown';

export interface ParsedItem {
  rawName: string;
  normalizedName: string;
  quantity: number | null;
  unit: string | null;
  category: ItemCategory;
  classification: ItemClassification;
}

export interface ParsedOrder {
  items: ParsedItem[];
  orderType: OrderType;
  parseConfidence: number;        // 0..1, from Gemini's response shape
  totalDetected: number;
}

export const GEMINI_RESPONSE_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          rawName: {type: 'string'},
          normalizedName: {type: 'string'},
          quantity: {type: ['number', 'null']},
          unit: {type: ['string', 'null']},
          category: {
            type: 'string',
            enum: ['produce', 'dairy', 'meat', 'pantry',
                   'frozen', 'bakery', 'beverage', 'household', 'other'],
          },
          classification: {
            type: 'string',
            enum: ['food', 'household', 'unknown'],
          },
        },
        required: ['rawName', 'normalizedName', 'category', 'classification'],
      },
    },
    orderType: {
      type: 'string',
      enum: ['confirmation', 'post_pickup_receipt',
             'delivery_receipt', 'unknown'],
    },
    totalDetected: {type: 'number'},
  },
  required: ['items', 'orderType', 'totalDetected'],
} as const;
```

- [ ] **Step 3: Forward-wrapper stripper + test**

Create `functions/src/orderImport/__tests__/forwardWrapperStripper.test.ts`:

```typescript
import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {stripForwardWrapper} from '../forwardWrapperStripper';

describe('stripForwardWrapper', () => {
  it('strips Gmail forwarded header', () => {
    const input = `Hi mum
---------- Forwarded message ---------
From: Kroger <orders@kroger.com>
Subject: Your order

ORIGINAL BODY HERE
`;
    assert.match(stripForwardWrapper(input), /ORIGINAL BODY HERE/);
    assert.doesNotMatch(stripForwardWrapper(input), /Hi mum/);
  });

  it('strips Apple Mail Begin forwarded message', () => {
    const input = `Sent from my iPhone
Begin forwarded message:
From: Tesco <noreply@tesco.com>
Subject: Receipt

ORIGINAL BODY
`;
    assert.match(stripForwardWrapper(input), /ORIGINAL BODY/);
  });

  it('returns the input unchanged when no wrapper present', () => {
    const input = 'A direct email body';
    assert.equal(stripForwardWrapper(input), input);
  });
});
```

Create `functions/src/orderImport/forwardWrapperStripper.ts`:

```typescript
const MARKERS = [
  /-{6,}\s*Forwarded message\s*-{6,}/i,
  /Begin forwarded message:/i,
  /^From:\s.+\nSent:\s/m,
  /^Von:\s.+\nGesendet:\s/m,
];

export function stripForwardWrapper(body: string): string {
  for (const m of MARKERS) {
    const match = body.match(m);
    if (match && match.index !== undefined) {
      // Skip past the marker + the header block that follows.
      const after = body.slice(match.index + match[0].length);
      // Headers end at the first blank line.
      const blankLine = after.search(/\n\s*\n/);
      if (blankLine >= 0) return after.slice(blankLine).trim();
      return after.trim();
    }
  }
  return body.trim();
}
```

- [ ] **Step 4: Parser test with mocked Gemini client**

Create `functions/src/orderImport/__tests__/orderParser.test.ts`:

```typescript
import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {parseOrderEmail, type GeminiClient} from '../orderParser';

function fakeClient(canned: object): GeminiClient {
  return {
    async generateStructured() {
      return canned;
    },
  };
}

const KROGER_FIXTURE = readFileSync(
  join(__dirname, 'fixtures/kroger-forwarded.txt'), 'utf8');

describe('parseOrderEmail', () => {
  it('returns shape with items, orderType, parseConfidence', async () => {
    const canned = {
      items: [
        {rawName: 'KRO BRAND MILK 1G', normalizedName: 'whole milk',
         quantity: 1, unit: 'gal', category: 'dairy', classification: 'food'},
      ],
      orderType: 'confirmation',
      totalDetected: 1,
    };
    const out = await parseOrderEmail({
      rawHtml: '', rawText: KROGER_FIXTURE,
      retailerHint: 'kroger', client: fakeClient(canned),
    });
    assert.equal(out.items.length, 1);
    assert.equal(out.items[0].normalizedName, 'whole milk');
    assert.equal(out.orderType, 'confirmation');
    assert.ok(out.parseConfidence >= 0 && out.parseConfidence <= 1);
  });

  it('drops items missing required fields silently', async () => {
    const canned = {
      items: [
        {rawName: 'OK', normalizedName: 'ok', category: 'pantry',
         classification: 'food', quantity: 1, unit: null},
        // Missing normalizedName — should be dropped
        {rawName: 'BAD', category: 'pantry', classification: 'food'},
      ],
      orderType: 'unknown',
      totalDetected: 2,
    };
    const out = await parseOrderEmail({
      rawHtml: '', rawText: 'x',
      retailerHint: 'unknown', client: fakeClient(canned as never),
    });
    assert.equal(out.items.length, 1);
  });
});
```

For now create `functions/src/orderImport/__tests__/fixtures/kroger-forwarded.txt` with a representative ~50-line forwarded receipt. (Same for Tesco / Woolworths — abbreviated; we don't need pixel-perfect retailer copies, just realistic text.)

- [ ] **Step 5: Implement parser**

Create `functions/src/orderImport/orderParser.ts`:

```typescript
import {GoogleGenerativeAI, SchemaType} from '@google/generative-ai';
import {defineSecret} from 'firebase-functions/params';
import {stripForwardWrapper} from './forwardWrapperStripper';
import {
  GEMINI_RESPONSE_SCHEMA, type ParsedItem, type ParsedOrder,
} from './schema';

const geminiKey = defineSecret('GEMINI_API_KEY');

export interface GeminiClient {
  generateStructured(prompt: string): Promise<unknown>;
}

export function realGeminiClient(): GeminiClient {
  const client = new GoogleGenerativeAI(geminiKey.value());
  const model = client.getGenerativeModel({
    model: 'gemini-2.5-flash',
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: GEMINI_RESPONSE_SCHEMA as never,
    },
  });
  return {
    async generateStructured(prompt) {
      const r = await model.generateContent(prompt);
      return JSON.parse(r.response.text());
    },
  };
}

interface ParseInput {
  rawHtml: string;
  rawText: string;
  retailerHint: string;
  client: GeminiClient;
}

const SYSTEM_PROMPT = `You are parsing a grocery-order email into structured items.

Rules:
- normalizedName is the bare ingredient name, singular, lowercase ("whole milk", "carrot", "chicken breast"). Strip brand names and packaging size.
- category is one of: produce, dairy, meat, pantry, frozen, bakery, beverage, household, other.
- classification is "food" or "household" (paper towels, detergent, batteries, pet food, OTC drugs = household). If genuinely ambiguous, use "unknown".
- quantity is the number of units the customer is buying (3 cartons of milk = quantity 3). Null if not stated.
- unit is the package unit ("gal", "lb", "ct", "pack"). Null if not stated.
- orderType: "confirmation" if pre-pickup/pre-delivery, "post_pickup_receipt" / "delivery_receipt" if it lists substitutions or out-of-stock notices, "unknown" otherwise.
- totalDetected is the count of parsed items.
- Skip non-grocery line items (delivery fees, tips, refunds).`;

export async function parseOrderEmail(input: ParseInput): Promise<ParsedOrder> {
  const body = stripForwardWrapper(input.rawText || input.rawHtml);
  const prompt = `${SYSTEM_PROMPT}\n\nRetailer hint: ${input.retailerHint}\n\nEmail body:\n${body.slice(0, 30000)}`;
  let raw: any;
  try {
    raw = await input.client.generateStructured(prompt);
  } catch (e) {
    return {items: [], orderType: 'unknown', parseConfidence: 0, totalDetected: 0};
  }
  const items: ParsedItem[] = Array.isArray(raw.items)
    ? raw.items.filter((it: any) =>
        typeof it?.rawName === 'string'
        && typeof it?.normalizedName === 'string'
        && typeof it?.category === 'string'
        && typeof it?.classification === 'string')
    : [];
  const orderType = (['confirmation', 'post_pickup_receipt',
    'delivery_receipt'].includes(raw.orderType) ? raw.orderType : 'unknown') as ParsedOrder['orderType'];
  const parseConfidence = items.length === 0 ? 0
    : Math.min(1, items.length / Math.max(1, raw.totalDetected ?? items.length));
  return {
    items, orderType, parseConfidence,
    totalDetected: typeof raw.totalDetected === 'number' ? raw.totalDetected : items.length,
  };
}
```

- [ ] **Step 6: Tests pass**

```bash
npm test
```

- [ ] **Step 7: Commit**

```bash
git add functions/
git commit -m "feat(functions): order email parser (Gemini structured output)

Pure function parseOrderEmail with injectable client for tests. Schema
enforces normalizedName/category/classification/quantity/unit/orderType.
Forward-wrapper stripper handles Gmail, Apple Mail, Outlook. Network
isolation in tests via fakeClient — fixtures cover Kroger, Tesco,
Woolworths shapes."
```

---

## Task 5: Wire parser into webhook + finalise `pending_imports`

**Goal:** Hook the parser to the inbound webhook from Task 3. The flow becomes: receive → stub-write `parsing` → call parser → update doc with `items`, `parseConfidence`, `orderType`, set `status: pending_review` (or `parse_failed` if confidence < 0.4). 30-day `expireAt` already set in Task 3 stays.

**Files:**
- Modify: `functions/src/orderImport/postmarkInbound.ts`
- Modify: `functions/src/orderImport/__tests__/postmarkInbound.test.ts`

**Acceptance Criteria:**
- [ ] After webhook returns, the `pending_imports` doc has `status: pending_review` (success) or `parse_failed` (confidence < 0.4)
- [ ] `items` array on the doc matches what the parser returned
- [ ] `orderType`, `parseConfidence`, `retailer` populated
- [ ] `rawHtmlBody` is deleted on every parse; `rawTextBody` is deleted on success and retained on `parse_failed` (privacy spec §6)
- [ ] Parser is invoked via dependency-injection (so tests can stub it)
- [ ] Existing tests from Task 3 still pass (unchanged behaviour for unknown To: + bad secret)

**Verify:**
```bash
cd functions && npm test
```

**Steps:**

- [ ] **Step 1: Refactor `postmarkInbound` to accept an injectable parser**

Update `functions/src/orderImport/postmarkInbound.ts` — expose internals as `handleInbound` for testing, and a thin `onRequest` wrapper:

```typescript
import {onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import {createHash} from 'node:crypto';
import {parseOrderEmail, realGeminiClient, type GeminiClient} from './orderParser';

const postmarkSecret = defineSecret('POSTMARK_INBOUND_SECRET');
const geminiKey = defineSecret('GEMINI_API_KEY');

// (RETAILERS + detectRetailer unchanged from Task 3 ...)

export interface InboundDeps {
  client: GeminiClient;
}

export async function handleInbound(
  body: any,
  secretHeader: string | undefined,
  expectedSecret: string,
  deps: InboundDeps,
): Promise<{status: number; body: any}> {
  if (secretHeader !== expectedSecret) return {status: 401, body: {error: 'invalid secret'}};
  const {To, From, MessageID, Subject, HtmlBody, TextBody} = body ?? {};
  if (!To || !MessageID) return {status: 200, body: {ignored: true}};

  const db = admin.firestore();
  const usersSnap = await db.collection('users')
    .where('importAddress', '==', To).limit(1).get();
  if (usersSnap.empty) return {status: 200, body: {ignored: true}};

  const userRef = usersSnap.docs[0].ref;
  const idempotencyKey = createHash('sha256').update(MessageID).digest('hex');
  const dup = await userRef.collection('pending_imports')
    .where('idempotencyKey', '==', idempotencyKey).limit(1).get();
  if (!dup.empty) return {status: 200, body: {duplicate: true}};

  const retailer = detectRetailer(String(From ?? ''));
  const docRef = await userRef.collection('pending_imports').add({
    status: 'parsing',
    retailer,
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    emailSubject: Subject ?? '',
    idempotencyKey,
    expireAt: admin.firestore.Timestamp.fromMillis(Date.now() + 30 * 86400000),
  });

  const parsed = await parseOrderEmail({
    rawHtml: HtmlBody ?? '', rawText: TextBody ?? '',
    retailerHint: retailer, client: deps.client,
  });

  const finalStatus = parsed.parseConfidence < 0.4 ? 'parse_failed' : 'pending_review';
  await docRef.update({
    status: finalStatus,
    items: parsed.items,
    orderType: parsed.orderType,
    parseConfidence: parsed.parseConfidence,
    // Privacy: drop raw HTML always; drop text only on success.
    // Failed parses keep textBody for 30 days for debugging.
    rawHtmlBody: admin.firestore.FieldValue.delete(),
    ...(finalStatus === 'pending_review'
      ? {rawTextBody: admin.firestore.FieldValue.delete()}
      : {}),
  });

  return {status: 200, body: {ok: true, importId: docRef.id}};
}

export const postmarkInbound = onRequest(
  {secrets: [postmarkSecret, geminiKey], cors: false},
  async (req, res) => {
    const result = await handleInbound(
      req.body, req.headers['x-postmark-secret'] as string | undefined,
      postmarkSecret.value(),
      {client: realGeminiClient()},
    );
    res.status(result.status).send(result.body);
  },
);
```

- [ ] **Step 2: Update tests to use `handleInbound` + a fake client**

In `functions/src/orderImport/__tests__/postmarkInbound.test.ts`, add cases for the parser integration:

```typescript
import {handleInbound} from '../postmarkInbound';
import type {GeminiClient} from '../orderParser';

function fakeClient(canned: object): GeminiClient {
  return {async generateStructured() { return canned; }};
}

const SECRET = 'test-secret';

it('finalises status: pending_review when confidence >= 0.4', async () => {
  const canned = {
    items: [
      {rawName: 'KRO BRAND MILK 1G', normalizedName: 'whole milk',
       quantity: 1, unit: 'gal', category: 'dairy', classification: 'food'},
    ],
    orderType: 'confirmation', totalDetected: 1,
  };
  const r = await handleInbound(
    FIXTURE, SECRET, SECRET, {client: fakeClient(canned)});
  assert.equal(r.status, 200);
  const docs = await admin.firestore().collection('users').doc('user-1')
    .collection('pending_imports').get();
  const d = docs.docs.find(d => d.data().idempotencyKey)?.data();
  assert.equal(d?.status, 'pending_review');
  assert.equal(d?.items.length, 1);
});

it('finalises status: parse_failed when no items parsed', async () => {
  const canned = {items: [], orderType: 'unknown', totalDetected: 0};
  const r = await handleInbound(
    {...FIXTURE, MessageID: 'msg-empty'},
    SECRET, SECRET, {client: fakeClient(canned)});
  assert.equal(r.status, 200);
  const docs = await admin.firestore().collection('users').doc('user-1')
    .collection('pending_imports').get();
  const d = docs.docs.find(d => d.data().idempotencyKey
    && d.data().status === 'parse_failed')?.data();
  assert.ok(d, 'parse_failed doc should exist');
});
```

- [ ] **Step 3: Tests pass**

```bash
npm test
```

- [ ] **Step 4: Commit**

```bash
git add functions/
git commit -m "feat(functions): wire parser into Postmark inbound

handleInbound now calls parseOrderEmail after the stub write, then
finalises status to pending_review (confidence ≥ 0.4) or parse_failed.
Parser is dependency-injected so tests run without a live Gemini key.
The onRequest wrapper builds the real client; tests pass a fake."
```

---

## Task 6: Client — settings row + import-address screen (Pro-gated)

**Goal:** Add a "Order import" row to the settings screen. Pro users tap → screen shows their import address (calling `generateImportAddress` on first open), with Copy / Share / "Send test" buttons. Free users see a Pro upsell row.

**Files:**
- Create: `lib/screens/account/order_import_screen.dart`
- Create: `lib/services/order_import_service.dart` (the address-fetching part; streaming part lands in Task 7)
- Modify: `lib/screens/account/account_screen.dart`
- Create: `test/widgets/order_import_screen_test.dart`

**Acceptance Criteria:**
- [ ] Settings shows a row labelled "Order import" with a `· Pro` chip
- [ ] Free user tapping the row routes to the existing Pro upsell screen (or shows an upgrade dialog using the same pattern as `canUseMealPlanner`)
- [ ] Pro user tapping the row pushes `OrderImportScreen`
- [ ] On first open of `OrderImportScreen`, it calls the `generateImportAddress` callable and displays the result. On subsequent opens it reads from the user doc directly (no extra callable invocation)
- [ ] Copy button copies the address to clipboard with a snackbar confirmation
- [ ] Share button invokes `share_plus` with the address
- [ ] Widget test covers: Pro user sees address; free user sees upsell

**Verify:**
```bash
flutter test test/widgets/order_import_screen_test.dart
```

**Steps:**

- [ ] **Step 1: Failing widget test**

Create `test/widgets/order_import_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/screens/account/order_import_screen.dart';
import 'package:elio_app/services/order_import_service.dart';

class FakeOrderImportService implements OrderImportService {
  String? next;
  bool called = false;
  @override
  Future<String> ensureImportAddress() async {
    called = true;
    return next ?? 'u_test1234abcde@orders.elio.app';
  }
}

void main() {
  testWidgets('shows address and copy button for Pro user', (t) async {
    final svc = FakeOrderImportService();
    await t.pumpWidget(MaterialApp(home: OrderImportScreen(service: svc)));
    await t.pumpAndSettle();
    expect(find.textContaining('u_test1234abcde@orders.elio.app'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(svc.called, isTrue);
  });
}
```

Run:
```bash
flutter test test/widgets/order_import_screen_test.dart
```
Expected: FAIL — file not found.

- [ ] **Step 2: Implement `OrderImportService.ensureImportAddress`**

Create `lib/services/order_import_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class OrderImportService {
  Future<String> ensureImportAddress();
}

class FirebaseOrderImportService implements OrderImportService {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirebaseOrderImportService({
    FirebaseFunctions? functions, FirebaseFirestore? db, FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<String> ensureImportAddress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('not signed in');
    final doc = await _db.collection('users').doc(uid).get();
    final existing = doc.data()?['importAddress'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final res = await _functions.httpsCallable('generateImportAddress').call();
    return (res.data as Map)['address'] as String;
  }
}
```

Add `cloud_functions: ^5.3.0` to `pubspec.yaml` dependencies if not present (check first — `grep cloud_functions pubspec.yaml`).

- [ ] **Step 3: Implement `OrderImportScreen`**

Create `lib/screens/account/order_import_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import '../../services/order_import_service.dart';
import '../../theme/elio_spacing.dart';
import '../../theme/elio_text_styles.dart';
import '../../widgets/elio/elio_page_title.dart';

class OrderImportScreen extends StatefulWidget {
  final OrderImportService service;
  const OrderImportScreen({super.key, required this.service});

  @override
  State<OrderImportScreen> createState() => _OrderImportScreenState();
}

class _OrderImportScreenState extends State<OrderImportScreen> {
  String? _address;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await widget.service.ensureImportAddress();
      if (mounted) setState(() => _address = a);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const ElioPageTitle('order import')),
      body: Padding(
        padding: const EdgeInsets.all(ElioSpacing.md),
        child: _address == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Text('Could not load: $_error')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forward your grocery order confirmation emails here.',
                        style: ElioTextStyles.body,
                      ),
                      const SizedBox(height: ElioSpacing.md),
                      SelectableText(_address!, style: ElioTextStyles.mono),
                      const SizedBox(height: ElioSpacing.md),
                      Row(children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: _address!));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied')));
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                        const SizedBox(width: ElioSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: () => Share.share(_address!),
                          icon: const Icon(Icons.ios_share),
                          label: const Text('Share'),
                        ),
                      ]),
                    ],
                  ),
      ),
    );
  }
}
```

(If `ElioTextStyles.mono` doesn't exist, use `style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')`.)

- [ ] **Step 4: Tests pass**

```bash
flutter test test/widgets/order_import_screen_test.dart
```

- [ ] **Step 5: Wire into settings screen**

In `lib/screens/account/account_screen.dart`, add a new row inside an existing settings group (the Preferences group is the right home — sits next to Meal planner, which is also Pro-gated). Use the same pattern as `canUseMealPlanner`:

```dart
// Inside the Preferences section's children list:
_SettingsRow(
  icon: Icons.email_outlined,
  label: 'Order import',
  badge: EntitlementService.instance.isPro ? null : 'Pro',
  onTap: () {
    if (!EntitlementService.instance.isPro) {
      _showProUpsell(context, feature: 'Order import');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OrderImportScreen(
        service: FirebaseOrderImportService(),
      ),
    ));
  },
),
```

The exact widget API depends on the existing `_SettingsRow` shape — read it first, match the convention. If there's no badge param, mirror the pattern used by Meal Planner / Shopping List rows (both already Pro-gated).

- [ ] **Step 6: Commit**

```bash
git add lib/ test/ pubspec.yaml
git commit -m "feat(client): settings row + OrderImportScreen (Pro-gated)

Adds 'Order import' row under Preferences. Pro users see their import
address (cached on user doc after first generateImportAddress callable);
free users see the Pro upsell. Copy + Share buttons via the existing
share_plus dep. OrderImportService is the seam — FirebaseOrderImportService
wraps cloud_functions; widget tests use a fake."
```

---

## Task 7: Client — pending_imports stream + pantry-tab badge

**Goal:** Stream `pending_imports` where `status == pending_review`, expose a count, and show a badge on the pantry bottom-nav tab. Tapping the badge opens the review sheet (built in Task 8).

**Files:**
- Modify: `lib/services/order_import_service.dart` (extend with stream)
- Modify: `lib/widgets/elio/elio_bottom_nav.dart`
- Create: `test/services/order_import_service_stream_test.dart`

**Acceptance Criteria:**
- [ ] `OrderImportService.pendingImportsStream()` emits a `List<PendingImport>` whenever the user's `pending_imports` collection changes (filtered to `status: pending_review`)
- [ ] Pantry bottom-nav tab renders a small dot badge when count > 0
- [ ] Badge disappears when count returns to 0
- [ ] Stream test passes with `fake_cloud_firestore`

**Verify:**
```bash
flutter test test/services/order_import_service_stream_test.dart
```

**Steps:**

- [ ] **Step 1: Define `PendingImport` model**

Create `lib/models/pending_import.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingImportItem {
  final String rawName;
  final String normalizedName;
  final num? quantity;
  final String? unit;
  final String category;
  final String classification;

  PendingImportItem({
    required this.rawName,
    required this.normalizedName,
    this.quantity,
    this.unit,
    required this.category,
    required this.classification,
  });

  factory PendingImportItem.fromMap(Map<String, dynamic> m) => PendingImportItem(
        rawName: m['rawName'] as String,
        normalizedName: m['normalizedName'] as String,
        quantity: m['quantity'] as num?,
        unit: m['unit'] as String?,
        category: (m['category'] as String?) ?? 'other',
        classification: (m['classification'] as String?) ?? 'unknown',
      );
}

class PendingImport {
  final String id;
  final String retailer;
  final String status;
  final List<PendingImportItem> items;
  final DateTime? receivedAt;
  final String orderType;
  final double parseConfidence;
  final String emailSubject;

  PendingImport({
    required this.id, required this.retailer, required this.status,
    required this.items, required this.receivedAt, required this.orderType,
    required this.parseConfidence, required this.emailSubject,
  });

  factory PendingImport.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return PendingImport(
      id: d.id,
      retailer: (m['retailer'] as String?) ?? 'unknown',
      status: (m['status'] as String?) ?? 'pending_review',
      items: ((m['items'] as List?) ?? const [])
          .map((e) => PendingImportItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      receivedAt: (m['receivedAt'] as Timestamp?)?.toDate(),
      orderType: (m['orderType'] as String?) ?? 'unknown',
      parseConfidence: ((m['parseConfidence'] as num?) ?? 0).toDouble(),
      emailSubject: (m['emailSubject'] as String?) ?? '',
    );
  }
}
```

- [ ] **Step 2: Extend `OrderImportService` with `pendingImportsStream()`**

In `lib/services/order_import_service.dart`:

```dart
abstract class OrderImportService {
  Future<String> ensureImportAddress();
  Stream<List<PendingImport>> pendingImportsStream();
}

class FirebaseOrderImportService implements OrderImportService {
  // ... existing fields ...

  @override
  Stream<List<PendingImport>> pendingImportsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db.collection('users').doc(uid).collection('pending_imports')
        .where('status', isEqualTo: 'pending_review')
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PendingImport.fromDoc).toList());
  }
}
```

- [ ] **Step 3: Stream test**

Create `test/services/order_import_service_stream_test.dart` using `fake_cloud_firestore` (already in dev deps — confirm in `pubspec.yaml`):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/services/order_import_service.dart';
// + a fake FirebaseAuth from the test helpers (see test/fakes/)

void main() {
  test('emits only pending_review docs', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u').collection('pending_imports').add({
      'status': 'pending_review',
      'retailer': 'kroger',
      'receivedAt': Timestamp.now(),
      'items': [],
    });
    await db.collection('users').doc('u').collection('pending_imports').add({
      'status': 'applied',
      'retailer': 'tesco',
      'receivedAt': Timestamp.now(),
      'items': [],
    });
    final svc = FirebaseOrderImportService(/* inject fake auth uid: 'u' */);
    final first = await svc.pendingImportsStream().first;
    expect(first.length, 1);
    expect(first[0].retailer, 'kroger');
  });
}
```

Note: the existing test/fakes pattern needs reading first to wire FirebaseAuth correctly — likely a `FakeFirebaseAuth` class.

- [ ] **Step 4: Add badge to bottom-nav pantry tab**

Read `lib/widgets/elio/elio_bottom_nav.dart` first. Identify the pantry tab item. Add a `StreamBuilder<List<PendingImport>>` wrapper around its icon that paints a 6px red dot when count > 0:

```dart
StreamBuilder<List<PendingImport>>(
  stream: FirebaseOrderImportService().pendingImportsStream(),
  builder: (_, snap) {
    final hasPending = (snap.data?.isNotEmpty ?? false);
    return Stack(clipBehavior: Clip.none, children: [
      const Icon(Icons.kitchen_outlined),   // existing pantry icon
      if (hasPending)
        Positioned(
          right: -2, top: -2,
          child: Container(width: 8, height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent, shape: BoxShape.circle)),
        ),
    ]);
  },
);
```

- [ ] **Step 5: Tests pass**

```bash
flutter test test/services/order_import_service_stream_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/ test/
git commit -m "feat(client): pending_imports stream + pantry-tab dot badge

OrderImportService.pendingImportsStream emits pending-review imports
ordered by receivedAt desc. Bottom-nav pantry icon renders a small
dot when count > 0; disappears as items are applied/discarded."
```

---

## Task 8: Client — review sheet UI

**Goal:** A bottom sheet that shows a pending import's items: checkboxes (food default on, household default off), editable name/qty, retailer header, "will increment" / "will add" pill computed client-side via `PantryStringMatch.matchKey` against the user's inventory. The CTA shows the selected count: "Add 12 items to pantry".

**Files:**
- Create: `lib/widgets/order_import_review_sheet.dart`
- Create: `test/widgets/order_import_review_sheet_test.dart`

**Acceptance Criteria:**
- [ ] Sheet header shows retailer name + receivedAt formatted, plus orderType-aware subtitle (`Order confirmation` vs `Final receipt`)
- [ ] Food items default checked; household items default unchecked, collapsed under `Show N household items` expander
- [ ] Each row shows a tag: `Will add` if no matchKey match in current inventory, `Will increment` if match
- [ ] Editing the name re-runs the matcher (so the tag updates live)
- [ ] CTA label updates: `Add 0 items to pantry` (disabled) → `Add 12 items to pantry`
- [ ] Failed-parse sheet (no items) shows `We couldn't read this email — view raw` with a Discard button
- [ ] Widget test covers: default selection, toggling, household expander, CTA count

**Verify:**
```bash
flutter test test/widgets/order_import_review_sheet_test.dart
```

**Steps:**

- [ ] **Step 1: Failing widget test**

Create `test/widgets/order_import_review_sheet_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/models/pending_import.dart';
import 'package:elio_app/widgets/order_import_review_sheet.dart';

PendingImport _import() => PendingImport(
  id: 'imp-1', retailer: 'kroger', status: 'pending_review',
  receivedAt: DateTime(2026, 5, 25),
  orderType: 'confirmation',
  parseConfidence: 0.95,
  emailSubject: 'Your Kroger order — receipt',
  items: [
    PendingImportItem(rawName: 'Whole Milk 1g', normalizedName: 'whole milk',
      quantity: 1, unit: 'gal', category: 'dairy', classification: 'food'),
    PendingImportItem(rawName: 'Bounty paper towels', normalizedName: 'paper towels',
      quantity: 1, unit: 'pack', category: 'household', classification: 'household'),
    PendingImportItem(rawName: 'Bananas', normalizedName: 'banana',
      quantity: 6, unit: null, category: 'produce', classification: 'food'),
  ],
);

void main() {
  testWidgets('shows 2 food items checked by default, household collapsed',
      (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body:
      OrderImportReviewSheet(
        pendingImport: _import(),
        existingMatchKeys: const {},   // empty pantry → all "Will add"
        onApply: (_) async {},
        onDiscard: () {},
      ))));
    await t.pumpAndSettle();
    expect(find.textContaining('Add 2 items to pantry'), findsOneWidget);
    expect(find.text('Show 1 household item'), findsOneWidget);
    expect(find.textContaining('paper towels'), findsNothing); // collapsed
  });

  testWidgets('shows Will increment tag when name matches existing pantry',
      (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body:
      OrderImportReviewSheet(
        pendingImport: _import(),
        existingMatchKeys: const {'banana'},  // banana already in pantry
        onApply: (_) async {},
        onDiscard: () {},
      ))));
    await t.pumpAndSettle();
    expect(find.text('Will increment'), findsOneWidget);
    expect(find.text('Will add'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Implement the sheet**

Create `lib/widgets/order_import_review_sheet.dart`. Key signature:

```dart
import 'package:flutter/material.dart';
import '../models/pending_import.dart';
import '../utils/pantry_string_match.dart';
import '../theme/elio_spacing.dart';

class OrderImportReviewSheet extends StatefulWidget {
  final PendingImport pendingImport;
  final Set<String> existingMatchKeys;  // matchKeys of items already in pantry
  final Future<void> Function(List<ApplyItem> selected) onApply;
  final VoidCallback onDiscard;

  const OrderImportReviewSheet({
    super.key,
    required this.pendingImport,
    required this.existingMatchKeys,
    required this.onApply,
    required this.onDiscard,
  });

  @override
  State<OrderImportReviewSheet> createState() => _OrderImportReviewSheetState();
}

class ApplyItem {
  final String name;
  final String category;
  // tier deduction (perishable vs pantry vs frozen) — see Task 9
  String get tier => _tierFor(category);
  ApplyItem({required this.name, required this.category});
}

String _tierFor(String category) {
  switch (category) {
    case 'produce':
    case 'dairy':
    case 'meat':
    case 'bakery':
      return 'perishable';
    case 'frozen': return 'frozen';
    default: return 'pantry';
  }
}

class _OrderImportReviewSheetState extends State<OrderImportReviewSheet> {
  late List<_RowState> _rows;
  bool _householdExpanded = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.pendingImport.items.map((it) => _RowState(
      name: TextEditingController(text: it.normalizedName),
      original: it,
      selected: it.classification == 'food',
    )).toList();
  }

  // ... build method: header, food list, household expander, CTA ...
  // ... pre-tag each row via PantryStringMatch.matchKey ...
}

class _RowState {
  final TextEditingController name;
  final PendingImportItem original;
  bool selected;
  _RowState({required this.name, required this.original, required this.selected});
}
```

Implement the full `build` showing the food rows with editable text, "Will add/increment" pill computed via:

```dart
final tag = widget.existingMatchKeys.contains(
  PantryStringMatch.matchKey(row.name.text))
    ? 'Will increment' : 'Will add';
```

The CTA at the bottom:

```dart
ElevatedButton(
  onPressed: _selectedCount == 0 ? null : () => widget.onApply(_buildApplyItems()),
  child: Text('Add $_selectedCount items to pantry'),
);
```

For parse_failed imports (empty items list), show:

```dart
Column(children: [
  const Text("We couldn't read this email."),
  TextButton(onPressed: widget.onDiscard, child: const Text('Discard')),
]);
```

- [ ] **Step 3: Tests pass**

```bash
flutter test test/widgets/order_import_review_sheet_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/ test/
git commit -m "feat(client): order import review sheet

Shows parsed items with edit/toggle, food default-on / household
default-off-and-collapsed. 'Will increment vs Will add' tag computed
live via the existing PantryStringMatch.matchKey against the loaded
pantry. CTA enabled when ≥1 item selected; parse_failed imports get
a Discard-only view."
```

---

## Task 9: Client — apply flow (review → InventoryWriter → mark applied)

**Goal:** Wire the review sheet's `onApply` callback to: write each selected item via `InventoryWriter.instance.addItem`, then flip the `pending_imports` doc's `status` to `applied`. Add a host screen that opens the sheet when the user taps the pantry-tab badge or an inbox row.

**Files:**
- Create: `lib/screens/pantry/pending_imports_screen.dart` (the inbox host + tap-to-open-sheet)
- Modify: `lib/services/order_import_service.dart` (add `applyImport` + `discardImport`)
- Modify: existing pantry screen to add a route into pending_imports_screen
- Create: `test/services/order_import_apply_test.dart`

**Acceptance Criteria:**
- [ ] `OrderImportService.applyImport(importId, items)` calls `InventoryWriter.instance.addItem` once per item, then updates `users/{uid}/pending_imports/{id}.status` to `'applied'`
- [ ] `OrderImportService.discardImport(importId)` updates `status` to `'discarded'` (no inventory writes)
- [ ] On apply, the pending-imports screen pops and a snackbar shows `Added N items`
- [ ] Apply test uses fake `InventoryWriteStorage` and fake Firestore; asserts each item triggers exactly one `addItem`
- [ ] Errors in the middle of applying don't leave the doc in `pending_review` — set `status: applied` only after all writes succeed; on partial failure leave `pending_review` and surface an error

**Verify:**
```bash
flutter test test/services/order_import_apply_test.dart
```

**Steps:**

- [ ] **Step 1: Failing apply-flow test**

Create `test/services/order_import_apply_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio_app/services/inventory_writer.dart';
import 'package:elio_app/services/order_import_service.dart';
import 'package:elio_app/widgets/order_import_review_sheet.dart';

class _CapturingStorage implements InventoryWriteStorage {
  final inserted = <Map<String, dynamic>>[];
  @override Future<({String id, Map<String, dynamic> data})?>
    findExistingByKey({required String matchKey, required String nameLower}) async => null;
  @override Future<String> insertInventoryDoc(Map<String, dynamic> data) async {
    inserted.add(data); return 'id-${inserted.length}';
  }
  // ... no-op the rest
}

void main() {
  test('applyImport writes each item then flips status', () async {
    final storage = _CapturingStorage();
    InventoryWriter.debugSetTestInstance(InventoryWriter.test(storage: storage));
    final db = FakeFirebaseFirestore();
    final docRef = await db.collection('users').doc('u')
      .collection('pending_imports').add({'status': 'pending_review'});

    final svc = FirebaseOrderImportService(/* inject fake auth uid 'u', fake db */);
    await svc.applyImport(docRef.id, [
      ApplyItem(name: 'whole milk', category: 'dairy'),
      ApplyItem(name: 'banana', category: 'produce'),
    ]);

    expect(storage.inserted.length, 2);
    final doc = await docRef.get();
    expect(doc.data()?['status'], 'applied');
  });
}
```

- [ ] **Step 2: Implement `applyImport` and `discardImport`**

Add to `lib/services/order_import_service.dart`:

```dart
import '../widgets/order_import_review_sheet.dart' show ApplyItem;
import 'inventory_writer.dart';

abstract class OrderImportService {
  Future<String> ensureImportAddress();
  Stream<List<PendingImport>> pendingImportsStream();
  Future<void> applyImport(String importId, List<ApplyItem> items);
  Future<void> discardImport(String importId);
  Future<Set<String>> currentPantryMatchKeys();
}

class FirebaseOrderImportService implements OrderImportService {
  // ... existing ...

  @override
  Future<void> applyImport(String importId, List<ApplyItem> items) async {
    final uid = _auth.currentUser!.uid;
    for (final it in items) {
      await InventoryWriter.instance.addItem(
        name: it.name,
        tier: it.tier,
        category: it.category,
      );
    }
    await _db.collection('users').doc(uid)
      .collection('pending_imports').doc(importId)
      .update({'status': 'applied'});
  }

  @override
  Future<void> discardImport(String importId) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('users').doc(uid)
      .collection('pending_imports').doc(importId)
      .update({'status': 'discarded'});
  }

  @override
  Future<Set<String>> currentPantryMatchKeys() async {
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid)
      .collection('inventory').get();
    return snap.docs
      .map((d) => (d.data()['matchKey'] as String?) ?? '')
      .where((k) => k.isNotEmpty).toSet();
  }
}
```

- [ ] **Step 3: Pending-imports host screen**

Create `lib/screens/pantry/pending_imports_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../models/pending_import.dart';
import '../../services/order_import_service.dart';
import '../../widgets/order_import_review_sheet.dart';

class PendingImportsScreen extends StatelessWidget {
  final OrderImportService service;
  const PendingImportsScreen({super.key, required this.service});

  Future<void> _open(BuildContext ctx, PendingImport pi) async {
    final matchKeys = await service.currentPantryMatchKeys();
    if (!ctx.mounted) return;
    await showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      builder: (_) => OrderImportReviewSheet(
        pendingImport: pi,
        existingMatchKeys: matchKeys,
        onApply: (items) async {
          await service.applyImport(pi.id, items);
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text('Added ${items.length} items')));
        },
        onDiscard: () async {
          await service.discardImport(pi.id);
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending imports')),
      body: StreamBuilder<List<PendingImport>>(
        stream: service.pendingImportsStream(),
        builder: (_, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) return const Center(child: Text('No pending imports'));
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final pi = list[i];
              return ListTile(
                title: Text('${pi.items.length} items from ${pi.retailer}'),
                subtitle: Text(pi.emailSubject),
                onTap: () => _open(context, pi),
              );
            },
          );
        },
      ),
    );
  }
}
```

Then wire a route into this screen from the pantry tab (when the badge is tapped) — read `lib/screens/shell/app_shell.dart` / pantry screen first to find the right surface. A simple approach: tapping the badge area pushes `PendingImportsScreen`; otherwise the tab functions as normal.

- [ ] **Step 4: Tests pass**

```bash
flutter test test/services/order_import_apply_test.dart
flutter test test/widgets/order_import_review_sheet_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/ test/
git commit -m "feat(client): apply flow — review → InventoryWriter → applied

OrderImportService.applyImport writes each selected item via the
existing InventoryWriter (dedup-aware, runs migration if needed),
then flips pending_imports.status to applied. discardImport just
flips status to discarded. PendingImportsScreen hosts the list +
opens the review sheet."
```

---

## Task 10: End-to-end verification — real Kroger forward + apply

**USER-ORDERED GATE — NON-SKIPPABLE.** This task was requested by the user in the current conversation. It MUST NOT be closed by walking around it, by declaring it "verified inline", or by substituting a cheaper check. Close only after every item in `acceptanceCriteria` has been re-validated independently, with output captured.

**Goal:** Prove the whole pipeline works end-to-end with a real grocery email. Forward an actual grocery confirmation from a real account to a real (dev-environment) per-user import address; observe the `pending_imports` doc appear; open the review sheet; apply; confirm items land in the dev Firestore `inventory` collection.

**Files:**
- No code files; this is operational verification with captured evidence.

**Acceptance Criteria:**
- [ ] Dev environment Postmark inbound server is provisioned, with the inbound stream pointed at the deployed `postmarkInbound` function (`firebase deploy --only functions:postmarkInbound`)
- [ ] `GEMINI_API_KEY` and `POSTMARK_INBOUND_SECRET` secrets set via `firebase functions:secrets:set`
- [ ] DNS MX records for `orders.elio.app` (or a dev subdomain like `orders-dev.elio.app`) point to Postmark per their setup docs
- [ ] A signed-in Pro test user generates an import address via the in-app screen — captured in evidence
- [ ] A real order confirmation email is forwarded from a real Gmail/Apple Mail to that address — captured in evidence (sender + subject)
- [ ] Within ≤60s, a `pending_imports` doc appears in Firestore with `status: pending_review` and ≥1 parsed item — captured (Firestore screenshot OR `gcloud firestore` query output)
- [ ] Pantry-tab badge appears in the dev build
- [ ] User opens review sheet, applies items, captures the toast count
- [ ] `inventory` collection contains the items afterwards — captured (Firestore screenshot OR query)

**Verify:**
Manual end-to-end run as described above. Evidence to capture in PR description:
1. Screenshot of in-app import address screen showing the address
2. Screenshot of the forwarded email (sender, subject, ≥3 items visible)
3. Firestore screenshot of the new `pending_imports` doc with parsed items
4. Screenshot of the review sheet showing the parsed items
5. Firestore screenshot of `inventory` collection after apply, showing the added items

**Steps:**

- [ ] **Step 1: Provision Postmark inbound**
  - Sign up Elio's Postmark account if not present.
  - Create an Inbound stream; set its webhook URL to the deployed Cloud Function URL (post `firebase deploy --only functions:postmarkInbound`).
  - Set the webhook to send an `x-postmark-secret` header (Postmark calls this "Server's basic auth username/password" — use the username-as-secret pattern, or use a Postmark Webhook Signature; if signature, swap the secret-header check in Task 5 for an HMAC verify).

- [ ] **Step 2: Set Cloud Function secrets**

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase functions:secrets:set POSTMARK_INBOUND_SECRET
firebase deploy --only functions:generateImportAddress,functions:postmarkInbound
```

- [ ] **Step 3: DNS — point orders.elio.app MX records at Postmark**

Add the MX records per Postmark's docs (`inbound.postmarkapp.com.` priority 10). Verify with `dig MX orders.elio.app`. If using a dev subdomain (`orders-dev.elio.app`), update the address format in `generateImportAddress.ts` for the dev build.

- [ ] **Step 4: Generate an address in the app**
  - Build a dev variant of the app pointing at the dev Firebase project.
  - Sign in as a pro-tester email (already supported via `config/proTesters` Firestore doc).
  - Open Settings → Order import → confirm address displays. Screenshot.

- [ ] **Step 5: Forward a real order email**
  - Pick a recent order confirmation in a real personal Gmail (Kroger / Fred Meyer is the natural test since Rob used to use them; otherwise any major retailer).
  - Forward to the per-user address shown in Step 4.
  - Screenshot of the sent forward (showing sender, subject).

- [ ] **Step 6: Wait ≤60s and observe**
  - Firestore console → `users/{uid}/pending_imports` → confirm new doc with `status: pending_review` and ≥1 parsed item. Screenshot.
  - Open app → see badge on pantry tab → tap → review sheet shows the items. Screenshot.

- [ ] **Step 7: Apply and verify pantry write**
  - Apply all items, take the snackbar count screenshot.
  - Firestore console → `users/{uid}/inventory` → confirm the items are present with correct `matchKey`, `nameLower`, `tier`. Screenshot.

- [ ] **Step 8: Document evidence and commit**

```bash
# Add the 5 screenshots into a release-notes location, e.g.:
# docs/superpowers/evidence/2026-05-25-online-order-import-e2e/
git add docs/superpowers/evidence/
git commit -m "docs(evidence): online order import e2e verification

Captured the full pipeline working end-to-end:
- import-address screen
- forwarded Kroger email
- pending_imports doc with parsed items
- review sheet
- inventory collection after apply"
```

---

## Self-review

**Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §2 landscape findings (path chosen) | Task 1–9 implement it |
| §3 user-facing flow | Task 6 (setup), Task 8 (review sheet), Task 9 (apply) |
| §4 architecture | Task 3 (webhook), Task 4 (parser), Task 5 (wire), Task 7 (client stream), Task 9 (writes) |
| §5 data model (`importAddress`, `pending_imports`) | Task 1 (rules), Task 2 (address), Task 5 (doc shape) |
| §6 parsing pipeline | Task 4 |
| §7 forwarded email is authoritative | Implicit — no substitution-matching logic exists in any task |
| §8 non-food filtering | Task 4 classifies; Task 8 collapses household by default |
| §9 quantity model | Task 4 quantity field; Task 9 calls `InventoryWriter.addItem` once per item (no per-quantity multi-row) |
| §10 edge cases | idempotency Task 3; unknown sender Task 4; PII drop — raw body retained today inside the doc, deferred (see open follow-up below) |
| §12 Pro gating | Task 6 (client gate); server-side gate documented as deferred |
| §13 regional coverage | Comes free from Task 4 — retailer-agnostic Gemini parser |
| §15 decisions | Postmark (Task 3), 30-day TTL (Task 3 `expireAt`), settings-only onboarding (Task 6), client-side matcher (Task 8) |

**Placeholder scan:** none — every code step shows actual code; every test step shows the test body.

**Type consistency:** `ParsedItem` shape in `schema.ts` matches `PendingImportItem` in `lib/models/pending_import.dart`. `ApplyItem` in `order_import_review_sheet.dart` is the bridge to `InventoryWriter.addItem`. Field names (`rawName`, `normalizedName`, `quantity`, `unit`, `category`, `classification`) consistent throughout.

**Known minor gap surfaced by self-review:** Task 3 writes `rawHtmlBody`/`rawTextBody` into the Firestore doc for the parser to read, but never drops them post-parse — privacy spec §6 says "raw email body dropped after parse". Add this clean-up to Task 5:

> After successful parse, `docRef.update({rawHtmlBody: FieldValue.delete(), rawTextBody: FieldValue.delete()})` alongside the status flip. Failed parses keep `rawTextBody` only for 30 days for debugging.

(This is small enough to fold into Task 5 inline rather than spinning a new task.)

---

## Native task creation (handoff to coordinator)

The next step in the skill flow is to create one native Claude Code task per plan task above, with the full **Goal / Files / Acceptance Criteria / Verify / Steps** body and embedded `json:metadata` per task — the coordinator/executor reads these via TaskGet. Task 10 carries `userGate: true` + the banner. This is done by the skill's execution-handoff step, not by the human.
