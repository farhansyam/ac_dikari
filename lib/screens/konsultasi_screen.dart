import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/setting_service.dart';

// ─── Models ───────────────────────────────────────────────────────

enum _MessageType { user, bot, options, actions, pricing }

class _ChatMessage {
  final _MessageType type;
  final String? text;
  final List<_Option>? options;
  final List<_Action>? actions;
  final _PricingData? pricingData;
  final bool isTopicLevel;

  _ChatMessage({
    required this.type,
    this.text,
    this.options,
    this.actions,
    this.pricingData,
    this.isTopicLevel = false,
  });
}

class _TopicModel {
  final int id;
  final String emoji;
  final String title;
  final String subtitle;
  final List<_QuestionModel> questions;

  _TopicModel({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.questions,
  });

  factory _TopicModel.fromJson(Map<String, dynamic> json) {
    return _TopicModel(
      id: json['id'],
      emoji: json['emoji'] ?? '💬',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      questions: (json['questions'] as List? ?? [])
          .map((q) => _QuestionModel.fromJson(q))
          .toList(),
    );
  }
}

class _QuestionModel {
  final int id;
  final String emoji;
  final String text;
  final String? answer;
  final String actionRoute; // ← tambah

  _QuestionModel({
    required this.id,
    required this.emoji,
    required this.text,
    this.answer,
    this.actionRoute = 'perbaikan', // ← default
  });

  factory _QuestionModel.fromJson(Map<String, dynamic> json) {
    return _QuestionModel(
      id: json['id'],
      emoji: json['emoji'] ?? '❓',
      text: json['text'] ?? '',
      answer: json['answer'],
      actionRoute: json['action_route'] ?? 'perbaikan', // ← tambah
    );
  }
}

class _Option {
  final String id;
  final String text;
  final String emoji;
  final dynamic data;

  const _Option({
    required this.id,
    required this.text,
    required this.emoji,
    this.data,
  });
}

class _Action {
  final String label;
  final String route;
  final IconData icon;
  final Color color;

  const _Action({
    required this.label,
    required this.route,
    required this.icon,
    required this.color,
  });
}

class _PricingData {
  final String bpName;
  final String city;
  final List<Map<String, dynamic>> services;

  _PricingData({
    required this.bpName,
    required this.city,
    required this.services,
  });
}

// ─── Helpers ──────────────────────────────────────────────────────

String _categoryLabel(String category) {
  switch (category) {
    case 'cuci_reguler':
      return 'Cuci Reguler';
    case 'cuci':
      return 'Cuci';
    case 'pasang_baru':
      return 'Pasang Baru';
    case 'unit':
      return 'Unit AC';
    case 'relokasi':
      return 'Relokasi';
    case 'relokasi_pasang':
      return 'Relokasi (Pasang)';
    case 'relokasi_bongkar':
      return 'Relokasi (Bongkar)';
    case 'service_perbaikan_survey':
      return 'Survey Perbaikan';
    case 'service_perbaikan_service':
      return 'Perbaikan';
    case 'home_care':
      return 'Home Care';
    case 'car_wash':
      return 'Car Wash';
    case 'massage':
      return 'Massage';
    default:
      return category;
  }
}

String _categoryEmoji(String category) {
  switch (category) {
    case 'cuci_reguler':
    case 'cuci':
      return '🫧';
    case 'pasang_baru':
      return '🔧';
    case 'unit':
      return '❄️';
    case 'relokasi':
    case 'relokasi_pasang':
    case 'relokasi_bongkar':
      return '🚚';
    case 'service_perbaikan_survey':
    case 'service_perbaikan_service':
      return '🛠️';
    case 'home_care':
      return '🏠';
    case 'car_wash':
      return '🚗';
    case 'massage':
      return '💆';
    default:
      return '⚙️';
  }
}

// ─── Screen ───────────────────────────────────────────────────────

class KonsultasiScreen extends StatefulWidget {
  const KonsultasiScreen({Key? key}) : super(key: key);

  @override
  State<KonsultasiScreen> createState() => _KonsultasiScreenState();
}

class _KonsultasiScreenState extends State<KonsultasiScreen> {
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  List<_TopicModel> _topics = [];
  List<Map<String, dynamic>> _businessPartners = [];
  bool _isTyping = false;
  bool _loadingTopics = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Load Data ────────────────────────────────────────────────

