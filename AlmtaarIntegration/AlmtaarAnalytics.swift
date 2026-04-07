import Foundation
import LightAnalytics

/// Drop-in replacement for `MixPanelAnalytics` using the LightAnalytics SDK.
///
/// Every method signature mirrors the original Mixpanel class so call sites
/// need only change the class name — no event names, no property keys, no
/// attribute helpers change.
///
/// Migration:
///   MixPanelAnalytics.trackEvent(name, attrs)  →  AlmtaarAnalytics.trackEvent(name, attrs)
///   authorizeMixPanel(mixpanel)                →  AlmtaarAnalytics.authorizeUser(profile)
///   getFlightBookedAttributes(manager)         →  AlmtaarAnalytics.getFlightBookedAttributes(manager)
///
/// Key difference vs Mixpanel:
///   `authorizeUser` is called ONCE at sign-in (not inside every trackEvent).
///   Profile fields become super properties merged into every subsequent event.
public enum AlmtaarAnalytics {

    // MARK: - Core

    /// Replacement for `MixPanelAnalytics.trackEvent(_:attributes:)`.
    /// Injects `user_country` and `Market` from `UserContext` automatically.
    public static func trackEvent(_ eventName: String, attributes: [String: Any]) {
        var props = attributes
        props[Attributes.userCountry] = UserContext.originCountry
        props[Attributes.market]      = UserContext.marketCountry
        Analytics.track(eventName, properties: props)
    }

    /// Replacement for the private `authorizeMixPanel`. Call once after sign-in.
    /// Guests (id == "0" or empty) are tracked anonymously — identify is skipped.
    public static func authorizeUser(_ profile: UserProfile) {
        if !profile.id.isEmpty && profile.id != "0" {
            Analytics.identify(profile.id)
        }
        var peopleProps: [String: Any] = [
            Attributes.email:     profile.email,
            Attributes.firstName: profile.firstName,
            Attributes.lastName:  profile.lastName,
            Attributes.phone:     "\(profile.phonePrefix)\(profile.phoneNumber)",
            Attributes.country:   profile.nationality,
            Attributes.language:  profile.language,
        ]
        if let currency = profile.currency {
            peopleProps[Attributes.currency] = currency
        }
        Analytics.registerSuperProperties(peopleProps)
    }

    /// Call on sign-out. Flushes pending events then clears identity + super properties.
    public static func deauthorizeUser() {
        Analytics.flush()
        Analytics.reset()
    }

    // MARK: - Flight attribute helpers

    public static func getBundleSelectedAttributes(_ manager: FlightAnalyticsManager) -> [String: Any] {
        var attrs: [String: Any] = [:]
        if let v = manager.onwardBrandedFare  { attrs[Attributes.onwardBrandedFare] = v }
        if let v = manager.returnBrandedFare  { attrs[Attributes.returnBrandedFare] = v }
        return attrs
    }

    public static func getAncillariesAttributes(_ manager: FlightAnalyticsManager) -> [String: Any] {
        [
            Attributes.hasBaggage:      manager.hasBaggage,
            Attributes.hasSeat:         manager.hasSeats,
            Attributes.hasAutoCheckIn:  manager.hasAutoCheckIn,
            Attributes.skipAncillaries: manager.ancillariesSkipped,
        ]
    }

    public static func getAddonsAttributes(_ manager: any AnalyticsManager, skipButtonClicked: Bool) -> [String: Any] {
        var attrs: [String: Any] = [
            Attributes.numberOfAddons: manager.numberOfAddons,
            Attributes.skipAddons:     skipButtonClicked || manager.numberOfAddons == 0,
        ]
        if let addons = manager.addons { attrs[Attributes.addOns] = addons }
        return attrs
    }

    public static func getFlightTravellerDetailsAttributes(_ manager: FlightAnalyticsManager) -> [String: Any] {
        var attrs: [String: Any] = [
            Attributes.noOfTravellers:          manager.travellersCount,
            Attributes.originAirport:           manager.originAirport,
            Attributes.originCountry:           manager.originCountry,
            Attributes.originCity:              manager.originCity,
            Attributes.departureFlightAirlines: manager.originAirlines,
            Attributes.destinationAirport:      manager.destinationAirport,
            Attributes.destinationCountry:      manager.destinationCountry,
            Attributes.travelClass:             manager.cabinClass,
            Attributes.isReturnBooked:          manager.isRoundTrip,
            Attributes.adults:                  manager.adultsCount,
            Attributes.children:                manager.childrenCount,
            Attributes.infants:                 manager.infantsCount,
            Attributes.totalPrice:              manager.totalPrice,
            Attributes.taxes:                   manager.totalTax,
            Attributes.isPassport:              manager.isDocumentPassport,
            Attributes.nationality:             manager.travellerNationality,
            Attributes.issuingCountry:          manager.documentIssuingCountry,
            Attributes.supplier:                manager.supplier,
            Attributes.flightNumber:            manager.flightNumber,
            Attributes.destinationCity:         manager.destinationCity,
        ]
        if let v = manager.destinationAirlines        { attrs[Attributes.returningFlightAirlines] = v }
        if let v = manager.originDepartingDate        { attrs[Attributes.departingDepartureDate]  = v }
        if let v = manager.originArrivalDate          { attrs[Attributes.departingArrivalDate]    = v }
        if let v = manager.destinationDepartingDate   { attrs[Attributes.returningDepartureDate]  = v }
        if let v = manager.destinationArrivalDate     { attrs[Attributes.returningArrivalDate]    = v }
        if let v = manager.travellerBirthDate         { attrs[Attributes.dateOfBirth]             = v }
        if let v = manager.documentExpiryDate         { attrs[Attributes.expiryDate]              = v }
        return attrs
    }

