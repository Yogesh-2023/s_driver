class SocketEvents {
  const SocketEvents._();

  // General Connection Status & Server Events
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String connectError = 'connect_error';
  static const String error = 'error';
  static const String socketReady = 'socket:ready';
  static const String stateSync = 'state:sync';
  static const String socketError = 'socket:error';
  static const String stateSyncRequest = 'state:sync:request';

  // Canonical Driver Protocol Events
  static const String driverOnline = 'driver:online';
  static const String driverGoOnline = 'driver:go-online';
  static const String driverOffline = 'driver:offline';
  static const String driverGoOffline = 'driver:go-offline';
  static const String driverLocationUpdateCanonical = 'driver:location:update';
  static const String dispatchAccept = 'dispatch:accept';
  static const String dispatchReject = 'dispatch:reject';
  static const String driverHeadingToPickup = 'driver:heading-to-pickup';
  static const String driverArrivedCanonical = 'driver:arrived';
  static const String tripStart = 'trip:start';
  static const String tripComplete = 'trip:complete';
  static const String driverHeartbeat = 'driver:heartbeat';

  // Customer Protocol Events
  static const String bookingTrack = 'booking:track';
  static const String bookingUntrack = 'booking:untrack';
  static const String bookingCancel = 'booking:cancel';

  // Shared Protocol Events
  static const String sosCreate = 'sos:create';
  static const String chatJoin = 'chat:join';
  static const String chatSend = 'chat:send';

  // Admin Subscribed Events (Server Push)
  static const String adminDriverAvailabilityUpdated =
      'admin:driver:availability-updated';
  static const String adminDriverLocationUpdated =
      'admin:driver:location-updated';
  static const String adminTripLocationUpdated = 'admin:trip:location-updated';

  // ==========================================
  // PASSENGER RIDE FLOW
  // ==========================================

  // Emits (Driver Side)
  static const String acceptTrip = 'ACCEPT_TRIP';
  static const String rejectTrip = 'REJECT_TRIP';
  static const String cancelTrip = 'CANCEL_TRIP';
  static const String driverLocationUpdate = 'DRIVER_LOCATION_UPDATE';
  static const String startTrip = 'START_TRIP';
  static const String endTrip = 'END_TRIP';

  // Canonical Driver Real-time Dispatch Events
  static const String dispatchOfferCanonical = 'dispatch:offer';
  static const String dispatchOffer = 'dispatch_offer';
  static const String bookingCancelled = 'booking_cancelled';
  static const String bookingCanceledAlias = 'booking_canceled';

  // Listens
  static const String driverOnlineSuccess = 'driver:online:success';
  static const String newTripRequest = 'NEW_TRIP_REQUEST';
  static const String tripAccepted = 'TRIP_ACCEPTED';
  static const String tripAcceptError = 'TRIP_ACCEPT_ERROR';
  static const String driverFound = 'DRIVER_FOUND';
  static const String driverLocation = 'DRIVER_LOCATION';
  static const String driverArrived = 'DRIVER_ARRIVED';
  static const String tripStarted = 'TRIP_STARTED';
  static const String tripCompleted = 'TRIP_COMPLETED';
  static const String tripCancelled = 'TRIP_CANCELLED';
  static const String tripCancelledByUser = 'TRIP_CANCELLED_BY_USER';
  static const String tripRequestExpired = 'TRIP_REQUEST_EXPIRED';
  static const String paymentCompleted = 'PAYMENT_COMPLETED';

  // ==========================================
  // GOODS BOOKING FLOW
  // ==========================================

  // Emits (Driver Side)
  static const String goodsBookingAccept = 'goods:booking:accept';
  static const String goodsBookingAcceptSuccess =
      'goods:booking:accept:success';
  static const String goodsBookingAcceptError = 'goods:booking:accept:error';
  static const String goodsBookingAccepted = 'goods.booking.accepted';
  static const String goodsRequestAccepted = 'goods.request.accepted';
  static const String goodsError = 'goods.error';
  static const String goodsBookingCancel = 'goods:booking:cancel';
  static const String goodsBookingRequestSent = 'goods.booking.request.sent';
  static const String goodsBookingRequestSentAlias =
      'goods:booking:request:sent';
  static const String goodsRequestNew = 'goods.request.new';
  static const String goodsBookingRequestTimeout =
      'goods.booking.request.timeout';
  static const String goodsBookingRequestExpired =
      'goods.booking.request.expired';
  static const String goodsDriverArrivedPickup = 'goods:driver:arrived_pickup';
  static const String goodsPickupVerify = 'goods:pickup:verify';
  static const String goodsBookingStart = 'goods:booking:start';
  static const String goodsDeliveryVerify = 'goods:delivery:verify';
  static const String goodsPaymentComplete = 'goods:payment:complete';
  static const String goodsBookingComplete = 'goods:booking:complete';

  // Listens (User Side & Shared)
  static const String goodsCustomerBookingCreated =
      'goods.customer.booking.created';
  static const String goodsBookingCreated = 'goods.booking.created';
  static const String goodsDriverAssigned = 'goods.driver.assigned';
  static const String goodsBookingCancelled = 'goods.booking.cancelled';
  static const String goodsPickupOtpSent = 'goods.pickup.otp.sent';
  static const String goodsDriverArrived = 'goods.driver.arrived';
  static const String goodsPickupOtpVerified = 'goods.pickup.otp.verified';
  static const String goodsTripStarted = 'goods.trip.started';
  static const String goodsLocationUpdated = 'goods.location.updated';
  static const String goodsDriverReachedDestination =
      'goods.driver.reached.destination';
  static const String goodsDeliveryOtpSent = 'goods.delivery.otp.sent';
  static const String goodsDeliveryOtpVerified = 'goods.delivery.otp.verified';
  static const String goodsTripEnded = 'goods.trip.ended';
  static const String goodsPaymentCompleted = 'goods.payment.completed';
  static const String goodsCompleted = 'goods.completed';
}
