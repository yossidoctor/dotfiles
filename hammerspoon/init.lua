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

-- AeroSpace watchdogs. On macOS Tahoe and later AeroSpace (0.21.3-Beta) does
-- not retile when a window closes (upstream #1615), its native-minimize
-- detection can stall so a minimized window keeps its tile as an empty gap,
-- and its fake `fullscreen` only resizes, so a fullscreen window can sit
-- behind tiled siblings. Every `aerospace` CLI call forces the daemon's
-- pending relayout, so each handler below is a poke off an event macOS does
-- deliver here: app termination, minimize, unminimize, focus. Window-close
-- itself never reaches Hammerspoon on this macOS (hs.window.filter's
-- windowDestroyed fires only at app quit), which is why the Karabiner
-- Cmd+W/Cmd+Q rules (aerospace/retry-poke.sh) stay. Mechanisms and
-- measurements: docs/aerospace/RETILE-DELAY.md, docs/aerospace/FULLSCREEN-ZORDER.md.
-- No AeroSpace handler below closes, kills or minimizes a window (the
-- 2026-07-29 incident invariant): the only mutations are `layout
-- floating/tiling` and a raise.
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
      local layout = out:match("^" .. id .. " (%S+)") or out:match("\n" .. id .. " (%S+)")
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

-- On every focus change: read AeroSpace's focused window (the read doubles as
-- the retile poke that fixes #1615 when a close hands focus to the survivor).
-- If it is AeroSpace-fullscreen, put it on top: AXRaise plus app activation,
-- the pair AeroSpace's own focus path uses. If it is not the window macOS
-- focused (a restored window takes macOS focus that AeroSpace never records,
-- so fullscreen and every other command then hit the neighbour), hand
-- AeroSpace the macOS one. The macOS side is re-read at callback time so a
-- stale event from before a workspace switch cannot drag focus back. The
-- Hyper+f binding in aerospace.toml calls this via `hs -c` too, since the
-- toggle itself moves no focus.
function aerospaceRaiseFullscreen()
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