  Future<void> _loadData() async {
    await Future.wait([_loadTopics(), _loadBusinessPartners()]);
    _initChat();
  }

  Future<void> _loadTopics() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/konsultasi'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _topics = (data['topics'] as List? ?? [])
                .map((t) => _TopicModel.fromJson(t))
                .toList();
            _loadingTopics = false;
          });
        }
      } else {
        if (mounted)
          setState(() {
            _loadingTopics = false;
            _loadError = 'Gagal memuat topik.';
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loadingTopics = false;
          _loadError = 'Tidak dapat terhubung ke server.';
        });
    }
  }

  Future<void> _loadBusinessPartners() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/business-partners/public'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _businessPartners = List<Map<String, dynamic>>.from(
          data['business_partners'] ?? [],
        );
      }
    } catch (_) {}
  }

  void _initChat() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addBotMessage(
        'Halo! 👋 Saya Dikari Assistant, siap membantu masalah AC kamu.',
      );
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_loadError != null) {
        _addBotMessage(
          'Maaf, $_loadError Silakan coba lagi nanti atau hubungi CS kami.',
        );
        return;
      }
      if (_topics.isEmpty) {
        _addBotMessage(
          'Maaf, belum ada topik konsultasi yang tersedia. Silakan hubungi CS kami langsung.',
        );
        return;
      }
      _addBotMessage('Pilih topik yang sesuai dengan keluhanmu:');
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted || _topics.isEmpty) return;
      _addTopicOptions();
    });
  }

  // ─── Message Helpers ──────────────────────────────────────────

  void _addBotMessage(String text) {
    if (!mounted) return;
    setState(
      () => _messages.add(_ChatMessage(type: _MessageType.bot, text: text)),
    );
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    if (!mounted) return;
    setState(
      () => _messages.add(_ChatMessage(type: _MessageType.user, text: text)),
    );
    _scrollToBottom();
  }

  void _addTopicOptions() {
    if (!mounted) return;
    final options = _topics
        .map(
          (t) => _Option(
            id: t.id.toString(),
            text: t.title,
            emoji: t.emoji,
            data: t,
          ),
        )
        .toList();

    // Tambah opsi Info Harga
    final allOptions = [
      ...options,
      const _Option(id: '__harga__', text: 'Info Harga Layanan', emoji: '💰'),
    ];

    setState(
      () => _messages.add(
        _ChatMessage(
          type: _MessageType.options,
          options: allOptions,
          isTopicLevel: true,
        ),
      ),
    );
    _scrollToBottom();
  }

  void _addQuestionOptions(List<_QuestionModel> questions) {
    if (!mounted) return;
    final options = questions
        .map(
          (q) => _Option(
            id: q.id.toString(),
            text: q.text,
            emoji: q.emoji,
            data: q,
          ),
        )
        .toList();

    setState(
      () => _messages.add(
        _ChatMessage(
          type: _MessageType.options,
          options: options,
          isTopicLevel: false,
        ),
      ),
    );
    _scrollToBottom();
  }

  void _addActions(List<_Action> actions) {
    if (!mounted) return;
    setState(
      () => _messages.add(
        _ChatMessage(type: _MessageType.actions, actions: actions),
      ),
    );
    _scrollToBottom();
  }

  void _addPricing(_PricingData data) {
    if (!mounted) return;
    setState(
      () => _messages.add(
        _ChatMessage(type: _MessageType.pricing, pricingData: data),
      ),
    );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startTyping(int ms) async {
    if (!mounted) return;
    setState(() => _isTyping = true);
    _scrollToBottom();
    await Future.delayed(Duration(milliseconds: ms));
    if (!mounted) return;
    setState(() => _isTyping = false);
  }

  // ─── Handlers ─────────────────────────────────────────────────

  Future<void> _onOptionTapped(_Option option, bool isTopicLevel) async {
    // Info harga
    if (option.id == '__harga__') {
      _addUserMessage('${option.emoji} ${option.text}');
      await _startTyping(800);
      _addBotMessage(
        'Harga layanan berbeda-beda tergantung area mitra. Pilih area/kota kamu:',
      );
      await Future.delayed(const Duration(milliseconds: 300));
      _showBpOptions();
      return;
    }

    // Pilih topik
    if (isTopicLevel && option.data is _TopicModel) {
      final topic = option.data as _TopicModel;
      _addUserMessage('${topic.emoji} ${topic.title}');
      await _startTyping(800);

      if (topic.questions.isEmpty) {
        _addBotMessage(
          'Maaf, belum ada pertanyaan untuk topik ini. Silakan hubungi CS kami.',
        );
        return;
      }

      _addBotMessage('Oke! Lebih spesifik, pilih pertanyaan yang sesuai:');
      await Future.delayed(const Duration(milliseconds: 300));
      _addQuestionOptions(topic.questions);
      return;
    }

    // Pilih pertanyaan
    if (!isTopicLevel && option.data is _QuestionModel) {
      final question = option.data as _QuestionModel;
      _addUserMessage('${question.emoji} ${question.text}');
      await _startTyping(1000);

      final answer = question.answer?.isNotEmpty == true
          ? question.answer!
          : 'Maaf, jawaban belum tersedia. Silakan hubungi CS kami untuk informasi lebih lanjut.';

      _addBotMessage(answer);
      // Ganti bagian ini di _onOptionTapped (setelah _addBotMessage(answer)):
      await Future.delayed(const Duration(milliseconds: 500));

      final actionRoute = question.actionRoute;
      String actionLabel;
      String route;
      IconData icon;
      Color color;

      switch (actionRoute) {
        case 'cuci':
          actionLabel = 'Pesan Cuci AC';
          route = '/order';
          icon = Icons.water_drop_rounded;
          color = Colors.blue.shade600;
          break;
        case 'langganan':
          actionLabel = 'Cuci Langganan';
          route = '/langganan-baru';
          icon = Icons.calendar_month_rounded;
          color = Colors.teal;
          break;
        case 'pasang_baru':
          actionLabel = 'Pasang Baru';
          route = '/pasang-baru';
          icon = Icons.handyman_rounded;
          color = Colors.green;
          break;
        case 'cs':
          actionLabel = 'Hubungi CS';
          route = '__cs__';
          icon = Icons.support_agent_rounded;
          color = Colors.green.shade600;
          break;
        default: // perbaikan
          actionLabel = 'Pesan Perbaikan';
          route = '/perbaikan';
          icon = Icons.build_rounded;
          color = AppTheme.primary;
      }

      _addBotMessage(
        actionRoute == 'cuci'
            ? 'Kemungkinan AC kamu perlu dicuci dulu 🫧'
            : actionRoute == 'langganan'
            ? 'Kamu bisa coba paket Cuci Langganan untuk perawatan rutin 📅'
            : actionRoute == 'cs'
            ? 'Untuk kasus ini sebaiknya konsultasi langsung dengan CS kami 💬'
            : 'Berdasarkan keluhan kamu, kami sarankan service perbaikan 🛠️',
      );

      await Future.delayed(const Duration(milliseconds: 300));
      _addActions([
        _Action(label: actionLabel, route: route, icon: icon, color: color),
        const _Action(
          label: 'Topik Lain',
          route: '__reset__',
          icon: Icons.refresh_rounded,
          color: Colors.orange,
        ),
      ]);
    }

    // Pilih BP
    if (option.data is Map<String, dynamic>) {
      final bp = option.data as Map<String, dynamic>;
      _addUserMessage('📍 ${option.text}');
      await _startTyping(800);

      final services = List<Map<String, dynamic>>.from(bp['services'] ?? []);
      if (services.isEmpty) {
        _addBotMessage(
          'Maaf, mitra ini belum memiliki layanan yang terdaftar.',
        );
        return;
      }

      _addBotMessage(
        'Berikut daftar harga layanan dari ${bp['name']} (${bp['city'] ?? '-'}):',
      );
      await Future.delayed(const Duration(milliseconds: 300));
      _addPricing(
        _PricingData(
          bpName: bp['name'] ?? '-',
          city: bp['city'] ?? '-',
          services: services,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 400));
      _addActions([
        const _Action(
          label: 'Pesan Sekarang',
          route: '/order',
          icon: Icons.flash_on_rounded,
          color: AppTheme.primary,
        ),
        const _Action(
          label: 'Area Lain',
          route: '__bp_picker__',
          icon: Icons.location_on_rounded,
          color: Colors.purple,
        ),
        const _Action(
          label: 'Topik Lain',
          route: '__reset__',
          icon: Icons.refresh_rounded,
          color: Colors.orange,
        ),
      ]);
    }
  }

  void _showBpOptions() {
    if (_businessPartners.isEmpty) {
      _addBotMessage('Maaf, tidak ada mitra yang tersedia saat ini.');
      return;
    }

    final options = _businessPartners
        .map(
          (bp) => _Option(
            id: bp['id'].toString(),
            text: '${bp['name']} — ${bp['city'] ?? '-'}',
            emoji: '📍',
            data: bp,
          ),
        )
        .toList();

    setState(
      () => _messages.add(
        _ChatMessage(
          type: _MessageType.options,
          options: options,
          isTopicLevel: false,
        ),
      ),
    );
    _scrollToBottom();
  }

  Future<void> _onActionTapped(_Action action) async {
    if (action.route == '__reset__') {
      _addUserMessage('🔄 Topik lain');
      await _startTyping(600);
      _addBotMessage('Tentu! Pilih topik lain yang ingin kamu tanyakan:');
      await Future.delayed(const Duration(milliseconds: 300));
      _addTopicOptions();
    } else if (action.route == '__bp_picker__') {
      _addUserMessage('📍 Cari area lain');
      await _startTyping(500);
      _addBotMessage('Pilih area/kota kamu:');
      await Future.delayed(const Duration(milliseconds: 300));
      _showBpOptions();
    } else if (action.route == '__cs__') {
      _openWhatsApp();
    } else {
      Navigator.of(context).pushNamed(action.route);
    }
  }

  Future<void> _openWhatsApp() async {
    final settings = await SettingService.getWaSettings();
    final phone = settings['wa_cs'] ?? '';
    final message =
        settings['wa_message_cs'] ??
        'Halo Dikari, saya butuh bantuan konsultasi AC';
    if (phone.isNotEmpty) {
      await SettingService.openWhatsApp(phone, message);
    }
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dikari Assistant',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: 'Chat CS',
            onPressed: _openWhatsApp,
          ),
        ],
      ),
      body: _loadingTopics
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _messages.length)
                        return _buildTypingIndicator();
                      return _buildMessage(_messages[index]);
                    },
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    switch (message.type) {
      case _MessageType.bot:
        return _buildBotBubble(message.text!);
      case _MessageType.user:
        return _buildUserBubble(message.text!);
      case _MessageType.options:
        return _buildOptionChips(message.options!, message.isTopicLevel);
      case _MessageType.actions:
        return _buildActionButtons(message.actions!);
      case _MessageType.pricing:
        return _buildPricingCard(message.pricingData!);
    }
  }

  Widget _buildBotBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 16)),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChips(List<_Option> options, bool isTopicLevel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (option) => GestureDetector(
                onTap: () => _onOptionTapped(option, isTopicLevel),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        option.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPricingCard(_PricingData data) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in data.services) {
      final cat = s['category'] as String? ?? 'lainnya';
      grouped.putIfAbsent(cat, () => []).add(s);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.bpName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          data.city,
                          style: TextStyle(
                            color: AppTheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...grouped.entries.map((entry) {
              final cat = entry.key;
              final services = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Row(
                      children: [
                        Text(
                          _categoryEmoji(cat),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _categoryLabel(cat),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...services.map((s) {
                    final basePrice = (s['base_price'] as num).toDouble();
                    final finalPrice = (s['final_price'] as num).toDouble();
                    final discount = (s['discount'] as num).toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s['name'] ?? '-',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (discount > 0)
                                Text(
                                  _formatCurrency(basePrice),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                _formatCurrency(finalPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade100,
                    indent: 16,
                    endIndent: 16,
                  ),
                ],
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                '*Harga belum termasuk biaya tambahan (apartemen, transportasi, dll)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(List<_Action> actions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (action) => GestureDetector(
                onTap: () => _onActionTapped(action),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: action.color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: action.color.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(action.icon, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        action.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤖', style: TextStyle(fontSize: 16)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _openWhatsApp,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.green.shade500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Butuh bantuan lebih lanjut?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Chat langsung dengan CS via WhatsApp',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Colors.green.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }
}

// ─── Typing Dots ──────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value - i * 0.2).clamp(0.0, 1.0);
            final bounce = t < 0.5 ? t * 2 : (1 - t) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.3 + bounce * 0.7),
                shape: BoxShape.circle,
              ),
              transform: Matrix4.translationValues(0, -4 * bounce, 0),
            );
          }),
        );
      },
    );
  }
}
