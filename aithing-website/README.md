# AI Thing Website

Welcome to the website repository for [AI Thing](https://aithing.dev).

[AI Thing](https://github.com/aithing-lab/aithing-mac) is a privacy-first AI automation tool that lets AI agents handle complex and repetitive tasks in parallel and in the background, so you can focus on what truly matters.

- **Privacy First**: Everything stays local — your conversations, files, and API keys
- **BYOK Models**: Use your API keys for frontier Anthropic, OpenAI and Gemini models
- **Model Switching**: Switch between multiple models in a single conversation
- **Multiple Agents**: Connect powerful agents like Google Workspace, GitHub, Notion, Asana, and more
- **Background Automations**: Set up recurring or one-off automations that run on your schedule
- **Complex Tasks**: Run complex tasks that span multiple apps and tools

AI Thing is now fully [open source](https://github.com/aithing-lab/aithing-mac) — give it a star!

![demo](https://download.aithing.dev/demo.png)

### Local Development

This website is built with [Mintlify](https://mintlify.com), accessible at [https://aithing.dev](https://aithing.dev).

#### Setup

1. Install [Mintlify CLI](https://www.mintlify.com/docs/installation)

2. Start the development server:

```bash
mint dev
```

The documentation site will be available at `http://localhost:3000`.

#### Making Changes

1. Edit any `.mdx` file to update content
2. Modify `docs.json` to change navigation, colors, or site settings
3. Add images to the `images/` directory
4. Preview changes in real-time on localhost

### Documentation Guidelines

#### Adding New Pages

1. Create a new `.mdx` file in the appropriate directory
2. Add front matter with `title`, `description`, and `icon`
3. Update `docs.json` navigation to include the new page

Example:

```mdx
---
title: "Feature Name"
description: "Brief description of the feature"
icon: "icon-name"
---

Your content here...
```

#### Using Components

Mintlify provides several built-in components:

- `<Card>` - Feature cards with links
- `<Tip>` - Helpful tips and notes
- `<Warning>` - Important warnings
- `<Frame>` - Image containers
- `<Columns>` - Multi-column layouts

### Contributing

To contribute to the documentation:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

Please ensure:
- All links work correctly
- Images are optimized and properly referenced
- Content follows the existing style and tone
- Navigation structure in `docs.json` is updated if needed

### Support

For questions or issues:
- **Email**: help@aithing.dev
- **Documentation Issues**: Open an issue in this repository
- **App Issues**: Report on the [main AI Thing repository](https://github.com/aithing-lab/aithing-mac)
