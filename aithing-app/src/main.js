// AIThing - Complete Frontend JavaScript
// Matching the Swift/SwiftUI implementation

// =============================================================================
// TAURI API IMPORTS
// =============================================================================
const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
const { getCurrentWindow } = window.__TAURI__.window;
const { exit } = window.__TAURI__.process;

// =============================================================================
// DOM ELEMENTS
// =============================================================================
const elements = {
    // Sidebar
    sidebar: document.getElementById('sidebar'),
    sidebarToggleBtn: document.getElementById('sidebarToggleBtn'),
    newChatBtn: document.getElementById('newChatBtn'),
    chatList: document.getElementById('chatList'),
    noChats: document.getElementById('noChats'),
    settingsBtn: document.getElementById('settingsBtn'),

    // Main Views
    intelligenceView: document.getElementById('intelligenceView'),
    settingsView: document.getElementById('settingsView'),

    // Intelligence View
    closeBtn: document.getElementById('closeBtn'),
    titleInput: document.getElementById('titleInput'),
    lastUpdated: document.getElementById('lastUpdated'),
    chatArea: document.getElementById('chatArea'),
    welcomeMessage: document.getElementById('welcomeMessage'),
    greeting: document.getElementById('greeting'),
    subheading: document.getElementById('subheading'),
    messages: document.getElementById('messages'),
    loadingIndicator: document.getElementById('loadingIndicator'),
    toolCall: document.getElementById('toolCall'),
    inputContainer: document.getElementById('inputContainer'),
    messageInput: document.getElementById('messageInput'),
    animatedBorder: document.getElementById('animatedBorder'),
    contextBar: document.getElementById('contextBar'),
    contextItems: document.getElementById('contextItems'),
    textSelectionBtn: document.getElementById('textSelectionBtn'),
    viewToolsBtn: document.getElementById('viewToolsBtn'),

    // Settings View
    settingsCloseBtn: document.getElementById('settingsCloseBtn'),
    checkUpdatesBtn: document.getElementById('checkUpdatesBtn'),
    settingsTabs: document.getElementById('settingsTabs'),
    accountPanel: document.getElementById('accountPanel'),
    modelsPanel: document.getElementById('modelsPanel'),
    agentsPanel: document.getElementById('agentsPanel'),
    preferencesPanel: document.getElementById('preferencesPanel'),
    signInBtn: document.getElementById('signInBtn'),
    anthropicApiKey: document.getElementById('anthropicApiKey'),
    openaiApiKey: document.getElementById('openaiApiKey'),
    googleApiKey: document.getElementById('googleApiKey'),
    anthropicModels: document.getElementById('anthropicModels'),
    openaiModels: document.getElementById('openaiModels'),
    googleModels: document.getElementById('googleModels'),
    agentsList: document.getElementById('agentsList'),
    addAgentBtn: document.getElementById('addAgentBtn'),
    showInScreenshot: document.getElementById('showInScreenshot'),
    useCapturedScreenshots: document.getElementById('useCapturedScreenshots'),
    openAtLogin: document.getElementById('openAtLogin'),
    shortcutsEnabled: document.getElementById('shortcutsEnabled'),
    quitBtn: document.getElementById('quitBtn'),

    // Logo
    logoContainer: document.getElementById('logoContainer'),
    notificationDot: document.getElementById('notificationDot'),
};

// =============================================================================
// STATE
// =============================================================================
const state = {
    // Sidebar state
    sidebarExpanded: true,

    // Chat state
    currentTabId: generateUUID(),
    chatHistory: [],
    histories: [],
    isThinking: false,
    modelOutput: '',

    // Context state
    modelContext: [],
    selectionEnabled: false,

    // Settings state
    showSettings: false,
    selectedTab: 'account',
    selectedModel: 'claude-sonnet-4-20250514',
    apiKeys: {
        anthropic: '',
        openai: '',
        google: ''
    },
    agents: [],
    preferences: {
        showInScreenshot: false,
        useCapturedScreenshots: false,
        openAtLogin: false,
        shortcutsEnabled: true
    }
};

