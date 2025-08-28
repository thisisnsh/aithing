//
//  GoogleOAuthManager.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 8/25/25.
//

import Firebase
import Foundation
import GoogleSignIn
import SwiftUI

@MainActor
class GoogleOAuthManager: ObservableObject {
    @Published var user: GIDGoogleUser?
    @Published var enabled: Set<GoogleTool> = []

    func generateToken(refresh: Bool) async -> GIDGoogleUser? {
        do {
            // Refresh token if user already exists
            if refresh {
                if let user = self.user {
                    do {
                        try await user.refreshTokensIfNeeded()
                        return user
                    } catch {}
                }
            }

            // Get the presenting window (required for macOS)
            guard let presentingWindow = NSApplication.shared.keyWindow else {
                throw LoginError.noPresentingWindow
            }
            // Configure Google Sign-In
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw LoginError.noClientID
            }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingWindow,
                hint: nil,
                additionalScopes: additionalScopes()
            )

            user = result.user
            return user
        } catch {
            logger.error("Get token: \(error.localizedDescription)")
            user = nil
            return user
        }
    }

    func resetToken() {
        user = nil
    }

    struct GoogleOAuthScopes {
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
        static let formsResponsesReadonly =
            "https://www.googleapis.com/auth/forms.responses.readonly"

        // Slides
        static let slides = "https://www.googleapis.com/auth/presentations"
        static let slidesReadonly = "https://www.googleapis.com/auth/presentations.readonly"

        // Tasks
        static let tasks = "https://www.googleapis.com/auth/tasks"
        static let tasksReadonly = "https://www.googleapis.com/auth/tasks.readonly"

    }

    struct GoogleScopeGroups {
        static let base = [
            GoogleOAuthScopes.userInfoEmail,
            GoogleOAuthScopes.userInfoProfile,
            GoogleOAuthScopes.openID,
        ]

        static let docs = [
            GoogleOAuthScopes.docsReadonly,
            GoogleOAuthScopes.docsWrite,
        ]

        static let calendar = [
            GoogleOAuthScopes.calendar,
            GoogleOAuthScopes.calendarReadonly,
            GoogleOAuthScopes.calendarEvents,
        ]

        static let drive = [
            GoogleOAuthScopes.drive,
            GoogleOAuthScopes.driveReadonly,
            GoogleOAuthScopes.driveFile,
        ]

        static let gmail = [
            GoogleOAuthScopes.gmailReadonly,
            GoogleOAuthScopes.gmailSend,
            GoogleOAuthScopes.gmailCompose,
            GoogleOAuthScopes.gmailModify,
            GoogleOAuthScopes.gmailLabels,
        ]

        static let sheets = [
            GoogleOAuthScopes.sheetsReadonly,
            GoogleOAuthScopes.sheetsWrite,
        ]

        static let forms = [
            GoogleOAuthScopes.formsBody,
            GoogleOAuthScopes.formsBodyReadonly,
            GoogleOAuthScopes.formsResponsesReadonly,
        ]

        static let slides = [
            GoogleOAuthScopes.slides,
            GoogleOAuthScopes.slidesReadonly,
        ]

        static let tasks = [
            GoogleOAuthScopes.tasks,
            GoogleOAuthScopes.tasksReadonly,
        ]
    }

    enum GoogleTool: String, CaseIterable, Identifiable {
        case gmail = "Gmail"
        case drive = "Drive"
        case calendar = "Calendar"
        case docs = "Docs"
        case sheets = "Sheets"
        case forms = "Form"
        case slides = "Slides"
        case tasks = "Tasks"

        var id: String { rawValue }
    }

    let toolScopesMap: [GoogleTool: [String]] = [
        .gmail: GoogleScopeGroups.gmail,
        .drive: GoogleScopeGroups.drive,
        .calendar: GoogleScopeGroups.calendar,
        .docs: GoogleScopeGroups.docs,
        .sheets: GoogleScopeGroups.sheets,
        .forms: GoogleScopeGroups.forms,
        .slides: GoogleScopeGroups.slides,
        .tasks: GoogleScopeGroups.tasks,
    ]

    func additionalScopes() -> [String] {
        var s = Set(enabled.flatMap { toolScopesMap[$0] ?? [] })
        for b in GoogleScopeGroups.base {
            s.insert(b)
        }
        return Array(s)
    }

    func enabledCapabilities() -> [String] {
        enabled.flatMap { toolCapabilities[$0] ?? [] }
    }

    let toolCapabilities: [GoogleTool: [String]] = [
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
            "batch_modify_gmail_message_labels",
        ],
        .drive: [
            "search_drive_files",
            "get_drive_file_content",
            "create_drive_file",
            "list_drive_items",
            "get_drive_file_permissions",
            "check_drive_file_public_access",
        ],
        .calendar: [
            "list_calendars",
            "get_events",
            "create_event",
            "modify_event",
            "delete_event",
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
            "resolve_document_comment",
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
            "resolve_spreadsheet_comment",
        ],
        .forms: [
            "create_form",
            "get_form",
            "list_form_responses",
            "set_publish_settings",
            "get_form_response",
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
            "resolve_presentation_comment",
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
            "clear_completed_tasks",
        ],
    ]

}
