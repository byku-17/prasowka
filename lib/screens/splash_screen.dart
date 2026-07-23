import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/main_screen.dart';
import 'package:prasowka/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _moveController;
  late AnimationController _shakeController;
  late AnimationController _particleController;
  
  late Animation<double> _praPosition;
  late Animation<double> _sowkaPosition;
  
  bool _collisionOccurred = false;
  bool _isDataReady = false;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _startInitialization();

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _praPosition = Tween<double>(begin: -2.0, end: -0.01).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOutBack),
    );

    _sowkaPosition = Tween<double>(begin: 2.0, end: 0.01).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOutBack),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _moveController.forward().then((_) {
      _onCollision();
    });
  }

  Future<void> _startInitialization() async {
    try {
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        final news = context.read<NewsProvider>();
        await settings.init();
        await news.init();
        
        setState(() {
          _isDataReady = true;
        });
        FlutterNativeSplash.remove();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDataReady = true);
        FlutterNativeSplash.remove();
      }
    }
  }

  void _onCollision() {
    setState(() {
      _collisionOccurred = true;
      _generateParticles();
    });
    
    _shakeController.forward(from: 0.0);
    _particleController.forward();

    _checkAndNavigate();
  }

  void _checkAndNavigate() {
    Future.delayed(const Duration(milliseconds: 2500), () async {
      while (!_isDataReady) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  void _generateParticles() {
    final random = Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(Particle(
        x: 0,
        y: 0,
        vx: (random.nextDouble() - 0.5) * 15,
        vy: (random.nextDouble() - 0.5) * 15,
        color: i % 2 == 0 ? AppTheme.accentGold : Colors.grey[400]!,
        size: random.nextDouble() * 4 + 1,
      ));
    }
  }

  @override
  void dispose() {
    _moveController.dispose();
    _shakeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: AnimatedBuilder(
        animation: Listenable.merge([_moveController, _shakeController, _particleController]),
        builder: (context, child) {
          double shakeOffset = 0;
          if (_shakeController.isAnimating) {
            shakeOffset = sin(_shakeController.value * 20 * pi) * 8 * (1 - _shakeController.value);
          }

          return Stack(
            children: [
              if (_collisionOccurred)
                Center(
                  child: CustomPaint(
                    painter: ParticlePainter(_particles, _particleController.value),
                  ),
                ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -60 + shakeOffset),
                      child: Padding(
                        padding: const EdgeInsets.all(36.0),
                        child: Image.asset(
                          'assets/logo.png',
                          height: 70,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(_praPosition.value * 200 + shakeOffset, 0),
                          child: Image.asset(
                            'assets/Pra.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(_sowkaPosition.value * 200 + shakeOffset, 0),
                          child: Image.asset(
                            _collisionOccurred ? 'assets/sówka 2.png' : 'assets/sówka.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class Particle {
  double x, y, vx, vy, size;
  Color color;
  Particle({required this.x, required this.y, required this.vx, required this.vy, required this.color, required this.size});
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      paint.color = p.color.withValues(alpha: 1 - progress);
      canvas.drawCircle(
        Offset(p.x + p.vx * progress * 20, p.y + p.vy * progress * 20),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
