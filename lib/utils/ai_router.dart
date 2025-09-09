import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ai_log_model.dart';

enum AiTaskType {
  dailyMission,
  mainMission,
  mainMissionPlanning,
  bookNaming,
  icebreaker,
  feedbackCoach,
  moodReflection,
  buddyMatching,
}

class AiModel {
  final String name;
  final String provider;
  final String apiKey;
  final String baseUrl;
  final Map<String, dynamic> defaultParams;

  const AiModel({
    required this.name,
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.defaultParams,
  });
}

class AiRouter {
  static const Map<AiTaskType, AiModel> _modelMapping = {
    // Daily Mission Generation - LLaMA 3 via Groq
    AiTaskType.dailyMission: AiModel(
      name: 'meta-llama/Llama-3-8b-chat',
      provider: 'groq',
      apiKey:
          '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', // Replace with actual key
      baseUrl: 'https://api.groq.com/openai/v1/chat/completions',
      defaultParams: {
        'model': 'llama3-8b-8192',
        'temperature': 0.7,
        'max_tokens': 200,
      },
    ),

    // Main Mission Planning - Mixtral via Together.ai
    AiTaskType.mainMissionPlanning: AiModel(
      name: 'mistralai/Mixtral-8x7b-instruct',
      provider: 'together',
      apiKey:
          'tgp_v1_olAQck78l5-f5EKCOl8nV6pk0JQDRriK5SzjBO3-PLc', // Replace with actual key
      baseUrl: 'https://api.together.xyz/v1/chat/completions',
      defaultParams: {
        'model': 'mistralai/Mixtral-8x7b-Instruct-v0.1',
        'temperature': 0.8,
        'max_tokens': 500,
      },
    ),

    // Main Mission Generation - Mixtral via Together.ai
    AiTaskType.mainMission: AiModel(
      name: 'mistralai/Mixtral-8x7b-instruct',
      provider: 'together',
      apiKey:
          'tgp_v1_olAQck78l5-f5EKCOl8nV6pk0JQDRriK5SzjBO3-PLc', // Replace with actual key
      baseUrl: 'https://api.together.xyz/v1/chat/completions',
      defaultParams: {
        'model': 'mistralai/Mixtral-8x7b-Instruct-v0.1',
        'temperature': 0.8,
        'max_tokens': 500,
      },
    ),

    // Book/Arc Naming - GPT-4o
    AiTaskType.bookNaming: AiModel(
      name: 'gpt-4.1',
      provider: 'openai',
      apiKey:
          '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', // Replace with actual key
      baseUrl: 'https://api.openai.com/v1/chat/completions',
      defaultParams: {'model': 'gpt-4o', 'temperature': 0.9, 'max_tokens': 150},
    ),

    // Icebreaker Questions - Mistral via Together.ai
    AiTaskType.icebreaker: AiModel(
      name: 'mistralai/Mistral-7B-Instruct',
      provider: 'together',
      apiKey:
          'tgp_v1_OQr26d6I3sPGs8FYSngBCnwmXjfVvMxRFjsirJFnOg0', // Replace with actual key
      baseUrl: 'https://api.together.xyz/v1/chat/completions',
      defaultParams: {
        'model': 'mistralai/Mistral-7B-Instruct-v0.2',
        'temperature': 0.7,
        'max_tokens': 100,
      },
    ),

    // Feedback Coach - GPT-3.5-turbo
    AiTaskType.feedbackCoach: AiModel(
      name: 'gpt-4.1',
      provider: 'openai',
      apiKey:
          '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', // Replace with actual key
      baseUrl: 'https://api.openai.com/v1/chat/completions',
      defaultParams: {
        'model': 'gpt-3.5-turbo',
        'temperature': 0.6,
        'max_tokens': 300,
      },
    ),

    // Mood Reflection - GPT-4o
    AiTaskType.moodReflection: AiModel(
      name: 'gpt-4.1',
      provider: 'openai',
      apiKey:
          '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', // Replace with actual key
      baseUrl: 'https://api.openai.com/v1/chat/completions',
      defaultParams: {'model': 'gpt-4o', 'temperature': 0.5, 'max_tokens': 400},
    ),

    // Buddy Matching - Claude (future)
    AiTaskType.buddyMatching: AiModel(
      name: 'claude-3-opus',
      provider: 'anthropic',
      apiKey:
          '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', // Replace with actual key
      baseUrl: 'https://api.anthropic.com/v1/messages',
      defaultParams: {'model': 'claude-3-opus-20240229', 'max_tokens': 1000},
    ),
  };

  static AiModel selectModel({required AiTaskType task}) {
    return _modelMapping[task] ?? _modelMapping[AiTaskType.dailyMission]!;
  }

