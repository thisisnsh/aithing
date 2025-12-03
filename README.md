<!--
  README.md
  AIThing
  
  Created by Nishant Singh Hada on December 2025.
  https://aithing.dev
-->

# AI Thing

A powerful macOS menu bar app that brings AI assistance to your fingertips. Access AI capabilities from anywhere on your Mac with a simple keyboard shortcut.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)

**Website:** [https://aithing.dev](https://aithing.dev)

## Features

- **Instant Access** - Summon AI assistance from anywhere with `Ctrl+Space` or `Ctrl+Option+Space`
- **Floating Interface** - A sleek, non-intrusive floating window that stays out of your way
- **MCP (Model Context Protocol) Support** - Connect to external tools and agents for extended capabilities
- **File Attachments** - Drag and drop images, PDFs, and text files directly into conversations
- **Text Selection Context** - Automatically capture selected text from any application
- **Screenshot Context** - Include application screenshots for visual context in your queries
- **Chat History** - Persistent conversation history with easy navigation
- **Auto Updates** - Built-in update mechanism via Sparkle

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)
- An API key from a supported LLM provider

## Supported LLM Providers

Currently supported:
- **Anthropic (Claude)** - Full support for Claude models

*More providers coming soon!*

## Installation

### Download

Visit [https://aithing.dev](https://aithing.dev) to download the latest release.

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/thisisnsh/AIThing.git
   cd AIThing
   ```

2. Open the project in Xcode:
   ```bash
   open AIThing.xcodeproj
   ```

3. Build and run the project (`Cmd+R`)

## Configuration

### API Key Setup

1. Launch AI Thing
2. Open Settings (click the gear icon or use the menu)
3. Navigate to the **Model** tab
4. Enter your API key for your preferred LLM provider:
   - **Anthropic**: Get your API key from [console.anthropic.com](https://console.anthropic.com/settings/keys)

For detailed setup instructions, visit: [https://aithing.dev/getstarted](https://aithing.dev/getstarted)

### Permissions

AI Thing requires the following permissions:
- **Accessibility** - To detect text selection across applications
- **Screen Recording** - To capture screenshots for visual context (optional)

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Space` | Toggle AI Thing window |
| `Ctrl+Option+Space` | Toggle AI Thing window (alternative) |

### Basic Workflow

1. Select text in any application (optional)
2. Press `Ctrl+Space` to open AI Thing
3. Type your query or use the selected text as context
4. Drag and drop files if needed
5. Press Enter to send

### MCP Agents

AI Thing supports the Model Context Protocol (MCP) for connecting external tools:

1. Go to Settings → Agents
2. Add an MCP server via URL or local command
3. Enable the agent to make its tools available in conversations

Use `@aithing` prefix in your queries to access built-in AI Thing tools.

## Tech Stack

- **SwiftUI** - Modern declarative UI framework
- **Firebase** - Authentication and analytics
- **Model Context Protocol (MCP)** - Tool and agent integration
- **Sparkle** - Auto-update framework
- **HotKey** - Global keyboard shortcut handling

## Project Structure

```
AIThing/
├── AIThingApp.swift          # App entry point
├── AppDelegate.swift         # Application delegate and window management
├── Managers/
│   ├── Intelligence/         # LLM integration and streaming
│   ├── Models/               # Data models
│   ├── Tools/                # MCP and OAuth implementations
│   └── Extensions/           # Swift extensions
└── Views/
    ├── ChatView/             # Chat interface components
    ├── NotchView/            # Floating window UI
    └── Components/           # Reusable UI components
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

For security vulnerabilities, please see our [Security Policy](SECURITY.md).

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Website:** [https://aithing.dev](https://aithing.dev)
- **Email:** help@aithing.dev
- **Issues:** [GitHub Issues](https://github.com/thisisnsh/AIThing/issues)

---

Made with ❤️ by [Nishant Singh Hada](https://github.com/thisisnsh)
