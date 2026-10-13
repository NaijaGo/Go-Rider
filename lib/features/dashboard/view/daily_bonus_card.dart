import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';

class DailyBonusCard extends StatefulWidget {
  const DailyBonusCard({super.key});
  @override
  State<DailyBonusCard> createState() => _DailyBonusCardState();
}

class _DailyBonusCardState extends State<DailyBonusCard> {
  Map<String, dynamic>? data;
  String error = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = asMap(
        (await ApiClient.dio.get('/riders/daily-bonus')).data,
      );
      if (result['success'] != true ||
          result['threshold'] != 20 ||
          result['amount'] != 10000) {
        throw const FormatException();
      }
      if (mounted) {
        setState(() {
          data = result;
          error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = apiMessage(e, 'Daily bonus progress is unavailable.'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _request() async {
    if (busy || data?['eligible'] != true || data?['claim'] != null) return;
    setState(() => busy = true);
    try {
      await ApiClient.dio.post('/riders/daily-bonus/request');
      if (mounted) setState(() => error = '');
    } catch (e) {
      if (mounted) {
        setState(
          () => error = apiMessage(
            e,
            'Bonus request could not be confirmed. Refresh before retrying.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = asDouble(data?['completedOrders']).toInt();
    final claim = asMap(data?['claim']), state = asString(claim['state']);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily delivery bonus',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete 20 orders in one day to qualify for a ₦10,000 bonus.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Lagos calendar day · Admin approval required · One bonus per day',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (data != null) ...[
            LinearProgressIndicator(value: (count / 20).clamp(0, 1)),
            const SizedBox(height: 8),
            Text('$count / 20 completed orders today'),
            if (state.isNotEmpty)
              Text(switch (state) {
                'approved' => 'Approved and credited to your wallet',
                'rejected' => 'Request reviewed: not approved',
                _ => 'Bonus request pending admin review',
              }),
            if (data!['eligible'] == true && claim.isEmpty)
              TextButton(
                onPressed: busy ? null : _request,
                child: const Text('Request daily bonus'),
              ),
          ],
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: AppTheme.textMuted)),
          TextButton.icon(
            onPressed: busy ? null : _load,
            icon: const Icon(Icons.refresh),
            label: Text(
              busy ? 'Checking progress...' : 'Refresh bonus progress',
            ),
          ),
        ],
      ),
    );
  }
}
