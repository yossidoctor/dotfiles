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

-- Every focus change: the `list-windows --focused` read is the #1615 retile
-- poke; a fullscreen focused window is raised (AeroSpace never manages
-- z-order); and when macOS and AeroSpace disagree on the focused window (a
-- restored window takes macOS focus AeroSpace never records) AeroSpace gets
-- the macOS one, re-read at callback time so a stale event cannot drag focus
-- back. A new window's first focus waits 400ms: extract-fullscreen-pair.sh
-- needs the ~100ms after detection in which the old window still reads as
-- fullscreen (2026-10-04: 0/3 extractions with the call immediate, 2/2 without).
-- aerospace.toml's Hyper+f binding calls this via `hs -c`.
local lastWindowCreated = 0
aerospaceWindows:subscribe(hs.window.filter.windowCreated, function() lastWindowCreated = hs.timer.secondsSinceEpoch() end)
function aerospaceRaiseFullscreen()
  if hs.timer.secondsSinceEpoch() - lastWindowCreated < 0.4 then
    hs.timer.doAfter(0.4, aerospaceRaiseFullscreen); return
  end
  aerospace({ "list-windows", "--focused", "--format", "%{window-id} %{window-is-fullscreen}" }, function(out)
    local id, fullscreen = out:match("^(%d+) (%S+)")
    if not id then return end
    local w = hs.window.get(tonumber(id))
    if fullscreen == "true" and w then w:raise(); w:application():activate(); note("raised fullscreen", id); return end
    local front = hs.window.focusedWindow()
    local frontId = front and front:isStandard() and front:id()
    if frontId and frontId ~= tonumber(id) then
      aerospace({ "focus", "--window-id", tostring(frontId) })
      note("focus resync", id, "->", tostring(frontId), front:application():name())
    end
  end)
  floatPhantoms()
end
aerospaceWindows:subscribe(hs.window.filter.windowFocused, aerospaceRaiseFullscreen)
