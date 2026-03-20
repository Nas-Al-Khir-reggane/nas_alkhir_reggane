import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final _msgCtl = TextEditingController();
  final ScrollController _scrollCtl = ScrollController();
  
  // For simplicity, using a global chat for workers and admins, or specific if argument is passed.
  // We'll use a single chat document 'general_chat' for demonstration,
  // but it can be dynamic depending on Get.arguments
  String _chatId = 'general_chat'; 

  @override
  void initState() {
    super.initState();
    if (Get.arguments != null && Get.arguments is String) {
      _chatId = Get.arguments as String;
    }
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      File file = File(picked.path);
      String fileName = "chats/$_chatId/${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      Get.snackbar("جاري الإرسال...", "يتم رفع الصورة الآن", duration: const Duration(seconds: 2));
      try {
        TaskSnapshot snap = await FirebaseStorage.instance.ref(fileName).putFile(file);
        String url = await snap.ref.getDownloadURL();
        _sendMessage(imageUrl: url);
      } catch (e) {
        Get.snackbar("خطأ", "فشل رفع الصورة");
      }
    }
  }

  void _sendMessage({String? imageUrl}) async {
    String text = _msgCtl.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    
    _msgCtl.clear();
    final user = _authController.currentUser.value;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection(AppConstants.chatCollection)
        .doc(_chatId)
        .collection('messages')
        .add({
      'senderId': user.id,
      'senderName': user.name,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollCtl.hasClients) {
      _scrollCtl.animateTo(
        _scrollCtl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    String name = data['senderName'] ?? 'مجهول';
    String text = data['text'] ?? '';
    String? imageUrl = data['imageUrl'];
    Timestamp? ts = data['timestamp'] as Timestamp?;
    String time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.green.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(name, style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
            if (!isMe) const SizedBox(height: 4),
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 4),
            ],
            if (text.isNotEmpty) Text(text, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authController.currentUser.value;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("الدردشة"),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.chatCollection)
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                // wait for build to finish then scroll to bottom
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollCtl,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == user?.id;
                    return _buildMessageBubble(data, isMe);
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.green),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtl,
                    decoration: InputDecoration(
                      hintText: "اكتب رسالة...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
