import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/cached_image_widget.dart';

class ChatScreen extends StatefulWidget {
  final bool isWorker;
  final String? targetUserId;
  final String? targetUserName;
  final bool isGroupChat;
  final String? chatId;
  final String? groupName;

  const ChatScreen({
    super.key,
    this.isWorker = false,
    this.targetUserId,
    this.targetUserName,
    this.isGroupChat = false,
    this.chatId,
    this.groupName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthController _authController = Get.find<AuthController>();
  final ValueNotifier<bool> _isTextEmpty = ValueNotifier<bool>(true);
  
  File? _selectedImage;
  bool _isUploading = false;
  bool _showScrollToBottom = false;
  ChatMessageModel? _replyingTo;
  ChatMessageModel? _editingMessage;
  bool _isSearchMode = false;
  
  late Stream<QuerySnapshot> _messagesStream;
  Stream<DocumentSnapshot>? _chatDocStream;
  Stream<DocumentSnapshot>? _targetUserStream;
  
  bool _isCurrentlyTyping = false;
  bool _showSlashCommands = false;
  Timer? _typingTimer;
  List<ChatMessageModel> _cachedMessages = [];
  String _localGuestName = '';
  String _localGuestPhone = '';
  
  static final Map<String, String> _bubbleAvatarCache = {};
  
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  String get _effectiveUserId {
    // 1. الأولوية للمستخدم المسجل في AuthController
    if (_authController.currentUser.value != null && _authController.currentUser.value!.id.isNotEmpty) {
      return _authController.currentUser.value!.id;
    }
    
    // 2. التحقق المباشر من FirebaseAuth (كطبقة حماية إضافية في حال تأخر AuthController)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      return firebaseUser.uid;
    }
    
    // 3. العودة لمعرف الزائر فقط إذا لم يكن هناك مستخدم مسجل
    if (widget.chatId != null && widget.chatId!.startsWith('guest_')) return widget.chatId!;
    return 'guest_$_localGuestPhone'; 
  }

  String get _effectiveUserName {
    // 1. الأولوية لاسم المستخدم في AuthController (بيانات كاملة من Firestore)
    final currentUser = _authController.currentUser.value;
    if (currentUser != null && currentUser.name.isNotEmpty) {
      return currentUser.name;
    }
    
    // 2. التحقق من اسم FirebaseAuth (قد يكون تم تعيينه أثناء التسجيل)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      if (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) {
        return firebaseUser.displayName!;
      }
      
      // 3. العودة لاسم الزائر إذا كانت المحادثة عبر رقم الهاتف (للضيوف)
      if (_localGuestName.isNotEmpty && _localGuestName != 'زائر') return _localGuestName;

      // 4. خيار أخير: الاسم المستخرج من البريد الإلكتروني
      if (firebaseUser.email != null && firebaseUser.email!.isNotEmpty) {
        final prefix = firebaseUser.email!.split('@')[0];
        // محاولة تحويل النقاط أو الخطوط السفلية لمسافات لمظهر أفضل
        return prefix.replaceAll(RegExp(r'[._-]'), ' ');
      }
    }
    
    // 5. العودة لاسم افتراضي
    if (widget.targetUserName != null && _effectiveUserId.startsWith('guest_')) return 'زائر';
    
    if (_effectiveUserId.startsWith('guest_')) {
      return 'ضيف (${_effectiveUserId.replaceFirst('guest_', '')})';
    }
    
