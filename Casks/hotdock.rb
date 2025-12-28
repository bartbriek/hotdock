cask "hotdock" do
  version "1.1.0"
  sha256 "1a8916e1c58cb3b1b2c65193fd04e84d36c2f07c3725804b0b4f7e662c68b287"

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
