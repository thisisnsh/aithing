//
//  FirestoreManager.swift
//  BF2
//
//  Created by Nishant Singh Hada on 6/21/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import os

struct Usage: Codable {
    var query: Int = 0
    var agentUse: Int = 0
    var filesAttached: Int = 0
}

struct Profile: Codable {
    var id: String
    var name: String?
    var email: String
    var creditsTotal: Int
    var creditsUsed: Int
    var blocked: Bool
    var apiKeyAnthropic: String
    var apiKeyOpenAI: String
    var usageData: Usage?
}

struct PlanDetail: Codable {
    var credits: Int
}

struct PlanOrder: Codable {
    var id: String
    var planId: String
    var endDate: Date
}

class FirestoreManager: ObservableObject {
    let db = Firestore.firestore()
    let logger = Logger(subsystem: "com.thisisnsh.mac.AIThing", category: "FirestoreManager")

    // MARK: Configs

    func getBreakglass() async -> Bool {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.6").getDocument()
            guard let data = snapshot.data() else { return false }
            guard let breakglass = data["breakglass"] as? Bool else { return false }
            AnalyticsManager.shared.customFirestore(action: "get_breakglass", status: "success")
            return breakglass
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_breakglass", status: "failure")
            logger.error(
                "[FirestoreManager] Error fetching breakglass: \(error.localizedDescription)"
            )
            return false
        }
    }

    func getExpired() async -> Bool {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.6").getDocument()
            guard let data = snapshot.data() else { return false }
            guard let expired = data["expired"] as? Bool else { return false }
            AnalyticsManager.shared.customFirestore(action: "get_expired", status: "success")
            return expired
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_expired", status: "failure")
            logger.error(
                "[FirestoreManager] Error fetching expired: \(error.localizedDescription)"
            )
            return false
        }
    }

    func getApiKeyAnthropic() async -> String {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.6").getDocument()
            guard let data = snapshot.data() else { return "" }
            guard let apiKeyAnthropic = data["apiKeyAnthropic"] as? String else { return "" }
            AnalyticsManager.shared.customFirestore(
                action: "get_anthropic_api_key",
                status: "success"
            )
            return apiKeyAnthropic
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "get_anthropic_api_key",
                status: "failure"
            )
            logger.error(
                "[FirestoreManager] Error fetching apiKeyAnthropic: \(error.localizedDescription)"
            )
            return ""
        }
    }

    func getDefaultCredits() async -> Int? {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.6").getDocument()
            guard let data = snapshot.data() else { return nil }
            guard let defaultCredits = data["defaultCredits"] as? Int else { return nil }
            AnalyticsManager.shared.customFirestore(
                action: "get_default_credits",
                status: "success"
            )
            return defaultCredits
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "get_default_credits",
                status: "failure"
            )
            logger.error(
                "[FirestoreManager] Error fetching defaultCredits: \(error.localizedDescription)"
            )
            return nil
        }
    }

    func getNotification() async -> String? {
        do {
            let snapshot = try await db.collection("System").document("Configs-1.6").getDocument()
            guard let data = snapshot.data() else { return nil }
            guard let notification = data["notification"] as? String else { return nil }
            AnalyticsManager.shared.customFirestore(
                action: "get_notification",
                status: "success"
            )
            return notification
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "get_notification",
                status: "failure"
            )
            logger.error(
                "[FirestoreManager] Error fetching notification: \(error.localizedDescription)"
            )
            return nil
        }
    }

    // MARK: Others

    private func _getProfile(user: AppUser) async -> Profile? {
        let id = user.uid

        do {
            let snapshot = try await db.collection("Profiles").document(id).getDocument()
            if let profile = try? snapshot.data(as: Profile.self) {
                AnalyticsManager.shared.customFirestore(action: "get_profile", status: "success")
                return profile
            }

            return nil
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_profile", status: "failure")
            logger.error(
                "[FirestoreManager] Error fetching profile for ID \(id): \(error.localizedDescription)"
            )
            return nil
        }
    }

    func getProfile(user: AppUser) async -> Profile? {
        let id = user.uid

        if let profile = await _getProfile(user: user) {
            return profile
        }

        let apiKeyAnthropic = await getApiKeyAnthropic()
        let defaultCredits = await getDefaultCredits()

        let profile = Profile(
            id: id,
            name: user.displayName,
            email: user.email ?? "",  // todo: handle properly
            creditsTotal: defaultCredits ?? 50,
            creditsUsed: 0,
            blocked: false,
            apiKeyAnthropic: apiKeyAnthropic,
            apiKeyOpenAI: "",
            usageData: Usage()
        )
        do {
            try db.collection("Profiles").document(id).setData(from: profile)
            AnalyticsManager.shared.customFirestore(action: "create_profile", status: "success")
            return profile
        } catch {
            AnalyticsManager.shared.customFirestore(action: "create_profile", status: "failure")
            logger.error(
                "[FirestoreManager] Error creating profile for ID \(id): \(error.localizedDescription)"
            )
            return nil
        }
    }

    func incrementCredits(user: AppUser, by amount: Int) async {
        let id = user.uid

        do {
            try await db.collection("Profiles").document(id).updateData([
                "creditsUsed": FieldValue.increment(Int64(amount))
            ])
            AnalyticsManager.shared.customFirestore(action: "increment_credit", status: "success")
        } catch {
            AnalyticsManager.shared.customFirestore(action: "increment_credit", status: "failure")
            logger.error(
                "[FirestoreManager] Error incrementing creditsUsed by \(amount) for ID \(id): \(error.localizedDescription)"
            )
        }
    }

    func incrementUsage(user: AppUser, usage: Usage) async {
        let id = user.uid

        do {
            try await db.collection("Profiles").document(id).updateData([
                "usageData.query": FieldValue.increment(Int64(usage.query)),
                "usageData.agentUse": FieldValue.increment(Int64(usage.agentUse)),
                "usageData.filesAttached": FieldValue.increment(Int64(usage.filesAttached)),
            ])
            AnalyticsManager.shared.customFirestore(action: "increment_usage", status: "success")
        } catch {
            AnalyticsManager.shared.customFirestore(action: "increment_usage", status: "failure")
            logger.error(
                "[FirestoreManager] Error incrementing usage for ID \(id): \(error.localizedDescription)"
            )
        }
    }

    func getModelInfos() async -> [ModelInfo] {
        do {
            let snapshot = try await db.collection("Models").getDocuments()

            let models: [ModelInfo] = snapshot.documents.compactMap { doc in
                if let model = try? doc.data(as: ModelInfo.self) {
                    return model
                }
                return nil
            }

            AnalyticsManager.shared.customFirestore(action: "get_model_info", status: "success")

            // Sort: first by order, then by title if order is equal
            return models.sorted {
                if $0.order == $1.order {
                    return $0.title.localizedCompare($1.title) == .orderedAscending
                }
                return $0.order < $1.order
            }
        } catch {
            AnalyticsManager.shared.customFirestore(action: "get_model_info", status: "failure")
            logger.error("[FirestoreManager] Error fetching models: \(error.localizedDescription)")
            return []
        }
    }

    func createModel(model: ModelInfo) async {
        do {
            try db.collection("Models").document(model.id).setData(from: model)
            logger.error("[FirestoreManager] Created/updated model with id \(model.id)")
        } catch {
            logger.error(
                "[FirestoreManager] Error creating model \(model.id): \(error.localizedDescription)"
            )
        }
    }

    func fetchCreditsPlans(email: String) async -> Int {
        let creditsPlans = await getActivePlanCredits(forEmail: email)
        return creditsPlans
    }

    // MARK: Agents

    struct ManagedGitHubAgent: Codable {
        var clientId: String
        var clientSecret: String
    }

    struct McpServer: Codable {
        let image: String?
        let name: String
        let url: String
    }

    func getManagedGitHubAgent() async -> ManagedGitHubAgent? {
        do {
            let snapshot = try await db.collection("Agents").document("managed_github_agent")
                .getDocument()
            if let agent = try? snapshot.data(as: ManagedGitHubAgent.self) {
                AnalyticsManager.shared.customFirestore(
                    action: "get_managed_github_agent",
                    status: "success"
                )
                return agent
            }

            return nil
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "get_managed_github_agent",
                status: "failure"
            )
            logger.error(
                "[FirestoreManager] Error fetching get_managed_github_agent: \(error.localizedDescription)"
            )
            return nil
        }
    }

    func allMcpServers() -> [McpServer] {
        return [
            McpServer(image: nil, name: "Apify", url: "https://mcp.apify.com"),
            McpServer(image: nil, name: "Asana", url: "https://mcp.asana.com/sse"),
            McpServer(image: nil, name: "Atlassian", url: "https://mcp.atlassian.com/v1/sse"),
            McpServer(image: nil, name: "Audioscrape", url: "https://mcp.audioscrape.com"),
            McpServer(image: nil, name: "Canva", url: "https://mcp.canva.com/mcp"),
            McpServer(image: nil, name: "Carbon Voice", url: "https://mcp.carbonvoice.app"),
            McpServer(image: nil, name: "Close", url: "https://mcp.close.com/mcp"),
            McpServer(
                image: nil,
                name: "Cloudflare Observability",
                url: "https://observability.mcp.cloudflare.com/sse"
            ),
            McpServer(
                image: nil,
                name: "Cloudflare Workers",
                url: "https://bindings.mcp.cloudflare.com/sse"
            ),
            McpServer(
                image: nil,
                name: "Cloudinary",
                url: "https://asset-management.mcp.cloudinary.com/sse"
            ),
            McpServer(image: nil, name: "Dialer", url: "https://getdialer.app/sse"),
            McpServer(image: nil, name: "Dodo Payments", url: "https://mcp.dodopayments.com/sse"),
            McpServer(image: nil, name: "Firefly", url: "https://api.fireflies.ai/mcp"),
            McpServer(image: nil, name: "GitMCP", url: "https://gitmcp.io/docs"),
            McpServer(image: nil, name: "Globalping", url: "https://mcp.globalping.dev/sse"),
            McpServer(image: nil, name: "HubSpot", url: "https://app.hubspot.com/mcp/v1/http"),
            McpServer(image: nil, name: "Hugging Face", url: "https://huggingface.co/mcp"),
            McpServer(image: nil, name: "Instant", url: "https://mcp.instantdb.com/mcp"),
            McpServer(image: nil, name: "Intercom", url: "https://mcp.intercom.com/sse"),
            McpServer(image: nil, name: "Jam", url: "https://mcp.jam.dev/mcp"),
            McpServer(image: nil, name: "Kollektiv", url: "https://mcp.thekollektiv.ai/sse"),
            McpServer(image: nil, name: "Linear", url: "https://mcp.linear.app/sse"),
            McpServer(image: nil, name: "Listenetic", url: "https://mcp.listenetic.com/v1/mcp"),
            McpServer(
                image: nil,
                name: "Meta Ads by Pipeboard",
                url: "https://mcp.pipeboard.co/meta-ads-mcp"
            ),
            McpServer(image: nil, name: "monday.com", url: "https://mcp.monday.com/sse"),
            McpServer(image: nil, name: "Neon", url: "https://mcp.neon.tech/sse"),
            McpServer(image: nil, name: "Netlify", url: "https://netlify-mcp.netlify.app/mcp"),
            McpServer(image: nil, name: "Notion", url: "https://mcp.notion.com/sse"),
            McpServer(image: nil, name: "Octagon", url: "https://mcp.octagonagents.com/mcp"),
            McpServer(
                image: nil,
                name: "OneContext",
                url: "https://rag-mcp-2.whatsmcp.workers.dev/sse"
            ),
            McpServer(image: nil, name: "PayPal", url: "https://mcp.paypal.com/sse"),
            McpServer(image: nil, name: "Prisma Postgres", url: "https://mcp.prisma.io/mcp"),
            McpServer(image: nil, name: "Rube", url: "https://rube.app/mcp"),
            McpServer(
                image: nil,
                name: "Scorecard",
                url: "https://scorecard-mcp.dare-d5b.workers.dev/sse"
            ),
            McpServer(image: nil, name: "Sentry", url: "https://mcp.sentry.dev/sse"),
            McpServer(image: nil, name: "Short.io", url: "https://ai-assistant.short.io/mcp"),
            McpServer(image: nil, name: "Simplescraper", url: "https://mcp.simplescraper.io/mcp"),
            McpServer(image: nil, name: "Square", url: "https://mcp.squareup.com/sse"),
            McpServer(image: nil, name: "Stytch", url: "http://mcp.stytch.dev/mcp"),
            McpServer(
                image: nil,
                name: "Turkish Airlines",
                url: "https://mcp.turkishtechlab.com/mcp"
            ),
            McpServer(image: nil, name: "Vercel", url: "https://mcp.vercel.com/"),
            McpServer(image: nil, name: "WayStation", url: "https://waystation.ai/mcp"),
            McpServer(image: nil, name: "Webflow", url: "https://mcp.webflow.com/sse"),
            McpServer(image: nil, name: "Wix", url: "https://mcp.wix.com/sse"),
            McpServer(image: nil, name: "Zapier", url: "https://mcp.zapier.com/api/mcp/mcp"),
            McpServer(image: nil, name: "Zine", url: "https://www.zine.ai/mcp"),
        ]
    }

    func runServers() {
        do {
            for server in allMcpServers() {
                let snakeCase = server.name
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: ".", with: "_")
                    .replacingOccurrences(of: "-", with: "_")

                try db.collection("Agents").document("managed_\(snakeCase)").setData(from: server)
            }
        } catch {}
    }

    /**
     | Asana | Project Management | `https://mcp.asana.com/sse` | OAuth2.1 | [Asana](https://asana.com) |
     | Audioscrape | RAG-as-a-Service | `https://mcp.audioscrape.com` | OAuth2.1 | [Audioscrape](https://www.audioscrape.com) |
     | Atlasian | Software Development | `https://mcp.atlassian.com/v1/sse` | OAuth2.1 🔐 | [Atlassian](https://atlassian.com) |
     | Box | Document Management | `https://mcp.box.com` | OAuth2.1 🔐| [Box](https://box.com) |
     | Buildkite | Software Developmenr | `https://mcp.buildkite.com/mcp` | OAuth2.1 | [Buildkite](https://buildkite.com) |
     | Canva | Design | `https://mcp.canva.com/mcp` | OAuth2.1 | [Canva](https://canva.com) |
     | Carbon Voice | Productivity | `https://mcp.carbonvoice.app` | OAuth2.1 | [Carbon Voice](https://getcarbon.app) |
     | Cloudflare Workers | Software Development | `https://bindings.mcp.cloudflare.com/sse` | OAuth2.1 | [Cloudflare](https://cloudflare.com) |
     | Cloudflare Observability | Observability | `https://observability.mcp.cloudflare.com/sse` | OAuth2.1 | [Cloudflare](https://cloudflare.com) |
     | Cloudinary | Asset Management | `https://asset-management.mcp.cloudinary.com/sse` | OAuth2.1 | [Cloudinary](https://cloudinary.com) |
     | Dialer | Outbound Phone Calls | `https://getdialer.app/sse` | OAuth2.1 | [Dialer](https://getdialer.app) |
     | Egnyte | Document Management | `https://mcp-server.egnyte.com/sse` | OAuth2.1 | [Egnyte](https://egnyte.com) |
     | Firefly | Productivity | `https://api.fireflies.ai/mcp` | OAuth2.1 | [Firefly](https://fireflies.ai) |
     | Find-A-Domain | Productivity | `https://api.findadomain.dev/mcp` | Open | [Find-A-Domain](https://findadomain.dev) |
     | GitHub | Software Development | `https://api.githubcopilot.com/mcp` | OAuth2.1 🔐 | [GitHub](https://github.com) |
     | Globalping | Software Development | `https://mcp.globalping.dev/sse` | OAuth2.1 | [Globalping](https://globalping.io/) |
     | Grafbase | Software Development | `https://api.grafbase.com/mcp` | OAuth 2.1 | [Grafbase](https://grafbase.com) |
     | Hive Intelligence | Crypto | `https://hiveintelligence.xyz/mcp` | OAuth 2.1 | [Hive Intelligence](https://hiveintelligence.xyz/) |
     | Instant | Software Development | `https://mcp.instantdb.com/mcp` | OAuth | [Instant](https://www.instantdb.com/) |
     | Intercom | Customer Support | `https://mcp.intercom.com/sse` | OAuth2.1 | [Intercom](https://intercom.com) |
     | Invidio | Video Platform | `https://mcp.invideo.io/sse` | OAuth2.1 | [Invidio](https://invideo.io/) |
     | Jam | Software Development | `https://mcp.jam.dev/mcp` | OAuth2.1 | [Jam.dev](https://jam.dev/) |
     | Kollektiv | Documentation | `https://mcp.thekollektiv.ai/sse` | Oauth2.1 | [Kollektiv](https://github.com/alexander-zuev/kollektiv-mcp) |
     | Linear | Project Management | `https://mcp.linear.app/sse` | OAuth2.1 | [Linear](https://linear.app) |
     | Listenetic | Productivity | `https://mcp.listenetic.com/v1/mcp` | OAuth2.1 | [Listenetic](https://app.listenetic.com) |
     | Meta Ads by Pipeboard | Advertising | `https://mcp.pipeboard.co/meta-ads-mcp` | OAuth2.1 | [Pipeboard](https://pipeboard.co) |
     | monday.com | Productivity | `https://mcp.monday.com/sse` | OAuth2.1 |  [monday MCP](https://github.com/mondaycom/mcp) |
     | Neon | Software Development | `https://mcp.neon.tech/sse` | OAuth2.1 | [Neon](https://neon.tech) |
     | Netlify | Software Development | `https://netlify-mcp.netlify.app/mcp` | OAuth2.1 | [Netlify](https://netlify.com) |
     | Notion | Project Management | `https://mcp.notion.com/sse` | OAuth2.1 | [Notion](https://notion.so) |
     | Octagon | Market Intelligence | `https://mcp.octagonagents.com/mcp` | OAuth2.1 | [Octagon](https://octagonai.co) |
     | OneContext | RAG-as-a-Service | `https://rag-mcp-2.whatsmcp.workers.dev/sse` | OAuth2.1 | [OneContext](https://onecontext.ai) |
     | PayPal | Payments | `https://mcp.paypal.com/sse` | OAuth2.1 | [PayPal](https://paypal.com) |
     | Plaid | Payments | `https://api.dashboard.plaid.com/mcp/sse` | OAuth2.1 🔐| [Plaid](https://plaid.com) |
     | Prisma Postgres | Database |  `https://mcp.prisma.io/mcp` | OAuth2.1 | [Prisma Postgres](https://www.prisma.io/docs/postgres/integrations/mcp-server#remote-mcp-server)
     | Rube | Other | `https://rube.app/mcp` | Oauth2.1 | [Composio](https://composio.dev) |
     | Scorecard | AI Evaluation | `https://scorecard-mcp.dare-d5b.workers.dev/sse` | OAuth2.1 | [Scorecard](https://scorecard.io) |
     | Sentry | Software Development | `https://mcp.sentry.dev/sse` | OAuth2.1 | [Sentry](https://sentry.io) |
     | Stripe | Payments | `https://mcp.stripe.com/` | OAuth2.1 & API Key | [Stripe](https://stripe.com) |
     | Stytch | Authentication | `http://mcp.stytch.dev/mcp` | OAuth2.1 | [Stytch](https://stytch.com) |
     | Square | Payments | `https://mcp.squareup.com/sse` | OAuth2.1 | [Square](https://square.com) |
     | Turkish Airlines | Airlines | `https://mcp.turkishtechlab.com/mcp` | OAuth2.1 | [Turkish Technology](https://mcp.turkishtechlab.com/) |
     | Vercel | Software Development | `https://mcp.vercel.com/` | OAuth2.1 | [Vercel](https://vercel.com) |
     | Webflow | CMS | `https://mcp.webflow.com/sse` | OAuth2.1 | [Webflow](https://webflow.com) |
     | Wix | CMS | `https://mcp.wix.com/sse` | OAuth2.1 | [Wix](https://wix.com) |
     | Simplescraper | Web Scraping | `https://mcp.simplescraper.io/mcp` | OAuth2.1 | [Simplescraper](https://simplescraper.io) |
     | WayStation | Productivity | `https://waystation.ai/mcp` | OAuth2.1 | [WayStation](https://waystation.ai) |
     | Zenable | Security | `https://mcp.www.zenable.app/` | OAuth2.1 | [Zenable](https://zenable.io) |
     | Zine | Memory | `https://www.zine.ai/mcp` | OAuth2.1 | [Zine](https://www.zine.ai/) |
     | Cloudflare Docs | Documentation | `https://docs.mcp.cloudflare.com/sse` | Open | [Cloudflare](https://cloudflare.com) |
     | Astro Docs | Documentation | `https://mcp.docs.astro.build/mcp` | Open | [Astro](https://astro.build) |
     | DeepWiki | RAG-as-a-Service | `https://mcp.deepwiki.com/sse` | Open | [Devin](https://devin.ai/) |
     | Hugging Face | Software Development | `https://huggingface.co/mcp` | Open | [Hugging Face](https://huggingface.co) |
     | Semgrep | Software Development | `https://mcp.semgrep.ai/sse` | Open | [Semgrep](https://semgrep.dev/) |
     | Remote MCP | MCP Directory | `https://mcp.remote-mcp.com` | Open | [Remote MCP](https://remote-mcp.com/) |
     | OpenMesh | Service Discovery | `https://api.openmesh.dev/mcp` | Open | [OpenMesh](https://openmesh.dev) |
     | OpenZeppelin Cairo Contracts | Software Development | `https://mcp.openzeppelin.com/contracts/cairo/mcp` | Open | [OpenZeppelin](https://openzeppelin.com) |
     | OpenZeppelin Solidity Contracts | Software Development | `https://mcp.openzeppelin.com/contracts/solidity/mcp` | Open | [OpenZeppelin](https://openzeppelin.com) |
     | OpenZeppelin Stellar Contracts | Software Development | `https://mcp.openzeppelin.com/contracts/stellar/mcp` | Open | [OpenZeppelin](https://openzeppelin.com) |
     | OpenZeppelin Stylus Contracts | Software Development | `https://mcp.openzeppelin.com/contracts/stylus/mcp` | Open | [OpenZeppelin](https://openzeppelin.com) |
     | LLM Text | Data Analysis | `https://mcp.llmtxt.dev/sse` | Open | [LLM Text](https://llmtxt.dev) |
     | GitMCP | Software Development | `https://gitmcp.io/docs` | Open | [GitMCP](https://gitmcp.io) |
     | Close | CRM | `https://mcp.close.com/mcp` | API Key | [Close](https://help.close.com/docs/mcp-server) |
     | HubSpot | CRM | `https://app.hubspot.com/mcp/v1/http` | API Key | [HubSpot](https://hubspot.com) |
     | Needle | RAG-as-a-service | `https://mcp.needle-ai.com/mcp` | API Key | [Needle](https://needle-ai.com) |
     | Zapier | Automation | `https://mcp.zapier.com/api/mcp/mcp` | API Key | [Zapier](https://zapier.com) |
     | Apify | Web Data Extraction Platform | `https://mcp.apify.com` | API Key | [Apify](https://apify.com) |
     | Dappier | RAG-as-a-Service | `https://mcp.dappier.com/mcp` | API Key | [Dappier](https://dappier.com/) |
     | Mercado Libre | E-Commerce | `https://mcp.mercadolibre.com/mcp` | API Key | [Mercado Libre MCP McpServer](https://mcp.mercadolibre.com/) |
     | Mercado Pago | Payments | `https://mcp.mercadopago.com/mcp` | API Key | [Mercado Pago MCP McpServer](https://mcp.mercadopago.com/) |
     | Short.io | Link shortener | `https://ai-assistant.short.io/mcp` | API Key | [Short.io](https://short.io) |
     | Telnyx | Communication | `https://api.telnyx.com/v2/mcp` | API Key | [Telnyx](https://telnyx.com) |
     | Dodo Payments | Payments | `https://mcp.dodopayments.com/sse` | API Key | [Dodo Payments](https://dodopayments.com) |
     | Polar Signals | Software Development | `https://api.polarsignals.com/api/mcp/` | API Key | [Polar Signals](https://www.polarsignals.com/blog/posts/2025/07/17/the-mcp-for-performance-engineering) |
     | Manifold | Forecasting | `https://api.manifold.markets/v0/mcp` | Open | [Manifold](https://manifold.markets) |
     | Javadocs | Software Development | `https://www.javadocs.dev/mcp` | Open | [Javadocs.dev](https://javadocs.dev) |
    
    
     3    Asana    https://mcp.asana.com/sse
     Anthropic Help Center
     +2
     Anthropic
     +2
     4    Atlassian    https://mcp.atlassian.com/v1/sse
     Anthropic Help Center
     +1
     5    Intercom    https://mcp.intercom.com/mcp
     Anthropic
     +1
     6    Linear    https://mcp.linear.app/sse
     GitHub
     +1
     7    Box    https://mcp.box.com
     GitHub
     8    Buildkite    https://mcp.buildkite.com/mcp
     GitHub
     9    Canva    https://mcp.canva.com/mcp
     GitHub
     10    Cloudflare Workers    https://bindings.mcp.cloudflare.com/sse
     GitHub
     11    Cloudflare Observability    https://observability.mcp.cloudflare.com/sse
     GitHub
     12    Cloudinary Asset Management    https://asset-management.mcp.cloudinary.com/sse
     GitHub
     13    Egnyte    https://mcp-server.egnyte.com/sse
     GitHub
     14    Fireflies.AI    https://api.fireflies.ai/mcp
     GitHub
     15    GitHub Copilot / GitHub    https://api.githubcopilot.com/mcp
     GitHub
     16    Globalping    https://mcp.globalping.dev/sse
     GitHub
     17    Grafbase    https://api.grafbase.com/mcp
     GitHub
     18    Intervidio / InVideo    https://mcp.invideo.io/sse
     GitHub
     19    Monday.com    https://mcp.monday.com/sse
     GitHub
     20    Notion    https://mcp.notion.com/sse
     GitHub
     21    PayPal    https://mcp.paypal.com/sse
     GitHub
     22    Sentry    https://mcp.sentry.dev/sse
     GitHub
     +1
     23    Stripe    https://mcp.stripe.com/
     GitHub
     24    Square    https://mcp.squareup.com/sse
     GitHub
     25    Vercel    https://mcp.vercel.com/
     */

}

