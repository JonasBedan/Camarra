import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/premium_model.dart';
import '../utils/premium_service.dart';
import '../utils/user_service.dart';
import '../utils/theme_provider.dart';
import '../utils/sound_service.dart';
import '../utils/payment_service.dart';
import '../screens/payment_proceeding_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with TickerProviderStateMixin {
  final PremiumService _premiumService = PremiumService();
  final UserService _userService = UserService();
  final SoundService _soundService = SoundService();
  final PaymentService _paymentService = PaymentService();

  String? _selectedPlanId;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Hardcoded plans
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'monthly',
      'name': 'Monthly Premium',
      'price': 4.99,
      'originalPrice': null,
      'description': 'Perfect for trying out premium features',
      'features': [
        'Enhanced AI Generation',
        'Advanced Analytics',
        'Priority Support',
        'Premium Themes',
      ],
      'isPopular': false,
      'icon': '🌟',
      'gradient': [Color(0xFF667eea), Color(0xFF764ba2)],
    },
    {
      'id': 'yearly',
      'name': 'Yearly Premium',
      'price': 39.99,
      'originalPrice': 59.88,
      'description': 'Best value - Save 33%',
      'features': [
        'Everything in Monthly',
        'Exclusive Yearly Rewards',
        'Enhanced AI Personalization',
        'Advanced Analytics Dashboard',
      ],
      'isPopular': true,
      'icon': '👑',
      'gradient': [Color(0xFFf093fb), Color(0xFFf5576c)],
    },
    {
      'id': 'lifetime',
      'name': 'Lifetime Premium',
      'price': 199.99,
      'originalPrice': null,
      'description': 'One-time payment, forever access',
      'features': [
        'Everything in Yearly',
        'Lifetime Updates',
        'VIP Support',
        'Custom Features',
      ],
      'isPopular': false,
      'icon': '💎',
      'gradient': [Color(0xFF4facfe), Color(0xFF00f2fe)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.1),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with animated background
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Choose Your Plan',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Unlock your full potential with premium features',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Plans
                              ..._plans.asMap().entries.map((entry) {
                                final index = entry.key;
                                final plan = entry.value;
                                return AnimatedContainer(
                                  duration: Duration(
                                    milliseconds: 300 + (index * 100),
                                  ),
                                  child: _buildPlanCard(theme, plan, index),
                                );
                              }),

                              const SizedBox(height: 30),

                              // Proceed to Payment Button
                              if (_selectedPlanId != null)
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors:
                                          _plans.firstWhere(
                                                (plan) =>
                                                    plan['id'] ==
                                                    _selectedPlanId,
                                              )['gradient']
                                              as List<Color>,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (_plans.firstWhere(
                                                      (plan) =>
                                                          plan['id'] ==
                                                          _selectedPlanId,
                                                    )['gradient']
                                                    as List<Color>)[0]
                                                .withOpacity(0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _processPayment,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.payment, size: 24),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Proceed to Payment - \$${_plans.firstWhere((plan) => plan['id'] == _selectedPlanId)['price'].toStringAsFixed(2)}',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Error Message
                              if (_errorMessage != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(top: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.red[700]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(ThemeData theme, Map<String, dynamic> plan, int index) {
    final isSelected = _selectedPlanId == plan['id'];
    final isPopular = plan['isPopular'] as bool;
    final gradient = plan['gradient'] as List<Color>;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 0 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? gradient[0].withOpacity(0.3)
                : theme.shadowColor.withOpacity(0.1),
            blurRadius: isSelected ? 20 : 10,
            offset: Offset(0, isSelected ? 10 : 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPlanId = plan['id'];
              _errorMessage = null;
            });
            _soundService.playButtonTap();
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and popular badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : gradient[0].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        plan['icon'],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan['name'],
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            plan['description'],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.9)
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange, Colors.red],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'HOT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Features with animated checkmarks
                ...(plan['features'] as List<String>).map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.9)
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Price and Choose Plan Button
                Row(
                  children: [
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (plan['originalPrice'] != null) ...[
                          Text(
                            '\$${plan['originalPrice'].toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.6)
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.5,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          '\$${plan['price'].toStringAsFixed(2)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : gradient[0],
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          plan['id'] == 'lifetime' ? 'one-time' : '/month',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Choose Plan Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.9),
                                ],
                              )
                            : LinearGradient(colors: gradient),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? Colors.white.withOpacity(0.3)
                                : gradient[0].withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedPlanId = plan['id'];
                            _errorMessage = null;
                          });
                          _soundService.playButtonTap();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: isSelected
                              ? gradient[0]
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.star,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isSelected ? 'Selected' : 'Choose Plan',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    );
  }

  Future<void> _processPayment() async {
    if (_selectedPlanId == null) return;

    try {
      _soundService.playButtonTap();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final selectedPlan = _plans.firstWhere(
        (plan) => plan['id'] == _selectedPlanId,
      );

      // Create a temporary PremiumPlanModel for payment processing
      final planModel = PremiumPlanModel(
        id: selectedPlan['id'],
        name: selectedPlan['name'],
        description: selectedPlan['description'],
        price: selectedPlan['price'].toDouble(),
        currency: 'USD',
        plan: SubscriptionPlan.monthly, // Default to monthly
        durationDays: selectedPlan['id'] == 'lifetime'
            ? 36500
            : selectedPlan['id'] == 'yearly'
            ? 365
            : 30,
        features: List<String>.from(selectedPlan['features']),
      );

      // Navigate to payment proceeding screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentProceedingScreen(plan: planModel),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _soundService.playNotification();
    }
  }
}
