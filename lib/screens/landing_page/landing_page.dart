import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import './landing_page_functions.dart';
import '../login_page/login_page.dart';
import '../../l10n/app_localizations.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _hasLogo = false;
  bool _hasBgSvg = false;
  bool _hasBgPng = false;

  @override
  void initState() {
    super.initState();
    _initAssets();
  }

  Future<void> _initAssets() async {
    final r = await LandingPageFunctions.initAssets();
    if (mounted) {
      setState(() {
        _hasBgPng = r.hasBgPng;
        _hasBgSvg = r.hasBgSvg;
        _hasLogo = r.hasLogo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: (_hasBgPng
                ? Image.asset(
                    'assets/images/landing_bg.png',
                    fit: BoxFit.cover,
                  )
                : (_hasBgSvg
                    ? SvgPicture.asset(
                        'assets/images/landing_bg.svg',
                        fit: BoxFit.cover,
                      )
                    : Container(color: Colors.black))),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_hasLogo)
                        SvgPicture.asset(
                          'assets/logo/logo.svg',
                          height: 40,
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        )
                      else
                        const Icon(Icons.water_drop, color: Colors.white, size: 36),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    AppLocalizations.of(context).landingHeadline1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context).landingHeadline2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).landingDescription,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => LoginPage()),
                        );
                      },
                      // Reemplazar Row malformado por uno correcto sin const
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppLocalizations.of(context).landingSignInButton),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_right_alt),
                        ],
                      ),
                     ),
                   ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).landingUseYourAccount,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}