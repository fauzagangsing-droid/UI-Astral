# Manual Studio component and window tests

Both `Components.spec.lua` and `Window.spec.lua` are opt-in **ModuleScripts** returning `function(libraryOverride)`. Requiring a spec does not execute it. Calling the returned function runs isolated client fixtures, prints `UILibrary Components: N tests passed` or `UILibrary Window: N tests passed`, and returns that count. A failed case raises its name and traceback after `xpcall` fixture cleanup. The runners do not require each other or a test framework.

Tests are **not auto-run or mapped by default**. Do not add them to the production mapping, rename them to `.client.lua`, or require them from `Main`. The existing `default.project.json` maps the source library and client shell, not these specs. No executor API, privileged simulated input, or external runtime dependency is used.

## Manual import and client invocation

1. Install one of these library forms:
   - **Source default:** sync the existing `default.project.json` with Rojo. The required source hierarchy is `ReplicatedStorage.UILibrary` (ModuleScript from `src/shared/UILibrary/init.lua`), with `Theme` and `Helpers` ModuleScripts; a `Core` Folder containing the `Window` ModuleScript; and a `Components` ModuleScript from `Components/init.lua` containing all 15 leaf ModuleScripts. If importing by hand, preserve these names/classes and use the corresponding source files. Do not use the archived root `ui.lua`.
   - **Bundle:** install the generated standalone bundle as a ModuleScript named **`ReplicatedStorage.AstralLite`**. Inject its required library table using the commands below. With an override supplied, neither spec waits for or requires `ReplicatedStorage.UILibrary`, nor does either depend on source-tree ModuleScripts. The argument is the result of `require`, not the ModuleScript Instance.
2. In Studio Explorer, insert **two ModuleScripts** directly under `ReplicatedStorage`, named exactly **`Components.spec`** and **`Window.spec`** (without `.lua`). Replace each source with the complete contents of its matching file in `tests/`. This manual test-only import does not modify project mapping.
3. Press **Play**, not server-only Run. Wait for the local player. Open **View → Command Bar**, choose the **Client** execution context, and open Output. Both runners assert Studio and client execution.
4. Execute the desired spec **sequentially** in the client Command Bar.

   Source default, with no override:

   ```lua
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local componentsPassed = require(ReplicatedStorage:WaitForChild("Components.spec"))()
   local windowsPassed = require(ReplicatedStorage:WaitForChild("Window.spec"))()
   print("Returned test counts:", componentsPassed, windowsPassed)
   ```

   Installed bundle, running the same suites with an injected library:

   ```lua
   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local componentsPassed = require(ReplicatedStorage:WaitForChild("Components.spec"))(require(ReplicatedStorage.AstralLite))
   local windowsPassed = require(ReplicatedStorage:WaitForChild("Window.spec"))(require(ReplicatedStorage.AstralLite))
   print("Returned bundled test counts:", componentsPassed, windowsPassed)
   ```

   Each runner can also be invoked individually. Do not omit the final function call: `require(spec)` alone only loads the runner. Allow it to yield for layout/render frames, property signals, destruction, and notification deadlines. Inspect Output for the success line or first named failure, and for asynchronous errors. Do not run the suites concurrently.
5. Stop Play when finished. Remove the manually imported spec ModuleScripts before publishing if they were inserted in edit mode. After editing a library or spec, stop/restart Play and update its imported source; ModuleScript results are cached in a session.

## Component suite

Existing coverage is retained:

- All **15 factories**: initialized values, silent construction, independent instances/state, dot/colon factory and method calls, layout order, independent destruction, idempotent `Destroy`, and rejected methods after destruction.
- Stateful setter callback counts and replacement/removal; SearchBox text-change callbacks. TextBox programmatic changes and Keybind setters/cancellation remain intentionally silent. `Callback = false` and `SetCallback(false)` are invalid, not callback-disable aliases; only `nil` removes a callback.
- Slider reversed/equal bounds, zero/negative step fallback, decimals, fractional origins, tiny steps, upward half-step ties, and displayed values.
- ColorPicker preview, all RGB labels/fills/knobs, `GetColor`, and complete rendering inside its single `SetColor` callback.
- Dropdown invalid defaults, cloned/deduplicated options, invalid selection, silent `SetOptions` invalidation, literal case-insensitive search, and Search/Options sibling hierarchy.
- MultiDropdown caps including zero, deduplication, invalid-value filtering, option replacement, and defensive copies of inputs, getter results, and callback payloads.
- NumericOnly TextBox default/setter sanitization; Section `Container`, both `AddComponent` forms, collapse and child destruction; Keybind enum validation, aliases and public cancellation.
- Notification hidden construction, content methods, repeated `Show`, expiry and early destruction past the timer deadline; invalid-config descendant counts and invalid setters preserving state/callbacks.
- Parent/root/ScreenGui/library destruction, caller-owned GUI preservation by lower-level `UI:Destroy`, rejected creation after destruction, repeated component creation/destruction, and instrumented fake-signal `Helpers.Scope` cleanup.

Added regressions:

