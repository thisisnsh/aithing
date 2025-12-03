<!--
  CONTRIBUTING.md
  AIThing
  
  Created by Nishant Singh Hada on December 2025.
  https://aithing.dev
-->

# Contributing to AI Thing

Thank you for your interest in contributing to AI Thing! We welcome contributions from the community and are grateful for any help you can provide.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to help@aithing.dev.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment (see [Development Setup](#development-setup))
4. Create a new branch for your contribution
5. Make your changes
6. Submit a pull request

## How to Contribute

There are many ways to contribute to AI Thing:

- **Report bugs** - Help us identify and fix issues
- **Suggest features** - Share ideas for new functionality
- **Improve documentation** - Help make our docs clearer and more comprehensive
- **Submit pull requests** - Contribute code fixes or new features
- **Add LLM provider support** - Help expand our multi-provider capabilities
- **Create MCP tools** - Build new tools and agents for the ecosystem

## Development Setup

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Git

### Setup Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/thisisnsh/AIThing.git
   cd AIThing
   ```

2. **Open in Xcode:**
   ```bash
   open AIThing.xcodeproj
   ```

3. **Configure signing:**
   - Select the AIThing target
   - Go to Signing & Capabilities
   - Select your development team

4. **Build and run:**
   - Press `Cmd+R` to build and run the project

### Project Structure

```
AIThing/
├── AIThingApp.swift          # App entry point
├── AppDelegate.swift         # Window management and hotkeys
├── Managers/
│   ├── Intelligence/         # LLM integration
│   ├── Models/               # Data models
│   ├── Tools/                # MCP and OAuth
│   └── Extensions/           # Swift extensions
└── Views/
    ├── ChatView/             # Chat interface
    ├── NotchView/            # Floating window
    └── Components/           # Reusable components
```

## Pull Request Process

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes:**
   - Write clear, concise commit messages
   - Keep commits focused and atomic
   - Add tests if applicable

3. **Test your changes:**
   - Ensure the app builds without warnings
   - Test the functionality on your local machine
   - Verify existing features still work

4. **Submit the pull request:**
   - Push your branch to your fork
   - Create a pull request against the `main` branch
   - Fill out the PR template completely
   - Link any related issues

5. **Address review feedback:**
   - Respond to comments promptly
   - Make requested changes
   - Re-request review when ready

### PR Requirements

- All tests must pass
- Code must build without warnings
- Follow the style guidelines
- Include documentation for new features
- Update README.md if necessary

## Style Guidelines

### Swift Code Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions focused and concise
- Add comments for complex logic
- Use `// MARK:` comments to organize code sections

### SwiftUI Best Practices

- Extract reusable views into separate files
- Use `@State`, `@Binding`, `@StateObject` appropriately
- Keep view bodies simple and readable
- Use view modifiers consistently

### Code Organization

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Body (for SwiftUI views)
// MARK: - Methods
// MARK: - Private Methods
```

### Naming Conventions

- **Types:** PascalCase (e.g., `ChatMessage`, `IntelligenceManager`)
- **Variables/Functions:** camelCase (e.g., `sendMessage`, `currentUser`)
- **Constants:** camelCase (e.g., `maxTokens`, `defaultModel`)

## Reporting Bugs

When reporting bugs, please include:

1. **Description:** Clear description of the bug
2. **Steps to Reproduce:** Detailed steps to reproduce the issue
3. **Expected Behavior:** What you expected to happen
4. **Actual Behavior:** What actually happened
5. **Environment:**
   - macOS version
   - AI Thing version
   - Any relevant configuration
6. **Screenshots/Logs:** If applicable

Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md) when creating issues.

## Requesting Features

When requesting features, please include:

1. **Problem Statement:** What problem does this solve?
2. **Proposed Solution:** Your idea for the feature
3. **Alternatives Considered:** Other approaches you've thought about
4. **Additional Context:** Mockups, examples, or references

Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md) when creating issues.

## Adding LLM Provider Support

AI Thing is designed to support multiple LLM providers. To add a new provider:

1. Create a new manager in `Managers/Intelligence/`
2. Implement the required protocol methods
3. Add configuration UI in Settings
4. Update documentation
5. Submit a PR with tests

## Questions?

- **General questions:** Open a [GitHub Discussion](https://github.com/thisisnsh/AIThing/discussions)
- **Bug reports:** Open a [GitHub Issue](https://github.com/thisisnsh/AIThing/issues)
- **Security issues:** See [SECURITY.md](SECURITY.md)
- **Email:** help@aithing.dev

---

Thank you for contributing to AI Thing!

