cask "m2ydesk" do
  version "1.0.13"
  sha256 "3cef555d20561899a6e0163115f0d7ab3e2f7706d7e2955fde89a8149eb8a5d9"

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
