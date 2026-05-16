import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:naijago_ridersapp/routes/app_routes.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/api/api_helpers.dart';
import '../controller/withdrawal_controller.dart';

class EarningsView extends StatelessWidget {
  const EarningsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<WithdrawalController>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Obx(
            () => RefreshIndicator(
              onRefresh: controller.loadEarnings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _EarningsHeader(),
                    const SizedBox(height: 22),

                    const Text(
                      'Wallet Summary',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Track rider earnings, completed jobs, and payout requests.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (controller.isLoading.value)
                      const SectionCard(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      SectionCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryItem(
                                    title: 'Available',
                                    value: _money(
                                      controller.availableBalance.value,
                                    ),
                                    icon: Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryItem(
                                    title: 'Pending',
                                    value: _money(
                                      controller.pendingEarnings.value,
                                    ),
                                    icon: Icons.pending_actions,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryItem(
                                    title: 'Total Earned',
                                    value: _money(
                                      controller.totalEarnings.value,
                                    ),
                                    icon: Icons.trending_up,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryItem(
                                    title: 'Withdrawn',
                                    value: _money(
                                      controller.totalWithdrawn.value,
                                    ),
                                    icon: Icons.payments_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryItem(
                                    title: 'This Week',
                                    value: _money(
                                      controller.weeklyEarnings.value,
                                    ),
                                    icon: Icons.calendar_view_week,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryItem(
                                    title: 'This Month',
                                    value: _money(
                                      controller.monthlyEarnings.value,
                                    ),
                                    icon: Icons.calendar_month,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: () => Get.toNamed(AppRoutes.withdrawalRequest),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Request Withdrawal'),
                    ),

                    const SizedBox(height: 26),

                    const Text(
                      'Withdrawal History',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (controller.withdrawalHistory.isEmpty)
                      const SectionCard(
                        child: Center(
                          child: Text(
                            'No withdrawal requests yet.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.withdrawalHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = controller.withdrawalHistory[index];
                          final status = asString(item['status'], 'pending');
                          final amount = asDouble(item['amount']);
                          final reference = asString(
                            item['reference'],
                            'Withdrawal request',
                          );
                          final date = asString(item['createdAt']);

                          return SectionCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 46,
                                      width: 46,
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          status,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Icon(
                                        Icons.account_balance_outlined,
                                        color: _statusColor(status),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reference,
                                            style: const TextStyle(
                                              color: AppTheme.textDark,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            date.isEmpty
                                                ? 'Date unavailable'
                                                : date,
                                            style: const TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _money(amount),
                                          style: const TextStyle(
                                            color: AppTheme.textDark,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _money(double value) => '₦${value.toStringAsFixed(0)}';

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return AppTheme.green;
    case 'failed':
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

class _EarningsHeader extends StatelessWidget {
  const _EarningsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF0B335C)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 44,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earnings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Your delivery income and payout records.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.secondary),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
