// ignore_for_file: unused_local_variable

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/school_info.dart';

Future<List<School>> fetchSchools() async {
  final box = await Hive.openBox<School>('school');
  try {
    return box.values.where((schoolItem) => schoolItem.termId != null).toList();
  } finally {}
}

class FlipLogoWidget extends StatefulWidget {
  final String? imagePath;
  final double width;
  final double height;

  const FlipLogoWidget({
    Key? key,
    required this.imagePath,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  State<FlipLogoWidget> createState() => _FlipLogoWidgetState();
}

class _FlipLogoWidgetState extends State<FlipLogoWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child: widget.imagePath != null
                ? Image.file(
                    File(widget.imagePath!),
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/assets/images/logo.png',
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                  ),
          ),
        );
      },
    );
  }
}

class CenterLogoFlipWidget extends StatefulWidget {
  final String? imagePath;
  final double width;
  final double height;

  const CenterLogoFlipWidget({
    Key? key,
    required this.imagePath,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  State<CenterLogoFlipWidget> createState() => _CenterLogoFlipWidgetState();
}

class _CenterLogoFlipWidgetState extends State<CenterLogoFlipWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _flipAnimation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()..rotateY(_flipAnimation.value),
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: widget.imagePath != null
                ? Image.file(
                    File(widget.imagePath!),
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/assets/images/logo.png',
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                  ),
          ),
        );
      },
    );
  }
}

Widget buildFutureSchoolsWidget({required bool isLargeScreen}) {
  return FutureBuilder<List<School>>(
    future: fetchSchools(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      } else if (snapshot.hasError) {
        return const Center(child: Text("Error loading school data"));
      } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
        final schoolItem = snapshot.data!.first;
        final double logoHeight = isLargeScreen ? 180 : 200;
        final double logoWidth = isLargeScreen ? 200 : 200;
        final double logoHeight1 = isLargeScreen ? 100 : 200;
        final double logoWidth1 = isLargeScreen ? 100 : 200;

        return Row(
          mainAxisAlignment: isLargeScreen
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLargeScreen)
              FlipLogoWidget(
                imagePath: schoolItem.schoolLogoPath,
                width: logoWidth1,
                height: logoHeight1,
              ),
            CenterLogoFlipWidget(
              imagePath: schoolItem.schoolLogoPath,
              width: logoWidth,
              height: logoHeight,
            ),
            if (isLargeScreen)
              FlipLogoWidget(
                imagePath: schoolItem.schoolLogoPath,
                width: logoWidth1,
                height: logoHeight1,
              ),
          ],
        );
      } else {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_rounded,
                size: 80,
                color: Colors.blueAccent,
              ),
              SizedBox(height: 16),
              Text(
                'Home Page',
                style: TextStyle(
                  fontSize: 26,
                  fontStyle: FontStyle.normal,
                  color: Color.fromARGB(255, 36, 32, 32),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    },
  );
}
