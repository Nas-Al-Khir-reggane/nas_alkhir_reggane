import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:math';

import '../../../core/routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import 'chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/user_model.dart';
import '../../../core/theme/app_theme.dart';

class AdminInboxScreen extends StatefulWidget {
  const AdminInboxScreen({super.key});

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showArchived = false;
  bool _showDeleted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String currentUserId = _authController.currentUser.value?.id ?? '';
      final bool isAdmin = _authController.currentUser.value?.role == UserRole.admin || 
                           _authController.currentUser.value?.role == UserRole.superAdmin;

      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📬 صندوق الرسائل',
                      style: GoogleFonts.tajawal(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface)),
                  Text('جميع محادثاتك الخاصة والجماعية',
                      style: GoogleFonts.tajawal(
                          fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو البريد الإلكتروني...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_showArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: _showArchived ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                        onPressed: () => setState(() {
                          _showArchived = !_showArchived;
                          if (_showArchived) _showDeleted = false;
                        }),
                        tooltip: _showArchived ? 'الرجوع للرسائل' : 'عرض الأرشيف',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: _showDeleted ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant),
                        onPressed: () => setState(() {
                          _showDeleted = !_showDeleted;
                          if (_showDeleted) _showArchived = false;
                        }),
                        tooltip: _showDeleted ? 'الرجوع للرسائل' : 'سلة المحذوفات',
                      ),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Group chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.to(() => const ChatScreen(isGroupChat: true, chatId: 'group_team', groupName: 'غرفة الفريق الجماعية')),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded, color: Colors.black, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('غرفة الفريق الجماعية',
                                      style: GoogleFonts.tajawal(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14)),
                                  Text('لجميع الأعضاء',
                                      style: GoogleFonts.tajawal(
                                          color: Colors.black54, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isAdmin)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Get.to(() => const ChatScreen(isGroupChat: true, chatId: 'group_management', groupName: 'غرفة الإدارة العليا')),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFFFD700)]),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFB8860B).withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.admin_panel_settings_rounded, color: Colors.black, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('الإدارة العليا',
                                        style: GoogleFonts.tajawal(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14)),
                                    Text('خاصة بالمدراء',
                                        style: GoogleFonts.tajawal(
                                            color: Colors.black54, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _showDeleted ? 'سلة المحذوفات 🗑️' : (_showArchived ? 'المحادثات المؤرشفة' : 'المحادثات الخاصة'),
                style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _showDeleted ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),

            // Private chat list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where(isAdmin 
                        ? Filter.or(
                            Filter('participants', arrayContains: currentUserId),
                            Filter('type', isEqualTo: 'guest')
                          )
                        : Filter('participants', arrayContains: currentUserId))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.orange, size: 40),
                              const SizedBox(height: 12),
                              const Text('تعذر تحميل المحادثات حالياً. يرجى إعادة المحاولة.', 
                                   textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.orange, fontSize: 12)),
                              const SizedBox(height: 8),
                              const Text('إذا استمر الخلل، تحقق من إعدادات قاعدة البيانات والفهارس المطلوبة.',
                                   textAlign: TextAlign.center,
                                   style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.primary));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmpty();
                    }

                    final allDocs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      
                      // تخطي المحادثات الجماعية (سيتم عرضها في زر منفصل)
                      if (data['type'] == 'group') return false;
                      
                      final deletedBy = (data['deletedBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      final isDeleted = deletedBy.contains(currentUserId);
                      
                      if (_showDeleted) return isDeleted;
                      if (isDeleted) return false;

                      final archivedBy = (data['archivedBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      final isArchived = archivedBy.contains(currentUserId);

                      if (_showArchived) return isArchived;
                      if (isArchived) return false;

                      // فلترة البحث
                      if (_searchQuery.isNotEmpty) {
                        final participantNames = data['participantNames'] as Map<String, dynamic>? ?? {};
                        final guestName = data['guestName']?.toString().toLowerCase() ?? '';
                        final guestPhone = data['guestPhone']?.toString() ?? '';
                        
                        bool matchFound = false;
                        participantNames.forEach((key, value) {
                          if (value.toString().toLowerCase().contains(_searchQuery)) {
                            matchFound = true;
                          }
                        });
                        
                        if (!matchFound && !guestName.contains(_searchQuery) && !guestPhone.contains(_searchQuery)) {
                          return false;
                        }
                      }

                      return true;
                    }).toList();

                    if (allDocs.isEmpty) {
                      return _buildEmpty();
                    }

                    // Sort: Pinned chats first, then by date
                    allDocs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aPinned = ((aData['pinnedBy'] as List?)?.contains(currentUserId)) ?? false;
                      final bPinned = ((bData['pinnedBy'] as List?)?.contains(currentUserId)) ?? false;
                      
                      if (aPinned && !bPinned) return -1;
                      if (!aPinned && bPinned) return 1;
                      
                      final aDate = (aData['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      final bDate = (bData['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      return bDate.compareTo(aDate);
                    });

                    final privates = allDocs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      return data['type'] == 'private' && participants.contains(currentUserId);
                    }).toList();

                    final guests = allDocs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['type'] == 'guest';
                    }).toList();

                    return RefreshIndicator(
                      onRefresh: () async {
                        await Future.delayed(const Duration(milliseconds: 800));
                        if (mounted) setState(() {});
                      },
                      color: Theme.of(context).colorScheme.primary,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          if (guests.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                              child: Text('طلبات تواصل الزوار',
                                  style: GoogleFonts.tajawal(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.primary)),
                            ),
                            ...guests.map((doc) => _buildGuestTile(context, doc.data() as Map<String, dynamic>, doc.id, currentUserId)),
                            const SizedBox(height: 16),
                            const Divider(),
                          ],
                          if (privates.isNotEmpty) ...[
                            if (_searchQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                child: Text('المحادثات الحالية',
                                    style: GoogleFonts.tajawal(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary)),
                              ),
                            ...privates.map((doc) => _buildConversationTile(context, doc.data() as Map<String, dynamic>, doc.id, currentUserId)),
                          ],
                          if (_searchQuery.isNotEmpty && !_showArchived && !_showDeleted) ...[
                              _buildUserSearch(_searchQuery, currentUserId)
                          ],
                          if (guests.isEmpty && privates.isEmpty && _searchQuery.isEmpty) ...[
                              _buildEmpty(),
                          ]
                        ],
                      ),
                    );
              },
            ),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      heroTag: 'admin_inbox_fab',
      onPressed: () => _showUserSelector(context, currentUserId),
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.add_comment_rounded, color: Colors.white),
    ),
  );
});
}

  void _showUserSelector(BuildContext context, String currentUserId) {
    String innerSearch = '';
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Text('بدء محادثة جديدة', 
                style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              TextField(
                onChanged: (val) => setModalState(() => innerSearch = val.toLowerCase().trim()),
                decoration: InputDecoration(
                  hintText: 'البحث عن مستفيد أو متطوع...',
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    final users = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name']?.toString().toLowerCase() ?? '';
                      final email = data['email']?.toString().toLowerCase() ?? '';
                      
                      // لا يظهر الشخص نفسه في القائمة
                      if (doc.id == currentUserId) return false;

                      return name.contains(innerSearch) || email.contains(innerSearch);
                    }).toList();

                    if (users.isEmpty) return Center(child: Text('لا يوجد نتائج', style: GoogleFonts.tajawal()));

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userData = users[index].data() as Map<String, dynamic>;
                        final userId = users[index].id;
                        final String userEmail = userData['email'] ?? '';
                        final String userName = userData['name'] ?? (userEmail.isNotEmpty ? userEmail.split('@').first : 'مشارك');
                        final avatar = userData['profileImage'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            backgroundImage: (avatar != null && avatar.isNotEmpty) ? CachedNetworkImageProvider(avatar) as ImageProvider : null,
                            child: (avatar == null || avatar.isEmpty) ? Text(userName[0], style: TextStyle(color: Theme.of(context).colorScheme.primary)) : null,
                          ),
                          title: Text(userName, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                          subtitle: Text(userEmail.isNotEmpty ? userEmail : 'بدون بريد إلكتروني'),
                          trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                          onTap: () {
                            Get.back();
                            Get.toNamed(AppRoutes.chatPrivate, arguments: {
                              'targetUserId': userId,
                              'targetUserName': userName,
                            });
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

  Widget _buildGuestTile(BuildContext context, Map<String, dynamic> data, String chatId, String currentUserId) {
    final String guestName = data['guestName'] ?? 'زائر مجهول';
    final String guestPhone = data['guestPhone'] ?? '';
    final String lastMessage = data['lastMessage'] ?? '';
    final Timestamp? lastAt = data['lastMessageAt'];
    final DateTime? lastTime = lastAt?.toDate();
    
    // For guests, we show a dot if it has unread messages and this admin is not a participant yet
    final Map<String, dynamic> unreadMap = Map<String, dynamic>.from(data['unreadCount'] ?? {});
    final int unreadCount = (unreadMap[currentUserId] ?? 0).toInt();
    final bool hasUnread = (data['hasUnreadGuestMessage'] == true && !(data['participants'] as List? ?? []).contains(currentUserId)) || unreadCount > 0;
    
    final List<String> tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return Dismissible(
      key: Key(chatId),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(true),
      secondaryBackground: _buildDismissBackground(false),
      confirmDismiss: (direction) async {
        await _toggleArchiveStatus(chatId, currentUserId);
        return false;
      },
      child: GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.chatPrivate,
            arguments: {'chatId': chatId, 'userName': guestName}),
        onLongPress: () => _showChatOptions(context, chatId, currentUserId, data),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasUnread ? AppTheme.emergencyColor.withValues(alpha: 0.1) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: hasUnread ? AppTheme.emergencyColor.withValues(alpha: 0.15) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.support_agent, color: Theme.of(context).colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(guestName,
                                    style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                                if (((data['pinnedBy'] as List?)?.contains(currentUserId)) ?? false)
                                   Padding(
                                     padding: const EdgeInsetsDirectional.only(end: 8),
                                     child: Icon(Icons.push_pin, size: 12, color: Theme.of(context).colorScheme.primary),
                                   ),
                              ],
                            ),
                          ),
                        if (lastTime != null)
                          Text(_formatTime(lastTime), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
                      ],
                    ),
                    Text(guestPhone, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                            child: Text(lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: hasUnread ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
                        if (hasUnread)
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                             decoration: BoxDecoration(
                               color: AppTheme.emergencyColor,
                               borderRadius: BorderRadius.circular(20),
                             ),
                             child: Text(
                               unreadCount > 0 ? unreadCount.toString() : "!",
                               style: const TextStyle(
                                   color: Colors.white,
                                   fontSize: 10,
                                   fontWeight: FontWeight.bold),
                             ),
                           ),
                      ],
                    ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 4,
                          children: tags.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)),
                            ),
                            child: Text(t, style: GoogleFonts.tajawal(fontSize: 9, color: Theme.of(context).colorScheme.secondary)),
                          )).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(BuildContext context,
      Map<String, dynamic> data, String chatId, String currentUserId) {
    final List participants = List.from(data['participants'] ?? []);
    final String otherUserId =
        participants.firstWhere((p) => p != currentUserId, orElse: () => '');
    final Map<String, dynamic> names =
        Map<String, dynamic>.from(data['participantNames'] ?? {});
    
    // التحقق من الاسم محلياً أولاً
    final String? localName = names[otherUserId] ?? data['guestName'];
    
    // استخدام ويدجت حل الاسم لضمان ظهور الاسم الحقيقي حتى لو غاب عن مستند المحادثة
    final Widget nameWidget = _ChatNameResolver(
      userId: otherUserId,
      currentName: localName,
      chatId: chatId,
      guestPhone: data['guestPhone'],
      fallbackId: otherUserId,
    );

    final String lastMessage = data['lastMessage'] ?? '';
    final Timestamp? lastAt = data['lastMessageAt'];
    final DateTime? lastTime = lastAt?.toDate();
    final Map<String, dynamic> unreadMap =
        Map<String, dynamic>.from(data['unreadCount'] ?? {});
    final int unread = (unreadMap[currentUserId] ?? 0).toInt();
    final String? senderAvatar = (data['participantAvatars'] ?? {})[otherUserId];
    final List<String> tags = (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

    Timestamp? chatLastActivity;
    if (data['lastActivity'] is Map && data['lastActivity'][otherUserId] != null) {
      chatLastActivity = data['lastActivity'][otherUserId] as Timestamp;
    } else if (data['lastActivity.$otherUserId'] != null) {
      chatLastActivity = data['lastActivity.$otherUserId'] as Timestamp;
    }
    
    bool isOnline = chatLastActivity != null && DateTime.now().difference(chatLastActivity.toDate()).inMinutes < 5;

    return Dismissible(
      key: Key(chatId),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(true),
      secondaryBackground: _buildDismissBackground(false),
      confirmDismiss: (direction) async {
        await _toggleArchiveStatus(chatId, currentUserId);
        return false;
      },
      child: GestureDetector(
      onTap: () {
        final resolvedName = _ChatNameResolver._nameCache[otherUserId];
        Get.toNamed(AppRoutes.chatPrivate,
          arguments: {
            'chatId': chatId, 
            'userId': otherUserId, 
            'userName': resolvedName ?? localName ?? "مشارك"
          });
      },
      onLongPress: () => _showChatOptions(context, chatId, currentUserId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread > 0
              ? AppTheme.emergencyColor.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: unread > 0
                  ? AppTheme.emergencyColor.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Get.toNamed('/profile', arguments: otherUserId),
              child: Stack(
                children: [
                  _ChatAvatarResolver(
                    userId: otherUserId,
                    currentAvatar: senderAvatar,
                    currentName: localName,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).cardColor, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                        Expanded(
                          child: Row(
                            children: [
                              nameWidget, // استخدام الحل المستند للبيانات الحقيقية
                              if (((data['pinnedBy'] as List?)?.contains(currentUserId)) ?? false)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 8),
                                  child: Icon(Icons.push_pin, size: 12, color: Theme.of(context).colorScheme.primary),
                                ),
                            ],
                          ),
                        ),
                      if (lastTime != null)
                        Text(
                          _formatTime(lastTime),
                          style: GoogleFonts.tajawal(
                              color: unread > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.tajawal(
                                color: unread > 0
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.emergencyColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(unread.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 4,
                        children: tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)),
                          ),
                          child: Text(t, style: GoogleFonts.tajawal(fontSize: 9, color: Theme.of(context).colorScheme.secondary)),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
   );
  }

  Widget _buildDismissBackground(bool isPrimary) {
    return Container(
      alignment: isPrimary ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        _showArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
        color: Colors.white,
      ),
    );
  }

  Future<void> _toggleArchiveStatus(String chatId, String userId) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final doc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (!doc.exists) return;
    
    final data = doc.data() as Map<String, dynamic>;
    final archivedBy = (data['archivedBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    if (archivedBy.contains(userId)) {
      archivedBy.remove(userId);
    } else {
      archivedBy.add(userId);
    }
    
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'archivedBy': archivedBy,
    });
    
    if (!mounted) return;
    Get.snackbar(
      'تم',
      _showArchived ? 'تمت استعادة المحادثة' : 'تم أرشفة المحادثة',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: primaryColor.withValues(alpha: 0.15),
    );
  }

  void _showChatOptions(BuildContext context, String chatId, String userId, Map<String, dynamic> data) {
    final pinnedBy = (data['pinnedBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final isPinned = pinnedBy.contains(userId);

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: Theme.of(context).colorScheme.primary),
              title: Text(isPinned ? 'إلغاء التثبيت' : 'تثبيت في الأعلى', style: GoogleFonts.tajawal()),
              onTap: () {
                Get.back();
                _togglePinStatus(chatId, userId);
              },
            ),
            ListTile(
              leading: Icon(_showArchived ? Icons.unarchive_outlined : Icons.archive_outlined, color: Theme.of(context).colorScheme.secondary),
              title: Text(_showArchived ? 'استعادة من الأرشيف' : 'أرشفة المحادثة', style: GoogleFonts.tajawal()),
              onTap: () {
                Get.back();
                _toggleArchiveStatus(chatId, userId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('حذف المحادثة نهائياً', style: GoogleFonts.tajawal(color: Colors.red)),
              onTap: () {
                Get.back();
                _showDeleteConfirmation(context, chatId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePinStatus(String chatId, String userId) async {
    final doc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final pinnedBy = (data['pinnedBy'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    if (pinnedBy.contains(userId)) {
      pinnedBy.remove(userId);
    } else {
      pinnedBy.add(userId);
    }
    
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({'pinnedBy': pinnedBy});
    Get.snackbar('تم', pinnedBy.contains(userId) ? 'تم تثبيت المحادثة' : 'تم إلغاء التثبيت', snackPosition: SnackPosition.BOTTOM);
  }

  Widget _buildUserSearch(String query, String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final users = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString().toLowerCase() ?? '';
          final email = data['email']?.toString().toLowerCase() ?? '';
          if (doc.id == currentUserId) return false;
          return name.contains(query) || email.contains(query);
        }).toList();

        if (users.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 24, bottom: 8, start: 4, end: 4),
              child: Row(
                children: [
                  Icon(Icons.person_search_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('دليل المستخدمين المتاحين للتواصل',
                      style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            ...users.map((doc) {
              final userData = doc.data() as Map<String, dynamic>;
              final userId = doc.id;
              final String userEmail = userData['email'] ?? '';
              final String userName = userData['name'] ?? (userEmail.isNotEmpty ? userEmail.split('@').first : 'مشارك');
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    backgroundImage: (userData['profileImage'] != null && userData['profileImage'].isNotEmpty) 
                        ? CachedNetworkImageProvider(userData['profileImage']) as ImageProvider : null,
                    child: (userData['profileImage'] == null || userData['profileImage'].isEmpty)
                        ? Text(userName[0], style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)) : null,
                  ),
                  title: Text(userName, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(userEmail.isNotEmpty ? userEmail : 'بدون بريد إلكتروني', style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.maps_ugc_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  onTap: () => Get.toNamed(AppRoutes.chatPrivate, arguments: {
                    'targetUserId': userId,
                    'targetUserName': userName,
                  }),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return intl.DateFormat('HH:mm').format(time);
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return '${diff.inDays} أيام';
    return intl.DateFormat('MM/dd').format(time);
  }

  void _showDeleteConfirmation(BuildContext context, String chatId) {
    final currentUserId = _authController.currentUser.value?.id;
    Get.dialog(
      AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_showDeleted ? 'خيارات السلة' : 'حذف المحادثة', style: GoogleFonts.tajawal(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showDeleted)
              ListTile(
                leading: const Icon(Icons.restore_page_outlined, color: Colors.green),
                title: const Text('استعادة المحادثة'),
                onTap: () async {
                  Get.back();
                  await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
                    'deletedBy': FieldValue.arrayRemove([currentUserId])
                  });
                  Get.snackbar('تمت الاستعادة ♻️', 'عادت المحادثة لصندوق الرسائل', backgroundColor: Colors.green.withValues(alpha: 0.15));
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text(_showDeleted ? 'حذف نهائي (لا يمكن التراجع)' : 'نقل إلى سلة المحذوفات'),
              onTap: () async {
                final errorColor = Theme.of(context).colorScheme.error;
                Get.back();
                if (_showDeleted) {
                  await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
                  Get.snackbar('تم الحذف 🗑️', 'تم حذف المحادثة نهائياً', backgroundColor: errorColor.withValues(alpha: 0.15));
                } else {
                  await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
                    'deletedBy': FieldValue.arrayUnion([currentUserId])
                  });
                  Get.snackbar('تم النقل 📂', 'المحادثة موجودة الآن في سلة المحذوفات', backgroundColor: Colors.orange.withValues(alpha: 0.15));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 70, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text('لا توجد محادثات تؤدي لنتائج البحث',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ويدجت ذكي لحل أسماء المشاركين وترميم بيانات المحادثة تلقائياً
class _ChatNameResolver extends StatelessWidget {
  final String userId;
  final String? currentName;
  final String chatId;
  final String? guestPhone;
  final String fallbackId;

  // ذاكرة مؤقتة لأسماء المستخدمين لمنع "الوميض" أو التبديل السريع عند إعادة بناء القائمة
  static final Map<String, String> _nameCache = {};
  static final Map<String, String> _avatarCache = {};
  // تتبع المحادثات التي تم إصلاحها بالفعل لتجنب حلقات التحديث اللانهائية
  static final Set<String> _repairedChats = {};

  const _ChatNameResolver({
    required this.userId,
    this.currentName,
    required this.chatId,
    this.guestPhone,
    required this.fallbackId,
  });

  @override
  Widget build(BuildContext context) {
    // 1. إذا كان الاسم موجوداً في الذاكرة المؤقتة للتطبيق (Cache)، نعرضه فوراً
    final String cleanId = userId.trim();
    if (_nameCache.containsKey(cleanId)) {
      return _buildNameText(context, _nameCache[cleanId]!);
    }

    // 2. إذا كان الاسم قادماً من مستند المحادثة (Denormalized)، نحفظه ونعرضه
    if (currentName != null && currentName!.isNotEmpty && currentName != 'مستخدم' && currentName != 'مشارك') {
      _nameCache[userId] = currentName!;
      return _buildNameText(context, currentName!);
    }

    // 3. إذا كان الطرف الآخر زائراً
    if (userId.isEmpty || userId.startsWith('guest_')) {
      final name = guestPhone != null ? 'ضيف ($guestPhone)' : 'زائر مجهول';
      return _buildNameText(context, name);
    }

    // 4. البحث في Firestore مع التخزين المؤقت
    return FutureBuilder<DocumentSnapshot>(
      // استخدام الكاش الخاص بـ Firestore لضمان السرعة
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final realName = data['name']?.toString() ?? '';
          final realImage = data['profileImage']?.toString() ?? '';
          
          if (realName.isNotEmpty) {
            final String cleanId = userId.trim();
            _nameCache[cleanId] = realName;
            if (realImage.isNotEmpty) _avatarCache[cleanId] = realImage;
            
            // إصلاح البيانات فقط إذا لم يتم إصلاحها في هذه الجلسة وبشرط أن يكون الاسم الحالي مختلفاً
            if (!_repairedChats.contains(chatId) && (currentName != realName || realImage.isNotEmpty)) {
              _repairedChats.add(chatId);
              _repairChatData(realName, realImage);
            }
            return _buildNameText(context, realName);
          }
        }

        // عرض الهوية المؤقتة أثناء التحميل أو في حال الفشل
        final shortId = fallbackId.isNotEmpty ? fallbackId.substring(0, min(5, fallbackId.length)) : '...';
        return _buildNameText(context, 'مشارك ($shortId)', isGray: snapshot.connectionState == ConnectionState.waiting);
      },
    );
  }

  Widget _buildNameText(BuildContext context, String name, {bool isGray = false}) {
    // التحقق مما إذا كان الويدجت يُستخدم داخل الدائرة (Avatar) أو كعنوان
    final bool isInsideAvatar = context.findAncestorWidgetOfExactType<CircleAvatar>() != null;

    if (isInsideAvatar) {
      return Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text(
      name,
      style: GoogleFonts.tajawal(
        color: isGray ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _repairChatData(String resolvedName, String resolvedImage) {
    try {
      final Map<String, dynamic> updateData = {
        'participantNames.$userId': resolvedName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (resolvedImage.isNotEmpty) {
        updateData['participantAvatars.$userId'] = resolvedImage;
      }

      FirebaseFirestore.instance.collection('chats').doc(chatId).set(updateData, SetOptions(merge: true));
      debugPrint('🔧 Data Repaired: Rescued identity for chat $chatId');
    } catch (e) {
      debugPrint('⚠️ Error repairing chat data: $e');
    }
  }
}

// ويدجت ذكي لحل الصور الشخصية في القوائم
class _ChatAvatarResolver extends StatelessWidget {
  final String userId;
  final String? currentAvatar;
  final String? currentName;

  const _ChatAvatarResolver({
    required this.userId,
    this.currentAvatar,
    this.currentName,
  });

  @override
  Widget build(BuildContext context) {
    final cleanId = userId.trim();
    
    // 1. استخدام الصورة المعطاة إذا كانت موجودة
    if (currentAvatar != null && currentAvatar!.isNotEmpty) {
       return _buildAvatar(context, currentAvatar!);
    }

    // 2. التحقق من الكاش
    if (_ChatNameResolver._avatarCache.containsKey(cleanId)) {
      return _buildAvatar(context, _ChatNameResolver._avatarCache[cleanId]!);
    }

    // 3. إذا كان ضيفاً
    if (userId.isEmpty || userId.startsWith('guest_')) {
      return _buildLetterAvatar(context, currentName ?? '؟');
    }

    // 4. جلب من Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(cleanId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final image = data['profileImage']?.toString() ?? '';
          final name = data['name']?.toString() ?? currentName ?? '؟';
          
          if (image.isNotEmpty) {
            _ChatNameResolver._avatarCache[cleanId] = image;
            return _buildAvatar(context, image);
          }
          return _buildLetterAvatar(context, name);
        }
        return _buildLetterAvatar(context, currentName ?? '؟');
      },
    );
  }

  Widget _buildAvatar(BuildContext context, String imageUrl) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      backgroundImage: CachedNetworkImageProvider(imageUrl),
    );
  }

  Widget _buildLetterAvatar(BuildContext context, String name) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '؟';
    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      child: Text(
        letter,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: (24 * 0.8),
        ),
      ),
    );
  }
}

