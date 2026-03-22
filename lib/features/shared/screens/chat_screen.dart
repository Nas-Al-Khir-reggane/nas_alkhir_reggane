import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
  File? _selectedImage;
  bool _isUploading = false;

  String get _currentUserId => _authController.currentUser.value?.id ?? '';
  String get _currentUserName => _authController.currentUser.value?.name ?? 'مستخدم';

  String _getChatId() {
    if (widget.isGroupChat) return 'group_team';
    final sorted = [_currentUserId, widget.targetUserId!]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_getChatId())
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
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
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (!widget.isGroupChat)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Get.back(),
                ),
              widget.isGroupChat ? Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    radius: 20,
                    child: const Icon(Icons.group, color: Colors.black),
                  ),
                ],
              ) : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
                builder: (context, snapshot) {
                  bool isOnline = false;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    if (data['lastActivity'] != null) {
                      DateTime lastActivity = (data['lastActivity'] as Timestamp).toDate();
                      if (DateTime.now().difference(lastActivity).inMinutes < 5) {
                        isOnline = true;
                      }
                    }
                  }
                  
                  return Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        radius: 20,
                        child: Text(widget.targetUserName?[0] ?? '?', 
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isOnline ? AppTheme.successColor : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.darkBg, width: 2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 12),
              
              widget.isGroupChat ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('مجموعة الفريق', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('دردشة جماعية', style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ) : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).snapshots(),
                builder: (context, snapshot) {
                  bool isOnline = false;
                  String statusText = 'غير متصل';
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    if (data['lastActivity'] != null) {
                      DateTime lastActivity = (data['lastActivity'] as Timestamp).toDate();
                      if (DateTime.now().difference(lastActivity).inMinutes < 5) {
                        isOnline = true;
                        statusText = 'متصل الآن';
                      }
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.targetUserName ?? 'دردشة',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(color: isOnline ? AppTheme.successColor : Colors.black54, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              if (widget.isGroupChat)
                IconButton(
                  icon: const Icon(Icons.group_outlined, color: Colors.black),
                  onPressed: _showMembersSheet,
                ),
              IconButton(icon: const Icon(Icons.more_vert, color: Colors.black), onPressed: _showChatOptions),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              leading: Icon(Icons.notifications_off_outlined, color: AppTheme.textPrimary),
              title: Text('كتم التنبيهات', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Get.back(),
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
        title: Text('مسح المحادثة', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('هل أنت متأكد من مسح جميع الرسائل؟', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
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
              Get.snackbar('تم', 'تم مسح المحادثة بنجاح');
            },
            child: const Text('مسح', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, ChatMessageModel? previousMessage) {
    final isMe = message.senderId == _currentUserId;
    final showAvatar = !isMe && (previousMessage?.senderId != message.senderId);
    final showTime = previousMessage == null || 
        message.createdAt.difference(previousMessage.createdAt).inMinutes > 5;

    return Column(
      children: [
        if (showTime)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.darkCard, borderRadius: BorderRadius.circular(10)),
              child: Text(
                intl.DateFormat('HH:mm').format(message.createdAt),
                style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                if (showAvatar)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                    child: Text(message.senderName[0], style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 10)),
                  )
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe && widget.isGroupChat && showAvatar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text(message.senderName, style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      decoration: BoxDecoration(
                        gradient: isMe ? AppTheme.primaryGradient : null,
                        color: isMe ? null : AppTheme.darkCard,
                        borderRadius: BorderRadius.only(
                          topRight: const Radius.circular(18),
                          topLeft: const Radius.circular(18),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                        ),
                        boxShadow: isMe ? AppTheme.cardShadow : null,
                      ),
                      padding: message.imageUrl != null ? EdgeInsets.zero : const EdgeInsets.all(12),
                      child: message.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                children: [
                                  Image.network(message.imageUrl!, fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                                    },
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Text(intl.DateFormat('HH:mm').format(message.createdAt), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.message,
                                  style: TextStyle(color: isMe ? Colors.black : AppTheme.textPrimary, fontSize: 14, height: 1.4),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      intl.DateFormat('HH:mm').format(message.createdAt),
                                      style: TextStyle(color: isMe ? Colors.black54 : AppTheme.textHint, fontSize: 10),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        message.isRead ? Icons.done_all : Icons.done,
                                        color: message.isRead ? Colors.black87 : Colors.black45,
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
              if (isMe) ...[
                const SizedBox(width: 8),
                if (showAvatar)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primaryGreen,
                    child: Text(_currentUserName[0], style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else
                  const SizedBox(width: 28),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(color: AppTheme.darkSurface, boxShadow: AppTheme.darkShadow),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.image_outlined, color: AppTheme.primaryGreen, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.glassBorder),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 4,
                    minLines: 1,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: (_messageController.text.isNotEmpty || _selectedImage != null) ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: _messageController.text.isNotEmpty ? AppTheme.primaryGradient : null,
                    color: _messageController.text.isEmpty ? AppTheme.darkCard : null,
                    shape: BoxShape.circle,
                    boxShadow: _messageController.text.isNotEmpty ? AppTheme.greenGlow : null,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.send_rounded,
                    color: _messageController.text.isNotEmpty ? Colors.black : AppTheme.textHint,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: AppTheme.textHint.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('لا توجد رسائل بعد', style: TextStyle(color: AppTheme.textHint)),
          Text('ابدأ المحادثة الآن', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
      _sendMessage();
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;
    
    final text = _messageController.text.trim();
    _messageController.clear();
    setState(() {});

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
      'message': text,
      'imageUrl': imageUrl,
      'isRead': false,
      'readBy': [_currentUserId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': imageUrl != null ? '📷 صورة' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': widget.isGroupChat ? FieldValue.arrayUnion([_currentUserId]) : [_currentUserId, widget.targetUserId],
    }, SetOptions(merge: true));

    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs) {
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (data['senderId'] != _currentUserId && !readBy.contains(_currentUserId)) {
        doc.reference.update({
          'readBy': FieldValue.arrayUnion([_currentUserId]),
          'isRead': true,
        });
      }
    }
  }

  void _showMembersSheet() {
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أعضاء الفريق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'worker').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final workers = snapshot.data!.docs.map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          final worker = workers[index];
                          if (worker.id == _currentUserId) return const SizedBox.shrink();
                          
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                                  child: Text(worker.name[0], style: const TextStyle(color: AppTheme.primaryGreen)),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: worker.isAvailable ? AppTheme.successColor : AppTheme.warningColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.darkSurface, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(worker.name, style: TextStyle(color: AppTheme.textPrimary)),
                            subtitle: Text(worker.workerRole ?? 'متطوع', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            trailing: GestureDetector(
                              onTap: () {
                                Get.back();
                                Get.toNamed('/chat/private', arguments: {'userId': worker.id, 'userName': worker.name});
                              },
                              child: Container(
                                decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryGreen, size: 18),
                              ),
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
