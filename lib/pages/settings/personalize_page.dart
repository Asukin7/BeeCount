import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../styles/tokens.dart';

// 兼容旧引用
final headerStyleProvider = StateProvider<String>((ref) => 'primary');

class PersonalizePage extends ConsumerStatefulWidget {
  const PersonalizePage({super.key});

  @override
  ConsumerState<PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends ConsumerState<PersonalizePage> {
  @override
  Widget build(BuildContext context) {
    final primary = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);

    final options = <_ThemeOption>[
      _ThemeOption(l10n.personalizeThemeHoney, const Color(0xFFF8C91C)),
      _ThemeOption(l10n.personalizeThemeOrange, const Color(0xFFFF7043)),
      _ThemeOption(l10n.personalizeThemeGreen, const Color(0xFF26A69A)),
      _ThemeOption(l10n.personalizeThemePurple, const Color(0xFF7E57C2)),
      _ThemeOption(l10n.personalizeThemePink, const Color(0xFFE91E63)),
      _ThemeOption(l10n.personalizeThemeBlue, const Color(0xFF2196F3)),
      _ThemeOption(l10n.personalizeThemeMint, const Color(0xFF80CBC4)),
      _ThemeOption(l10n.personalizeThemeSand, const Color(0xFFFFCC80)),
      _ThemeOption(l10n.personalizeThemeLavender, const Color(0xFFB39DDB)),
      _ThemeOption(l10n.personalizeThemeSky, const Color(0xFF90CAF9)),
      // 新增注意色系
      _ThemeOption(l10n.personalizeThemeWarmOrange, const Color(0xFFFF8A65)),
      _ThemeOption(l10n.personalizeThemeMintGreen, const Color(0xFF4DB6AC)),
      _ThemeOption(l10n.personalizeThemeRoseGold, const Color(0xFFAD7A99)),
      _ThemeOption(l10n.personalizeThemeDeepBlue, const Color(0xFF1565C0)),
      _ThemeOption(l10n.personalizeThemeMapleRed, const Color(0xFFD32F2F)),
      _ThemeOption(l10n.personalizeThemeEmerald, const Color(0xFF388E3C)),
      _ThemeOption(l10n.personalizeThemeLavenderPurple, const Color(0xFF9575CD)),
      _ThemeOption(l10n.personalizeThemeAmber, const Color(0xFFFFA726)),
      _ThemeOption(l10n.personalizeThemeRouge, const Color(0xFFC2185B)),
      _ThemeOption(l10n.personalizeThemeIndigo, const Color(0xFF3F51B5)),
      _ThemeOption(l10n.personalizeThemeOlive, const Color(0xFF689F38)),
      _ThemeOption(l10n.personalizeThemeCoral, const Color(0xFFFF8A80)),
      _ThemeOption(l10n.personalizeThemeDarkGreen, const Color(0xFF2E7D32)),
      _ThemeOption(l10n.personalizeThemeViolet, const Color(0xFF673AB7)),
      _ThemeOption(l10n.personalizeThemeSunset, const Color(0xFFFF5722)),
      _ThemeOption(l10n.personalizeThemePeacock, const Color(0xFF00ACC1)),
      _ThemeOption(l10n.personalizeThemeLime, Colors.lime),
    ];

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context)!.personalizeTitle,
            showBack: true,
            leadingIcon: Icons.brush_outlined,
            leadingPlain: true,
            compact: true,
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: options.length + 1, // +1 for custom color picker
              itemBuilder: (_, i) {
                if (i == options.length) {
                  // Custom color picker card
                  return _CustomColorCard(
                    onTap: () => _showColorPicker(context, ref),
                  );
                }
                final o = options[i];
                final selected = o.color == primary;
                return _ThemeCard(
                  option: o,
                  selected: selected,
                  onTap: () =>
                      ref.read(primaryColorProvider.notifier).state = o.color,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.personalizeCustomTitle),
        content: SingleChildScrollView(
          child: _ColorPicker(
            onColorSelected: (color) {
              ref.read(primaryColorProvider.notifier).state = color;
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}

class _ThemeOption {
  final String name;
  final Color color;
  _ThemeOption(this.name, this.color);
}

class _ThemeCard extends StatelessWidget {
  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeCard(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: BeeTokens.border(context)) : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: option.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: selected
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.check_circle, color: Colors.white),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              child: Text(option.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: BeeTokens.textPrimary(context),
                      )),
            ),
          ],
        ),
      ),
    );
  }
}

