import Foundation

public struct Receipt: Identifiable, Codable, Equatable {
    public struct Money: Codable, Equatable {
        public var amount: Decimal?
        public var currency: String // e.g. "USD"

        public init(amount: Decimal?, currency: String = "USD") {
            self.amount = amount
            self.currency = currency
        }
    }

    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date

    public var vendor: String?
    public var date: Date?
    public var subtotal: Money
    public var tax: Money
    public var total: Money
    public var paymentMethod: String?
    public var last4: String?
    public var tags: [String]

    public var fileName: String?
    public var fileURL: URL?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        vendor: String? = nil,
        date: Date? = nil,
        subtotal: Money = .init(amount: nil),
        tax: Money = .init(amount: nil),
        total: Money = .init(amount: nil),
        paymentMethod: String? = nil,
        last4: String? = nil,
        tags: [String] = [],
        fileName: String? = nil,
        fileURL: URL? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.vendor = vendor
        self.date = date
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.paymentMethod = paymentMethod
        self.last4 = last4
        self.tags = tags
        self.fileName = fileName
        self.fileURL = fileURL
    }
}

public struct OCRBlock: Codable, Equatable {
    public var text: String
    public var boundingBox: CGRect
    public init(text: String, boundingBox: CGRect) {
        self.text = text
        self.boundingBox = boundingBox
    }
}