1. **Notification colon no config and dot nil use identical defaults**: both calls produce independent hidden notifications with default title/content and the same holder.
2. **Section logical heights at ancestor scales 0.5, 1 and 2**: two fixed-height rows retain a 90-unit content container and 122-unit expanded section, collapsing to 32 units. The test waits multiple render/layout frames after each scale change and restore.
3. **Immediate explicit component destruction**: every factory's methods are checked before yielding; the existing `dead` helper checks rejection before repeating `Destroy`, so cleanup cannot mask a missing guard.
4. **False config/callback rejection**: dot/colon false configs for every factory, `Library.new(false)`, `Callback = false` construction, and `SetCallback(false)` rejection on every component that exposes it. Existing callback/state-preservation expectations remain in place.

## Window suite: 13 named cases

1. **Metadata and default cosmic window structure without default tabs**: exact `Version = "2.0.0"`, sorted 15-name registry, empty Pages/Tabs, default rich-text ASTRAL LITE title/version, purple border, dark frame, size/topbar/sidebar, logo, minimize/close controls, floating logo, and notification holder. These are structural/property assertions, not screenshot comparisons or asset-load assertions.
2. **Custom config, default dot call and independent window themes**: Title/Name/Version/Theme/Parent, cloned override tables, distinct window/UI/theme state, per-window default picker colors, and independent destruction.
3. **All 14 tab factories, default state, independent instances and call styles**: tab shape, page title/layout, map aliases, default values, automatic order, dot/colon calls, and no tab-level notification factory.
4. **Window and tab invalid configs are transactional**: invalid values/themes/parents, duplicate names, foreign selections, false configs/callbacks, no published GUI/tab residue, and unchanged existing selection/maps.
5. **Automatic LayoutOrder, explicit order, config copies and failed creation**: automatic progression, explicit high/negative order, caller config preservation, failure not advancing order, and per-tab independence.
6. **Selection, selected-tab removal and name reuse**: select by name/object, tab Select, active indicator/page, fallback to first remaining tab, inactive removal, empty maps, and recreation under a removed name.
7. **External page and navigation-button destruction remove tab state**: fallback selection, component disposal, and map/page cleanup after deferred destruction signals settle.
8. **Show, Hide, Minimize, Restore and Enabled visibility**: both method call styles, floating-logo visibility, restored size, and ScreenGui.Enabled participation in `IsVisible`.
9. **Window notifications default calls, Show, Destroy and expiry**: no-config colon/dot nil defaults, holder ownership, repeated Show, immediate destruction, false validation, and short expiry.
10. **Explicit window Destroy owns GUI, all components and tab maps immediately**: all 15 components, including a shown notification, are disposed with the entire GUI; retained map references are emptied and methods reject further work. `Destroy` remains idempotent and `IsVisible` returns false rather than throwing.
11. **Lower-level UI Destroy leaves shell; explicit window Destroy finishes ownership**: the low-level library disposes components but leaves the window/tab shell alive until the owner destroys the window.
12. **External ScreenGui destruction tears down window and tabs**: window/tab/component state settles and rejects later work after the external destruction event.
13. **Repeated window construction and explicit destruction leave no GUI residue**: sequential window/tab/component creation, visibility transitions and shutdown.

## Ownership and the shell getter's third return

Tests create their own windows; they never invoke or destroy `Main`'s live window. `CreateWindow()` itself creates **no default tabs**. `Main` is the separate client script that adds the eight standard tabs.

For application code using that shell, the current client BindableFunction returns **three values**:

```lua
local Players = game:GetService("Players")
local main = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Main")
local UI, pages, window = main:WaitForChild("GetUI"):Invoke()
assert(UI == window.UI and pages == window.Pages)
-- Only the owner, when shutting down this entire shell:
-- window:Destroy()
```

`window:Hide()` and `window:Minimize()` are reversible visibility operations, not cleanup. For permanent shutdown, the owner must call **`window:Destroy()` explicitly**, preferably before destroying its owning script. A script's own Destroying handler is only best-effort under deferred signals. Do not rely on stopping a script to release its external listeners. Do not call `UI:Destroy()` as a substitute for whole-window disposal: it preserves the shell GUI. Conversely, `Library.new({ ScreenGui = suppliedGui })` does not own the supplied GUI; its caller remains responsible for destroying it.

## Boundaries and validation status

These instructions and assertions are **not a claim of Studio execution or passing tests**. The Luau compiler can check syntax but cannot validate Roblox rendering, signal scheduling, input or timer behavior. If the local compiler is available, syntax-check with:

```sh
.tools/luau/luau-compile.exe --null tests/Components.spec.lua tests/Window.spec.lua
```

No synthetic click, drag/touch, keyboard capture, focus-loss, or Enter-submission tests are included. Manually verify these interactions, including active-input destruction, RightShift and logo dragging. Keybind cancellation is tested through its public API without claiming to start a capture. Cosmetic assertions do not verify remote asset availability.

Descendant/GUI counts cannot detect unparented leaked Instances, scheduler timer counts, or private `UserInputService` listener counts. The fake signal measures only Scope's connection contract and does not patch Roblox services. Timer tests check observable lifetime past deadlines, not cancellation internals. Render-frame waits and deadlines may take longer on a busy Studio client. The specs do not automatically test `Main.GetUI` or destroy `Main`; its third return and owner shutdown are documented above.
