# AI Thing v1

The original [AI Thing](https://aithing.dev) macOS app, written in Swift. Download the [**latest**](https://aithing.dev/latest) release.

AI Thing v1 is a privacy-first AI automation tool that lets AI agents handle complex and repetitive tasks in parallel and in the background.

![summary](https://download.aithing.dev/summary-transparent.png)

## Features

- **Privacy First**: Everything stays local — your conversations, files, and API keys
- **BYOK Models**: Use your API keys for frontier Anthropic, OpenAI and Gemini models
- **Model Switching**: Switch between multiple models in a single conversation
- **Multiple Agents**: Connect agents like Google Workspace, GitHub, Notion, Asana, and more
- **MCP Servers**: Bring your own MCP servers (remote or local)
- **Background Automations**: Set up recurring or one-off automations that run on your schedule
- **Complex Tasks**: Run tasks that span multiple apps and tools

## Development

You need **Xcode** with Swift.

1. Open `aithing-mac/AIThing.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies
3. Build and run (`⌘R`)

```
aithing-mac/AIThing/
├── Managers/          # Business logic and core functionality
│   ├── Automation/    # Automation handling
│   ├── Context/       # App context and screen capture
│   ├── Firebase/      # Authentication and storage
│   ├── Intelligence/  # AI provider integrations
│   └── Tools/         # OAuth and external tool integrations
└── Views/             # SwiftUI views
    ├── ChatView/      # Chat interface components
    ├── IntelligenceView/  # Main intelligence interface
    ├── NotchView/     # Notch UI and window management
    └── SettingsView/  # Settings interface
```

New work is happening in [`aithing-desktop`](../aithing-desktop). See the [main README](../README.md).
