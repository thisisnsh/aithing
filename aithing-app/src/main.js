// AIThing Frontend JavaScript

// Tauri API imports
const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
const { getCurrentWindow } = window.__TAURI__.window;

// DOM Elements
const chatArea = document.getElementById('chatArea');
const messageInput = document.getElementById('messageInput');
const sendBtn = document.getElementById('sendBtn');
const minimizeBtn = document.getElementById('minimizeBtn');
const closeBtn = document.getElementById('closeBtn');
const settingsToggle = document.getElementById('settingsToggle');
const settingsPanel = document.getElementById('settingsPanel');
const closeSettings = document.getElementById('closeSettings');
const showInScreenshot = document.getElementById('showInScreenshot');
const shortcutsEnabled = document.getElementById('shortcutsEnabled');

// State
let settings = {
    show_in_screenshot: false,
    open_at_login: false,
    shortcuts_enabled: true
};

// Initialize the application
async function init() {
    // Load settings
    await loadSettings();

    // Set up event listeners
    setupEventListeners();

    // Listen for Tauri events
    await setupTauriListeners();

    // Auto-resize textarea
    setupTextareaAutoResize();
}

// Load settings from backend
async function loadSettings() {
    try {
        settings = await invoke('get_settings');
        updateSettingsUI();
    } catch (error) {
        console.error('Failed to load settings:', error);
    }
}

// Update settings UI to match state
function updateSettingsUI() {
    showInScreenshot.checked = settings.show_in_screenshot;
    shortcutsEnabled.checked = settings.shortcuts_enabled;
}

// Save settings to backend
async function saveSettings() {
    try {
        await invoke('set_settings', { settings });

        // Apply screenshot protection
        await invoke('set_screenshot_protection', { enabled: !settings.show_in_screenshot });

        // Apply shortcuts setting
        await invoke('set_shortcuts_enabled', { enabled: settings.shortcuts_enabled });
    } catch (error) {
        console.error('Failed to save settings:', error);
    }
}

// Set up DOM event listeners
function setupEventListeners() {
    // Send message
    sendBtn.addEventListener('click', sendMessage);
    messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    // Window controls
    minimizeBtn.addEventListener('click', async () => {
        try {
            await invoke('toggle_visibility');
        } catch (error) {
            console.error('Failed to toggle visibility:', error);
        }
    });

    closeBtn.addEventListener('click', async () => {
        const window = getCurrentWindow();
        await window.hide();
    });

    // Settings panel
    settingsToggle.addEventListener('click', () => {
        settingsPanel.classList.toggle('visible');
    });

    closeSettings.addEventListener('click', () => {
        settingsPanel.classList.remove('visible');
    });

    // Close settings when clicking outside
    document.addEventListener('click', (e) => {
        if (!settingsPanel.contains(e.target) && !settingsToggle.contains(e.target)) {
            settingsPanel.classList.remove('visible');
        }
    });

    // Settings toggles
    showInScreenshot.addEventListener('change', async () => {
        settings.show_in_screenshot = showInScreenshot.checked;
        await saveSettings();
    });

    shortcutsEnabled.addEventListener('change', async () => {
        settings.shortcuts_enabled = shortcutsEnabled.checked;
        await saveSettings();
    });
}

// Set up Tauri event listeners
async function setupTauriListeners() {
    // Listen for shortcut triggers
    await listen('shortcut-triggered', (event) => {
        const action = event.payload;
        handleShortcut(action);
    });
}

// Handle keyboard shortcuts
async function handleShortcut(action) {
    switch (action) {
        case 'toggle-visibility':
            try {
                await invoke('toggle_visibility');
            } catch (error) {
                console.error('Failed to toggle visibility:', error);
            }
            break;
    }
}

// Send message function
function sendMessage() {
    const text = messageInput.value.trim();
    if (!text) return;

    // Add user message to chat
    addMessage(text, 'user');

    // Clear input
    messageInput.value = '';
    messageInput.style.height = 'auto';

    // Hide welcome message if visible
    const welcomeMessage = document.querySelector('.welcome-message');
    if (welcomeMessage) {
        welcomeMessage.style.display = 'none';
    }

    // Show loading indicator
    showLoading();

    // Simulate AI response (replace with actual AI integration)
    setTimeout(() => {
        hideLoading();
        addMessage("I'm a placeholder response. Connect me to your AI backend to get real responses!", 'assistant');
    }, 1000);
}

// Add message to chat area
function addMessage(text, type) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${type}`;
    messageDiv.textContent = text;

    // Remove welcome message if it exists and this is the first message
    const welcomeMessage = chatArea.querySelector('.welcome-message');
    if (welcomeMessage) {
        welcomeMessage.remove();
    }

    chatArea.appendChild(messageDiv);
    chatArea.scrollTop = chatArea.scrollHeight;
}

// Show loading indicator
function showLoading() {
    const loadingDiv = document.createElement('div');
    loadingDiv.className = 'loading-indicator';
    loadingDiv.id = 'loadingIndicator';
    loadingDiv.innerHTML = `
        <div class="loading-dots">
            <span></span>
            <span></span>
            <span></span>
        </div>
        <span>Thinking...</span>
    `;
    chatArea.appendChild(loadingDiv);
    chatArea.scrollTop = chatArea.scrollHeight;
}

// Hide loading indicator
function hideLoading() {
    const loadingDiv = document.getElementById('loadingIndicator');
    if (loadingDiv) {
        loadingDiv.remove();
    }
}

// Auto-resize textarea
function setupTextareaAutoResize() {
    messageInput.addEventListener('input', function() {
        this.style.height = 'auto';
        this.style.height = Math.min(this.scrollHeight, 120) + 'px';
    });
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', init);
