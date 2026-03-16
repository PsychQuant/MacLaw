## ADDED Requirements

### Requirement: OpenAI-compatible API client

The system SHALL send chat completion requests to any OpenAI-compatible API endpoint. The request SHALL include model, messages array, and optional parameters (temperature, max_tokens, reasoning_effort). The system SHALL parse the response and extract the assistant message content.

#### Scenario: Cloud API call (gpt-5.4)

- **WHEN** a user message is received and the primary model is configured
- **THEN** the system sends a chat completion request to the primary endpoint and returns the assistant response

#### Scenario: Local model fallback (Paw on Kyle)

- **WHEN** the primary model endpoint is unreachable
- **THEN** the system falls back to the configured fallback endpoint

### Requirement: Model routing

The system SHALL support a primary and fallback model configuration. If the primary model returns an error or times out (30s connect, 120s response), the system SHALL automatically try the fallback model.

#### Scenario: Primary timeout, fallback succeeds

- **WHEN** the primary model does not respond within the timeout
- **THEN** the system tries the fallback model and returns its response

#### Scenario: Both models fail

- **WHEN** both primary and fallback models fail
- **THEN** the system sends an error message to the user via Telegram indicating the service is temporarily unavailable
