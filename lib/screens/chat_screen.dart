import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/message_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String caseId;
  const ChatScreen({super.key, required this.caseId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isCaseClosed = false; // Dava kapalı mı?
  Timer? _timer;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    // Her 5 saniyede bir mesajları güncelle
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  Future<void> _loadInitialData() async {
    // Önce kullanıcının rolünü belirle
    final auth = context.read<AuthProvider>();
    setState(() {
      _currentUserRole = auth.user?['role'];
    });

    // Dava durumunu kontrol et
    await _checkCaseStatus();
    await _loadMessages();
  }

  Future<void> _checkCaseStatus() async {
    try {
      final response = await ApiService.dio.get('/cases/${widget.caseId}');
      final status = response.data['status']?.toString().toUpperCase();
      if (status == 'CLOSED' || status == 'KAPANDI' || status == 'REJECTED' || status == 'REDDEDILDI') {
        if (mounted) setState(() => _isCaseClosed = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final msgs = await MessageService.getMessages(widget.caseId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        if (!silent) _scrollToBottom();
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      await MessageService.sendMessage(widget.caseId, text);
      _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlaşma'),
        backgroundColor: AppColors.bgSurface,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? const Center(child: Text('Henüz mesaj yok.', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final auth = context.read<AuthProvider>();
                          final myId = auth.user?['id']?.toString();
                          final gonderenId = m['gonderenId']?.toString();
                          
                          // Kesin hizalama kuralı: 
                          // Mesajı gönderen kişi BEN isem (id'ler eşleşiyorsa) SAĞDA, 
                          // değılse SOLDA görünsün.
                          bool isMe = (myId != null && gonderenId != null && myId == gonderenId);
                          
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primary : AppColors.bgCard,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomRight: isMe ? const Radius.circular(0) : null,
                                  bottomLeft: !isMe ? const Radius.circular(0) : null,
                                ),
                                border: isMe ? null : Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['icerik'] ?? '',
                                    style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m['createdAt'] != null ? _formatTime(m['createdAt']) : '',
                                    style: TextStyle(color: isMe ? Colors.white70 : AppColors.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          _isCaseClosed ? _buildClosedCaseInfo() : _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildClosedCaseInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: AppColors.danger, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bu dava dosyası sonuçlandığı veya kapandığı için mesajlaşma durdurulmuştur.',
                style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Mesajınızı yazın...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
