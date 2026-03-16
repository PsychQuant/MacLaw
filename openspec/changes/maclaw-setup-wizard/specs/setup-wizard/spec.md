## ADDED Requirements

### Requirement: Prerequisite validation

The system SHALL check that `codex` CLI is installed and authenticated before proceeding. If running via SSH, the system SHALL warn that Keychain access may fail and suggest running locally.

#### Scenario: Codex installed and authenticated

- **WHEN** the user runs `maclaw setup` and codex is installed and logged in
- **THEN** the system prints a checkmark and proceeds to the next step

#### Scenario: Codex not installed

- **WHEN** `codex` is not found in PATH
- **THEN** the system prints an error with install instructions (`npm i -g @openai/codex`) and exits

#### Scenario: Running via SSH

- **WHEN** the SSH_CONNECTION or SSH_TTY environment variable is set
- **THEN** the system warns that Keychain may not work and recommends running from a local Terminal

### Requirement: Telegram bot token setup

The system SHALL prompt for a Telegram bot token via secure input (no echo) and store it in Keychain under key `telegram-bot-token`.

#### Scenario: Token entered successfully

- **WHEN** the user enters a valid bot token
- **THEN** the system stores it in Keychain and prints confirmation

#### Scenario: Token already exists

- **WHEN** a token is already stored in Keychain
- **THEN** the system asks whether to overwrite or keep the existing token

### Requirement: Config generation

The system SHALL generate `~/.maclaw/maclaw.json` with the Telegram bot token referencing Keychain (`@keychain:telegram-bot-token`).

#### Scenario: Config created

- **WHEN** prerequisites are met and token is stored
- **THEN** the system writes a valid JSON config and prints the path

### Requirement: Optional daemon installation

The system SHALL ask whether to install the launchd daemon. If yes, it SHALL call the existing `DaemonInstall` logic.

#### Scenario: User wants daemon

- **WHEN** the user answers yes to "Install launchd daemon?"
- **THEN** the system installs and starts the daemon

#### Scenario: User skips daemon

- **WHEN** the user answers no
- **THEN** the system skips daemon installation and prints how to start manually (`maclaw gateway run`)
