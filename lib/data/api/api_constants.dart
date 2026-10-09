class ApiConstants {
  // Base URL
  static const String baseUrl = 'https://tuk.technogigz.co.in/api';
  static const String fileBaseUrl = 'https://tuk.technogigz.co.in';

  // Authentication Endpoints
  static const String requestOtp = '/v1/driver/auth/request-otp';
  static const String sendOtp = '/v1/driver/auth/send-otp';
  static const String verifyOtp = '/v1/driver/auth/verify-otp';
  static const String resendOtp = '/v1/driver/auth/resend-otp';
  static const String authMe = '/v1/driver/auth/me';
  static const String authSession = '/v1/driver/auth/session';
  static const String authSessions = '/v1/driver/auth/sessions';
  static String revokeSession(String sessionId) =>
      '/v1/driver/auth/sessions/$sessionId';
  static const String deleteAccount = '/v1/driver/auth/account';
  static const String logout = '/v1/driver/auth/logout';
  static const String logoutAll = '/v1/driver/auth/logout-all';
  static const String verifyDriverCode = '/auth/custom/verify-code/DRIVER';
  static const String registerDriver = '/auth/register';

  // Driver Endpoints & Profile
  static const String driverDashboard = '/v1/driver/dashboard';
  static const String driverAccountInfo = '/v1/driver/account-info';
  static const String driverVehicleInfo = '/v1/driver/vehicle-info';
  static const String createDriverProfile = '/v1/driver/profile';
  static const String updateDriverProfile = '/v1/driver/profile';
  static const String driverProfile = '/v1/driver/profile';
  static const String profileImageUploadUrl =
      '/v1/driver/profile/image/upload-url';
  static const String uploadProfileImage = '/v1/driver/profile/image';
  static const String deleteProfileImage = '/v1/driver/profile/image';
  static const String onboardingStatus = '/v1/driver/onboarding-status';
  static const String onboardingStatusCanonical =
      '/v1/driver/onboarding/status';
  static const String accountStatus = '/v1/driver/account/status';
  static const String createDriverVehicle = '/v1/driver/vehicles';
  static const String driverVehicles = '/v1/driver/vehicles';
  static const String updateDriverStatus = '/v1/driver/availability/online';
  static const String activeTrips = '/v1/driver/bookings/active';
  static const String ongoingTrips = '/v1/driver/bookings/active';
  static const String tripHistory = '/v1/driver/trip-history';

  static const String savePersonalInformation =
      '/driver/details/personal-information';
  static const String heartbeat = '/driver/details/heartbeat';
  static const String driverTickets = '/support/driver/tickets';
  static const String getDriverTickets = driverTickets;

  // Availability & Location Endpoints
  static const String availabilityOnline = '/v1/driver/availability/online';
  static const String availabilityOffline = '/v1/driver/availability/offline';
  static const String driverLocation = '/v1/driver/location';

  // Location Endpoints
  static const String locationsStates = '/v1/locations/states';
  static String locationsCities(String stateCode) =>
      '/v1/locations/states/$stateCode/cities';
  static String locationsPincode(String pincode) =>
      '/v1/locations/pincodes/$pincode';

  // Canonical Booking & Trip Lifecycle Endpoints
  static String acceptBooking(String id) => '/v1/driver/bookings/$id/accept';
  static String rejectBooking(String id) => '/v1/driver/bookings/$id/reject';
  static String arriveBooking(String id) => '/v1/driver/bookings/$id/arrived';
  static String startBooking(String id) => '/v1/driver/bookings/$id/start';
  static String completeBooking(String id) => '/v1/driver/bookings/$id/complete';
  static String verifyPickupOtp(String id) =>
      '/v1/driver/bookings/$id/pickup-otp/verify';
  static String cancelBooking(String id) => '/v1/driver/bookings/$id/cancel';
  static String confirmCashPayment(String id) =>
      '/v1/driver/bookings/$id/payment/cash-confirm';

  // Wallet & Earnings Endpoints
  static const String driverWallet = '/v1/driver/wallet';
  static const String earningsSummary = '/v1/driver/earnings/summary';
  static const String withdrawWallet = '/v1/driver/wallet/withdraw';

  // Driver Subscription Endpoints
  static const String subscriptionPlans = '/v1/driver/subscriptions/plans';
  static const String activeSubscription = '/v1/driver/subscriptions/active';
  static const String purchaseSubscription = '/v1/driver/subscriptions/purchase';
  static const String subscriptionHistory = '/v1/driver/subscriptions/history';
  static String subscriptionPlanDetails(String id) =>
      '/v1/driver/subscriptions/plans/$id';
  static String subscriptionDetails(String id) =>
      '/v1/driver/subscriptions/$id';
  static String subscriptionPaymentStatus(String id) =>
      '/v1/driver/subscriptions/$id/payment';
  static const String verifyPayment = '/v1/payments/verify';

  // Ride Action Endpoints
  static const String acceptRide = '/rides/driver/accept';
  static const String rejectRide = '/rides/driver/reject';
  static const String startRide = '/rides/driver/start';
  static const String completeRide = '/rides/driver/complete-cash';
  static const String arrivePickup = '/rides/driver/arrive';
  static const String carOptions = '/rides/car-options';
  static const String submitDriverReview = '/reviews/driver';

  // Goods Driver Endpoints
  static const String goodsBookings = '/v1/driver/bookings/active';
  static String acceptGoodsBooking(String id) => '/v1/driver/bookings/$id/accept';
  static String rejectGoodsBooking(String id) => '/v1/driver/bookings/$id/reject';
  static String arriveGoodsPickup(String id) => '/v1/driver/bookings/$id/arrived';
  static String verifyGoodsPickupOtp(String id) =>
      '/v1/driver/bookings/$id/pickup-otp/verify';
  static String startGoodsTrip(String id) => '/v1/driver/bookings/$id/start';
  static String updateGoodsLocation(String id) => '/v1/driver/location';
  static String reachGoodsDestination(String id) =>
      '/v1/driver/bookings/$id/arrived';
  static String verifyGoodsDeliveryOtp(String id) =>
      '/v1/driver/bookings/$id/delivery-otp/verify';
  static String completeGoodsBooking(String id) =>
      '/v1/driver/bookings/$id/complete';

  // Driver Support Ticket Endpoints
  static const String driverSupportCategories = '/v1/driver/support/categories';
  static const String driverSupportTickets = '/v1/driver/support/tickets';
  static const String driverSupportAttachments = '/v1/driver/support/attachments';
  static String driverSupportTicket(String ticketId) => '/v1/driver/support/tickets/$ticketId';
  static String driverSupportTicketMessages(String ticketId) => '/v1/driver/support/tickets/$ticketId/messages';
  static String driverSupportTicketMessagesRead(String ticketId) => '/v1/driver/support/tickets/$ticketId/messages/read';
  static String driverSupportTicketClose(String ticketId) => '/v1/driver/support/tickets/$ticketId/close';

  static String supportTicket(String base, String ticketId) =>
      '$base/$ticketId';
  static String supportTicketMessages(String base, String ticketId) =>
      '${supportTicket(base, ticketId)}/messages';
  static String supportTicketRead(String base, String ticketId) =>
      '${supportTicket(base, ticketId)}/messages/read';
  static String supportTicketClose(String base, String ticketId) =>
      '${supportTicket(base, ticketId)}/close';
  static String supportTicketReopen(String base, String ticketId) =>
      '${supportTicket(base, ticketId)}/reopen';

  // Driver KYC Endpoints
  static const String driverKycStatus = '/v1/driver/kyc/status';
  static const String driverKycDetails = '/v1/driver/kyc/details';
  static const String submitDriverKyc = '/v1/driver/kyc/submit';
  static const String uploadDriverKyc = '/v1/driver/kyc/upload';
  static const String vehicleOptions = '/v1/vehicles/options';
  static const String providerKycStatus = '/provider/kyc/status';
  static const String uploadProviderKyc = '/provider/kyc';
  static const String providerKycSubmitApproval = '/provider/kyc/submit';

  // Notification Endpoints
  static const String registerToken = '/v1/driver/device-tokens';
  static const String notificationToken = '/v1/driver/device-tokens';
  static const String notifications = '/v1/driver/notifications';
  static String notificationDetail(String id) => '/v1/driver/notifications/$id';
  static String markNotificationRead(String id) => '/v1/driver/notifications/$id/read';
  static String markNotificationUnread(String id) =>
      '/v1/driver/notifications/$id/unread';
  static const String markAllNotificationsRead = '/v1/driver/notifications/read-all';
  static const String unreadNotificationCount = '/v1/driver/notifications/unread-count';
  static const String notificationPreferences = '/v1/driver/notifications/preferences';
}
