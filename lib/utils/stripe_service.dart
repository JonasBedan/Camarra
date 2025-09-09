import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/premium_model.dart';

class StripeService {
  // Replace with your actual Stripe publishable key
  static const String _publishableKey = 'pk_test_51OqXqNn8PqKTu4DgGfc0';

  // Your backend URL for creating checkout sessions
  static const String _backendUrl = 'http://localhost:3001';

  static Future<void> initialize() async {
    try {
      // Skip Stripe initialization on web platform
      if (kIsWeb) {
        print('Stripe initialization skipped on web platform');
        return;
      }

      Stripe.publishableKey = _publishableKey;
      await Stripe.instance.applySettings();
    } catch (e) {
      print('Stripe initialization error: $e');
      // For web platform, we'll continue without Stripe
    }
  }

  Future<PaymentResult> processPayment({
    required PremiumPlanModel plan,
    required String userId,
    required String userEmail,
  }) async {
    try {
      // Create checkout session on your backend
      final checkoutSession = await _createCheckoutSession(
        plan,
        userEmail,
        userId,
      );

      // For web, we'll redirect to the checkout URL
      // For mobile, we would use Stripe.instance.redirectToCheckout
      if (checkoutSession['url'] != null) {
        // In a real app, you would handle the redirect properly
        // For now, we'll return success and let the UI handle the redirect
        return PaymentResult(
          success: true,
          paymentId: checkoutSession['id'],
          message:
              'Checkout session created. Redirect to: ${checkoutSession['url']}',
        );
      }

      return PaymentResult(
        success: false,
        error: 'No checkout URL received',
        message: 'Failed to create checkout session',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: e.toString(),
        message: 'Payment failed: $e',
      );
    }
  }

  // Cancel subscription through Stripe
  Future<CancelResult> cancelSubscription(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/cancel-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return CancelResult(
          success: true,
          message: result['message'] ?? 'Subscription cancelled successfully',
        );
      } else {
        throw Exception('Failed to cancel subscription: ${response.body}');
      }
    } catch (e) {
      return CancelResult(
        success: false,
        error: e.toString(),
        message: 'Failed to cancel subscription: $e',
      );
    }
  }

  // Get customer portal URL for subscription management
  Future<String?> getCustomerPortalUrl(String userId, String returnUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/create-portal-session'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'return_url': returnUrl}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['url'];
      } else {
        throw Exception('Failed to create portal session: ${response.body}');
      }
    } catch (e) {
      print('Error getting customer portal URL: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _createCheckoutSession(
    PremiumPlanModel plan,
    String userEmail,
    String userId,
  ) async {
    // This would be your actual backend endpoint
    final response = await http.post(
      Uri.parse('$_backendUrl/create-checkout-session'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'plan_id': plan.id,
        'plan_name': plan.name,
        'amount': (plan.price * 100).round(), // Convert to cents
        'currency': plan.currency.toLowerCase(),
        'customer_email': userEmail,
        'user_id': userId,
        'success_url':
            'http://localhost:3000/success?session_id={CHECKOUT_SESSION_ID}',
        'cancel_url': 'http://localhost:3000/cancel',
        'mode': plan.id == 'lifetime' ? 'payment' : 'subscription',
        'line_items': [
          {
            'price_data': {
              'currency': plan.currency.toLowerCase(),
              'product_data': {
                'name': plan.name,
                'description': plan.description,
              },
              'unit_amount': (plan.price * 100).round(),
              ...(plan.id != 'lifetime'
                  ? {
                      'recurring': {
                        'interval': plan.id == 'yearly' ? 'year' : 'month',
                      },
                    }
                  : {}),
            },
            'quantity': 1,
          },
        ],
        'metadata': {'user_id': userId, 'plan_id': plan.id},
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create checkout session: ${response.body}');
    }
  }
}

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? error;
  final String message;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.error,
    required this.message,
  });
}

class CancelResult {
  final bool success;
  final String? error;
  final String message;

  CancelResult({required this.success, this.error, required this.message});
}
