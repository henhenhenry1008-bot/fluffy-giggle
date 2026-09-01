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
      guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else {
        continue
      }

      let isPresent = (description[kIOPSIsPresentKey] as? NSNumber)?.boolValue ?? true
      guard isPresent else { continue }

      guard let currentCapacity = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.intValue,
        let maximumCapacity = (description[kIOPSMaxCapacityKey] as? NSNumber)?.intValue,
        let isCharging = (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue,
        let isFullyCharged = (description[kIOPSIsChargedKey] as? NSNumber)?.boolValue,
        let powerSourceState = description[kIOPSPowerSourceStateKey] as? String,
        powerSourceState == kIOPSACPowerValue || powerSourceState == kIOPSBatteryPowerValue
      else {
        continue
      }

      guard
        let reading = Self.makeReading(
          currentCapacity: currentCapacity,
          maximumCapacity: maximumCapacity,
          isCharging: isCharging,
          isFullyCharged: isFullyCharged,
          isACPowered: powerSourceState == kIOPSACPowerValue
        )
      else {
        continue
      }
      return reading
    }

    // Desktop Macs and systems without a present internal battery arrive here.
    return nil
  }

  static func makeReading(
    currentCapacity: Int,
    maximumCapacity: Int,
    isCharging: Bool,
    isFullyCharged: Bool,
    isACPowered: Bool
  ) -> BatteryReading? {
    guard currentCapacity >= 0, maximumCapacity > 0 else { return nil }

    let percentage = min(max(Double(currentCapacity) / Double(maximumCapacity), 0), 1)
    return BatteryReading(
      percentage: percentage,
      isCharging: isCharging,
      isFullyCharged: isFullyCharged,
      isACPowered: isACPowered
    )
  }
}
