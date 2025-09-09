import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class SettingsProvider extends ChangeNotifier {
  final UserService _userService = UserService();

  // App-wide settings state
  bool _isDarkMode = false;
  String _language = 'English';
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  String _moodCheckInFrequency = 'Every 3 days';
  bool _missionRemindersEnabled = true;
  bool _buddyMessagesEnabled = true;
  bool _dataCollectionEnabled = true;
  bool _analyticsEnabled = true;

  // Getters
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get soundEnabled => _soundEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  String get moodCheckInFrequency => _moodCheckInFrequency;
  bool get missionRemindersEnabled => _missionRemindersEnabled;
  bool get buddyMessagesEnabled => _buddyMessagesEnabled;
  bool get dataCollectionEnabled => _dataCollectionEnabled;
  bool get analyticsEnabled => _analyticsEnabled;

  // Initialize settings from user data
  Future<void> loadUserSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _userService.getUser(user.uid);
      if (userData != null) {
        _isDarkMode = userData.settings.darkModeEnabled;
        _language = userData.settings.language;
        _soundEnabled = userData.settings.soundEnabled;
        _notificationsEnabled = userData.settings.pushNotificationsEnabled;
        _moodCheckInFrequency = userData.settings.moodCheckInFrequency;
        _missionRemindersEnabled = userData.settings.missionRemindersEnabled;
        _buddyMessagesEnabled = userData.settings.buddyMessagesEnabled;
        _dataCollectionEnabled = userData.settings.dataCollectionEnabled;
        _analyticsEnabled = userData.settings.analyticsEnabled;
        notifyListeners();
      }
    }
  }

  // Update settings and save to Firestore
  Future<void> updateSetting(String settingKey, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _userService.updateSetting(user.uid, settingKey, value);

      // Update local state
      switch (settingKey) {
        case 'darkModeEnabled':
          _isDarkMode = value;
          break;
        case 'language':
          _language = value;
          break;
        case 'soundEnabled':
          _soundEnabled = value;
          break;
        case 'pushNotificationsEnabled':
          _notificationsEnabled = value;
          break;
        case 'moodCheckInFrequency':
          _moodCheckInFrequency = value;
          break;
        case 'missionRemindersEnabled':
          _missionRemindersEnabled = value;
          break;
        case 'buddyMessagesEnabled':
          _buddyMessagesEnabled = value;
          break;
        case 'dataCollectionEnabled':
          _dataCollectionEnabled = value;
          break;
        case 'analyticsEnabled':
          _analyticsEnabled = value;
          break;
      }

      notifyListeners();
    } catch (e) {
      print('Error updating setting $settingKey: $e');
      rethrow;
    }
  }

  // Get theme data based on dark mode setting
  ThemeData getThemeData() {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  // Light theme
  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B46C1),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF1ECFB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
      ),
    ),
  );

  // Dark theme
  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B46C1),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A1A1A),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
      ),
    ),
    // Additional dark theme overrides
    dividerTheme: const DividerThemeData(color: Color(0xFF2D2D2D)),
    iconTheme: const IconThemeData(color: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Colors.white),
      labelLarge: TextStyle(color: Colors.white),
      labelMedium: TextStyle(color: Colors.white),
      labelSmall: TextStyle(color: Colors.white70),
    ),
  );

  // Get localized strings based on language
  Map<String, String> getLocalizedStrings() {
    switch (_language) {
      case 'Spanish':
        return _spanishStrings;
      case 'French':
        return _frenchStrings;
      case 'German':
        return _germanStrings;
      default:
        return _englishStrings;
    }
  }

  // Localized strings
  static const Map<String, String> _englishStrings = {
    'home': 'Home',
    'missions': 'Missions',
    'chat': 'Chat',
    'settings': 'Settings',
    'daily_mission': 'Daily Mission',
    'complete': 'Complete',
    'completed': 'Completed!',
    'level': 'Level',
    'xp': 'XP',
    'streak': 'Streak',
    'buddy': 'Buddy',
    'search': 'Search',
    'send_request': 'Send Request',
    'accept': 'Accept',
    'decline': 'Decline',
    'logout': 'Logout',
    'login': 'Login',
    'register': 'Register',
    'email': 'Email',
    'password': 'Password',
    'confirm_password': 'Confirm Password',
    'start_journey': 'Start Journey',
    'welcome': 'Welcome',
    'onboarding': 'Onboarding',
    'next': 'Next',
    'skip': 'Skip',
    'save': 'Save',
    'cancel': 'Cancel',
    'ok': 'OK',
    'error': 'Error',
    'success': 'Success',
    'loading': 'Loading...',
    'no_data': 'No data available',
    'try_again': 'Try Again',
    'close': 'Close',
    'back': 'Back',
    'forward': 'Forward',
    'edit': 'Edit',
    'delete': 'Delete',
    'share': 'Share',
    'copy': 'Copy',
    'paste': 'Paste',
    'select_all': 'Select All',
    'undo': 'Undo',
    'redo': 'Redo',
    'cut': 'Cut',
    'find': 'Find',
    'replace': 'Replace',
    'zoom_in': 'Zoom In',
    'zoom_out': 'Zoom Out',
    'fullscreen': 'Fullscreen',
    'exit_fullscreen': 'Exit Fullscreen',
    'refresh': 'Refresh',
    'stop': 'Stop',
    'play': 'Play',
    'pause': 'Pause',
    'mute': 'Mute',
    'unmute': 'Unmute',
    'volume_up': 'Volume Up',
    'volume_down': 'Volume Down',
    'settings_title': 'Settings',
    'profile': 'Profile',
    'preferences': 'Preferences',
    'notifications': 'Notifications',
    'privacy_security': 'Privacy & Security',
    'support': 'Support',
    'account': 'Account',
    'dark_mode': 'Dark Mode',
    'sound_effects': 'Sound Effects',
    'language': 'Language',
    'push_notifications': 'Push Notifications',
    'mood_checkins': 'Mood Check-ins',
    'mission_reminders': 'Mission Reminders',
    'buddy_messages': 'Buddy Messages',
    'data_collection': 'Data Collection',
    'analytics': 'Analytics',
    'change_password': 'Change Password',
    'privacy_policy': 'Privacy Policy',
    'terms_of_service': 'Terms of Service',
    'help_faq': 'Help & FAQ',
    'contact_support': 'Contact Support',
    'about_camarra': 'About Camarra',
    'rate_app': 'Rate App',
    'export_data': 'Export Data',
    'delete_account': 'Delete Account',
    'upgrade_premium': 'Upgrade to Premium',
    'current_password': 'Current Password',
    'new_password': 'New Password',
    'confirm_new_password': 'Confirm New Password',
    'change_password_success': 'Password changed successfully!',
    'passwords_dont_match': 'New passwords do not match!',
    'setting_updated': 'Setting updated successfully!',
    'data_exported': 'Data exported successfully!',
    'account_deleted': 'Account deleted successfully!',
    'logout_confirm': 'Are you sure you want to logout?',
    'delete_account_confirm':
        'This action cannot be undone. All your data, progress, and conversations will be permanently deleted.',
    'export_data_confirm':
        'Export your data including conversations, progress, and settings. This may take a few moments.',
    'premium_upgrade_text':
        'Get unlimited AI features, unlimited faith sending, exclusive themes, and priority support!',
    'privacy_policy_text':
        'Your privacy is important to us. We collect minimal data to provide you with the best experience. Full privacy policy available on our website.',
    'terms_of_service_text':
        'By using Camarra, you agree to our terms of service. Full terms available on our website.',
    'help_faq_text':
        'Need help? Check our FAQ or contact support. We\'re here to help you on your journey!',
    'contact_support_text':
        'Email us at support@camarra.app or use the in-app chat with Camarra for immediate help!',
    'about_camarra_text':
        'Camarra is your AI-powered companion for overcoming social anxiety. Built with love and science to help you grow and thrive.',
    'rate_app_text':
        'Enjoying Camarra? Please rate us on the App Store! Your feedback helps us improve and reach more people who need support.',
  };

  static const Map<String, String> _spanishStrings = {
    'home': 'Inicio',
    'missions': 'Misiones',
    'chat': 'Chat',
    'settings': 'Configuración',
    'daily_mission': 'Misión Diaria',
    'complete': 'Completar',
    'completed': '¡Completado!',
    'level': 'Nivel',
    'xp': 'XP',
    'streak': 'Racha',
    'buddy': 'Compañero',
    'search': 'Buscar',
    'send_request': 'Enviar Solicitud',
    'accept': 'Aceptar',
    'decline': 'Rechazar',
    'logout': 'Cerrar Sesión',
    'login': 'Iniciar Sesión',
    'register': 'Registrarse',
    'email': 'Correo Electrónico',
    'password': 'Contraseña',
    'confirm_password': 'Confirmar Contraseña',
    'start_journey': 'Comenzar Viaje',
    'welcome': 'Bienvenido',
    'onboarding': 'Configuración Inicial',
    'next': 'Siguiente',
    'skip': 'Saltar',
    'save': 'Guardar',
    'cancel': 'Cancelar',
    'ok': 'OK',
    'error': 'Error',
    'success': 'Éxito',
    'loading': 'Cargando...',
    'no_data': 'No hay datos disponibles',
    'try_again': 'Intentar de Nuevo',
    'close': 'Cerrar',
    'back': 'Atrás',
    'forward': 'Adelante',
    'edit': 'Editar',
    'delete': 'Eliminar',
    'share': 'Compartir',
    'copy': 'Copiar',
    'paste': 'Pegar',
    'select_all': 'Seleccionar Todo',
    'undo': 'Deshacer',
    'redo': 'Rehacer',
    'cut': 'Cortar',
    'find': 'Buscar',
    'replace': 'Reemplazar',
    'zoom_in': 'Acercar',
    'zoom_out': 'Alejar',
    'fullscreen': 'Pantalla Completa',
    'exit_fullscreen': 'Salir de Pantalla Completa',
    'refresh': 'Actualizar',
    'stop': 'Detener',
    'play': 'Reproducir',
    'pause': 'Pausar',
    'mute': 'Silenciar',
    'unmute': 'Activar Sonido',
    'volume_up': 'Subir Volumen',
    'volume_down': 'Bajar Volumen',
    'settings_title': 'Configuración',
    'profile': 'Perfil',
    'preferences': 'Preferencias',
    'notifications': 'Notificaciones',
    'privacy_security': 'Privacidad y Seguridad',
    'support': 'Soporte',
    'account': 'Cuenta',
    'dark_mode': 'Modo Oscuro',
    'sound_effects': 'Efectos de Sonido',
    'language': 'Idioma',
    'push_notifications': 'Notificaciones Push',
    'mood_checkins': 'Registros de Estado de Ánimo',
    'mission_reminders': 'Recordatorios de Misión',
    'buddy_messages': 'Mensajes de Compañero',
    'data_collection': 'Recopilación de Datos',
    'analytics': 'Análisis',
    'change_password': 'Cambiar Contraseña',
    'privacy_policy': 'Política de Privacidad',
    'terms_of_service': 'Términos de Servicio',
    'help_faq': 'Ayuda y Preguntas Frecuentes',
    'contact_support': 'Contactar Soporte',
    'about_camarra': 'Acerca de Camarra',
    'rate_app': 'Calificar App',
    'export_data': 'Exportar Datos',
    'delete_account': 'Eliminar Cuenta',
    'upgrade_premium': 'Actualizar a Premium',
    'current_password': 'Contraseña Actual',
    'new_password': 'Nueva Contraseña',
    'confirm_new_password': 'Confirmar Nueva Contraseña',
    'change_password_success': '¡Contraseña cambiada exitosamente!',
    'passwords_dont_match': '¡Las nuevas contraseñas no coinciden!',
    'setting_updated': '¡Configuración actualizada exitosamente!',
    'data_exported': '¡Datos exportados exitosamente!',
    'account_deleted': '¡Cuenta eliminada exitosamente!',
    'logout_confirm': '¿Estás seguro de que quieres cerrar sesión?',
    'delete_account_confirm':
        'Esta acción no se puede deshacer. Todos tus datos, progreso y conversaciones se eliminarán permanentemente.',
    'export_data_confirm':
        'Exporta tus datos incluyendo conversaciones, progreso y configuraciones. Esto puede tomar unos momentos.',
    'premium_upgrade_text':
        '¡Obtén funciones AI ilimitadas, envío de fe ilimitado, temas exclusivos y soporte prioritario!',
    'privacy_policy_text':
        'Tu privacidad es importante para nosotros. Recopilamos datos mínimos para brindarte la mejor experiencia. Política de privacidad completa disponible en nuestro sitio web.',
    'terms_of_service_text':
        'Al usar Camarra, aceptas nuestros términos de servicio. Términos completos disponibles en nuestro sitio web.',
    'help_faq_text':
        '¿Necesitas ayuda? Revisa nuestras preguntas frecuentes o contacta soporte. ¡Estamos aquí para ayudarte en tu viaje!',
    'contact_support_text':
        '¡Envíanos un correo a support@camarra.app o usa el chat en la app con Camarra para ayuda inmediata!',
    'about_camarra_text':
        'Camarra es tu compañero impulsado por IA para superar la ansiedad social. Construido con amor y ciencia para ayudarte a crecer y prosperar.',
    'rate_app_text':
        '¿Disfrutando Camarra? ¡Por favor califícanos en la App Store! Tu retroalimentación nos ayuda a mejorar y llegar a más personas que necesitan apoyo.',
  };

  static const Map<String, String> _frenchStrings = {
    'home': 'Accueil',
    'missions': 'Missions',
    'chat': 'Chat',
    'settings': 'Paramètres',
    'daily_mission': 'Mission Quotidienne',
    'complete': 'Terminer',
    'completed': 'Terminé !',
    'level': 'Niveau',
    'xp': 'XP',
    'streak': 'Série',
    'buddy': 'Ami',
    'search': 'Rechercher',
    'send_request': 'Envoyer une Demande',
    'accept': 'Accepter',
    'decline': 'Refuser',
    'logout': 'Se Déconnecter',
    'login': 'Se Connecter',
    'register': 'S\'inscrire',
    'email': 'E-mail',
    'password': 'Mot de Passe',
    'confirm_password': 'Confirmer le Mot de Passe',
    'start_journey': 'Commencer le Voyage',
    'welcome': 'Bienvenue',
    'onboarding': 'Configuration Initiale',
    'next': 'Suivant',
    'skip': 'Passer',
    'save': 'Enregistrer',
    'cancel': 'Annuler',
    'ok': 'OK',
    'error': 'Erreur',
    'success': 'Succès',
    'loading': 'Chargement...',
    'no_data': 'Aucune donnée disponible',
    'try_again': 'Réessayer',
    'close': 'Fermer',
    'back': 'Retour',
    'forward': 'Avancer',
    'edit': 'Modifier',
    'delete': 'Supprimer',
    'share': 'Partager',
    'copy': 'Copier',
    'paste': 'Coller',
    'select_all': 'Tout Sélectionner',
    'undo': 'Annuler',
    'redo': 'Rétablir',
    'cut': 'Couper',
    'find': 'Trouver',
    'replace': 'Remplacer',
    'zoom_in': 'Zoom Avant',
    'zoom_out': 'Zoom Arrière',
    'fullscreen': 'Plein Écran',
    'exit_fullscreen': 'Quitter le Plein Écran',
    'refresh': 'Actualiser',
    'stop': 'Arrêter',
    'play': 'Jouer',
    'pause': 'Pause',
    'mute': 'Muet',
    'unmute': 'Activer le Son',
    'volume_up': 'Augmenter le Volume',
    'volume_down': 'Diminuer le Volume',
    'settings_title': 'Paramètres',
    'profile': 'Profil',
    'preferences': 'Préférences',
    'notifications': 'Notifications',
    'privacy_security': 'Confidentialité et Sécurité',
    'support': 'Support',
    'account': 'Compte',
    'dark_mode': 'Mode Sombre',
    'sound_effects': 'Effets Sonores',
    'language': 'Langue',
    'push_notifications': 'Notifications Push',
    'mood_checkins': 'Vérifications d\'Humeur',
    'mission_reminders': 'Rappels de Mission',
    'buddy_messages': 'Messages d\'Ami',
    'data_collection': 'Collecte de Données',
    'analytics': 'Analyses',
    'change_password': 'Changer le Mot de Passe',
    'privacy_policy': 'Politique de Confidentialité',
    'terms_of_service': 'Conditions d\'Utilisation',
    'help_faq': 'Aide et FAQ',
    'contact_support': 'Contacter le Support',
    'about_camarra': 'À Propos de Camarra',
    'rate_app': 'Évaluer l\'App',
    'export_data': 'Exporter les Données',
    'delete_account': 'Supprimer le Compte',
    'upgrade_premium': 'Passer à Premium',
    'current_password': 'Mot de Passe Actuel',
    'new_password': 'Nouveau Mot de Passe',
    'confirm_new_password': 'Confirmer le Nouveau Mot de Passe',
    'change_password_success': 'Mot de passe changé avec succès !',
    'passwords_dont_match': 'Les nouveaux mots de passe ne correspondent pas !',
    'setting_updated': 'Paramètre mis à jour avec succès !',
    'data_exported': 'Données exportées avec succès !',
    'account_deleted': 'Compte supprimé avec succès !',
    'logout_confirm': 'Êtes-vous sûr de vouloir vous déconnecter ?',
    'delete_account_confirm':
        'Cette action ne peut pas être annulée. Toutes vos données, progrès et conversations seront définitivement supprimés.',
    'export_data_confirm':
        'Exportez vos données incluant les conversations, progrès et paramètres. Cela peut prendre quelques instants.',
    'premium_upgrade_text':
        'Obtenez des fonctionnalités IA illimitées, l\'envoi de foi illimité, des thèmes exclusifs et un support prioritaire !',
    'privacy_policy_text':
        'Votre confidentialité est importante pour nous. Nous collectons des données minimales pour vous offrir la meilleure expérience. Politique de confidentialité complète disponible sur notre site web.',
    'terms_of_service_text':
        'En utilisant Camarra, vous acceptez nos conditions d\'utilisation. Conditions complètes disponibles sur notre site web.',
    'help_faq_text':
        'Besoin d\'aide ? Consultez notre FAQ ou contactez le support. Nous sommes là pour vous aider dans votre voyage !',
    'contact_support_text':
        'Envoyez-nous un e-mail à support@camarra.app ou utilisez le chat dans l\'app avec Camarra pour une aide immédiate !',
    'about_camarra_text':
        'Camarra est votre compagnon alimenté par l\'IA pour surmonter l\'anxiété sociale. Construit avec amour et science pour vous aider à grandir et prospérer.',
    'rate_app_text':
        'Vous aimez Camarra ? Veuillez nous évaluer sur l\'App Store ! Vos commentaires nous aident à améliorer et à atteindre plus de personnes qui ont besoin de soutien.',
  };

  static const Map<String, String> _germanStrings = {
    'home': 'Startseite',
    'missions': 'Missionen',
    'chat': 'Chat',
    'settings': 'Einstellungen',
    'daily_mission': 'Tägliche Mission',
    'complete': 'Abschließen',
    'completed': 'Abgeschlossen!',
    'level': 'Level',
    'xp': 'XP',
    'streak': 'Serie',
    'buddy': 'Kumpel',
    'search': 'Suchen',
    'send_request': 'Anfrage Senden',
    'accept': 'Akzeptieren',
    'decline': 'Ablehnen',
    'logout': 'Abmelden',
    'login': 'Anmelden',
    'register': 'Registrieren',
    'email': 'E-Mail',
    'password': 'Passwort',
    'confirm_password': 'Passwort Bestätigen',
    'start_journey': 'Reise Beginnen',
    'welcome': 'Willkommen',
    'onboarding': 'Ersteinrichtung',
    'next': 'Weiter',
    'skip': 'Überspringen',
    'save': 'Speichern',
    'cancel': 'Abbrechen',
    'ok': 'OK',
    'error': 'Fehler',
    'success': 'Erfolg',
    'loading': 'Lädt...',
    'no_data': 'Keine Daten verfügbar',
    'try_again': 'Erneut Versuchen',
    'close': 'Schließen',
    'back': 'Zurück',
    'forward': 'Vorwärts',
    'edit': 'Bearbeiten',
    'delete': 'Löschen',
    'share': 'Teilen',
    'copy': 'Kopieren',
    'paste': 'Einfügen',
    'select_all': 'Alles Auswählen',
    'undo': 'Rückgängig',
    'redo': 'Wiederholen',
    'cut': 'Ausschneiden',
    'find': 'Suchen',
    'replace': 'Ersetzen',
    'zoom_in': 'Vergrößern',
    'zoom_out': 'Verkleinern',
    'fullscreen': 'Vollbild',
    'exit_fullscreen': 'Vollbild Beenden',
    'refresh': 'Aktualisieren',
    'stop': 'Stoppen',
    'play': 'Abspielen',
    'pause': 'Pause',
    'mute': 'Stummschalten',
    'unmute': 'Stummschaltung Aufheben',
    'volume_up': 'Lauter',
    'volume_down': 'Leiser',
    'settings_title': 'Einstellungen',
    'profile': 'Profil',
    'preferences': 'Präferenzen',
    'notifications': 'Benachrichtigungen',
    'privacy_security': 'Datenschutz & Sicherheit',
    'support': 'Support',
    'account': 'Konto',
    'dark_mode': 'Dunkler Modus',
    'sound_effects': 'Soundeffekte',
    'language': 'Sprache',
    'push_notifications': 'Push-Benachrichtigungen',
    'mood_checkins': 'Stimmungs-Check-ins',
    'mission_reminders': 'Missions-Erinnerungen',
    'buddy_messages': 'Kumpel-Nachrichten',
    'data_collection': 'Datensammlung',
    'analytics': 'Analysen',
    'change_password': 'Passwort Ändern',
    'privacy_policy': 'Datenschutzrichtlinie',
    'terms_of_service': 'Nutzungsbedingungen',
    'help_faq': 'Hilfe & FAQ',
    'contact_support': 'Support Kontaktieren',
    'about_camarra': 'Über Camarra',
    'rate_app': 'App Bewerten',
    'export_data': 'Daten Exportieren',
    'delete_account': 'Konto Löschen',
    'upgrade_premium': 'Zu Premium Upgraden',
    'current_password': 'Aktuelles Passwort',
    'new_password': 'Neues Passwort',
    'confirm_new_password': 'Neues Passwort Bestätigen',
    'change_password_success': 'Passwort erfolgreich geändert!',
    'passwords_dont_match': 'Neue Passwörter stimmen nicht überein!',
    'setting_updated': 'Einstellung erfolgreich aktualisiert!',
    'data_exported': 'Daten erfolgreich exportiert!',
    'account_deleted': 'Konto erfolgreich gelöscht!',
    'logout_confirm': 'Sind Sie sicher, dass Sie sich abmelden möchten?',
    'delete_account_confirm':
        'Diese Aktion kann nicht rückgängig gemacht werden. Alle Ihre Daten, Fortschritte und Gespräche werden dauerhaft gelöscht.',
    'export_data_confirm':
        'Exportieren Sie Ihre Daten einschließlich Gesprächen, Fortschritten und Einstellungen. Dies kann einen Moment dauern.',
    'premium_upgrade_text':
        'Erhalten Sie unbegrenzte KI-Funktionen, unbegrenztes Glauben-Senden, exklusive Themes und priorisierten Support!',
    'privacy_policy_text':
        'Ihre Privatsphäre ist uns wichtig. Wir sammeln minimale Daten, um Ihnen die beste Erfahrung zu bieten. Vollständige Datenschutzrichtlinie auf unserer Website verfügbar.',
    'terms_of_service_text':
        'Durch die Nutzung von Camarra stimmen Sie unseren Nutzungsbedingungen zu. Vollständige Bedingungen auf unserer Website verfügbar.',
    'help_faq_text':
        'Brauchen Sie Hilfe? Schauen Sie sich unsere FAQ an oder kontaktieren Sie den Support. Wir sind hier, um Ihnen auf Ihrer Reise zu helfen!',
    'contact_support_text':
        'E-Mail an support@camarra.app oder nutzen Sie den In-App-Chat mit Camarra für sofortige Hilfe!',
    'about_camarra_text':
        'Camarra ist Ihr KI-gestützter Begleiter zur Überwindung sozialer Angst. Gebaut mit Liebe und Wissenschaft, um Ihnen beim Wachsen und Gedeihen zu helfen.',
    'rate_app_text':
        'Gefällt Ihnen Camarra? Bitte bewerten Sie uns im App Store! Ihr Feedback hilft uns zu verbessern und mehr Menschen zu erreichen, die Unterstützung benötigen.',
  };

  // Play sound effect if enabled
  void playSound(String soundName) {
    if (_soundEnabled) {
      // TODO: Implement sound playing
      print('Playing sound: $soundName');
    }
  }

  // Show notification if enabled
  void showNotification(String title, String body) {
    if (_notificationsEnabled) {
      // TODO: Implement push notifications
      print('Showing notification: $title - $body');
    }
  }
}
