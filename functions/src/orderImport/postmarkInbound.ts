import {onRequest} from 'firebase-functions/v2/https';
import {defineSecret} from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import {createHash} from 'node:crypto';
import {
  parseOrderEmail,
  realGeminiClient,
  type GeminiClient,
} from './orderParser';

// POSTMARK_INBOUND_SECRET stores the Basic-Auth credential pair the
// Postmark inbound webhook sends. Format: "username:password" — the same
// string you embed in the webhook URL on Postmark's side
// (https://username:password@<function-url>). We compare against the
// base64-decoded `Authorization: Basic ...` header value byte-for-byte.
const postmarkSecret = defineSecret('POSTMARK_INBOUND_SECRET');
const geminiKey = defineSecret('GEMINI_API_KEY');

/**
 * Returns true if the request's Authorization header is a valid Basic Auth
 * value matching `expected` ("username:password"). Returns false on any
 * malformed header, wrong scheme, or credential mismatch.
 */
export function verifyBasicAuth(
  authHeader: string | undefined,
  expected: string,
): boolean {
  if (!authHeader || !authHeader.toLowerCase().startsWith('basic ')) {
    return false;
  }
  try {
    const decoded = Buffer.from(authHeader.slice(6).trim(), 'base64')
      .toString('utf8');
    return decoded === expected;
  } catch {
    return false;
  }
}

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

export interface InboundDeps {
  client: GeminiClient;
}

export interface InboundResult {
  status: number;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  body: any;
}

/**
 * Pure-ish webhook handler — extracted so unit tests can call it directly
 * with a fake Gemini client (no live API key needed). The exported
 * `postmarkInbound` onRequest is a thin wrapper that builds the real client.
 */
export async function handleInbound(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  body: any,
  authHeader: string | undefined,
  expectedCredentials: string,
  deps: InboundDeps,
): Promise<InboundResult> {
  if (!verifyBasicAuth(authHeader, expectedCredentials)) {
    return {status: 401, body: {error: 'invalid credentials'}};
  }
  const {To, From, MessageID, Subject, HtmlBody, TextBody} = body ?? {};
  if (!To || !MessageID) {
    return {status: 200, body: {ignored: true}};
  }

  const db = admin.firestore();
  const usersSnap = await db.collection('users')
    .where('importAddress', '==', To).limit(1).get();
  if (usersSnap.empty) {
    return {status: 200, body: {ignored: true}};
  }
  const userRef = usersSnap.docs[0].ref;
  const idempotencyKey = createHash('sha256').update(MessageID).digest('hex');

  // Idempotency check
  const dup = await userRef.collection('pending_imports')
    .where('idempotencyKey', '==', idempotencyKey).limit(1).get();
  if (!dup.empty) {
    return {status: 200, body: {duplicate: true}};
  }

  const retailer = detectRetailer(String(From ?? ''));
  const docRef = await userRef.collection('pending_imports').add({
    status: 'parsing',
    retailer,
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    emailSubject: Subject ?? '',
    idempotencyKey,
    rawHtmlBody: HtmlBody ?? '',
    rawTextBody: TextBody ?? '',
    expireAt: admin.firestore.Timestamp.fromMillis(
      Date.now() + 30 * 24 * 60 * 60 * 1000,
    ),
  });

  const parsed = await parseOrderEmail({
    rawHtml: HtmlBody ?? '',
    rawText: TextBody ?? '',
    retailerHint: retailer,
    client: deps.client,
  });

  const finalStatus = parsed.parseConfidence < 0.4
    ? 'parse_failed'
    : 'pending_review';

  // Privacy (spec §6): drop the raw HTML body on every parse. Drop the
  // text body only on success — failed parses retain rawTextBody for 30
  // days for debugging, then the TTL on expireAt sweeps it.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const update: Record<string, any> = {
    status: finalStatus,
    items: parsed.items,
    orderType: parsed.orderType,
    parseConfidence: parsed.parseConfidence,
    rawHtmlBody: admin.firestore.FieldValue.delete(),
  };
  if (finalStatus === 'pending_review') {
    update.rawTextBody = admin.firestore.FieldValue.delete();
  }
  await docRef.update(update);

  return {status: 200, body: {ok: true, importId: docRef.id}};
}

export const postmarkInbound = onRequest(
  {secrets: [postmarkSecret, geminiKey], cors: false},
  async (req, res) => {
    const result = await handleInbound(
      req.body,
      req.headers['authorization'] as string | undefined,
      postmarkSecret.value(),
      {client: realGeminiClient()},
    );
    res.status(result.status).send(result.body);
  },
);
