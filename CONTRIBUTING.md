# Contributing to AI Thing

Thanks for your interest in AI Thing! We're reimagining it in the open, and everyone is welcome to help. That includes first-time contributors.

## Ways to contribute

- **Fix a bug** or build a feature
- **Report a bug** or suggest an idea by [opening an issue](https://github.com/thisisnsh/aithing/issues/new)
- **Improve the docs**, from typos to guides
- **Share feedback** on the direction of the new app
- **Review pull requests** and help test changes

You don't need permission to start. Small fixes can go straight to a pull request. For larger changes, we suggest opening an issue first. That way we can agree on the approach before you spend a lot of time on it.

## Development setup

You need [Node.js](https://nodejs.org) 20+ and [Rust](https://www.rust-lang.org/tools/install). See the [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/) for anything else your OS needs.

```bash
git clone https://github.com/<your-username>/aithing.git
cd aithing/aithing-desktop
npm install
npm run tauri dev
```

| Folder | What it is |
| --- | --- |
| `aithing-desktop/src` | Frontend (HTML, CSS, JavaScript, built with Vite) |
| `aithing-desktop/src-tauri` | Rust backend and Tauri config |
| `aithing-website` | Website and docs |
| `v1` | The original Swift macOS app (see [v1/README.md](v1/README.md)) |

## Making a pull request

1. Fork the repository and create a branch from `main`
2. Make your changes and check that the app still runs
3. Write a clear commit message that says what changed and why
4. Open a pull request that describes your change, and link any related issue

Keep each pull request focused on one change. Pull requests are easier to review that way. Draft pull requests are welcome if you want early feedback.

## Guidelines

- Match the style of the code around your change
- Keep changes small and easy to review
- Test on macOS and Windows if you can. Otherwise, say in the pull request which OS you tested on.
- Update docs when behavior changes

## Questions

Open an issue or email **[help@aithing.dev](mailto:help@aithing.dev)**.

## Code of conduct

Be kind, respectful and constructive. We want AI Thing to be a welcoming place for everyone.
