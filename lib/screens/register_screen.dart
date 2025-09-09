import 'package:flutter/material.dart';
import '../utils/auth_service.dart';
import '../utils/user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final FocusNode usernameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode confirmPasswordFocusNode = FocusNode();
  bool _obscurePassword =
      true; // Changed back to true - passwords hidden by default
  bool _obscureConfirmPassword =
      true; // Changed back to true - passwords hidden by default
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = true;
  bool _isLoading = false;
  String _usernameStatus = '';
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    usernameController.addListener(_onUsernameChanged);
    passwordController.addListener(() => setState(() {}));
    confirmPasswordController.addListener(() => setState(() {}));
  }

  void _onUsernameChanged() {
    final username = usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = true;
        _usernameStatus = '';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameStatus = 'Username must be at least 3 characters';
      });
      return;
    }

    // Check for valid characters
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameStatus =
            'Username can only contain letters, numbers, and underscores';
      });
      return;
    }

    // Debounced availability check against usernames collection
    setState(() {
      _isCheckingUsername = true;
      _usernameStatus = 'Checking availability...';
    });
    Future.microtask(() async {
      final taken = await _userService.isUsernameTaken(username);
      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = !taken;
        _usernameStatus = taken
            ? 'Username is already taken'
            : 'Username is available';
      });
    });
  }

  bool _canRegister() {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Basic validation - all fields must be filled
    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      return false;
    }

    // Passwords must match
    if (password != confirmPassword) {
      return false;
    }

    // Username must be available and not being checked
    if (_isCheckingUsername || !_isUsernameAvailable || _isLoading) {
      return false;
    }

    return true;
  }

  Future<void> _register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final username = usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters long'),
        ),
      );
      return;
    }

    if (!_isUsernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a different username')),
      );
      return;
    }

    // Show loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Detect system theme preference
      final brightness = MediaQuery.of(context).platformBrightness;
      final isSystemDarkMode = brightness == Brightness.dark;

      final authService = AuthService();
      await authService.registerWithEmail(
        email,
        password,
        username,
        darkModeEnabled: isSystemDarkMode,
      );

      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacementNamed(context, '/onboarding-questions');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Registration failed. Please try again.';

      // Handle specific error cases
      if (e.toString().contains('Username') &&
          e.toString().contains('already taken')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else if (e.toString().contains('email-already-in-use')) {
        errorMessage =
            'An account with this email already exists. Please use a different email or try signing in.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage =
            'Password is too weak. Please choose a stronger password (at least 6 characters).';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Please enter a valid email address.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Registration Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = MediaQuery.of(context).platformBrightness;
    final isSystemDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isSystemDark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/octopus.png', height: 120),
                  const SizedBox(height: 24),
                  Text(
                    'Create new account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isSystemDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: usernameController,
                    focusNode: usernameFocusNode,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      color: isSystemDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Username',
                      filled: true,
                      fillColor: isSystemDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF1F3F4),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: usernameController.text.isNotEmpty
                              ? (_isUsernameAvailable
                                    ? Colors.green
                                    : Colors.red)
                              : (isSystemDark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade300),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: usernameController.text.isNotEmpty
                              ? (_isUsernameAvailable
                                    ? Colors.green
                                    : Colors.red)
                              : (isSystemDark
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFF6B46C1)),
                          width: 2,
                        ),
                      ),
                      hintStyle: TextStyle(
                        color: isSystemDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      suffixIcon: _isCheckingUsername
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : usernameController.text.isNotEmpty
                          ? Icon(
                              _isUsernameAvailable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _isUsernameAvailable
                                  ? Colors.green
                                  : Colors.red,
                            )
                          : null,
                    ),
                    onSubmitted: (_) {
                      emailFocusNode.requestFocus();
                    },
                  ),
                  if (_usernameStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            _isUsernameAvailable
                                ? Icons.check_circle
                                : Icons.info_outline,
                            size: 16,
                            color: _isUsernameAvailable
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _usernameStatus,
                              style: TextStyle(
                                fontSize: 12,
                                color: _isUsernameAvailable
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    focusNode: emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      color: isSystemDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: isSystemDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF1F3F4),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: TextStyle(
                        color: isSystemDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    onSubmitted: (_) {
                      passwordFocusNode.requestFocus();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    focusNode: passwordFocusNode,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      color: isSystemDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: isSystemDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF1F3F4),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: TextStyle(
                        color: isSystemDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: isSystemDark
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF6B46C1),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                      ),
                    ),
                    onSubmitted: (_) {
                      confirmPasswordFocusNode.requestFocus();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    focusNode: confirmPasswordFocusNode,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      color: isSystemDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      filled: true,
                      fillColor: isSystemDark
                          ? const Color(0xFF2D2D2D)
                          : const Color(0xFFF1F3F4),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: TextStyle(
                        color: isSystemDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: isSystemDark
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF6B46C1),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        tooltip: _obscureConfirmPassword
                            ? 'Show password'
                            : 'Hide password',
                      ),
                    ),
                    onSubmitted: (_) {
                      if (_canRegister()) {
                        // Trigger registration
                        _register();
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canRegister()
                            ? (isSystemDark
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF6B46C1))
                            : (isSystemDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: _canRegister() ? 4 : 0,
                      ),
                      onPressed: _canRegister() ? _register : null,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 16,
                          color: isSystemDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 16,
                            color: isSystemDark
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF6B46C1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    usernameController.removeListener(_onUsernameChanged);
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    usernameFocusNode.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }
}
