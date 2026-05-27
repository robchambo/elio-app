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
    assert.doesNotMatch(stripForwardWrapper(input), /Sent from my iPhone/);
  });

  it('strips Outlook From:/Sent: header block', () => {
    const input = `FYI

From: Woolworths <noreply@woolworths.com.au>
Sent: Monday, 25 May 2026 14:32
To: rob@example.com
Subject: Your delivery receipt

ORIGINAL OUTLOOK BODY
`;
    assert.match(stripForwardWrapper(input), /ORIGINAL OUTLOOK BODY/);
    assert.doesNotMatch(stripForwardWrapper(input), /^FYI$/m);
  });

  it('returns the input unchanged (trimmed) when no wrapper present', () => {
    const input = 'A direct email body';
    assert.equal(stripForwardWrapper(input), input);
  });
});
