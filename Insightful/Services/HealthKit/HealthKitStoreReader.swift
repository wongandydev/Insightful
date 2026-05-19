import Foundation
import HealthKit

/// Production `HealthKitReading` — wraps `HKHealthStore` with async/await.
///
/// Quantity reads use `HKStatisticsCollectionQuery` bucketed by calendar day;
/// sleep uses `HKSampleQuery` over `HKCategorySample`s grouped by night; the
/// running-workouts path queries `HKWorkoutType` and sums `totalDistance`.
struct HealthKitStoreReader: HealthKitReading {
    private let store: HKHealthStore

    init(store: HKHealthStore) {
        self.store = store
    }

    // MARK: - Authorization

    func requestAuthorization(read: Set<HKSampleType>) async throws {
        try await store.requestAuthorization(toShare: [], read: read)
    }

    // MARK: - Quantity reads

    func readDailyQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        aggregation: HealthKitMetric.Aggregation,
        interval: DateInterval
    ) async throws -> [Double] {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )
        let options: HKStatisticsOptions = {
            switch aggregation {
            case .sum: return .cumulativeSum
            case .average: return .discreteAverage
            case .mostRecent: return .mostRecent
            }
        }()
        let anchor = Calendar.current.startOfDay(for: interval.start)
        let dailyInterval = DateComponents(day: 1)

        let collection: HKStatisticsCollection = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchor,
                intervalComponents: dailyInterval
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let results {
                    continuation.resume(returning: results)
                } else {
                    continuation.resume(throwing: HealthKitReadError.noResults)
                }
            }
            store.execute(query)
        }

        var values: [Double] = []
        collection.enumerateStatistics(from: interval.start, to: interval.end) { stats, _ in
            let quantity: HKQuantity? = {
                switch aggregation {
                case .sum: return stats.sumQuantity()
                case .average: return stats.averageQuantity()
                case .mostRecent: return stats.mostRecentQuantity()
                }
            }()
            if let q = quantity {
                values.append(q.doubleValue(for: unit))
            }
        }
        return values
    }

    // MARK: - Sleep

    func readSleepHours(in interval: DateInterval) async throws -> [Double] {
        let type = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: []
        )
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }

        // Group "asleep" samples by night. Key on the local calendar day of
        // the sample's *end* time so sleep that begins before midnight rolls
        // forward into the morning's totals.
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        var totalsByNight: [Date: TimeInterval] = [:]
        let calendar = Calendar.current
        for sample in samples where asleepValues.contains(sample.value) {
            let night = calendar.startOfDay(for: sample.endDate)
            totalsByNight[night, default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
        }
        return totalsByNight
            .sorted(by: { $0.key < $1.key })
            .map { $0.value / 3600 }
    }

    // MARK: - Running workout distances

    func readRunningWorkoutDistances(in interval: DateInterval) async throws -> [Double] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .running),
            HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: []),
        ])
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKWorkout]) ?? [])
                }
            }
            store.execute(query)
        }

        var totalsByDay: [Date: Double] = [:]
        let calendar = Calendar.current
        for workout in workouts {
            guard let distance = workout.totalDistance?.doubleValue(for: .meter()) else { continue }
            let day = calendar.startOfDay(for: workout.startDate)
            totalsByDay[day, default: 0] += distance
        }
        return totalsByDay
            .sorted(by: { $0.key < $1.key })
            .map { $0.value }
    }
}

enum HealthKitReadError: Error, Equatable {
    case noResults
}
