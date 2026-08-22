import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme extension exposing the trust/risk verdict scale so feature code
/// reads `Theme.of(context).extension<RiskColors>()` instead of reaching
/// into [AppColors] directly — keeps the "this color means Verified"
/// mapping in one place and swappable per theme brightness.
@immutable
class RiskColors extends ThemeExtension<RiskColors> {
  const RiskColors({
    required this.verifiedLeaning,
    required this.verifiedLeaningBg,
    required this.caution,
    required this.cautionBg,
    required this.highRisk,
    required this.highRiskBg,
  });

  final Color verifiedLeaning;
  final Color verifiedLeaningBg;
  final Color caution;
  final Color cautionBg;
  final Color highRisk;
  final Color highRiskBg;

  static const light = RiskColors(
    verifiedLeaning: AppColors.verifiedLeaning,
    verifiedLeaningBg: AppColors.verifiedLeaningBg,
    caution: AppColors.caution,
    cautionBg: AppColors.cautionBg,
    highRisk: AppColors.highRisk,
    highRiskBg: AppColors.highRiskBg,
  );

  static const dark = RiskColors(
    verifiedLeaning: AppColors.verifiedLeaningDark,
    verifiedLeaningBg: AppColors.inkSurface,
    caution: AppColors.cautionDark,
    cautionBg: AppColors.inkSurface,
    highRisk: AppColors.highRiskDark,
    highRiskBg: AppColors.inkSurface,
  );

  @override
  RiskColors copyWith({
    Color? verifiedLeaning,
    Color? verifiedLeaningBg,
    Color? caution,
    Color? cautionBg,
    Color? highRisk,
    Color? highRiskBg,
  }) {
    return RiskColors(
      verifiedLeaning: verifiedLeaning ?? this.verifiedLeaning,
      verifiedLeaningBg: verifiedLeaningBg ?? this.verifiedLeaningBg,
      caution: caution ?? this.caution,
      cautionBg: cautionBg ?? this.cautionBg,
      highRisk: highRisk ?? this.highRisk,
      highRiskBg: highRiskBg ?? this.highRiskBg,
    );
  }

  @override
  RiskColors lerp(ThemeExtension<RiskColors>? other, double t) {
    if (other is! RiskColors) return this;
    return RiskColors(
      verifiedLeaning: Color.lerp(verifiedLeaning, other.verifiedLeaning, t)!,
      verifiedLeaningBg: Color.lerp(verifiedLeaningBg, other.verifiedLeaningBg, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      cautionBg: Color.lerp(cautionBg, other.cautionBg, t)!,
      highRisk: Color.lerp(highRisk, other.highRisk, t)!,
      highRiskBg: Color.lerp(highRiskBg, other.highRiskBg, t)!,
    );
  }
}