    public static func getFlightBookedAttributes(_ manager: FlightAnalyticsManager) -> [String: Any] {
        var attrs: [String: Any] = [
            Attributes.originAirport:           manager.originAirport,
            Attributes.originCountry:           manager.originCountry,
            Attributes.originCity:              manager.originCity,
            Attributes.departureFlightAirlines: manager.originAirlines,
            Attributes.destinationAirport:      manager.destinationAirport,
            Attributes.destinationCountry:      manager.destinationCountry,
            Attributes.destinationCity:         manager.destinationCity,
            Attributes.travelClass:             manager.cabinClass,
            Attributes.isReturnBooked:          manager.isRoundTrip,
            Attributes.adults:                  manager.adultsCount,
            Attributes.children:                manager.childrenCount,
            Attributes.infants:                 manager.infantsCount,
            Attributes.totalPrice:              manager.totalPrice,
            Attributes.taxes:                   manager.totalTax,
            Attributes.discountValue:           manager.discountValue,
            Attributes.couponCode:              manager.couponCode,
            Attributes.bookingId:               manager.bookingId,
            Attributes.supplier:                manager.supplier,
            Attributes.flightNumber:            manager.flightNumber,
            Attributes.redeemedValue:           manager.redeemedAmount,
            Attributes.currency:                manager.paidCurrency,
            Attributes.flightType:              manager.typeOfFlight,
            Attributes.numberOfAddons:          manager.numberOfAddons,
        ]
        if let v = manager.destinationAirlines        { attrs[Attributes.returningFlightAirlines] = v }
        if let v = manager.originDepartingDate        { attrs[Attributes.departingDepartureDate]  = v }
        if let v = manager.originArrivalDate          { attrs[Attributes.departingArrivalDate]    = v }
        if let v = manager.destinationDepartingDate   { attrs[Attributes.returningDepartureDate]  = v }
        if let v = manager.destinationArrivalDate     { attrs[Attributes.returningArrivalDate]    = v }
        if let v = manager.redeemedPoint              { attrs[Attributes.redeemedPoint]           = v }
        if let v = manager.userTier                   { attrs[Attributes.tier]                    = v }
        if let v = manager.bookingEarnedPoints        { attrs[Attributes.earnedPoint]             = v }
        if let v = manager.addons                     { attrs[Attributes.addOns]                  = v }
        return attrs
    }

    // MARK: - Hotel attribute helpers

    public static func getHotelGuestDetailsAttributes(_ manager: HotelAnalyticsManager) -> [String: Any] {
        var attrs: [String: Any] = [
            Attributes.noOfGuests:          manager.guestsCount,
            Attributes.adults:              manager.adultsCount,
            Attributes.children:            manager.childrenCount,
            Attributes.totalPrice:          manager.totalPrice,
            Attributes.taxes:               manager.totalTax,
            Attributes.roomType:            manager.roomName,
            Attributes.pricePerNight:       manager.pricePerNight,
            Attributes.location:            manager.address,
            Attributes.country:             manager.countryName,
            Attributes.city:               manager.cityName,
            Attributes.hotelName:           manager.name,
            Attributes.nationality:         manager.mainGuestNationality,
            Attributes.discountValue:       manager.discountValue,
            Attributes.priceBeforeDiscount: manager.priceBeforeDiscount,
            Attributes.noOfNights:          manager.nightsCount,
        ]
        if let v = manager.mainGuestBirthDate { attrs[Attributes.dateOfBirth] = v }
        if let v = manager.hotelId            { attrs[Attributes.hotelId]     = v }
        return attrs
    }

