# Privacy policy and account-deletion pages (DRAFT)

Two self-contained static pages, each in English and Arabic (Arabic is right-to-left):
- `terms.html` (draft terms of use, English and Arabic)
- `privacy-policy.html`
- `delete-account.html`

**They are drafts for legal review.** They describe what the app actually stores (see `docs/privacy-data-map.md`) and cover the
Saudi PDPL, the Google Play Families Policy and the Apple Kids Category. Every `[bracketed]` item (highlighted in yellow) is
something only the owner/lawyer can fill in: controller name and address, contact email, effective date, hosting provider and
region, backup retention, deletion time frame, target markets.

Rules (enforced by `tests/KidsEnglish.Application.Tests/SitePagesTests.cs`): no scripts, no external stylesheets/fonts/images,
no URLs, no trackers; only the system fonts already on the reader's device.

To publish: host the two files on any static host over HTTPS and paste their URLs into the store listings (privacy policy URL and
the Play "delete account" web link). Remove the DRAFT banners only after the lawyer has approved the text. Keep the pages in
sync with `docs/privacy-data-map.md` whenever the app's data practices change.
