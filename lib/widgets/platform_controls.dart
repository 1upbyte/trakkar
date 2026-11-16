import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'liquid_glass.dart';
import 'ios_system_control.dart';

bool isIOS(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Keeps the existing Material controls on Android and uses Cupertino on iOS.
class PlatformButton extends StatelessWidget {
  const PlatformButton({
    required this.onPressed,
    required this.child,
    this.style,
    this.tonal = false,
    super.key,
  }) : icon = null,
       filled = true,
       outlined = false;

  const PlatformButton.icon({
    required this.onPressed,
    required Widget label,
    required this.icon,
    this.style,
    this.tonal = false,
    super.key,
  }) : child = label,
       filled = true,
       outlined = false;

  const PlatformButton.tonalIcon({
    required this.onPressed,
    required Widget label,
    required this.icon,
    this.style,
    super.key,
  }) : child = label,
       filled = true,
       outlined = false,
       tonal = true;

  const PlatformButton.text({
    required this.onPressed,
    required this.child,
    this.style,
    this.tonal = false,
    super.key,
  }) : icon = null,
       filled = false,
       outlined = false;

  const PlatformButton.outlined({
    required this.onPressed,
    required this.child,
    this.style,
    this.tonal = false,
    super.key,
  }) : icon = null,
       filled = false,
       outlined = true;

  const PlatformButton.outlinedIcon({
    required this.onPressed,
    required Widget label,
    required this.icon,
    this.style,
    this.tonal = false,
    super.key,
  }) : child = label,
       filled = false,
       outlined = true;

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;
  final bool tonal;
  final bool filled;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (!isIOS(context)) {
      if (tonal) {
        return FilledButton.tonalIcon(
          onPressed: onPressed,
          style: style,
          icon: icon,
          label: child,
        );
      }
      if (filled) {
        return icon == null
            ? FilledButton(onPressed: onPressed, style: style, child: child)
            : FilledButton.icon(
                onPressed: onPressed,
                style: style,
                icon: icon,
                label: child,
              );
      }
      if (outlined) {
        return icon == null
            ? OutlinedButton(onPressed: onPressed, style: style, child: child)
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: style,
                icon: icon,
                label: child,
              );
      }
      return TextButton(onPressed: onPressed, style: style, child: child);
    }
    final foreground = style?.foregroundColor?.resolve({});
    if (context.findAncestorWidgetOfExactType<CupertinoAlertDialog>() != null) {
      return CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: filled,
        textStyle: foreground == null ? null : TextStyle(color: foreground),
        child: child,
      );
    }
    final content = icon == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon!,
              const SizedBox(width: 8),
              Flexible(child: child),
            ],
          );
    if (filled || outlined) {
      final colors = Theme.of(context).colorScheme;
      final color = onPressed == null
          ? colors.onSurface.withValues(alpha: .38)
          : foreground ?? (filled ? colors.onPrimary : colors.primary);
      return LiquidGlass(
        radius: 28,
        tint: filled && onPressed != null ? colors.primary : null,
        child: CupertinoButton(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
            child: IconTheme.merge(
              data: IconThemeData(color: color),
              child: content,
            ),
          ),
        ),
      );
    }
    return CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: foreground == null
          ? content
          : DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: content,
              ),
            ),
    );
  }
}

class PlatformAlertDialog extends StatelessWidget {
  const PlatformAlertDialog({
    this.title,
    this.content,
    this.actions = const [],
    super.key,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => isIOS(context)
      ? CupertinoAlertDialog(title: title, content: content, actions: actions)
      : AlertDialog(title: title, content: content, actions: actions);
}

class PlatformSwitchTile extends StatelessWidget {
  const PlatformSwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (!isIOS(context)) {
      return SwitchListTile(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        contentPadding: contentPadding,
      );
    }
    return MergeSemantics(
      child: ListTile(
        contentPadding: contentPadding,
        title: title,
        subtitle: subtitle,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        trailing: usesIOSSystemControls
            ? SizedBox(
                width: 64,
                height: 44,
                child: IOSSystemControl(
                  kind: 'switch',
                  configuration: {'value': value},
                  onChanged: onChanged == null
                      ? null
                      : (value) {
                          if (value is bool) onChanged!(value);
                        },
                ),
              )
            : CupertinoSwitch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class PlatformSlider extends StatelessWidget {
  const PlatformSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (isIOS(context) && usesIOSSystemControls) {
      return SizedBox(
        height: 44,
        child: IOSSystemControl(
          kind: 'slider',
          configuration: {
            'value': value,
            'min': min,
            'max': max,
            'divisions': divisions,
            'label': label,
          },
          onChanged: onChanged == null
              ? null
              : (value) {
                  if (value is num) onChanged!(value.toDouble());
                },
        ),
      );
    }
    return Slider.adaptive(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      label: label,
      onChanged: onChanged,
    );
  }
}

class PlatformTextField extends StatelessWidget {
  const PlatformTextField({
    this.controller,
    this.enabled,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.decoration = const InputDecoration(),
    super.key,
  });

  final TextEditingController? controller;
  final bool? enabled;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final InputDecoration decoration;

  @override
  Widget build(BuildContext context) {
    if (!isIOS(context)) {
      return TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        obscureText: obscureText,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        decoration: decoration,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (decoration.labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              decoration.labelText!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        CupertinoTextField(
          controller: controller,
          enabled: enabled ?? true,
          autofocus: autofocus,
          obscureText: obscureText,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          placeholder: decoration.hintText ?? decoration.labelText,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffix: decoration.suffixIcon,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: CupertinoColors.separator.resolveFrom(context),
              width: .5,
            ),
          ),
        ),
        if (decoration.helperText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              decoration.helperText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
