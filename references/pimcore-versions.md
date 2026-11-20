# Pimcore version lines

One page that every agent and command reads when a decision depends on the Pimcore line. It records what the official documentation says and where it says it. Anything not stated there is marked "not stated". Never fill a gap from memory: read `composer.lock` of the project, `composer show -a pimcore/pimcore`, or the page named in the Sources list.

Checked against the official docs on 2026-11-20 (docs.pimcore.com showed 2026.3 as the latest release).

## 1. How the lines are named
- Pimcore 10 and 11 are numbered releases. 12.x is the last numbered line.
- From 2026.1 all Pimcore repositories use one platform version scheme: `YYYY.N.patch` (the release notes give `2026.1.1` as a bug fix, `2026.2.0` as a minor and `2027.1.0` as the next yearly major). The release notes say there will be no `2.*` or `3.*` releases in between for bundles such as Data Hub.
- The official upgrade page is titled "Version 12 to Version 2026". How the 12.x and 2025.x release tags map onto each other is not stated on the pages read. Take the real version from `composer.lock`; never infer it from a marketing name.

## 2. Support matrix
| Line | PHP | Symfony | Admin UI | Support | Source |
|---|---|---|---|---|---|
| 10.x | 8.0 to 8.1 | 5.4 | core admin | not covered by the pages read; check the docs support page | landmarks in `pimcore-engineering` skill, verify in `vendor/` |
| 11.x | 8.1 to 8.3 (Packagist, `pimcore/pimcore` 11.5) | 6.2+ (6.4 in later 11.x) | `pimcore/admin-ui-classic-bundle` | check the release page for the exact end date | Packagist, verify in `vendor/` |
| 12.x | read `composer.lock` | read `composer.lock` | Classic UI | not stated on the pages read | upgrade page "Version 12 to Version 2026" |
| 2025.4 (LTS) | not stated in the 2025.4 blog; read the system requirements page | Symfony 7 supported alongside 6.4 | Classic UI and Studio side by side; the final release with Classic UI | LTS: three years from the release date (the blog is dated 2025-12-09; the docs sidebar says "until Dec 2028"). LTS covers platform functionality, not Studio. | 2025.4 release blog, docs sidebar |
| 2026.x | 8.4 or 8.5 (8.3 removed) | 7.x only (the upgrade page says 7.3 or higher) | Studio only; Classic UI fully removed | LTS status not stated; end of support not stated | 2026.1 release notes, 12 to 2026 upgrade page |

Observation, not an announcement: 2024.4 and 2025.4 are both labelled LTS in the docs sidebar (2024.4 until Dec 2026). Do not tell a user that a later release will be LTS; say it is not stated.

## 3. Licence and product key
Neither the 2025.4 blog nor the 2026.1 release notes describe a licence model change or a product key. Do not state one as fact. Read the licence of the exact version (`composer show pimcore/pimcore`, the licence page of the docs) and read `pimcore-install --help` for the installer. The environment safety rules still apply: never register an account for the user and never pass a skip flag.

## 4. Pimcore Studio
- 2025.4: Studio is not part of the platform release and not part of the LTS promise, but it is compatible and can run alongside the Classic UI. 2025.4 receives Studio-compatibility fixes until 2026.1 and then three more months (per the blog).
- 2026.1: "Pimcore Studio is now the only supported administration interface." All ExtJS files, classic admin controllers, `PimcoreBundleAdminClassicInterface` implementations, `BundleAdminClassicTrait` and `AdminSubscriber` with the legacy admin listeners and ACL integrations are removed.
- Packages: frontend `pimcore/studio-ui-bundle`, backend `pimcore/studio-backend-bundle`. Check the installed versions and their `require` blocks in `composer.lock`.
- `pimcore/admin-ui-classic-bundle` is end of life and will not be ported to Studio.

## 5. Decision table
| Situation | Use |
|---|---|
| Project on 10.x | Plan 10 to 11 first (`upgrade-migration.md`), never straight to 2026 |
| Project on 11.x | Plan 11 to 12 or 2025.4, then 2026 (`upgrade-migration.md`, `platform-2026-upgrade.md`) |
| Project on 12.x or 2025.x | `platform-2026-upgrade.md` |
| Project on 2025.4, wants a long support window and keeps Classic UI customisations | Stay on 2025.4 LTS; customisations stay on Classic UI; plan the Studio rewrite before the LTS window ends |
| Project on 2026.x | Studio only: `studio-ui-development.md`, `studio-backend-extension.md` |
| New install, no key problem | Newest line the environment can run; Pimcore 11 is the fallback when a newer line needs a product key |

The jump 10 to 12 in one step is reported as unsupported by a community guide (not verified against the official docs). Treat it as one phase per major.

## 6. Sources
- Release 2026.1: https://docs.pimcore.com/platform/Pimcore_Platform/Updating_Pimcore/Release_Notes/03_2026.1/
- Platform release 2025.4 blog: https://pimcore.com/en/resources/blog/platform-release-2025.4
- Version 12 to Version 2026: https://docs.pimcore.com/platform/2025.4/Pimcore/Installation_and_Upgrade/Updating_Pimcore/V12_to_V2026/
- Upgrade notes: https://docs.pimcore.com/platform/Pimcore/Upgrade_Notes/
- Studio UI: https://docs.pimcore.com/platform/Studio_UI
- Studio Backend: https://docs.pimcore.com/platform/Studio_Backend/Extending/
