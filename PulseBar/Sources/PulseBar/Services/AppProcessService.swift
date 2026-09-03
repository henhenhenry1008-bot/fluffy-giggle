import AppKit
import Darwin

struct AppProcessSample: Sendable {
  let id: AppProcessID
  let name: String
  let userTicks: UInt64
  let systemTicks: UInt64
  let residentBytes: UInt64
  let instant: ContinuousClock.Instant
}

struct AppProcessTracker {
  private(set) var previous: [AppProcessID: AppProcessSample] = [:]

  mutating func update(
    samples: [AppProcessSample],
    listedCount: Int,
    queriedCount: Int,
    secondsPerTick: Double?
  ) -> AppProcessListReading {
    var current: [AppProcessID: AppProcessSample] = [:]
    var readings: [AppProcessReading] = []
    for sample in samples where current[sample.id] == nil {
      readings.append(
        AppProcessReading(
          id: sample.id,
          name: sample.name,
          cpuUsage: Self.cpuUsage(
            previous: previous[sample.id], current: sample, secondsPerTick: secondsPerTick
          ),
          residentBytes: sample.residentBytes
        )
      )
      current[sample.id] = sample
    }
    // Disappeared, denied, and reused PIDs must not keep an old CPU baseline.
    previous = current
    readings.sort {
      if $0.cpuUsage != $1.cpuUsage { return ($0.cpuUsage ?? -1) > ($1.cpuUsage ?? -1) }
      if $0.residentBytes != $1.residentBytes { return $0.residentBytes > $1.residentBytes }
      return $0.id.pid < $1.id.pid
    }
    return AppProcessListReading(
      topProcesses: Array(readings.prefix(5)),
      listedCount: listedCount,
      queriedCount: queriedCount,
      readableCount: readings.count
    )
  }

  static func cpuUsage(
    previous: AppProcessSample?,
    current: AppProcessSample,
    secondsPerTick: Double?
  ) -> Double? {
    guard let previous, previous.id == current.id,
      let secondsPerTick, secondsPerTick.isFinite, secondsPerTick > 0,
      current.userTicks >= previous.userTicks,
      current.systemTicks >= previous.systemTicks
    else { return nil }

    let duration = previous.instant.duration(to: current.instant).components
    let elapsed = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    guard elapsed.isFinite, elapsed > 0 else { return nil }

    // PROC_PIDTASKALLINFO returns Mach absolute ticks, not nanoseconds on every
    // architecture. Convert using mach_timebase_info, including Apple Silicon.
    // Subtract integers before converting; add as Double to avoid UInt64 overflow.
    let ticks =
      Double(current.userTicks - previous.userTicks)
      + Double(current.systemTicks - previous.systemTicks)
    let usage = ticks * secondsPerTick / elapsed
    // 1.0 means one fully occupied core; multi-threaded processes may exceed it.
    return usage.isFinite && (usage * 100).isFinite ? usage : nil
  }
}

actor AppProcessService: AppProcessProviding {
  static let maximumCandidates = 1_024
  private var tracker = AppProcessTracker()
  private let secondsPerTick: Double?

  init() {
    var timebase = mach_timebase_info_data_t()
    if mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.numer > 0, timebase.denom > 0 {
      secondsPerTick = Double(timebase.numer) / Double(timebase.denom) / 1e9
    } else {
      secondsPerTick = nil
    }
  }

  func readAppProcesses() async -> AppProcessListReading? {
    // The public workspace list covers application processes, not all daemons
    // or all child processes. Only copy PIDs here; resource queries run on this actor.
    let pids = await MainActor.run {
      Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier).filter { $0 > 0 })
        .sorted()
    }
    guard !Task.isCancelled else { return nil }
    let candidates = pids.prefix(Self.maximumCandidates)
    var samples: [AppProcessSample] = []
    samples.reserveCapacity(candidates.count)
    for pid in candidates {
      guard !Task.isCancelled else { return nil }
      if let sample = Self.readSample(pid: pid) { samples.append(sample) }
    }
    return tracker.update(
      samples: samples,
      listedCount: pids.count,
      queriedCount: candidates.count,
      secondsPerTick: secondsPerTick
    )
  }

  private static func readSample(pid: pid_t) -> AppProcessSample? {
    var info = proc_taskallinfo()
    let size = Int32(MemoryLayout<proc_taskallinfo>.size)
    // Read task counters and BSD start time together. A PID alone is not a
    // stable process identity, since macOS can reuse it after a process exits.
    guard proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size) == size,
      info.pbsd.pbi_pid == UInt32(pid), info.pbsd.pbi_start_tvsec > 0,
      info.pbsd.pbi_start_tvusec < 1_000_000
    else { return nil }

    let name = withUnsafeBytes(of: info.pbsd.pbi_name) { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
    let shortName = withUnsafeBytes(of: info.pbsd.pbi_comm) { bytes in
      String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
    return AppProcessSample(
      id: AppProcessID(
        pid: pid,
        startSeconds: info.pbsd.pbi_start_tvsec,
        startMicroseconds: info.pbsd.pbi_start_tvusec
      ),
      name: name.isEmpty ? (shortName.isEmpty ? "PID \(pid)" : shortName) : name,
      userTicks: info.ptinfo.pti_total_user,
      systemTicks: info.ptinfo.pti_total_system,
      residentBytes: info.ptinfo.pti_resident_size,
      instant: ContinuousClock.now
    )
  }
}
