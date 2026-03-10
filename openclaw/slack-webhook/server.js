/**
 * Minimal Slack Interactivity webhook for OpenClaw SEO.
 * Handles "Publicera" button: runs publish-draft.sh and updates the Slack message.
 *
 * Env:
 *   SLACK_SIGNING_SECRET  – from Slack app Basic Information
 *   PUBLISH_CMD           – shell command to run; use literal SLUG, e.g.:
 *                           ssh tha 'docker exec $(docker ps -q -f name=openclaw | head -1) /data/.openclaw/scripts/publish-draft.sh SLUG'
 *   PORT                  – default 3000
 *
 * Slack: Interactivity & Shortcuts → Request URL = https://your-host/slack-interaction
 */

const express = require('express');
const crypto = require('crypto');
const { exec } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3000;
const SIGNING_SECRET = process.env.SLACK_SIGNING_SECRET;
const PUBLISH_CMD = process.env.PUBLISH_CMD;

// We need the raw body for signature verification
app.use(
  '/slack-interaction',
  express.raw({ type: 'application/x-www-form-urlencoded', limit: '1mb' }),
  (req, res, next) => {
    if (req.body && typeof req.body.toString === 'function') {
      req.rawBody = req.body.toString('utf8');
    }
    next();
  }
);

function verifySlackSignature(rawBody, signature, timestamp) {
  if (!SIGNING_SECRET) return false;
  if (!timestamp || Math.abs(Date.now() / 1000 - parseInt(timestamp, 10)) > 60 * 5) return false;
  const sigBasestring = `v0:${timestamp}:${rawBody}`;
  const mySig = 'v0=' + crypto.createHmac('sha256', SIGNING_SECRET).update(sigBasestring).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(mySig, 'utf8'), Buffer.from(signature, 'utf8'));
}

function parsePayload(rawBody) {
  const params = new URLSearchParams(rawBody);
  const payloadStr = params.get('payload');
  if (!payloadStr) return null;
  try {
    return JSON.parse(payloadStr);
  } catch {
    return null;
  }
}

function updateSlackMessage(responseUrl, text) {
  return fetch(responseUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text, replace_original: true })
  }).catch((err) => console.error('Slack response_url error:', err));
}

app.post('/slack-interaction', (req, res) => {
  const rawBody = req.rawBody || (req.body && req.body.toString ? req.body.toString('utf8') : '');
  const signature = req.headers['x-slack-signature'];
  const timestamp = req.headers['x-slack-request-timestamp'];

  if (!verifySlackSignature(rawBody, signature || '', timestamp)) {
    return res.status(401).send('Invalid signature');
  }

  const payload = parsePayload(rawBody);
  if (!payload || payload.type !== 'block_actions') {
    return res.status(200).send();
  }

  const action = payload.actions && payload.actions[0];
  const responseUrl = payload.response_url;

  if (!action || action.action_id !== 'publish_draft') {
    return res.status(200).send();
  }

  const slug = (action.value || '').trim();
  if (!slug) {
    if (responseUrl) updateSlackMessage(responseUrl, '❌ Slug saknas.');
    return res.status(200).send();
  }

  // Answer Slack within 3 seconds
  if (responseUrl) {
    updateSlackMessage(responseUrl, '⏳ Publicerar …');
  }
  res.status(200).send();

  // Run publish in background
  if (!PUBLISH_CMD || !PUBLISH_CMD.includes('SLUG')) {
    if (responseUrl) updateSlackMessage(responseUrl, '❌ PUBLISH_CMD inte konfigurerad (saknar SLUG).');
    return;
  }

  const cmd = PUBLISH_CMD.replace(/\bSLUG\b/g, slug);
  exec(cmd, { timeout: 120000, maxBuffer: 1024 * 1024 }, (err, stdout, stderr) => {
    let msg;
    if (err) {
      msg = `❌ Publicering misslyckades:\n\`\`\`${(stderr || stdout || err.message || '').slice(0, 500)}\`\`\``;
    } else {
      const out = (stdout || '').trim();
      const urlMatch = out.match(/Published:\s*(https:\/\/\S+)/);
      msg = urlMatch
        ? `✅ Publicerat. Verifiera här (kan ta 1–2 min): ${urlMatch[1]}`
        : `✅ Klar.\n\`\`\`${out.slice(0, 400)}\`\`\``;
    }
    if (responseUrl) updateSlackMessage(responseUrl, msg);
  });
});

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'openclaw-slack-webhook' });
});

app.listen(PORT, () => {
  console.log(`OpenClaw Slack webhook listening on port ${PORT}`);
  if (!SIGNING_SECRET) console.warn('SLACK_SIGNING_SECRET not set – requests will be rejected');
  if (!PUBLISH_CMD) console.warn('PUBLISH_CMD not set – publish button will not run script');
});
