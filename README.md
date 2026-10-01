# TouchGuard

TouchGuard is a native macOS menu bar app that ignores accidental clicks immediately after you type. It is a clean-room replacement for the legacy TouchGuard command-line tool: no root daemon, no copied plist, and no manual `launchctl` commands.

## What it does

- Runs as a small menu bar app.
- Clearly reports whether protection is active, paused, or missing permission.
- Lets you adjust the click suppression interval from 0.1 to 1.0 seconds.
- Restores its Core Graphics event tap when macOS disables it.
- Uses `SMAppService` to enable Launch at Login on first launch, with a toggle to turn it off.
- Stores settings locally and makes no network requests.

TouchGuard filters mouse-button events from all pointing devices during the short post-typing interval. Core Graphics does not reliably identify whether a click came from a trackpad or an external mouse.

## Requirements

- macOS 13 or later.
- Accessibility permission, requested on first use.

## Build

```bash
make test
make build
```

`make build` uses ad-hoc code signing by default. To preserve the app identity across local rebuilds, pass a signing identity:

```bash
CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make build
```

Install and launch it from `/Applications` before enabling Launch at Login:

```bash
make install
```

## Why this is a new project

The legacy TouchGuard repositories do not declare an open-source license. This implementation copies no source or binaries from them and uses only public macOS APIs.

## License

MIT
