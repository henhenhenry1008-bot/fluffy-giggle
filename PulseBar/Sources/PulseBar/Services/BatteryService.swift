import Foundation
import IOKit.ps

actor BatteryService: BatteryProviding {
  func readBattery() async -> BatteryReading? {
    guard let informationReference = IOPSCopyPowerSourcesInfo() else {
      return nil
    }
    let information = informationReference.takeRetainedValue()

    guard let sourceListReference = IOPSCopyPowerSourcesList(information) else {
      return nil
    }
    let sources = sourceListReference.takeRetainedValue() as [AnyObject]

    for source in sources {
      guard let descriptionReference = IOPSGetPowerSourceDescription(information, source) else {
        continue
      }

      // The description is owned by the retained information snapshot and
      // must not be released independently.
      let description = descriptionReference.takeUnretainedValue() as NSDictionary
      if let reading = Self.makeReading(from: description) { return reading }
    }

    // Desktop Macs and systems without a present internal battery arrive here.
    return nil
  }

  // Keep dictionary parsing testable without requiring a particular Mac or
  // changing its live charging state.
  static func makeReading(from description: NSDictionary) -> BatteryReading? {
    guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { return nil }

    let isPresent = (description[kIOPSIsPresentKey] as? NSNumber)?.boolValue ?? true
    guard isPresent else { return nil }

    guard let currentCapacity = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.intValue,
      let maximumCapacity = (description[kIOPSMaxCapacityKey] as? NSNumber)?.intValue,
      let isCharging = (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue,
      let powerSourceState = description[kIOPSPowerSourceStateKey] as? String,
      powerSourceState == kIOPSACPowerValue || powerSourceState == kIOPSBatteryPowerValue
    else { return nil }

    let isACPowered = powerSourceState == kIOPSACPowerValue
    // Some system snapshots omit this flag. Preserve an explicit system value;
    // otherwise infer full charge only at full capacity on external power.
    let isFullyCharged =
      (description[kIOPSIsChargedKey] as? NSNumber)?.boolValue
      ?? (isACPowered && currentCapacity >= maximumCapacity)

    return makeReading(
      currentCapacity: currentCapacity,
      maximumCapacity: maximumCapacity,
      isCharging: isCharging,
      isFullyCharged: isFullyCharged,
      isACPowered: isACPowered,
      healthStatus: preferredHealthStatus(
        condition: description[kIOPSBatteryHealthConditionKey] as? String,
        estimate: description[kIOPSBatteryHealthKey] as? String
      ),
      timeToEmptyMinutes: (description[kIOPSTimeToEmptyKey] as? NSNumber)?.intValue,
      timeToFullChargeMinutes: (description[kIOPSTimeToFullChargeKey] as? NSNumber)?.intValue
    )
  }

  static func makeReading(
    currentCapacity: Int,
    maximumCapacity: Int,
    isCharging: Bool,
    isFullyCharged: Bool,
    isACPowered: Bool,
    healthStatus: String? = nil,
    timeToEmptyMinutes: Int? = nil,
    timeToFullChargeMinutes: Int? = nil
  ) -> BatteryReading? {
    guard currentCapacity >= 0, maximumCapacity > 0 else { return nil }

    let percentage = min(max(Double(currentCapacity) / Double(maximumCapacity), 0), 1)
    return BatteryReading(
      percentage: percentage,
      isCharging: isCharging,
      isFullyCharged: isFullyCharged,
      isACPowered: isACPowered,
      healthStatus: normalizedHealthStatus(healthStatus),
      timeToEmptyMinutes: isCharging || isACPowered
        ? nil : normalizedMinutes(timeToEmptyMinutes),
      timeToFullChargeMinutes: isCharging && !isFullyCharged
        ? normalizedMinutes(timeToFullChargeMinutes) : nil
    )
  }

  static func preferredHealthStatus(
    condition: String?,
    estimate: String?
  ) -> String? {
    normalizedHealthStatus(condition) ?? normalizedHealthStatus(estimate)
  }

  private static func normalizedHealthStatus(_ status: String?) -> String? {
    guard let status else { return nil }

    let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }

  private static func normalizedMinutes(_ minutes: Int?) -> Int? {
    // IOPowerSources uses -1 while it is still calculating an estimate.
    guard let minutes, minutes >= 0 else { return nil }
    return minutes
  }
}
