# RWR-Unraid Automation Rules

## Environment classification

**DISPOSABLE DEVELOPMENT / TEST MACHINE**

The automated test machine is not production-critical. Temporary service outages, container recreation, package installation, test-data changes, and machine restarts are acceptable when they are required to develop or validate RWR-Unraid.

The permanent source of truth remains GitHub. Secrets must never be committed to this repository.

## Authorized automation

The test-machine agent may, without human confirmation:

- pull branches from this repository;
- modify the local development checkout;
- build Docker images;
- create, start, stop, restart, and remove RWR development containers;
- run repository tests and validation helpers;
- inspect Docker state, logs, networking, mounts, and process state;
- modify test-only RWR server data;
- create local backups/checkpoints before risky changes;
- install packages required for development or validation;
- reboot the disposable test machine when necessary;
- retry a failed task up to the configured retry budget;
- commit machine-generated result files to the task branch.

## Hard limits

Automation must stop and report a blocker when:

- Steam Guard, MFA, CAPTCHA, or another interactive authentication step is required;
- credentials are required but unavailable locally;
- physical hardware interaction is required;
- the requested operation would affect a system outside the disposable test environment;
- the task goal or destructive scope is materially ambiguous;
- the retry budget is exhausted.

## Secrets

Never commit or print:

- `STEAM_PASS`;
- GitHub tokens or private keys;
- cookies/session tokens;
- registry credentials;
- unrelated host secrets.

Local secrets should live outside the repository, for example under `/etc/rwr-agent/secrets/` or another root-only path.

## Verification rule

**Remove human confirmation, not verification.**

A command exiting with code 0 is not enough. Every task should define observable acceptance criteria and the agent should capture the evidence needed to evaluate them.

## Retry budget

Default autonomous repair attempts per task: **5**.

After the budget is exhausted, preserve the failed state when useful, capture logs and machine state, and report the blocker rather than continuing indefinitely.
