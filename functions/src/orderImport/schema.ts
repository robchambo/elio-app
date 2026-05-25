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
  parseConfidence: number;        // 0..1, derived from Gemini's response shape
  totalDetected: number;
}

// JSON-schema-ish shape describing the Gemini structured-output contract.
// We keep this in a plain-object form so it's easy to assert on in tests;
// the runtime adapter (realGeminiClient) translates it to the SDK's
// SchemaType enum at the call site.
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
          quantity: {type: 'number', nullable: true},
          unit: {type: 'string', nullable: true},
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