  static Future<String> generate({
    required AiTaskType task,
    required String prompt,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      final model = selectModel(task: task);
      final params = {...model.defaultParams, ...?additionalParams};

      final response = await _makeApiCall(
        task: task,
        model: model,
        prompt: prompt,
        params: params,
      );

      return response;
    } catch (e) {
      print('AI generation error: $e');
      // Fallback to a simple response
      return _getFallbackResponse(task);
    }
  }

  static Future<String> _makeApiCall({
    required AiTaskType task,
    required AiModel model,
    required String prompt,
    required Map<String, dynamic> params,
  }) async {
    print('Making API call to: ${model.baseUrl}');
    print('Provider: ${model.provider}');
    print('API Key (first 10 chars): ${model.apiKey.substring(0, 10)}...');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${model.apiKey}',
    };

    Map<String, dynamic> body;

    switch (model.provider) {
      case 'groq':
      case 'openai':
      case 'together':
        body = {
          'messages': [
            {'role': 'system', 'content': _getSystemPrompt(model.name)},
            {'role': 'user', 'content': prompt},
          ],
          ...params,
        };
        break;

      case 'anthropic':
        body = {
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          ...params,
        };
        break;

      default:
        throw Exception('Unsupported provider: ${model.provider}');
    }

    print('Sending request to API...');
    final response = await http.post(
      Uri.parse(model.baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final extractedResponse = _extractResponse(data, model.provider);
      print('Extracted response: $extractedResponse');

      // Log the AI call to Firestore
      await _logAiCall(task, prompt, extractedResponse, model.name);

      return extractedResponse;
    } else {
      print('API call failed with status: ${response.statusCode}');
      throw Exception(
        'API call failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static String _getSystemPrompt(String modelName) {
    switch (modelName) {
      case 'meta-llama/Llama-3-8b-chat':
        return 'You are Camarra, a supportive AI assistant helping users overcome social anxiety. Generate creative, achievable daily missions that are personalized and encouraging. Keep responses concise and motivating.';

      case 'mistralai/Mixtral-8x7b-instruct':
        return 'You are Camarra\'s mission planner. Create structured, progressive mission plans that guide users toward social mastery. Focus on narrative coherence and emotional growth.';

      case 'gpt-4o':
        return 'You are Camarra\'s creative assistant. Generate poetic, meaningful names and provide deep emotional insights. Be empathetic and supportive in all responses.';

      case 'mistralai/Mistral-7B-Instruct':
        return 'You are Camarra\'s social assistant. Generate friendly, engaging icebreaker questions that help users connect with their buddies. Be warm and approachable.';

      case 'gpt-3.5-turbo':
        return 'You are Camarra\'s feedback coach. Provide encouraging, constructive feedback after mission completion. Be supportive and help users reflect on their progress.';

      default:
        return 'You are Camarra, a supportive AI assistant helping users overcome social anxiety.';
    }
  }

  static String _extractResponse(Map<String, dynamic> data, String provider) {
    switch (provider) {
      case 'groq':
      case 'openai':
      case 'together':
        return data['choices'][0]['message']['content'] ?? '';

      case 'anthropic':
        return data['content'][0]['text'] ?? '';

      default:
        return '';
    }
  }

  static String _getFallbackResponse(AiTaskType task) {
    switch (task) {
      case AiTaskType.dailyMission:
        return 'Take a deep breath and smile at a stranger today. You\'ve got this!';

      case AiTaskType.mainMission:
        return '{"title": "Personal Growth Mission", "description": "Take a step toward your social goals today. Reflect on your progress and plan your next action.", "book": "Growth", "chapter": "1"}';

      case AiTaskType.mainMissionPlanning:
        return 'Your journey to social confidence continues. Keep pushing your boundaries gently.';

      case AiTaskType.bookNaming:
        return 'Chapter of Courage';

      case AiTaskType.icebreaker:
        return 'What\'s the most interesting thing that happened to you this week?';

      case AiTaskType.feedbackCoach:
        return 'Great job completing your mission! Every step forward is progress.';

      case AiTaskType.moodReflection:
        return 'You\'re doing amazing work on your social journey. Keep reflecting and growing.';

      case AiTaskType.buddyMatching:
        return 'Finding the perfect buddy for your journey...';
    }
  }

  // Log AI calls to Firestore for debugging and insights
  static Future<void> _logAiCall(
    AiTaskType taskType,
    String prompt,
    String response,
    String model,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final aiLog = AILogModel(
        id: '', // Will be auto-generated by Firestore
        type: taskType.toString(),
        prompt: prompt,
        response: response,
        model: model,
        timestamp: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('aiLogs')
          .add(aiLog.toFirestore());
    } catch (e) {
      print('Failed to log AI call: $e');
    }
  }
}
