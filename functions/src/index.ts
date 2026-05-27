/**
 * Elio Cloud Functions — Crashlytics → Notion pipe (Tier 2)
 *
 * Subscribes to all four Firebase Alerts crashlytics event types and
 * upserts a row in the Notion Crashes database for each issue. Idempotent
 * on Crashlytics Issue ID — re-firing events update the same Notion row
 * rather than creating duplicates.
 *
 * Notion DB: Operations → Crashes
 *   id: 32affae3-cb5e-4256-b4f5-a81692f35b72
 *
 * Schema lives in Notion; this file maps Crashlytics event payloads to
 * the property names. If you change a property name in Notion, update
 * `buildProperties` below.
 *
 * Token storage: NOTION_TOKEN lives in Firebase Secret Manager. Set with:
 *   firebase functions:secrets:set NOTION_TOKEN
 *
 * Forward-compat for Tier 3 (auto-triage): the Crashes DB has empty
 * `Claude analysis` and `Linked PR` columns that this Function leaves
 * untouched — a future routine fills them in via the Anthropic API.
 */

import {logger} from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

// Initialise Admin SDK once for the whole codebase. The orderImport
// functions use admin.firestore() at request time; without this they
// throw "The default Firebase app does not exist."
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Re-export the orderImport module's functions (generateImportAddress,
// postmarkInbound, etc.). Cloud Functions deployment picks these up
// alongside the Crashlytics handlers defined in this file.
export * from './orderImport';
import {defineSecret} from 'firebase-functions/params';
import {
  onNewFatalIssuePublished,
  onNewNonfatalIssuePublished,
  onVelocityAlertPublished,
  onRegressionAlertPublished,
} from 'firebase-functions/v2/alerts/crashlytics';
import {Client} from '@notionhq/client';

// ─── Constants ────────────────────────────────────────────────────────

const notionToken = defineSecret('NOTION_TOKEN');

/** Crashes DB id (without dashes is also accepted by the Notion SDK). */
const CRASHES_DB_ID = '32affae3-cb5e-4256-b4f5-a81692f35b72';

const PROJECT_ID = 'elio-prototype';

/** Android app id from google-services.json. iOS gets added later. */
const ANDROID_APP_ID = 'android:com.elio.elio_app';

/** Notion rich-text content cap (the API cap is 2000 chars per item). */
const NOTION_TEXT_CAP = 1900;

// ─── Types ────────────────────────────────────────────────────────────

type CrashType = 'Fatal' | 'Non-fatal' | 'Velocity alert' | 'Regression';

