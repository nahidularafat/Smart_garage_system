// lib/login_page.dart (Loading Indicator Fixed)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'auth_gate.dart';
import 'bus_constants.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;

  // লোডিং, অ্যানিমেশন ও এরর স্টেট
  bool _isLoading = false;
  String? _errorMessage;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeIn,
    );
    _animationController!.forward();

    // ইউজার নতুন কিছু টাইপ করলে এরর মেসেজ মুছে যাবে
    idController.addListener(_clearErrorOnType);
    passwordController.addListener(_clearErrorOnType);
  }

  void _clearErrorOnType() {
    if (_errorMessage != null && mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    idController.removeListener(_clearErrorOnType);
    passwordController.removeListener(_clearErrorOnType);
    _animationController?.dispose();
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ✅ নির্ভুল সাইন-ইন লজিক
  void _signIn() async {
    if (_isLoading) return;

    final userInput = idController.text.trim();
    final password = passwordController.text.trim();

    // ১. খালি ইনপুট চেক
    if (userInput.isEmpty) {
      _showError("দয়া করে আপনার ID বা Email লিখুন!");
      return;
    }
    if (password.isEmpty) {
      _showError("দয়া করে পাসওয়ার্ড লিখুন!");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String emailToSignIn;

      if (userInput.contains('@')) {
        emailToSignIn = userInput;
      } else {
        // বাস ড্রাইভার/অ্যাডমিনের নাম (যেমন padma, meghna) হলে @bubt.com, অন্যথায় @bubt.edu.bd
        final isBus = BusConstants.allBusNames.any(
          (b) => b.toLowerCase() == userInput.toLowerCase(),
        );
        if (isBus) {
          emailToSignIn = '${userInput.toLowerCase()}@bubt.com';
        } else {
          emailToSignIn = '$userInput@bubt.edu.bd';
        }
      }

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToSignIn,
        password: password,
      );

      // সফল হলে সরাসরি AuthGate-এ নেভিগেট করবে (কখনোই আটকে থাকবে না)
      if (cred.user != null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
        Get.offAll(() => const AuthGate());
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
        case 'wrong-password':
          message = "ভুল ID/ইমেইল অথবা পাসওয়ার্ড দেওয়া হয়েছে!";
          break;
        case 'invalid-email':
          message = "ID বা ইমেলের ফরম্যাট সঠিক নয়!";
          break;
        case 'user-disabled':
          message = "এই অ্যাকাউন্টটি নিষ্ক্রিয় করা হয়েছে!";
          break;
        case 'too-many-requests':
          message = "অতিরিক্ত ভুল চেষ্টা! কিছুক্ষণ পর আবার চেষ্টা করুন।";
          break;
        case 'network-request-failed':
          message = "ইন্টারনেট কানেকশন চেক করুন!";
          break;
        default:
          message = e.message ?? "লগইন ব্যর্থ হয়েছে! পুনরায় চেষ্টা করুন।";
      }
      _showError(message);
    } catch (e) {
      _showError("লগইন ত্রুটি: $e");
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade700;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: FadeTransition(
        opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/bubt_bus-removebg-preview.png',
                    height: 120,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Smart Garage',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 30),
                  MyTextField(
                    controller: idController,
                    hintText: "ID / Email",
                    obscureText: false,
                    prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                  ),
                  const SizedBox(height: 15),
                  MyTextField(
                    controller: passwordController,
                    hintText: "Password",
                    obscureText: _obscurePassword,
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                    suffixIcon: IconButton(
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  // ── স্পষ্ট এরর মেসেজ বক্স ──
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 25),

                  // MyButton উইজেট
                  MyButton(
                    text:
                        _isLoading
                            ? null
                            : "Sign In",
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 25,
                              width: 25,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                            : null,
                    onTap: _signIn,
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
