hs.autoLaunch(true)
hs.automaticallyCheckForUpdates(false)
hs.dockIcon(false)
hs.menuIcon(false)
hs.consoleOnTop(false)
hs.uploadCrashData(false)
-- `hs -c '<lua>'` from a shell; aerospace.toml's Hyper+f binding uses it.
require("hs.ipc")

-- Quit these when their last window closes. macOS sends no event for that
-- (the app stays frontmost with zero windows), so a timer looks, but only
-- while one of them is running: an app-launch event starts it and the sweep
-- stops it once none is left. IINA quits on its own (quitWhenNoOpenedWindow
-- in mac/defaults.sh).
local quitOnLastWindowApps = {
  ["com.apple.Preview"] = true,
  ["com.apple.TextEdit"] = true,
  ["com.apple.calculator"] = true,
  ["us.zoom.xos"] = true,
  ["com.apple.Passwords"] = true,
  ["com.apple.Safari"] = true,
  ["com.microsoft.VSCode"] = true,
}

local hadWindow = {}

quitOnLastWindow = hs.timer.new(0.25, function()
  local running = false
  for bundleID in pairs(quitOnLastWindowApps) do
    local app = hs.application.applicationsForBundleID(bundleID)[1]
    if not app then
      hadWindow[bundleID] = nil
    elseif #app:allWindows() > 0 then
      running, hadWindow[bundleID] = true, true
    elseif hadWindow[bundleID] then
      hadWindow[bundleID] = nil
      app:kill()
    else
      running = true
    end
  end
  if not running then quitOnLastWindow:stop() end
end)

quitOnLastWindowLauncher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.launched and quitOnLastWindowApps[app and app:bundleID() or ""] then
    quitOnLastWindow:start()
  end
end):start()
quitOnLastWindow:start()

