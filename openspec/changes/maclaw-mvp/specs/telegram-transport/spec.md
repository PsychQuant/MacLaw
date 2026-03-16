## ADDED Requirements

### Requirement: Long-polling with automatic reconnection

The system SHALL poll Telegram's `getUpdates` endpoint using URLSession. When the network path changes (detected via NWPathMonitor), the system SHALL cancel the current request and immediately start a new polling cycle. The system SHALL NOT rely on a timeout-based watchdog for reconnection.

#### Scenario: Normal message reception

- **WHEN** a user sends a message to the Telegram bot
- **THEN** the system receives it via getUpdates and routes it to the agent runtime

#### Scenario: Network path change (sleep/wake)

- **WHEN** NWPathMonitor reports a path change (e.g., wake from sleep)
- **THEN** the system cancels the current getUpdates request and starts a new polling cycle within 2 seconds

#### Scenario: Temporary network outage

- **WHEN** the network is unreachable
- **THEN** the system retries with exponential backoff (2s, 4s, 8s, max 30s) until connectivity is restored

### Requirement: Send messages

The system SHALL support sending text messages to Telegram chats (DM and group) via the `sendMessage` API. Messages exceeding 4096 characters SHALL be split into multiple messages.

#### Scenario: Send reply to user

- **WHEN** the agent produces a response
- **THEN** the system sends it as a Telegram message to the originating chat

#### Scenario: Long message splitting

- **WHEN** the response exceeds 4096 characters
- **THEN** the system splits at the last newline before the limit and sends multiple messages in order
