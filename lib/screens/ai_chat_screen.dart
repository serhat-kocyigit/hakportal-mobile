import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  List<dynamic> _sessions = [];
  bool _isLoading = false;
  bool _isLoadingSessions = false;
  int? _sessionId;
  String _sessionTitle = 'Yeni Sohbet';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
    });
    _loadSessions();
    _setWelcomeMessage();
  }

  void _checkAccess() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final role = user?['rol'] ?? user?['role'] ?? 'kullanici';
    
    if (role != 'avukat' && role != 'admin') {
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu bölüme sadece avukatlar erişebilir.')),
      );
    }
  }

  void _setWelcomeMessage() {
    setState(() {
      _messages = [{
        'role': 'ai',
        'content': 'Merhaba! Ben HakPortal Hukuk Asistanıyım. Mevzuat, yargıtay kararları ve işçi hakları konusundaki sorularınızı yanıtlayabilirim. Size nasıl yardımcı olabilirim?',
        'time': DateTime.now(),
      }];
    });
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoadingSessions = true);
    try {
      final response = await ApiService.dio.get('/rag/sessions');
      setState(() {
        _sessions = response.data;
        _isLoadingSessions = false;
      });
    } catch (e) {
      setState(() => _isLoadingSessions = false);
    }
  }

  Future<void> _loadSessionMessages(int sessionId, String title) async {
    setState(() {
      _sessionId = sessionId;
      _sessionTitle = title;
      _isLoading = true;
      _messages = [];
    });
    Navigator.pop(context); // Drawer'ı kapat

    try {
      final response = await ApiService.dio.get('/rag/sessions/$sessionId/messages');
      final List rawMessages = response.data;
      
      setState(() {
        _messages = rawMessages.expand((m) => [
          if (m['message'] != null) {
            'role': 'user',
            'content': m['message'],
            'time': DateTime.parse(m['created_at'] ?? DateTime.now().toString()),
          },
          if (m['response'] != null) {
            'role': 'ai',
            'content': m['response'],
            'sources': m['sources'],
            'time': DateTime.parse(m['created_at'] ?? DateTime.now().toString()),
          }
        ]).toList().cast<Map<String, dynamic>>();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSession(int sessionId) async {
    try {
      await ApiService.dio.delete('/rag/sessions/$sessionId');
      if (_sessionId == sessionId) {
        setState(() {
          _sessionId = null;
          _sessionTitle = 'Yeni Sohbet';
          _setWelcomeMessage();
        });
      }
      _loadSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sohbet silinemedi.')));
    }
  }

  Future<void> _createNewChat() async {
    setState(() {
      _sessionId = null;
      _sessionTitle = 'Yeni Sohbet';
      _setWelcomeMessage();
    });
    // Drawer açıksa kapat
    if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
        'time': DateTime.now(),
      });
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await ApiService.dio.post('/rag/chat', data: {
        'message': text,
        'sessionId': _sessionId,
      });

      final data = response.data;
      if (mounted) {
        setState(() {
          bool isNewSession = _sessionId == null;
          _sessionId = data['sessionId'];
          _messages.add({
            'role': 'ai',
            'content': data['response'] ?? 'Yanıt alınamadı.',
            'sources': data['sources'],
            'time': DateTime.now(),
          });
          _isLoading = false;
          if (isNewSession) _loadSessions();
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'content': 'Üzgünüm, bir hata oluştu: ${e.toString()}',
            'isError': true,
            'time': DateTime.now(),
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚖️ Hukuk AI Asistanı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_sessionTitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.accent),
            onPressed: _createNewChat,
            tooltip: 'Yeni Sohbet',
          ),
        ],
      ),
      drawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, idx) {
                if (idx == _messages.length) {
                  return _buildLoadingBubble();
                }
                return _buildMessageBubble(_messages[idx]);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.bgSurface),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, size: 40, color: AppColors.primaryLight),
                const SizedBox(height: 12),
                const Text('Sohbet Geçmişi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _createNewChat,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Yeni Sohbet', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: _isLoadingSessions 
              ? const Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
                ? const Center(child: Text('Henüz sohbet yok.', style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _sessions.length,
                    itemBuilder: (ctx, i) {
                      final s = _sessions[i];
                      final isSelected = s['id'] == _sessionId;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                        title: Text(s['title'] ?? 'Sohbet #${s['id']}', 
                          style: TextStyle(color: isSelected ? AppColors.primaryLight : Colors.white70, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(s['created_at'])), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        onTap: () => _loadSessionMessages(s['id'], s['title'] ?? 'Sohbet'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          onPressed: () => _deleteSession(s['id']),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Drawer'ı kapat
                  Navigator.pop(context); // Ekrandan çık (Panele dön)
                },
                icon: const Icon(Icons.logout, size: 18, color: AppColors.danger),
                label: const Text('Asistandan Çık', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['role'] == 'user';
    final isError = msg['isError'] == true;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accent : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: !isMe ? const Radius.circular(0) : null,
          ),
          border: isMe ? null : Border.all(color: isError ? AppColors.danger.withValues(alpha: 0.5) : AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['content'],
              style: TextStyle(
                color: isMe ? Colors.black : (isError ? AppColors.danger : AppColors.textPrimary),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (msg['sources'] != null) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),
              Text('📚 Kaynaklar:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMe ? Colors.black54 : AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(msg['sources'].toString(), style: TextStyle(fontSize: 10, color: isMe ? Colors.black54 : AppColors.textMuted, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat('HH:mm').format(msg['time']),
                style: TextStyle(color: isMe ? Colors.black45 : AppColors.textMuted, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(0)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BouncingDots(),
            const SizedBox(width: 12),
            Text('Asistan yanıtlıyor...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Hukuki bir soru sorun...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: AppColors.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  _BouncingDotsState createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true));

    _animations = _controllers.map((controller) => Tween<double>(begin: 0, end: -5.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    )).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) => AnimatedBuilder(
        animation: _animations[index],
        builder: (context, child) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          transform: Matrix4.translationValues(0, _animations[index].value, 0),
          width: 6, height: 6,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        ),
      )),
    );
  }
}
