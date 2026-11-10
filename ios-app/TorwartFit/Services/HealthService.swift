import Foundation
import HealthKit

/// Apple Health: Schritte und Gewicht lesen, Trainings speichern.
final class HealthService {
    static let shared = HealthService()
    private let hs = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        let read: Set<HKObjectType> = [HKQuantityType(.stepCount), HKQuantityType(.bodyMass), HKQuantityType(.heartRate), HKObjectType.workoutType(),
                                       HKQuantityType(.activeEnergyBurned), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.distanceCycling),
                                       HKQuantityType(.restingHeartRate), HKCategoryType(.sleepAnalysis)]
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
        let activity: FreeActivity      // run, walk, hike, bike
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

    /// Alle Trainings anderer Apps (Garmin Connect, Strava, Apple Watch …) seit `since`, ohne die von TorwartFit selbst
    private func foreignWorkouts(since: Date) async -> [HKWorkout] {
        guard isAvailable else { return [] }
        let q = HKSampleQueryDescriptor(predicates: [.workout(HKQuery.predicateForSamples(withStart: since, end: nil))],
                                        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)], limit: 500)
        guard let workouts = try? await q.result(for: hs) else { return [] }
        let own = Bundle.main.bundleIdentifier ?? ""
        return workouts.filter { $0.sourceRevision.source.bundleIdentifier != own }
    }

    private static let bpm = HKUnit.count().unitDivided(by: .minute())

    /// Aktivitäten mit Strecke: Laufen, Gehen, Wandern, Radfahren
    func distanceWorkouts(since: Date) async -> [ImportedRun] {
        let workouts = await foreignWorkouts(since: since)
        var out: [ImportedRun] = []
        for w in workouts {
            let activity: FreeActivity
            switch w.workoutActivityType {
            case .running: activity = .run
            case .walking: activity = .walk
            case .hiking: activity = .hike
            case .cycling: activity = .bike
            default: continue
            }
            let distType = HKQuantityType(activity == .bike ? .distanceCycling : .distanceWalkingRunning)
            let km = w.statistics(for: distType)?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
            let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            let hr = w.statistics(for: HKQuantityType(.heartRate))
            let avg: Int? = hr?.averageQuantity().map { Int($0.doubleValue(for: HealthService.bpm).rounded()) }
            let peak: Int? = hr?.maximumQuantity().map { Int($0.doubleValue(for: HealthService.bpm).rounded()) }
            out.append(ImportedRun(id: w.uuid.uuidString, start: w.startDate, end: w.endDate, km: km, kcal: kcal,
                                   avgHR: avg, maxHR: peak, source: w.sourceRevision.source.name, activity: activity))
        }
        return out
    }

    /// Alle anderen Trainings (Kraft, HIIT, Fußball, Schwimmen, Yoga …)
    func otherWorkouts(since: Date) async -> [ImportedWorkout] {
        let workouts = await foreignWorkouts(since: since)
        var out: [ImportedWorkout] = []
        for w in workouts {
            guard let name = HealthService.workoutName(w.workoutActivityType) else { continue }
            let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            let avg: Int? = w.statistics(for: HKQuantityType(.heartRate))?.averageQuantity().map { Int($0.doubleValue(for: HealthService.bpm).rounded()) }
            out.append(ImportedWorkout(id: w.uuid.uuidString, start: w.startDate, end: w.endDate, kcal: kcal, avgHR: avg,
                                       source: w.sourceRevision.source.name, kind: name))
        }
        return out
    }

    /// Deutscher Name einer Trainingsart; nil für Strecken-Aktivitäten (die laufen über distanceWorkouts)
    static func workoutName(_ t: HKWorkoutActivityType) -> String? {
        switch t {
        case .running, .walking, .hiking, .cycling: return nil
        case .soccer: return "Fußball"
        case .traditionalStrengthTraining: return "Krafttraining"
        case .functionalStrengthTraining: return "Funktionelles Krafttraining"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "Crosstraining"
        case .coreTraining: return "Rumpftraining"
        case .mixedCardio: return "Cardio"
        case .swimming: return "Schwimmen"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .flexibility: return "Dehnen"
        case .cooldown: return "Cool-down"
        case .elliptical: return "Crosstrainer"
        case .rowing: return "Rudern"
        case .stairClimbing: return "Treppensteigen"
        case .jumpRope: return "Seilspringen"
        case .tennis: return "Tennis"
        case .tableTennis: return "Tischtennis"
        case .badminton: return "Badminton"
        case .squash: return "Squash"
        case .basketball: return "Basketball"
        case .volleyball: return "Volleyball"
        case .handball: return "Handball"
        case .martialArts: return "Kampfsport"
        case .boxing: return "Boxen"
        case .golf: return "Golf"
        default: return "Training"
        }
    }

    // MARK: Tageswerte (Garmin, Apple Watch, iPhone)

    /// Aktiv verbrannte Kalorien heute
    func activeEnergyToday() async -> Double {
        guard isAvailable else { return 0 }
        let pred = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
        let q = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(.activeEnergyBurned), predicate: pred),
                                            options: .cumulativeSum)
        let r = try? await q.result(for: hs)
        return r?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    /// Schritte pro Tag, die letzten `days` Tage (ältester zuerst, heute zuletzt)
    func dailySteps(days: Int) async -> [(date: Date, steps: Int)] {
        guard isAvailable else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [(date: Date, steps: Int)] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            guard let start = cal.date(byAdding: .day, value: -i, to: today),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { continue }
            let pred = HKQuery.predicateForSamples(withStart: start, end: end)
            let q = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: pred),
                                                options: .cumulativeSum)
            let r = try? await q.result(for: hs)
            out.append((start, Int(r?.sumQuantity()?.doubleValue(for: .count()) ?? 0)))
        }
        return out
    }

    /// Letzter Ruhepuls (höchstens 3 Tage alt)
    func restingHeartRate() async -> Int? {
        guard isAvailable else { return nil }
        let q = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(.restingHeartRate))],
                                        sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        guard let s = (try? await q.result(for: hs))?.first, Date().timeIntervalSince(s.endDate) < 3 * 86400 else { return nil }
        return Int(s.quantity.doubleValue(for: HealthService.bpm).rounded())
    }

    /// Geschlafene Stunden in den letzten 24 Stunden (passt auch zu Tagschlaf nach Nachtdienst).
    /// Bei mehreren Quellen (Garmin, iPhone, Watch) zählt die mit dem meisten Schlaf – nichts wird doppelt gezählt.
    func sleepLast24h() async -> Double? {
        guard isAvailable else { return nil }
        let pred = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24 * 3600), end: Date())
        let q = HKSampleQueryDescriptor(predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: pred)],
                                        sortDescriptors: [SortDescriptor(\.startDate, order: .forward)], limit: 1000)
        guard let samples = try? await q.result(for: hs), !samples.isEmpty else { return nil }
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        var bySource: [String: Double] = [:]
        for smp in samples where asleep.contains(smp.value) {
            bySource[smp.sourceRevision.source.bundleIdentifier, default: 0] += smp.endDate.timeIntervalSince(smp.startDate)
        }
        guard let best = bySource.values.max(), best > 0 else { return nil }
        return best / 3600
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
