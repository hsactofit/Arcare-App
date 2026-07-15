import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class SosContact {
  final int id;
  final String name;
  final String phone;

  SosContact({required this.id, required this.name, required this.phone});

  factory SosContact.fromJson(Map<String, dynamic> json) {
    return SosContact(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  static const Color _sosRed = Color(0xFFFF3B30);
  static const Color _sosCoral = Color(0xFFFF6D55);
  static const Color _mint = Color(0xFF2EE5A3);
  static const Color _policeBlue = Color(0xFF4A90E2);
  static const Color _fireAmber = Color(0xFFFFB03A);

  bool _isLoading = true;
  bool _isTriggering = false;
  String? _error;
  String? _email;

  List<SosContact> _contacts = [];
  String _policeNumber = '112';
  String _ambulanceNumber = '102';
  String _fireNumber = '101';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadSosData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSosData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = await ApiService.instance.getUserEmail();
      final data = await ApiService.instance.getSos(email);

      final contactsRaw = data['contacts'] as List<dynamic>? ?? [];
      final emergency =
          data['emergency_numbers'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        _email = email;
        _contacts = contactsRaw
            .map((c) => SosContact.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        _policeNumber = emergency['police_number'] as String? ?? '112';
        _ambulanceNumber = emergency['ambulance_number'] as String? ?? '102';
        _fireNumber = emergency['fire_number'] as String? ?? '101';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load SOS data: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Unable to open dialer for $number', isError: true);
      }
    } catch (e) {
      _showSnack('Failed to call $number', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? _sosRed : _mint,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _confirmAndTriggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF16161C).withOpacity(0.88)
                      : Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.10)
                        : Colors.white.withOpacity(0.65),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _sosRed.withOpacity(0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sosRed.withOpacity(0.12),
                        border: Border.all(color: _sosRed.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: _sosRed, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Trigger SOS?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This alerts all emergency contacts and shares your emergency numbers. Only use in a real emergency.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _MorphButton(
                            label: 'Cancel',
                            isDark: isDark,
                            onTap: () => Navigator.pop(ctx, false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MorphButton(
                            label: 'Send SOS',
                            isDark: isDark,
                            filled: true,
                            fillColor: _sosRed,
                            onTap: () => Navigator.pop(ctx, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _triggerSos();
    }
  }

  Future<void> _triggerSos() async {
    if (_email == null) {
      _showSnack('User email not available', isError: true);
      return;
    }

    setState(() => _isTriggering = true);
    HapticFeedback.heavyImpact();

    try {
      final result = await ApiService.instance.triggerSos(_email!);
      final message = result['message'] as String? ?? 'SOS alert sent';
      final notified = result['notified_contacts'] as List<dynamic>? ?? [];

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF16161C).withOpacity(0.88)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.10)
                          : Colors.white.withOpacity(0.65),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _mint.withOpacity(0.14),
                          ),
                          child: const Icon(Icons.check_circle_rounded,
                              color: _mint, size: 30),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'SOS Triggered',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      if (notified.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Notified (${notified.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...notified.map((c) {
                          final map = Map<String, dynamic>.from(c as Map);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _sosRed.withOpacity(0.12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      () {
                                        final n =
                                            map['name'] as String? ?? '?';
                                        return n.isNotEmpty
                                            ? n[0].toUpperCase()
                                            : '?';
                                      }(),
                                      style: const TextStyle(
                                        color: _sosRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${map['name']}  ·  ${map['phone']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      _MorphButton(
                        label: 'Done',
                        isDark: isDark,
                        filled: true,
                        fillColor: _mint,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isTriggering = false);
    }
  }

  Future<void> _showContactSheet({SosContact? contact}) async {
    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16161C).withOpacity(0.90)
                          : Colors.white.withOpacity(0.92),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.white.withOpacity(0.70),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            contact == null
                                ? 'Add Emergency Contact'
                                : 'Edit Contact',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'People notified when you trigger SOS',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: _morphInput('Name', isDark),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _morphInput('Phone number', isDark),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          _MorphButton(
                            label: contact == null
                                ? 'Add Contact'
                                : 'Save Changes',
                            isDark: isDark,
                            filled: true,
                            fillColor: _sosRed,
                            loading: saving,
                            onTap: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    if (_email == null) return;

                                    setSheetState(() => saving = true);
                                    try {
                                      if (contact == null) {
                                        await ApiService.instance
                                            .createSosContact(_email!, {
                                          'name': nameCtrl.text.trim(),
                                          'phone': phoneCtrl.text.trim(),
                                        });
                                      } else {
                                        await ApiService.instance
                                            .updateSosContact(contact.id, {
                                          'name': nameCtrl.text.trim(),
                                          'phone': phoneCtrl.text.trim(),
                                        });
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      await _loadSosData();
                                      _showSnack(contact == null
                                          ? 'Contact added'
                                          : 'Contact updated');
                                    } catch (e) {
                                      setSheetState(() => saving = false);
                                      _showSnack(
                                        e
                                            .toString()
                                            .replaceFirst('Exception: ', ''),
                                        isError: true,
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  Future<void> _deleteContact(SosContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF16161C).withOpacity(0.9)
                      : Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Delete contact?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Remove ${contact.name} from emergency contacts?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MorphButton(
                            label: 'Cancel',
                            isDark: isDark,
                            onTap: () => Navigator.pop(ctx, false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MorphButton(
                            label: 'Delete',
                            isDark: isDark,
                            filled: true,
                            fillColor: _sosRed,
                            onTap: () => Navigator.pop(ctx, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.instance.deleteSosContact(contact.id);
      await _loadSosData();
      _showSnack('Contact deleted');
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _showEmergencyNumbersSheet() async {
    final policeCtrl = TextEditingController(text: _policeNumber);
    final ambulanceCtrl = TextEditingController(text: _ambulanceNumber);
    final fireCtrl = TextEditingController(text: _fireNumber);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16161C).withOpacity(0.90)
                          : Colors.white.withOpacity(0.92),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.white.withOpacity(0.70),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Edit Emergency Numbers',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: policeCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _morphInput('Police', isDark),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: ambulanceCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _morphInput('Ambulance', isDark),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: fireCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _morphInput('Fire', isDark),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          _MorphButton(
                            label: 'Save Numbers',
                            isDark: isDark,
                            filled: true,
                            fillColor: _sosRed,
                            loading: saving,
                            onTap: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    if (_email == null) return;

                                    setSheetState(() => saving = true);
                                    try {
                                      await ApiService.instance
                                          .updateEmergencyNumbers(_email!, {
                                        'police_number':
                                            policeCtrl.text.trim(),
                                        'ambulance_number':
                                            ambulanceCtrl.text.trim(),
                                        'fire_number': fireCtrl.text.trim(),
                                      });
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      await _loadSosData();
                                      _showSnack('Emergency numbers updated');
                                    } catch (e) {
                                      setSheetState(() => saving = false);
                                      _showSnack(
                                        e
                                            .toString()
                                            .replaceFirst('Exception: ', ''),
                                        isError: true,
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    policeCtrl.dispose();
    ambulanceCtrl.dispose();
    fireCtrl.dispose();
  }

  Future<void> _resetEmergencyNumbers() async {
    if (_email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF16161C).withOpacity(0.9)
                      : Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reset numbers?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reset police / ambulance / fire to defaults (112 / 102 / 101)?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MorphButton(
                            label: 'Cancel',
                            isDark: isDark,
                            onTap: () => Navigator.pop(ctx, false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MorphButton(
                            label: 'Reset',
                            isDark: isDark,
                            filled: true,
                            fillColor: _sosCoral,
                            onTap: () => Navigator.pop(ctx, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.instance.resetEmergencyNumbers(_email!);
      await _loadSosData();
      _showSnack('Emergency numbers reset to defaults');
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  InputDecoration _morphInput(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white54 : Colors.black45,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _sosRed.withOpacity(0.7), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      body: Stack(
        children: [
          // ── Morphic glowing background ──
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF6F8FC),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _sosRed.withOpacity(isDark ? 0.28 : 0.18),
                    _sosRed.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 280,
            left: -110,
            width: 320,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _sosCoral.withOpacity(isDark ? 0.18 : 0.12),
                    _sosCoral.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(isDark ? 0.16 : 0.10),
                    Colors.purple.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _sosRed),
                  )
                : _error != null
                    ? _buildErrorState(textColor, secondaryText)
                    : RefreshIndicator(
                        color: _sosRed,
                        backgroundColor:
                            isDark ? const Color(0xFF1E1E24) : Colors.white,
                        onRefresh: _loadSosData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(theme, isDark, textColor, secondaryText),
                              const SizedBox(height: 28),
                              _buildSosTrigger(isDark, secondaryText),
                              const SizedBox(height: 32),
                              _buildSectionLabel(
                                'EMERGENCY SERVICES',
                                theme,
                                actions: [
                                  _MorphIconButton(
                                    icon: Icons.restart_alt_rounded,
                                    tooltip: 'Reset defaults',
                                    isDark: isDark,
                                    onTap: _resetEmergencyNumbers,
                                  ),
                                  const SizedBox(width: 6),
                                  _MorphIconButton(
                                    icon: Icons.tune_rounded,
                                    tooltip: 'Edit numbers',
                                    isDark: isDark,
                                    onTap: _showEmergencyNumbersSheet,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _EmergencyMorphCard(
                                      icon: Icons.local_police_rounded,
                                      label: 'Police',
                                      number: _policeNumber,
                                      color: _policeBlue,
                                      isDark: isDark,
                                      onTap: () => _callNumber(_policeNumber),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _EmergencyMorphCard(
                                      icon: Icons.local_hospital_rounded,
                                      label: 'Ambulance',
                                      number: _ambulanceNumber,
                                      color: _mint,
                                      isDark: isDark,
                                      onTap: () =>
                                          _callNumber(_ambulanceNumber),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _EmergencyMorphCard(
                                      icon: Icons.local_fire_department_rounded,
                                      label: 'Fire',
                                      number: _fireNumber,
                                      color: _fireAmber,
                                      isDark: isDark,
                                      onTap: () => _callNumber(_fireNumber),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              _buildSectionLabel(
                                'EMERGENCY CONTACTS',
                                theme,
                                actions: [
                                  _MorphIconButton(
                                    icon: Icons.person_add_alt_1_rounded,
                                    tooltip: 'Add contact',
                                    isDark: isDark,
                                    accent: true,
                                    onTap: () => _showContactSheet(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_contacts.isEmpty)
                                _buildEmptyContacts(isDark, textColor, secondaryText)
                              else
                                ..._contacts.map(
                                  (c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ContactMorphCard(
                                      contact: c,
                                      isDark: isDark,
                                      onCall: () => _callNumber(c.phone),
                                      onEdit: () =>
                                          _showContactSheet(contact: c),
                                      onDelete: () => _deleteContact(c),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _sosCoral.withOpacity(0.12),
                                      ),
                                      child: const Icon(
                                        Icons.info_outline_rounded,
                                        color: _sosCoral,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'In an emergency, tap SOS to notify contacts, or call services directly from the cards above.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                          color: secondaryText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    bool isDark,
    Color textColor,
    Color? secondaryText,
  ) {
    return Row(
      children: [
        _MorphIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          isDark: isDark,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _sosRed.withOpacity(0.22),
                _sosCoral.withOpacity(0.12),
              ],
            ),
            border: Border.all(color: _sosRed.withOpacity(0.18)),
          ),
          child: const Center(
            child: Text('🛡️', style: TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SOS Emergency',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: textColor,
                ),
              ),
              Text(
                'Contacts, services & one-tap alert',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _MorphIconButton(
          icon: Icons.refresh_rounded,
          isDark: isDark,
          onTap: _isLoading ? null : _loadSosData,
        ),
      ],
    );
  }

  Widget _buildSectionLabel(
    String title,
    ThemeData theme, {
    List<Widget> actions = const [],
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ...actions,
      ],
    );
  }

  Widget _buildSosTrigger(bool isDark, Color? secondaryText) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = 0.55 + (_pulseController.value * 0.45);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Soft outer morph rings
                Container(
                  width: 210 + (_pulseController.value * 12),
                  height: 210 + (_pulseController.value * 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sosRed.withOpacity(
                      (isDark ? 0.08 : 0.06) * pulse,
                    ),
                  ),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sosRed.withOpacity(isDark ? 0.10 : 0.07),
                  ),
                ),
                // Main morph button
                GestureDetector(
                  onTap: _isTriggering ? null : _confirmAndTriggerSos,
                  child: Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _isTriggering
                              ? _sosRed.withOpacity(0.75)
                              : const Color(0xFFFF6B60),
                          _sosRed,
                          const Color(0xFFC62828),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _sosRed.withOpacity(isDark ? 0.45 : 0.32),
                          blurRadius: 28 + (_pulseController.value * 10),
                          spreadRadius: 1,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(isDark ? 0.06 : 0.35),
                          blurRadius: 12,
                          offset: const Offset(-4, -4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: _isTriggering
                          ? const SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sos_rounded,
                                    color: Colors.white, size: 46),
                                SizedBox(height: 2),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to alert emergency contacts',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyContacts(
    bool isDark,
    Color textColor,
    Color? secondaryText,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _sosRed.withOpacity(0.10),
              border: Border.all(color: _sosRed.withOpacity(0.15)),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 30,
              color: _sosRed.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No emergency contacts yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.2,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add people who should be notified when you trigger SOS.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 18),
          _MorphButton(
            label: 'Add Contact',
            isDark: isDark,
            filled: true,
            fillColor: _sosRed,
            onTap: () => _showContactSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color textColor, Color? secondaryText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _sosRed.withOpacity(0.12),
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 30, color: _sosRed),
              ),
              const SizedBox(height: 14),
              Text(
                'Could not load SOS data',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
              const SizedBox(height: 18),
              _MorphButton(
                label: 'Retry',
                isDark: Theme.of(context).brightness == Brightness.dark,
                filled: true,
                fillColor: _sosRed,
                onTap: _loadSosData,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Morph UI building blocks
// ─────────────────────────────────────────────────────────────

class _MorphButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool filled;
  final Color? fillColor;
  final bool loading;
  final VoidCallback? onTap;

  const _MorphButton({
    required this.label,
    required this.isDark,
    this.filled = false,
    this.fillColor,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = fillColor ?? const Color(0xFFFF3B30);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: filled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.95),
                      color,
                    ],
                  )
                : null,
            color: filled
                ? null
                : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04)),
            border: Border.all(
              color: filled
                  ? color.withOpacity(0.35)
                  : (isDark
                      ? Colors.white.withOpacity(0.10)
                      : Colors.black.withOpacity(0.06)),
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.1,
                      color: filled
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MorphIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final bool accent;
  final String? tooltip;
  final VoidCallback? onTap;

  const _MorphIconButton({
    required this.icon,
    required this.isDark,
    this.accent = false,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: accent
                ? const Color(0xFFFF3B30).withOpacity(0.12)
                : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04)),
            border: Border.all(
              color: accent
                  ? const Color(0xFFFF3B30).withOpacity(0.2)
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05)),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: accent
                ? const Color(0xFFFF3B30)
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class _EmergencyMorphCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _EmergencyMorphCard({
    required this.icon,
    required this.label,
    required this.number,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      borderRadius: 20,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withOpacity(0.22),
                    color.withOpacity(0.08),
                  ],
                ),
                border: Border.all(color: color.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isDark ? 0.18 : 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: color.withOpacity(0.12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_rounded, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    'Call',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: color,
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
}

class _ContactMorphCard extends StatelessWidget {
  final SosContact contact;
  final bool isDark;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactMorphCard({
    required this.contact,
    required this.isDark,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFF3B30).withOpacity(0.22),
                  const Color(0xFFFF6D55).withOpacity(0.10),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFF3B30).withOpacity(0.18),
              ),
            ),
            child: Center(
              child: Text(
                contact.name.isNotEmpty
                    ? contact.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Color(0xFFFF3B30),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          _MorphIconButton(
            icon: Icons.phone_rounded,
            isDark: isDark,
            accent: true,
            tooltip: 'Call',
            onTap: onCall,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'More',
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
