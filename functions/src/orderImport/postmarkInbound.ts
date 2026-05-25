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
