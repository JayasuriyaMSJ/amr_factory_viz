import 'package:amr_factory_viz/core/utility/loading_anime.dart';
import 'package:amr_factory_viz/core/utility/lottie.dart';
import 'package:flutter/material.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottieAnimation(
              fileName: 'assets/gif/construction.json',
              play: true,
              continuousPlay: true,
              wid: 200,
              hei: 200,
            ),
            SizedBox(height: 10),
            RichText(text: TextSpan(text: "Under Construction... :-) ")),
          ],
        ),
      ),
    );
  }
}
