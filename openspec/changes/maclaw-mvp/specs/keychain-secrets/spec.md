## ADDED Requirements

### Requirement: Store secrets in Keychain

The system SHALL store all sensitive values (bot tokens, API keys) in macOS Keychain Services under the service name "maclaw". Secrets SHALL be identified by a key name (e.g., "telegram-bot-token"). The system SHALL NOT write secrets to any file on disk.

#### Scenario: Store a new secret

- **WHEN** the user runs `maclaw secrets set telegram-bot-token`
- **THEN** the system prompts for the value via secure input (no echo) and stores it in Keychain

#### Scenario: Retrieve a secret programmatically

- **WHEN** the gateway needs the Telegram bot token at startup
- **THEN** the system retrieves it from Keychain via `SecItemCopyMatching` without logging the value

### Requirement: Config file with Keychain references

The system SHALL use `@keychain:<key-name>` syntax in `~/.maclaw/maclaw.json` to reference Keychain-stored secrets. The config parser SHALL resolve these references at runtime.

#### Scenario: Config references Keychain

- **WHEN** the config contains `"botToken": "@keychain:telegram-bot-token"`
- **THEN** the system resolves it to the actual value from Keychain at runtime, never writing the resolved value to disk or logs

### Requirement: Secrets management CLI

The system SHALL provide `maclaw secrets set <key>`, `maclaw secrets delete <key>`, and `maclaw secrets list` commands.

#### Scenario: List stored keys

- **WHEN** the user runs `maclaw secrets list`
- **THEN** the system outputs key names only, never values
