import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../store/store.dart';

/// 举报原因选项
class ReportReason {
  final String value;
  final String label;
  final IconData icon;

  const ReportReason({
    required this.value,
    required this.label,
    required this.icon,
  });
}

const _reasons = [
  ReportReason(value: 'harassment', label: '骚扰', icon: Icons.person_off),
  ReportReason(value: 'pornography', label: '色情', icon: Icons.visibility_off),
  ReportReason(value: 'fraud', label: '诈骗', icon: Icons.warning),
  ReportReason(value: 'advertising', label: '广告', icon: Icons.campaign),
  ReportReason(value: 'other', label: '其他', icon: Icons.more_horiz),
];

/// 举报弹窗
class ReportDialog extends ConsumerStatefulWidget {
  const ReportDialog({super.key});

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  String? _selectedReason;
  final _detailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.flag, color: Colors.orange, size: 22),
          SizedBox(width: 8),
          Text('举报', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请选择举报原因',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // 原因选择
            ..._reasons.map((reason) => _buildReasonTile(reason)),
            const SizedBox(height: 16),
            // 补充说明
            const Text(
              '补充说明（可选）',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: '请描述具体情况...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A4E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null || _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            disabledBackgroundColor: Colors.grey.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('提交举报', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildReasonTile(ReportReason reason) {
    final selected = _selectedReason == reason.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? Colors.orange.withAlpha(30) : const Color(0xFF2A2A4E),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedReason = reason.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(reason.icon, color: selected ? Colors.orange : Colors.white54, size: 20),
                const SizedBox(width: 10),
                Text(
                  reason.label,
                  style: TextStyle(
                    color: selected ? Colors.orange : Colors.white70,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle, color: Colors.orange, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(chatProvider.notifier).reportUser(
            _selectedReason!,
            detail: _detailController.text.trim().isNotEmpty
                ? _detailController.text.trim()
                : null,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('举报已提交，我们会尽快处理'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('举报失败：$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

/// 显示举报弹窗的便捷方法
Future<void> showReportDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const ReportDialog(),
  );
}
