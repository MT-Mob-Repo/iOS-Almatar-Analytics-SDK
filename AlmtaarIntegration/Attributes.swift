import Foundation

/// All analytics property key constants.
/// Mirrors `AnalyticsManager.Attributes` from the original Mixpanel integration.
public enum Attributes {

    // MARK: - User / profile
    public static let userCountry             = "user_country"
    public static let market                  = "Market"
    public static let email                   = "$email"
    public static let firstName               = "$first_name"
    public static let lastName                = "$last_name"
    public static let phone                   = "$phone"
    public static let country                 = "$country"
    public static let language                = "$language"
    public static let currency                = "currency"
    public static let nationality             = "nationality"
    public static let tier                    = "tier"

    // MARK: - Loyalty
    public static let earnedPoint             = "earned_point"
    public static let redeemedPoint           = "redeemed_point"
    public static let redeemedValue           = "redeemed_value"
    public static let pointAll                = "point_all"

    // MARK: - Booking shared
    public static let bookingId               = "booking_id"
    public static let productType             = "product_type"
    public static let totalPrice              = "total_price"
    public static let taxes                   = "taxes"
    public static let discountValue           = "discount_value"
    public static let priceBeforeDiscount     = "price_before_discount"
    public static let couponCode              = "coupon_code"
    public static let paymentMode             = "payment_mode"
    public static let defaultPayment          = "default_payment"
    public static let numberOfPaymentMethods  = "number_of_payment_methods"

    // MARK: - Flight
    public static let originAirport           = "origin_airport"
    public static let originCountry           = "origin_country"
    public static let originCity              = "origin_city"
    public static let destinationAirport      = "destination_airport"
    public static let destinationCountry      = "destination_country"
    public static let destinationCity         = "destination_city"
    public static let departureFlightAirlines = "departure_flight_airlines"
    public static let returningFlightAirlines = "returning_flight_airlines"
    public static let travelClass             = "travel_class"
    public static let isReturnBooked          = "is_return_booked"
    public static let flightType              = "flight_type"
    public static let flightNumber            = "flight_number"
    public static let supplier                = "supplier"
    public static let departingDepartureDate  = "departing_departure_date"
    public static let departingArrivalDate    = "departing_arrival_date"
    public static let returningDepartureDate  = "returning_departure_date"
    public static let returningArrivalDate    = "returning_arrival_date"
    public static let onwardBrandedFare       = "onward_branded_fare"
    public static let returnBrandedFare       = "return_branded_fare"
    public static let isPassport              = "is_passport"
    public static let issuingCountry          = "issuing_country"
    public static let expiryDate              = "expiry_date"

    // MARK: - Travellers
    public static let noOfTravellers          = "no_of_travellers"
    public static let adults                  = "adults"
    public static let children               = "children"
    public static let infants                 = "infants"
    public static let dateOfBirth             = "date_of_birth"

    // MARK: - Ancillaries / add-ons
    public static let hasBaggage              = "has_baggage"
    public static let hasSeat                 = "has_seat"
    public static let hasAutoCheckIn          = "has_auto_check_in"
    public static let skipAncillaries         = "skip_ancillaries"
    public static let addOns                  = "add_ons"
    public static let numberOfAddons          = "number_of_addons"
    public static let skipAddons              = "skip_addons"

    // MARK: - Hotel
    public static let hotelName               = "hotel_name"
    public static let hotelId                 = "hotel_id"
    public static let location                = "location"
    public static let city                    = "city"
    public static let starRating              = "star_rating"
    public static let roomType                = "room_type"
    public static let noOfRooms               = "no_of_rooms"
    public static let noOfNights              = "no_of_nights"
    public static let noOfGuests              = "no_of_guests"
    public static let pricePerNight           = "price_per_night"
    public static let checkInDate             = "check_in_date"
    public static let checkOutDate            = "check_out_date"

    // MARK: - Home / referral
    public static let ref                     = "ref"
    public static let widget                  = "widget"
}