    return 'مشارك (${_effectiveUserId.isNotEmpty ? _effectiveUserId.substring(0, min(5, _effectiveUserId.length)) : "مجهول"})';
  }


  String? get _currentUserImage => _authController.currentUser.value?.profileImage;

  String _getChatId() {
    // إذا كان الـ chatId محدد مسبقاً (مثل فتح محادثة موجودة)
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      return widget.chatId!;
    }
    
    // محادثة جماعية
    if (widget.isGroupChat) {
      return 'group_team';
    }
    
    // التأكد من وجود targetUserId
    final target = widget.targetUserId;
    if (target == null || target.isEmpty) {
      debugPrint('⚠️ خطأ: targetUserId فارغ');
      return 'invalid_chat';
    }
    
    // التأكد من وجود معرف المستخدم الحالي
    if (_effectiveUserId.isEmpty) {
      debugPrint('⚠️ خطأ: _effectiveUserId فارغ');
      return 'invalid_chat';
    }
    
    // إنشاء chatId فريد بترتيب أبجدي
    final sorted = [_effectiveUserId, target]..sort();
    final generatedChatId = '${sorted[0]}_${sorted[1]}';
    
    debugPrint('✅ تم إنشاء chatId: $generatedChatId');
    return generatedChatId;
  }

  Future<void> _markAsRead() async {
    final chatId = _getChatId();
    if (chatId == 'invalid_chat') return;
    
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'unreadCount': {
        _effectiveUserId: 0,
      }
    }, SetOptions(merge: true));
  }

  void _updateTypingStatus(bool isTyping) {
    if (widget.isGroupChat || _effectiveUserId.isEmpty) return;
    FirebaseFirestore.instance.collection('chats').doc(_getChatId()).set({
      'typing': {
        _effectiveUserId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  Future<void> _loadGuestIdentity() async {
    if (_authController.currentUser.value == null) {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _localGuestName = prefs.getString('guest_name') ?? 'زائر';
          _localGuestPhone = prefs.getString('guest_phone') ?? '';
        });
      }
    }
  }

  Future<void> _syncMyMetadata() async {
    final chatId = _getChatId();
    if (chatId == 'invalid_chat' || widget.isGroupChat) return;
    
    // الانتظار قليلاً للتأكد من تحميل بيانات المستخدم إذا لزم الأمر
    if (_authController.currentUser.value == null) {
       await Future.delayed(const Duration(milliseconds: 1000));
    }

    final String name = _effectiveUserName;
    final String id = _effectiveUserId;
    
    if (id.isNotEmpty) {
      try {
        final updateData = {
          'participantNames.$id': name,
          'participantAvatars.$id': _currentUserImage ?? '',
          'lastActivity.$id': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // إذا كان الطرف الآخر زائراً، نحفظ بياناته أيضاً لتسهيل العرض في القوائم
        if (id.startsWith('guest_')) {
          updateData['guestName'] = name;
          updateData['guestPhone'] = id.replaceFirst('guest_', '');
          updateData['type'] = 'guest';
          updateData['lastActivityAt'] = FieldValue.serverTimestamp();
        }

        await FirebaseFirestore.instance.collection('chats').doc(chatId).set(updateData, SetOptions(merge: true));
        debugPrint('✅ Chat Metadata Synced for $name');
      } catch (e) {
        debugPrint('⚠️ Error syncing chat metadata: $e');
      }
    }
  }

  // مزامنة بيانات الطرف الآخر لتقديم واجهة أفضل للمديرين مستقبلاً
  void _syncOtherParticipantMetadata(String realName, String profileImage) {
    if (widget.isGroupChat) return;
    try {
      final chatId = _getChatId();
      if (chatId == 'invalid_chat') return;

      if (widget.targetUserId != null) {
        FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'participantNames.${widget.targetUserId}': realName,
          'participantAvatars.${widget.targetUserId}': profileImage,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('⚠️ Error syncing other participant metadata: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGuestIdentity();
    _syncMyMetadata(); // مزامنة البيانات فور فتح الشاشة
    final chatId = _getChatId();
    
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    if (!widget.isGroupChat && widget.targetUserId != null) {
      _chatDocStream = FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots();
      _targetUserStream = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId!).snapshots();
    }

    _markAsRead();
    _loadCachedMessages();

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
    _searchController.dispose();
    _scrollController.dispose();
    _isTextEmpty.dispose();
    super.dispose();
  }

  void _handleTyping(String val) {
    if (val.startsWith('/')) {
      if (!_showSlashCommands) setState(() => _showSlashCommands = true);
    } else {
      if (_showSlashCommands) setState(() => _showSlashCommands = false);
    }

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

  Future<void> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('cached_chat_${_getChatId()}');
      if (cachedData != null && cachedData.isNotEmpty && mounted) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        if (mounted) {
          setState(() {
            _cachedMessages = decoded
                .map((e) => ChatMessageModel.fromMap(Map<String, dynamic>.from(e)))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ خطأ في تحميل الكاش: $e');
    }
  }

  void _handleError(String operation, dynamic error) {
    debugPrint('❌ خطأ في $operation: $error');
    
    Get.snackbar(
      'خطأ',
      'حدث خطأ في $operation',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withValues(alpha: 0.1),
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _cacheMessages(List<QueryDocumentSnapshot> docs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = docs.length > 20 ? 20 : docs.length;
      final latestDocs = docs.take(count).toList();
      final List<Map<String, dynamic>> toCache = [];
      for (var doc in latestDocs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        toCache.add(data);
      }
      await prefs.setString('cached_chat_${_getChatId()}', jsonEncode(toCache));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isSearchMode) _buildSearchOverlay(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    List<ChatMessageModel> displayMessages = [];
                    bool isUsingCache = false;

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      if (_cachedMessages.isNotEmpty) {
                        displayMessages = _cachedMessages;
                        isUsingCache = true;
                      } else {
                        return _buildSkeletonLoading();
                      }
                    } else if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final messages = snapshot.data!.docs;
                      WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsRead(messages));
                      _cacheMessages(messages);
                      displayMessages = messages.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        data['id'] = d.id;
                        return ChatMessageModel.fromMap(data);
                      }).toList();
                    } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      if (_cachedMessages.isNotEmpty) {
                         displayMessages = _cachedMessages;
                         isUsingCache = true;
                      } else {
                         displayMessages = [
                           ChatMessageModel(
                             id: 'system_welcome',
                             senderId: 'system',
                             senderName: 'النظام الروبوتي',
                             message: 'مرحباً بك! هذه رسالة آلية ترحيبية. فريق الدعم سيكون معك بأقرب وقت للمساعدة. يمكنك ترك تفاصيل استفسارك هنا.',
                             createdAt: DateTime.now(),
                             chatId: _getChatId(),
                           )
                         ];
                      }
                    }

                    final filteredMessages = _isSearchMode && _searchController.text.isNotEmpty 
                      ? displayMessages.where((m) => m.message.toLowerCase().contains(_searchController.text.toLowerCase())).toList()
                      : displayMessages;

                    return RefreshIndicator(
                      onRefresh: () async {
                        await Future.delayed(const Duration(milliseconds: 800));
                        if (mounted) setState(() {});
                        await _syncMyMetadata(); // إعادة مزامنة البيانات كنوع من التحديث
                      },
                      color: Theme.of(context).colorScheme.primary,
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: !_isSearchMode,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) {
                          final message = filteredMessages[index];
                          final previousMessage = index + 1 < filteredMessages.length
                            ? filteredMessages[index + 1]
                            : null;

                          if (message.id != null) {
                            _messageKeys.putIfAbsent(message.id!, () => GlobalKey());
                          }

                          return Opacity(
                            opacity: isUsingCache ? 0.7 : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(seconds: 1),
                              key: message.id != null ? _messageKeys[message.id!] : null,
                              color: _highlightedMessageId == message.id ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                              child: _buildMessageBubble(message, previousMessage),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (_isUploading)
                LinearProgressIndicator(backgroundColor: Colors.transparent, color: Theme.of(context).colorScheme.primary),
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).cardColor,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'بحث في الرسائل...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isSearchMode = false)),
        ),
        onChanged: (val) => setState(() {}),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).cardColor,
      highlightColor: Theme.of(context).colorScheme.surface,
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
        final isOtherTyping = (widget.targetUserId != null) ? (typing?[widget.targetUserId] ?? false) : false;

        if (!isOtherTyping) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('${widget.targetUserName ?? 'الطرف الآخر'} يكتب الآن',
                style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic)),
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
      baseColor: Theme.of(context).colorScheme.primary,
      highlightColor: Theme.of(context).colorScheme.onPrimary,
      child: const Text('...', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 1,
      backgroundColor: Theme.of(context).colorScheme.surface,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 20, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => Get.back(),
      ),
      titleSpacing: 0,
      title: widget.isGroupChat ? _buildGroupTitle() : _buildPrivateTitle(),
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _isSearchMode = !_isSearchMode)),
        if (widget.isGroupChat)
          IconButton(
            icon: Icon(Icons.people_outline, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showMembersSheet,
          ),
        IconButton(
          icon: Icon(Icons.print_outlined, color: Theme.of(context).colorScheme.primary),
          tooltip: 'تصدير المحادثة (PDF/نص)',
          onPressed: _exportChatLocally,
        ),
        IconButton(icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface), onPressed: _showChatOptions),
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
              Text('غرفة الفريق', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface), overflow: TextOverflow.ellipsis),
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
                  Builder(
                    builder: (context) {
                      String name = widget.targetUserName ?? 'المحادثة';
                      
                      // إذا وصلتنا بيانات حقيقية من Firestore للطرف الآخر، نستخدمها
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        final realName = data['name']?.toString() ?? '';
                        final realImage = data['profileImage']?.toString() ?? '';
                        if (realName.isNotEmpty) {
                          name = realName;
                          // ترميم البيانات في الخلفية إذا كانت ناقصة في مستند المحادثة
                          _syncOtherParticipantMetadata(realName, realImage);
                        }
                      } else if (name == 'مشارك' || name == 'مستخدم') {
                         // إذا كان الاسم الحالي مجرد رمز، نحاول جلب رقم الهاتف من الـ ID إذا كان ضيفاً
                         if (widget.targetUserId != null && widget.targetUserId!.startsWith('guest_')) {
                           name = 'ضيف (${widget.targetUserId!.replaceFirst('guest_', '')})';
                         }
                      }

                      return Text(
                        name,
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.groups_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
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
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        backgroundImage: (profileImage != null && profileImage.isNotEmpty) ? CachedNetworkImageProvider(profileImage) as ImageProvider : null,
        child: (profileImage == null || profileImage.isEmpty)
          ? Text(widget.targetUserName != null && widget.targetUserName!.isNotEmpty ? widget.targetUserName![0] : '?', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))
          : null,
      ),
    );
  }

  Widget _buildOnlineStatus(AsyncSnapshot<DocumentSnapshot>? snapshot) {
    if (widget.isGroupChat) return Text('دردشة جماعية', style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant));

    return StreamBuilder<DocumentSnapshot>(
      stream: _chatDocStream,
      builder: (context, chatSnapshot) {
        DateTime? finalLastActivity;

        // 1. التحقق من حالة المستخدم العامة
        if (snapshot != null && snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['lastActivity'] != null) {
            finalLastActivity = (data['lastActivity'] as Timestamp).toDate();
          }
        }

        // 2. التحقق من النشاط الخاص داخل هذه المحادثة 
        if (chatSnapshot.hasData && chatSnapshot.data!.exists && widget.targetUserId != null) {
          var chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
          Timestamp? chatLastActivity;
          
          if (chatData['lastActivity'] is Map && chatData['lastActivity'][widget.targetUserId] != null) {
            chatLastActivity = chatData['lastActivity'][widget.targetUserId] as Timestamp;
          } else if (chatData['lastActivity.${widget.targetUserId}'] != null) {
            chatLastActivity = chatData['lastActivity.${widget.targetUserId}'] as Timestamp;
          }
          
          if (chatLastActivity != null) {
             final chatActivityDate = chatLastActivity.toDate();
             if (finalLastActivity == null || chatActivityDate.isAfter(finalLastActivity)) {
                 finalLastActivity = chatActivityDate;
             }
          }
        }

        bool isOnline = false;
        String statusText = 'غير متصل';

        if (finalLastActivity != null) {
          if (DateTime.now().difference(finalLastActivity).inMinutes < 5) {
            isOnline = true;
            statusText = 'متصل الآن';
          } else {
            statusText = timeago.format(finalLastActivity, locale: 'ar'); // يتطلب استيراد timeago
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: GoogleFonts.tajawal(fontSize: 12, color: isOnline ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        );
      }
    );
  }

  void _showChatOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('مسح المحادثة', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Get.back();
                _confirmClearChat();
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('كتم التنبيهات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () async {
                final colorOnSurface = Theme.of(context).colorScheme.onSurface;
                Get.back();
                final prefs = await SharedPreferences.getInstance();
                final key = 'muted_${_getChatId()}';
                final isMuted = prefs.getBool(key) ?? false;
                await prefs.setBool(key, !isMuted);
                if (!mounted) return;
                Get.snackbar(!isMuted ? '🔕 تم الكتم' : '🔔 تم رفع الكتم', '', colorText: colorOnSurface);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportChatLocally() async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final docs = await FirebaseFirestore.instance.collection('chats').doc(_getChatId()).collection('messages').orderBy('createdAt').get();
    if (docs.docs.isEmpty) {
      Get.snackbar('فارغة', 'لا يوجد رسائل لتصديرها');
      return;
    }
    
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('=== سجل محادثة ناس الخير ===');
    buffer.writeln('التاريخ: ${intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('بين: $_effectiveUserName والطرف الآخر');
    buffer.writeln('----------------------------------\n');
    
    for (var doc in docs.docs) {
      final data = doc.data();
      final name = data['senderName'] ?? 'مجهول';
      final msg = data['message'] ?? '';
      final time = data['createdAt'] != null ? intl.DateFormat('MM/dd HH:mm').format((data['createdAt'] as Timestamp).toDate()) : '';
      if (data['isDeleted'] == true) continue;
      
      buffer.writeln('[$time] $name: $msg');
    }
    
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    Get.snackbar(
      'تم تصدير المحادثة 🖨️',
      'تم نسخ السجل النصي للحافظة.',
      backgroundColor: primaryColor.withValues(alpha: 0.1),
      colorText: primaryColor,
      duration: const Duration(seconds: 4),
    );
  }

  void _confirmClearChat() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('مسح المحادثة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text('هل أنت متأكد من مسح جميع الرسائل؟ لا يمكن التراجع عن هذا الإجراء.', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('إلغاء', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          TextButton(
            onPressed: () async {
              final bgColor = Theme.of(context).cardColor;
              final fgColor = Theme.of(context).colorScheme.onSurface;
              Get.back();
              final chatId = _getChatId();
              final batch = FirebaseFirestore.instance.batch();
              final messages = await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').get();
              for (var doc in messages.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              if (!mounted) return;
              Get.snackbar('تم', 'تم مسح المحادثة بنجاح', backgroundColor: bgColor, colorText: fgColor);
            },
            child: Text('مسح الكل', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, ChatMessageModel? previousMessage) {
    final isMe = message.senderId == _effectiveUserId || (_effectiveUserId.isEmpty && message.senderName == _effectiveUserName);
    final isRead = message.isRead;
    final showTicks = isMe && !message.isSystem;
    
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    
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
                color: Theme.of(context).cardColor.withValues(alpha: 0.5), 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1))
              ),
              child: Text(
                _formatDividerDate(message.createdAt),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500),
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
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(message.senderName, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            gradient: isMe ? LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]) : null,
                            color: isMe ? null : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.only(
                              topRight: const Radius.circular(22),
                              topLeft: const Radius.circular(22),
                              bottomRight: Radius.circular(isMe ? 4 : 22),
                              bottomLeft: Radius.circular(isMe ? 22 : 4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isMe ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
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
                              if (message.isDeleted)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.block, size: 16, color: isMe ? Colors.black54 : Theme.of(context).colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 8),
                                    Text('🚫 تم سحب هذه الرسالة', style: TextStyle(fontStyle: FontStyle.italic, color: isMe ? Colors.black54 : Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                )
                              else ...[
                                if (message.imageUrl != null) _buildImageContent(message.imageUrl!),
                                if (message.message.isNotEmpty)
                                  MarkdownBody(
                                    data: message.message,
                                    styleSheet: MarkdownStyleSheet(
                                      p: TextStyle(color: isMe ? Colors.black : Theme.of(context).colorScheme.onSurface, fontSize: 15, height: 1.4),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: TextStyle(color: isMe ? Colors.black54 : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w500),
                                  ),
                                    if (showTicks) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        isRead ? Icons.done_all : Icons.done,
                                        color: isRead ? Colors.blue : Colors.black26,
                                        size: 15,
                                      ),
                                    ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (message.reactions != null && message.reactions!.isNotEmpty)
                          Positioned(
                            bottom: -15,
                            right: isMe ? 20 : null,
                            left: isMe ? null : 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildReactionsList(message.reactions!),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
                  if (isMe) _buildBubbleAvatar(_effectiveUserId, _effectiveUserName, _currentUserImage),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleAvatar(String userId, String name, String? image) {
    if (image != null && image.isNotEmpty) {
      return _buildRawAvatar(userId, name, image);
    }
    
    // للمستخدم الحالي
    if (userId == _effectiveUserId && _currentUserImage != null && _currentUserImage!.isNotEmpty) {
      return _buildRawAvatar(userId, name, _currentUserImage);
    }

    // للمستدخم الزائر (لا يملك صورة)
    if (userId.startsWith('guest_')) {
      return _buildRawAvatar(userId, name, null);
    }

    // فحص الذاكرة المؤقتة (cache)
    if (_bubbleAvatarCache.containsKey(userId)) {
      return _buildRawAvatar(userId, name, _bubbleAvatarCache[userId]);
    }

    // جلب الصورة ديناميكياً إذا كانت مفقودة في الرسائل القديمة
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final fetchedImage = data['profileImage']?.toString() ?? '';
          if (fetchedImage.isNotEmpty) {
            _bubbleAvatarCache[userId] = fetchedImage;
            return _buildRawAvatar(userId, name, fetchedImage);
          }
        }
        return _buildRawAvatar(userId, name, null); // حرف الاسم الأول كبديل أخير
      },
    );
  }

  Widget _buildRawAvatar(String userId, String name, String? image) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          if (userId.startsWith('guest_')) {
            Get.snackbar(
              'مستخدم زائر 👤',
              'هذا المستخدم يتواصل كزائر، لا يوجد ملف شخصي متاح.',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
              colorText: Theme.of(context).colorScheme.onSurface,
            );
          } else {
            Get.toNamed('/profile', arguments: userId);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), width: 1),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.surface,
            backgroundImage: (image != null && image.isNotEmpty) ? CachedNetworkImageProvider(image) as ImageProvider : null,
            child: (image == null || image.isEmpty)
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', 
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold))
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
        child: CachedImageWidget(
          imageUrl: url, 
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  String _formatTime(DateTime date) => intl.DateFormat('HH:mm').format(date);

  String _formatDividerDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'اليوم، ${intl.DateFormat('HH:mm a').format(date)}';
    }
    return intl.DateFormat('dd MMM, HH:mm a').format(date);
  }

  List<Widget> _buildReactionsList(Map<String, dynamic> reactions) {
    final targetCounts = <String, int>{};
    for (var r in reactions.values) {
      targetCounts[r] = (targetCounts[r] ?? 0) + 1;
    }
    return targetCounts.entries.map((e) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text('${e.key} ${e.value > 1 ? e.value : ""}', style: const TextStyle(fontSize: 12)),
    )).toList();
  }

  Widget _buildReplyInBubble(Map<String, dynamic> reply, bool isMe) {
    return GestureDetector(
      onTap: () {
        final replyId = reply['id'];
        if (replyId != null && _messageKeys.containsKey(replyId)) {
          final context = _messageKeys[replyId]?.currentContext;
          if (context != null) {
            Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
            setState(() => _highlightedMessageId = replyId);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _highlightedMessageId = null);
            });
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMe ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border(right: BorderSide(color: isMe ? Colors.black45 : Theme.of(context).colorScheme.primary, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reply['senderName'] ?? '', style: TextStyle(color: isMe ? Colors.black87 : Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
            Text(reply['message'] ?? '', style: TextStyle(color: isMe ? Colors.black54 : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showLongPressMenu(ChatMessageModel message) {
    Vibrate.feedback(FeedbackType.medium);
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '🙏', '😂', '😮', '😢'].map((emoji) {
                return GestureDetector(
                  onTap: () async {
                    Get.back();
                    if (message.id != null) {
                       await FirebaseFirestore.instance.collection('chats').doc(_getChatId()).collection('messages').doc(message.id).set({
                         'reactions': {_effectiveUserId: emoji}
                       }, SetOptions(merge: true));
                       Vibrate.feedback(FeedbackType.light);
                    }
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: Icon(Icons.reply_rounded, color: Theme.of(context).colorScheme.onSurface),
              title: Text('رد', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Get.back();
                setState(() => _replyingTo = message);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.onSurface),
              title: Text('تعديل', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Get.back();
                setState(() {
                  _editingMessage = message;
                  _messageController.text = message.message;
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded, color: Theme.of(context).colorScheme.onSurface),
              title: Text('نسخ النص', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Get.back();
                Clipboard.setData(ClipboardData(text: message.message));
              },
            ),
            ListTile(
              leading: Icon(Icons.forward_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text('إعادة توجيه', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              onTap: () {
                Get.back();
                _showForwardSelector(message);
              },
            ),
            if (message.senderId == _effectiveUserId || (_effectiveUserId.isEmpty && message.senderName == _effectiveUserName))
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text('سحب الرسالة', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Get.back();
                  if (message.id != null) _deleteMessage(message.id!);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showForwardSelector(ChatMessageModel message) {
    String query = '';
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('إرسال إلى...', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(hintText: 'بحث عن اسم أو هاتف...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                onChanged: (val) => setModalState(() => query = val.toLowerCase()),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final users = snapshot.data!.docs.where((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final name = d['name']?.toString().toLowerCase() ?? '';
                      return name.contains(query) && doc.id != _effectiveUserId;
                    }).toList();

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final u = users[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(child: Text(u['name']?[0] ?? '')),
                          title: Text(u['name'] ?? ''),
                          trailing: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.primary),
                          onTap: () async {
                            Get.back();
                            _forwardTo(users[index].id, u['name'], message);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _forwardTo(String targetId, String? targetName, ChatMessageModel original) async {
    final chatId = _getChatIdFor(targetId);
    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add({
      'senderId': _effectiveUserId,
      'senderName': _effectiveUserName,
      'senderImage': _currentUserImage,
      'message': original.message,
      'isRead': false,
      'isForwarded': true,
      'createdAt': FieldValue.serverTimestamp(),
      'chatId': chatId,
    });

    // Update chat document so conversation appears in inbox
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': '↩️ ${original.message}',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'type': 'private',
      'participants': FieldValue.arrayUnion([_effectiveUserId, targetId]),
      'participantNames.$_effectiveUserId': _effectiveUserName,
      'participantNames.$targetId': targetName ?? 'مستخدم',
      'participantAvatars.$_effectiveUserId': _currentUserImage ?? '',
      'unreadCount.$targetId': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Notify the recipient
    try {
      await NotificationService.sendNotification(
        userId: targetId,
        type: 'new_message',
        title: 'رسالة محوّلة من $_effectiveUserName ↩️',
        body: original.message,
        data: {'chatId': chatId, 'senderId': _effectiveUserId, 'senderName': _effectiveUserName},
      );
    } catch (_) {}

    Get.snackbar('تم التوجيه 🚀', 'تم إرسال الرسالة إلى ${targetName ?? "المستلم"}');
  }

  String _getChatIdFor(String targetId) {
    if (_effectiveUserId.startsWith('guest_')) return _effectiveUserId; // Guests can only chat in their own ID
    final List<String> ids = [_effectiveUserId, targetId];
    ids.sort();
    return ids.join('_');
  }


  Widget _buildSlashCommandsBar() {
    final query = _messageController.text.trim();
    final matches = {
      '/ترحيب': 'مرحباً بك في منصة ناس الخير. فريقنا جاهز لتقديم الدعم.',
      '/وثائق': 'يرجى إرسال صور واضحة لوثيقة الهوية والتقرير الطبي (إن وجد).',
      '/انتظار': 'طلبك حالياً قيد المراجعة لدى قسم التقييم. سيتم الرد عليك قريباً.',
      '/إغلاق': 'نشكرك على تواصلك معنا. سيتم إغلاق المحادثة الآن. حافظكم الله.',
    }.entries.where((e) => e.key.startsWith(query)).toList();
    
    if (matches.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: matches.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = matches[index];
          return ListTile(
            title: Text(entry.key, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            onTap: () {
              setState(() => _showSlashCommands = false);
              _messageController.text = entry.value;
              _sendMessage();
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    final isAdminOrSupport = _authController.currentUser.value?.role == UserRole.admin || _authController.currentUser.value?.role == UserRole.superAdmin || _authController.currentUser.value?.role == UserRole.chatModerator;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null) _buildReplyPreview(),
        if (_editingMessage != null) _buildEditPreview(),
        if (_showSlashCommands && isAdminOrSupport) _buildSlashCommandsBar(),
        Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10, top: 10, left: 12, right: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface, 
            boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05), offset: const Offset(0, -2), blurRadius: 4)]
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Get.snackbar(
                  'قريباً 🚀',
                  'ميزة إرسال الصور ستتوفر في التحديث القادم',
                  backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
                  colorText: Theme.of(context).colorScheme.onSurface,
                  snackPosition: SnackPosition.TOP,
                ),
                child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.photo_camera, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Get.snackbar(
                  'قريباً 🎙️',
                  'ميزة الرسائل الصوتية ستتوفر في التحديث القادم',
                  backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
                  colorText: Theme.of(context).colorScheme.onSurface,
                  snackPosition: SnackPosition.TOP,
                ),
                child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.mic_none_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: canSend ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        _editingMessage != null ? Icons.check : Icons.send_rounded,
                        color: canSend ? Colors.white : Colors.grey,
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
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(right: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_replyingTo!.senderName, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(_replyingTo!.message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('تعديل الرسالة...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _editingMessage = null;
              _messageController.clear();
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;

    final chatId = _getChatId();
    
    // منع الإرسال إذا كان chatId غير صحيح
    if (chatId == 'invalid_chat') {
      Get.snackbar(
        'خطأ',
        'لا يمكن تحديد المحادثة. تأكد من البيانات',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.1),
      );
      return;
    }

    final text = _messageController.text.trim();
    final replyTo = _replyingTo;
    final editingMessage = _editingMessage;
    
    _messageController.clear();
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
    });
    
    _isCurrentlyTyping = false;
    _updateTypingStatus(false);

    final messagesRef = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages');

    if (editingMessage != null && editingMessage.id != null) {
      await messagesRef.doc(editingMessage.id).update({'message': text});
    } else {
      String? imageUrl;
      if (_selectedImage != null) {
        setState(() => _isUploading = true);
        final ref = FirebaseStorage.instance.ref('chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
        _selectedImage = null;
        setState(() => _isUploading = false);
      }

      final String sendingName = _effectiveUserName;
      
      try {
        await messagesRef.add({
          'senderId': _effectiveUserId,
          'senderName': sendingName,
          'senderImage': _currentUserImage,
          'message': text,
          'imageUrl': imageUrl,
          'isRead': false,
          'readBy': [_effectiveUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'chatId': chatId,
          if (replyTo != null) 'reply_to': {
            'id': replyTo.id,
            'message': replyTo.message,
            'senderName': replyTo.senderName,
          }
        });
      } catch (e) {
        _handleError('إرسال الرسالة (عذراً، قد يكون هناك مشكلة في الصلاحيات)', e);
        return;
      }

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastMessage': imageUrl != null ? '📷 صورة' : text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'type': widget.isGroupChat ? 'group' : (chatId.startsWith('guest_') ? 'guest' : 'private'),
        'participants': FieldValue.arrayUnion([_effectiveUserId, if (widget.targetUserId != null) widget.targetUserId!]),
        'participantNames.$_effectiveUserId': sendingName,
        'participantAvatars.$_effectiveUserId': _currentUserImage ?? '',
      }, SetOptions(merge: true));

      // جلب اسم وصورة المستقبل إذا لم تكن موجودة (لمزامنة البيانات في صندوق الرسائل)
      if (widget.targetUserId != null && widget.targetUserId!.isNotEmpty && !widget.isGroupChat) {
        try {
          final targetUserDoc = await FirebaseFirestore.instance.collection('users').doc(widget.targetUserId!).get();
          if (targetUserDoc.exists) {
            final targetUserData = targetUserDoc.data() as Map<String, dynamic>;
            final targetName = targetUserData['name'] ?? 'مستخدم';
            final targetAvatar = targetUserData['profileImage'] ?? targetUserData['avatar'] ?? '';
            
            await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
              'participantNames.${widget.targetUserId!}': targetName,
              'participantAvatars.${widget.targetUserId!}': targetAvatar,
            }, SetOptions(merge: true));
          } else if (widget.targetUserName != null) {
            // كحل بديل إذا لم يكن المستخدم مسجلاً (زائر) ولكن الاسم متاح
            await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
              'participantNames.${widget.targetUserId!}': widget.targetUserName,
            }, SetOptions(merge: true));
          }
        } catch (e) {
          _handleError('حفظ بيانات الطرف الآخر', e);
        }
      }

      // حفظ صورة المستقبل بشكل منفصل (إذا كان موجوداً)
      if (widget.targetUserId != null && widget.targetUserId!.isNotEmpty && !widget.isGroupChat) {
        try {
          final targetUserDoc = await FirebaseFirestore.instance.collection('users').doc(widget.targetUserId!).get();
          if (targetUserDoc.exists) {
            final targetUserData = targetUserDoc.data() as Map<String, dynamic>;
            final targetUserAvatar = targetUserData['profileImage'] ?? '';
            
            await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
              'participantAvatars.${widget.targetUserId!}': targetUserAvatar,
            }, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('⚠️ خطأ في حفظ صورة المستقبل: $e');
        }
      }

      // تحديث عداد الرسائل غير المقروءة
      if (widget.targetUserId != null && !widget.isGroupChat) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'unreadCount.${widget.targetUserId!}': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      // حفظ بيانات الزائر إذا كان زائراً لضمان بقاء المحادثة مرئية للمديرين
      if (chatId.startsWith('guest_')) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'type': 'guest', // التأكيد على نوع المحادثة
          'guestName': _effectiveUserName,
          'guestPhone': _effectiveUserId.replaceFirst('guest_', ''),
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Send Notification
      try {
        final String senderDisplayName = (_authController.currentUser.value?.name != null && _authController.currentUser.value!.name.isNotEmpty) 
            ? _authController.currentUser.value!.name 
            : _effectiveUserName;

        final notificationData = {
          'chatId': chatId,
          'senderId': _effectiveUserId,
          'senderName': senderDisplayName,
        };

        final bool isSenderGuest = _effectiveUserId.startsWith('guest_');
        final bool isReceiverGuest = widget.targetUserId != null && widget.targetUserId!.startsWith('guest_');

        // 1. منع الإشعارات الذاتية (إذا كان المرسل هو نفسه المستقبل)
        if (widget.targetUserId == _effectiveUserId) {
          debugPrint('🚫 منع إشعار: المرسل هو نفسه المستقبل');
          return;
        }

        // 2. إشعارات المجموعات (برودكاست لجميع المدراء)
        if (widget.isGroupChat) {
          if (chatId == 'group_team') {
            await NotificationService.notifyAllAdmins(
              type: 'group_message',
              title: 'رسالة في مجموعة الفريق 👥',
              body: '$senderDisplayName: $text',
              data: notificationData,
              excludeUserId: _effectiveUserId,
            );
          }
        } 
        // 3. إشعارات الزوار (برودكاست لجميع المدراء)
        else if (isSenderGuest) {
          await NotificationService.notifyAllAdmins(
            type: 'guest_message',
            title: 'رسالة جديدة من زائر 💬',
            body: '$senderDisplayName: $text',
            data: notificationData,
            excludeUserId: _effectiveUserId,
          );
        } 
        // 4. المحادثات الخاصة الموجهة (للمستقبل فقط)
        else if (widget.targetUserId != null && !isReceiverGuest) {
          // تأكيد إضافي: لا ترسل إشعاراً لجميع المدراء إذا كانت المحادثة خاصة
          await NotificationService.sendNotification(
            userId: widget.targetUserId!,
            type: 'new_message',
            title: 'رسالة من $senderDisplayName 💬',
            body: text,
            data: notificationData,
          );
        } else if (isReceiverGuest) {
          debugPrint('📤 رسالة من الإدارة لزائر - لا يوجد إشعار داخلي للزائر حالياً');
        }
      } catch (e) {
        _handleError('إرسال إشعار الدردشة', e);
      }
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final chatId = _getChatId();
      
      // حذف من Firestore مباشرة
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      // حذف من الكاش المحلي
      setState(() {
        _cachedMessages.removeWhere((msg) => msg.id == messageId);
      });
      
      // تحديث الكاش في SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final encodedMessages = _cachedMessages.map((m) => m.toMap()).toList();
        await prefs.setString('cached_chat_$chatId', jsonEncode(encodedMessages));
      } catch (e) {
        debugPrint('⚠️ خطأ في تحديث الكاش: $e');
      }
      
      // رسالة تأكيد
      Get.snackbar(
        'تم الحذف',
        'تم حذف الرسالة بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      
    } catch (e) {
      debugPrint('❌ خطأ في حذف الرسالة: $e');
      Get.snackbar(
        'خطأ',
        'فشل حذف الرسالة',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.1),
      );
    }
  }

  Future<void> _markMessagesAsRead(List<QueryDocumentSnapshot> docs) async {
    final unread = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final readBy = (data['readBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
      return (data['senderId'] ?? data['sender_id']) != _effectiveUserId && !readBy.contains(_effectiveUserId);
    }).toList();

    if (unread.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unread) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([_effectiveUserId]),
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
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('أعضاء الغرفة', style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('role', whereIn: ['admin', 'superAdmin', 'worker', 'chatModerator']).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final workers = snapshot.data!.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                      
                      return ListView.builder(
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          final worker = workers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              backgroundImage: (worker.profileImage != null && worker.profileImage!.isNotEmpty) ? CachedNetworkImageProvider(worker.profileImage!) as ImageProvider : null,
                              child: (worker.profileImage == null || worker.profileImage!.isEmpty) ? Text(worker.name[0], style: TextStyle(color: Theme.of(context).colorScheme.primary)) : null,
                            ),
                            title: Text(worker.name, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                            subtitle: Text(worker.role.displayName, style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            trailing: worker.id == _effectiveUserId ? null : IconButton(
                              icon: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary, size: 24),
                              onPressed: () {
                                Get.back();
                                Get.to(() => ChatScreen(isGroupChat: false, targetUserId: worker.id, targetUserName: worker.name));
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
      body: Center(child: InteractiveViewer(child: CachedImageWidget(imageUrl: url))),
    );
  }
}
