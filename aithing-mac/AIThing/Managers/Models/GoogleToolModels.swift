//
//  GoogleToolModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

// MARK: - Google Tool Configuration

/// Static configuration for Google OAuth scopes and API capabilities.
/// Maps tools to required scopes and available API operations.
enum GoogleToolModels {
    
    // MARK: - OAuth Scopes
    
    /// Available Google OAuth scopes
    enum Scopes {
        // User info
        static let userInfoEmail = "https://www.googleapis.com/auth/userinfo.email"
        static let userInfoProfile = "https://www.googleapis.com/auth/userinfo.profile"
        static let openID = "openid"
        
        // Calendar
        static let calendar = "https://www.googleapis.com/auth/calendar"
        static let calendarReadonly = "https://www.googleapis.com/auth/calendar.readonly"
        static let calendarEvents = "https://www.googleapis.com/auth/calendar.events"
        
        // Drive
        static let drive = "https://www.googleapis.com/auth/drive"
        static let driveReadonly = "https://www.googleapis.com/auth/drive.readonly"
        static let driveFile = "https://www.googleapis.com/auth/drive.file"
        
        // Docs
        static let docsReadonly = "https://www.googleapis.com/auth/documents.readonly"
        static let docsWrite = "https://www.googleapis.com/auth/documents"
        
        // Gmail
        static let gmailReadonly = "https://www.googleapis.com/auth/gmail.readonly"
        static let gmailSend = "https://www.googleapis.com/auth/gmail.send"
        static let gmailCompose = "https://www.googleapis.com/auth/gmail.compose"
        static let gmailModify = "https://www.googleapis.com/auth/gmail.modify"
        static let gmailLabels = "https://www.googleapis.com/auth/gmail.labels"
        
        // Sheets
        static let sheetsReadonly = "https://www.googleapis.com/auth/spreadsheets.readonly"
        static let sheetsWrite = "https://www.googleapis.com/auth/spreadsheets"
        
        // Forms
        static let formsBody = "https://www.googleapis.com/auth/forms.body"
        static let formsBodyReadonly = "https://www.googleapis.com/auth/forms.body.readonly"
        static let formsResponsesReadonly = "https://www.googleapis.com/auth/forms.responses.readonly"
        
        // Slides
        static let slides = "https://www.googleapis.com/auth/presentations"
        static let slidesReadonly = "https://www.googleapis.com/auth/presentations.readonly"
        
        // Tasks
        static let tasks = "https://www.googleapis.com/auth/tasks"
        static let tasksReadonly = "https://www.googleapis.com/auth/tasks.readonly"
    }
    
    // MARK: - Scope Groups
    
    /// Grouped scopes for convenience
    enum ScopeGroups {
        static let base = [
            Scopes.userInfoEmail,
            Scopes.userInfoProfile,
            Scopes.openID
        ]
        
        static let docs = [
            Scopes.docsReadonly,
            Scopes.docsWrite
        ]
        
        static let calendar = [
            Scopes.calendar,
            Scopes.calendarReadonly,
            Scopes.calendarEvents
        ]
        
        static let drive = [
            Scopes.drive,
            Scopes.driveReadonly,
            Scopes.driveFile
        ]
        
        static let gmail = [
            Scopes.gmailReadonly,
            Scopes.gmailSend,
            Scopes.gmailCompose,
            Scopes.gmailModify,
            Scopes.gmailLabels
        ]
        
        static let sheets = [
            Scopes.sheetsReadonly,
            Scopes.sheetsWrite
        ]
        
        static let forms = [
            Scopes.formsBody,
            Scopes.formsBodyReadonly,
            Scopes.formsResponsesReadonly
        ]
        
        static let slides = [
            Scopes.slides,
            Scopes.slidesReadonly
        ]
        
        static let tasks = [
            Scopes.tasks,
            Scopes.tasksReadonly
        ]
    }
    
    // MARK: - Tool to Scope Mapping
    
    /// Maps Google tools to their required OAuth scopes
    static let toolScopesMap: [GoogleTool: [String]] = [
        .gmail: ScopeGroups.gmail,
        .drive: ScopeGroups.drive,
        .calendar: ScopeGroups.calendar,
        .docs: ScopeGroups.docs,
        .sheets: ScopeGroups.sheets,
        .forms: ScopeGroups.forms,
        .slides: ScopeGroups.slides,
        .tasks: ScopeGroups.tasks
    ]
    
    // MARK: - Tool Capabilities
    
    /// Maps Google tools to their available API operations
    static let toolCapabilities: [GoogleTool: [String]] = [
        .gmail: [
            "search_gmail_messages",
            "get_gmail_message_content",
            "get_gmail_messages_content_batch",
            "send_gmail_message",
            "get_gmail_thread_content",
            "modify_gmail_message_labels",
            "list_gmail_labels",
            "manage_gmail_label",
            "draft_gmail_message",
            "get_gmail_threads_content_batch",
            "batch_modify_gmail_message_labels"
        ],
        .drive: [
            "search_drive_files",
            "get_drive_file_content",
            "create_drive_file",
            "list_drive_items",
            "get_drive_file_permissions",
            "check_drive_file_public_access"
        ],
        .calendar: [
            "list_calendars",
            "get_events",
            "create_event",
            "modify_event",
            "delete_event"
        ],
        .docs: [
            "get_doc_content",
            "create_doc",
            "modify_doc_text",
            "export_doc_to_pdf",
            "search_docs",
            "find_and_replace_doc",
            "list_docs_in_folder",
            "insert_doc_elements",
            "insert_doc_image",
            "update_doc_headers_footers",
            "batch_update_doc",
            "inspect_doc_structure",
            "create_table_with_data",
            "debug_table_structure",
            "read_document_comments",
            "create_document_comment",
            "reply_to_document_comment",
            "resolve_document_comment"
        ],
        .sheets: [
            "create_spreadsheet",
            "read_sheet_values",
            "modify_sheet_values",
            "list_spreadsheets",
            "get_spreadsheet_info",
            "create_sheet",
            "read_spreadsheet_comments",
            "create_spreadsheet_comment",
            "reply_to_spreadsheet_comment",
            "resolve_spreadsheet_comment"
        ],
        .forms: [
            "create_form",
            "get_form",
            "list_form_responses",
            "set_publish_settings",
            "get_form_response"
        ],
        .slides: [
            "create_presentation",
            "get_presentation",
            "batch_update_presentation",
            "get_page",
            "get_page_thumbnail",
            "read_presentation_comments",
            "create_presentation_comment",
            "reply_to_presentation_comment",
            "resolve_presentation_comment"
        ],
        .tasks: [
            "get_task",
            "list_tasks",
            "create_task",
            "update_task",
            "delete_task",
            "list_task_lists",
            "get_task_list",
            "create_task_list",
            "update_task_list",
            "delete_task_list",
            "move_task",
            "clear_completed_tasks"
        ]
    ]
}

