# Contributing

Thanks for your interest! This repository is primarily a reference of an infrastructure setup. Still, improvements are welcome.

## Ground Rules

- Do not commit real secrets. Use `.env` locally and only commit `.env.example`.
- Keep docker-compose changes minimal and documented.
- Prefer PRs with a short rationale in the description.
- Avoid introducing proprietary or paid service dependencies.

## Workflow

1. Fork the repo.
2. Create a feature branch: `git checkout -b feature/short-description`.
3. Make changes (update relevant README sections if needed).
4. Run basic validation (lint markdown if available).
5. Open a PR.

## Security / Secrets

If you accidentally commit a secret:

1. Force remove it (`git rm --cached <file>`), rotate the secret externally.
2. Amend commit & push force if before PR, otherwise open an issue describing rotation done.

## License

By contributing you agree that your contributions are licensed under the MIT License.