// Available models (matching Swift ModelInfo)
const availableModels = [
    { id: 'claude-sonnet-4-20250514', name: 'Claude Sonnet 4', provider: 'anthropic' },
    { id: 'claude-opus-4-20250514', name: 'Claude Opus 4', provider: 'anthropic' },
    { id: 'claude-3-5-sonnet-20241022', name: 'Claude 3.5 Sonnet', provider: 'anthropic' },
    { id: 'gpt-4o', name: 'GPT-4o', provider: 'openai' },
    { id: 'gpt-4o-mini', name: 'GPT-4o Mini', provider: 'openai' },
    { id: 'o1', name: 'O1', provider: 'openai' },
    { id: 'gemini-2.0-flash', name: 'Gemini 2.0 Flash', provider: 'google' },
    { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', provider: 'google' },
];

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

function timeBasedGreeting() {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Hello';
}

function timeBasedSubheading() {
    const hour = new Date().getHours();

    const morning = [
        "What big thing can I take off your plate this morning?",
        "What can I kickstart for you today?",
        "What challenge can I tackle to power up your day?",
    ];

    const afternoon = [
        "What can I take over so your afternoon runs smoother?",
        "What challenge can I eliminate for you today?",
        "What can I automate, solve, or build right now?",
    ];

    const evening = [
        "What big thing can I take off your plate tonight?",
        "What can I wrap up so your evening stays peaceful?",
        "What challenge can I tackle before the day ends?",
    ];

    const night = [
        "What can I handle while you wind down for the night?",
        "What final task can I take off your plate before you rest?",
        "What can I automate to make tomorrow easier?",
    ];

    let options;
    if (hour >= 5 && hour < 12) options = morning;
    else if (hour >= 12 && hour < 17) options = afternoon;
    else if (hour >= 17 && hour < 22) options = evening;
    else options = night;

    return options[Math.floor(Math.random() * options.length)];
}

function formatDate(timestamp) {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Simple markdown parser
function parseMarkdown(text) {
    if (!text) return '';

    // Escape HTML first
    let html = escapeHtml(text);

    // Code blocks (must be before inline code)
    html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre><code class="language-$1">$2</code></pre>');

    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>');

    // Headers
    html = html.replace(/^### (.*$)/gm, '<h3>$1</h3>');
    html = html.replace(/^## (.*$)/gm, '<h2>$1</h2>');
    html = html.replace(/^# (.*$)/gm, '<h1>$1</h1>');

    // Bold
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');

    // Italic
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');

    // Links
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');

    // Line breaks
    html = html.replace(/\n/g, '<br>');

    return html;
}

// =============================================================================
// UI UPDATE FUNCTIONS
// =============================================================================

function updateGreeting() {
    elements.greeting.innerHTML = `# ${timeBasedGreeting()}, Human!`;
    elements.subheading.textContent = timeBasedSubheading();
}

function toggleSidebar() {
    state.sidebarExpanded = !state.sidebarExpanded;
    elements.sidebar.classList.toggle('collapsed', !state.sidebarExpanded);
}

function showIntelligenceView() {
    state.showSettings = false;
    elements.intelligenceView.classList.remove('hidden');
    elements.settingsView.classList.add('hidden');
}

function showSettingsView() {
    state.showSettings = true;
    elements.intelligenceView.classList.add('hidden');
    elements.settingsView.classList.remove('hidden');
}

function updateChatList() {
    elements.chatList.innerHTML = '';

    if (state.histories.length === 0) {
        elements.noChats.classList.remove('hidden');
        return;
    }

    elements.noChats.classList.add('hidden');

    state.histories.forEach((history, index) => {
        const item = document.createElement('div');
        item.className = `chat-item${history.id === state.currentTabId ? ' active' : ''}`;
        item.innerHTML = `
            <span class="chat-item-title">${escapeHtml(history.title || `Session #${index + 1}`)}</span>
            ${history.unseen ? '<span class="chat-item-notification"></span>' : ''}
            <button class="chat-item-delete" title="Delete">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="3 6 5 6 21 6"/>
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                </svg>
            </button>
        `;

        item.addEventListener('click', (e) => {
            if (!e.target.closest('.chat-item-delete')) {
                switchToChat(history.id);
            }
        });

        item.querySelector('.chat-item-delete').addEventListener('click', (e) => {
            e.stopPropagation();
            deleteChat(history.id);
        });

        elements.chatList.appendChild(item);
    });
}

function updateMessages() {
    elements.messages.innerHTML = '';

    if (state.chatHistory.length === 0) {
        elements.welcomeMessage.classList.remove('hidden');
        return;
    }

    elements.welcomeMessage.classList.add('hidden');

    state.chatHistory.forEach(item => {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${item.role}`;

        if (item.payloads && item.payloads.length > 0) {
            item.payloads.forEach(payload => {
                if (payload.type === 'text') {
                    const contentDiv = document.createElement('div');
                    contentDiv.className = 'message-content';
                    contentDiv.innerHTML = parseMarkdown(payload.text);
                    messageDiv.appendChild(contentDiv);
                } else if (payload.type === 'imageBase64') {
                    const imgDiv = document.createElement('div');
                    imgDiv.className = 'image-bubble';
                    imgDiv.innerHTML = `<img src="data:${payload.media};base64,${payload.image}" alt="${payload.name}">`;
                    messageDiv.appendChild(imgDiv);
                } else if (payload.type === 'toolUse') {
                    const toolDiv = document.createElement('div');
                    toolDiv.className = 'tool-bubble';
                    toolDiv.textContent = `Called tool: ${payload.name}`;
                    messageDiv.appendChild(toolDiv);
                }
            });
        }

        elements.messages.appendChild(messageDiv);
    });

    // Scroll to bottom
    elements.chatArea.scrollTop = elements.chatArea.scrollHeight;
}

function setThinking(thinking, text = 'Responding...') {
    state.isThinking = thinking;

    if (thinking) {
        elements.loadingIndicator.classList.remove('hidden');
        elements.loadingIndicator.innerHTML = `
            <div class="loading-dots">
                <span></span>
                <span></span>
                <span></span>
            </div>
            <span>${text}</span>
        `;
        elements.animatedBorder.classList.add('active');
        elements.animatedBorder.classList.remove('hidden');
        elements.messageInput.placeholder = text;
    } else {
        elements.loadingIndicator.classList.add('hidden');
        elements.animatedBorder.classList.remove('active');
        elements.animatedBorder.classList.add('hidden');
        elements.messageInput.placeholder = 'Ask anything on AI Thing...';
    }
}

function updateModelsList() {
    const providers = {
        anthropic: elements.anthropicModels,
        openai: elements.openaiModels,
        google: elements.googleModels
    };

    Object.keys(providers).forEach(provider => {
        const container = providers[provider];
        container.innerHTML = '';

        availableModels
            .filter(model => model.provider === provider)
            .forEach(model => {
                const item = document.createElement('div');
                item.className = 'model-item';
                item.innerHTML = `
                    <div class="model-info">
                        <span class="model-name">${model.name}</span>
                        <span class="model-id">${model.id}</span>
                    </div>
                    <label class="toggle-switch">
                        <input type="checkbox" ${state.selectedModel === model.id ? 'checked' : ''}>
                        <span class="toggle-slider"></span>
                    </label>
                `;

                item.addEventListener('click', () => {
                    state.selectedModel = model.id;
                    saveSettings();
                    updateModelsList();
                });

                container.appendChild(item);
            });
    });
}

function updatePreferences() {
    elements.showInScreenshot.checked = state.preferences.showInScreenshot;
    elements.useCapturedScreenshots.checked = state.preferences.useCapturedScreenshots;
    elements.openAtLogin.checked = state.preferences.openAtLogin;
    elements.shortcutsEnabled.checked = state.preferences.shortcutsEnabled;
}

function switchSettingsTab(tabName) {
    state.selectedTab = tabName;

    // Update tab buttons
    document.querySelectorAll('.settings-tab').forEach(tab => {
        tab.classList.toggle('active', tab.dataset.tab === tabName);
    });

    // Update panels
    elements.accountPanel.classList.toggle('hidden', tabName !== 'account');
    elements.modelsPanel.classList.toggle('hidden', tabName !== 'models');
    elements.agentsPanel.classList.toggle('hidden', tabName !== 'agents');
    elements.preferencesPanel.classList.toggle('hidden', tabName !== 'preferences');
}

// =============================================================================
// CHAT FUNCTIONS
// =============================================================================

function newChat() {
    state.currentTabId = generateUUID();
    state.chatHistory = [];
    state.modelOutput = '';
    elements.titleInput.value = 'New Chat';
    updateMessages();
    updateChatList();
    showIntelligenceView();
}

function switchToChat(chatId) {
    state.currentTabId = chatId;
    loadChatHistory(chatId);
    showIntelligenceView();
    updateChatList();
}

function deleteChat(chatId) {
    state.histories = state.histories.filter(h => h.id !== chatId);

    if (state.currentTabId === chatId) {
        if (state.histories.length > 0) {
            switchToChat(state.histories[0].id);
        } else {
            newChat();
        }
    }

    updateChatList();
    saveHistories();
}

async function sendMessage() {
    const query = elements.messageInput.value.trim();
    if (!query || state.isThinking) return;

    // Add user message
    state.chatHistory.push({
        id: generateUUID(),
        role: 'user',
        payloads: [{ type: 'text', text: query }]
    });

    elements.messageInput.value = '';
    updateMessages();

    // Show thinking state
    setThinking(true);

    try {
        // Call AI provider (placeholder - implement actual API calls)
        const response = await callAIProvider(query);

        // Add assistant message
        state.chatHistory.push({
            id: generateUUID(),
            role: 'assistant',
            payloads: [{ type: 'text', text: response }]
        });

        // Save history
        await saveCurrentHistory();

    } catch (error) {
        console.error('Error calling AI:', error);
        state.chatHistory.push({
            id: generateUUID(),
            role: 'assistant',
            payloads: [{ type: 'text', text: `Error: ${error.message}` }]
        });
    } finally {
        setThinking(false);
        updateMessages();
    }
}

async function callAIProvider(query) {
    // This is a placeholder - in the real implementation, you would:
    // 1. Get the selected model and API key
    // 2. Make the API call to the appropriate provider
    // 3. Stream the response

    const apiKey = state.apiKeys[getProviderForModel(state.selectedModel)];

    if (!apiKey) {
        return "Please add an API key in Settings > Models to use this feature.";
    }

    // Placeholder response
    return `I received your message: "${query}"\n\nThis is a placeholder response. Connect me to your preferred AI provider (Anthropic, OpenAI, or Google) through the API key settings to get real responses.`;
}

function getProviderForModel(modelId) {
    const model = availableModels.find(m => m.id === modelId);
    return model ? model.provider : 'anthropic';
}

// =============================================================================
// STORAGE FUNCTIONS
// =============================================================================

async function loadSettings() {
    try {
        const settings = await invoke('get_settings');
        if (settings) {
            state.preferences.showInScreenshot = settings.show_in_screenshot;
            state.preferences.openAtLogin = settings.open_at_login;
            state.preferences.shortcutsEnabled = settings.shortcuts_enabled;
        }
    } catch (error) {
        console.error('Failed to load settings:', error);
    }

    // Load from localStorage as fallback
    const saved = localStorage.getItem('aithing_state');
    if (saved) {
        try {
            const parsed = JSON.parse(saved);
            state.selectedModel = parsed.selectedModel || state.selectedModel;
            state.apiKeys = parsed.apiKeys || state.apiKeys;
            state.histories = parsed.histories || [];
        } catch (e) {
            console.error('Failed to parse saved state:', e);
        }
    }

    updatePreferences();
    updateModelsList();
    updateChatList();
}

async function saveSettings() {
    try {
        await invoke('set_settings', {
            settings: {
                show_in_screenshot: state.preferences.showInScreenshot,
                open_at_login: state.preferences.openAtLogin,
                shortcuts_enabled: state.preferences.shortcutsEnabled
            }
        });
    } catch (error) {
        console.error('Failed to save settings:', error);
    }

    // Also save to localStorage
    localStorage.setItem('aithing_state', JSON.stringify({
        selectedModel: state.selectedModel,
        apiKeys: state.apiKeys,
        histories: state.histories
    }));
}

function loadChatHistory(chatId) {
    const history = state.histories.find(h => h.id === chatId);
    if (history) {
        state.chatHistory = history.history || [];
        elements.titleInput.value = history.title || 'New Chat';
        elements.lastUpdated.textContent = formatDate(history.lastUpdated);
    } else {
        state.chatHistory = [];
        elements.titleInput.value = 'New Chat';
        elements.lastUpdated.textContent = '';
    }
    updateMessages();
}

async function saveCurrentHistory() {
    const existingIndex = state.histories.findIndex(h => h.id === state.currentTabId);

    const historyEntry = {
        id: state.currentTabId,
        title: elements.titleInput.value || 'New Chat',
        history: state.chatHistory,
        lastUpdated: Date.now(),
        unseen: false
    };

    if (existingIndex >= 0) {
        state.histories[existingIndex] = historyEntry;
    } else {
        state.histories.unshift(historyEntry);
    }

    await saveHistories();
    updateChatList();
}

async function saveHistories() {
    localStorage.setItem('aithing_histories', JSON.stringify(state.histories));
}

function loadHistories() {
    const saved = localStorage.getItem('aithing_histories');
    if (saved) {
        try {
            state.histories = JSON.parse(saved);
        } catch (e) {
            console.error('Failed to parse histories:', e);
            state.histories = [];
        }
    }
}

// =============================================================================
// WINDOW CONTROL FUNCTIONS
// =============================================================================

async function closeWindow() {
    const window = getCurrentWindow();
    await window.hide();
}

async function toggleVisibility() {
    try {
        await invoke('toggle_visibility');
    } catch (error) {
        console.error('Failed to toggle visibility:', error);
    }
}

async function quitApp() {
    try {
        await exit(0);
    } catch (error) {
        console.error('Failed to quit app:', error);
    }
}

// =============================================================================
// EVENT LISTENERS
// =============================================================================

function setupEventListeners() {
    // Sidebar
    elements.sidebarToggleBtn.addEventListener('click', toggleSidebar);
    elements.newChatBtn.addEventListener('click', newChat);
    elements.settingsBtn.addEventListener('click', showSettingsView);

    // Intelligence View
    elements.closeBtn.addEventListener('click', closeWindow);
    elements.messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    // Auto-resize textarea
    elements.messageInput.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.min(this.scrollHeight, 120) + 'px';
    });

    // Title input
    elements.titleInput.addEventListener('blur', () => {
        saveCurrentHistory();
    });

    elements.titleInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            elements.titleInput.blur();
        }
    });

    // Context buttons
    elements.textSelectionBtn.addEventListener('click', () => {
        state.selectionEnabled = !state.selectionEnabled;
        elements.textSelectionBtn.classList.toggle('active', state.selectionEnabled);
    });

    // Settings View
    elements.settingsCloseBtn.addEventListener('click', showIntelligenceView);

    // Settings tabs
    document.querySelectorAll('.settings-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            switchSettingsTab(tab.dataset.tab);
        });
    });

    // API Keys
    elements.anthropicApiKey.addEventListener('change', () => {
        state.apiKeys.anthropic = elements.anthropicApiKey.value;
        saveSettings();
    });

    elements.openaiApiKey.addEventListener('change', () => {
        state.apiKeys.openai = elements.openaiApiKey.value;
        saveSettings();
    });

    elements.googleApiKey.addEventListener('change', () => {
        state.apiKeys.google = elements.googleApiKey.value;
        saveSettings();
    });

    // Preferences
    elements.showInScreenshot.addEventListener('change', async () => {
        state.preferences.showInScreenshot = elements.showInScreenshot.checked;
        await saveSettings();
        try {
            await invoke('set_screenshot_protection', {
                enabled: !state.preferences.showInScreenshot
            });
        } catch (e) {
            console.error('Failed to update screenshot protection:', e);
        }
    });

    elements.useCapturedScreenshots.addEventListener('change', () => {
        state.preferences.useCapturedScreenshots = elements.useCapturedScreenshots.checked;
        saveSettings();
    });

    elements.openAtLogin.addEventListener('change', () => {
        state.preferences.openAtLogin = elements.openAtLogin.checked;
        saveSettings();
    });

    elements.shortcutsEnabled.addEventListener('change', async () => {
        state.preferences.shortcutsEnabled = elements.shortcutsEnabled.checked;
        await saveSettings();
        try {
            await invoke('set_shortcuts_enabled', {
                enabled: state.preferences.shortcutsEnabled
            });
        } catch (e) {
            console.error('Failed to update shortcuts:', e);
        }
    });

    elements.quitBtn.addEventListener('click', quitApp);

    // Drag and drop
    setupDragAndDrop();
}

