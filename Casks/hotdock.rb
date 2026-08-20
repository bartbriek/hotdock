cask "hotdock" do
  version "1.2.0"
  sha256 "88f247669e5410985e7fc0579f8ae9053e98b0b41c075363139cbc32994a1570"

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
