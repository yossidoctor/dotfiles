hs.autoLaunch(true)
hs.automaticallyCheckForUpdates(false)
hs.dockIcon(false)
hs.menuIcon(false)
hs.consoleOnTop(false)
hs.uploadCrashData(false)
-- `hs -c '<lua>'` from a shell; aerospace.toml's Hyper+f binding uses it.
require("hs.ipc")

local quitOnLastWindowApps = {
  "com.apple.Preview",
  "com.apple.TextEdit",
  "com.apple.calculator",
  "us.zoom.xos",
  "com.apple.Passwords",
  "com.colliderli.iina",
}

local hadWindow = {}

quitOnLastWindow = hs.timer.doEvery(0.25, function()
  for _, bundleID in ipairs(quitOnLastWindowApps) do
    local app = hs.application.applicationsForBundleID(bundleID)[1]
    if not app then
      hadWindow[bundleID] = nil
    elseif #app:allWindows() > 0 then
      hadWindow[bundleID] = true
    elseif hadWindow[bundleID] then
      hadWindow[bundleID] = nil
      app:kill()
    end
  end
end)

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

-- Phantom tile: a window still tiled 1s after macOS minimized it. Float it so
-- its slot collapses; a window AeroSpace already took out of the tree is not
-- in the list and is left alone. Floated windows are re-tiled on restore.
local floatedPhantoms = {}
aerospaceWindows:subscribe(hs.window.filter.windowMinimized, function(w)
  local id = w:id()
  if not id then return end
  hs.timer.doAfter(1, function()
    if not w:isMinimized() then return end
    aerospace({ "list-windows", "--all", "--format", "%{window-id} %{window-layout}" }, function(out)
      local layout = ("\n" .. out):match("\n" .. id .. " (%S+)")
      if layout and layout ~= "floating" then
        floatedPhantoms[id] = true
        aerospace({ "layout", "floating", "--window-id", tostring(id) })
      end
    end)
  end)
end)
aerospaceWindows:subscribe(hs.window.filter.windowUnminimized, function(w)
  local id = w:id()
  if id and floatedPhantoms[id] then
    floatedPhantoms[id] = nil
    aerospace({ "layout", "tiling", "--window-id", tostring(id) })
  end
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
    if fullscreen == "true" and w then w:raise(); w:application():activate(); return end
    local front = hs.window.focusedWindow()
    local frontId = front and front:isStandard() and front:id()
    if frontId and frontId ~= tonumber(id) then
      aerospace({ "focus", "--window-id", tostring(frontId) })
    end
  end)
end
aerospaceWindows:subscribe(hs.window.filter.windowFocused, aerospaceRaiseFullscreen)