extension FirestoreManager {

    private func getActivePlanCredits(forEmail email: String, asOf: Date = Date()) async -> Int {
        let planCredits = await getPlanDetailsMap()

        let orders = await getActiveOrders(forEmail: email, planCredits: planCredits, asOf: asOf)

        var total = 0
        for order in orders {
            if let credits = planCredits[order.planId] {
                total += credits
            } else {
                AnalyticsManager.shared.customFirestore(
                    action: "fetch_credits_missing_plan_details",
                    status: "failure"
                )
                logger.error("[FirestoreManager] Missing PlanDetails for planId \(order.planId)")
            }
        }
        return total
    }

    /// Returns a map of planId -> credits, read from /PlanDetails/<planId>.
    func getPlanDetailsMap() async -> [String: Int] {
        var result: [String: Int] = [:]
        do {
            let snapshot = try await db.collection("PlanDetails").getDocuments()
            for doc in snapshot.documents {
                if let detail = try? doc.data(as: PlanDetail.self) {
                    result[doc.documentID] = detail.credits
                } else {
                    // If decoding fails, try a tolerant read
                    let data = doc.data()
                    if let credits = data["credits"] as? Int {
                        result[doc.documentID] = credits
                    }
                }
            }
        } catch {
            AnalyticsManager.shared.customFirestore(
                action: "fetch_credits_error_plan_details",
                status: "failure"
            )
            logger.error(
                "[FirestoreManager] Error fetching PlanDetails: \(error.localizedDescription)"
            )
        }
        return result
    }

