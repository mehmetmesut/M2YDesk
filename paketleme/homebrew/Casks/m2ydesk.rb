cask "m2ydesk" do
  version "1.0.9"
  sha256 "6e3854fdc3afab0cf6e3f64e25a5a7714af2c770c21d884fd5f9df4ceca9320e"

  url "https://github.com/mehmetmesut/M2YDesk/releases/download/v#{version}/M2YDesk-#{version}-aarch64.dmg",
      verified: "github.com/mehmetmesut/M2YDesk/"
  name "M2YDesk"
  desc "Remote desktop and remote support client based on RustDesk"
  homepage "https://desk.mehmetmesut.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: ">= :monterey"

  app "M2YDesk.app"

  zap trash: [
    "~/Library/Application Support/com.m2y.m2ydesk",
    "~/Library/Preferences/com.m2y.m2ydesk.plist",
  ]

  caveats <<~EOS
    M2YDesk is signed with the M2Y Software certificate but is not notarized by Apple yet.
    If macOS blocks the first launch, run:
      xattr -dr com.apple.quarantine /Applications/M2YDesk.app
    Then grant Screen Recording and Accessibility in System Settings > Privacy & Security.
  EOS
end
