import Foundation

/// Base analytics manager protocol.
/// Mirrors `IAnalyticsManager` from the Android implementation.
public protocol AnalyticsManager: AnyObject {
    var paymentMethod: String           { get }
    var couponCode: String              { get }
    var productType: String             { get }
    var totalPrice: Any                 { get }
    var bookingId: String               { get }
    var destinationCity: String         { get }
    var discountValue: Any              { get }
    var redeemedAmount: Any?            { get }
    var redeemedPoint: Any?             { get }
    var userTier: String?               { get }
    var bookingEarnedPoints: Any?       { get }
    var priceBeforeDiscount: Any        { get }
    var numberOfPaymentMethods: Int?    { get }
    var isAllPaidWithJawwakPoints: Bool { get }
    var defaultPaymentMethod: String?   { get }
    var numberOfAddons: Int             { get }
    var addons: Any?                    { get }
}

/// Flight-specific analytics manager protocol.
/// Mirrors `FlightAnalyticsManager` from the Android implementation.
public protocol FlightAnalyticsManager: AnalyticsManager {
    var homeWidget: String?             { get }
    var travellersCount: Int            { get }
    var originAirport: String           { get }
    var originCountry: String           { get }
    var originCity: String              { get }
    var originAirlines: String          { get }
    var destinationAirport: String      { get }
    var destinationCountry: String      { get }
    var destinationAirlines: String?    { get }
    var cabinClass: String              { get }
    var isRoundTrip: Bool               { get }
    var adultsCount: Int                { get }
    var childrenCount: Int              { get }
    var infantsCount: Int               { get }
    var totalTax: Any                   { get }
    var originDepartingDate: String?    { get }
    var originArrivalDate: String?      { get }
    var destinationDepartingDate: String? { get }
    var destinationArrivalDate: String? { get }
    var isDocumentPassport: Bool        { get }
    var travellerNationality: String    { get }
    var documentIssuingCountry: String  { get }
    var travellerBirthDate: String?     { get }
    var documentExpiryDate: String?     { get }
    var supplier: String                { get }
    var flightNumber: String            { get }
    var typeOfFlight: String            { get }
    var paidCurrency: String            { get }
    var onwardBrandedFare: String?      { get }
    var returnBrandedFare: String?      { get }
    var hasBaggage: Bool                { get }
    var hasSeats: Bool                  { get }
    var hasAutoCheckIn: Bool            { get }
    var ancillariesSkipped: Bool        { get }
}

/// Hotel-specific analytics manager protocol.
/// Mirrors `HotelAnalyticsManager` from the Android implementation.
public protocol HotelAnalyticsManager: AnalyticsManager {
    var homeWidget: String?             { get }
    var guestsCount: Int                { get }
    var adultsCount: Int                { get }
    var childrenCount: Int              { get }
    var totalTax: Any                   { get }
    var roomName: String                { get }
    var pricePerNight: Any              { get }
    var address: String                 { get }
    var countryName: String             { get }
    var cityName: String                { get }
    var name: String                    { get }
    var mainGuestNationality: String    { get }
    var mainGuestBirthDate: String?     { get }
    var nightsCount: Int                { get }
    var hotelId: String?                { get }
    var starRating: Any                 { get }
    var roomsCount: Int                 { get }
    var checkInDate: String?            { get }
    var checkOutDate: String?           { get }
    var paidCurrency: String            { get }
}
