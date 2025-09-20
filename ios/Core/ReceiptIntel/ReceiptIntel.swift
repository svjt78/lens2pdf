import Foundation

public enum ReceiptIntelError: Error {
    case unableToExtract
}

public struct ReceiptExtraction {
    public var vendor: String?
    public var date: Date?
    public var subtotal: Decimal?
    public var tax: Decimal?
    public var total: Decimal?
    public var paymentMethod: String?
    public var last4: String?
    public init(vendor: String? = nil,
                date: Date? = nil,
                subtotal: Decimal? = nil,
                tax: Decimal? = nil,
                total: Decimal? = nil,
                paymentMethod: String? = nil,
                last4: String? = nil) {
        self.vendor = vendor
        self.date = date
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.paymentMethod = paymentMethod
        self.last4 = last4
    }
}

public enum ReceiptIntel {
    // US English date formats common on receipts
    private static let dateFormats = [
        "MM/dd/yyyy", "MM/dd/yy", "M/d/yy", "M/d/yyyy",
        "MMM d, yyyy", "MMMM d, yyyy", "yyyy-MM-dd"
    ]

    public static func extract(from text: String) -> ReceiptExtraction {
        let normalized = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        let lines = normalized.components(separatedBy: .newlines)

        let date = detectDate(in: normalized)
        let amounts = detectAmounts(in: normalized)
        let (payment, last4) = detectPayment(in: normalized)
        let vendor = detectVendor(lines: lines)

        return ReceiptExtraction(
            vendor: vendor,
            date: date,
            subtotal: amounts.subtotal,
            tax: amounts.tax,
            total: amounts.total,
            paymentMethod: payment,
            last4: last4
        )
    }

    public static func suggestFileName(from extraction: ReceiptExtraction, creationDate: Date = Date()) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: extraction.date ?? creationDate)
        let vendor = (extraction.vendor ?? "Receipt").replacingOccurrences(of: " ", with: "-")
        let currencySymbol = "$"
        let total = extraction.total.map { Self.formatAmount($0) } ?? ""
        let totalPart = total.isEmpty ? "" : "_\(currencySymbol)\(total)"
        return "\(dateStr)_\(vendor)\(totalPart).pdf"
    }

    // MARK: - Helpers
    private static func detectDate(in text: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in dateFormats {
            df.dateFormat = fmt
            if let match = firstMatch(regex: #"\b(\d{1,2}/\d{1,2}/\d{2,4}|\w{3,9} \d{1,2}, \d{4}|\d{4}-\d{2}-\d{2})\b"#, in: text) {
                if let d = df.date(from: match) { return d }
            }
        }
        return nil
    }

    private static func detectAmounts(in text: String) -> (subtotal: Decimal?, tax: Decimal?, total: Decimal?) {
        // Look for lines with Subtotal/Tax/Total and capture nearest amount
        func parse(_ str: String) -> Decimal? {
            let cleaned = str.replacingOccurrences(of: ",", with: "")
            return Decimal(string: cleaned)
        }
        var subtotal: Decimal?
        var tax: Decimal?
        var total: Decimal?

        let lines = text.components(separatedBy: .newlines)
        for l in lines {
            let lower = l.lowercased()
            if subtotal == nil, lower.contains("subtotal") || lower.contains("sub-total") {
                if let amt = firstMatch(regex: #"(\d+[\d,]*\.\d{2})"#, in: l) { subtotal = parse(amt) }
            }
            if tax == nil, lower.contains("tax") {
                if let amt = firstMatch(regex: #"(\d+[\d,]*\.\d{2})"#, in: l) { tax = parse(amt) }
            }
            if lower.contains("total") || lower.contains("amount due") {
                if let amt = firstMatch(regex: #"(\d+[\d,]*\.\d{2})"#, in: l) { total = parse(amt) }
            }
        }

        // Fallback: pick the largest currency value as total
        if total == nil {
            let currencyMatches = matches(regex: #"(\d+[\d,]*\.\d{2})"#, in: text)
            let decimals = currencyMatches.compactMap { Decimal(string: $0.replacingOccurrences(of: ",", with: "")) }
            if let maxVal = decimals.max() { total = maxVal }
        }
        return (subtotal, tax, total)
    }

    private static func detectPayment(in text: String) -> (method: String?, last4: String?) {
        // Visa|Mastercard|Amex with last 4 digits
        if let card = firstMatch(regex: #"\b(Visa|Mastercard|MasterCard|Amex|American Express|Discover)\b"#, in: text) {
            let last4 = firstMatch(regex: #"(?:\*{2,}|x{2,}|XXXX|####)?\s*(\d{4})\b"#, in: text)
            return (card, last4)
        }
        return (nil, nil)
    }

    private static func detectVendor(lines: [String]) -> String? {
        // Heuristic: first non-empty line with letter count > 2 and not a date/amount
        for l in lines.prefix(8) { // focus on header
            let trimmed = l.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 2 else { continue }
            if firstMatch(regex: #"\d{1,2}/\d{1,2}/\d{2,4}|\d+\.\d{2}"#, in: trimmed) != nil { continue }
            // Remove address-like lines
            if trimmed.range(of: #"\d+\s+\w+\s+(St|Ave|Rd|Blvd|Dr)"#, options: .regularExpression) != nil { continue }
            return trimmed
        }
        return nil
    }

    private static func firstMatch(regex: String, in text: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: regex, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = r.firstMatch(in: text, options: [], range: range) else { return nil }
        guard m.numberOfRanges > 1 else {
            return String(text[Range(m.range, in: text)!])
        }
        if let mr = Range(m.range(at: 1), in: text) {
            return String(text[mr])
        }
        return nil
    }

    private static func matches(regex: String, in text: String) -> [String] {
        guard let r = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return r.matches(in: text, options: [], range: range).compactMap { m in
            if m.numberOfRanges > 1, let mr = Range(m.range(at: 1), in: text) {
                return String(text[mr])
            } else if let rr = Range(m.range, in: text) {
                return String(text[rr])
            }
            return nil
        }
    }

    private static func formatAmount(_ d: Decimal) -> String {
        let ns = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: ns) ?? ns.stringValue
    }
}

