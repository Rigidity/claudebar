<div align="center">

# ClaudeBar

**Your Claude usage, one glance away in the macOS menu bar.**

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![No Xcode needed](https://img.shields.io/badge/Xcode-not%20required-lightgrey)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/hero-dark.png">
  <img alt="ClaudeBar's menu bar label (S 42% · W 71%) with its usage panel open, showing session, weekly and Fable weekly bars with pace markers" src="docs/hero-light.png" width="640">
</picture>

</div>

## What it shows

The menu bar shows your 5-hour **session** usage and your **weekly** usage (`S 42% · W 71%`). Click it to open the panel, which shows each limit:

| Limit | Window | Notes |
| --- | --- | --- |
| **Session** | 5 hours | Shows "No active session" when idle |
| **Weekly** | 7 days | Across all models |
| **Fable weekly** | 7 days | Only appears if your plan has a Fable-specific limit |

Each limit has a usage bar, a countdown to its reset, and your **pace**.

## Pacing

ClaudeBar compares your usage against an even burn rate across the window. The tick on each bar marks where that even pace would put you right now.

- **In reserve** (green): you're under pace. If 40% of the week has passed and you've used 30%, you're **10% in reserve**.
- **In deficit** (red): you're over pace. Used 50% at the same point? You're **10% in deficit**.

The bar turns **orange** when you're over pace and **red** above 90%.

## Getting started

### Requirements

- macOS 13 or later
- A Swift toolchain. The Command Line Tools are enough; you don't need Xcode.
- A logged-in Claude Code (`claude`). ClaudeBar reads the same OAuth token from the `Claude Code-credentials` keychain item.

### Build & run

```sh
./build.sh
open build/ClaudeBar.app
```

> [!TIP]
> To launch it at login, copy `build/ClaudeBar.app` to `/Applications` and add it under **System Settings → General → Login Items**.

## How it works

- Usage comes from `https://api.anthropic.com/api/oauth/usage`, the same endpoint Claude Code's `/usage` command calls.
- It refreshes every 5 minutes, or when you click ↻. The token is read again on every refresh, so tokens Claude Code refreshes get picked up.
- If it says your token expired, run `claude` once to refresh it.

> [!WARNING]
> The usage endpoint is undocumented and may change without notice.
