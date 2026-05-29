import {GoogleGenerativeAI, SchemaType} from '@google/generative-ai';
import {logger} from 'firebase-functions/v2';
import {defineSecret} from 'firebase-functions/params';
import {stripForwardWrapper} from './forwardWrapperStripper';
import {
  type ItemCategory,
  type ItemClassification,
  type ParsedItem,
  type ParsedOrder,
} from './schema';

const geminiKey = defineSecret('GEMINI_API_KEY');

// The SDK's responseSchema uses its own `SchemaType` enum, not raw JSON-schema
// strings. We build the schema once at module load using that enum so the
// "real" client passes shape validation. The plain-object GEMINI_RESPONSE_SCHEMA
// in schema.ts is the human-readable contract; this is the runtime form.
const SDK_RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    items: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          rawName: {type: SchemaType.STRING},
          normalizedName: {type: SchemaType.STRING},
          quantity: {type: SchemaType.NUMBER, nullable: true},
          unit: {type: SchemaType.STRING, nullable: true},
          category: {
            type: SchemaType.STRING,
            enum: ['produce', 'dairy', 'meat', 'pantry',
                   'frozen', 'bakery', 'beverage', 'household', 'other'],
          },
          classification: {
            type: SchemaType.STRING,
            enum: ['food', 'household', 'unknown'],
          },
        },
        required: ['rawName', 'normalizedName', 'category', 'classification'],
      },
    },
    orderType: {
      type: SchemaType.STRING,
      enum: ['confirmation', 'post_pickup_receipt',
             'delivery_receipt', 'unknown'],
    },
    totalDetected: {type: SchemaType.NUMBER},
  },
  required: ['items', 'orderType', 'totalDetected'],
};

export interface GeminiClient {
  generateStructured(prompt: string): Promise<unknown>;
}

export function realGeminiClient(): GeminiClient {
  const client = new GoogleGenerativeAI(geminiKey.value());
  const model = client.getGenerativeModel({
    model: 'gemini-2.5-flash',
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: SDK_RESPONSE_SCHEMA as never,
    },
  });
  return {
    async generateStructured(prompt) {
      const r = await model.generateContent(prompt);
      return JSON.parse(r.response.text());
    },
  };
}

export interface ParseInput {
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

const VALID_CATEGORIES: readonly ItemCategory[] = [
  'produce', 'dairy', 'meat', 'pantry',
  'frozen', 'bakery', 'beverage', 'household', 'other',
];
const VALID_CLASSIFICATIONS: readonly ItemClassification[] = [
  'food', 'household', 'unknown',
];
const VALID_ORDER_TYPES = [
  'confirmation', 'post_pickup_receipt', 'delivery_receipt',
] as const;

interface RawItem {
  rawName?: unknown;
  normalizedName?: unknown;
  quantity?: unknown;
  unit?: unknown;
  category?: unknown;
  classification?: unknown;
}

function isValidItem(it: RawItem): it is {
  rawName: string;
  normalizedName: string;
  quantity?: number | null;
  unit?: string | null;
  category: ItemCategory;
  classification: ItemClassification;
} {
  return typeof it?.rawName === 'string'
    && it.rawName.length > 0
    && typeof it.normalizedName === 'string'
    && it.normalizedName.length > 0
    && typeof it.category === 'string'
    && (VALID_CATEGORIES as readonly string[]).includes(it.category)
    && typeof it.classification === 'string'
    && (VALID_CLASSIFICATIONS as readonly string[]).includes(it.classification);
}

export async function parseOrderEmail(
  input: ParseInput,
): Promise<ParsedOrder> {
  const body = stripForwardWrapper(input.rawText || input.rawHtml);
  // Diagnostic (29 May 2026, order-import-not-working investigation):
  // body sizes tell us if a forwarded email arrives with an empty/tiny
  // text body (→ extraction problem) vs full content (→ Gemini problem).
  // No content logged — lengths only — to keep email bodies out of logs.
  logger.info('parseOrderEmail: body prepared', {
    rawTextLen: input.rawText?.length ?? 0,
    rawHtmlLen: input.rawHtml?.length ?? 0,
    strippedLen: body.length,
    retailerHint: input.retailerHint,
  });
  const prompt =
    `${SYSTEM_PROMPT}\n\nRetailer hint: ${input.retailerHint}\n\n` +
    `Email body:\n${body.slice(0, 30000)}`;

  let raw: {
    items?: RawItem[];
    orderType?: unknown;
    totalDetected?: unknown;
  };
  try {
    raw = await input.client.generateStructured(prompt) as typeof raw;
  } catch (e) {
    // Was previously a silent swallow → looked identical to "0 items
    // parsed". Log so we can tell a Gemini API/key/model failure apart
    // from a genuine no-items email.
    logger.error('parseOrderEmail: Gemini call threw', {
      error: e instanceof Error ? e.message : String(e),
    });
    return {items: [], orderType: 'unknown', parseConfidence: 0, totalDetected: 0};
  }

  const items: ParsedItem[] = Array.isArray(raw?.items)
    ? raw.items
        .filter(isValidItem)
        .map((it) => ({
          rawName: it.rawName,
          normalizedName: it.normalizedName,
          quantity: typeof it.quantity === 'number' ? it.quantity : null,
          unit: typeof it.unit === 'string' ? it.unit : null,
          category: it.category,
          classification: it.classification,
        }))
    : [];

  const orderType = (VALID_ORDER_TYPES as readonly string[]).includes(
      raw?.orderType as string)
    ? (raw.orderType as ParsedOrder['orderType'])
    : 'unknown';

  const totalDetected = typeof raw?.totalDetected === 'number'
    ? raw.totalDetected
    : items.length;

  // Confidence = ratio of items we accepted to items Gemini claims it found.
  // 0 when we got nothing; clamped to [0, 1].
  const parseConfidence = items.length === 0
    ? 0
    : Math.min(1, items.length / Math.max(1, totalDetected));

  // Diagnostic: raw vs valid item counts. If rawItemCount > 0 but
  // validItemCount == 0, Gemini returned items that failed isValidItem
  // (schema/category mismatch). If both 0, Gemini found nothing in the
  // body it was given.
  logger.info('parseOrderEmail: gemini returned', {
    rawItemCount: Array.isArray(raw?.items) ? raw.items.length : -1,
    validItemCount: items.length,
    totalDetected,
    orderType,
  });

  return {items, orderType, parseConfidence, totalDetected};
}
