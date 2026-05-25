import {onCall, HttpsError} from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {randomBytes} from 'node:crypto';

const BASE32 = 'abcdefghijklmnopqrstuvwxyz234567';

function mintToken(): string {
  // 9 random bytes → 72 bits. We consume 65 bits (13 chars × 5 bits) and
  // discard the high 7 bits. Result is 13 base32 chars.
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
  const existing = snap.data()?.importAddress as string | undefined;
  if (existing) return {address: existing};
  const address = `u_${mintToken()}@orders.elio.app`;
  await ref.set({importAddress: address}, {merge: true});
  return {address};
});
