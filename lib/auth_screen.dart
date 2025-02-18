import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart'; // Add this to pubspec.yaml after resolving version conflicts

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// LocalAuth instance for biometrics
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isBiometricEnabled = false; // Stored user preference
  bool _canCheckBiometrics = false; // Device capability

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
    _loadBiometricPreference();
  }

  /// Check if the device has biometrics (fingerprint/face) capabilities
  Future<void> _checkBiometricSupport() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      setState(() {
        _canCheckBiometrics = canCheck;
      });
    } catch (e) {
      // If there's an error, assume we can't do biometrics
      setState(() {
        _canCheckBiometrics = false;
      });
    }
  }

  /// Load from SharedPreferences whether user has enabled biometrics
  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    });
  }

  /// Save user's preference to enable biometrics
  Future<void> _saveBiometricPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricEnabled', enabled);
    setState(() {
      _isBiometricEnabled = enabled;
    });
  }

  /// Attempt to authenticate with biometrics if user previously enabled them.
  /// If successful, navigate to /tracker. If fail/cancel, fall back to password.
  Future<bool> _attemptBiometricLogin() async {
    if (!_canCheckBiometrics || !_isBiometricEnabled) {
      return false; // Either device not supported or user not enabled
    }
    try {
      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to log in',
        options: const AuthenticationOptions(
          biometricOnly: true,
        ),
      );
      if (didAuthenticate) {
        // If biometrics pass, go directly to tracker
        Navigator.pushNamed(context, '/tracker');
        return true;
      }
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    }
    return false;
  }

  /// Validate password or fallback logic
  Future<void> _validateAndLogin() async {
    // 1. Attempt biometrics first
    bool biometricSuccess = await _attemptBiometricLogin();
    if (biometricSuccess) return; // Already navigated if success

    // 2. If biometrics not used or user canceled, do password check
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      final storedPassword = prefs.getString(email);

      if (storedPassword == password) {
        // Password success => navigate to /tracker
        Navigator.pushNamed(context, '/tracker');

        // Prompt to enable biometrics if device supports them
        if (_canCheckBiometrics && !_isBiometricEnabled) {
          _askToEnableBiometrics();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password. Please try again.'),
          ),
        );
      }
    }
  }

  /// Prompt the user if they'd like to enable biometrics for next time
  void _askToEnableBiometrics() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Biometrics?'),
          content: const Text(
            'Would you like to use biometrics for quicker login next time?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveBiometricPreference(true);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  /// Create an account (store email+password in SharedPreferences)
  Future<void> _validateAndCreateAccount() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account already exists. Please log in.'),
          ),
        );
      } else {
        await prefs.setString(email, password);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please log in.'),
          ),
        );
        _emailController.clear();
        _passwordController.clear();
      }
    }
  }

  /// Let user retrieve password from SharedPreferences
  Future<void> _forgotPassword() async {
    final email = _emailController.text;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account found with this email.')),
      );
    } else {
      final storedPass = prefs.getString(email) ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your password is: $storedPass')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In or Create Account'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    'assets/images/verithesia_icon.png',
                    height: 200,
                  ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration:
                      const InputDecoration(labelText: 'Username (Email)'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email address';
                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                        .hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    } else if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _forgotPassword(),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _validateAndCreateAccount,
                      child: const Text('Create Account'),
                    ),
                    // Single "Log In" button that tries biometrics first
                    ElevatedButton(
                      onPressed: _validateAndLogin,
                      child: const Text('Log In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