interface NormalizedIssue {
  id: string;
  title: string;
  subtitle?: string;
  appVersion?: string;
  type: CrashType;
  count?: number;
  crashPercentage?: number;
  resolveTime?: string;
  crashlyticsUrl: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────

function buildCrashlyticsUrl(issueId: string): string {
  // Format Crashlytics deep-link to the specific issue.
  return `https://console.firebase.google.com/project/${PROJECT_ID}` +
    `/crashlytics/app/${ANDROID_APP_ID}/issues/${issueId}`;
}

function truncate(input: string | undefined | null, max = NOTION_TEXT_CAP): string {
  if (!input) return '';
  return input.length > max ? `${input.slice(0, max - 1)}…` : input;
}

function buildProperties(issue: NormalizedIssue): Record<string, unknown> {
  const titleText = truncate(issue.title || 'Untitled crash', 200);
  const props: Record<string, unknown> = {
    Title: {
      title: [{type: 'text', text: {content: titleText}}],
    },
    'Issue ID': {
      rich_text: [{type: 'text', text: {content: issue.id}}],
    },
    Type: {
      select: {name: issue.type},
    },
    Status: {
      select: {name: 'New'},
    },
    'Crashlytics URL': {
      url: issue.crashlyticsUrl,
    },
  };

  if (issue.appVersion) {
    props['App version'] = {
      rich_text: [{type: 'text', text: {content: truncate(issue.appVersion, 200)}}],
    };
  }

  if (issue.count !== undefined && Number.isFinite(issue.count)) {
    props.Count = {number: issue.count};
  }

  if (issue.crashPercentage !== undefined && Number.isFinite(issue.crashPercentage)) {
    // Velocity alerts come with a percentage; round to 2dp for sanity.
    props.Count = {number: Math.round(issue.crashPercentage * 100) / 100};
  }

  // Crashlytics gives us subtitle (file/line context) — store it in the
  // page body as a paragraph rather than a property so it doesn't bloat
  // the table view. (Page body comes through `children`, set in `create`
  // call site; properties are scalar / structured fields only.)

  return props;
}

function buildBodyChildren(issue: NormalizedIssue): unknown[] {
  const children: unknown[] = [];

  if (issue.subtitle) {
    children.push({
      object: 'block',
      type: 'paragraph',
      paragraph: {
        rich_text: [{
          type: 'text',
          text: {content: truncate(issue.subtitle)},
          annotations: {code: true},
        }],
      },
    });
  }

  if (issue.resolveTime) {
    children.push({
      object: 'block',
      type: 'callout',
      callout: {
        icon: {type: 'emoji', emoji: '⚠️'},
        rich_text: [{
          type: 'text',
          text: {content: `Regression: previously resolved at ${issue.resolveTime}.`},
        }],
        color: 'orange_background',
      },
    });
  }

  children.push({
    object: 'block',
    type: 'paragraph',
    paragraph: {
      rich_text: [{
        type: 'text',
        text: {content: 'Open in Crashlytics: '},
      }, {
        type: 'text',
        text: {content: issue.crashlyticsUrl, link: {url: issue.crashlyticsUrl}},
      }],
    },
  });

  return children;
}

/**
 * Idempotent upsert: query the Crashes DB by Issue ID; if a row exists,
 * update its properties; otherwise create a new one. Stops Velocity /
 * Regression events from creating duplicate rows for the same crash.
 */
async function upsertCrashRow(
  client: Client,
  issue: NormalizedIssue,
): Promise<void> {
  const existing = await client.databases.query({
    database_id: CRASHES_DB_ID,
    filter: {
      property: 'Issue ID',
      rich_text: {equals: issue.id},
    },
    page_size: 1,
  });

  const properties = buildProperties(issue);

  if (existing.results.length > 0) {
    const pageId = existing.results[0].id;
    await client.pages.update({
      page_id: pageId,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      properties: properties as any,
    });
    logger.info('Updated existing Crashes row', {
      issueId: issue.id,
      pageId,
      type: issue.type,
    });
    return;
  }

  const created = await client.pages.create({
    parent: {database_id: CRASHES_DB_ID},
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    properties: properties as any,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    children: buildBodyChildren(issue) as any,
  });
  logger.info('Created new Crashes row', {
    issueId: issue.id,
    pageId: created.id,
    type: issue.type,
  });
}

/**
 * Wrap the Notion call in try/catch. We log + swallow errors rather than
 * throwing — Firebase Functions retries on uncaught throws, and a
 * deterministic Notion API failure (e.g. schema drift) would otherwise
 * burn retries indefinitely. Crashlytics alerts are not idempotent
 * upstream — re-firing fixes themselves later.
 */
async function safeUpsert(issue: NormalizedIssue): Promise<void> {
  try {
    const client = new Client({auth: notionToken.value()});
    await upsertCrashRow(client, issue);
  } catch (err) {
    logger.error('Notion upsert failed', {
      issueId: issue.id,
      type: issue.type,
      error: err instanceof Error ? err.message : String(err),
      stack: err instanceof Error ? err.stack : undefined,
    });
  }
}

// ─── Functions ────────────────────────────────────────────────────────

export const crashlyticsFatal = onNewFatalIssuePublished(
  {secrets: [notionToken]},
  async (event) => {
    const issue = event.data.payload.issue;
    await safeUpsert({
      id: issue.id,
      title: issue.title,
      subtitle: issue.subtitle,
      appVersion: issue.appVersion,
      type: 'Fatal',
      crashlyticsUrl: buildCrashlyticsUrl(issue.id),
    });
  },
);

export const crashlyticsNonfatal = onNewNonfatalIssuePublished(
  {secrets: [notionToken]},
  async (event) => {
    const issue = event.data.payload.issue;
    await safeUpsert({
      id: issue.id,
      title: issue.title,
      subtitle: issue.subtitle,
      appVersion: issue.appVersion,
      type: 'Non-fatal',
      crashlyticsUrl: buildCrashlyticsUrl(issue.id),
    });
  },
);

export const crashlyticsVelocity = onVelocityAlertPublished(
  {secrets: [notionToken]},
  async (event) => {
    const payload = event.data.payload;
    const issue = payload.issue;
    await safeUpsert({
      id: issue.id,
      title: issue.title,
      subtitle: issue.subtitle,
      appVersion: issue.appVersion,
      type: 'Velocity alert',
      count: payload.crashCount,
      crashPercentage: payload.crashPercentage,
      crashlyticsUrl: buildCrashlyticsUrl(issue.id),
    });
  },
);

export const crashlyticsRegression = onRegressionAlertPublished(
  {secrets: [notionToken]},
  async (event) => {
    const payload = event.data.payload;
    const issue = payload.issue;
    await safeUpsert({
      id: issue.id,
      title: issue.title,
      subtitle: issue.subtitle,
      appVersion: issue.appVersion,
      type: 'Regression',
      resolveTime: payload.resolveTime,
      crashlyticsUrl: buildCrashlyticsUrl(issue.id),
    });
  },
);
