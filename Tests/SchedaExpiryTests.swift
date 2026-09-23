import Foundation

struct SchedaExpiryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    func testLastSixDaysAreStillValid() {
        let start = date("2026-09-01T12:00:00+02:00")
        let end = date("2026-09-29T12:00:00+02:00")
        let scheda = Scheda(dataInizio: start, durata: 4, giorni: [])
        for daysLeft in 1...6 {
            let now = calendar.date(byAdding: .day, value: -daysLeft, to: end)!
            precondition(!scheda.isScaduta(at: now, calendar: calendar), "\(daysLeft) days left")
        }
    }

    func testExactExpirationBoundary() {
        let scheda = Scheda(dataInizio: date("2026-09-01T12:00:00+02:00"), durata: 4, giorni: [])
        let end = date("2026-09-29T12:00:00+02:00")
        precondition(!scheda.isScaduta(at: end.addingTimeInterval(-1), calendar: calendar))
        precondition(scheda.isScaduta(at: end, calendar: calendar))
        precondition(scheda.isScaduta(at: end.addingTimeInterval(1), calendar: calendar))
    }

    func testCalendarWeeksAcrossDaylightSavingChanges() {
        for (start, end) in [
            ("2026-03-22T12:00:00+01:00", "2026-03-29T12:00:00+02:00"),
            ("2026-10-18T12:00:00+02:00", "2026-10-25T12:00:00+01:00")
        ] {
            let scheda = Scheda(dataInizio: date(start), durata: 1, giorni: [])
            precondition(!scheda.isScaduta(at: date(end).addingTimeInterval(-1), calendar: calendar))
            precondition(scheda.isScaduta(at: date(end), calendar: calendar))
        }
    }

    func testZeroDurationAndPastWorkout() {
        let start = date("2026-09-01T12:00:00+02:00")
        precondition(Scheda(dataInizio: start, durata: 0, giorni: []).isScaduta(at: start, calendar: calendar))
        precondition(Scheda(dataInizio: start, durata: 1, giorni: []).isScaduta(
            at: date("2026-09-22T12:00:00+02:00"), calendar: calendar))
    }

    func testCurrentPropertyDoesNotUseRoundedWeeks() {
        let start = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let scheda = Scheda(dataInizio: start, durata: 1, giorni: [])
        precondition(scheda.getDurataScheda() == 0)
        precondition(!scheda.isScaduta)
    }
}

let tests = SchedaExpiryTests()
tests.testLastSixDaysAreStillValid()
tests.testExactExpirationBoundary()
tests.testCalendarWeeksAcrossDaylightSavingChanges()
tests.testZeroDurationAndPastWorkout()
tests.testCurrentPropertyDoesNotUseRoundedWeeks()
print("PASS: 5 expiry regression tests (last week, boundary, DST, past dates, current property)")
