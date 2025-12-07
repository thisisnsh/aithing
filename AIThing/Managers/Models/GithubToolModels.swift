//
//  GithubToolModels.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation

// MARK: - GitHub Tool Configuration

/// Static configuration for GitHub OAuth scopes and API capabilities.
/// Maps tools to required scopes and available API operations.
enum GithubToolModels {
    
    // MARK: - OAuth Scopes
    
    /// Available GitHub OAuth scopes
    enum Scopes {
        // Default scopes
        static let readUser = "read:user"
        static let userEmail = "user:email"
        static let readOrg = "read:org"
        
        // Tool-specific scopes
        static let workflow = "workflow"
        static let repo = "repo"
        static let publicRepo = "public_repo"
        static let securityEvents = "security_events"
        static let gist = "gist"
        static let notifications = "notifications"
    }
    
    // MARK: - Tool to Scope Mapping
    
    /// Maps GitHub tools to their required OAuth scopes
    static let toolScopesMap: [GithubTool: [String]] = [
        .actions: [
            Scopes.workflow,
            Scopes.repo
        ],
        .codeSecurity: [
            Scopes.securityEvents
        ],
        .dependabot: [
            Scopes.securityEvents
        ],
        .discussions: [
            Scopes.repo,
            Scopes.publicRepo
        ],
        .gists: [
            Scopes.gist
        ],
        .issues: [
            Scopes.repo,
            Scopes.publicRepo
        ],
        .notifications: [
            Scopes.notifications
        ],
        .orgs: [
            Scopes.readOrg
        ],
        .pullRequests: [
            Scopes.repo,
            Scopes.publicRepo
        ],
        .repos: [
            Scopes.repo,
            Scopes.publicRepo
        ],
        .secretProtection: [
            Scopes.securityEvents
        ],
        .securityAdvisories: [
            Scopes.repo,
            Scopes.readOrg
        ],
        .users: [
            Scopes.readUser
        ]
    ]
    
    // MARK: - Tool Capabilities
    
    /// Maps GitHub tools to their available API operations
    static let toolCapabilities: [GithubTool: [String]] = [
        .actions: [
            "cancel_workflow_run",
            "delete_workflow_run_logs",
            "download_workflow_run_artifact",
            "get_job_logs",
            "get_workflow_run",
            "get_workflow_run_logs",
            "get_workflow_run_usage",
            "list_workflow_jobs",
            "list_workflow_run_artifacts",
            "list_workflow_runs",
            "list_workflows",
            "rerun_failed_jobs",
            "rerun_workflow_run",
            "run_workflow"
        ],
        .codeSecurity: [
            "get_code_scanning_alert",
            "list_code_scanning_alerts"
        ],
        .dependabot: [
            "get_dependabot_alert",
            "list_dependabot_alerts"
        ],
        .discussions: [
            "get_discussion",
            "get_discussion_comments",
            "list_discussion_categories",
            "list_discussions"
        ],
        .gists: [
            "create_gist",
            "list_gists",
            "update_gist"
        ],
        .issues: [
            "add_issue_comment",
            "add_sub_issue",
            "assign_copilot_to_issue",
            "create_issue",
            "get_issue",
            "get_issue_comments",
            "list_issue_types",
            "list_issues",
            "list_sub_issues",
            "remove_sub_issue",
            "reprioritize_sub_issue",
            "search_issues",
            "update_issue"
        ],
        .notifications: [
            "dismiss_notification",
            "get_notification_details",
            "list_notifications",
            "manage_notification_subscription",
            "manage_repository_notification_subscription",
            "mark_all_notifications_read"
        ],
        .orgs: [
            "search_orgs"
        ],
        .pullRequests: [
            "add_comment_to_pending_review",
            "create_and_submit_pull_request_review",
            "create_pending_pull_request_review",
            "create_pull_request",
            "delete_pending_pull_request_review",
            "get_pull_request",
            "get_pull_request_comments",
            "get_pull_request_diff",
            "get_pull_request_files",
            "get_pull_request_reviews",
            "get_pull_request_status",
            "list_pull_requests",
            "merge_pull_request",
            "request_copilot_review",
            "search_pull_requests",
            "submit_pending_pull_request_review",
            "update_pull_request",
            "update_pull_request_branch"
        ],
        .repos: [
            "create_branch",
            "create_or_update_file",
            "create_repository",
            "delete_file",
            "fork_repository",
            "get_commit",
            "get_file_contents",
            "get_latest_release",
            "get_release_by_tag",
            "get_tag",
            "list_branches",
            "list_commits",
            "list_releases",
            "list_tags",
            "push_files",
            "search_code",
            "search_repositories"
        ],
        .secretProtection: [
            "get_secret_scanning_alert",
            "list_secret_scanning_alerts"
        ],
        .securityAdvisories: [
            "get_global_security_advisory",
            "list_global_security_advisories",
            "list_org_repository_security_advisories",
            "list_repository_security_advisories"
        ],
        .users: [
            "search_users"
        ]
    ]
}