// 自定义颜色卡片
class _CustomColorCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CustomColorCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? BeeTokens.border(context) : Colors.grey[300]!,
            width: isDark ? 1 : 2,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  size: 48,
                  color: BeeTokens.iconSecondary(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context)!.personalizeCustomColor,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: BeeTokens.textSecondary(context),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// HSV颜色选择器
class _ColorPicker extends StatefulWidget {
  final Function(Color) onColorSelected;
  const _ColorPicker({required this.onColorSelected});

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late HSVColor currentColor;
  late TextEditingController _hexController;
  bool _isEditingHex = false;
  final _hexFocusNode = FocusNode();

  /// 获取当前实际颜色的亮度（用于文字颜色判断）
  double get _brightness => currentColor.value;

  @override
  void initState() {
    super.initState();
    currentColor = HSVColor.fromColor(Colors.blue);
    _hexController = TextEditingController(text: _colorToHex(Colors.blue));
    _hexFocusNode.addListener(() {
      if (!_hexFocusNode.hasFocus && _isEditingHex) {
        _commitHexInput();
      }
    });
  }

  @override
  void dispose() {
    _hexController.dispose();
    _hexFocusNode.dispose();
    super.dispose();
  }

  /// 将 Color 转为 HEX 字符串（#RRGGBB）
  static String _colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  /// 解析 HEX 字符串为 Color，支持 #RRGGBB 和 RRGGBB
  Color? _hexToColor(String hex) {
    hex = hex.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    return Color.fromARGB(255, r, g, b);
  }

  void _commitHexInput() {
    final parsed = _hexToColor(_hexController.text);
    if (parsed != null) {
      setState(() {
        currentColor = HSVColor.fromColor(parsed);
        _isEditingHex = false;
      });
      // 直接设置 controller 文本为用户输入的原始值，不做任何转换
      final hex = _hexController.text.trim();
      final cleanHex = hex.startsWith('#') ? hex.substring(1) : hex;
      _hexController.text = '#${cleanHex.toUpperCase()}';
    } else {
      // 无效输入，恢复为当前颜色的 HEX 值
      _hexController.text = _colorToHex(currentColor.toColor());
      setState(() => _isEditingHex = false);
    }
  }

  /// 滑块变化时更新 HEX 文本
  void _onSliderChanged() {
    _hexController.text = _colorToHex(currentColor.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _brightness > 0.5 ? Colors.black : Colors.white;
    final displayColor = currentColor.toColor();

    return SizedBox(
      width: 320,
      height: 420,
      child: Column(
        children: [
          // 颜色预览
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: displayColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BeeTokens.borderStrong(context), width: 1),
            ),
            child: Center(
              child: _isEditingHex
                  ? SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _hexController,
                        focusNode: _hexFocusNode,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        autofocus: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: textColor, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _commitHexInput(),
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        setState(() => _isEditingHex = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _hexFocusNode.requestFocus();
                          _hexController.selection = TextSelection(baseOffset: 0, extentOffset: _hexController.text.length);
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _hexController.text,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // 色相滑块
          Text(AppLocalizations.of(context)!.personalizeHue(currentColor.hue.round()), style: TextStyle(fontWeight: FontWeight.w500, color: BeeTokens.textPrimary(context))),
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: List.generate(7, (index) => HSVColor.fromAHSV(1.0, index * 60.0, 1.0, 1.0).toColor()),
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: currentColor.hue,
                min: 0,
                max: 360,
                onChanged: (value) {
                  setState(() {
                    currentColor = currentColor.withHue(value);
                    _onSliderChanged();
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 饱和度滑块
          Text(AppLocalizations.of(context)!.personalizeSaturation((currentColor.saturation * 100).round()), style: TextStyle(fontWeight: FontWeight.w500, color: BeeTokens.textPrimary(context))),
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1.0, currentColor.hue, 0.0, currentColor.value).toColor(),
                  HSVColor.fromAHSV(1.0, currentColor.hue, 1.0, currentColor.value).toColor(),
                ],
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: currentColor.saturation,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    currentColor = currentColor.withSaturation(value);
                    _onSliderChanged();
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 亮度滑块
          Text(AppLocalizations.of(context)!.personalizeBrightness((currentColor.value * 100).round()), style: TextStyle(fontWeight: FontWeight.w500, color: BeeTokens.textPrimary(context))),
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1.0, currentColor.hue, currentColor.saturation, 0.0).toColor(),
                  HSVColor.fromAHSV(1.0, currentColor.hue, currentColor.saturation, 1.0).toColor(),
                ],
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: currentColor.value,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    currentColor = currentColor.withValue(value);
                    _onSliderChanged();
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 确认按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onColorSelected(displayColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: displayColor,
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppLocalizations.of(context)!.personalizeSelectColor, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