-- AeroSpace watchdogs for upstream bugs on macOS 27 (no retile on window
-- close #1615, stalled minimize detection, fake fullscreen with no z-order):
-- every `aerospace` CLI call forces the daemon's pending relayout, so each
-- handler is a poke off an event macOS does deliver. Mechanisms and
-- measurements: docs/aerospace/RETILE-DELAY.md, FULLSCREEN-ZORDER.md.
-- No handler here closes, kills or minimizes a window (2026-07-29 invariant).
local AEROSPACE = "/opt/homebrew/bin/aerospace"

local function aerospace(args, onOutput)
  local cb = onOutput and function(_, out) onOutput(out) end or nil
  hs.task.new(AEROSPACE, cb, args):start()
end

aerospaceWindows = hs.window.filter.new(true)   -- every window, minimized ones included
aerospaceAppWatcher = hs.application.watcher.new(function(_, event)
  if event == hs.application.watcher.terminated then aerospace({ "list-windows", "--all" }) end
end):start()

local noteLog = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/aerospace/hammerspoon.log"
local function note(...)
  local f = io.open(noteLog, "a")
  if f then f:write(os.date("%Y-%m-%dT%H:%M:%S"), " ", table.concat({ ... }, " "), "\n"); f:close() end
end

-- Phantom tile: a minimized window AeroSpace still tiles. Float it so its
-- slot collapses, re-tile it on restore. Checked 1s after a minimize and, as
-- long as any window is minimized, on every focus change too: AeroSpace has
-- been seen to put a minimized window back into the tree hours after the
-- minimize, with no event to catch it (Safari, 2026-10-05). The minimized
-- set comes from the minimize/unminimize/destroy events, so the scan costs
-- one `list-windows` call and no Accessibility queries.
aerospaceMinimized = {}
local floatedPhantoms = {}
local function floatPhantoms()
  if next(aerospaceMinimized) == nil then return end
  aerospace({ "list-windows", "--all", "--format", "%{window-id} %{window-layout} %{app-name}" }, function(out)
    for id in pairs(aerospaceMinimized) do
      local layout, app = ("\n" .. out):match("\n" .. id .. " (%S+) ([^\n]*)")
      if layout and layout ~= "floating" then
        floatedPhantoms[id] = true
        aerospace({ "layout", "floating", "--window-id", tostring(id) })
        note("phantom", tostring(id), app, "was", layout, "-> floating")
      end
    end
  end)
end
aerospaceWindows:subscribe(hs.window.filter.windowMinimized, function(w)
  local id = w:id()
  if not id then return end
  aerospaceMinimized[id] = true
  hs.timer.doAfter(1, floatPhantoms)
end)
aerospaceWindows:subscribe({ hs.window.filter.windowUnminimized, hs.window.filter.windowDestroyed }, function(w, _, event)
  local id = w:id()
  if not id then return end
  aerospaceMinimized[id] = nil
  if floatedPhantoms[id] and event == hs.window.filter.windowUnminimized then
    aerospace({ "layout", "tiling", "--window-id", tostring(id) })
    note("restored phantom", tostring(id), "-> tiling")
  end
  floatedPhantoms[id] = nil
end)

-- Every focus change and every app activation (Cmd+Tab, Dock): the
-- `list-windows --focused` read is the #1615 retile poke; a fullscreen
-- focused window is raised (AeroSpace never manages z-order); and when macOS
-- and AeroSpace disagree on the focused window AeroSpace gets the macOS one,
-- re-read at callback time so a stale event cannot drag focus back. That
-- resync is what switches workspace on a Cmd+Tab AeroSpace missed: it follows
-- native focus only when the focused window id changes and the window has a
-- workspace (focusCache.swift, focus.swift; upstream discussion #949, open).
-- Three misses stay out of reach and are logged as "focus resync skipped":
-- Cmd+Tab from an empty workspace back to the app last focused fires no
-- macOS event at all (alt-N or Hyper+bracket instead, by design per #301);
-- a minimized-only app refuses focus (Dock click restores it); an overlay or
-- sheet leaves macOS reporting no window (Esc closes it, #1568).
-- A new window's first focus waits 400ms: extract-fullscreen-pair.sh
-- needs the ~100ms after detection in which the old window still reads as
-- fullscreen (2026-10-04: 0/3 extractions with the call immediate, 2/2 without).
-- aerospace.toml's Hyper+f binding calls this via `hs -c`.
local lastWindowCreated = 0
aerospaceWindows:subscribe(hs.window.filter.windowCreated, function() lastWindowCreated = hs.timer.secondsSinceEpoch() end)
function aerospaceRaiseFullscreen(activatedPid)
  if hs.timer.secondsSinceEpoch() - lastWindowCreated < 0.4 then
    hs.timer.doAfter(0.4, function() aerospaceRaiseFullscreen(activatedPid) end); return
  end
  aerospace({ "list-windows", "--focused", "--format", "%{window-id} %{window-is-fullscreen}" }, function(out)
    local id, fullscreen = out:match("^(%d+) (%S+)")
    local w = id and hs.window.get(tonumber(id))
    if fullscreen == "true" and w then w:raise(); w:application():activate(); note("raised fullscreen", id); return end
    local front = hs.window.focusedWindow()
    local frontId = front and front:isStandard() and front:id()
    local frontApp = front and front:application():name() or "no front window"
    -- On an empty workspace AeroSpace has no focused window; follow the
    -- macOS one only when it belongs to the app that was just activated
    -- (Mission Control click, Cmd+Tab back to the app you left), so a
    -- launch onto the empty workspace is not dragged back to the old window.
    local emptyWs = not id and frontId and front:application():pid() == activatedPid
    if not frontId or not id and not emptyWs then
      note("focus resync skipped", id or "no aerospace focus", frontId and "" or "nonstandard", frontApp)
    elseif emptyWs or frontId ~= tonumber(id) then
      -- Re-read after 300ms: on Cmd+Q macOS still reports the dying window
      -- as focused for a moment (Notes, 2026-10-22), and following it sent
      -- AeroSpace to the dead window's workspace.
      hs.timer.doAfter(0.3, function()
        local still = hs.window.focusedWindow()
        if not still or still:id() ~= frontId then note("focus resync dropped", id or "none", "->", tostring(frontId), frontApp); return end
        aerospace({ "focus", "--window-id", tostring(frontId) })
        note("focus resync", id or "none", "->", tostring(frontId), frontApp)
      end)
    end
  end)
  floatPhantoms()
end
aerospaceWindows:subscribe(hs.window.filter.windowFocused, aerospaceRaiseFullscreen)
aerospaceActivationWatcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.activated then aerospaceRaiseFullscreen(app and app:pid()) end
end):start()
