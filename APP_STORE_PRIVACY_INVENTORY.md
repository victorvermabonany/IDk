# Weektable beta privacy data inventory

Operational inventory for App Store Connect privacy answers. It must be rechecked whenever analytics, authentication, payments, grocery providers, or support tooling changes.

| Data | Purpose | Linked to identity | Tracking | Retention |
| --- | --- | --- | --- | --- |
| ZIP code and selected estimated catalog | App functionality: locating the chosen planning catalog | No account; associated with an anonymous plan | No | Server plan retention, up to 14 days |
| Budget, household, dinner count, leftovers | App functionality: plan and package calculations | No account; associated with an anonymous plan | No | Up to 14 days server-side; local draft until app data is removed |
| Dietary restrictions, allergies, dislikes, cuisines, pantry, custom instructions | App functionality and safety constraint validation | No account; associated with an anonymous plan | No | Up to 14 days server-side; local draft until app data is removed |
| Generated plan, grocery ownership and checkoffs, swap state | App functionality and state recovery | No account; associated with an anonymous plan | No | Up to 14 days server-side; latest state cached locally |
| Random app-install identifier | Security, abuse prevention, rate limiting | Not linked to a named account | No | Stored locally; server receives a one-way hash for rate limiting |
| Operational event category, latency, safe error category | Diagnostics and service reliability | No | No | Hosting/log retention must be configured and documented before public launch |
| Support email and message | Customer support | Yes, by submitted email | No | Up to 30 days |

OpenAI receives constrained recipe-planning inputs when live planning is enabled. Complete payloads containing allergy, ZIP-code, preference, or custom-instruction values must not be written to Weektable structured logs. Weektable does not use beta data for advertising and does not sell it.
