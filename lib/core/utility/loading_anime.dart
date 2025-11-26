import 'package:amr_factory_viz/core/utility/lottie.dart';
import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final double width;
  final double height;

  const LoadingWidget({super.key, this.width = 300, this.height = 300});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LottieAnimation(
        fileName: "assets/gif/loading.json",
        play: true,
        continuousPlay: true,
        wid: width,
        hei: height,
      ),
    );
  }
}