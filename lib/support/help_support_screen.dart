import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../services/ticket_service.dart';
import 'raise_issue_screen.dart';
import 'ticket_chat_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, this.isProvider = false});

  final bool isProvider;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TicketService _ticketService = TicketService();
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final res = await _ticketService.getTickets(page: 1, limit: 30);
    if (!mounted) return;

    if (res != null) {
      final items = (res['items'] as List?) ?? [];
      setState(() {
        _tickets = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  (String, Color, Color) _getStatusChipStyle(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'OPEN':
        return ('Open', const Color(0xFF2563EB), const Color(0xFFEFF6FF));
      case 'IN_PROGRESS':
        return ('In Progress', const Color(0xFFD97706), const Color(0xFFFFFBEB));
      case 'WAITING_FOR_CUSTOMER':
        return ('Waiting for You', const Color(0xFF7C3AED), const Color(0xFFF5F3FF));
      case 'RESOLVED':
        return ('Resolved', const Color(0xFF16A34A), const Color(0xFFF0FDF4));
      case 'CLOSED':
        return ('Closed', const Color(0xFF64748B), const Color(0xFFF8FAFC));
      case 'ESCALATED':
        return ('Escalated', const Color(0xFFDC2626), const Color(0xFFFEF2F2));
      default:
        return (rawStatus, const Color(0xFF64748B), const Color(0xFFF8FAFC));
    }
  }

  String _formatRelativeDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF4),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeaderSection(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTickets,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Need Help Card Banner
                      _buildBannerCard(),
                      SizedBox(height: 20.h),

                      // Section Title & Raise Ticket CTA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Driver Tickets',
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final created = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RaiseIssueScreen(isProvider: widget.isProvider),
                                ),
                              );
                              if (created == true) _loadTickets();
                            },
                            icon: Icon(Icons.add_circle_rounded, size: 16.sp, color: Colors.black),
                            label: Text(
                              'Raise Ticket',
                              style: TextStyle(
                                fontFamily: AppFonts.fontFamily,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // List / Skeleton / Empty State
                      if (_isLoading)
                        _buildSkeletonList()
                      else if (_hasError)
                        _buildErrorState()
                      else if (_tickets.isEmpty)
                        _buildNoTicketsPlaceholder()
                      else
                        _buildTicketsList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFCC00), Color(0xFFFFB020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.support_agent_rounded, color: const Color(0xFFFFCC00), size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Support 24x7',
                  style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Facing trip or payment issues? Raise a ticket now.',
                  style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: EdgeInsets.only(bottom: 10.h),
          height: 70.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: const Color(0xFFDC2626), size: 32.sp),
          SizedBox(height: 8.h),
          Text('Failed to load support tickets', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B))),
          SizedBox(height: 10.h),
          ElevatedButton(
            onPressed: _loadTickets,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTicketsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 48.sp),
          SizedBox(height: 14.h),
          Text(
            'No tickets yet',
            style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 16.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(height: 6.h),
          Text(
            'Need help with a ride or payout? Raise a ticket and our support team will assist you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 12.sp, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final ticketId = (ticket['id'] ?? '').toString();
        final ticketNumber = (ticket['ticketNumber'] ?? ticketId).toString();
        final subject = (ticket['subject'] ?? 'Driver Support Issue').toString();
        final rawStatus = (ticket['status'] ?? 'OPEN').toString();
        final (statusLabel, statusTextColor, statusBgColor) = _getStatusChipStyle(rawStatus);
        final dateText = _formatRelativeDate(ticket['createdAt']?.toString());
        final int unread = (ticket['unreadMessages'] is num) ? (ticket['unreadMessages'] as num).toInt() : 0;

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketChatScreen(ticketId: ticketId, ticketData: ticket, isProvider: widget.isProvider),
              ),
            );
            _loadTickets();
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            ticketNumber,
                            style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 11.sp, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6.r)),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 10.sp, fontWeight: FontWeight.bold, color: statusTextColor),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        dateText,
                        style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 10.sp, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    margin: EdgeInsets.only(left: 8.w),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                    child: Text(
                      '$unread',
                      style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                Icon(Icons.chevron_right_rounded, color: const Color(0xFF94A3B8), size: 22.sp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final canPop = Navigator.canPop(context);
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
        border: Border(bottom: BorderSide(color: Color(0xFFFFEF9E), width: 1.0)),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.arrow_back, size: 20.sp, color: const Color(0xFF1E293B)),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Text(
              'Help & Support',
              style: TextStyle(fontFamily: AppFonts.fontFamily, fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }
}
