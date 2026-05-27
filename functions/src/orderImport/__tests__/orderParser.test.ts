import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {parseOrderEmail, type GeminiClient} from '../orderParser';

function fakeClient(canned: unknown): GeminiClient {
  return {
    async generateStructured() {
      return canned;
    },
  };
}

function throwingClient(): GeminiClient {
  return {
    async generateStructured() {
      throw new Error('network down');
    },
  };
}

const KROGER_FIXTURE = readFileSync(
  join(__dirname, 'fixtures/kroger-forwarded.txt'), 'utf8');
const TESCO_FIXTURE = readFileSync(
  join(__dirname, 'fixtures/tesco-forwarded.txt'), 'utf8');
const WOOLWORTHS_FIXTURE = readFileSync(
  join(__dirname, 'fixtures/woolworths-forwarded.txt'), 'utf8');

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
    assert.equal(out.items[0].category, 'dairy');
    assert.equal(out.items[0].classification, 'food');
    assert.equal(out.orderType, 'confirmation');
    assert.ok(out.parseConfidence >= 0 && out.parseConfidence <= 1);
    assert.equal(out.totalDetected, 1);
  });

  it('drops items missing required fields silently', async () => {
    const canned = {
      items: [
        {rawName: 'OK', normalizedName: 'ok', category: 'pantry',
         classification: 'food', quantity: 1, unit: null},
        // Missing normalizedName — should be dropped
        {rawName: 'BAD', category: 'pantry', classification: 'food'},
        // Missing category — should be dropped
        {rawName: 'WORSE', normalizedName: 'worse', classification: 'food'},
        // Missing classification — should be dropped
        {rawName: 'WORST', normalizedName: 'worst', category: 'pantry'},
      ],
      orderType: 'unknown',
      totalDetected: 4,
    };
    const out = await parseOrderEmail({
      rawHtml: '', rawText: 'x',
      retailerHint: 'unknown', client: fakeClient(canned),
    });
    assert.equal(out.items.length, 1);
    assert.equal(out.items[0].normalizedName, 'ok');
  });

  it('coerces unknown orderType to "unknown"', async () => {
    const canned = {items: [], orderType: 'something_weird', totalDetected: 0};
    const out = await parseOrderEmail({
      rawHtml: '', rawText: 'x',
      retailerHint: 'unknown', client: fakeClient(canned),
    });
    assert.equal(out.orderType, 'unknown');
    assert.equal(out.parseConfidence, 0);
  });

  it('returns empty result when client throws (network down)', async () => {
    const out = await parseOrderEmail({
      rawHtml: '', rawText: 'whatever',
      retailerHint: 'kroger', client: throwingClient(),
    });
    assert.equal(out.items.length, 0);
    assert.equal(out.orderType, 'unknown');
    assert.equal(out.parseConfidence, 0);
    assert.equal(out.totalDetected, 0);
  });

  it('parses a Tesco-shaped fixture with 3+ items', async () => {
    const canned = {
      items: [
        {rawName: 'Tesco British Semi Skimmed Milk 2.272L',
         normalizedName: 'semi skimmed milk', quantity: 2, unit: 'L',
         category: 'dairy', classification: 'food'},
        {rawName: 'Tesco Free Range Eggs Large 12pk',
         normalizedName: 'eggs', quantity: 1, unit: 'pack',
         category: 'dairy', classification: 'food'},
        {rawName: 'Tesco Wholemeal Bread 800g',
         normalizedName: 'wholemeal bread', quantity: 1, unit: 'loaf',
         category: 'bakery', classification: 'food'},
      ],
      orderType: 'delivery_receipt',
      totalDetected: 3,
    };
    const out = await parseOrderEmail({
      rawHtml: '', rawText: TESCO_FIXTURE,
      retailerHint: 'tesco', client: fakeClient(canned),
    });
    assert.ok(out.items.length >= 3);
    assert.equal(out.orderType, 'delivery_receipt');
    assert.ok(out.parseConfidence >= 0.7);
  });

  it('parses a Woolworths-shaped fixture with 3+ items', async () => {
    const canned = {
      items: [
        {rawName: 'Woolworths Bananas Cavendish 1kg',
         normalizedName: 'banana', quantity: 1, unit: 'kg',
         category: 'produce', classification: 'food'},
        {rawName: 'Woolworths Chicken Breast Fillets 600g',
         normalizedName: 'chicken breast', quantity: 1, unit: 'pack',
         category: 'meat', classification: 'food'},
        {rawName: 'Quilton Toilet Tissue 12 pack',
         normalizedName: 'toilet paper', quantity: 1, unit: 'pack',
         category: 'household', classification: 'household'},
      ],
      orderType: 'delivery_receipt',
      totalDetected: 3,
    };
    const out = await parseOrderEmail({
      rawHtml: '', rawText: WOOLWORTHS_FIXTURE,
      retailerHint: 'woolworths', client: fakeClient(canned),
    });
    assert.ok(out.items.length >= 3);
    assert.equal(out.items[2].classification, 'household');
    assert.ok(out.parseConfidence >= 0.7);
  });

  it('parseConfidence is < 1 when Gemini claims more than we accepted', async () => {
    const canned = {
      items: [
        {rawName: 'A', normalizedName: 'a', category: 'pantry',
         classification: 'food', quantity: 1, unit: null},
      ],
      orderType: 'confirmation',
      totalDetected: 4,   // claims 4 but only one validates
    };
    const out = await parseOrderEmail({
      rawHtml: '', rawText: KROGER_FIXTURE,
      retailerHint: 'kroger', client: fakeClient(canned),
    });
    assert.equal(out.items.length, 1);
    assert.equal(out.totalDetected, 4);
    assert.ok(out.parseConfidence < 1);
    assert.ok(out.parseConfidence > 0);
  });
});
