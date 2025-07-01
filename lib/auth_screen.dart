import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? error;

  void _login() async{
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        error = 'Enter e-mail or password';
      });
      return;
    }

    try{
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
        );
        //úspěšné přihlášení
        if(!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
    }on FirebaseAuthException catch (e){
        setState((){
            error = e.message;
        });
    }

    // FirebaseAuth.instance.signInWithEmailAndPassword(...)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // ← opravený překlep "retrun" → "return"
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), // oprava "fontWeight"
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress, // oprava "Addres"
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Heslo'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),

                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),

                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom( // oprava "ElevetadeButton"
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
