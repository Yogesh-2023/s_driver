import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../services/socket/socket_service.dart';
import '../../services/socket/socket_events.dart';
import 'controllers/active_booking_controller.dart';
import 'customer_call_screen.dart';

class CustomerChatScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;

  const CustomerChatScreen({super.key, this.requestData});

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final Color themeColor = const Color(0xFF00ABE4);
  final Color lightThemeColor = const Color(0xFFE6F7FD);
  final Color chatBgColor = const Color(0xFFE4ECEF);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  final ActiveBookingController _booking = Get.find<ActiveBookingController>();
  bool _isLoadingHistory = true;
  String? _chatError;
  Timer? _historyTimeout;

  String? get tripId =>
      BookingCustomer.fromBooking(widget.requestData).bookingId;

  @override
  void initState() {
    super.initState();
    _booking.updateBooking(widget.requestData);
    _setupSocketListeners();
  }

  @override
  void didUpdateWidget(covariant CustomerChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTripId = BookingCustomer.fromBooking(
      oldWidget.requestData,
    ).bookingId;
    _booking.updateBooking(widget.requestData);
    if (oldTripId != tripId) {
      SocketService.to.stopListening('CHAT_HISTORY', _onChatHistory);
      SocketService.to.stopListening('RECEIVE_MESSAGE', _onMessageReceived);
      _messages.clear();
      _isLoadingHistory = true;
      _chatError = null;
      _setupSocketListeners();
    }
  }

  void _setupSocketListeners() {
    if (tripId == null) {
      _isLoadingHistory = false;
      _chatError = 'Booking details are unavailable.';
      return;
    }

    // Request chat history & join room
    SocketService.to.joinChat(bookingId: tripId!);
    final requested = SocketService.to.emitEvent('TRIP_CHAT', {
      'tripId': tripId,
    });
    if (!requested) {
      _isLoadingHistory = false;
      _chatError = 'Chat is unavailable while disconnected.';
    } else {
      _historyTimeout?.cancel();
      _historyTimeout = Timer(const Duration(seconds: 8), () {
        if (!mounted || !_isLoadingHistory) return;
        setState(() {
          _isLoadingHistory = false;
          _chatError = 'Chat history could not be loaded. Please try again.';
        });
      });
    }

    SocketService.to.listenTo('CHAT_HISTORY', _onChatHistory);
    SocketService.to.listenTo('RECEIVE_MESSAGE', _onMessageReceived);
  }

  bool _isCurrentTrip(Map payload) {
    final payloadTripId =
        payload['tripId']?.toString() ??
        payload['bookingId']?.toString() ??
        (payload['booking'] is Map
            ? payload['booking']['id']?.toString()
            : null);
    return payloadTripId == null || payloadTripId == tripId;
  }

  void _onChatHistory(dynamic data) {
    if (!mounted) return;
    final payload = (data is List && data.isNotEmpty) ? data.first : data;
    if (payload is! Map || !_isCurrentTrip(payload)) return;
    _historyTimeout?.cancel();
    final messages = payload['messages'];
    setState(() {
      _isLoadingHistory = false;
      _chatError = null;
      _messages.clear();
      if (messages is List) {
        for (final message in messages.whereType<Map>()) {
          final role = message['senderRole']?.toString().toLowerCase();
          _messages.add({
            'sender': role == 'driver' ? 'user' : 'customer',
            'text': message['message']?.toString() ?? '',
            'time': _localMessageTime(message['createdAt']),
          });
        }
      }
    });
    _scrollToBottom();
  }

  void _onMessageReceived(dynamic data) {
    if (!mounted) return;
    final payload = (data is List && data.isNotEmpty) ? data.first : data;
    if (payload is! Map ||
        !_isCurrentTrip(payload) ||
        payload['message'] == null) {
      return;
    }
    setState(() {
      final role = payload['senderRole']?.toString().toLowerCase();
      _messages.add({
        'sender': role == 'driver' ? 'user' : 'customer',
        'text': payload['message'].toString(),
        'time': _localMessageTime(payload['createdAt']),
      });
    });
    _scrollToBottom();
  }

  DateTime _localMessageTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    SocketService.to.stopListening('CHAT_HISTORY', _onChatHistory);
    SocketService.to.stopListening('RECEIVE_MESSAGE', _onMessageReceived);
    _historyTimeout?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || tripId == null) return;

    final clientMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    SocketService.to.sendChat(
      bookingId: tripId!,
      message: text,
      clientMessageId: clientMsgId,
    );
    SocketService.to.emitEvent('TRIP_CHAT', {
      'tripId': tripId,
      'message': text,
    });

    _messageController.clear();
  }


  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _messages.add({
            'sender': 'user',
            'text': '',
            'time': DateTime.now(),
            'attachment': image.path,
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildChatBody()),
          _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12.h,
        bottom: 12.h,
        left: 16.w,
        right: 16.w,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAE1),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFEF9E), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(20.r),
            child: Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20.sp,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Obx(() {
              final customer = _booking.customer.value;
              return Row(
                children: [
                  BookingCustomerAvatar(customer: customer, size: 42.r),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer?.name ?? 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        if (customer?.isOnline != null)
                          Text(
                            customer!.isOnline! ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 12.sp,
                              color: customer.isOnline!
                                  ? const Color(0xFF15803D)
                                  : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call customer',
                    onPressed: customer?.phone == null
                        ? null
                        : () => Get.to(
                            () => CustomerCallScreen(
                              requestData: widget.requestData,
                            ),
                          ),
                    icon: const Icon(Icons.call_outlined),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBody() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chatError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            _chatError!,
            textAlign: TextAlign.center,
            style: AppFonts.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 36.w),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 32.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: lightThemeColor,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: themeColor,
                  size: 28.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Start a conversation',
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Send a message to the customer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.fontFamily,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildDateDivider('TODAY');
        }

        final msgIndex = _messages.length - 1 - index;
        final msg = _messages[msgIndex];
        final bool isUser = msg['sender'] == 'user';
        final String timeString = DateFormat(
          'hh:mm a',
        ).format(_localMessageTime(msg['time']));

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 4.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFFBCE7F6) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isUser ? 20.r : 0),
                topRight: Radius.circular(isUser ? 0 : 20.r),
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg['attachment'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.file(
                      File(msg['attachment']),
                      width: 200.w,
                      height: 150.h,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],
                if (msg['text'] != null && msg['text'].isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      msg['text'],
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        color: const Color(0xFF212529),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 9.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateDivider(String label) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: const Color(0xFFD6E2E6),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.fontFamily,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReplies() {
    final List<String> quickReplies = [
      "I have arrived",
      "Stuck in traffic",
      "Where exactly are you?",
      "Ok",
    ];

    return Container(
      height: 40.h,
      margin: EdgeInsets.only(top: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: quickReplies.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _messageController.text = quickReplies[index];
              _sendMessage();
            },
            child: Container(
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: themeColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  quickReplies[index],
                  style: TextStyle(
                    fontFamily: AppFonts.fontFamily,
                    fontSize: 12.sp,
                    color: themeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 8.w,
        right: 8.w,
        top: 8.h,
        bottom: MediaQuery.of(context).padding.bottom + 8.h,
      ),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.insert_emoticon_outlined,
                      color: Colors.grey.shade500,
                      size: 22.sp,
                    ),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontFamily: AppFonts.fontFamily,
                        fontSize: 14.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: TextStyle(
                          fontFamily: AppFonts.fontFamily,
                          fontSize: 14.sp,
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: Colors.grey.shade500,
                      size: 20.sp,
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.grey.shade500,
                      size: 20.sp,
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                  SizedBox(width: 4.w),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.25),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
