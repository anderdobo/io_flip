import 'package:flame/cache.dart';
import 'package:flame/extensions.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';
import 'package:io_flip_ui/io_flip_ui.dart';
import 'package:provider/provider.dart';

/// {@template victory_charge_back}
/// A widget that renders a [SpriteAnimation] for the victory charge
/// behind the card.
/// {@endtemplate}
class VictoryChargeBack extends StatelessWidget {
  /// {@macro victory_charge_back}
  const VictoryChargeBack(
    this.path, {
    required this.size,
    required this.assetSize,
    super.key,
    this.onComplete,
  });

  /// The size of the card.
  final GameCardSize size;

  /// Optional callback to be called when the animation is complete.
  final VoidCallback? onComplete;

  /// Path of the asset containing the sprite sheet.
  final String path;

  /// Size of the assets to use, large or small
  final AssetSize assetSize;

  @override
  Widget build(BuildContext context) {
    final images = context.read<Images>();
    final height = 1.22 * size.height;
    final width = 1.59 * size.width;

    return SizedBox(
      height: height,
      width: width,
      child: SpriteAnimationWidget.asset(
        path: path,
        images: images,
        anchor: Anchor.center,
        onComplete: onComplete,
        data: SpriteAnimationData.sequenced(
          amount: 18,
          amountPerRow: 6,
          textureSize: assetSize == AssetSize.large
              ? Vector2(607, 695)
              : Vector2(364, 417),
          stepTime: 0.04,
          loop: false,
        ),
      ),
    );
  }
}