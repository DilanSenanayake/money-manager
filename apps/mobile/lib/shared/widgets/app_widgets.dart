import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.icon,
    this.tonal = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final IconData? icon;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: context.colors.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(label),
            ],
          );

    final button = tonal
        ? FilledButton.tonal(
            onPressed: loading ? null : onPressed,
            child: child,
          )
        : FilledButton(
            onPressed: loading ? null : onPressed,
            child: child,
          );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.enabled = true,
    this.autofillHints,
    this.style,
    this.textAlign,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      enabled: enabled,
      autofillHints: autofillHints,
      style: style,
      textAlign: textAlign ?? TextAlign.start,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: context.colors.outline,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal50.withValues(
                alpha: context.isDark ? 0.2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: context.colors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: context.texts.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: context.texts.bodySmall?.copyWith(
              color: context.muted,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expanded: false,
                ),
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Center(
        child: Padding(
          padding: AppSpacing.page,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SkeletonBlock(height: 88),
              const SizedBox(height: AppSpacing.sm),
              const _SkeletonBlock(height: 72),
              const SizedBox(height: AppSpacing.sm),
              const _SkeletonBlock(height: 72),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(message!, style: TextStyle(color: context.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load this",
        message: message,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: AppSpacing.page,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => const _SkeletonBlock(height: 76),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: AppSpacing.page,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _SkeletonBlock(height: 22, width: 140),
          SizedBox(height: AppSpacing.lg),
          _SkeletonBlock(height: 48, width: 220),
          SizedBox(height: AppSpacing.xs),
          _SkeletonBlock(height: 40, width: 180),
          SizedBox(height: AppSpacing.md),
          _SkeletonBlock(height: 72),
          SizedBox(height: AppSpacing.md),
          _SkeletonBlock(height: 48),
          SizedBox(height: AppSpacing.lg),
          _SkeletonBlock(height: 140),
          SizedBox(height: AppSpacing.md),
          _SkeletonBlock(height: 64),
          SizedBox(height: AppSpacing.lg),
          _SkeletonBlock(height: 180),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final base = context.colors.outlineVariant;
    final highlight = Color.lerp(base, Colors.white, context.isDark ? 0.12 : 0.55)!;
    final shimmer = Shimmer.of(context);

    Widget box({required Alignment begin, required Alignment end}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [base, highlight, base],
            stops: const [0.15, 0.5, 0.85],
          ),
        ),
      );
    }

    if (shimmer == null || MediaQuery.of(context).disableAnimations) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      );
    }

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final t = shimmer.value;
        final dx = (t * 2) - 1;
        return box(
          begin: Alignment(dx - 1, 0),
          end: Alignment(dx + 1, 0),
        );
      },
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Date',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () async {
        final parsed = DateTime.tryParse(value) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked == null) return;
        final y = picked.year.toString().padLeft(4, '0');
        final m = picked.month.toString().padLeft(2, '0');
        final d = picked.day.toString().padLeft(2, '0');
        onChanged('$y-$m-$d');
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text(value.isEmpty ? 'Choose date' : value),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.texts.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: context.texts.bodyMedium?.copyWith(
              color: context.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: context.texts.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = StatusTone.neutral,
    this.onTap,
  });

  final String message;
  final IconData icon;
  final StatusTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StatusTone.danger => AppColors.danger,
      StatusTone.warn => AppColors.warn,
      StatusTone.success => AppColors.success,
      StatusTone.neutral => context.colors.primary,
    };
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { neutral, success, warn, danger }

class CaptureModeGrid extends StatelessWidget {
  const CaptureModeGrid({
    super.key,
    required this.modes,
    this.compact = false,
  });

  final List<CaptureMode> modes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          for (var i = 0; i < modes.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _CaptureTile(mode: modes[i])),
          ],
        ],
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.45,
      children: [for (final mode in modes) _CaptureTile(mode: mode)],
    );
  }
}

class CaptureMode {
  const CaptureMode({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({required this.mode});

  final CaptureMode mode;

  @override
  Widget build(BuildContext context) {
    final selected = mode.selected;
    final accentSoft = context.isDark
        ? context.colors.primary.withValues(alpha: 0.16)
        : AppColors.teal50;
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        mode.onTap();
      },
      child: AnimatedContainer(
        duration: AppDuration.fast,
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: selected ? accentSoft : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? context.colors.primary : context.colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppDuration.fast,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? context.colors.primary : accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                mode.icon,
                size: 16,
                color: selected
                    ? context.colors.onPrimary
                    : (context.isDark ? context.colors.primary : AppColors.teal700),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall?.copyWith(
                fontSize: AppSize.navLabel,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: AppDuration.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class FadeUp extends StatelessWidget {
  const FadeUp({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final total = AppDuration.slow + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final start = delay.inMilliseconds / total.inMilliseconds;
        final t = start >= 1 ? 1.0 : ((value - start) / (1 - start)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Tweens a number from 0 (or the previous value) to [amount].
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({
    super.key,
    required this.amount,
    required this.builder,
    this.duration = AppDuration.countUp,
  });

  final num amount;
  final Duration duration;
  final Widget Function(BuildContext context, num value) builder;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(
      begin: 0,
      end: widget.amount.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount == widget.amount) return;
    _animation = Tween<double>(
      begin: _animation.value,
      end: widget.amount.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.builder(context, widget.amount);
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => widget.builder(context, _animation.value),
    );
  }
}

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  static Animation<double>? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;
  }

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.shimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      animation != oldWidget.animation;
}

class IndeterminateBar extends StatefulWidget {
  const IndeterminateBar({super.key, this.width = 96});

  final double width;

  @override
  State<IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ColoredBox(
          color: context.colors.primary.withValues(alpha: 0.16),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Align(
                alignment: Alignment(-1.2 + (t * 2.4), 0),
                child: FractionallySizedBox(
                  widthFactor: 0.38,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
