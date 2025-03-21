import 'package:flutter/material.dart';
import 'package:expirydatetracker/constants/colors.dart';
import 'package:expirydatetracker/widgets/custom_button.dart';
import 'package:expirydatetracker/widgets/custom_text_field.dart';
import 'package:expirydatetracker/services/auth_service.dart';
import 'package:expirydatetracker/utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Sign in function
  Future<void> signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        // Show a more user-friendly message based on the error
        String errorMessage = 'An error occurred. Please try again.';
        if (e is Exception) {
          errorMessage = e.toString(); // Or handle specific error types
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF082969), // Sky blue
              Color(0xFF070625),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 48),
                  // Rounded image
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      // Rounded corners
                      child: Image.asset(
                        'assets/images/login.jpg',
                        width: 400, // Adjust width as needed
                        height: 190, // Adjust height as needed
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.deepOrangeAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // Email input field
                  CustomTextField(
                    label: 'Email',
                    controller: _emailController,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  // Password input field
                  CustomTextField(
                    label: 'Password',
                    controller: _passwordController,
                    isPassword: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 24),
                  // Login button
                  CustomButton(
                    text: _isLoading ? 'Logging in...' : 'Login',
                    onPressed: _isLoading
                        ? null
                        : () async {
                      await signIn();
                    },
                  ),
                  const SizedBox(height: 16),
                  // Redirect to Sign Up page
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.pushNamed(context, '/signup'),
                    child: Text(
                      'Don\'t have an account? Sign Up',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
