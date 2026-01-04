//! AIThing - AI-powered assistant visible on top of all apps
//!
//! This module contains the main backend logic for the AIThing application:
//! - macOS window management with NSPanel for fullscreen overlay
//! - Global keyboard shortcuts
//! - Tauri commands for frontend interaction

use once_cell::sync::Lazy;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
#[cfg(target_os = "macos")]
use tauri::WebviewWindow;
use tauri::{AppHandle, Emitter, Manager};
#[cfg(target_os = "macos")]
use tauri_nspanel::{tauri_panel, CollectionBehavior, PanelLevel, StyleMask, WebviewWindowExt};
use tauri_plugin_global_shortcut::{Code, GlobalShortcutExt, Modifiers, Shortcut};
use tauri_plugin_store::StoreExt;

// =============================================================================
// DATA TYPES
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowState {
    pub is_visible: bool,
    pub is_expanded: bool,
    pub width: f64,
    pub height: f64,
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub show_in_screenshot: bool,
    pub open_at_login: bool,
    pub shortcuts_enabled: bool,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            show_in_screenshot: false,
            open_at_login: false,
            shortcuts_enabled: true,
        }
    }
}

// =============================================================================
// GLOBAL STATE
// =============================================================================

static APP_HANDLE: Lazy<Arc<RwLock<Option<AppHandle>>>> = Lazy::new(|| Arc::new(RwLock::new(None)));
static WINDOW_STATE: Lazy<Arc<RwLock<WindowState>>> = Lazy::new(|| {
    Arc::new(RwLock::new(WindowState {
        is_visible: true,
        is_expanded: false,
        width: 660.0,
        height: 600.0,
        x: 0.0,
        y: 0.0,
    }))
});
static APP_SETTINGS: Lazy<Arc<RwLock<AppSettings>>> =
    Lazy::new(|| Arc::new(RwLock::new(AppSettings::default())));

// =============================================================================
// SETTINGS STORAGE
// =============================================================================

fn save_settings_to_store(app: &AppHandle) {
    if let Ok(store) = app.store("aithing-store.json") {
        let settings = APP_SETTINGS.read();
        if let Ok(json) = serde_json::to_value(&*settings) {
            store.set("settings", json);
            let _ = store.save();
        }
    }
}

fn load_settings_from_store(app: &AppHandle) {
    if let Ok(store) = app.store("aithing-store.json") {
        if let Some(settings_json) = store.get("settings") {
            if let Ok(settings) = serde_json::from_value::<AppSettings>(settings_json.clone()) {
                let mut app_settings = APP_SETTINGS.write();
                *app_settings = settings;
            }
        }
    }
}

// =============================================================================
// TAURI COMMANDS
// =============================================================================

#[tauri::command]
fn get_window_state() -> WindowState {
    WINDOW_STATE.read().clone()
}

#[tauri::command]
fn set_window_state(state: WindowState) {
    let mut window_state = WINDOW_STATE.write();
    *window_state = state;
}

#[tauri::command]
fn get_settings() -> AppSettings {
    APP_SETTINGS.read().clone()
}

#[tauri::command]
fn set_settings(app: AppHandle, settings: AppSettings) {
    {
        let mut app_settings = APP_SETTINGS.write();
        *app_settings = settings;
    }
    save_settings_to_store(&app);
}

#[tauri::command]
fn set_screenshot_protection(app: AppHandle, enabled: bool) -> Result<(), String> {
    let window = app
        .get_webview_window("main")
        .ok_or("Failed to get main window")?;
    window
        .set_content_protected(enabled)
        .map_err(|e| format!("Failed to update content protection: {}", e))?;
    Ok(())
}

#[tauri::command]
fn toggle_visibility(app: AppHandle) -> Result<bool, String> {
    let window = app
        .get_webview_window("main")
        .ok_or("Failed to get main window")?;

    let is_visible = window
        .is_visible()
        .map_err(|e| format!("Failed to check visibility: {}", e))?;

    if is_visible {
        window
            .hide()
            .map_err(|e| format!("Failed to hide window: {}", e))?;
    } else {
        window
            .show()
            .map_err(|e| format!("Failed to show window: {}", e))?;
    }

    Ok(!is_visible)
}

