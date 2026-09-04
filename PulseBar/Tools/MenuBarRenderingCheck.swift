// Standalone, developer-only macOS regression probe. Not part of the app target.
// Compile alongside Sources/PulseBar/**/*.swift, excluding App/PulseBarApp.swift.
// It uses a separate bundle identifier and never reads or changes user preferences.
import AppKit
import ObjectiveC.runtime
import SwiftUI

// Test-only instrumentation of a public AppKit factory. Weak references avoid
// keeping a removed status item alive. NSWindow.isVisible is not item.isVisible.
@MainActor private final class CapturedStatusItems {
  final class WeakItem {
    weak var value: NSStatusItem?
    init(_ value: NSStatusItem) { self.value = value }
  }
  static var items: [WeakItem] = []
  static var installed = false
  static func install() {
    guard !installed,
      let original = class_getInstanceMethod(
        NSStatusBar.self, #selector(NSStatusBar.statusItem(withLength:))),
      let replacement = class_getInstanceMethod(
        NSStatusBar.self, #selector(NSStatusBar.pulseBarProbeStatusItem(withLength:)))
    else { return }
    method_exchangeImplementations(original, replacement)
    installed = true
  }
}

extension NSStatusBar {
  @MainActor @objc fileprivate func pulseBarProbeStatusItem(withLength length: CGFloat)
    -> NSStatusItem
  {
    let item = pulseBarProbeStatusItem(withLength: length)
    CapturedStatusItems.items.append(.init(item))
    return item
  }
}

@main
struct MenuBarRenderingCheck: App {
  @State private var inserted = true
  @State private var presentation = Self.sample(visibility: .standard)
  @State private var report = "Ready. This probe checks the actual AppKit menu-bar title."
  @State private var running = false

  init() { CapturedStatusItems.install() }

  var body: some Scene {
    Window("PulseBar menu-bar regression check", id: "regression") {
      VStack(alignment: .leading, spacing: 12) {
        Text("PulseBar menu-bar regression check").font(.headline)
        Text(report).textSelection(.enabled)
        Button("Run native checks") {
          running = true
          Task { @MainActor in
            await runChecks()
            running = false
          }
        }
        .disabled(running)
        Button("Quit check") { NSApplication.shared.terminate(nil) }
      }
      .padding(20)
      .frame(width: 680)
    }
    MenuBarExtra(isInserted: $inserted) {
      Text("Isolated regression check — not the installed PulseBar.")
    } label: {
      MenuBarPresentationView(presentation: presentation).equatable()
    }
    .menuBarExtraStyle(.window)
  }

  private static func sample(visibility: MenuBarMetricVisibility) -> MenuBarPresentation {
    MenuBarPresentation(
      cpuUsage: 0.23, memoryUsage: 0.51, downloadBytesPerSecond: 2_500_000,
      uploadBytesPerSecond: 820_000, batteryPercentage: 0.83, visibility: visibility)
  }

  @MainActor private func runChecks() async {
    let all = MenuBarMetricVisibility(
      showsCPU: true, showsMemory: true, showsNetworkDownload: true,
      showsNetworkUpload: true, showsBattery: true)
    let none = MenuBarMetricVisibility(
      showsCPU: false, showsMemory: false, showsNetworkDownload: false,
      showsNetworkUpload: false, showsBattery: false)
    let cases: [(String, MenuBarPresentation)] = [
      ("Default three metrics", Self.sample(visibility: .standard)),
      ("All five metrics", Self.sample(visibility: all)),
      ("All hidden fallback", Self.sample(visibility: none)),
      (
        "Unavailable readings",
        MenuBarPresentation(
          cpuUsage: nil, memoryUsage: nil, downloadBytesPerSecond: nil, visibility: all)
      ),
    ]
    var results: [String] = []
    inserted = true
    for (name, value) in cases {
      presentation = value
      try? await Task.sleep(for: .milliseconds(300))
      let titles = statusButtons().map(\.title)
      results.append("\(titles.contains(value.title) ? "PASS" : "FAIL") \(name): \(titles)")
    }
    inserted = false
    try? await Task.sleep(for: .milliseconds(300))
    let removed =
      CapturedStatusItems.installed
      && CapturedStatusItems.items.compactMap(\.value).allSatisfy { !$0.isVisible }
    results.append("\(removed ? "PASS" : "FAIL") Remove menu item without closing main window")
    presentation = Self.sample(visibility: .standard)
    inserted = true
    try? await Task.sleep(for: .milliseconds(300))
    let restored = CapturedStatusItems.items.compactMap(\.value).contains {
      $0.isVisible && $0.button?.title == presentation.title
    }
    results.append("\(restored ? "PASS" : "FAIL") Reinsert menu item")
    report = results.joined(separator: "\n")
  }

  @MainActor private func statusButtons() -> [NSStatusBarButton] {
    func collect(_ view: NSView) -> [NSStatusBarButton] {
      let own = (view as? NSStatusBarButton).map { [$0] } ?? []
      return own + view.subviews.flatMap(collect)
    }
    // Only this diagnostic process's own windows, using public AppKit APIs.
    return NSApplication.shared.windows.compactMap(\.contentView).flatMap(collect)
  }
}
