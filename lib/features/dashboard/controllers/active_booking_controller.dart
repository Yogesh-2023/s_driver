import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../../data/api/api_constants.dart';

@immutable
class BookingCustomer {
  const BookingCustomer({
    required this.bookingId,
    required this.name,
    required this.phone,
    required this.imageUrl,
    required this.isOnline,
  });

  final String? bookingId;
  final String? name;
  final String? phone;
  final String? imageUrl;
  final bool? isOnline;

  factory BookingCustomer.fromBooking(Map<String, dynamic>? payload) {
    final source = payload ?? const <String, dynamic>{};
    final raw = _map(source['data']) ?? source;
    final booking =
        _map(raw['booking']) ?? _map(raw['trip']) ?? _map(raw['ride']) ?? raw;
    final customer =
        _map(raw['customer']) ??
        _map(raw['user']) ??
        _map(raw['rider']) ??
        _map(booking['customer']) ??
        _map(booking['user']) ??
        _map(booking['rider']) ??
        _map(booking['sender']) ??
        _map(raw['sender']) ??
        const <String, dynamic>{};
    final profile =
        _map(customer['profile']) ??
        _map(customer['userProfile']) ??
        _map(customer['customerProfile']) ??
        const <String, dynamic>{};

    final profileName = [
      profile['firstname'] ?? profile['firstName'],
      profile['lastname'] ?? profile['lastName'],
    ].map(_text).whereType<String>().join(' ');
    final name = _firstText([
      raw['customerName'],
      booking['customerName'],
      customer['displayName'],
      customer['name'],
      customer['fullName'],
      profileName,
    ]) ?? 'Customer';
    final image = _firstText([
      raw['customerImage'],
      booking['customerImage'],
      customer['profileImageUrl'],
      customer['profileImageURL'],
      customer['profileImage'],
      customer['profilePhoto'],
      customer['profilePicture'],
      customer['avatar'],
      customer['image'],
      customer['imageUrl'],
      profile['profileImageUrl'],
      profile['profileImageURL'],
      profile['profileImage'],
      profile['profilePhoto'],
      profile['profilePicture'],
      profile['avatar'],
      profile['image'],
      profile['imageUrl'],
    ]);

    return BookingCustomer(
      bookingId: _firstText([
        raw['tripId'],
        raw['bookingId'],
        booking['tripId'],
        booking['bookingId'],
        booking['id'],
        raw['id'],
      ]),
      name: name,
      phone: _firstText([
        raw['customerPhone'],
        booking['customerPhone'],
        customer['phone'],
        customer['phoneNumber'],
        customer['mobile'],
      ]),
      imageUrl: _normalizeImageUrl(image),
      isOnline: _readOnline([
        raw['customerOnline'],
        booking['customerOnline'],
        customer['isOnline'],
        customer['online'],
        customer['status'],
      ]),
    );
  }

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
  }

  static String? _firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = _text(value);
      if (text != null) return text;
    }
    return null;
  }

  static String? _normalizeImageUrl(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('http')) {
      final uri = Uri.tryParse(normalized);
      if (uri != null &&
          (uri.host == 'localhost' || uri.host == 'cars.carosa.in')) {
        return '${ApiConstants.fileBaseUrl}${uri.path}';
      }
      return normalized;
    }
    return '${ApiConstants.fileBaseUrl}${normalized.startsWith('/') ? '' : '/'}$normalized';
  }

  static bool? _readOnline(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is bool) return value;
      final normalized = value?.toString().trim().toLowerCase();
      if (normalized == 'online' ||
          normalized == 'active' ||
          normalized == '1') {
        return true;
      }
      if (normalized == 'offline' ||
          normalized == 'inactive' ||
          normalized == '0') {
        return false;
      }
    }
    return null;
  }
}

class ActiveBookingController extends GetxController {
  final customer = Rxn<BookingCustomer>();
  Map<String, dynamic>? _bookingPayload;
  int _updateVersion = 0;

  Map<String, dynamic>? get bookingPayload => _bookingPayload == null
      ? null
      : Map<String, dynamic>.unmodifiable(_bookingPayload!);

  void updateBooking(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return;
    final snapshot = Map<String, dynamic>.from(payload);
    final version = ++_updateVersion;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (version == _updateVersion && !isClosed) {
          _applyBooking(snapshot);
        }
      });
      return;
    }
    _applyBooking(snapshot);
  }

  void _applyBooking(Map<String, dynamic> payload) {
    final next = BookingCustomer.fromBooking(payload);
    final currentId = customer.value?.bookingId;
    if (currentId != null &&
        next.bookingId != null &&
        currentId != next.bookingId) {
      _bookingPayload = null;
      customer.value = null;
    }
    _bookingPayload = payload;
    customer.value = next;
  }

  void clear({String? bookingId}) {
    if (bookingId != null && customer.value?.bookingId != bookingId) return;
    _updateVersion++;
    _bookingPayload = null;
    customer.value = null;
  }
}

class BookingCustomerAvatar extends StatelessWidget {
  const BookingCustomerAvatar({
    super.key,
    required this.customer,
    required this.size,
  });

  final BookingCustomer? customer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Image.asset(
      'assets/images/profile.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
    final imageUrl = customer?.imageUrl;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: imageUrl == null
            ? placeholder
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, synchronous) {
                  if (synchronous || frame != null) {
                    return AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 180),
                      child: child,
                    );
                  }
                  return placeholder;
                },
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}
