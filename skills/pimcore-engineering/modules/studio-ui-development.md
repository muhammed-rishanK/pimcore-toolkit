# Studio UI development

## Purpose and scope
Building frontend extensions for Pimcore Studio, the React based admin UI that replaces the Classic UI (ExtJS) from Pimcore platform 2026.1. Covers where a plugin lives, the npm and build setup, how the build is registered on the PHP side, and how to work without inventing JavaScript APIs.

**Use when:** the project runs Pimcore Studio (`pimcore/studio-ui-bundle` in `composer.lock`) and the task changes what editors see: a panel, tab, grid cell, button or widget.
**Do not use when:** the project runs the Classic UI (use `admin-ui-development.md`), or the rule must hold for imports and APIs (enforce it in PHP, see `studio-backend-extension.md` and `backend-development.md`).

## Inspect the project first
- Studio packages in `composer.lock`: `pimcore/studio-ui-bundle`, `pimcore/studio-backend-bundle`, and their versions. Studio UI is versioned with the platform (for example 2026.3.x) and requires a matching platform version in its `require` block.
- Whether the project already has a Studio plugin: a bundle or `assets/` folder with `package.json`, `rsbuild.config.ts`, `js/src/index.ts`, `js/src/plugins.ts`, `main.ts`.
- Services tagged `pimcore_studio_ui.webpack_entry_point_provider` (`grep -rn "webpack_entry_point_provider" src bundles config`).
- The React version Studio uses: the plugin must match it (the docs show `react@18.3.x`).
- Existing Classic UI JS in the project: each file is a candidate to port (see `platform-2026-upgrade.md`).

## Workflow
1. **Decide the layer.** Presentation and editor interaction go in a Studio UI plugin. Data shaping, validation and permissions go in PHP (`studio-backend-extension.md`).
2. **Where to host it.** In a Pimcore bundle (reusable across installs) or directly in the app. Both are documented.
3. **Start from the official example.** The docs link the example bundle `pimcore/studio-example-bundle` and a "Getting started with your first plugin" page. Copy the structure from there rather than from memory.
4. **Set up the package.** In the assets folder: `npm install @pimcore/studio-ui-bundle react@18.3.x react-dom@18.3.x`. Rsbuild is the recommended bundler (`@rsbuild/core`, `@rsbuild/plugin-react`, `@module-federation/rsbuild-plugin` as dev dependencies; the Pimcore plugin `pluginGenerateEntrypoints` from `@pimcore/studio-ui-bundle/rsbuild/plugins` writes the `entrypoints.json` manifest). Use the `@canary` tag only when the docs for your release say so.
5. **File layout** from the docs: `js/src/index.ts` (the plugin), `js/src/plugins.ts` (exports it), `js/src/main.ts` (Rsbuild entrypoint), plus `package.json` and `rsbuild.config.ts`. Output goes to `public/build/<build-id>/`; `assetPrefix` in `rsbuild.config.ts` must point to `/bundles/<bundlename>/build/<build-id>/`.
6. **Build commands** documented: `npm run build` (production), `npm run dev` (watch), `npm run dev-server` (live reload). The script bodies come from the example `package.json`; check yours.
7. **Register the build in PHP.** Implement `Pimcore\Bundle\StudioUiBundle\Webpack\WebpackEntryPointProviderInterface`:
   - `getEntryPointsJsonLocations()` returns the absolute paths of the `entrypoints.json` files, usually `glob(__DIR__ . '/../../public/build/*/entrypoints.json')`;
   - `getEntryPoints()` returns `['exposeRemote']` for a plugin bundle;
   - `getOptionalEntryPoints()` returns `[]` normally; a missing non-optional entry throws `InvalidEntryPointsJsonException`.
   Tag the service `pimcore_studio_ui.webpack_entry_point_provider`. Use `pimcore_studio_ui.webpack_entry_point_provider.document_editor_iframe` only for code that runs inside the document editor iframe.
8. **Install assets** (`bin/console assets:install public`), clear caches, rebuild the JS, hard reload the browser.
9. **Verify** that the plugin loads: put a `console.log()` in a plugin method, rebuild and look for it in the browser console. Then test the real behaviour as an admin and as a restricted role.

## The plugin API is read from the installed package
The JavaScript registration API (what `index.ts` calls to add a tab, a cell type or a widget) was not in the pages this toolkit was written from. Do not write it from memory. Read, in this order: the example bundle, `node_modules/@pimcore/studio-ui-bundle` (types and exports), the SDK overview page of the Studio docs. State which one you used. If you cannot find an API, say so and stop.

A custom grid cell type must match a backend `getFrontendType()` string: the Studio UI side is a `DynamicTypeGridCellAbstract` subclass whose `id` equals that string (see `studio-backend-extension.md`).

## Best practices
- Keep the UI plugin thin; call Studio Backend endpoints that check permissions.
- Pin React to the version Studio ships; a mismatch breaks the module federation remote.
- Commit `package-lock.json`. Decide whether `public/build` is committed or built in CI, and state it in the release notes.
- Translate labels through the Studio translation mechanism, not hard-coded text.

## Common mistakes
- Porting ExtJS code line by line. The Classic UI and Studio are different frameworks; port behaviour, not code.
- Forgetting the PHP entrypoint provider tag: the build exists but never loads.
- Wrong `assetPrefix`: the manifest loads and the chunks 404.
- Using a different React version than Studio.
- Enforcing a rule only in the browser.

## Version notes
- Studio is the only admin UI from 2026.1. In 2025.4 it runs beside the Classic UI and is outside the LTS promise.
- The docs read for this module were the 2026.3 pages. Check the page for your installed version; the 2026.x Extending page was not read in full.
- The registration API and npm publishing are not covered here: not found in the pages read.

## Example
Add a read-only "Locked by integration" banner to the Product editor:
- PHP: a Studio Backend PreResponse subscriber adds a custom attribute when the lock flag is set (`studio-backend-extension.md`).
- UI plugin: read that attribute and render the banner, using the API found in the example bundle.
- PHP guard: a `PRE_UPDATE` subscriber rejects changes to locked fields. The banner is a convenience; the guard is the rule.

## Validation checklist
- [ ] Studio packages and versions read from `composer.lock`.
- [ ] Plugin API taken from the example bundle or the installed package, with the source named.
- [ ] Entry point provider tagged and `entrypoints.json` found.
- [ ] `assets:install`, build and cache clear done; plugin visible in the browser.
- [ ] Rules enforced in PHP, not only in the UI.
- [ ] Checked as admin and as a restricted role, browser console clean.

## Expected output
Files changed, where the plugin is hosted, the build and registration steps, the commands run with results, the manual UI checks with results, and which APIs could not be verified.
