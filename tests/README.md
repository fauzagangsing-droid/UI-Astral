# Manual Studio component tests

`Components.spec.lua` is an opt-in **ModuleScript** returning `function()`. Requiring it does not execute the suite. Calling the returned function creates temporary client `ScreenGui` fixtures, prints `UILibrary Components: N tests passed` on success, and returns that same number. A failed case raises an error with its name and traceback after fixture cleanup.

These tests are **not auto-run or mapped by default**. Do not add them to the production runtime mapping, rename them to `.client.lua`, or require them from `Main`. No test framework, executor API, simulated privileged input, or external dependency is required.

## Import manually

1. Open the place in Roblox Studio. Ensure the actual library is installed as **`ReplicatedStorage.UILibrary`**, a ModuleScript whose source is `src/shared/UILibrary/init.lua`.
   - Its direct ModuleScript children must be `Theme` and `Helpers`, with source from the corresponding `.lua` files.
   - Its `Components` child must itself be a **ModuleScript**, with source from `src/shared/UILibrary/Components/init.lua`, not a Folder.
   - Under `Components`, create the 15 ModuleScripts named `Toggle`, `Slider`, `Button`, `Dropdown`, `MultiDropdown`, `TextBox`, `Keybind`, `ColorPicker`, `Notification`, `Section`, `Label`, `Paragraph`, `Divider`, `ProgressBar`, and `SearchBox`; assign each corresponding component source file.
   - If the library is already synced/imported in this structure, leave it alone. Do not substitute the archived root `ui.lua`.
2. In Explorer, insert a **ModuleScript** directly under `ReplicatedStorage`. Name it exactly **`Components.spec`** (without `.lua`). Replace its source with the complete contents of `tests/Components.spec.lua`. This is a manual, test-only import; it does not change any project mapping.
3. Press **Play** (not server-only Run). Wait for the local player to spawn. Open **View → Command Bar** and select the **Client** execution context, not Server. The runner asserts both Studio and client execution.
4. Execute this in the **client Command Bar**:

   ```lua
   local run = require(game:GetService("ReplicatedStorage"):WaitForChild("Components.spec")); local passed = run(); print("Returned test count:", passed)
   ```

   Do not omit the `run()` call: `require(...)` alone only loads the runner. The suite yields for property signals, destruction, and notification deadlines; let the invocation finish. Inspect Output for the success line or the first named failure. Run sequentially, not concurrently.
5. Stop Play when finished. Remove the manually imported test ModuleScript before publishing if it was inserted in edit mode. Fixtures are destroyed on success or failure. After editing the runner, stop/restart Play and re-import/update its source before requiring again, since ModuleScript results are cached within a session.

## Coverage and boundaries

- All **15 factories**: initialized values, silent construction, separate component instances/state, dot/colon factory and component calls, layout order, independent destruction, idempotent `Destroy`, and rejection of remaining methods after direct root destruction.
- Callback counts and replacement/removal for stateful setters; SearchBox text-change callbacks. TextBox programmatic changes and Keybind setters/cancellation are intentionally silent.
- Slider reversed/equal bounds, zero/negative step fallback, decimal steps, fractional origins, small decimals, upward half-step ties, and displayed values.
- ColorPicker `GetColor`, preview, all RGB labels/fills/knobs, and complete RGB rendering **inside** its single `SetColor` callback.
- Dropdown invalid defaults, cloned/deduplicated options, rejected missing values, silent `SetOptions` invalidation, and literal case-insensitive search. Search is checked as a sibling of the option ScrollingFrame rather than a child of its layout.
- MultiDropdown selection caps (including zero), deduplication, invalid-value filtering, option replacement, and defensive copies of input, getter results, and callback payloads.
- NumericOnly TextBox sanitization at construction and through `SetValue`; Section `Container`, both `AddComponent` forms, collapse and child destruction; Keybind Enum.KeyCode validation, aliases, and idempotent `CancelCapture`.
- Notification hidden construction, content methods, repeated `Show`, expiry, early destruction, and waiting past the early-destroyed notification's timer deadline. These assert observable lifetime/descendant behavior, not private scheduler timer counts.
- Invalid shared/component configs: errors with unchanged fixture descendant counts, including property errors after partial construction. Invalid numeric/color/options/callback setters must preserve existing state and callback behavior.
- Parent, component root, ScreenGui, and library destruction; `Library.Destroy` leaves the supplied ScreenGui and caller panel alive; all factories reject creation after library destruction.
- Repeated create/destroy checks for UI residue. A separate isolated fake signal implements `Connect`, `Disconnect`, live connection counts, and firing, and verifies `Helpers.Scope` releases its connections after explicit or root destruction. It never patches services or production helpers.

Descendant counts cannot detect unparented leaked Instances. Component state/count checks do **not** measure live `UserInputService` subscriptions, and the fake signal verifies only the Scope contract. Public Studio APIs do not expose those service listener counts. The suite does not synthesize real clicks, drag/touch gestures, keyboard capture, focus loss, or TextBox Enter submission. `CancelCapture` is exercised through its public API without claiming to start an actual capture. Manually verify those interactions and inspect Output for asynchronous errors, especially after notification cleanup and destruction during active input. Timing checks yield past short deadlines and can take longer on a busy Studio client.

## Validation status

Studio execution is required for behavioral results. This README is a procedure, **not a claim that the suite has run or passed**. Static parsing or editor diagnostics cannot validate Roblox rendering, signal scheduling, input behavior, or timer cleanup.
