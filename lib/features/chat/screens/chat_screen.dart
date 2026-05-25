import 'dart:io';

import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:animate_do/animate_do.dart';

import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../auth/controllers/auth_controller.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/firebase_storage_service.dart';
import '../../../data/services/image_compression_service.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/user_model.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/cached_image_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/audio_player_widget.dart'; // We will create this

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
  
  Stream<QuerySnapshot> _messagesStream = const Stream.empty();
  Stream<DocumentSnapshot>? _chatDocStream;
  Stream<DocumentSnapshot>? _targetUserStream;
  
  bool _isCurrentlyTyping = false;
  bool _showSlashCommands = false;
  Timer? _typingTimer;
  Timer? _presenceTimer;
  Timer? _cacheDebounceTimer;
  static const int _maxMessageKeys = 200;
  List<ChatMessageModel> _cachedMessages = [];
  
  static final Map<String, String> _bubbleAvatarCache = {};
  final Map<String, UserRole?> _roleCache = <String, UserRole?>{};
  
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  bool _accessDenied = false;
  String _accessDeniedMessage = '';
  bool _privateStreamsBound = false;
  bool _metadataSynced = false;

  // Audio Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDurationSeconds = 0;
  String _recordingDurationStr = '00:00';

  String get _effectiveUserId {
    if (_authController.currentUser.value != null && _authController.currentUser.value!.id.isNotEmpty) {
      return _authController.currentUser.value!.id;
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      return firebaseUser.uid;
    }
    return '';
  }

  String get _effectiveUserName {
    final currentUser = _authController.currentUser.value;
    if (currentUser != null && currentUser.name.isNotEmpty) {
      return currentUser.name;
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      if (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) {
        return firebaseUser.displayName!;
      }
      if (firebaseUser.email != null && firebaseUser.email!.isNotEmpty) {
        final prefix = firebaseUser.email!.split('@')[0];
        return prefix.replaceAll(RegExp(r'[._-]'), ' ');
      }
    }
    return 'مشارك (${_effectiveUserId.isNotEmpty ? _effectiveUserId.substring(0, min(5, _effectiveUserId.length)) : "مجهول"})';
  }


  String? get _currentUserImage => _authController.currentUser.value?.profileImage;

  bool _isAdminRole(UserRole? role) {
    return role == UserRole.admin || role == UserRole.superAdmin;
  }

  bool _isGroupAllowedForRole(String groupId, UserRole? role) {
    // 🛡️ إذا كان الدور لم يحمل بعد، نمنح فرصة للتحقق لاحقاً في الـ build
    if (role == null) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      // لا نحظر هنا، سنحظر في الـ build إذا استمر النقص
      return true; 
    }

    if (groupId == 'group_management') {
      return _isAdminRole(role);
    }
    if (groupId == 'group_team') {
      return role == UserRole.worker ||
          role == UserRole.chatModerator ||
          _isAdminRole(role);
    }
    return false;
  }

  UserRole? _parseUserRole(dynamic rawRole) {
    if (rawRole == null) return null;
    final roleName = rawRole.toString();
    for (final role in UserRole.values) {
      if (role.name == roleName) return role;
    }
    return null;
  }

  bool _canCurrentRoleMessageTargetRole({
    required UserRole? myRole,
    required UserRole? targetRole,
  }) {
    if (targetRole == null || myRole == null) return false;

    if (_isAdminRole(myRole)) {
      return true;
    }

    if (myRole == UserRole.worker ||
        myRole == UserRole.chatModerator ||
        myRole == UserRole.donor ||
        myRole == UserRole.beneficiary) {
      return _isAdminRole(targetRole);
    }

    return false;
  }

  Future<UserRole?> _fetchRoleForUser(String userId) async {
    if (_roleCache.containsKey(userId)) {
      return _roleCache[userId];
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) {
        _roleCache[userId] = null;
        return null;
      }
      final data = doc.data() as Map<String, dynamic>;
      final parsedRole = _parseUserRole(data['role']);
      _roleCache[userId] = parsedRole;
      return parsedRole;
    } catch (_) {
      _roleCache[userId] = null;
      return null;
    }
  }

  Future<bool> _canMessageTargetUser(String targetId) async {
    final myRole = _authController.currentUser.value?.role;
    if (_isAdminRole(myRole)) {
      return true;
    }
    final targetRole = await _fetchRoleForUser(targetId);
    return _canCurrentRoleMessageTargetRole(myRole: myRole, targetRole: targetRole);
  }

  void _denyChatAccess(String message) {
    if (!mounted) return;
    setState(() {
      _accessDenied = true;
      _accessDeniedMessage = message;
    });
    Get.snackbar(
      'وصول مرفوض',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withValues(alpha: 0.15),
    );
  }

  Future<void> _validateDynamicChatAccessAndBootstrap() async {
    if (_accessDenied) return;

    if (!widget.isGroupChat && widget.targetUserId != null && widget.targetUserId!.isNotEmpty) {
      final allowed = await _canMessageTargetUser(widget.targetUserId!);
      if (!allowed) {
        _denyChatAccess('هذا الدور يمكنه مراسلة الإدارة فقط في المحادثات الخاصة.');
        return;
      }

      await _ensurePrivateChatDocument();
      _bindPrivateStreamsIfNeeded();

      _setChatPresence(true);
      _presenceTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _setChatPresence(true);
      });
    }

    await _syncMyMetadata();
    await _markAsRead();
    await _loadCachedMessages();
  }

  Map<String, dynamic> _privateBootstrapFields() {
    if (widget.isGroupChat || widget.targetUserId == null || widget.targetUserId!.isEmpty) {
      return <String, dynamic>{};
    }

    final targetId = widget.targetUserId!;
    final participants = <String>[_effectiveUserId, targetId]..sort();
    return <String, dynamic>{
      'type': 'private',
      'participants': participants,
      'participantNames.$_effectiveUserId': _effectiveUserName,
      'participantNames.$targetId': widget.targetUserName ?? 'مستخدم',
      'participantAvatars.$_effectiveUserId': _currentUserImage ?? '',
      'participantAvatars.$targetId': '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool _sameParticipantSet(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    final a = [...first]..sort();
    final b = [...second]..sort();
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _bindPrivateStreamsIfNeeded() {
    if (_privateStreamsBound) return;

    final chatId = _getChatId();
    if (chatId == 'invalid_chat') return;

    _privateStreamsBound = true;
    if (!mounted) return;

    setState(() {
      _messagesStream = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();

      _chatDocStream = FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots();
      if (widget.targetUserId != null && widget.targetUserId != 'system') {
        _targetUserStream = FirebaseFirestore.instance.collection('users').doc(widget.targetUserId!).snapshots();
      }
    });
  }

  Future<void> _ensurePrivateChatDocument() async {
    if (widget.isGroupChat || widget.targetUserId == null || widget.targetUserId!.isEmpty) return;

    final chatId = _getChatId();
    if (chatId == 'invalid_chat') return;

    try {
      final targetId = widget.targetUserId!;
      final expectedParticipants = <String>[_effectiveUserId, targetId]..sort();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final existing = await chatRef.get();

      if (existing.exists) {
        final existingData = existing.data() as Map<String, dynamic>;
        final existingType = (existingData['type'] ?? '').toString();
        if (existingType.isNotEmpty && existingType != 'private') {
          _denyChatAccess('تعذر تهيئة المحادثة: نوع محادثة غير متوافق.');
          return;
        }

        final existingParticipants = List<String>.from(existingData['participants'] ?? const <String>[]);
        if (existingParticipants.isNotEmpty && !_sameParticipantSet(existingParticipants, expectedParticipants)) {
          _denyChatAccess('تعذر تهيئة المحادثة: المشاركون لا يطابقون معرف المحادثة.');
          return;
        }
      }

      await chatRef.set({
        ..._privateBootstrapFields(),
        'unreadCount.$_effectiveUserId': 0,
        'unreadCount.$targetId': 0,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error ensuring private chat doc: $e');
      _denyChatAccess('تعذر تهيئة المحادثة وفق الصلاحيات الحالية.');
    }
  }

  String _getChatId() {
    final currentRole = _authController.currentUser.value?.role;

    if (_effectiveUserId.isEmpty) {
      debugPrint('⚠️ خطأ: _effectiveUserId فارغ');
      return 'invalid_chat';
    }

    if (widget.isGroupChat) {
      final requestedGroupId = (widget.chatId != null && widget.chatId!.isNotEmpty)
          ? widget.chatId!
          : 'group_team';
      if (!_isGroupAllowedForRole(requestedGroupId, currentRole)) {
        debugPrint('⚠️ وصول مرفوض للمجموعة: $requestedGroupId للدور: $currentRole');
        return 'invalid_chat';
      }
      return requestedGroupId;
    }

    if (widget.chatId != null &&
        widget.chatId!.isNotEmpty &&
        widget.targetUserId == null &&
        widget.chatId!.startsWith('guest_')) {
      return _isAdminRole(currentRole) ? widget.chatId! : 'invalid_chat';
    }

    final target = widget.targetUserId;
    if (target == null || target.isEmpty || target == _effectiveUserId || target == 'system') {
      debugPrint('⚠️ خطأ: targetUserId فارغ');
      return 'invalid_chat';
    }

    final sorted = [_effectiveUserId, target]..sort();
    final generatedChatId = '${sorted[0]}_${sorted[1]}';

    if (widget.chatId != null && widget.chatId!.isNotEmpty && widget.chatId! != generatedChatId) {
      debugPrint('⚠️ محاولة تمرير chatId غير متوافق مع المشاركين');
      return 'invalid_chat';
    }
    
    debugPrint('✅ تم إنشاء chatId: $generatedChatId');
    return generatedChatId;
  }

  Future<void> _markAsRead() async {
    final chatId = _getChatId();
    if (chatId == 'invalid_chat' || _effectiveUserId.isEmpty) return;

    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid != null && firebaseUid != _effectiveUserId) {
      debugPrint('⚠️ Refused unread reset due to uid mismatch. effective=$_effectiveUserId firebase=$firebaseUid');
      return;
    }
    
    final isAdmin = _isAdminRole(_authController.currentUser.value?.role);
    final isGuestChat = chatId.startsWith('guest_');

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        ..._privateBootstrapFields(),
        'unreadCount.$_effectiveUserId': 0,
        if (isAdmin && isGuestChat) 'guestUnreadCount': 0,
        if (isAdmin && isGuestChat) 'hasUnreadGuestMessage': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error marking chat as read: $e');
    }
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (widget.isGroupChat || _effectiveUserId.isEmpty) return;

    final chatId = _getChatId();
    if (chatId == 'invalid_chat') return;

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        ..._privateBootstrapFields(),
        'typing': {
          _effectiveUserId: isTyping,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error updating typing state: $e');
    }
  }

  // وظيفة جلب هوية الزائر تم حذفها

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

        // تم إزالة تحديث بيانات الزوار

        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          ..._privateBootstrapFields(),
          ...updateData,
        }, SetOptions(merge: true));
        debugPrint('✅ Chat Metadata Synced for $name');
      } catch (e) {
        debugPrint('⚠️ Error syncing chat metadata: $e');
      }
    }
  }

  // مزامنة بيانات الطرف الآخر لتقديم واجهة أفضل للمديرين مستقبلاً
  Future<void> _syncOtherParticipantMetadata(String realName, String profileImage) async {
    if (widget.isGroupChat) return;
    try {
      final chatId = _getChatId();
      if (chatId == 'invalid_chat') return;

      if (widget.targetUserId != null) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          ..._privateBootstrapFields(),
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
    final chatId = _getChatId();

    if (chatId != 'invalid_chat') {
      if (widget.isGroupChat) {
        _messagesStream = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots();
      }

      _validateDynamicChatAccessAndBootstrap();
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
    _presenceTimer?.cancel();
    _cacheDebounceTimer?.cancel();
    if (!_accessDenied && !widget.isGroupChat && widget.targetUserId != null) {
      _setChatPresence(false);
    }
    _updateTypingStatus(false);
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _isTextEmpty.dispose();
    super.dispose();
  }

  Future<void> _setChatPresence(bool isActive) async {
    if (widget.isGroupChat || _effectiveUserId.isEmpty) return;
    final chatId = _getChatId();
    if (chatId == 'invalid_chat') return;

    try {
      final payload = {
        ..._privateBootstrapFields(),
        'activeInChat.$_effectiveUserId': isActive,
        'lastActivity.$_effectiveUserId': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error updating chat presence: $e');
    }
  }

  Future<bool> _isTargetUserActiveInThisChat(String chatId, String targetUserId) async {
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return false;

      final data = chatDoc.data() as Map<String, dynamic>;
      final activeInChat = Map<String, dynamic>.from(data['activeInChat'] ?? {});
      final isActive = activeInChat[targetUserId] == true;

      Timestamp? lastActivityTs;
      if (data['lastActivity'] is Map && data['lastActivity'][targetUserId] != null) {
        lastActivityTs = data['lastActivity'][targetUserId] as Timestamp;
      }

      if (!isActive || lastActivityTs == null) return false;

      final secondsSinceLastActivity = DateTime.now().difference(lastActivityTs.toDate()).inSeconds;
      return secondsSinceLastActivity <= 45;
    } catch (_) {
      return false;
    }
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
      backgroundColor: Colors.red.withValues(alpha: 0.15),
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
    if (_accessDenied) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _accessDeniedMessage.isNotEmpty
                  ? _accessDeniedMessage
                  : 'لا تملك صلاحية الوصول إلى هذه المحادثة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

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
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'تعذر تحميل المحادثة بسبب الصلاحيات أو الاتصال.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    List<ChatMessageModel> displayMessages = [];

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      if (_cachedMessages.isNotEmpty) {
                        displayMessages = _cachedMessages;
                      } else {
                        return _buildSkeletonLoading();
                      }
                    } else if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final messages = snapshot.data!.docs;
                      WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsRead(messages));
                      // Debounce cache writes: write to disk at most once every 3s, not on every snapshot
                      _cacheDebounceTimer?.cancel();
                      _cacheDebounceTimer = Timer(const Duration(seconds: 3), () => _cacheMessages(messages));
                      displayMessages = messages.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        data['id'] = d.id;
                        return ChatMessageModel.fromMap(data);
                      }).toList();
                    } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      if (_cachedMessages.isNotEmpty) {
                         displayMessages = _cachedMessages;
                      } else {
                         displayMessages = [];
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
                        physics: const BouncingScrollPhysics(), // تجربة تمرير أكثر سلاسة
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) {
                          final message = filteredMessages[index];
                          final previousMessage = index + 1 < filteredMessages.length
                            ? filteredMessages[index + 1]
                            : null;

                          if (message.id != null) {
                            _messageKeys.putIfAbsent(message.id!, () => GlobalKey());
                            // Prevent unbounded growth: trim oldest half when exceeding limit
                            if (_messageKeys.length > _maxMessageKeys) {
                              final toRemove = _messageKeys.keys.take(_maxMessageKeys ~/ 2).toList();
                              for (final k in toRemove) { _messageKeys.remove(k); }
                            }
                          }

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300), 
                            key: message.id != null ? _messageKeys[message.id!] : ValueKey('msg_$index'),
                            color: _highlightedMessageId == message.id 
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                                : Colors.transparent,
                            child: _buildMessageBubble(message, previousMessage),
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
            alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
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
                          // ترميم البيانات في الخلفية مرة واحدة فقط لتجنب الكتابات المتكررة
                          if (!_metadataSynced) {
                            _metadataSynced = true;
                            _syncOtherParticipantMetadata(realName, realImage);
                          }
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
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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
                color: isOnline ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              statusText,
              style: GoogleFonts.tajawal(fontSize: 12, color: isOnline ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant),
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
      backgroundColor: primaryColor.withValues(alpha: 0.15),
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
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05)),
          ),
          child: Text(
            message.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 10.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    
    final showTimeDivider = previousMessage == null ||
        message.createdAt.difference(previousMessage.createdAt).inMinutes > 60 ||
        message.createdAt.day != previousMessage.createdAt.day;

    return Column(
      children: [
        if (showTimeDivider)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _formatDividerDate(message.createdAt),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6), 
                  fontSize: 10, 
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        SwipeTo(
          onRightSwipe: (details) {
            HapticFeedback.mediumImpact();
            setState(() => _replyingTo = message);
          },
          child: GestureDetector(
            onLongPress: () {
              HapticFeedback.heavyImpact();
              _showLongPressMenu(message);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) ...[
                    _buildBubbleAvatar(message.senderId, message.senderName, message.senderImage),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(bottom: 6, start: 8),
                            child: Text(
                              message.senderName, 
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary, 
                                fontSize: 11, 
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              )
                            ),
                          ),
                        Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            gradient: isMe ? AppTheme.primaryGradient : null,
                            color: isMe ? null : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.only(
                              topRight: const Radius.circular(22),
                              topLeft: const Radius.circular(22),
                              bottomRight: Radius.circular(isMe ? 4 : 22),
                              bottomLeft: Radius.circular(isMe ? 22 : 4),
                            ),
                            border: isMe ? null : Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05), width: 0.5),
                            boxShadow: [
                              BoxShadow(
                                color: isMe 
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) 
                                  : Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topRight: const Radius.circular(22),
                              topLeft: const Radius.circular(22),
                              bottomRight: Radius.circular(isMe ? 4 : 22),
                              bottomLeft: Radius.circular(isMe ? 22 : 4),
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: message.imageUrl != null 
                                      ? const EdgeInsets.all(4) 
                                      : const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 20),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (message.replyTo != null) _buildReplyInBubble(message.replyTo!, isMe),
                                      if (message.isDeleted)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.block_flipped, size: 14, color: isMe ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                            const SizedBox(width: 8),
                                            Text(
                                              'تم حذف هذه الرسالة', 
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic, 
                                                color: isMe ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                              )
                                            ),
                                          ],
                                        )
                                      else ...[
                                        if (message.imageUrl != null) _buildImageContent(message.imageUrl!),
                                        if (message.audioUrl != null) 
                                          AudioPlayerWidget(
                                            url: message.audioUrl!, 
                                            duration: message.audioDuration,
                                            isMe: isMe,
                                          ),
                                        if (message.message.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: MarkdownBody(
                                              data: message.message,
                                              styleSheet: MarkdownStyleSheet(
                                                p: TextStyle(
                                                  color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface, 
                                                  fontSize: 15.5, 
                                                  height: 1.45,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                // الوقت والحالة في الركن السفلي
                                Positioned(
                                  bottom: 6,
                                  right: isMe ? 12 : null,
                                  left: isMe ? null : 12,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(message.createdAt),
                                        style: TextStyle(
                                          color: isMe ? Colors.white.withValues(alpha: 0.6) : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), 
                                          fontSize: 9.5, 
                                          fontWeight: FontWeight.w600
                                        ),
                                      ),
                                      if (showTicks) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                                          color: isRead ? const Color(0xFF4FC3F7) : Colors.white.withValues(alpha: 0.4),
                                          size: 13,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (message.reactions != null && message.reactions!.isNotEmpty)
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: EdgeInsetsDirectional.only(start: isMe ? 0 : 12, end: isMe ? 12 : 0),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1), width: 0.5),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 3))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _buildReactionsList(message.reactions!),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildBubbleAvatar(_effectiveUserId, _effectiveUserName, _currentUserImage),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleAvatar(String userId, String name, String? image) {
    if (userId == 'system') {
      return _buildRawAvatar(userId, name, null);
    }

    // الأولوية للصورة الممررة مع الرسالة
    if (image != null && image.isNotEmpty) {
      return _buildRawAvatar(userId, name, image);
    }
    
    // للمستخدم الحالي
    if (userId == _effectiveUserId && _currentUserImage != null && _currentUserImage!.isNotEmpty) {
      return _buildRawAvatar(userId, name, _currentUserImage);
    }

    // فحص الذاكرة المؤقتة (cache)
    if (_bubbleAvatarCache.containsKey(userId)) {
      return _buildRawAvatar(userId, name, _bubbleAvatarCache[userId]);
    }

    // إذا لم تتوفر الصورة، نعرض رمزاً مؤقتاً سريعاً بدلاً من FutureBuilder الثقيل
    // سيتم تحديث الكاش لاحقاً أو عند وصول رسائل جديدة تحتوي على الصورة
    return _buildRawAvatar(userId, name, null);
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
              backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.15),
              colorText: Theme.of(context).colorScheme.onSurface,
            );
          } else {
            Get.toNamed('/profile', arguments: userId);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), width: 1),
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
          color: isMe ? Colors.black.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.15),
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

  bool get _canDeleteAnyMessage {
    final role = _authController.currentUser.value?.role;
    return _isAdminRole(role) || role == UserRole.chatModerator;
  }

  void _showLongPressMenu(ChatMessageModel message) {
    HapticFeedback.heavyImpact();
    
    final isMe = message.senderId == _effectiveUserId || (_effectiveUserId.isEmpty && message.senderName == _effectiveUserName);
    
    Get.dialog(
      GestureDetector(
        onTap: () => Get.back(),
        child: Material(
          color: Colors.black.withValues(alpha: 0.6), // تظليل أغمق للتركيز
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. شريط الرموز التعبيرية (Emoji Bar)
              FadeInDown(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 1)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...['👍', '❤️', '😂', '😮', '😢', '🙏'].asMap().entries.map((entry) {
                        return ZoomIn(
                          delay: Duration(milliseconds: entry.key * 30),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () { Get.back(); _addReaction(message, entry.value); },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(entry.value, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        );
                      }),
                      InkWell(
                        onTap: () { Get.back(); _showFullEmojiPicker(message); },
                        child: Container(
                          margin: const EdgeInsetsDirectional.only(start: 4),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. معاينة الرسالة المختارة (توسيط كامل)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 2)
                      ],
                    ),
                    child: _buildBubbleContentOnly(message, isMe),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. شريط الإجراءات (Actions Bar)
              FadeInUp(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 1)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniHorizontalAction(
                        Icons.reply_rounded, 
                        'رد', 
                        () { Get.back(); setState(() => _replyingTo = message); }
                      ),
                      _buildMiniDivider(),
                      _buildMiniHorizontalAction(
                        Icons.copy_rounded, 
                        'نسخ', 
                        () { 
                          Get.back(); 
                          Clipboard.setData(ClipboardData(text: message.message));
                          Get.snackbar('نسخ', 'تم نسخ النص', snackPosition: SnackPosition.TOP, duration: const Duration(seconds: 1));
                        }
                      ),
                      _buildMiniDivider(),
                      if (isMe) ...[
                        _buildMiniHorizontalAction(
                          Icons.edit_outlined, 
                          'تعديل', 
                          () { 
                            Get.back(); 
                            setState(() { _editingMessage = message; _messageController.text = message.message; }); 
                          }
                        ),
                        _buildMiniDivider(),
                      ],
                      _buildMiniHorizontalAction(
                        Icons.forward_rounded, 
                        'توجيه', 
                        () { Get.back(); _showForwardSelector(message); }
                      ),
                      if (isMe || _canDeleteAnyMessage) ...[
                        _buildMiniDivider(),
                        _buildMiniHorizontalAction(
                          Icons.delete_outline_rounded, 
                          'حذف', 
                          () { Get.back(); if (message.id != null) _deleteMessage(message.id!); },
                          color: Theme.of(context).colorScheme.error
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.transparent,
      barrierDismissible: true,
    );
  }

  // الجزء الجمالي لفقاعة الرسالة بدون الرو أو الأفاتار (للمعاينة فقط)
  Widget _buildBubbleContentOnly(ChatMessageModel message, bool isMe) {
    final isRead = message.isRead;
    final showTicks = isMe && !message.isSystem;
    
    return Container(
      constraints: BoxConstraints(maxWidth: Get.width * 0.75),
      decoration: BoxDecoration(
        gradient: isMe ? LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]) : null,
        color: isMe ? null : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
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
                const Text('🚫 رسالة مسحوبة', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            )
          else ...[
            if (message.imageUrl != null) _buildImageContent(message.imageUrl!),
            if (message.message.isNotEmpty)
              MarkdownBody(
                data: message.message,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: isMe ? Colors.black : Theme.of(context).colorScheme.onSurface, fontSize: 15),
                ),
              ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.createdAt),
                style: TextStyle(color: isMe ? Colors.black54 : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9),
              ),
              if (showTicks) ...[
                const SizedBox(width: 4),
                if (widget.isGroupChat) ...[
                  Icon(Icons.done_all, color: (message.readBy?.length ?? 0) > 1 ? Colors.blue : Colors.black26, size: 15),
                  if ((message.readBy?.length ?? 0) > 1)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 2),
                      child: Text((message.readBy!.length - 1).toString(), style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                ] else
                  Icon(isRead ? Icons.done_all : Icons.done, color: isRead ? Colors.blue : Colors.black26, size: 15),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ودجت مساعد لعنصر الإجراء الأفقي الصغير
  Widget _buildMiniHorizontalAction(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurface, size: 20),
            const SizedBox(height: 4),
            Text(
              title, 
              style: GoogleFonts.tajawal(
                fontSize: 10, 
                fontWeight: FontWeight.bold, 
                color: color ?? Theme.of(context).colorScheme.onSurfaceVariant
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniDivider() => Container(width: 1, height: 25, color: Colors.grey.withValues(alpha: 0.15));




  // إضافة تفاعل للرسالة
  void _addReaction(ChatMessageModel message, String emoji) async {
    if (message.id != null) {
      await FirebaseFirestore.instance.collection('chats').doc(_getChatId()).collection('messages').doc(message.id).set({
        'reactions': {_effectiveUserId: emoji}
      }, SetOptions(merge: true));
      HapticFeedback.lightImpact();
    }
  }

  // القائمة الموسعة للإيموجي
  void _showFullEmojiPicker(ChatMessageModel message) {
    final List<String> emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', 
      '😋', '😛', '😝', '😜', '🧐', '😎', '🤩', '🥳', '😏', '😔', '😟', '😢', '😭', '😤', '😠', '😡', '🤯', 
      '😳', '🥵', '🥶', '😱', '😨', '😰', '🤤', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '😈', '👿', '👻',
      '💀', '👽', '👾', '🤖', '🎃', '😺', '🤲', '👐', '🙌', '👏', '🤝', '👍', '👎', '👊', '✊', '🤛', '🤜',
      '🤞', '✌️', '🤟', '🤘', '👌', '🤌', '🤏', '👈', '👉', '👆', '👇', '✋', '🤚', '🖐', '🖖', '👋', '🤙',
      '💪', '🦾', '🙏', '🧠', '👀', '👁', '👅', '👄', '💋', '🩸', '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤'
    ];

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 45, 
              height: 5, 
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15), 
                borderRadius: BorderRadius.circular(10)
              )
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 16),
              child: Row(
                children: [
                  Text(
                    'اختر تفاعل', 
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold, 
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.onSurface
                    )
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6, 
                  mainAxisSpacing: 15, 
                  crossAxisSpacing: 15
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () { 
                    Get.back(); 
                    _addReaction(message, emojis[index]); 
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      emojis[index], 
                      style: const TextStyle(fontSize: 28)
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }


  void _showForwardSelector(ChatMessageModel message) {
    String query = '';
    final myRole = _authController.currentUser.value?.role;
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
                      final targetRole = _parseUserRole(d['role']);
                      return name.contains(query) &&
                          doc.id != _effectiveUserId &&
                          _canCurrentRoleMessageTargetRole(myRole: myRole, targetRole: targetRole);
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
    if (_accessDenied) {
      Get.snackbar('وصول مرفوض', 'لا يمكنك توجيه الرسائل من هذه المحادثة.');
      return;
    }

    final canForward = await _canMessageTargetUser(targetId);
    if (!canForward) {
      Get.snackbar('وصول مرفوض', 'يمكنك التوجيه للإدارة فقط حسب صلاحيات حسابك.');
      return;
    }

    final chatId = _getChatIdFor(targetId);
    if (chatId == 'invalid_chat') {
      Get.snackbar('خطأ', 'تعذر إنشاء معرف المحادثة للمستلم المحدد.');
      return;
    }

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
    if (_effectiveUserId.isEmpty || targetId.isEmpty || targetId == _effectiveUserId) {
      return 'invalid_chat';
    }
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
    
    if (_isRecording) {
      return Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 10, top: 10, left: 16, right: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -2), blurRadius: 4)]
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.red),
            const SizedBox(width: 12),
            Text(_recordingDurationStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            TextButton(
              onPressed: _cancelRecording,
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

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
            boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.15), offset: const Offset(0, -2), blurRadius: 4)]
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery),
                onLongPress: () => _pickImage(ImageSource.camera),
                child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.camera_alt_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onLongPress: _startRecording,
                onTap: () {
                   Get.snackbar('نصيحة 💡', 'اضغط مطولاً لبدء تسجيل رسالة صوتية', snackPosition: SnackPosition.TOP);
                },
                child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.mic_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
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
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(right: const BorderSide(color: Colors.orange, width: 4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تعديل الرسالة', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(_editingMessage!.message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              onPressed: () {
                _messageController.clear();
                setState(() => _editingMessage = null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
      
      if (image != null) {
        _showImageConfirmDialog(File(image.path));
      }
    } catch (e) {
      _handleError('اختيار الصورة', e);
    }
  }

  void _showImageConfirmDialog(File imageFile) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد إرسال الصورة',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'هل أنت متأكد من رغبتك في إرسال هذه الصورة للمحادثات؟',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: Text('إلغاء', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Get.back();
                    setState(() {
                      _selectedImage = imageFile;
                    });
                    _sendMessage();
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  label: Text('إرسال', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = p.join(directory.path, 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordingDurationSeconds = 0;
          _recordingDurationStr = '00:00';
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDurationSeconds++;
            _recordingDurationStr = _formatDuration(_recordingDurationSeconds);
          });
        });
      }
    } catch (e) {
      _handleError('بدء التسجيل', e);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null && _recordingDurationSeconds > 0) {
        _sendMessage(audioPath: path, duration: _recordingDurationSeconds);
      }
    } catch (e) {
      _handleError('إيقاف التسجيل', e);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      setState(() {
        _isRecording = false;
        _recordingDurationSeconds = 0;
      });
    } catch (e) {
      debugPrint('⚠️ Error cancelling recording: $e');
    }
  }

  Future<void> _sendMessage({String? audioPath, int? duration}) async {
    if (_accessDenied) {
      Get.snackbar('وصول مرفوض', _accessDeniedMessage.isNotEmpty ? _accessDeniedMessage : 'لا تملك صلاحية الإرسال في هذه المحادثة.');
      return;
    }

    if (_messageController.text.trim().isEmpty && _selectedImage == null && audioPath == null) return;

    final chatId = _getChatId();

    if (widget.isGroupChat && !_isGroupAllowedForRole(chatId, _authController.currentUser.value?.role)) {
      _denyChatAccess('غير مسموح لك بالمحادثات الجماعية خارج نطاق دورك.');
      return;
    }

    if (!widget.isGroupChat && widget.targetUserId != null && widget.targetUserId!.isNotEmpty) {
      final canMessageTarget = await _canMessageTargetUser(widget.targetUserId!);
      if (!canMessageTarget) {
        _denyChatAccess('هذا الدور يمكنه مراسلة الإدارة فقط في المحادثات الخاصة.');
        return;
      }
    }
    
    // منع الإرسال إذا كان chatId غير صحيح
    if (chatId == 'invalid_chat') {
      Get.snackbar(
        'خطأ',
        'لا يمكن تحديد المحادثة. تأكد من البيانات',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.15),
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
      String? audioUrl;
      int? audioDuration = duration;

      if (_selectedImage != null || audioPath != null) {
        setState(() => _isUploading = true);
        try {
          if (_selectedImage != null) {
            // ضغط الصورة قبل الرفع
            final compressedFile = await ImageCompressionService.compressImage(_selectedImage!);
            final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
            imageUrl = await FirebaseStorageService.uploadMedia(
              compressedFile ?? _selectedImage!,
              'chats/$chatId/$fileName',
            );
          } else if (audioPath != null) {
            final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
            audioUrl = await FirebaseStorageService.uploadMedia(
              File(audioPath),
              'chats/$chatId/$fileName',
            );
          }
        } catch (e) {
          _handleError('رفع الوسائط', e);
        } finally {
          _selectedImage = null;
          setState(() => _isUploading = false);
        }
      }

      final String sendingName = _effectiveUserName;
      
      // تحديث بيانات المحادثة الرئيسية أولاً لضمان وجود الصلاحيات (Participants Array) قبل إرسال الرسالة
      try {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'lastMessage': imageUrl != null ? '📷 صورة' : (audioUrl != null ? '🎙️ رسالة صوتية' : text),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastMessageSenderId': _effectiveUserId,
          'type': widget.isGroupChat ? 'group' : (chatId.startsWith('guest_') ? 'guest' : 'private'),
          'participants': FieldValue.arrayUnion([_effectiveUserId, if (widget.targetUserId != null) widget.targetUserId!]),
          'participantNames.$_effectiveUserId': sendingName,
          'participantAvatars.$_effectiveUserId': _currentUserImage ?? '',
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('⚠️ تحذير: فشل تحديث وثيقة المحادثة: $e');
      }

      try {
        await messagesRef.add({
          'senderId': _effectiveUserId,
          'senderName': sendingName,
          'senderImage': _currentUserImage,
          'message': text,
          'imageUrl': imageUrl,
          'audioUrl': audioUrl,
          'audioDuration': audioDuration,
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

      // حفظ بيانات الزائر وتحديث عداد الرسائل غير المقروءة للإدارة
      if (chatId.startsWith('guest_')) {
        await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
          'type': 'guest',
          'guestName': _effectiveUserName,
          'guestPhone': _effectiveUserId.replaceFirst('guest_', ''),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'hasUnreadGuestMessage': true,
          'guestUnreadCount': FieldValue.increment(1),
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
              title: '💬 تفاعل جديد في مجموعة الفريق',
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
            title: '📩 رسالة من زائر محتاج',
            body: '$senderDisplayName: $text',
            data: notificationData,
            excludeUserId: _effectiveUserId,
          );
        } 
        // 4. المحادثات الخاصة الموجهة (للمستقبل فقط)
        else if (widget.targetUserId != null && !isReceiverGuest) {
          final targetIsOnScreen = await _isTargetUserActiveInThisChat(chatId, widget.targetUserId!);
          if (targetIsOnScreen) {
            debugPrint('🔕 Skip push notification: target user is active in this chat screen');
            return;
          }

          // تأكيد إضافي: لا ترسل إشعاراً لجميع المدراء إذا كانت المحادثة خاصة
          await NotificationService.sendNotification(
            userId: widget.targetUserId!,
            type: 'new_message',
            title: '💬 رسالة من $senderDisplayName',
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
        backgroundColor: Colors.red.withValues(alpha: 0.15),
      );
    }
  }

  Future<void> _markMessagesAsRead(List<QueryDocumentSnapshot> docs) async {
    if (_accessDenied || _effectiveUserId.isEmpty) return;

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
    try {
      await batch.commit();
      await _markAsRead();
    } catch (e) {
      debugPrint('⚠️ Error marking messages as read: $e');
    }
  }

  void _showMembersSheet() {
    final myRole = _authController.currentUser.value?.role;

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
                      final workers = snapshot.data!.docs
                          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                          .where((user) => user.id != _effectiveUserId)
                          .where((user) => _canCurrentRoleMessageTargetRole(myRole: myRole, targetRole: user.role))
                          .toList();
                      
                      return ListView.builder(
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          final worker = workers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              backgroundImage: (worker.profileImage != null && worker.profileImage!.isNotEmpty) ? CachedNetworkImageProvider(worker.profileImage!) as ImageProvider : null,
                              child: (worker.profileImage == null || worker.profileImage!.isEmpty) ? Text(worker.name[0], style: TextStyle(color: Theme.of(context).colorScheme.primary)) : null,
                            ),
                            title: Text(worker.name, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                            subtitle: Text(worker.role.displayName, style: GoogleFonts.tajawal(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            trailing: IconButton(
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

