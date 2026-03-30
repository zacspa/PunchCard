import Foundation
import Testing
@testable import PunchCardLib

@Suite("Session Model Tests")
struct SessionModelTests {
    @Test("New session is active")
    func newSessionIsActive() {
        let session = Session(project: "Test")
        #expect(session.isActive)
        #expect(session.endTime == nil)
        #expect(session.duration == nil)
        #expect(session.hours == nil)
    }

    @Test("Session project is set correctly")
    func sessionProject() {
        let session = Session(project: "MyProject")
        #expect(session.project == "MyProject")
    }

    @Test("Session has unique ID")
    func uniqueIDs() {
        let s1 = Session(project: "Test")
        let s2 = Session(project: "Test")
        #expect(s1.id != s2.id)
    }

    @Test("Session starts with empty notes and commits")
    func emptyCollections() {
        let session = Session(project: "Test")
        #expect(session.notes.isEmpty)
        #expect(session.commits.isEmpty)
        #expect(session.summary == nil)
    }

    @Test("Formatted duration shows hours and minutes")
    func formattedDuration() {
        var session = Session(project: "Test")
        // Manually set end time to 1 hour 30 minutes later
        session.endTime = session.startTime.addingTimeInterval(5400) // 1.5 hours
        #expect(session.formattedDuration == "1h 30m")
    }

    @Test("Hours calculation is correct")
    func hoursCalculation() {
        var session = Session(project: "Test")
        session.endTime = session.startTime.addingTimeInterval(7200) // 2 hours
        #expect(session.hours == 2.0)
    }

    @Test("Negative duration is clamped to zero")
    func negativeDuration() {
        var session = Session(project: "Test")
        session.endTime = session.startTime.addingTimeInterval(-3600) // 1 hour before start
        #expect(session.duration == 0)
        #expect(session.hours == 0)
        #expect(session.formattedDuration == "0h 0m")
    }

    @Test("Session JSON round-trip encoding")
    func jsonRoundTrip() throws {
        var session = Session(project: "Test")
        session.endTime = session.startTime.addingTimeInterval(3600)
        session.summary = "Did stuff"
        session.notes = ["note1", "note2"]
        session.commits = ["abc123 Fix bug"]

        let encoder = DateFormatting.makeEncoder()
        let decoder = DateFormatting.makeDecoder()

        let data = try encoder.encode(session)
        let decoded = try decoder.decode(Session.self, from: data)

        #expect(decoded.id == session.id)
        #expect(decoded.project == session.project)
        #expect(decoded.summary == session.summary)
        #expect(decoded.notes == session.notes)
        #expect(decoded.commits == session.commits)
        #expect(decoded.isActive == false)
    }
}

@Suite("ProjectConfig Model Tests")
struct ProjectConfigModelTests {
    @Test("Add returns true for new project")
    func addNew() {
        var config = ProjectConfig()
        #expect(config.add("Test") == true)
        #expect(config.projects == ["Test"])
    }

    @Test("Add returns false for duplicate")
    func addDuplicate() {
        var config = ProjectConfig()
        _ = config.add("Test")
        #expect(config.add("Test") == false)
    }

    @Test("Remove returns true for existing")
    func removeExisting() {
        var config = ProjectConfig()
        _ = config.add("Test")
        #expect(config.remove("Test") == true)
        #expect(config.projects.isEmpty)
    }

    @Test("Remove returns false for non-existent")
    func removeNonExistent() {
        var config = ProjectConfig()
        #expect(config.remove("Ghost") == false)
    }

    @Test("Validate checks membership")
    func validate() {
        var config = ProjectConfig()
        _ = config.add("Test")
        #expect(config.validate("Test") == true)
        #expect(config.validate("Other") == false)
    }
}

@Suite("InvoiceData Model Tests")
struct InvoiceDataModelTests {
    @Test("Total hours sums line items")
    func totalHours() {
        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test",
            client: "Client",
            fromDate: Date(),
            toDate: Date(),
            hourlyRate: 100,
            lineItems: [
                InvoiceLineItem(date: Date(), hours: 2.5, description: "Work A"),
                InvoiceLineItem(date: Date(), hours: 3.0, description: "Work B"),
            ]
        )
        #expect(invoice.totalHours == 5.5)
    }

    @Test("Total amount is hours times rate")
    func totalAmount() {
        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test",
            client: "Client",
            fromDate: Date(),
            toDate: Date(),
            hourlyRate: 150,
            lineItems: [
                InvoiceLineItem(date: Date(), hours: 4.0, description: "Work"),
            ]
        )
        #expect(invoice.totalAmount == 600.0)
    }

    @Test("Total amount sums across multiple line items")
    func totalAmountMultipleItems() {
        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test",
            client: "Client",
            fromDate: Date(),
            toDate: Date(),
            hourlyRate: 125,
            lineItems: [
                InvoiceLineItem(date: Date(), hours: 2.0, description: "Day 1"),
                InvoiceLineItem(date: Date(), hours: 3.5, description: "Day 2"),
                InvoiceLineItem(date: Date(), hours: 1.25, description: "Day 3"),
            ]
        )
        #expect(invoice.totalHours == 6.75)
        #expect(invoice.totalAmount == 843.75)
    }

    @Test("Empty line items gives zero totals")
    func emptyLineItems() {
        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test",
            client: "Client",
            fromDate: Date(),
            toDate: Date(),
            hourlyRate: 100,
            lineItems: []
        )
        #expect(invoice.totalHours == 0)
        #expect(invoice.totalAmount == 0)
    }
}
