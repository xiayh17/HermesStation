import Foundation

struct PlatformConfigField: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let label: String
    let isSecret: Bool
    let isAllowlist: Bool
    let helpText: String
    let defaultValue: String?
}

struct PlatformDescriptor: Identifiable, Equatable {
    let id: String
    let displayName: String
    let icon: String
    let tokenVar: String
    let setupInstructions: [String]
    let fields: [PlatformConfigField]
    let specialDiscovery: PlatformDiscoveryType
}

enum PlatformDiscoveryType: Equatable {
    case `default`
    case whatsapp
    case signal
    case email
    case matrix
    case weixin
}

enum PlatformDescriptorRegistry {
    static let allPlatforms: [PlatformDescriptor] = [
        .init(
            id: "telegram",
            displayName: "Telegram",
            icon: "paperplane.fill",
            tokenVar: "TELEGRAM_BOT_TOKEN",
            setupInstructions: [
                "1. Open Telegram and message @BotFather",
                "2. Send /newbot and follow the prompts",
                "3. Copy the bot token BotFather gives you",
                "4. To find your user ID: message @userinfobot",
            ],
            fields: [
                .init(key: "TELEGRAM_BOT_TOKEN", label: "Bot token", isSecret: true, isAllowlist: false, helpText: "Paste the token from @BotFather.", defaultValue: nil),
                .init(key: "TELEGRAM_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated user IDs.", defaultValue: nil),
                .init(key: "TELEGRAM_HOME_CHANNEL", label: "Home channel ID", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "discord",
            displayName: "Discord",
            icon: "bubble.left.and.bubble.right.fill",
            tokenVar: "DISCORD_BOT_TOKEN",
            setupInstructions: [
                "1. Go to discord.com/developers/applications → New Application",
                "2. Go to Bot → Reset Token → copy the bot token",
                "3. Enable Message Content Intent",
                "4. Invite the bot to your server with required scopes",
                "5. Get your user ID with Developer Mode",
            ],
            fields: [
                .init(key: "DISCORD_BOT_TOKEN", label: "Bot token", isSecret: true, isAllowlist: false, helpText: "Paste the token from step 2.", defaultValue: nil),
                .init(key: "DISCORD_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated user IDs or usernames.", defaultValue: nil),
                .init(key: "DISCORD_HOME_CHANNEL", label: "Home channel ID", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "slack",
            displayName: "Slack",
            icon: "number",
            tokenVar: "SLACK_BOT_TOKEN",
            setupInstructions: [
                "1. Go to api.slack.com/apps → Create New App",
                "2. Enable Socket Mode and create an App-Level Token",
                "3. Add required Bot Token Scopes",
                "4. Subscribe to events: message.im, message.channels, app_mention",
                "5. Install to Workspace and copy the bot token",
            ],
            fields: [
                .init(key: "SLACK_BOT_TOKEN", label: "Bot Token (xoxb-...)", isSecret: true, isAllowlist: false, helpText: "Paste the bot token.", defaultValue: nil),
                .init(key: "SLACK_APP_TOKEN", label: "App Token (xapp-...)", isSecret: true, isAllowlist: false, helpText: "Paste the app-level token.", defaultValue: nil),
                .init(key: "SLACK_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated member IDs.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "matrix",
            displayName: "Matrix",
            icon: "grid",
            tokenVar: "MATRIX_ACCESS_TOKEN",
            setupInstructions: [
                "1. Works with any Matrix homeserver",
                "2. Get an access token from Element settings",
                "3. Or provide user ID + password for direct login",
                "4. For E2EE: set MATRIX_ENCRYPTION=true",
            ],
            fields: [
                .init(key: "MATRIX_HOMESERVER", label: "Homeserver URL", isSecret: false, isAllowlist: false, helpText: "e.g. https://matrix.example.org", defaultValue: nil),
                .init(key: "MATRIX_ACCESS_TOKEN", label: "Access token", isSecret: true, isAllowlist: false, helpText: "Leave empty to use password login.", defaultValue: nil),
                .init(key: "MATRIX_USER_ID", label: "User ID", isSecret: false, isAllowlist: false, helpText: "@bot:server", defaultValue: nil),
                .init(key: "MATRIX_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated Matrix user IDs.", defaultValue: nil),
                .init(key: "MATRIX_HOME_ROOM", label: "Home room ID", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .matrix
        ),
        .init(
            id: "mattermost",
            displayName: "Mattermost",
            icon: "message.fill",
            tokenVar: "MATTERMOST_TOKEN",
            setupInstructions: [
                "1. In Mattermost: Integrations → Bot Accounts → Add Bot Account",
                "2. Give it a username and copy the bot token",
                "3. Enter your self-hosted Mattermost server URL",
                "4. Find your user ID in Profile settings",
            ],
            fields: [
                .init(key: "MATTERMOST_URL", label: "Server URL", isSecret: false, isAllowlist: false, helpText: "e.g. https://mm.example.com", defaultValue: nil),
                .init(key: "MATTERMOST_TOKEN", label: "Bot token", isSecret: true, isAllowlist: false, helpText: "Paste the bot token.", defaultValue: nil),
                .init(key: "MATTERMOST_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "26-character Mattermost user IDs.", defaultValue: nil),
                .init(key: "MATTERMOST_HOME_CHANNEL", label: "Home channel ID", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
                .init(key: "MATTERMOST_REPLY_MODE", label: "Reply mode", isSecret: false, isAllowlist: false, helpText: "off or thread", defaultValue: "off"),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "whatsapp",
            displayName: "WhatsApp",
            icon: "phone.fill",
            tokenVar: "WHATSAPP_ENABLED",
            setupInstructions: [
                "1. Enable WhatsApp in settings",
                "2. Pair your phone by scanning the QR code on first run",
                "3. Session is stored locally after pairing",
            ],
            fields: [
                .init(key: "WHATSAPP_ENABLED", label: "Enabled", isSecret: false, isAllowlist: false, helpText: "Set to true to enable WhatsApp.", defaultValue: "false"),
            ],
            specialDiscovery: .whatsapp
        ),
        .init(
            id: "signal",
            displayName: "Signal",
            icon: "wave.3.forward",
            tokenVar: "SIGNAL_HTTP_URL",
            setupInstructions: [
                "1. Set up a Signal CLI REST API endpoint",
                "2. Provide the HTTP URL and your phone number/account",
            ],
            fields: [
                .init(key: "SIGNAL_HTTP_URL", label: "Signal HTTP URL", isSecret: false, isAllowlist: false, helpText: "Signal CLI REST API endpoint.", defaultValue: nil),
                .init(key: "SIGNAL_ACCOUNT", label: "Phone number / account", isSecret: false, isAllowlist: false, helpText: "Your Signal phone number.", defaultValue: nil),
            ],
            specialDiscovery: .signal
        ),
        .init(
            id: "email",
            displayName: "Email",
            icon: "envelope.fill",
            tokenVar: "EMAIL_ADDRESS",
            setupInstructions: [
                "1. Use a dedicated email account",
                "2. For Gmail: create an App Password",
                "3. IMAP must be enabled",
                "4. Default ports are IMAP 993 and SMTP 587; some providers may require SMTP 465",
            ],
            fields: [
                .init(key: "EMAIL_ADDRESS", label: "Email address", isSecret: false, isAllowlist: false, helpText: "e.g. hermes@gmail.com", defaultValue: nil),
                .init(key: "EMAIL_PASSWORD", label: "Email password / app password", isSecret: true, isAllowlist: false, helpText: "Use App Password for Gmail.", defaultValue: nil),
                .init(key: "EMAIL_IMAP_HOST", label: "IMAP host", isSecret: false, isAllowlist: false, helpText: "e.g. imap.gmail.com", defaultValue: nil),
                .init(key: "EMAIL_IMAP_PORT", label: "IMAP port", isSecret: false, isAllowlist: false, helpText: "Default 993 (IMAP SSL).", defaultValue: "993"),
                .init(key: "EMAIL_SMTP_HOST", label: "SMTP host", isSecret: false, isAllowlist: false, helpText: "e.g. smtp.gmail.com", defaultValue: nil),
                .init(key: "EMAIL_SMTP_PORT", label: "SMTP port", isSecret: false, isAllowlist: false, helpText: "Default 587 (STARTTLS). Try 465 if your provider expects SMTP SSL.", defaultValue: "587"),
                .init(key: "EMAIL_POLL_INTERVAL", label: "Poll interval (seconds)", isSecret: false, isAllowlist: false, helpText: "How often Hermes checks the inbox. Default 15.", defaultValue: "15"),
                .init(key: "EMAIL_ALLOWED_USERS", label: "Allowed sender emails", isSecret: false, isAllowlist: true, helpText: "Comma-separated email addresses.", defaultValue: nil),
                .init(key: "EMAIL_ALLOW_ALL_USERS", label: "Allow all senders", isSecret: false, isAllowlist: false, helpText: "true or false. Not recommended unless you trust the inbox.", defaultValue: "false"),
                .init(key: "EMAIL_HOME_ADDRESS", label: "Home address", isSecret: false, isAllowlist: false, helpText: "Default recipient for proactive delivery / cron.", defaultValue: nil),
                .init(key: "EMAIL_HOME_ADDRESS_NAME", label: "Home address label", isSecret: false, isAllowlist: false, helpText: "Display name for the home address target.", defaultValue: "Home"),
                .init(key: "platforms.email.skip_attachments", label: "Skip attachments", isSecret: false, isAllowlist: false, helpText: "true or false. Ignores inbound attachments before decoding.", defaultValue: "false"),
            ],
            specialDiscovery: .email
        ),
        .init(
            id: "dingtalk",
            displayName: "DingTalk",
            icon: "bell.fill",
            tokenVar: "DINGTALK_CLIENT_ID",
            setupInstructions: [
                "1. Go to open-dev.dingtalk.com → Create Application",
                "2. Copy AppKey and AppSecret",
                "3. Enable Stream Mode",
            ],
            fields: [
                .init(key: "DINGTALK_CLIENT_ID", label: "AppKey (Client ID)", isSecret: false, isAllowlist: false, helpText: "From DingTalk application credentials.", defaultValue: nil),
                .init(key: "DINGTALK_CLIENT_SECRET", label: "AppSecret", isSecret: true, isAllowlist: false, helpText: "From DingTalk application credentials.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "feishu",
            displayName: "Feishu / Lark",
            icon: "paperplane.circle.fill",
            tokenVar: "FEISHU_APP_ID",
            setupInstructions: [
                "1. Go to open.feishu.cn (or open.larksuite.com)",
                "2. Create an app and copy App ID and App Secret",
                "3. Enable the Bot capability",
                "4. Choose WebSocket or Webhook connection mode",
            ],
            fields: [
                .init(key: "FEISHU_APP_ID", label: "App ID", isSecret: false, isAllowlist: false, helpText: "From Feishu/Lark application.", defaultValue: nil),
                .init(key: "FEISHU_APP_SECRET", label: "App Secret", isSecret: true, isAllowlist: false, helpText: "From Feishu/Lark application.", defaultValue: nil),
                .init(key: "FEISHU_DOMAIN", label: "Domain", isSecret: false, isAllowlist: false, helpText: "feishu or lark", defaultValue: "feishu"),
                .init(key: "FEISHU_CONNECTION_MODE", label: "Connection mode", isSecret: false, isAllowlist: false, helpText: "websocket or webhook", defaultValue: "websocket"),
                .init(key: "FEISHU_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated user IDs.", defaultValue: nil),
                .init(key: "FEISHU_HOME_CHANNEL", label: "Home chat ID", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "wecom",
            displayName: "WeCom",
            icon: "building.2.fill",
            tokenVar: "WECOM_BOT_ID",
            setupInstructions: [
                "1. Go to WeCom Admin Console → Applications → Create AI Bot",
                "2. Copy Bot ID and Secret",
                "3. Add the bot to a group chat or message it directly",
            ],
            fields: [
                .init(key: "WECOM_BOT_ID", label: "Bot ID", isSecret: false, isAllowlist: false, helpText: "From your WeCom AI Bot.", defaultValue: nil),
                .init(key: "WECOM_SECRET", label: "Secret", isSecret: true, isAllowlist: false, helpText: "From your WeCom AI Bot.", defaultValue: nil),
                .init(key: "WECOM_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated user IDs.", defaultValue: nil),
                .init(key: "WECOM_HOME_CHANNEL", label: "Home chat ID", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "wecom_callback",
            displayName: "WeCom Callback",
            icon: "building.2.fill",
            tokenVar: "WECOM_CALLBACK_CORP_ID",
            setupInstructions: [
                "1. Go to WeCom Admin Console → Applications → Create Self-Built App",
                "2. Note Corp ID and create a Corp Secret",
                "3. Configure callback URL to point to your server",
                "4. Copy Token and EncodingAESKey",
            ],
            fields: [
                .init(key: "WECOM_CALLBACK_CORP_ID", label: "Corp ID", isSecret: false, isAllowlist: false, helpText: "Your WeCom enterprise Corp ID.", defaultValue: nil),
                .init(key: "WECOM_CALLBACK_CORP_SECRET", label: "Corp Secret", isSecret: true, isAllowlist: false, helpText: "Secret for your self-built app.", defaultValue: nil),
                .init(key: "WECOM_CALLBACK_AGENT_ID", label: "Agent ID", isSecret: false, isAllowlist: false, helpText: "Agent ID of your self-built app.", defaultValue: nil),
                .init(key: "WECOM_CALLBACK_TOKEN", label: "Callback Token", isSecret: true, isAllowlist: false, helpText: "From callback configuration.", defaultValue: nil),
                .init(key: "WECOM_CALLBACK_ENCODING_AES_KEY", label: "Encoding AES Key", isSecret: true, isAllowlist: false, helpText: "From callback configuration.", defaultValue: nil),
                .init(key: "WECOM_CALLBACK_PORT", label: "Callback server port", isSecret: false, isAllowlist: false, helpText: "Port for HTTP callback server.", defaultValue: "8645"),
                .init(key: "WECOM_CALLBACK_ALLOWED_USERS", label: "Allowed user IDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated user IDs.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "weixin",
            displayName: "Weixin / WeChat",
            icon: "message.circle.fill",
            tokenVar: "WEIXIN_ACCOUNT_ID",
            setupInstructions: [
                "1. Register an iLingAI bot account",
                "2. Copy Account ID and Token",
                "3. Configure base URL and CDN settings",
            ],
            fields: [
                .init(key: "WEIXIN_ACCOUNT_ID", label: "Account ID", isSecret: false, isAllowlist: false, helpText: "Your Weixin bot account ID.", defaultValue: nil),
                .init(key: "WEIXIN_TOKEN", label: "Token", isSecret: true, isAllowlist: false, helpText: "Your Weixin bot token.", defaultValue: nil),
                .init(key: "WEIXIN_BASE_URL", label: "Base URL", isSecret: false, isAllowlist: false, helpText: "iLingAI base URL.", defaultValue: nil),
                .init(key: "WEIXIN_CDN_BASE_URL", label: "CDN Base URL", isSecret: false, isAllowlist: false, helpText: "CDN endpoint.", defaultValue: nil),
                .init(key: "WEIXIN_DM_POLICY", label: "DM policy", isSecret: false, isAllowlist: false, helpText: "open or closed", defaultValue: "open"),
                .init(key: "WEIXIN_ALLOW_ALL_USERS", label: "Allow all users", isSecret: false, isAllowlist: false, helpText: "true or false", defaultValue: "true"),
                .init(key: "WEIXIN_ALLOWED_USERS", label: "Allowed users", isSecret: false, isAllowlist: true, helpText: "Comma-separated user IDs.", defaultValue: nil),
                .init(key: "WEIXIN_GROUP_POLICY", label: "Group policy", isSecret: false, isAllowlist: false, helpText: "disabled, allowlist, or open", defaultValue: "disabled"),
                .init(key: "WEIXIN_GROUP_ALLOWED_USERS", label: "Group allowed users", isSecret: false, isAllowlist: true, helpText: "Comma-separated user IDs.", defaultValue: nil),
                .init(key: "WEIXIN_HOME_CHANNEL", label: "Home channel", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .weixin
        ),
        .init(
            id: "bluebubbles",
            displayName: "BlueBubbles (iMessage)",
            icon: "bubble.fill",
            tokenVar: "BLUEBUBBLES_SERVER_URL",
            setupInstructions: [
                "1. Install BlueBubbles on a Mac server",
                "2. Note the Server URL and password from API settings",
                "3. Authorize users with DM pairing",
            ],
            fields: [
                .init(key: "BLUEBUBBLES_SERVER_URL", label: "Server URL", isSecret: false, isAllowlist: false, helpText: "e.g. http://192.168.1.10:1234", defaultValue: nil),
                .init(key: "BLUEBUBBLES_PASSWORD", label: "Server password", isSecret: true, isAllowlist: false, helpText: "From BlueBubbles API settings.", defaultValue: nil),
                .init(key: "BLUEBUBBLES_ALLOWED_USERS", label: "Allowed users", isSecret: false, isAllowlist: true, helpText: "Phone numbers or iMessage IDs.", defaultValue: nil),
                .init(key: "BLUEBUBBLES_HOME_CHANNEL", label: "Home channel", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "qqbot",
            displayName: "QQ Bot",
            icon: "message.circle",
            tokenVar: "QQ_APP_ID",
            setupInstructions: [
                "1. Register a QQ Bot at q.qq.com",
                "2. Note App ID and App Secret",
                "3. Enable required intents",
            ],
            fields: [
                .init(key: "QQ_APP_ID", label: "QQ Bot App ID", isSecret: false, isAllowlist: false, helpText: "From q.qq.com.", defaultValue: nil),
                .init(key: "QQ_CLIENT_SECRET", label: "QQ Bot App Secret", isSecret: true, isAllowlist: false, helpText: "From q.qq.com.", defaultValue: nil),
                .init(key: "QQ_ALLOWED_USERS", label: "Allowed user OpenIDs", isSecret: false, isAllowlist: true, helpText: "Comma-separated OpenIDs.", defaultValue: nil),
                .init(key: "QQ_HOME_CHANNEL", label: "Home channel", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
        .init(
            id: "sms",
            displayName: "SMS (Twilio)",
            icon: "message.circle.fill",
            tokenVar: "TWILIO_ACCOUNT_SID",
            setupInstructions: [
                "1. Create a Twilio account",
                "2. Get Account SID and Auth Token",
                "3. Configure a phone number and webhook URL",
            ],
            fields: [
                .init(key: "TWILIO_ACCOUNT_SID", label: "Account SID", isSecret: false, isAllowlist: false, helpText: "From Twilio Console.", defaultValue: nil),
                .init(key: "TWILIO_AUTH_TOKEN", label: "Auth Token", isSecret: true, isAllowlist: false, helpText: "From Twilio Console.", defaultValue: nil),
                .init(key: "TWILIO_PHONE_NUMBER", label: "Phone number", isSecret: false, isAllowlist: false, helpText: "E.164 format, e.g. +15551234567", defaultValue: nil),
                .init(key: "SMS_ALLOWED_USERS", label: "Allowed phone numbers", isSecret: false, isAllowlist: true, helpText: "E.164 format, comma-separated.", defaultValue: nil),
                .init(key: "SMS_HOME_CHANNEL", label: "Home channel", isSecret: false, isAllowlist: false, helpText: "For cron/notifications.", defaultValue: nil),
            ],
            specialDiscovery: .default
        ),
    ]

    static func descriptor(for id: String) -> PlatformDescriptor? {
        allPlatforms.first { $0.id == id }
    }

    static func discoverInstances(envValues: [String: String], configValues: [String: String]) -> [PlatformInstance] {
        var instances: [PlatformInstance] = []

        for platform in allPlatforms {
            let resolvedValues = resolvedFieldValues(for: platform, envValues: envValues, configValues: configValues)
            let isConfigured = isConfigured(platform, values: resolvedValues)
            let hasSavedInput = hasSavedInput(for: platform, envValues: envValues, configValues: configValues)

            if isConfigured || hasSavedInput {
                instances.append(PlatformInstance(
                    id: platform.id,
                    platformID: platform.id,
                    displayName: platform.displayName,
                    isEnabled: isConfigured,
                    configs: resolvedValues
                ))
            }
        }

        return instances
    }

    private static func resolvedFieldValues(
        for platform: PlatformDescriptor,
        envValues: [String: String],
        configValues: [String: String]
    ) -> [String: String] {
        var configs: [String: String] = [:]
        for field in platform.fields {
            configs[field.key] = envValues[field.key] ?? configValues[field.key] ?? field.defaultValue ?? ""
        }
        return configs
    }

    private static func hasSavedInput(
        for platform: PlatformDescriptor,
        envValues: [String: String],
        configValues: [String: String]
    ) -> Bool {
        platform.fields.contains { field in
            guard let rawValue = envValues[field.key] ?? configValues[field.key] else { return false }
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return false }

            if let defaultValue = field.defaultValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               value == defaultValue {
                return false
            }

            return true
        }
    }

    private static func isConfigured(_ platform: PlatformDescriptor, values: [String: String]) -> Bool {
        func nonEmpty(_ key: String) -> Bool {
            guard let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !value.isEmpty
        }

        switch platform.specialDiscovery {
        case .whatsapp:
            return values[platform.tokenVar]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        case .signal:
            return nonEmpty(platform.tokenVar) || nonEmpty("SIGNAL_ACCOUNT")
        case .email:
            return ["EMAIL_ADDRESS", "EMAIL_PASSWORD", "EMAIL_IMAP_HOST", "EMAIL_SMTP_HOST"].allSatisfy(nonEmpty)
        case .matrix:
            return nonEmpty("MATRIX_HOMESERVER") && (nonEmpty("MATRIX_ACCESS_TOKEN") || nonEmpty("MATRIX_PASSWORD"))
        case .weixin:
            return nonEmpty("WEIXIN_ACCOUNT_ID") && nonEmpty("WEIXIN_TOKEN")
        default:
            return nonEmpty(platform.tokenVar)
        }
    }
}

struct PlatformInstance: Identifiable, Equatable {
    let id: String
    let platformID: String
    var displayName: String
    var isEnabled: Bool
    var configs: [String: String]
}
