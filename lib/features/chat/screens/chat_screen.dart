import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shimmer/shimmer.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart' as intl;

class ChatScreen extends StatefulWidget {
  final bool isWorker;
  final String? targetUserId;
  final String? targetUserName;
  final bool isGroupChat;

  const ChatScreen({
    super.key,
    this.isWorker = false,
    this.targetUserId,
    this.targetUserName,
    this.isGroupChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthController _authController = Get.find<AuthController>();
  final ValueNotifier<bool> _isTextEmpty = ValueNotifier<bool>(true);
  
  File? _selectedImage;
  bool _isUploading = false;
  bool _showScrollToBottom = false;
  ChatMessageModel? _replyingTo;
  
  late Stream<QuerySnapshot> _messagesStream;
  Stream<DocumentSnapshot>? _chatDocStream;
  Stream<DocumentSnapshot>? _targetUserStream;
  
  bool _isCurrentlyTyping = false;
  Timer? _typingTimer;

  String get _currentUserId => _authController.currentUser.value?.id ?? '';
  String get _currentUserName => _authController.currentUser.value?.name ?? 'مستخدم';
  String? get _currentUserImage => _authController.currentUser.value?.profileImage;

  String _getChatId() {
    if (widget.isGroupChat) return 'group_team';
    final target = widget.targetUserId;
    if (target == null || target.isEmpty) return 'invalid_chat';
    final sorted = [_currentUserId, target]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  @override
  void initState() {
    super.initState();
    final chatId = _getChatId();
    
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
    
    if (!widget.isGroupChat) {
      _chatDocStream = FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots();
      _targetUserStream = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots();
    }

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        if (_scrollController.offset > 300 && !_showScrollToBottom) {
          setState(() => _showScrollToBottom = true);
        } else if (_scrollController.offset <= 300 && _showScrollToBottom) {
          setState(() => _showScrollToBottom = false);
        }
      }
    });
    
    _messageController.addListener(() {
      _isTextEmpty.value = _messageController.text.trim().isEmpty;
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _updateTypingStatus(false);
    _messageController.dispose();
    _scrollController.dispose();
    _isTextEmpty.dispose();
    super.dispose();
  }

  void _handleTyping(String val) {
    if (widget.isGroupChat) return;
    
    if (!_isCurrentlyTyping && val.isNotEmpty) {
      _isCurrentlyTyping = true;
      _updateTypingStatus(true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        _updateTypingStatus(false);
      }
    });
  }

  void _updateTypingStatus(bool isTyping) {
    if (widget.isGroupChat) return;
    FirebaseFirestore.instance.collection('chats').doc(_getChatId()).set({
      'typing': {
        _currentUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return _buildSkeletonLoading();
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    final messages = snapshot.data!.docs;
                    _markMessagesAsRead(messages);

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data() as Map<String, dynamic>;
                        data['id'] = messages[index].id;
                        final message = ChatMessageModel.fromMap(data);

                        final previousMessage = index + 1 < messages.length
                          ? ChatMessageModel.fromMap(messages[index + 1].data() as Map<String, dynamic>)
                          : null;

                        return _buildMessageBubble(message, previousMessage);
                      },
                    );
                  },
                ),
              ),
              if (_isUploading)
                const LinearProgressIndicator(backgroundColor: Colors.transparent, color: AppTheme.primaryGreen),
              _buildTypingIndicator(),
              _buildInputArea(),
            ],
          ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                backgroundColor: AppTheme.primaryGreen,
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Shimmer.fromColors(
      baseColor: AppTheme.darkCard,
      highlightColor: AppTheme.darkSurface,
      child: ListView.builder(
        reverse: true,
        itemCount: 10,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final isMe = index % 2 == 0;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              width: MediaQuery.of(context).size.width * (0.3 + (index % 5) * 0.1),
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (widget.isGroupChat || _chatDocStream == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatDocStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final typing = data?['typing'] as Map<String, dynamic>?;
        final isOtherTyping = typing?[widget.targetUserId] ?? false;

        if (!isOtherTyping) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${widget.targetUserName ?? 'الطرف الآخر'} يكتب الآن', 
                style: GoogleFonts.tajawal(fontSize: 12, color: AppTheme.primaryGreen, fontStyle: FontStyle.italic)),
              const SizedBox(width: 4),
              _buildThreeDots(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThreeDots() {
    return Shimmer.fromColors(
      baseColor: AppTheme.primaryGreen,
      highlightColor: Colors.white,
      child: const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 1,
      backgroundColor: AppTheme.darkSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 0,
      title: widget.isGroupChat ? _buildGroupTitle() : _buildPrivateTitle(),
      actions: [
        if (widget.isGroupChat)
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.white),
            onPressed: _showMembersSheet,
          ),
        IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: _showChatOptions),
      ],
    );
  }

  Widget _buildGroupTitle() {
    return Row(
      children: [
        _buildAvatar(null),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('غرفة الفريق', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis),
              _buildOnlineStatus(null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivateTitle() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _targetUserStream,
      builder: (context, snapshot) {
        return Row(
          children: [
            _buildAvatar(snapshot),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.targetUserName ?? 'المحادثة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis),
                  _buildOnlineStatus(snapshot),
                ],
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildAvatar(AsyncSnapshot<DocumentSnapshot>? snapshot) {
    if (widget.isGroupChat) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.groups_rounded, color: AppTheme.primaryGreen, size: 24),
      );
    }

    String? profileImage;
    if (snapshot != null && snapshot.hasData && snapshot.data!.exists) {
      profileImage = (snapshot.data!.data() as Map<String, dynamic>)['profileImage'];
    }
    return GestureDetector(
      onTap: () {
        if (snapshot != null && snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          data['id'] = snapshot.data!.id;
          final userModel = UserModel.fromMap(data);
          Get.toNamed('/profile', arguments: userModel);
        }
      },
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
        backgroundImage: (profileImage != null && profileImage.isNotEmpty) ? NetworkImage(profileImage) : null,
        child: (profileImage == null || profileImage.isEmpty)
          ? Text(widget.targetUserName != null && widget.targetUserName!.isNotEmpty ? widget.targetUserName![0] : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen))
          : null,
      ),
    );
  }

  Widget _buildOnlineStatus(AsyncSnapshot<DocumentSnapshot>? snapshot) {
    if (widget.isGroupChat) return Text('دردشة جماعية', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey[400]));

    bool isOnline = false;
    if (snapshot != null && snapshot.hasData && snapshot.data!.exists) {
      var data = snapshot.data!.data() as Map<String, dynamic>;
      if (data['lastActivity'] != null) {
        DateTime lastActivity = (data['lastActivity'] as Timestamp).toDate();
        isOnline = DateTime.now().difference(lastActivity).inMinutes < 5;
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? AppTheme.successColor : Colors.grey[600],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isOnline ? 'متصل الآن' : 'غير متصل',
          style: GoogleFonts.tajawal(fontSize: 12, color: isOnline ? AppTheme.successColor : Colors.grey[400]),
        ),
      ],
    );
  }

  void _showChatOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              title: const Text('مسح المحادثة', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Get.back();
                _confirmClearChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined, color: Colors.white),
              title: const Text('كتم التنبيهات', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                final prefs = await SharedPreferences.getInstance();
                final key = 'muted_${_getChatId()}';
                final isMuted = prefs.getBool(key) ?? false;
                await prefs.setBool(key, !isMuted);
                Get.snackbar(!isMuted ? '🔕 تم الكتم' : '🔔 تم رفع الكتم', '', colorText: Colors.white);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearChat() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('مسح المحادثة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text('هل أنت متأكد من مسح جميع الرسائل؟ لا يمكن التراجع عن هذا الإجراء.', style: GoogleFonts.tajawal(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Get.back();
              final chatId = _getChatId();
              final batch = FirebaseFirestore.instance.batch();
              final messages = await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').get();
              for (var doc in messages.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              Get.snackbar('تم', 'تم مسح المحادثة بنجاح', backgroundColor: AppTheme.darkCard, colorText: Colors.white);
            },
            child: Text('مسح الكل', style: GoogleFonts.tajawal(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, ChatMessageModel? previousMessage) {
    final isMe = message.senderId == _currentUserId;
    
    // إظهار الوقت كفاصل فقط إذا كان الفرق أكثر من 30 دقيقة
    final showTimeDivider = previousMessage == null ||
        message.createdAt.difference(previousMessage.createdAt).inMinutes > 30 ||
        message.createdAt.day != previousMessage.createdAt.day;

    return Column(
      children: [
        if (showTimeDivider)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withOpacity(0.5), 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.glassBorder)
              ),
              child: Text(
                _formatDividerDate(message.createdAt),
                style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        SwipeTo(
          onRightSwipe: (details) {
            Vibrate.feedback(FeedbackType.light);
            setState(() => _replyingTo = message);
          },
          child: GestureDetector(
            onLongPress: () => _showLongPressMenu(message),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) _buildBubbleAvatar(message.senderId, message.senderName, message.senderImage),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe && widget.isGroupChat)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 12),
                            child: Text(message.senderName, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            gradient: isMe ? AppTheme.primaryGradient : null,
                            color: isMe ? null : AppTheme.darkCard,
                            borderRadius: BorderRadius.only(
                              topRight: const Radius.circular(22),
                              topLeft: const Radius.circular(22),
                              bottomRight: Radius.circular(isMe ? 4 : 22),
                              bottomLeft: Radius.circular(isMe ? 22 : 4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isMe ? AppTheme.primaryGreen.withOpacity(0.15) : Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          padding: message.imageUrl != null ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (message.replyTo != null) _buildReplyInBubble(message.replyTo!, isMe),
                              if (message.imageUrl != null) _buildImageContent(message.imageUrl!),
                              if (message.message.isNotEmpty)
                                MarkdownBody(
                                  data: message.message,
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15, height: 1.4),
                                    strong: const TextStyle(fontWeight: FontWeight.bold),
                                    code: TextStyle(backgroundColor: isMe ? Colors.black12 : Colors.white10, fontFamily: 'monospace'),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    intl.DateFormat('HH:mm').format(message.createdAt),
                                    style: TextStyle(color: isMe ? Colors.black54 : Colors.white38, fontSize: 9, fontWeight: FontWeight.w500),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      message.isRead ? Icons.done_all : Icons.done,
                                      color: message.isRead ? Colors.blue.shade800 : Colors.black45,
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMe) _buildBubbleAvatar(_currentUserId, _currentUserName, _currentUserImage),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleAvatar(String userId, String name, String? image) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () => Get.toNamed('/profile', arguments: userId),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), width: 1),
          ),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.darkSurface,
            backgroundImage: (image != null && image.isNotEmpty) ? NetworkImage(image) : null,
            child: (image == null || image.isEmpty)
                ? Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold))
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(String url) {
    return GestureDetector(
      onTap: () => Get.to(() => _FullScreenImage(url: url)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          url, 
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200, width: 200, 
              color: AppTheme.darkSurface,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      ),
    );
  }

  String _formatDividerDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'اليوم، ${intl.DateFormat('HH:mm a').format(date)}';
    }
    return intl.DateFormat('dd MMM, HH:mm a').format(date);
  }

  Widget _buildReplyInBubble(Map<String, dynamic> reply, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border(right: BorderSide(color: isMe ? Colors.black45 : AppTheme.primaryGreen, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reply['senderName'] ?? '', style: TextStyle(color: isMe ? Colors.black87 : AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 11)),
          Text(reply['message'] ?? '', style: TextStyle(color: isMe ? Colors.black54 : Colors.white60, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _showLongPressMenu(ChatMessageModel message) {
    Vibrate.feedback(FeedbackType.medium);
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.white),
              title: const Text('رد', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                setState(() => _replyingTo = message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white),
              title: const Text('نسخ النص', style: TextStyle(color: Colors.white)),
              onTap: () {
                Get.back();
                // Clipboard functionality
              },
            ),
            if (message.senderId == _currentUserId)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                title: const Text('حذف للجميع', style: TextStyle(color: AppTheme.errorColor)),
                onTap: () {
                  Get.back();
                  _deleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessageModel message) async {
    if (message.id == null) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_getChatId())
        .collection('messages')
        .doc(message.id)
        .delete();
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null) _buildReplyPreview(),
        Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10, top: 10, left: 12, right: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface, 
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), offset: const Offset(0, -2), blurRadius: 4)]
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.photo_camera, color: AppTheme.primaryGreen, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    minLines: 1,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: _handleTyping,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _isTextEmpty,
                builder: (context, isEmpty, child) {
                  final canSend = !isEmpty || _selectedImage != null;
                  return GestureDetector(
                    onTap: canSend ? _sendMessage : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: canSend ? AppTheme.primaryGradient : null,
                        color: !canSend ? AppTheme.darkCard : null,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.send_rounded,
                        color: canSend ? Colors.black : Colors.white54,
                        size: 24,
                      ),
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.darkSurface,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: const Border(right: BorderSide(color: AppTheme.primaryGreen, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_replyingTo!.senderName, style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(_replyingTo!.message, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.white54),
              onPressed: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.primaryGreen.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          const Text('لا توجد رسائل بعد', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('ابدأ المحادثة الآن عن طريق كتابة رسالة بالأسفل', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
      _sendMessage();
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;

    final text = _messageController.text.trim();
    final replyTo = _replyingTo;
    _messageController.clear();
    setState(() {
      _replyingTo = null;
    });
    
    _isCurrentlyTyping = false;
    _updateTypingStatus(false);

    String? imageUrl;
    if (_selectedImage != null) {
      setState(() => _isUploading = true);
      final ref = FirebaseStorage.instance.ref('chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_selectedImage!);
      imageUrl = await ref.getDownloadURL();
      _selectedImage = null;
      setState(() => _isUploading = false);
    }

    final chatId = _getChatId();

    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'senderId': _currentUserId,
      'senderName': _currentUserName,
      'senderImage': _currentUserImage,
      'message': text,
      'imageUrl': imageUrl,
      'isRead': false,
      'readBy': [_currentUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'chatId': chatId,
      if (replyTo != null) 'reply_to': {
        'id': replyTo.id,
        'message': replyTo.message,
        'senderName': replyTo.senderName,
      }
    });

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': imageUrl != null ? '📷 صورة' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': widget.isGroupChat ? FieldValue.arrayUnion([_currentUserId]) : [_currentUserId, widget.targetUserId],
    }, SetOptions(merge: true));

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _markMessagesAsRead(List<QueryDocumentSnapshot> docs) async {
    final unread = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final readBy = List<String>.from(data['readBy'] ?? []);
      return (data['senderId'] ?? data['sender_id']) != _currentUserId && !readBy.contains(_currentUserId);
    }).toList();

    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unread) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([_currentUserId]),
        'isRead': true,
      });
    }
    await batch.commit();
  }

  void _showMembersSheet() {
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('أعضاء الغرفة', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('role', whereIn: ['worker', 'admin', 'superAdmin']).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final workers = snapshot.data!.docs.map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>..['id'] = d.id)).toList();

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          final worker = workers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              backgroundImage: (worker.profileImage != null && worker.profileImage!.isNotEmpty) ? NetworkImage(worker.profileImage!) : null,
                              child: (worker.profileImage == null || worker.profileImage!.isEmpty) ? Text(worker.name[0], style: const TextStyle(color: AppTheme.primaryGreen)) : null,
                            ),
                            title: Text(worker.name, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, color: Colors.white)),
                            subtitle: Text(worker.role.name, style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white54)),
                            trailing: worker.id == _currentUserId ? null : IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryGreen, size: 24),
                              onPressed: () {
                                Get.back();
                                Get.toNamed('/chat/private', arguments: {'userId': worker.id, 'userName': worker.name});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(child: InteractiveViewer(child: Image.network(url))),
    );
  }
}
