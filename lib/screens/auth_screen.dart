import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _confirmPasswordController.clear();
    });
  }

  /// Strip any Dart-added "Exception: " prefix from thrown strings.
  String _cleanError(Object e) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) return raw.substring(11);
    return raw;
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isLogin) {
        await _authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      // Re-identify RevenueCat with the signed-in user so their paid
      // entitlements are applied immediately.
      final uid = _authService.userId;
      if (uid != null) await SubscriptionService().loginUser(uid);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        final uid = _authService.userId;
        if (uid != null) await SubscriptionService().loginUser(uid);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Password strength ───────────────────────────────────────────────────

  /// Returns 0–3 (none, weak, medium, strong).
  int _passwordStrength(String pw) {
    if (pw.isEmpty) return 0;
    if (pw.length < 6) return 1;
    final hasUpper = pw.contains(RegExp(r'[A-Z]'));
    final hasDigit = pw.contains(RegExp(r'[0-9]'));
    final hasSpecial = pw.contains(RegExp(r'[!@#\$&*~%^()]'));
    final score = [pw.length >= 8, hasUpper, hasDigit, hasSpecial]
        .where((b) => b)
        .length;
    if (score >= 3) return 3;
    if (score >= 1) return 2;
    return 1;
  }

  Color _strengthColor(int level) => switch (level) {
        1 => Colors.red,
        2 => Colors.orange,
        3 => AppTheme.accentGreen,
        _ => Colors.transparent,
      };

  String _strengthLabel(int level) => switch (level) {
        1 => 'Weak',
        2 => 'Medium',
        3 => 'Strong',
        _ => '',
      };

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _isLogin ? 'Welcome Back' : 'Get Started',
            key: ValueKey(_isLogin),
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/icons/wakemeup_text_black.png',
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isLogin
                          ? 'Welcome back! Ready to never miss your stop?'
                          : 'Never miss your stop again! Let\'s get you started.',
                      key: ValueKey(_isLogin),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Error banner ──────────────────────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _errorMessage == null
                        ? const SizedBox.shrink()
                        : Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // ── Email field ───────────────────────────────────────────
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_passwordFocusNode),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter your email';
                      }
                      final emailRegex =
                          RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailRegex.hasMatch(v.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ────────────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: !_showPassword,
                    textInputAction: _isLogin
                        ? TextInputAction.done
                        : TextInputAction.next,
                    autofillHints: _isLogin
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) {
                      if (_isLogin) {
                        _handleEmailAuth();
                      } else {
                        FocusScope.of(context)
                            .requestFocus(_confirmFocusNode);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: _isLogin
                          ? 'Your password'
                          : 'Create a strong password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        tooltip: _showPassword ? 'Hide password' : 'Show password',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (!_isLogin && v.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  // ── Password strength bar (signup only) ───────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _isLogin
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _PasswordStrengthBar(
                              strength:
                                  _passwordStrength(_passwordController.text),
                              strengthColor: _strengthColor(
                                  _passwordStrength(_passwordController.text)),
                              strengthLabel: _strengthLabel(
                                  _passwordStrength(_passwordController.text)),
                            ),
                          ),
                  ),

                  // ── Confirm password (signup only) ────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: _isLogin
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmFocusNode,
                              obscureText: !_showConfirmPassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) => _handleEmailAuth(),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                hintText: 'Re-enter your password',
                                prefixIcon:
                                    const Icon(Icons.lock_person_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(() =>
                                      _showConfirmPassword =
                                          !_showConfirmPassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                if (_isLogin) return null;
                                if (v == null || v.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (v != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                  ),

                  // ── Forgot password (login only) ──────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: !_isLogin
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      ),
                              child: const Text('Forgot your password?'),
                            ),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // ── Primary button ────────────────────────────────────────
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 20),

                  // ── OR divider ────────────────────────────────────────────
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR',
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Google button ─────────────────────────────────────────
                  OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _GoogleIcon(),
                        const SizedBox(width: 12),
                        Text(
                          _isLogin
                              ? 'Continue with Google'
                              : 'Sign up with Google',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Toggle login / signup ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "New here? " : 'Already have an account? ',
                        style: const TextStyle(fontSize: 15),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : _toggleMode,
                        child: Text(
                          _isLogin ? 'Create Account' : 'Sign In',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Google "G" icon (no network, no extra assets) ────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw the four colored arcs of the Google "G"
    final colors = [
      const Color(0xFF4285F4), // blue
      const Color(0xFF34A853), // green
      const Color(0xFFFBBC05), // yellow
      const Color(0xFFEA4335), // red
    ];
    final starts = [0.0, 90.0, 180.0, 270.0];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.72),
        _deg(starts[i]),
        _deg(88),
        false,
        paint,
      );
    }

    // White horizontal bar for the "G" cut
    final barPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(center.dx - r * 0.02, center.dy - r * 0.22,
          center.dx + r, center.dy + r * 0.22),
      barPaint,
    );
  }

  double _deg(double d) => d * 3.14159265 / 180;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Password strength bar ────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  final Color strengthColor;
  final String strengthLabel;

  const _PasswordStrengthBar({
    required this.strength,
    required this.strengthColor,
    required this.strengthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < strength;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? strengthColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (strength > 0) ...[
          const SizedBox(height: 4),
          Text(
            strengthLabel,
            style: TextStyle(
              fontSize: 11,
              color: strengthColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
