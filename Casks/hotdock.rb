cask "hotdock" do
  version "1.0.0"
  sha256 "ee30dfbd97e30ca04dc203f98e8df09a272c55d34365d3cb43c72626f8636e4a"

  url "https://github.com/bartbriek/hotdock/releases/download/v#{version}/Hotdock-#{version}.dmg"
  name "Hotdock"
  desc "Keyboard shortcuts for dock applications"
  homepage "https://github.com/bartbriek/hotdock"

  app "Hotdock.app"

  postflight do
    # Remove quarantine attribute to avoid Gatekeeper warning
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Hotdock.app"],
                   sudo: false
  end
end
