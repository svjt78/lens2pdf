import Foundation

public enum CSVExporter {
    public static func exportMonthCSV(receipts: [Receipt], month: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: month)
        let filtered = receipts.filter { r in
            guard let d = r.date ?? r.createdAt as Date? else { return false }
            let dc = cal.dateComponents([.year, .month], from: d)
            return dc.year == comps.year && dc.month == comps.month
        }

        var rows: [String] = []
        // Header
        rows.append("Date,Vendor,Category,Subtotal,Tax,Total,PaymentMethod,Last4,Notes,FileName")

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        func fmt(_ d: Decimal?) -> String { d.map { NSDecimalNumber(decimal: $0).stringValue } ?? "" }
        func csvEsc(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") {
                let q = s.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(q)\""
            }
            return s
        }

        for r in filtered {
            let dateStr = df.string(from: r.date ?? r.createdAt)
            let vendor = csvEsc(r.vendor ?? "")
            let category = csvEsc(r.tags.first ?? "")
            let subtotal = fmt(r.subtotal.amount)
            let tax = fmt(r.tax.amount)
            let total = fmt(r.total.amount)
            let pm = csvEsc(r.paymentMethod ?? "")
            let last4 = csvEsc(r.last4 ?? "")
            let notes = ""
            let fname = csvEsc(r.fileName ?? "")
            rows.append([dateStr,vendor,category,subtotal,tax,total,pm,last4,notes,fname].joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }
}