#[tauri::command]
fn set_shortcuts_enabled(app: AppHandle, enabled: bool) -> Result<(), String> {
    let shortcuts = [
        // Toggle visibility: Control+Option+Space (Mac) / Control+Alt+Space (Windows)
        Shortcut::new(Some(Modifiers::ALT | Modifiers::CONTROL), Code::Space),
        // Alternative: Control+Space
        Shortcut::new(Some(Modifiers::CONTROL), Code::Space),
    ];

    if enabled {
        app.global_shortcut()
            .register_multiple(shortcuts)
            .map_err(|e| format!("Failed to register shortcuts: {}", e))?;
    } else {
        for shortcut in shortcuts {
            let _ = app.global_shortcut().unregister(shortcut);
        }
    }
    Ok(())
}

// =============================================================================
// MACOS NSPANEL INITIALIZATION
// =============================================================================

#[cfg(target_os = "macos")]
#[allow(deprecated, unexpected_cfgs)]
fn init_nspanel(app_handle: &AppHandle) {
    tauri_panel! {
        panel!(AIThingPanel {
            config: {
                can_become_key_window: true,
                is_floating_panel: true
            }
        })
    }

    let window: WebviewWindow = app_handle.get_webview_window("main").unwrap();

    let panel = window.to_panel::<AIThingPanel>().unwrap();

    // Set floating window level
    panel.set_level(PanelLevel::Floating.value());

    // Prevent panel from activating the app (required for fullscreen display)
    panel.set_style_mask(StyleMask::empty().nonactivating_panel().resizable().into());

    // Allow panel to display over fullscreen windows and join all spaces
    panel.set_collection_behavior(
        CollectionBehavior::new()
            .full_screen_auxiliary()
            .can_join_all_spaces()
            .into(),
    );

    // Prevent panel from hiding when app deactivates
    panel.set_hides_on_deactivate(false);
}

// =============================================================================
// APPLICATION ENTRY POINT
// =============================================================================

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    #[cfg_attr(not(target_os = "macos"), allow(unused_mut))]
    let mut builder = tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_process::init())
        .plugin(
            tauri_plugin_global_shortcut::Builder::new()
                .with_handler(|app, shortcut, event| {
                    if event.state() == tauri_plugin_global_shortcut::ShortcutState::Pressed {
                        let action = match shortcut.id() {
                            // Toggle visibility: Control+Option+Space or Control+Space
                            id if id
                                == Shortcut::new(
                                    Some(Modifiers::ALT | Modifiers::CONTROL),
                                    Code::Space,
                                )
                                .id() =>
                            {
                                "toggle-visibility"
                            }
                            id if id
                                == Shortcut::new(Some(Modifiers::CONTROL), Code::Space).id() =>
                            {
                                "toggle-visibility"
                            }
                            _ => return,
                        };
                        let _ = app.emit("shortcut-triggered", action);
                    }
                })
                .build(),
        );

    #[cfg(target_os = "macos")]
    {
        builder = builder.plugin(tauri_nspanel::init());
    }

    builder
        .setup(|app| {
            // Set activation policy to Accessory to prevent the app icon from showing on the dock (macOS only)
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Store app handle for emitting events
            {
                let mut handle = APP_HANDLE.write();
                *handle = Some(app.handle().clone());
            }

            // Load stored settings from persistent storage
            load_settings_from_store(app.handle());

            // Platform-specific window initialization
            #[cfg(target_os = "macos")]
            init_nspanel(app.app_handle());

            // Register global shortcuts
            let shortcuts = [
                // Toggle visibility: Control+Option+Space (Mac) / Control+Alt+Space (Windows)
                Shortcut::new(Some(Modifiers::ALT | Modifiers::CONTROL), Code::Space),
                // Alternative: Control+Space
                Shortcut::new(Some(Modifiers::CONTROL), Code::Space),
            ];

            if let Err(e) = app.global_shortcut().register_multiple(shortcuts) {
                eprintln!("Failed to register global shortcuts: {}", e);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_window_state,
            set_window_state,
            get_settings,
            set_settings,
            set_screenshot_protection,
            toggle_visibility,
            set_shortcuts_enabled
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
