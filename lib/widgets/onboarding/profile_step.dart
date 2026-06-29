import 'package:flutter/material.dart';
import '../glass_card.dart';
import 'fade_slide_transition.dart';

class ProfileStep extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController dobController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final String gender;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const ProfileStep({
    super.key,
    required this.formKey,
    required this.dobController,
    required this.heightController,
    required this.weightController,
    required this.gender,
    required this.onGenderChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> with SingleTickerProviderStateMixin {
  late AnimationController _avatarController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _avatarController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideTransition(
                  delay: Duration.zero,
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: const Text(
                          "👤",
                          style: TextStyle(fontSize: 66),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Basic Profile",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Let's customize your profile preferences",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600], 
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Birth Date
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 150),
                  child: TextFormField(
                    controller: widget.dobController,
                    readOnly: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    decoration: _inputDecoration("Date of Birth", Icons.calendar_today_outlined, isDark),
                    validator: (v) => (v == null || v.isEmpty) ? "Please select your date of birth" : null,
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime(1998, 1, 1),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      );
                      if (selectedDate != null) {
                        widget.dobController.text = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Gender Selector
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                        child: Text(
                          "Gender", 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildGenderCard("Female", "👩", isDark),
                          const SizedBox(width: 10),
                          _buildGenderCard("Male", "👨", isDark),
                          const SizedBox(width: 10),
                          _buildGenderCard("Other", "🧑", isDark),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 450),
                  child: Column(
                    children: [
                      Divider(height: 20, color: isDark ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // Optional details header
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 550),
                  child: Text(
                    "Optional Details",
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideTransition(
                  delay: const Duration(milliseconds: 650),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: widget.heightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: _inputDecoration("Height (cm)", Icons.straighten_outlined, isDark),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: widget.weightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: _inputDecoration("Weight (kg)", Icons.scale_outlined, isDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                FadeSlideTransition(
                  delay: const Duration(milliseconds: 750),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                          ),
                          onPressed: widget.onBack,
                          child: Text("Back", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            shadowColor: Colors.blueAccent.withOpacity(0.3),
                            elevation: 4,
                          ),
                          onPressed: () {
                            if (widget.formKey.currentState!.validate()) {
                              widget.onNext();
                            }
                          },
                          child: const Text("Next", style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildGenderCard(String label, String emoji, bool isDark) {
    final isSelected = widget.gender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onGenderChanged(label),
        child: AnimatedScale(
          scale: isSelected ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blueAccent.withOpacity(0.20)
                  : (isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.035)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.blueAccent
                    : (isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.10)),
                width: isSelected ? 2.0 : 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected 
                        ? Colors.blueAccent 
                        : (isDark ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.75)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.65), 
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: Colors.blueAccent, 
        fontWeight: FontWeight.bold,
      ),
      prefixIcon: Icon(icon, color: Colors.blueAccent, size: 22),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.12),
          width: 1.2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.22) : Colors.black.withOpacity(0.12),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2.0),
      ),
    );
  }
}
