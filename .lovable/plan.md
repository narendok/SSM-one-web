# Keep the Lovable Git page connected

## Goal
Help keep the project’s Lovable Git connection available without repeatedly signing in through the Git page, using GitHub’s remembered authorization for as long as it remains valid.

## Plan
1. Inspect the Git settings status in Lovable to determine whether the project has an active repository connection or an expired/removed authorization.
2. If no connection is active, open the supported Git connection flow so you can authorize GitHub once and select the appropriate account or organization.
3. Verify that the connection remains visible after the authorization flow completes. If GitHub later expires or revokes its authorization, use the same reconnect flow rather than repeatedly starting from scratch.

## Important limitation
- GitHub controls sign-in persistence, including expiration caused by browser privacy settings, device policy, two-factor authentication, or organization security rules.
- I cannot store, retain, or reuse your GitHub password, session, or personal authorization outside GitHub’s approved connection flow. GitHub and your organization determine any expiration period.
- If the project has no existing connection, Lovable’s Git sync creates a new private repository; it does not attach an existing repository.
