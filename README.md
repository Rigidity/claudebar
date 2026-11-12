# ClaudeBar

A tiny macOS menu bar app that shows your Claude usage: the 5-hour session, the weekly limit, and the Fable weekly limit. For each one it also shows how far ahead of or behind an even pace you are.

The pace is linear. If 40% of the week has passed and you've used 30%, you're **10% in reserve**. If you've used 50%, you're **10% in deficit**. The tick on each bar marks where an even pace would put you.

## Requirements

- macOS 13+
- Swift toolchain (the Command Line Tools are enough; you don't need Xcode)
- Logged in to Claude Code (`claude`). ClaudeBar reads the same OAuth token from the `Claude Code-credentials` keychain item.

## Build & run

```sh
./build.sh
open build/ClaudeBar.app
```

To start it at login, add `build/ClaudeBar.app` (or a copy in `/Applications`) under System Settings → General → Login Items.

## Notes

- Data comes from `https://api.anthropic.com/api/oauth/usage`, the endpoint Claude Code's `/usage` uses. It's undocumented and could change.
- It refreshes every 5 minutes, or when you click refresh. The token is read again on every refresh, so tokens refreshed by Claude Code get picked up. If it says the token expired, run `claude` once.
