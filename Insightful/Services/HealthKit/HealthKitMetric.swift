import Foundation
import HealthKit

/// Every metric the backend's `/insight` whitelist accepts. The raw value is
/// the exact key the backend expects in the request body.
///
/// Each case maps to a HealthKit query strategy via `kind`. The three special
/// strategies (`sleepDuration`, `runningDistanceFromWorkouts`) handle the
/// metrics that don't fit the "quantity sample + statistics query" shape.
enum HealthKitMetric: String, CaseIterable, Sendable {
    case activeEnergyBurned
    case basalEnergyBurned
    case appleExerciseTime
    case bodyMass
    case bodyFatPercentage
    case heartRateVariabilitySDNN
    case restingHeartRate
    case heartRateRecoveryOneMinute
    case vo2Max
    case oxygenSaturation
    case respiratoryRate
    case sleepAnalysis
    case sleepHours
    case appleSleepingWristTemperature
    case distanceWalkingRunning
    case distanceRunning
    case distanceCycling
    case distanceSwimming
    case runningPower
    case runningSpeed
    case cyclingPower
    case cyclingSpeed
    case steps

    enum Kind: Sendable {
        case quantity(HKQuantityTypeIdentifier, HKUnit, Aggregation)
        case sleepDuration
        case runningDistanceFromWorkouts
    }

    enum Aggregation: Sendable {
        case sum
        case average
        case mostRecent
    }

    var kind: Kind {
        switch self {
        // Energy and exercise time — summed per day
        case .activeEnergyBurned:
            return .quantity(.activeEnergyBurned, .kilocalorie(), .sum)
        case .basalEnergyBurned:
            return .quantity(.basalEnergyBurned, .kilocalorie(), .sum)
        case .appleExerciseTime:
            return .quantity(.appleExerciseTime, .minute(), .sum)

        // Body composition — latest reading per day (measured infrequently)
        case .bodyMass:
            return .quantity(.bodyMass, .gramUnit(with: .kilo), .mostRecent)
        case .bodyFatPercentage:
            return .quantity(.bodyFatPercentage, .percent(), .mostRecent)

        // Cardiovascular — averaged per day
        case .heartRateVariabilitySDNN:
            return .quantity(.heartRateVariabilitySDNN, .secondUnit(with: .milli), .average)
        case .restingHeartRate:
            return .quantity(.restingHeartRate, beatsPerMinute, .average)
        case .heartRateRecoveryOneMinute:
            return .quantity(.heartRateRecoveryOneMinute, beatsPerMinute, .average)
        case .vo2Max:
            return .quantity(.vo2Max, mlPerKgPerMinute, .mostRecent)
        case .oxygenSaturation:
            return .quantity(.oxygenSaturation, .percent(), .average)
        case .respiratoryRate:
            return .quantity(.respiratoryRate, breathsPerMinute, .average)

        // Sleep — derived from HKCategorySample, summed asleep hours per night
        case .sleepAnalysis, .sleepHours:
            return .sleepDuration

        case .appleSleepingWristTemperature:
            return .quantity(.appleSleepingWristTemperature, .degreeCelsius(), .average)

        // Distances — summed per day
        case .distanceWalkingRunning:
            return .quantity(.distanceWalkingRunning, .meter(), .sum)
        case .distanceCycling:
            return .quantity(.distanceCycling, .meter(), .sum)
        case .distanceSwimming:
            return .quantity(.distanceSwimming, .meter(), .sum)

        // Running distance from workouts — there is no HKQuantityType.running
        // specifically; HealthKit lumps walking + running together. We sum
        // `totalDistance` over running `HKWorkout`s for accuracy.
        case .distanceRunning:
            return .runningDistanceFromWorkouts

        // Power / speed during workouts — averaged per day
        case .runningPower:
            return .quantity(.runningPower, .watt(), .average)
        case .runningSpeed:
            return .quantity(.runningSpeed, metersPerSecond, .average)
        case .cyclingPower:
            return .quantity(.cyclingPower, .watt(), .average)
        case .cyclingSpeed:
            return .quantity(.cyclingSpeed, metersPerSecond, .average)

        case .steps:
            return .quantity(.stepCount, .count(), .sum)
        }
    }

    /// Multiplier applied to raw HealthKit readings before they leave
    /// ``HealthKitService``.
    ///
    /// `HKUnit.percent()` yields 0.0–1.0 fractions, but everything downstream
    /// — the backend agent, the daily-insight cache, chart axes labelled "%"
    /// — expects human percent values (18.7, not 0.187), so percent metrics
    /// scale by 100. Every other metric's HKUnit already matches its display
    /// unit and ships unchanged.
    var wireScale: Double {
        switch self {
        case .bodyFatPercentage, .oxygenSaturation:
            return 100
        default:
            return 1
        }
    }

    /// All HealthKit sample types this metric needs read permission for.
    /// Used when bundling the one-shot authorization request.
    var sampleTypes: Set<HKSampleType> {
        switch kind {
        case .quantity(let id, _, _):
            return [HKQuantityType(id)]
        case .sleepDuration:
            return [HKCategoryType(.sleepAnalysis)]
        case .runningDistanceFromWorkouts:
            return [HKWorkoutType.workoutType(), HKQuantityType(.distanceWalkingRunning)]
        }
    }
}

// MARK: - Shared HKUnits

private let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
private let breathsPerMinute = HKUnit.count().unitDivided(by: .minute())
private let metersPerSecond = HKUnit.meter().unitDivided(by: .second())
private let mlPerKgPerMinute = HKUnit.literUnit(with: .milli)
    .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
