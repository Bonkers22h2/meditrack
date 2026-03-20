import 'package:flutter/material.dart';
import 'package:meditrack/modals/medicine_modal.dart';
import 'package:meditrack/services/medicine_icons.dart';
import 'package:meditrack/services/medicine_storage.dart';

class MedicineDetailsModal extends StatefulWidget {
  const MedicineDetailsModal({required this.medicine, super.key});

  final MedicineRecord medicine;

  @override
  State<MedicineDetailsModal> createState() => _MedicineDetailsModalState();
}

class _MedicineDetailsModalState extends State<MedicineDetailsModal> {
  bool _isDeleting = false;

  final Color _modalBgColor = const Color(0xFFF2F6EF);
  final Color _cardColor = Colors.white;
  final Color _titleColor = const Color(0xFF1B2C1B);
  final Color _valueColor = const Color(0xFF243324);
  final Color _labelColor = const Color(0xFF5E6D5E);
  final Color _accentColor = const Color(0xFF5E8A64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: _modalBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 64,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D8CF),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      MedicineIcons.resolve(widget.medicine.iconKey),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.medicine.name.isEmpty
                          ? 'Medicine details'
                          : widget.medicine.name,
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  children: [
                    _buildInfoCard(
                      title: 'Dosage',
                      children: [
                        _buildInfoRow(
                          'Dose amount',
                          _displayValue(widget.medicine.doseAmount),
                        ),
                        _buildInfoRow(
                          'Frequency',
                          _displayValue(widget.medicine.frequency),
                        ),
                      ],
                    ),
                    _buildInfoCard(
                      title: 'Schedule',
                      children: [
                        _buildInfoRow(
                          'Date range',
                          _buildDateRangeText(
                            widget.medicine.reminderStartDate,
                            widget.medicine.reminderEndDate,
                          ),
                        ),
                        _buildInfoRow(
                          'Reminder time',
                          _buildReminderTimeText(context),
                        ),
                      ],
                    ),
                    _buildInfoCard(
                      title: 'Notes',
                      children: [
                        _buildInfoRow(
                          'Saved on',
                          _formatDateTime(context, widget.medicine.createdAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isDeleting ? null : _editMedicine,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accentColor,
                            side: BorderSide(color: _accentColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size(double.infinity, 52),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isDeleting ? null : _confirmDelete,
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.delete_outline, size: 20),
                          label: Text(
                            _isDeleting ? 'Deleting...' : 'Delete',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB53434),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size(double.infinity, 52),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline, size: 24),
                      label: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE5DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: _valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _buildDateRangeText(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return 'Not set';
    }

    if (startDate != null && endDate != null) {
      return '${_formatDate(startDate)} to ${_formatDate(endDate)}';
    }

    return _formatDate(startDate ?? endDate);
  }

  String _buildReminderTimeText(BuildContext context) {
    if (widget.medicine.specificTime == null) {
      return 'Not set';
    }

    return TimeOfDay.fromDateTime(
      widget.medicine.specificTime!,
    ).format(context);
  }

  String _displayValue(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? 'Not set' : trimmed;
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Not set';
    }

    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final String date = _formatDate(dateTime);
    final String time = TimeOfDay.fromDateTime(dateTime).format(context);
    return '$date, $time';
  }

  Future<void> _editMedicine() async {
    final bool? didUpdate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return MedicineModal(initialMedicine: widget.medicine);
      },
    );

    if (!mounted) {
      return;
    }

    if (didUpdate == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _confirmDelete() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete medication?'),
          content: const Text(
            'This will remove the medication from your reminders list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await MedicineStorage.deleteMedicine(widget.medicine);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to delete medication.')),
        );
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context, true);
  }
}