    public static func getHotelBookedAttributes(_ manager: HotelAnalyticsManager) -> [String: Any] {
        var attrs: [String: Any] = [
            Attributes.discountValue:       manager.discountValue,
            Attributes.totalPrice:          manager.totalPrice,
            Attributes.bookingId:           manager.bookingId,
            Attributes.couponCode:          manager.couponCode,
            Attributes.children:            manager.childrenCount,
            Attributes.adults:              manager.adultsCount,
            Attributes.hotelName:           manager.name,
            Attributes.location:            manager.address,
            Attributes.starRating:          manager.starRating,
            Attributes.country:             manager.countryName,
            Attributes.city:               manager.cityName,
            Attributes.noOfRooms:           manager.roomsCount,
            Attributes.noOfNights:          manager.nightsCount,
            Attributes.noOfGuests:          manager.guestsCount,
            Attributes.roomType:            manager.roomName,
            Attributes.priceBeforeDiscount: manager.priceBeforeDiscount,
            Attributes.pricePerNight:       manager.pricePerNight,
            Attributes.redeemedValue:       manager.redeemedAmount,
            Attributes.currency:            manager.paidCurrency,
            Attributes.numberOfAddons:      manager.numberOfAddons,
        ]
        if let v = manager.checkInDate        { attrs[Attributes.checkInDate]   = v }
        if let v = manager.checkOutDate       { attrs[Attributes.checkOutDate]  = v }
        if let v = manager.userTier           { attrs[Attributes.tier]          = v }
        if let v = manager.bookingEarnedPoints{ attrs[Attributes.earnedPoint]   = v }
        if let v = manager.redeemedPoint      { attrs[Attributes.redeemedPoint] = v }
        if let v = manager.hotelId            { attrs[Attributes.hotelId]       = v }
        if let v = manager.addons             { attrs[Attributes.addOns]        = v }
        return attrs
    }

    // MARK: - Checkout

    public static func getCheckoutCompletedAttributes(_ manager: any AnalyticsManager) -> [String: Any] {
        var attrs: [String: Any] = [
            Attributes.paymentMode:         manager.paymentMethod,
            Attributes.couponCode:          manager.couponCode,
            Attributes.productType:         manager.productType,
            Attributes.totalPrice:          manager.totalPrice,
            Attributes.bookingId:           manager.bookingId,
            Attributes.destinationCity:     manager.destinationCity,
            Attributes.discountValue:       manager.discountValue,
            Attributes.priceBeforeDiscount: manager.priceBeforeDiscount,
            Attributes.pointAll:            manager.isAllPaidWithJawwakPoints,
        ]
        if let v = manager.redeemedAmount         { attrs[Attributes.redeemedValue]          = v }
        if let v = manager.redeemedPoint          { attrs[Attributes.redeemedPoint]          = v }
        if let v = manager.userTier               { attrs[Attributes.tier]                   = v }
        if let v = manager.bookingEarnedPoints    { attrs[Attributes.earnedPoint]            = v }
        if let v = manager.numberOfPaymentMethods { attrs[Attributes.numberOfPaymentMethods] = v }
        if let v = manager.defaultPaymentMethod   { attrs[Attributes.defaultPayment]         = v }

        if let hotel = manager as? HotelAnalyticsManager {
            attrs[Attributes.hotelName]         = hotel.name
            attrs[Attributes.noOfTravellers]    = hotel.guestsCount
            attrs[Attributes.destinationCountry] = hotel.countryName
            attrs[Attributes.isReturnBooked]    = false
            attrs[Attributes.taxes]             = hotel.totalTax
            attrs[Attributes.numberOfAddons]    = hotel.numberOfAddons
            if let v = hotel.hotelId   { attrs[Attributes.hotelId] = v }
            if let v = hotel.addons    { attrs[Attributes.addOns]  = v }
        } else if let flight = manager as? FlightAnalyticsManager {
            attrs[Attributes.noOfTravellers]    = flight.travellersCount
            attrs[Attributes.originCountry]     = flight.originCountry
            attrs[Attributes.destinationCountry] = flight.destinationCountry
            attrs[Attributes.isReturnBooked]    = flight.isRoundTrip
            attrs[Attributes.supplier]          = flight.supplier
            attrs[Attributes.flightNumber]      = flight.flightNumber
            attrs[Attributes.originCity]        = flight.originCity
            attrs[Attributes.taxes]             = flight.totalTax
            attrs[Attributes.flightType]        = flight.typeOfFlight
            attrs[Attributes.numberOfAddons]    = flight.numberOfAddons
            if let v = flight.addons { attrs[Attributes.addOns] = v }
        }
        return attrs
    }

    // MARK: - Home widget helpers

    public static func addHomeAttributesToHotelsSearched(
        _ attributes: inout [String: Any],
        manager: HotelAnalyticsManager
    ) {
        guard let widget = manager.homeWidget else { return }
        attributes[Attributes.ref]    = "Home"
        attributes[Attributes.widget] = widget
    }

    public static func getHotelViewedAttributes(
        _ attributes: inout [String: Any],
        manager: HotelAnalyticsManager
    ) {
        guard let widget = manager.homeWidget else { return }
        attributes[Attributes.ref]    = "Home"
        attributes[Attributes.widget] = widget
    }

    public static func addHomeAttributesToFlightSearched(
        _ attributes: inout [String: Any],
        manager: FlightAnalyticsManager
    ) {
        guard let widget = manager.homeWidget else { return }
        attributes[Attributes.ref]    = "Home"
        attributes[Attributes.widget] = widget
    }
}
