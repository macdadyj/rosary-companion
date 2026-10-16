# TestFlight

The upload workflow is `.github/workflows/ios.yml`. It is the Watch Remote pipeline, pointed at this app: unit tests and UI tests run first, and a push to `main` archives with build number `GITHUB_RUN_NUMBER + 100`. A re-run of the same run uses `number.attempt`, so App Store Connect does not reject it. Settings shows that build number (`CFBundleVersion`).

GitHub Actions on this account currently refuses jobs because of billing. The workflow is ready. Do not re-run it in a loop. After the spending limit is raised, one push to `main` on the GitHub mirror is enough.

Origin does not provide the `macos-26` runner this workflow needs, so the runner is GitHub Actions on a private mirror, `macdadyj/rosary-companion`.

## Bundle ids

Use these exact ids. The free-account `XTL-` prefix cannot be registered for App Store Connect.

| Target | Bundle id |
| --- | --- |
| iPhone app | `com.lojo.Rosary` |
| Widget and Live Activity | `com.lojo.Rosary.widget` |
| Apple Watch | `com.lojo.Rosary.watchkitapp` |

## What to click

### Apple Developer

1. Open [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) on the paid team.
2. Register an explicit App ID `com.lojo.Rosary`.
3. Register an explicit App ID `com.lojo.Rosary.widget`.
4. Register an explicit App ID `com.lojo.Rosary.watchkitapp`.
5. No App Group is required. The widget shows the day’s mysteries from the date alone. The Live Activity is started by the app.

### App Store Connect

1. Open [Apps](https://appstoreconnect.apple.com/apps) and choose the plus button, then **New App**.
2. Platform: **iOS**. Name: **Rosary** (if that name is taken, `Rosary Companion` is fine; the bundle id is what the upload matches).
3. Primary language: English.
4. Bundle ID: **com.lojo.Rosary**. It appears in the menu only after the App ID exists. If you still see an `XTL-` id, that is the free-account id and it will not work here.
5. SKU: `rosary-companion`.
6. Create the app.
7. The API key already used for Watch Remote can upload this app if it belongs to the same team and its role is App Manager or Admin. The workflow looks up the app by `com.lojo.Rosary` and adds the build to the internal TestFlight group, creating that group if the app has none. Internal testers are App Store Connect users. Add yourself under **Users and Access** if you are not already a user, then accept the TestFlight invite on your phone. You do not have to tap through the app yourself; the UI tests do that.

### GitHub secrets

On `macdadyj/rosary-companion`, open **Settings → Secrets and variables → Actions** and add the same four secrets as Watch Remote. This agent cannot copy secret values.

| Secret | What it is |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect API key id |
| `ASC_ISSUER_ID` | Issuer id |
| `ASC_KEY_P8` | The `.p8` file, as PEM or base64 |
| `DEVELOPMENT_TEAM` | `N9H4648NB9`, with no `XTL-` prefix |

### Billing

Open GitHub **Settings → Billing and plans** and raise the Actions spending limit. Until that is done, every workflow on the account is refused.

## What the workflow runs

1. `swift test` (the Linux-tested core, including text and painting hashes).
2. `scripts/archive-upload.sh --self-test` (key decoding and build-number math, no secrets printed).
3. Phone UI tests that open every tab and tap the prayer, devotion, intention, saint, and settings controls.
4. Watch UI tests that tap Bead, Back, and Reset.
5. On a push to `main` only, after those jobs are green: archive `com.lojo.Rosary` with the widget and the watch app embedded, and upload it.

Pull requests run the tests and do not upload.
