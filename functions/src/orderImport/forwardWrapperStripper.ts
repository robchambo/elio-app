// Strips the leading "I'm forwarding this to you" chrome that mail clients
// prepend to the body. We want the original retailer message, not the
// user's "Hi mum, here's my Tesco order" note above it.
const MARKERS = [
  /-{3,}\s*Forwarded message\s*-{3,}/i,         // Gmail
  /Begin forwarded message:/i,                   // Apple Mail
  /^From:\s.+\nSent:\s.+/m,                      // Outlook (English)
  /^Von:\s.+\nGesendet:\s.+/m,                   // Outlook (German)
];

export function stripForwardWrapper(body: string): string {
  for (const m of MARKERS) {
    const match = body.match(m);
    if (match && match.index !== undefined) {
      // Skip past the marker line itself, then skip past the header block
      // that follows ("From:", "To:", "Subject:" lines). Headers end at the
      // first blank line.
      const after = body.slice(match.index + match[0].length);
      const blankLine = after.search(/\n\s*\n/);
      if (blankLine >= 0) return after.slice(blankLine).trim();
      return after.trim();
    }
  }
  return body.trim();
}
