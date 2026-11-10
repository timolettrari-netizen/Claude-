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
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling)]
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

    struct ImportedRun {
        let id: String
        let start: Date
        let end: Date
        let km: Double
        let kcal: Double?
        let avgHR: Int?
        let maxHR: Int?
        let source: String
    }

    struct ImportedWorkout {
        let id: String
        let start: Date
        let end: Date
        let kcal: Double?
        let avgHR: Int?
        let source: String
        let kind: String
    }

    /// Kraft- und Fitnesstrainings anderer Apps (Strava, Garmin Connect, Apple Watch …)
    func strengthWorkouts(since: Date) async -> [ImportedWorkout] {
        guard isAvailable else { return [] }
        let types: [(HKWorkoutActivityType, String)] = [
            (.traditionalStrengthTraining, "Krafttraining"), (.functionalStrengthTraining, "Funktionelles Krafttraining"),
            (.highIntensityIntervalTraining, "HIIT"), (.crossTraining, "Crosstraining"), (.coreTraining, "Rumpftraining"),
        ]
        let typePred = NSCompoundPredicate(orPredicateWithSubpredicates: types.map { HKQuery.predicateForWorkouts(with: $0.0) })
        let pred = NSCompoundPredicate(andPredicateWithSubpredicates: [HKQuery.predicateForSamples(withStart: since, end: nil), typePred])
        let q = HKSampleQueryDescriptor(predicates: [.workout(pred)],
                                        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 200)
        guard let workouts = try? await q.result(for: hs) else { return [] }
        let own = Bundle.main.bundleIdentifier ?? ""
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return workouts.compactMap { w in
            if w.sourceRevision.source.bundleIdentifier == own { return nil }
            let name = types.first { $0.0 == w.workoutActivityType }?.1 ?? "Krafttraining"
            return ImportedWorkout(id: w.uuid.uuidString, start: w.startDate, end: w.endDate,
                                   kcal: w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                                   avgHR: w.statistics(for: HKQuantityType(.heartRate))?.averageQuantity().map { Int($0.doubleValue(for: bpm).rounded()) },
                                   source: w.sourceRevision.source.name, kind: name)
        }
    }

    /// Lauf-Trainings anderer Apps (Strava, Garmin Connect, Apple Watch …) aus Apple Health
    func runningWorkouts(since: Date) async -> [ImportedRun] {
        guard isAvailable else { return [] }
        let pred = HKQuery.predicateForSamples(withStart: since, end: nil)
        let q = HKSampleQueryDescriptor(predicates: [.workout(NSCompoundPredicate(andPredicateWithSubpredicates: [
                                            pred, HKQuery.predicateForWorkouts(with: .running)]))],
                                        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
                                        limit: 200)
        guard let workouts = try? await q.result(for: hs) else { return [] }
        let own = Bundle.main.bundleIdentifier ?? ""
        let bpm = HKUnit.count().unitDivided(by: .minute())
        return workouts.compactMap { w in
            if w.sourceRevision.source.bundleIdentifier == own { return nil }   // eigene Läufe nicht doppelt
            let km = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
            let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            let hr = w.statistics(for: HKQuantityType(.heartRate))
            return ImportedRun(id: w.uuid.uuidString, start: w.startDate, end: w.endDate, km: km, kcal: kcal,
                               avgHR: hr?.averageQuantity().map { Int($0.doubleValue(for: bpm).rounded()) },
                               maxHR: hr?.maximumQuantity().map { Int($0.doubleValue(for: bpm).rounded()) },
                               source: w.sourceRevision.source.name)
        }
    }

    func saveRun(start: Date, end: Date, km: Double, kcal: Double) async {
        guard isAvailable else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .running
        cfg.locationType = .outdoor
        var samples: [HKSample] = [HKCumulativeQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                                              quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                                              start: start, end: end)]
        if km > 0 {
            samples.append(HKCumulativeQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                                      quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: km),
                                                      start: start, end: end))
        }
        await writeWorkout(cfg, start: start, end: end, samples: samples)
    }

    /// Freies Training oder Lauf mit passender Aktivitätsart speichern
    func saveActivity(_ a: FreeActivity, start: Date, end: Date, km: Double, kcal: Double) async {
        guard isAvailable else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = a.healthType
        cfg.locationType = a.usesGPS ? .outdoor : .indoor
        var samples: [HKSample] = [HKCumulativeQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                                              quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                                              start: start, end: end)]
        if km > 0 && a.usesGPS {
            samples.append(HKCumulativeQuantitySample(type: HKQuantityType(a == .bike ? .distanceCycling : .distanceWalkingRunning),
                                                      quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: km),
                                                      start: start, end: end))
        }
        await writeWorkout(cfg, start: start, end: end, samples: samples)
    }

    func saveWorkout(start: Date, end: Date, kcal: Double) async {
        guard isAvailable else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .traditionalStrengthTraining
        cfg.locationType = .indoor
        let energy = HKCumulativeQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                                start: start, end: end)
        await writeWorkout(cfg, start: start, end: end, samples: [energy])
    }

    /// Legt ein Training über HKWorkoutBuilder an (Completion-Handler-API, in allen SDK-Versionen gleich benannt).
    private func writeWorkout(_ cfg: HKWorkoutConfiguration, start: Date, end: Date, samples: [HKSample]) async {
        let builder = HKWorkoutBuilder(healthStore: hs, configuration: cfg, device: .local())
        do {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                builder.beginCollection(withStart: start) { _, error in
                    if let error { c.resume(throwing: error) } else { c.resume() }
                }
            }
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                builder.add(samples) { _, error in
                    if let error { c.resume(throwing: error) } else { c.resume() }
                }
            }
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                builder.endCollection(withEnd: end) { _, error in
                    if let error { c.resume(throwing: error) } else { c.resume() }
                }
            }
            builder.finishWorkout { _, _ in }
        } catch {
            // Speichern in Health ist optional – Fehler ignorieren.
        }
    }
}
