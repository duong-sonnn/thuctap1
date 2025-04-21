import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // Controllers cho email và password
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Instance của FirebaseAuth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Hàm đăng nhập bằng email và mật khẩu
  Future<void> _signInWithEmailAndPassword() async {
    try {
      print('Attempting email/password sign in...');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      print('Sign in successful: ${userCredential.user?.email}');
      _navigateToHomePage();
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      _showErrorSnackBar(e.message ?? 'Đăng nhập thất bại');
    } catch (e) {
      print('Unexpected error: $e');
      _showErrorSnackBar('Đăng nhập thất bại');
    }
  }

  // Hàm đăng nhập bằng Google
  Future<void> _signInWithGoogle() async {
    try {
      print('Starting Google sign in...');
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        print('Google sign in cancelled by user');
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      print('Firebase sign in successful: ${userCredential.user?.email}');
      _navigateToHomePage();
    } catch (e) {
      print('Google sign in error: $e');
      _showErrorSnackBar('Đăng nhập bằng Google thất bại');
    }
  }

  // Hàm đăng nhập bằng Facebook
  Future<void> _signInWithFacebook() async {
    try {
      print('Starting Facebook sign in...');
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final OAuthCredential credential = FacebookAuthProvider.credential(accessToken.tokenString);
        final userCredential = await _auth.signInWithCredential(credential);
        print('Firebase sign in successful: ${userCredential.user?.email}');
        _navigateToHomePage();
      } else {
        _showErrorSnackBar('Đăng nhập bằng Facebook thất bại');
      }
    } catch (e) {
      print('Facebook sign in error: $e');
      _showErrorSnackBar('Đăng nhập bằng Facebook thất bại');
    }
  }

  // Hàm đăng nhập bằng Apple
  Future<void> _signInWithApple() async {
    try {
      if (!await SignInWithApple.isAvailable()) {
        _showErrorSnackBar('Apple Sign In không khả dụng trên nền tảng này');
        return;
      }
      
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      if (appleCredential.identityToken == null) {
        _showErrorSnackBar('Đăng nhập bằng Apple thất bại: Không nhận được token');
        return;
      }
      
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      print('Firebase sign in successful: ${userCredential.user?.email}');
      _navigateToHomePage();
    } catch (e) {
      print('Apple sign in error: $e');
      _showErrorSnackBar('Đăng nhập bằng Apple thất bại');
    }
  }

  // Hàm điều hướng đến trang chính
  void _navigateToHomePage() {
    print('Navigating to HomeScreen...');
    Navigator.pushReplacementNamed(context, '/home');
  }

  // Hàm hiển thị thông báo lỗi
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sign in your account',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text('Email'),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'ex: xxx@email.com',
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Password'),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: '********',
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _signInWithEmailAndPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('SIGN IN'),
                ),
                const SizedBox(height: 16),
                const Text('or sign in with', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: _signInWithGoogle,
                      child: _socialIcon('assets/google.png'),
                    ),
                    GestureDetector(
                      onTap: _signInWithFacebook,
                      child: _socialIcon('assets/facebook.png'),
                    ),
                    GestureDetector(
                      onTap: _signInWithApple,
                      child: _socialIcon('assets/apple.png'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      ),
                      child: const Text(
                        'SIGN UP',
                        style: TextStyle(color: Colors.green),
                      ),
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

  // Hàm tạo icon cho các nút đăng nhập mạng xã hội
  Widget _socialIcon(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(assetPath, width: 24, height: 24),
    );
  }
}