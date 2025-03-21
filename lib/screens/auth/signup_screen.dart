import 'package:flutter/material.dart';
import 'package:expirydatetracker/constants/colors.dart';
import 'package:expirydatetracker/widgets/custom_button.dart';
import 'package:expirydatetracker/widgets/custom_text_field.dart';
import 'package:expirydatetracker/widgets/auth_header.dart';
import 'package:expirydatetracker/services/auth_service.dart';
import 'package:expirydatetracker/utils/validators.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
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
              Color(0xFF070625),  // Blue color at the end
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
                children: [
                  const SizedBox(height: 48),
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
                  const AuthHeader(
                    title: 'Create Account',
                    subtitle: 'Sign up to get started',
                  ),
                  const SizedBox(height: 48),
                  CustomTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    validator: Validators.name,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Email',
                    controller: _emailController,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Password',
                    controller: _passwordController,
                    isPassword: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    isPassword: true,
                    validator: (value) => Validators.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: _isLoading ? 'Creating Account...' : 'Sign Up',
                    onPressed: _isLoading
                        ? null
                        : () async {
                      await _signUp(); // Wrap the async call in a synchronous closure
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      'Already have an account? Login',
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