    /// Loads all orders for the given email with endDate in the future relative to `asOf`.
    ///
    /// Implementation note:
    /// - We first fetch all planIds from /PlanDetails, then for each planId we read the subcollection
    ///   /Plans/<email>/<planId>.
    /// - We try a server filter `whereField("endDate", isGreaterThan:)` assuming endDate is a Timestamp.
    ///   If the field is stored as string, we fall back to fetching the subcollection and filtering client-side.
    func getActiveOrders(forEmail email: String, planCredits: [String: Int], asOf: Date = Date())
        async -> [PlanOrder]
    {
        var active: [PlanOrder] = []
        let planIds = Array(planCredits.keys)  // Using PlanDetails as the source of truth for valid planIds
        if planIds.isEmpty {
            return []
        }

        let userDoc = db.collection("Plans").document(email)

        await withTaskGroup(of: [PlanOrder].self) { group in
            for planId in planIds {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }

                    let subcol = userDoc.collection(planId)
                    var collected: [PlanOrder] = []

                    // Preferred path: endDate is a Firestore Timestamp (server-side filter)
                    do {

                        let ts = Timestamp(date: asOf)

                        let snap = try await subcol.whereField("endDate", isGreaterThan: ts)
                            .getDocuments()

                        for doc in snap.documents {

                            if let order = self.decodeOrder(
                                doc: doc,
                                planId: planId,
                                fallbackStringParsing: false
                            ) {
                                collected.append(order)
                            }
                        }
                        return collected.sorted { $0.endDate < $1.endDate }
                    } catch {
                        // Fallback: load all docs and parse endDate that might be a String

                        do {
                            let snap = try await subcol.getDocuments()

                            for doc in snap.documents {

                                if let order = self.decodeOrder(
                                    doc: doc,
                                    planId: planId,
                                    fallbackStringParsing: true
                                ),
                                    order.endDate > asOf
                                {
                                    collected.append(order)
                                }
                            }
                            return collected.sorted { $0.endDate < $1.endDate }
                        } catch {
                            AnalyticsManager.shared.customFirestore(
                                action: "fetch_credits_error_reading_orders",
                                status: "failure"
                            )
                            logger.error(
                                "[FirestoreManager] Error reading /Plans/\(email)/\(planId): \(error.localizedDescription)"
                            )
                            return []
                        }
                    }
                }
            }

