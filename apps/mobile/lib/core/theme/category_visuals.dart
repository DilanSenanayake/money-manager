import 'package:flutter/material.dart';

import 'app_theme.dart';

class CategoryIconOption {
  const CategoryIconOption(this.id, this.label);
  final String id;
  final String label;
}

const categoryIconOptions = [
  CategoryIconOption('shopping-cart', 'Groceries'),
  CategoryIconOption('utensils', 'Dining'),
  CategoryIconOption('car', 'Transport'),
  CategoryIconOption('shopping-bag', 'Shopping'),
  CategoryIconOption('zap', 'Utilities'),
  CategoryIconOption('heart', 'Health'),
  CategoryIconOption('film', 'Entertainment'),
  CategoryIconOption('home', 'Home / Rent'),
  CategoryIconOption('wallet', 'Salary'),
  CategoryIconOption('briefcase', 'Work'),
  CategoryIconOption('trending-up', 'Investments'),
  CategoryIconOption('circle', 'Other'),
];

class CategoryStyle {
  const CategoryStyle({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.chipBackground,
    required this.chipBorder,
    required this.hex,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final Color chipBackground;
  final Color chipBorder;
  final Color hex;
}

const _styles = <String, CategoryStyle>{
  'wallet': CategoryStyle(
    icon: Icons.account_balance_wallet_outlined,
    background: Color(0xFFCCFBF1),
    foreground: Color(0xFF115E59),
    chipBackground: Color(0xFFF0FDFA),
    chipBorder: Color(0xFF99F6E4),
    hex: Color(0xFF0F766E),
  ),
  'briefcase': CategoryStyle(
    icon: Icons.work_outline_rounded,
    background: Color(0xFFE2E8F0),
    foreground: Color(0xFF1E293B),
    chipBackground: Color(0xFFF1F5F9),
    chipBorder: Color(0xFFCBD5E1),
    hex: Color(0xFF334155),
  ),
  'trending-up': CategoryStyle(
    icon: Icons.trending_up_rounded,
    background: Color(0xFFD1FAE5),
    foreground: Color(0xFF065F46),
    chipBackground: Color(0xFFECFDF5),
    chipBorder: Color(0xFFA7F3D0),
    hex: Color(0xFF047857),
  ),
  'shopping-cart': CategoryStyle(
    icon: Icons.shopping_cart_outlined,
    background: Color(0xFFECFCCB),
    foreground: Color(0xFF3F6212),
    chipBackground: Color(0xFFF7FEE7),
    chipBorder: Color(0xFFD9F99D),
    hex: Color(0xFF4D7C0F),
  ),
  'utensils': CategoryStyle(
    icon: Icons.restaurant_outlined,
    background: Color(0xFFFFEDD5),
    foreground: Color(0xFF9A3412),
    chipBackground: Color(0xFFFFF7ED),
    chipBorder: Color(0xFFFED7AA),
    hex: Color(0xFFEA580C),
  ),
  'car': CategoryStyle(
    icon: Icons.directions_car_outlined,
    background: Color(0xFFE0F2FE),
    foreground: Color(0xFF075985),
    chipBackground: Color(0xFFF0F9FF),
    chipBorder: Color(0xFFBAE6FD),
    hex: Color(0xFF0284C7),
  ),
  'shopping-bag': CategoryStyle(
    icon: Icons.shopping_bag_outlined,
    background: Color(0xFFFAE8FF),
    foreground: Color(0xFF86198F),
    chipBackground: Color(0xFFFDF4FF),
    chipBorder: Color(0xFFF5D0FE),
    hex: Color(0xFFC026D3),
  ),
  'zap': CategoryStyle(
    icon: Icons.bolt_outlined,
    background: Color(0xFFFEF3C7),
    foreground: Color(0xFF78350F),
    chipBackground: Color(0xFFFFFBEB),
    chipBorder: Color(0xFFFDE68A),
    hex: Color(0xFFD97706),
  ),
  'heart': CategoryStyle(
    icon: Icons.favorite_border_rounded,
    background: Color(0xFFFFE4E6),
    foreground: Color(0xFF9F1239),
    chipBackground: Color(0xFFFFF1F2),
    chipBorder: Color(0xFFFECDD3),
    hex: Color(0xFFE11D48),
  ),
  'film': CategoryStyle(
    icon: Icons.movie_outlined,
    background: Color(0xFFEDE9FE),
    foreground: Color(0xFF5B21B6),
    chipBackground: Color(0xFFF5F3FF),
    chipBorder: Color(0xFFDDD6FE),
    hex: Color(0xFF7C3AED),
  ),
  'home': CategoryStyle(
    icon: Icons.home_outlined,
    background: Color(0xFFCFFAFE),
    foreground: Color(0xFF164E63),
    chipBackground: Color(0xFFECFEFF),
    chipBorder: Color(0xFFA5F3FC),
    hex: Color(0xFF0E7490),
  ),
  'circle': CategoryStyle(
    icon: Icons.circle_outlined,
    background: Color(0xFFE7E5E4),
    foreground: Color(0xFF44403C),
    chipBackground: Color(0xFFF5F5F4),
    chipBorder: Color(0xFFD6D3D1),
    hex: Color(0xFF57534E),
  ),
};

const _nameToIcon = <String, String>{
  'salary': 'wallet',
  'freelance': 'briefcase',
  'investments': 'trending-up',
  'groceries': 'shopping-cart',
  'dining': 'utensils',
  'transport': 'car',
  'shopping': 'shopping-bag',
  'utilities': 'zap',
  'health': 'heart',
  'entertainment': 'film',
  'rent': 'home',
  'other': 'circle',
};

const _fallbackKeys = [
  'car',
  'utensils',
  'heart',
  'zap',
  'shopping-cart',
  'home',
  'film',
  'wallet',
];

const _fallbackHex = [
  Color(0xFF0284C7),
  Color(0xFFEA580C),
  Color(0xFFE11D48),
  Color(0xFFD97706),
  Color(0xFF65A30D),
  Color(0xFF0E7490),
  Color(0xFF7C3AED),
  Color(0xFF0F766E),
];

int _hashKey(String key) {
  var h = 0;
  for (final unit in key.codeUnits) {
    h = (h * 31 + unit).toSigned(32);
  }
  return h.abs();
}

int _fallbackIndex(String? icon, String? name) {
  final key = (name ?? icon ?? 'other').toLowerCase();
  return _hashKey(key) % _fallbackKeys.length;
}

String? effectiveCategoryIcon(String? icon, String? name) {
  if (icon != null && _styles.containsKey(icon)) return icon;
  return name == null ? icon : _nameToIcon[name.toLowerCase()] ?? icon;
}

IconData categoryIconData(String? icon, {String? name}) {
  return _styles[effectiveCategoryIcon(icon, name)]?.icon ??
      Icons.circle_outlined;
}

CategoryStyle categoryStyle({String? icon, String? name}) {
  final key = effectiveCategoryIcon(icon, name);
  if (key != null && _styles.containsKey(key)) return _styles[key]!;
  return _styles[_fallbackKeys[_fallbackIndex(icon, name)]]!;
}

Color categoryHex({String? icon, String? name}) {
  if (icon != null && _styles.containsKey(icon)) return _styles[icon]!.hex;
  final fromName = name == null ? null : _nameToIcon[name.toLowerCase()];
  if (fromName != null) return _styles[fromName]!.hex;
  return _fallbackHex[_fallbackIndex(icon, name)];
}

class CategoryMark extends StatelessWidget {
  const CategoryMark({
    super.key,
    this.icon,
    this.name,
    this.framed = false,
    this.size = 16,
    this.selected = false,
  });

  final String? icon;
  final String? name;
  final bool framed;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final style = categoryStyle(icon: icon, name: name);
    final dark = context.isDark;
    final bg = dark ? style.hex.withValues(alpha: 0.22) : style.background;
    final fg = dark
        ? Color.lerp(style.hex, Colors.white, 0.45)!
        : style.foreground;
    final glyph = Icon(
      categoryIconData(icon, name: name),
      size: size,
      color: selected ? Colors.white : fg,
    );

    if (!framed) return glyph;

    return AnimatedContainer(
      duration: AppDuration.fast,
      width: size + 16,
      height: size + 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? style.hex : bg,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? null
            : Border.all(
                color: style.chipBorder.withValues(alpha: dark ? 0.35 : 1),
              ),
      ),
      child: glyph,
    );
  }
}

class CategoryChoiceChip extends StatelessWidget {
  const CategoryChoiceChip({
    super.key,
    required this.name,
    this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String name;
  final String? icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final style = categoryStyle(icon: icon, name: name);
    final dark = context.isDark;
    final bg = selected
        ? style.hex
        : (dark ? style.hex.withValues(alpha: 0.16) : style.chipBackground);
    final fg = selected
        ? Colors.white
        : (dark ? Color.lerp(style.hex, Colors.white, 0.5)! : style.foreground);
    final border = selected ? style.hex : style.chipBorder;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIconData(icon, name: name), size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in categoryIconOptions)
          Tooltip(
            message: opt.label,
            child: GestureDetector(
              onTap: () => onChanged(opt.id),
              child: CategoryMark(
                icon: opt.id,
                name: opt.label,
                framed: true,
                size: 18,
                selected: value == opt.id,
              ),
            ),
          ),
      ],
    );
  }
}
