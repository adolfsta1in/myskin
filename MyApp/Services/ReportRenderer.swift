import Foundation
import SwiftUI

/// Renders the doctor report to a PDF file (`ImageRenderer` → PDF context).
/// Text, charts and shapes stay vector; photos are embedded as images.
enum ReportRenderer {
    /// A4 width in points; the page is as tall as the report.
    static let pageWidth: CGFloat = 595

    enum RenderError: Error, LocalizedError {
        case couldNotCreatePDF

        var errorDescription: String? { "The PDF couldn't be created." }
    }

    /// Writes the PDF into the app's private export folder and returns its URL.
    static func makePDF(
        report: DoctorReport,
        weeklyItch: [DayValue],
        images: [String: UIImage],
        folder: URL = ExportFolder.url
    ) throws -> URL {
        let page = ReportPaper(report: report, weeklyItch: weeklyItch, images: images)
            .frame(width: pageWidth)
            .background(.white)
            .fontDesign(.rounded)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: nil)

        let url = try ExportFolder.prepare(folder).appending(path: "MySkin report \(fileDate(report.end)).pdf")
        var written = false
        renderer.render { size, render in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            render(context)
            context.endPDFPage()
            context.closePDF()
            written = true
        }
        guard written else { throw RenderError.couldNotCreatePDF }
        try ExportFolder.protect(url)
        return url
    }

    static func fileDate(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}

/// Temporary folder for files the user shares (PDF report, CSV). Inside the app container,
/// fully protected, never backed up; emptied before each export.
enum ExportFolder {
    static var url: URL { URL.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory) }

    /// Clears old exports and returns the folder.
    @discardableResult
    static func prepare(_ folder: URL = url) throws -> URL {
        let manager = FileManager.default
        if manager.fileExists(atPath: folder.path(percentEncoded: false)) {
            try manager.removeItem(at: folder)
        }
        try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = folder
        try excluded.setResourceValues(values)
        return folder
    }

    static func protect(_ file: URL) throws {
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path(percentEncoded: false))
    }

    static func clear(_ folder: URL = url) {
        try? FileManager.default.removeItem(at: folder)
    }
}
