# Contributing to AI Thing

Thank you for your interest in contributing to AI Thing! We're excited to have you as part of our community.

## Getting Started

### Before You Begin

1. **Star the repository** ⭐ - Show your support for the project!
2. **Check existing issues** - See if someone else has already reported the issue or requested the feature
3. **Read the README** - Familiarize yourself with the project's goals and features

## How to Contribute

### 1. Open an Issue First

Before making any changes, please **open an issue** to discuss your proposed contribution. This helps us:
- Avoid duplicate work
- Ensure your contribution aligns with the project's direction
- Provide feedback and guidance early in the process

**Issue Types:**
- 🐛 **Bug Report** - Something isn't working as expected
- ✨ **Feature Request** - Suggest a new feature or enhancement
- 📚 **Documentation** - Improvements to documentation
- ❓ **Question** - General questions about the project

### 2. Make a Pull Request

Once your issue has been discussed and approved:

1. **Fork the repository** to your GitHub account
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/aithing-lab/aithing-mac.git
   cd aithing-mac
   ```

3. **Create a new branch** for your changes:
   ```bash
   git checkout -b fix/issue-123-description
   # or
   git checkout -b feature/issue-123-description
   ```

4. **Make your changes** following our coding guidelines (see below)

5. **Commit your changes** with a clear message:
   ```bash
   git commit -m "Fix: Description of fix (closes #123)"
   # or
   git commit -m "Feature: Description of feature (closes #123)"
   ```

6. **Push to your fork**:
   ```bash
   git push origin your-branch-name
   ```

7. **Open a Pull Request** on GitHub:
   - Reference the issue number in your PR title: `Fix: Description (closes #123)`
   - Provide a clear description of what your PR does
   - Link to the original issue in the PR description

## Development Setup

### Prerequisites

- **Xcode** with Swift

### Setting Up the Project

1. Open `AIThing.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies
3. Build and run the project (`⌘R`)

### Project Structure

```
AIThing/
├── Managers/          # Business logic and core functionality
│   ├── Automation/    # Automation handling
│   ├── Context/       # App context and screen capture
│   ├── Firebase/      # Authentication and storage
│   ├── Intelligence/  # AI provider integrations
│   └── Tools/         # OAuth and external tool integrations
├── Views/             # SwiftUI views
│   ├── ChatView/      # Chat interface components
│   ├── IntelligenceView/  # Main intelligence interface
│   ├── NotchView/     # Notch UI and window management
│   └── SettingsView/  # Settings interface
└── Models/            # Data models
```

## Coding Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused on a single responsibility

### SwiftUI Best Practices

- Use `@State`, `@Binding`, `@ObservedObject`, and `@EnvironmentObject` appropriately
- Extract reusable components into separate views
- Use view modifiers for styling consistency

### Code Quality

- Ensure your code builds without warnings
- Test your changes thoroughly on macOS
- Verify that existing functionality still works

## Pull Request Guidelines

### What Makes a Good PR?

✅ **DO:**
- Reference the issue number in your PR title and description
- Keep changes focused on solving one issue
- Write clear commit messages
- Test your changes thoroughly
- Update documentation if needed
- Add comments for complex code

❌ **DON'T:**
- Submit PRs without an associated issue
- Mix multiple unrelated changes in one PR
- Submit incomplete or work-in-progress code
- Break existing functionality

### PR Review Process

1. A maintainer will review your PR
2. They may request changes or ask questions
3. Once approved, your PR will be merged
4. Your contribution will be included in the next release! 🎉

## Questions?

If you have any questions about contributing, feel free to:
- Open an issue with the "question" label
- Email us at **[help@aithing.dev](mailto:help@aithing.dev)**

## Code of Conduct

We are committed to providing a welcoming and inclusive experience for everyone. Please be respectful and constructive in all interactions.

---

Thank you for contributing to AI Thing! Your efforts help make this project better for everyone. 🚀