            for await chunk in group {
                active.append(contentsOf: chunk)
            }
        }

        return active
    }

    /// Attempts to decode a PlanOrder from a DocumentSnapshot.
    /// - Tries Codable first if the schema matches.
    /// - Otherwise, reads fields manually and parses endDate as Timestamp or String.
    private func decodeOrder(doc: DocumentSnapshot, planId: String, fallbackStringParsing: Bool)
        -> PlanOrder?
    {
        // Try Codable first (if you ever add @DocumentID etc.):
        // if let order = try? doc.data(as: PlanOrder.self) { return order }

        let data = doc.data() ?? [:]

        // Try Timestamp
        if let ts = data["endDate"] as? Timestamp {
            return PlanOrder(id: doc.documentID, planId: planId, endDate: ts.dateValue())
        }

        // Optionally parse String endDate
        if fallbackStringParsing, let s = data["endDate"] as? String,
            let parsed = parseEndDateString(s)
        {
            return PlanOrder(id: doc.documentID, planId: planId, endDate: parsed)
        }

        // Try ISO8601 string variants too, if you store them that way
        if fallbackStringParsing, let s = data["endDateISO"] as? String,
            let parsed = ISO8601DateFormatter().date(from: s)
        {
            return PlanOrder(id: doc.documentID, planId: planId, endDate: parsed)
        }

        AnalyticsManager.shared.customFirestore(
            action: "fetch_credits_error_decoding_date",
            status: "failure"
        )
        return nil
    }

    /// Parses example strings like: "endDate September 16, 2025 at 11:59:59 PM UTC-4"
    /// Tries a few tolerant formats; add/remove as your data dictates.
    private func parseEndDateString(_ raw: String) -> Date? {
        // Strip leading "endDate " if present
        let s = raw.replacingOccurrences(of: "^endDate\\s+", with: "", options: .regularExpression)

        // Common patterns you might encounter:
        let candidates: [(DateFormatter, String)] = {
            var list: [(DateFormatter, String)] = []

            func df(
                _ format: String,
                tz: TimeZone? = nil,
                locale: Locale = Locale(identifier: "en_US_POSIX")
            ) -> DateFormatter {
                let f = DateFormatter()
                f.locale = locale
                f.dateFormat = format
                f.timeZone = tz
                return f
            }

            // Example with “at”, timezone suffix like "UTC-4"
            list.append(
                (
                    df("MMMM d, yyyy 'at' h:mm:ss a 'UTC'XXXXX"),
                    "MMMM d, yyyy at h:mm:ss a 'UTC'XXXXX"
                )
            )
            list.append(
                (df("MMMM d, yyyy 'at' h:mm a 'UTC'XXXXX"), "MMMM d, yyyy at h:mm a 'UTC'XXXXX")
            )

            // Without the word “at”
            list.append(
                (df("MMMM d, yyyy h:mm:ss a 'UTC'XXXXX"), "MMMM d, yyyy h:mm:ss a 'UTC'XXXXX")
            )
            list.append((df("MMMM d, yyyy h:mm a 'UTC'XXXXX"), "MMMM d, yyyy h:mm a 'UTC'XXXXX"))

            // Fallback: no explicit timezone -> assume system (or set to Eastern)
            let eastern = TimeZone(identifier: "America/New_York")
            list.append(
                (df("MMMM d, yyyy 'at' h:mm:ss a", tz: eastern), "MMMM d, yyyy at h:mm:ss a")
            )
            list.append((df("MMMM d, yyyy 'at' h:mm a", tz: eastern), "MMMM d, yyyy at h:mm a"))

            return list
        }()

        for (formatter, _) in candidates {
            if let d = formatter.date(from: s) {
                return d
            }
        }

        // Try ISO8601 as last resort
        if let d = ISO8601DateFormatter().date(from: s) {
            return d
        }

        logger.error("[FirestoreManager] Failed to parse endDate string: \(raw)")
        return nil
    }
}
