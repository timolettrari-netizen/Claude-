import Foundation
import HealthKit

/// Apple Health: Schritte und Gewicht lesen, Trainings speichern.
final class HealthService {
    static let shared = HealthService()
    private let hs = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        let read: Set<HKObjectType> = [HKQuantityType(.stepCount), HKQuantityType(.bodyMass), HKQuantityType(.heartRate), HKObjectType.workoutType()]
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning)]
        do {
            try await hs.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            return false
        }
    }

    func stepsToday() async -> Double {
        guard isAvailable else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let q = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: pred),
                                            options: .cumulativeSum)
        let r = try? await q.result(for: hs)
        return r?.sumQuantity()?.doubleValue(for: .count()) ?? 0
    }

    func latestWeight() async -> Double? {
        guard isAvailable else { return nil }
        let q = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
                                        sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                                        limit: 1)
        let r = try? await q.result(for: hs)
        return r?.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    /// Live-Puls der Apple Watch (während auf der Uhr ein Training läuft) über Apple Health
    func streamHeartRate(since start: Date, handler: @escaping (Int) -> Void) -> HKQuery? {
        guard isAvailable else { return nil }
        let type = HKQuantityType(.heartRate)
        let pred = HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-120), end: nil)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let deliver: ([HKSample]?) -> Void = { samples in
            guard let last = (samples as? [HKQuantitySample])?.max(by: { $0.endDate < $1.endDate }) else { return }
            let bpm = Int(last.quantity.doubleValue(for: unit).rounded())
            DispatchQueue.main.async { handler(bpm) }
        }
        let q = HKAnchoredObjectQuery(type: type, predicate: pred, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            deliver(samples)
        }
        q.updateHandler = { _, samples, _, _, _ in deliver(samples) }
        hs.execute(q)
        return q
    }

    func stop(_ q: HKQuery) { hs.stop(q) }

    func saveRun(start: Date, end: Date, km: Double, kcal: Double) async {
        guard isAvailable else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .running
        cfg.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: hs, configuration: cfg, device: .local())
        do {
            try await builder.beginCollection(at: start)
            var samples: [HKSample] = [HKCumulativeQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                                                  quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                                                  start: start, end: end)]
            if km > 0 {
                samples.append(HKCumulativeQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                                          quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: km),
                                                          start: start, end: end))
            }
            try await builder.addSamples(samples)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
        }
    }

    func saveWorkout(start: Date, end: Date, kcal: Double) async {
        guard isAvailable else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .traditionalStrengthTraining
        cfg.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: hs, configuration: cfg, device: .local())
        do {
            try await builder.beginCollection(at: start)
            let energy = HKCumulativeQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                                    start: start, end: end)
            try await builder.addSamples([energy])
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // Speichern in Health ist optional – Fehler ignorieren.
        }
    }
}
