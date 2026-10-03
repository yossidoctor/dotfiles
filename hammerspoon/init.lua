hs.autoLaunch(true)
hs.automaticallyCheckForUpdates(false)
hs.dockIcon(false)
hs.menuIcon(false)
hs.consoleOnTop(false)
hs.uploadCrashData(false)

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
