import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CountryCodeItem {
  final String flag;
  final String code; // e.g. '+94'
  final String dial; // e.g. '94'
  final String name; // e.g. 'Sri Lanka'

  const CountryCodeItem({
    required this.flag,
    required this.code,
    required this.dial,
    required this.name,
  });
}

const List<CountryCodeItem> kSupportedCountryCodes = [
  CountryCodeItem(flag: '🇱🇰', code: '+94', dial: '94', name: 'Sri Lanka'),
  CountryCodeItem(flag: '🇮🇳', code: '+91', dial: '91', name: 'India'),
  CountryCodeItem(flag: '🇦🇪', code: '+971', dial: '971', name: 'UAE'),
  CountryCodeItem(flag: '🇸🇦', code: '+966', dial: '966', name: 'Saudi Arabia'),
  CountryCodeItem(flag: '🇶🇦', code: '+974', dial: '974', name: 'Qatar'),
  CountryCodeItem(flag: '🇰🇼', code: '+965', dial: '965', name: 'Kuwait'),
  CountryCodeItem(flag: '🇴🇲', code: '+968', dial: '968', name: 'Oman'),
  CountryCodeItem(flag: '🇬🇧', code: '+44', dial: '44', name: 'United Kingdom'),
  CountryCodeItem(flag: '🇺🇸', code: '+1', dial: '1', name: 'United States'),
  CountryCodeItem(flag: '🇨🇦', code: '+1', dial: '1', name: 'Canada'),
  CountryCodeItem(flag: '🇦🇺', code: '+61', dial: '61', name: 'Australia'),
  CountryCodeItem(flag: '🇸🇬', code: '+65', dial: '65', name: 'Singapore'),
  CountryCodeItem(flag: '🇲🇾', code: '+60', dial: '60', name: 'Malaysia'),
  CountryCodeItem(flag: '🇲🇻', code: '+960', dial: '960', name: 'Maldives'),
  CountryCodeItem(flag: '🇮🇹', code: '+39', dial: '39', name: 'Italy'),
  CountryCodeItem(flag: '🇩🇪', code: '+49', dial: '49', name: 'Germany'),
  CountryCodeItem(flag: '🇫🇷', code: '+33', dial: '33', name: 'France'),
  CountryCodeItem(flag: '🇯🇵', code: '+81', dial: '81', name: 'Japan'),
  CountryCodeItem(flag: '🇰🇷', code: '+82', dial: '82', name: 'South Korea'),
  CountryCodeItem(flag: '🇨🇳', code: '+86', dial: '86', name: 'China'),
  CountryCodeItem(flag: '🇳🇿', code: '+64', dial: '64', name: 'New Zealand'),
];

CountryCodeItem getCountryByCode(String code) {
  return kSupportedCountryCodes.firstWhere(
    (c) => c.code == code || c.dial == code,
    orElse: () => kSupportedCountryCodes.first, // Sri Lanka fallback
  );
}

/// Global helper to show searchable country code picker bottom sheet
void showCountryCodePickerSheet(
  BuildContext context, {
  required String selectedCountryCode,
  required ValueChanged<String> onCountryChanged,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (ctx) {
      String query = '';
      return StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = kSupportedCountryCodes.where((c) {
            final q = query.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.code.contains(q) ||
                c.dial.contains(q);
          }).toList();

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Country Code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search country or code (e.g. Sri Lanka, +94)...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      query = val.trim();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = item.code == selectedCountryCode;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Text(item.flag, style: const TextStyle(fontSize: 24)),
                        title: Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing: Text(
                          item.code,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF16A34A) : AppColors.textSecondary,
                          ),
                        ),
                        tileColor: isSelected ? const Color(0xFFECFDF5) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onTap: () {
                          onCountryChanged(item.code);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// A compact flag and dial code picker button
class CountryCodePickerButton extends StatelessWidget {
  final String selectedCountryCode;
  final ValueChanged<String> onCountryChanged;
  final BorderRadius? borderRadius;

  const CountryCodePickerButton({
    super.key,
    required this.selectedCountryCode,
    required this.onCountryChanged,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final currentCountry = getCountryByCode(selectedCountryCode);

    return InkWell(
      onTap: () => showCountryCodePickerSheet(
        context,
        selectedCountryCode: selectedCountryCode,
        onCountryChanged: onCountryChanged,
      ),
      borderRadius: borderRadius ?? const BorderRadius.horizontal(left: Radius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentCountry.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              currentCountry.code,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// Complete phone number input field with country code prefix button
class PhoneInputWithCountryCode extends StatelessWidget {
  final String? label;
  final String hintText;
  final String? helperText;
  final TextEditingController controller;
  final String selectedCountryCode;
  final ValueChanged<String> onCountryChanged;
  final IconData? icon;
  final Color? iconColor;
  final double borderRadius;
  final EdgeInsets? contentPadding;

  const PhoneInputWithCountryCode({
    super.key,
    this.label,
    required this.hintText,
    this.helperText,
    required this.controller,
    required this.selectedCountryCode,
    required this.onCountryChanged,
    this.icon,
    this.iconColor,
    this.borderRadius = 12,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Country Code Selector Button
              CountryCodePickerButton(
                selectedCountryCode: selectedCountryCode,
                onCountryChanged: onCountryChanged,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(borderRadius)),
              ),

              // Local Phone Number Input
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    prefixIcon: icon != null ? Icon(icon, size: 16, color: iconColor ?? AppColors.textSecondary) : null,
                    isDense: true,
                    contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helperText != null && helperText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
