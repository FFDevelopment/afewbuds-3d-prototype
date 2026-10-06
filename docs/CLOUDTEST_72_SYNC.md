# Cloud-test .72 compatibility pass — prototype 0.9.5

Source: `FFDevelopment/afewbuds-cloud-test` at `fb96e6637cc368ec6146ed7333197982120a4774` (cloudtest.72).
Previous simulation import: `.64`, `9a9c8015df45b4b527fe20238a59bd6cebee5d6e`.
Prototype base: 0.9.4, `dbef0f37d7a3c9567d0d2e100682f54694960759`.

Reviewed the complete .64-to-.72 commit/file comparison, main-script changes, runtime builder, browser recovery form, shared API client and password-reset endpoint source. The intervening main-script changes affect front-door geometry, walking/view delegation and door labels. No new economy, upgrades, progression or save-schema changes were present in this comparison.

| Upstream change | Prototype handling |
| --- | --- |
| .65–.68 neighborhood textures, roads, building layout, door movement | Keep the prototype's later map, continuous sidewalks, door collision and interiors. Do not overwrite with web neighborhood code. |
| .67 mobile analog control | Web/mobile-specific; keep native WASD/mouse controls. |
| .69 free indoor movement and nearby station approach | Already supplied by prototype player physics and E interaction raycasts. Keep existing physical collisions and workstation behavior. |
| .70 wider web view, rotation-responsive web phone and splash | Keep approved desktop camera height/FOV and portrait phone. Adapt account page to short desktop windows with vertical scrolling. |
| .71–.72 password recovery | Add native Forgot Password screen; username or saved email up to 254 characters, trimming, shared-email guidance, and explicit email-service errors. |
| Recovery return URL | Send the established cloud-test web reset-page URL so emailed links can complete in the browser. Then sign back into the desktop app. |
| Existing account profile/email opt-in | Keep existing profile RPCs; explicitly support 254-character emails in registration/profile and explain recovery use. |
| SQL patch and Brevo server configuration | Do not apply/deploy/copy credentials. Use the existing public recovery endpoint. |

## Native recovery contract

POST `/functions/v1/afb-password-reset`, with the public `apikey` header and JSON `{username, return_url}`. No account session, administrator credential or Brevo key is embedded. Recovery never creates/accepts a login session or modifies the career. All successful requests show the same generic account-existence message. Sending is serialized in the form and controls recover after errors. The server owns delivery, token expiry, one-time use, lookup and rate limiting.

## Verification

`tools/test.py` passes the existing movement/interior/gameplay, isolated save/account, and HTTP suites. Added local HTTP fixtures exercise usernames, >20-character emails, 254-character boundary, whitespace trimming, unknown accounts, unconfigured delivery, send failure, unavailable service, invalid responses and native UI mode transitions. Browser reset completion remains the existing cloud-test implementation.

No live email was sent as part of validation. Live delivery still depends on the shared service's existing Brevo configuration. No database, Edge Function, beta or cloud-test mutation was performed. Only the prototype integration branch is updated.