function setupDragAndDrop() {
    const dropZone = elements.inputContainer;

    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('dropping');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('dropping');
    });

    dropZone.addEventListener('drop', async (e) => {
        e.preventDefault();
        dropZone.classList.remove('dropping');

        const files = Array.from(e.dataTransfer.files);

        for (const file of files) {
            if (file.type.startsWith('image/')) {
                const reader = new FileReader();
                reader.onload = (event) => {
                    const base64 = event.target.result.split(',')[1];
                    state.modelContext.push({
                        type: 'image',
                        name: file.name,
                        media: file.type,
                        image: base64
                    });
                    updateContextItems();
                };
                reader.readAsDataURL(file);
            } else if (file.type === 'application/pdf' || file.type.startsWith('text/')) {
                const reader = new FileReader();
                reader.onload = (event) => {
                    state.modelContext.push({
                        type: 'text',
                        name: file.name,
                        content: event.target.result
                    });
                    updateContextItems();
                };
                reader.readAsText(file);
            }
        }
    });
}

function updateContextItems() {
    elements.contextItems.innerHTML = '';

    state.modelContext.forEach((item, index) => {
        const contextItem = document.createElement('div');
        contextItem.className = 'context-item';

        if (item.type === 'image') {
            contextItem.innerHTML = `
                <img class="context-item-preview" src="data:${item.media};base64,${item.image}" alt="${item.name}">
                <span class="context-item-name">${item.name}</span>
                <button class="context-item-remove" title="Remove">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            `;
        } else {
            contextItem.innerHTML = `
                <svg class="context-item-preview" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                    <polyline points="14 2 14 8 20 8"/>
                    <line x1="16" y1="13" x2="8" y2="13"/>
                    <line x1="16" y1="17" x2="8" y2="17"/>
                    <polyline points="10 9 9 9 8 9"/>
                </svg>
                <span class="context-item-name">${item.name}</span>
                <button class="context-item-remove" title="Remove">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            `;
        }

        contextItem.querySelector('.context-item-remove').addEventListener('click', () => {
            state.modelContext.splice(index, 1);
            updateContextItems();
        });

        elements.contextItems.appendChild(contextItem);
    });
}

async function setupTauriListeners() {
    // Listen for shortcut triggers
    await listen('shortcut-triggered', (event) => {
        const action = event.payload;
        if (action === 'toggle-visibility') {
            toggleVisibility();
        }
    });
}

// =============================================================================
// INITIALIZATION
// =============================================================================

async function init() {
    // Load saved data
    loadHistories();
    await loadSettings();

    // Update UI
    updateGreeting();
    updateModelsList();
    updateChatList();

    // Set up event listeners
    setupEventListeners();
    await setupTauriListeners();

    // Load API keys into inputs
    elements.anthropicApiKey.value = state.apiKeys.anthropic;
    elements.openaiApiKey.value = state.apiKeys.openai;
    elements.googleApiKey.value = state.apiKeys.google;

    console.log('AIThing initialized successfully');
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', init);
