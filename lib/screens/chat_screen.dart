import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/message_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

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
  bool _isCaseClosed = false;
  bool _isUploading = false;
  Timer? _timer;
  String? _currentUserRole;
  Map<String, dynamic>? _caseData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages(silent: true));
  }

  Future<void> _loadInitialData() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _currentUserRole = auth.user?['role'];
    });

    await _fetchCaseInfo();
    await _loadMessages();
  }

  Future<void> _fetchCaseInfo() async {
    try {
      final response = await ApiService.dio.get('/cases/${widget.caseId}');
      setState(() {
        _caseData = response.data;
        final status = _caseData?['status']?.toString().toUpperCase();
        if (status == 'CLOSED' || status == 'KAPANDI' || status == 'REJECTED') {
          _isCaseClosed = true;
        }
      });
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
      if (!silent && mounted) setState(() => _isLoading = false);
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
    if (text.isEmpty || _isCaseClosed) return;

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
    final caseTitle = _caseData?['davaTuru'] ?? 'Dava Dosyası';
    final caseNo = _caseData?['dosyaNo'] ?? '#${widget.caseId.substring(0, 8)}';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              radius: 18,
              child: const Text('💬', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caseTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(caseNo, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isCaseClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppColors.danger.withValues(alpha: 0.15),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text('Bu dava kapandığı için yeni mesaj gönderilemez.', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final auth = context.read<AuthProvider>();
                          final myId = auth.user?['id']?.toString();
                          final gonderenId = m['gonderenId']?.toString();
                          bool isMe = (myId != null && gonderenId != null && myId == gonderenId);
                          
                          return _buildMessageBubble(m, isMe);
                        },
                      ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Henüz mesaj yok.', style: TextStyle(color: AppColors.textSecondary)),
          const Text('İlk mesajı siz gönderin.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> m, bool isMe) {
    final String content = m['icerik'] ?? '';
    final bool isFile = content.startsWith('/uploads/');
    final time = m['createdAt'] != null 
        ? DateFormat('HH:mm').format(DateTime.parse(m['createdAt'])) 
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accent : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: !isMe ? const Radius.circular(0) : null,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFile)
              _buildFileMessage(content, isMe)
            else
              Text(
                content,
                style: TextStyle(
                  color: isMe ? Colors.black : Colors.white,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                time,
                style: TextStyle(color: isMe ? Colors.black45 : AppColors.textMuted, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessage(String url, bool isMe) {
    final fileName = url.split('/').last;
    final isImage = url.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|webp)'));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              ApiService.baseUrl.replaceAll('/api', '') + url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, color: isMe ? Colors.black54 : AppColors.primaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fileName, style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 13, decoration: TextDecoration.underline)),
              ),
            ],
          ),
      ],
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
          IconButton(
            onPressed: _isCaseClosed ? null : _handleFileSelection,
            icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isCaseClosed,
              onSubmitted: (_) => _handleSend(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _isCaseClosed ? 'Dava kapalı...' : 'Mesajınızı yazın...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: AppColors.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          _isUploading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : CircleAvatar(
                backgroundColor: _isCaseClosed ? AppColors.textMuted : AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _isCaseClosed ? null : _handleSend,
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _handleFileSelection() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploading = true);
        final file = result.files.single;
        final url = await MessageService.uploadFile(file.bytes!, file.name);
        await MessageService.sendMessage(widget.caseId, url);
        setState(() => _isUploading = false);
        _loadMessages();
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya gönderilemedi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
