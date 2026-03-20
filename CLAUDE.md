# Claude CLI – Project Instructions

This project uses autonomous mode. Read and follow `docs/guides/CLAUDE-CLI-AUTONOMOUS-PROMPT.txt`.

## Quick summary

**Act freely** (no approval needed): read/edit files, run scripts, SSH to `tha`, apt upgrade, deploy/restart containers via Coolify API, git add/commit, SEO work up to draft, AEO article refreshes (stage-refresh.sh + publish-draft.sh → auto-push to site repos).

**Wait for approval** (`⏸️ GODKÄNN`): git push to **this repo** (tur-coolify-setup), publish *new* article (`publicera <slug>`), delete data, change secrets, change Coolify env vars, new paid services.

## Key facts

- SSH alias: `tha` (Hetzner, 46.62.206.47)
- Coolify API token: `~/.coolify-token`
- Deploy script: `scripts/coolify-update.sh`
- OpenClaw container: `openclaw-w44cc84w8kog4og400008csg`
- Sync to container: `./scripts/openclaw-install-seo-agent.sh`
- Commit style: `feat:` / `fix:` / `docs:` + `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`
- gh CLI active account must be `emilingemarkarlsson` for push (switch with `gh auth switch --user emilingemarkarlsson`)

## Full rules

See `docs/guides/CLAUDE-CLI-AUTONOMOUS-MODE.md` for complete autonomous/approval action list.
